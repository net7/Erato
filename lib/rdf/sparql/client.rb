require 'net/http'
require 'rdf' # @see http://rubygems.org/gems/rdf
require 'rdf/ntriples'

module RDF::SPARQL
  ##
  # A SPARQL client for RDF.rb.
  #
  # @see http://www.w3.org/TR/rdf-sparql-protocol/
  # @see http://www.w3.org/TR/rdf-sparql-json-res/
  class Client
    class ClientError < StandardError; end
    class MalformedQuery < ClientError; end
    class ServerError < StandardError; end

    RESULT_BOOL      = 'text/boolean'.freeze # Sesame-specific
    RESULT_JSON      = 'application/sparql-results+json'.freeze
    RESULT_JSON_UTF8 = 'application/sparql-results+json;charset=UTF-8'.freeze
    RESULT_XML       = 'application/sparql-results+xml'.freeze
    RESULT_XML_UTF8  = 'application/sparql-results+xml;charset=UTF-8'.freeze

    ACCEPT_JSON = {'Accept' => RESULT_JSON}.freeze
    ACCEPT_XML  = {'Accept' => RESULT_XML}.freeze

    attr_reader :url
    attr_reader :options

    ##
    # @param  [String, #to_s]          url
    # @param  [Hash{Symbol => Object}] options
    def initialize(url, options = {}, &block)
      @url, @options = RDF::URI.new(url.to_s), options
      @headers = {
        'Accept' => "#{RESULT_JSON_UTF8}, #{RESULT_XML_UTF8}, #{RESULT_JSON}, #{RESULT_XML}," + 
          RDF::Format.content_types.map {|k,v| k.to_s}.join(', ')
      }
      if block_given?
        case block.arity
          when 1 then block.call(self)
          else instance_eval(&block)
        end
      end
    end

    ##
    # Executes a boolean `ASK` query.
    #
    # @return [Query]
    def ask(*args)
      call_query_method(:ask, *args)
    end

    ##
    # Executes a tuple `SELECT` query.
    #
    # @param  [Array<Symbol>] variables
    # @return [Query]
    def select(*args)
      call_query_method(:select, *args)
    end

    ##
    # Executes a `DESCRIBE` query.
    #
    # @param  [Array<Symbol, RDF::URI>] variables
    # @return [Query]
    def describe(*args)
      call_query_method(:describe, *args)
    end

    ##
    # Executes a graph `CONSTRUCT` query.
    #
    # @param  [Array<Symbol>] pattern
    # @return [Query]
    def construct(*args)
      call_query_method(:construct, *args)
    end

    ##
    # @private
    def call_query_method(meth, *args)
      client = self
      result = Query.send(meth, *args)
      (class << result; self; end).send(:define_method, :execute) do
        client.query(self)
      end
      result
    end

    ##
    # Executes a SPARQL query.
    #
    # @param  [String, #to_s]          url
    # @param  [Hash{Symbol => Object}] options
    # @option options [String] :content_type
    # @return [Array<RDF::Query::Solution>]
    def query(query, options = {})
      @headers['Accept'] = options[:content_type] if options[:content_type]

      get(query) do |response|
        case response
          when Net::HTTPBadRequest  # 400 Bad Request
            raise MalformedQuery.new(response.body)
          when Net::HTTPClientError # 4xx
            raise ClientError.new(response.body)
          when Net::HTTPServerError # 5xx
            raise ServerError.new(response.body)
          when Net::HTTPSuccess     # 2xx
            parse_response(response, options)
        end
      end
    end

    ##
    # @param  [Net::HTTPSuccess] response
    # @param  [Hash{Symbol => Object}] options
    # @return [Object]
    def parse_response(response, options = {})
      content_type = options[:content_type] || response.content_type
      case content_type = options[:content_type] || response.content_type
        when RESULT_BOOL # Sesame-specific
          response.body == 'true'
        when RESULT_JSON, RESULT_JSON_UTF8
          parse_json_bindings(response.body)
        when RESULT_XML, RESULT_XML_UTF8
          parse_xml_bindings(response.body)
        else
          parse_rdf_serialization(response, options)
      end
    end

    ##
    # @param  [String, Hash] json
    # @return [Enumerable<RDF::Query::Solution>]
    # @see    http://www.w3.org/TR/rdf-sparql-json-res/#results
    def parse_json_bindings(json)
      require 'json' unless defined?(::JSON)
      json = JSON.parse(json.to_s) unless json.is_a?(Hash)
      case
        when json['boolean']
          json['boolean']
        when json['results']
          json['results']['bindings'].map do |row|
            row = row.inject({}) do |cols, (name, value)|
              cols.merge(name.to_sym => parse_json_value(value))
            end
            RDF::Query::Solution.new(row)
          end
      end
    end

    ##
    # @param  [Hash{String => String}] value
    # @return [RDF::Value]
    # @see    http://www.w3.org/TR/rdf-sparql-json-res/#variable-binding-results
    def parse_json_value(value)
      case value['type'].to_sym
        when :bnode
          @nodes ||= {}
          @nodes[id = value['value']] ||= RDF::Node.new(id)
        when :uri
          RDF::URI.new(value['value'])
        when :literal
          RDF::Literal.new(value['value'], :language => value['xml:lang'])
        when :'typed-literal'
          RDF::Literal.new(value['value'], :datatype => value['datatype'])
        else nil
      end
    end

    ##
    # @param  [String, REXML::Element] xml
    # @return [Enumerable<RDF::Query::Solution>]
    # @see    http://www.w3.org/TR/rdf-sparql-json-res/#results
    def parse_xml_bindings(xml)
      xml.force_encoding(encoding) if xml.respond_to?(:force_encoding)
      require 'rexml/document' unless defined?(::REXML::Document)
      xml = REXML::Document.new(xml).root unless xml.is_a?(REXML::Element)

      case
        when boolean = xml.elements['boolean']
          boolean.text == 'true'
        when results = xml.elements['results']
          results.elements.map do |result|
            row = {}
            result.elements.each do |binding|
              name  = binding.attributes['name'].to_sym
              value = binding.select { |node| node.kind_of?(::REXML::Element) }.first
              row[name] = parse_xml_value(value)
            end
            RDF::Query::Solution.new(row)
          end
      end
    end

    ##
    # @param  [REXML::Element] value
    # @return [RDF::Value]
    # @see    http://www.w3.org/TR/rdf-sparql-json-res/#variable-binding-results
    def parse_xml_value(value)
      case value.name.to_sym
        when :bnode
          @nodes ||= {}
          @nodes[id = value.text] ||= RDF::Node.new(id)
        when :uri
          RDF::URI.new(value.text)
        when :literal
          RDF::Literal.new(value.text, {
            :language => value.attributes['xml:lang'],
            :datatype => value.attributes['datatype'],
          })
        else nil
      end
    end

    ##
    # @param  [Net::HTTPSuccess] response
    # @param  [Hash{Symbol => Object}] options
    # @return [RDF::Enumerable]
    def parse_rdf_serialization(response, options = {})
      options = {:content_type => response.content_type} if options.empty?
      if reader = RDF::Reader.for(options)
        reader.new(response.body)
      end
    end

    ##
    # @return [Encoding]
    def encoding
      @encoding ||= ::Encoding::UTF_8
    end

    ##
    # Outputs a developer-friendly representation of this object to `stderr`.
    #
    # @return [void]
    def inspect!
      warn(inspect)
    end

    ##
    # Returns a developer-friendly representation of this object.
    #
    # @return [String]
    def inspect
      sprintf("#<%s:%#0x(%s)>", self.class.name, __id__, url.to_s)
    end

    protected

    ##
    # Returns an HTTP class or HTTP proxy class based on environment http_proxy & https_proxy settings
    # @return [Net::HTTP::Proxy]
    def http_klass(scheme)
      proxy_uri = nil
      case scheme
        when "http"
          proxy_uri = URI.parse(ENV['http_proxy']) unless ENV['http_proxy'].nil?
        when "https"
          proxy_uri = URI.parse(ENV['https_proxy']) unless ENV['https_proxy'].nil?
      end
      return Net::HTTP if proxy_uri.nil? 

      proxy_host, proxy_port = proxy_uri.host, proxy_uri.port
      proxy_user, proxy_pass = proxy_uri.userinfo.split(/:/) if proxy_uri.userinfo
      Net::HTTP::Proxy(proxy_host, proxy_port, proxy_user, proxy_pass)
    end

    ##
    # Performs an HTTP GET request against the SPARQL endpoint.
    # 
    # @param  [String, #to_s]          query
    # @param  [Hash{String => String}] headers
    # @yield  [response]
    # @yieldparam [Net::HTTPResponse] response
    # @return [Net::HTTPResponse]
    def get(query, headers = {}, &block)
      url = self.url.dup
      url.query_values = {:query => query.to_s}
      http_klass(url.scheme).start(url.host, url.port) do |http|
        response = http.get(url.path + "?#{url.query}", @headers.merge(headers))

        if block_given?
          block.call(response)
        else
          response
        end
      end
    end
  end # class Client
end # module RDF::SPARQL
