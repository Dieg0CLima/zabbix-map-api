module Maps
  module Import
    module Providers
      class BaseAdapter
        def parse(input:)
          raise NotImplementedError
        end

        def normalize(parsed:)
          raise NotImplementedError
        end
      end
    end
  end
end
