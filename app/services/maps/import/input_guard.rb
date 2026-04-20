module Maps
  module Import
    class InputGuard
      DEFAULT_MAX_BYTES = 10.megabytes
      ALLOWED_EXTENSIONS = %w[.kmz .kml].freeze
      ALLOWED_MIME_TYPES = %w[
        application/vnd.google-earth.kmz
        application/vnd.google-earth.kml+xml
        application/octet-stream
        application/xml
        text/xml
        text/plain
      ].freeze

      class << self
        def validate!(file:, raw_input:, provider:)
          new(file: file, raw_input: raw_input, provider: provider).validate!
        end
      end

      def initialize(file:, raw_input:, provider:)
        @file = file
        @raw_input = raw_input
        @provider = provider.to_s
      end

      def validate!
        validate_presence!
        validate_size!
        validate_file_format! if file_present?
      end

      private

      attr_reader :file, :raw_input, :provider

      def validate_presence!
        return if file_present? || raw_input.present?

        raise Maps::Import::Errors::DomainError.new(
          code: "import_missing_input",
          message: "Import input is required",
          details: { accepted: %w[file input] }
        )
      end

      def validate_size!
        size = input_size
        return if size <= max_bytes

        raise Maps::Import::Errors::DomainError.new(
          code: "import_file_too_large",
          message: "Import input exceeds allowed size",
          details: { max_bytes: max_bytes, actual_bytes: size }
        )
      end

      def validate_file_format!
        extension = File.extname(file.original_filename.to_s).downcase
        if extension.present? && !ALLOWED_EXTENSIONS.include?(extension)
          raise Maps::Import::Errors::DomainError.new(
            code: "import_invalid_file_type",
            message: "Unsupported import file extension",
            details: { extension: extension, allowed_extensions: ALLOWED_EXTENSIONS, provider: provider }
          )
        end

        mime = file.respond_to?(:content_type) ? file.content_type.to_s.strip.downcase : ""
        return if mime.blank? || ALLOWED_MIME_TYPES.include?(mime)

        raise Maps::Import::Errors::DomainError.new(
          code: "import_invalid_mime_type",
          message: "Unsupported import MIME type",
          details: { mime_type: mime, allowed_mime_types: ALLOWED_MIME_TYPES, provider: provider }
        )
      end

      def file_present?
        file.present? && file.respond_to?(:original_filename)
      end

      def input_size
        return file_size if file_present?

        raw_input.to_s.bytesize
      end

      def file_size
        return file.size if file.respond_to?(:size)
        return file.tempfile.size if file.respond_to?(:tempfile) && file.tempfile.respond_to?(:size)

        0
      end

      def max_bytes
        configured = ENV["IMPORT_MAX_FILE_BYTES"].to_i
        configured.positive? ? configured : DEFAULT_MAX_BYTES
      end
    end
  end
end
