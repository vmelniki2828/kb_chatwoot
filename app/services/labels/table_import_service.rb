# frozen_string_literal: true

require 'csv'
require 'securerandom'

module Labels
  # Imports rows from .xlsx (first sheet) or TSV/CSV:
  # columns 1–3 = title (required), description (optional), color (optional; random hex if blank)
  class TableImportService
    MAX_FILE_BYTES = 5.megabytes

    def initialize(account:, uploaded_file:)
      @account = account
      @uploaded_file = uploaded_file
    end

    def perform
      raise ArgumentError, 'file is required' if @uploaded_file.blank?
      raise ArgumentError, 'file is too large (max 5 MB)' if @uploaded_file.respond_to?(:size) && @uploaded_file.size > MAX_FILE_BYTES

      rows = load_rows

      imported = 0
      errors = []

      rows.each_with_index do |row, index|
        line_number = index + 1
        cells = row.map { |c| cell_to_plain_string(c).strip }
        next if cells.all?(&:blank?)

        next if header_row?(cells) && index.zero?

        title = cells[0]
        description = cells[1].presence
        color_raw = cells[2].presence

        if title.blank?
          errors << { line: line_number, error: 'title is required' }
          next
        end

        attrs = {
          title: title,
          description: description,
          color: color_raw.present? ? normalize_color(color_raw) : random_label_color
        }

        record = @account.labels.new(attrs)

        if record.save
          imported += 1
        else
          errors << { line: line_number, error: record.errors.full_messages.join(', ') }
        end
      end

      { imported: imported, errors: errors }
    end

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
      when String
        value.to_s
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
      text.sub!(/\A\uFEFF/, '')
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
      c = cells[2].to_s.downcase
      title_col = a.match?(/title|name|label|название|метка|имя/)
      desc_col = b.match?(/description|описание|desc|text|текст|content/)
      color_col = c.match?(/color|цвет/)
      title_col && (desc_col || color_col)
    end

    def normalize_color(value)
      s = value.to_s.strip
      return s if s.start_with?('#')
      return "##{s}" if s.match?(/\A[0-9a-fA-F]{3,8}\z/)

      s
    end

    # Same idea as dashboard/helper/labelColor.js getRandomColor (# + 6 hex digits)
    def random_label_color
      "##{SecureRandom.hex(3).upcase}"
    end
  end
end
