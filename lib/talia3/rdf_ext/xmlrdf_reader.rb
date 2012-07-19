# FIXME
module RDF::RDFXML
  class Reader

    def initialize(input = $stdin, options = {}, &block)
      super do
        @debug = options[:debug]
        @base_uri = uri(options[:base_uri]) if options[:base_uri]

        @doc = case input
        when Nokogiri::XML::Document then input
        else
          # Forcing UTF-8 encoding, quick fix for problems with d2rserver responses
          # in the temart project.
          Nokogiri::XML.parse(input, @base_uri.to_s, 'UTF-8') do |config|
            config.noent
          end
        end
        
        raise RDF::ReaderError, "Synax errors:\n#{@doc.errors}" if !@doc.errors.empty? && validate?
        raise RDF::ReaderError, "Empty document" if (@doc.nil? || @doc.root.nil?) && validate?

        block.call(self) if block_given?
      end
    end
  end
end
