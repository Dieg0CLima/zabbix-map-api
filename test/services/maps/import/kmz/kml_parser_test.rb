require "test_helper"

class Maps::Import::Kmz::KmlParserTest < ActiveSupport::TestCase
  test "parses document name point linestring and extended data" do
    kml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <kml xmlns="http://www.opengis.net/kml/2.2">
        <Document>
          <name>Mapa KMZ</name>
          <Placemark>
            <name>POP Centro</name>
            <ExtendedData>
              <Data name="category"><value>site</value></Data>
            </ExtendedData>
            <Point>
              <coordinates>-46.63,-23.55,0</coordinates>
            </Point>
          </Placemark>
          <Placemark>
            <name>Backbone</name>
            <ExtendedData>
              <SchemaData>
                <SimpleData name="role">backbone</SimpleData>
              </SchemaData>
            </ExtendedData>
            <LineString>
              <coordinates>
                -46.63,-23.55,0 -46.62,-23.56,0 -46.61,-23.57,0
              </coordinates>
            </LineString>
          </Placemark>
        </Document>
      </kml>
    XML

    result = Maps::Import::Kmz::KmlParser.call(kml: kml)

    assert_equal "Mapa KMZ", result.dig(:document, :name)
    assert_equal 2, result[:placemarks].size

    point = result[:placemarks].find { |p| p[:geometry_type] == "point" }
    assert_equal "POP Centro", point[:name]
    assert_equal(-23.55, point.dig(:coordinates, :lat))
    assert_equal(-46.63, point.dig(:coordinates, :lng))
    assert_equal "site", point.dig(:extended_data, "category")

    line = result[:placemarks].find { |p| p[:geometry_type] == "linestring" }
    assert_equal "Backbone", line[:name]
    assert_equal 3, line[:coordinates].size
    assert_equal "backbone", line.dig(:extended_data, "role")
  end

  test "ignores placemark without supported geometry" do
    kml = <<~XML
      <kml xmlns="http://www.opengis.net/kml/2.2">
        <Document>
          <Placemark>
            <name>Sem geometria suportada</name>
            <Polygon><outerBoundaryIs/></Polygon>
          </Placemark>
        </Document>
      </kml>
    XML

    result = Maps::Import::Kmz::KmlParser.call(kml: kml)
    assert_equal 0, result[:placemarks].size
  end

  test "raises domain error for invalid kml content" do
    error = assert_raises(Maps::Import::Errors::DomainError) do
      Maps::Import::Kmz::KmlParser.call(kml: "<kml><Document>")
    end

    assert_equal "import_invalid_kml", error.code
  end
end
