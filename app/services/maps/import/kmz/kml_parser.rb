require "nokogiri"

module Maps
  module Import
    module Kmz
      class KmlParser
        def self.call(kml:)
          new(kml: kml).call
        end

        def initialize(kml:)
          @kml = kml.to_s
        end

        def call
          raise_invalid_kml!("KML content is empty") if @kml.blank?

          document = Nokogiri::XML(@kml) { |config| config.strict.noblanks }

          {
            document: {
              name: document_name(document)
            },
            placemarks: parse_placemarks(document)
          }
        rescue Nokogiri::XML::SyntaxError => e
          raise_invalid_kml!("Invalid KML content: #{e.message}")
        end

        private

        def document_name(document)
          node = document.at_xpath("//*[local-name()='Document']/*[local-name()='name']") ||
                 document.at_xpath("//*[local-name()='kml']/*[local-name()='name']")
          node&.text&.strip
        end

        def parse_placemarks(document)
          document.xpath("//*[local-name()='Placemark']").filter_map do |placemark|
            parse_placemark(placemark)
          end
        end

        def parse_placemark(placemark)
          point_node = placemark.at_xpath("./*[local-name()='Point']/*[local-name()='coordinates']")
          line_node = placemark.at_xpath("./*[local-name()='LineString']/*[local-name()='coordinates']")

          geometry_type, coordinates = if point_node
            [ "point", parse_coordinates(point_node.text, point: true) ]
          elsif line_node
            [ "linestring", parse_coordinates(line_node.text, point: false) ]
          else
            return nil
          end

          {
            name: placemark.at_xpath("./*[local-name()='name']")&.text&.strip,
            geometry_type: geometry_type,
            coordinates: coordinates,
            extended_data: parse_extended_data(placemark)
          }
        end

        def parse_coordinates(raw, point:)
          values = raw.to_s.strip.split(/\s+/).filter_map do |tuple|
            lng, lat, alt = tuple.split(",")
            next if lng.blank? || lat.blank?

            {
              lng: lng.to_f,
              lat: lat.to_f,
              alt: alt.present? ? alt.to_f : nil
            }
          end

          point ? values.first : values
        end

        def parse_extended_data(placemark)
          data = {}

          placemark.xpath(".//*[local-name()='ExtendedData']/*[local-name()='Data']").each do |node|
            key = node["name"].to_s.strip
            next if key.blank?

            data[key] = node.at_xpath("./*[local-name()='value']")&.text&.strip
          end

          placemark.xpath(".//*[local-name()='ExtendedData']//*[local-name()='SimpleData']").each do |node|
            key = node["name"].to_s.strip
            next if key.blank?

            data[key] = node.text.to_s.strip
          end

          data
        end

        def raise_invalid_kml!(message)
          raise Maps::Import::Errors::DomainError.new(
            code: "import_invalid_kml",
            message: message,
            details: {}
          )
        end
      end
    end
  end
end
