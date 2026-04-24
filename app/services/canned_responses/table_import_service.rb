# frozen_string_literal: true

require 'csv'

# rubocop:disable Style/ClassAndModuleChildren -- Zeitwerk path canned_responses/ → CannedResponses::
module CannedResponses
  # Imports rows from:
  # - .xlsx (first sheet): columns 1–3 = short code, content, optional topic;
  #   optional column 4 = label titles (comma / semicolon / pipe). Missing labels are created on the account.
  # - With only 3 columns: if the first row was skipped as a header, column 3 is topic unless the header
  #   or cell indicates labels (see below). If there is no header row, column 3 is always label title(s).
  # - Label hints: header cell mentions labels / метки / …, or the value contains comma / semicolon / pipe.
  # - TSV/CSV: same columns; invalid bytes are replaced (Windows-1251 / broken UTF-8 safe)
  class TableImportService
    MAX_FILE_BYTES = 5.megabytes

    def initialize(account:, uploaded_file:)
      @account = account
      @uploaded_file = uploaded_file
    end

    # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/AbcSize -- import row loop
    def perform
      raise ArgumentError, 'file is required' if @uploaded_file.blank?
      raise ArgumentError, 'file is too large (max 5 MB)' if @uploaded_file.respond_to?(:size) && @uploaded_file.size > MAX_FILE_BYTES

      rows = load_rows

      imported = 0
      errors = []
      @header_says_third_column_is_labels = false
      @import_skipped_header_row = false
      @header_row_consumed = false

      rows.each_with_index do |row, index|
        line_number = index + 1
        cells = row.map { |c| cell_to_plain_string(c).strip }
        next if cells.all?(&:blank?)

        # First header-like row may be after leading blank rows (do not tie to index.zero? only).
        if header_row?(cells) && !@header_row_consumed
          @header_row_consumed = true
          @import_skipped_header_row = true
          # Third column named "Labels" → data col3 is labels; "Topic" (or unknown) → data col3 is topic.
          labels_hdr = header_labels_in_third_column?(cells)
          topic_hdr = header_topic_in_third_column?(cells)
          @header_says_third_column_is_labels = labels_hdr && !topic_hdr
          next
        end

        short_code = cells[0]
        content = cells[1]
        topic, labels_raw = topic_and_labels_from_row(cells)

        if short_code.blank? || content.blank?
          errors << { line: line_number, error: 'short_code and content are required' }
          next
        end

        label_ids = resolve_label_ids_from_import(labels_raw, line_number, errors)
        next if label_ids.nil?

        record = @account.canned_responses.new(short_code: short_code, content: content, label_ids: label_ids)
        assign_topic(record, topic)

        if record.save
          imported += 1
        else
          errors << { line: line_number, error: record.errors.full_messages.join(', ') }
        end
      end

      { imported: imported, errors: errors }
    end
    # rubocop:enable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/AbcSize

    private

    def load_rows
      if xlsx_file?
        parse_xlsx
      else
        parse_table(read_text_safe)
      end
    end

    def xlsx_file?
      name = original_filename.downcase
      return true if name.end_with?('.xlsx')

      content_type.to_s.include?('spreadsheetml.sheet')
    end

    def original_filename
      @uploaded_file.try(:original_filename).to_s
    end

    def content_type
      @uploaded_file.try(:content_type).to_s
    end

    def tempfile_path
      if @uploaded_file.respond_to?(:tempfile) && @uploaded_file.tempfile
        @uploaded_file.tempfile.path
      elsif @uploaded_file.respond_to?(:path)
        @uploaded_file.path
      end
    end

    def parse_xlsx
      path = tempfile_path
      raise ArgumentError, 'cannot read uploaded xlsx file' if path.blank?

      TableImports::XlsxFirstSheetReader.call(path).map do |row|
        row.map { |c| cell_to_plain_string(c) }
      end
    end

    def cell_to_plain_string(value)
      return '' if value.nil?

      case value
      when Date, Time, DateTime
        value.iso8601
      else
        value.to_s
      end
    end

    def read_text_safe
      raw = @uploaded_file.respond_to?(:read) ? @uploaded_file.read : @uploaded_file.to_s
      text = raw.dup.force_encoding(Encoding::BINARY).encode(
        'UTF-8',
        invalid: :replace,
        undef: :replace,
        replace: ''
      )
      text.delete_prefix!("\uFEFF")
      text
    end

    def parse_table(text)
      sep = text.include?("\t") ? "\t" : ','
      CSV.parse(text, col_sep: sep, liberal_parsing: true)
    rescue CSV::MalformedCSVError => e
      raise ArgumentError, e.message
    end

    def header_row?(cells)
      a = cells[0].to_s.downcase
      b = cells[1].to_s.downcase
      code_col = a.match?(/short[\s_]?code|шаблон|код|template|^code$|^key$/)
      content_col = b.match?(/content|текст|message|сообщ/)
      code_col && content_col
    end

    def header_labels_in_third_column?(cells)
      cells[2].to_s.match?(/\b(label|labels|метк|тег|tags?)\b/i)
    end

    def header_topic_in_third_column?(cells)
      cells[2].to_s.match?(/\b(topic|тема|тематик|theme)\b/i)
    end

    def assign_topic(record, topic)
      return if topic.blank?
      return unless record.class.column_names.include?('topic')

      record.topic = topic
    end

    # 4+ columns: short_code, content, topic, labels (4th).
    # 3 columns, no header row: short_code, content, labels (typical spreadsheet export).
    # 3 columns with header: third is topic unless header/separators mark labels.
    def topic_and_labels_from_row(cells)
      if cells.length >= 4
        [cells[2].presence, cells[3].presence]
      elsif cells.length == 3
        raw = cells[2]
        if third_column_is_labels_cell?(raw) || !@import_skipped_header_row
          [nil, raw.presence]
        else
          [raw.presence, nil]
        end
      else
        [cells[2].presence, nil]
      end
    end

    def third_column_is_labels_cell?(raw)
      text = raw.to_s
      return false if text.blank?

      return true if @header_says_third_column_is_labels

      /[,;|]/.match?(text)
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def resolve_label_ids_from_import(labels_raw, line_number, errors)
      return [] if labels_raw.blank?

      wanted = labels_raw.split(/[,;|]/).map(&:strip).reject(&:blank?)
      return [] if wanted.empty?

      ids = []
      wanted.each do |title|
        label = Labels::FindOrCreateService.new(account: @account, title: title).perform
        if label
          ids << label.id
        else
          errors << { line: line_number, error: "label #{title.inspect} could not be created (invalid name)" }
        end
      end

      return nil if ids.size != wanted.size

      ids
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  end
end
# rubocop:enable Style/ClassAndModuleChildren
