require "open3"
require "tempfile"

module Maps
  module Import
    module Kmz
      class ArchiveReader
        def self.call(input:)
          new(input: input).call
        end

        def initialize(input:)
          @input = input
        end

        def call
          raw, filename, input_path = read_binary_input
          raise_invalid_input!("Import input is empty") if raw.blank?

          if kmz_archive?(raw, filename)
            extract_from_kmz(raw: raw, input_path: input_path)
          else
            {
              kml: raw.force_encoding("UTF-8"),
              source_format: "kml",
              entry_name: nil
            }
          end
        end

        private

        def read_binary_input
          if @input.respond_to?(:tempfile) && @input.tempfile.respond_to?(:read)
            tempfile = @input.tempfile
            tempfile.rewind if tempfile.respond_to?(:rewind)
            return [ tempfile.read.to_s, @input.original_filename.to_s, tempfile.path ]
          end
          return [ File.binread(@input), File.basename(@input), @input ] if @input.is_a?(String) && File.file?(@input)
          return [ @input.read.to_s, nil, nil ] if @input.respond_to?(:read)

          [ @input.to_s, nil, nil ]
        end

        def kmz_archive?(raw, filename)
          filename = filename.to_s.downcase
          filename.end_with?(".kmz") || raw.start_with?("PK\x03\x04".b)
        end

        def extract_from_kmz(raw:, input_path:)
          archive_path, owned_tempfile = materialize_archive_path(raw: raw, input_path: input_path)
          entries_output, entries_status = Open3.capture2("unzip", "-Z1", archive_path)
          raise_invalid_input!("Invalid KMZ archive") unless entries_status.success?

          entries = entries_output.lines.map(&:strip).reject(&:blank?)
          entry_name = entries.find { |entry| entry.downcase == "doc.kml" } ||
                       entries.find { |entry| entry.downcase.end_with?(".kml") }
          raise_missing_kml! if entry_name.blank?

          kml_content, kml_status = Open3.capture2("unzip", "-p", archive_path, entry_name)
          raise_invalid_input!("Unable to read KML from KMZ archive") unless kml_status.success?

          {
            kml: kml_content.to_s.force_encoding("UTF-8"),
            source_format: "kmz",
            entry_name: entry_name
          }
        ensure
          owned_tempfile&.close!
        end

        def raise_missing_kml!
          raise Maps::Import::Errors::DomainError.new(
            code: "import_kmz_missing_kml",
            message: "KMZ archive does not contain a KML document",
            details: {}
          )
        end

        def raise_invalid_input!(message)
          raise Maps::Import::Errors::DomainError.new(
            code: "import_invalid_input",
            message: message,
            details: {}
          )
        end

        def materialize_archive_path(raw:, input_path:)
          return [ input_path, nil ] if input_path.present?

          tempfile = Tempfile.new([ "kmz-import", ".kmz" ])
          tempfile.binmode
          tempfile.write(raw)
          tempfile.rewind

          [ tempfile.path, tempfile ]
        end
      end
    end
  end
end
