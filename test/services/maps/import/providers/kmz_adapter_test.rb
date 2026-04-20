require "test_helper"
require "shellwords"
require "tempfile"
require "tmpdir"

class Maps::Import::Providers::KmzAdapterTest < ActiveSupport::TestCase
  UploadedFile = Struct.new(:original_filename, :tempfile)

  test "passes through when input is already canonical contract" do
    adapter = Maps::Import::Providers::KmzAdapter.new
    payload = canonical_payload

    parsed = adapter.parse(input: payload)
    normalized = adapter.normalize(parsed: parsed)

    assert_equal payload["schema_version"], normalized["schema_version"]
    assert_equal payload["provider"], normalized["provider"]
    assert_equal payload["map"]["external_id"], normalized.dig("map", "external_id")
  end

  test "converts kml input into canonical contract with nodes and cables" do
    adapter = Maps::Import::Providers::KmzAdapter.new
    kml = <<~XML
      <kml xmlns="http://www.opengis.net/kml/2.2">
        <Document>
          <name>Mapa KMZ Adapter</name>
          <Placemark>
            <name>Node Explicito</name>
            <Point>
              <coordinates>-46.6300,-23.5500,0</coordinates>
            </Point>
            <ExtendedData>
              <Data name="node_kind"><value>switch</value></Data>
            </ExtendedData>
          </Placemark>
          <Placemark>
            <name>Cabo Principal</name>
            <LineString>
              <coordinates>-46.6300,-23.5500,0 -46.6200,-23.5600,0 -46.6100,-23.5700,0</coordinates>
            </LineString>
            <ExtendedData>
              <Data name="status"><value>up</value></Data>
              <Data name="cable_type"><value>fiber</value></Data>
            </ExtendedData>
          </Placemark>
        </Document>
      </kml>
    XML

    parsed = adapter.parse(input: kml)
    normalized = adapter.normalize(parsed: parsed)

    assert_equal "1.0", normalized["schema_version"]
    assert_equal "kmz", normalized["provider"]
    assert_equal "geo", normalized["coordinate_system"]
    assert_equal "Mapa KMZ Adapter", normalized.dig("map", "name")

    assert normalized["nodes"].size >= 2
    assert_equal 1, normalized["cables"].size

    cable = normalized["cables"].first
    assert_equal "up", cable["status"]
    assert_equal "fiber", cable["cable_type"]
    assert_equal 3, cable["points"].size
    assert_equal 0, cable["points"].first["position"]
    assert_equal -23.55, cable["points"].first["lat"]

    node_ids = normalized["nodes"].map { |node| node["external_id"] }
    assert_includes node_ids, cable["source_external_id"]
    assert_includes node_ids, cable["target_external_id"]
  end

  test "defaults explicit point placemark to site import entity metadata" do
    adapter = Maps::Import::Providers::KmzAdapter.new
    kml = <<~XML
      <kml xmlns="http://www.opengis.net/kml/2.2">
        <Document>
          <name>Mapa Site Default</name>
          <Placemark>
            <name>Site A</name>
            <Point>
              <coordinates>-46.6300,-23.5500,0</coordinates>
            </Point>
          </Placemark>
        </Document>
      </kml>
    XML

    parsed = adapter.parse(input: kml)
    normalized = adapter.normalize(parsed: parsed)
    node = normalized.fetch("nodes").first

    assert_equal "site", node.dig("metadata", "import_entity")
    assert_equal node["external_id"], node.dig("metadata", "site_external_id")
  end

  test "parses kmz upload and normalizes into canonical contract" do
    adapter = Maps::Import::Providers::KmzAdapter.new
    upload = build_kmz_upload

    parsed = adapter.parse(input: upload)
    normalized = adapter.normalize(parsed: parsed)

    assert_equal "1.0", normalized["schema_version"]
    assert_equal "kmz", normalized["provider"]
    assert_equal "Mapa KMZ Upload", normalized.dig("map", "name")
    assert_equal 1, normalized["cables"].size
  end

  private

  def canonical_payload
    {
      "schema_version" => "1.0",
      "provider" => "kmz",
      "coordinate_system" => "geo",
      "map" => { "name" => "Mapa", "external_id" => "map-ext", "metadata" => {} },
      "nodes" => [
        { "external_id" => "node-a", "label" => "A", "lat" => -23.0, "lng" => -46.0, "node_kind" => "generic", "metadata" => {} },
        { "external_id" => "node-b", "label" => "B", "lat" => -23.1, "lng" => -46.1, "node_kind" => "generic", "metadata" => {} }
      ],
      "cables" => [
        { "external_id" => "cable-a", "label" => "C", "source_external_id" => "node-a", "target_external_id" => "node-b", "status" => "planned", "cable_type" => "manual", "metadata" => {}, "points" => [] }
      ]
    }
  end

  def build_kmz_upload
    Dir.mktmpdir("kmz-adapter") do |dir|
      kml_path = File.join(dir, "doc.kml")
      File.write(kml_path, <<~XML)
        <kml xmlns="http://www.opengis.net/kml/2.2">
          <Document>
            <name>Mapa KMZ Upload</name>
            <Placemark>
              <name>Link</name>
              <LineString>
                <coordinates>-46.6300,-23.5500,0 -46.6200,-23.5600,0</coordinates>
              </LineString>
            </Placemark>
          </Document>
        </kml>
      XML

      kmz_path = File.join(dir, "sample.kmz")
      system("cd #{Shellwords.escape(dir)} && zip -q -r #{Shellwords.escape(kmz_path)} doc.kml") || raise("zip failed")

      tempfile = Tempfile.new([ "kmz-upload", ".kmz" ])
      tempfile.binmode
      tempfile.write(File.binread(kmz_path))
      tempfile.rewind

      return UploadedFile.new("sample.kmz", tempfile)
    end
  end
end
