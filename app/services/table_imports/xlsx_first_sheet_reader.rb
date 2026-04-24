# frozen_string_literal: true

require 'nokogiri'
require 'zip'

class TableImports::XlsxFirstSheetReader
  WORKBOOK_NS = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
  PACKAGE_REL_NS = 'http://schemas.openxmlformats.org/package/2006/relationships'
  OFFICE_REL_NS = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'

  def self.call(path)
    new(path).rows
  end

  def self.column_index_for_ref(cell_ref)
    m = cell_ref.to_s.match(/\A([A-Za-z]+)/)
    return 0 if m.blank?

    m[1].upcase.chars.reduce(0) do |acc, ch|
      (acc * 26) + (ch.ord - 'A'.ord + 1)
    end - 1
  end

  def initialize(path)
    @path = path
  end

  def rows
    Zip::File.open(@path) do |zip|
      sheet_entry = first_worksheet_entry(zip)
      raise ArgumentError, 'xlsx has no worksheet' if sheet_entry.blank?

      shared = read_shared_strings(zip)
      sheet_xml = zip.read(sheet_entry.name)
      parse_sheet(sheet_xml, shared)
    end
  end

  private

  def first_worksheet_entry(zip)
    rels_path = 'xl/_rels/workbook.xml.rels'
    wb_path = 'xl/workbook.xml'
    return nil unless zip.find_entry(rels_path) && zip.find_entry(wb_path)

    rid = workbook_sheet_rel_id(zip, wb_path)
    return nil if rid.blank?

    path = worksheet_target(zip, rels_path, rid)
    return nil if path.blank?

    zip.find_entry(path)
  end

  def workbook_sheet_rel_id(zip, wb_path)
    wb_doc = parse_xml(zip.read(wb_path))
    sheet = wb_doc.at_xpath('//m:sheets/m:sheet', 'm' => WORKBOOK_NS)
    sheet&.attribute_with_ns('id', OFFICE_REL_NS)&.value
  end

  def worksheet_target(zip, rels_path, relationship_id)
    rels_doc = parse_xml(zip.read(rels_path))
    rel = rels_doc.at_xpath(
      %(//pr:Relationship[@Id="#{relationship_id}"]),
      'pr' => PACKAGE_REL_NS
    )
    target = rel&.[]('Target')
    return nil if target.blank?

    target.start_with?('/') ? "xl#{target}" : "xl/#{target}"
  end

  def parse_xml(raw)
    Nokogiri::XML(raw)
  end

  def read_shared_strings(zip)
    entry = zip.find_entry('xl/sharedStrings.xml')
    return [] if entry.blank?

    doc = parse_xml(zip.read(entry.name))
    doc.remove_namespaces!
    doc.xpath('//si').map do |si|
      si.xpath('.//t').map(&:text).join
    end
  end

  def parse_sheet(xml, shared_strings)
    doc = parse_xml(xml)
    doc.remove_namespaces!
    out = []
    doc.xpath('//sheetData/row').each do |row|
      cells = row_cells(row, shared_strings)
      next if cells.empty?

      max = cells.keys.max
      out << (0..max).map { |i| cells[i] || '' }
    end
    out
  end

  def row_cells(row, shared_strings)
    cells = {}
    row.xpath('./c').each do |cell_node|
      ref = cell_node['r']
      next if ref.blank?

      col = self.class.column_index_for_ref(ref)
      cells[col] = cell_string(cell_node, shared_strings)
    end
    cells
  end

  # OOXML cell kinds (+inlineStr, +b, shared string index, default).
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def cell_string(cell_node, shared_strings)
    t = cell_node['t']
    v = cell_node.at_xpath('./v')&.text
    if t == 's'
      shared_string_at(shared_strings, v)
    elsif t == 'inlineStr'
      cell_node.xpath('.//t').map(&:text).join
    elsif t == 'b'
      v == '1' ? 'TRUE' : 'FALSE'
    else
      v.presence || ''
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def shared_string_at(shared_strings, index_text)
    return '' if index_text.blank?

    shared_strings[index_text.to_i] || ''
  end
end
