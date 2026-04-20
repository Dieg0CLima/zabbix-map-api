require "test_helper"
require "fileutils"
require "shellwords"
require "tempfile"
require "tmpdir"

class Maps::Import::Kmz::ArchiveReaderTest < ActiveSupport::TestCase
  UploadedFile = Struct.new(:original_filename, :tempfile)

  test "reads plain kml input" do
    kml = "<kml><Document><name>Mapa</name></Document></kml>"

    result = Maps::Import::Kmz::ArchiveReader.call(input: kml)

    assert_equal "kml", result[:source_format]
    assert_nil result[:entry_name]
    assert_includes result[:kml], "<kml>"
  end

  test "extracts doc.kml from kmz archive" do
    kmz_binary = build_kmz("doc.kml" => "<kml><Document><name>Doc</name></Document></kml>")
    upload = build_upload("mapa.kmz", kmz_binary)

    result = Maps::Import::Kmz::ArchiveReader.call(input: upload)

    assert_equal "kmz", result[:source_format]
    assert_equal "doc.kml", result[:entry_name]
    assert_includes result[:kml], "<Document>"
  end

  test "falls back to first kml entry when doc.kml is absent" do
    kmz_binary = build_kmz("nested/mapa.kml" => "<kml><Document><name>Fallback</name></Document></kml>")
    upload = build_upload("fallback.kmz", kmz_binary)

    result = Maps::Import::Kmz::ArchiveReader.call(input: upload)

    assert_equal "kmz", result[:source_format]
    assert_equal "nested/mapa.kml", result[:entry_name]
  end

  test "raises domain error when kmz has no kml entry" do
    kmz_binary = build_kmz("readme.txt" => "sem kml")
    upload = build_upload("invalid.kmz", kmz_binary)

    error = assert_raises(Maps::Import::Errors::DomainError) do
      Maps::Import::Kmz::ArchiveReader.call(input: upload)
    end

    assert_equal "import_kmz_missing_kml", error.code
  end

  private

  def build_upload(filename, content)
    tempfile = Tempfile.new([ "upload", File.extname(filename) ])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind
    UploadedFile.new(filename, tempfile)
  end

  def build_kmz(entries)
    Dir.mktmpdir("kmz-fixture") do |dir|
      entries.each do |name, content|
        path = File.join(dir, name)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
      end

      output_path = File.join(dir, "archive.kmz")
      cmd = "cd #{Shellwords.escape(dir)} && zip -q -r #{Shellwords.escape(output_path)} ."
      success = system(cmd)
      raise "Unable to build KMZ fixture" unless success

      return File.binread(output_path)
    end
  end
end
