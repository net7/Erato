require 'rdf/sparql/client'
module RDF::Sesame
  ##
  # TODO: change examples to reflect new server url logic.
  # A server endpoint compatible with the Sesame 2.0 HTTP protocol.
  #
  # Instances of this class represent Sesame-compatible servers that contain
  # one or more readable and/or writable RDF {Repository repositories}.
  #
  # @example Connecting to a Sesame server
  #   url    = RDF::URI("http://localhost:8080/openrdf-sesame")
  #   server = RDF::Sesame::Server.new(url)
  #
  # @example Retrieving the server's protocol version
  #   server.protocol                 #=> 4
  #
  # @example Iterating over available RDF repositories
  #   server.each_repository do |repository|
  #     puts repository.inspect
  #   end
  #
  # @example Finding all readable, non-empty RDF repositories
  #   server.find_all do |repository|
  #     repository.readable? && !repository.empty?
  #   end
  #
  # @example Checking if any RDF repositories are writable
  #   server.any? { |repository| repository.writable? }
  #
  # @example Checking if a specific RDF repository exists on the server
  #   server.has_repository?(:SYSTEM) #=> true
  #   server.has_repository?(:foobar) #=> false
  #
  # @example Obtaining a specific RDF repository
  #   server.repository(:SYSTEM)      #=> RDF::Sesame::Repository(SYSTEM)
  #   server[:SYSTEM]                 #=> RDF::Sesame::Repository(SYSTEM)
  #
  # @see http://www.openrdf.org/doc/sesame2/system/ch08.html
  class Server < RDF::SPARQL::Client

    ACCEPT_BOOL = {'Accept' => 'text/boolean'}
    ACCEPT_TEXT = {'Accept' => 'text/plain'}

    # @return [RDF::URI]
    attr_reader :url

    # @return [RDF::URI]
    attr_reader :repository_url

    # @return [Hash{Symbol => Object}]
    attr_reader :options

    # @return [Connection]
    attr_reader :connection

    ##
    # Initializes this `Server` instance.
    #
    # BY RIK: pretty big change: #server now gets the full repository url, 
    # instead of the server url; this is needed to make it compatibile 
    # with RDF::SPARQL::Client.
    #
    # @param  [RDF::URI]               url
    # @param  [Hash{Symbol => Object}] options
    # @option options [Connection] :connection (nil)
    # @yield  [connection]
    # @yieldparam [Server]
    def initialize(url, options = {}, &block)
      require 'addressable/uri' unless defined?(Addressable)
      @repository_url = url
      @url = RDF::URI.new(Pathname.new(url.to_s).parent.parent.to_s)

      @connection = options.delete(:connection) || Connection.new(@url)
      @options    = options

      if block_given?
        case block.arity
          when 1 then block.call(self)
          else instance_eval(&block)
        end
      end
    end

    ##
    # Returns the URL for the given server-relative `path`.
    #
    # BY RIK: pretty big change: #server now gets the full repository url, 
    # instead of the server url; this method returns the old-style server url, 
    # 
    # @example Getting a Sesame server's URL
    #   server.url            #=> RDF::URI("http://localhost:8080/openrdf-sesame")
    #
    # @example Getting a Sesame server's protocol URL
    #   server.url(:protocol) #=> RDF::URI("http://localhost:8080/openrdf-sesame/protocol")
    #
    # @param  [String, #to_s] path
    # @return [RDF::URI]
    def url(path = nil)
      path ? RDF::URI.new("#{@url}/#{path}") : @url # FIXME
    end

    alias_method :uri, :url

    ##
    # Returns the URL of this server.
    #
    # @return [RDF::URI]
    def to_uri
      url
    end

    ##
    # Returns the URL of this server as a string.
    #
    # @return [String]
    def to_s
      url.to_s
    end

    ##
    # Returns a developer-friendly representation of this instance.
    #
    # @return [String]
    def inspect
      sprintf("#<%s:%#0x(%s)>", self.class.name, object_id, to_s)
    end

    ##
    # Returns the Sesame server's protocol version.
    #
    # @example Retrieving the protocol version
    #   server.protocol #=> 4
    #
    # @return [Integer]
    # @see    http://www.openrdf.org/doc/sesame2/system/ch08.html#d0e180
    def protocol
      get(url(:protocol)) do |response|
        case response
          when Net::HTTPSuccess
            version = response.body
            version.to_i rescue 0
          else 0
        end
      end
    end

    alias_method :protocol_version, :protocol

    ##
    # Enumerates over each repository on this Sesame server.
    #
    # @yield  [repository]
    # @yieldparam [Repository] repository
    # @return [Enumerator]
    # @see    #repository
    # @see    #repositories
    def each_repository(&block)
      repositories.values.each(&block)
    end

    alias_method :each, :each_repository

    ##
    # Returns `true` if this server has a repository identified by `id`.
    #
    # @param  [String] id
    # @return [Boolean]
    def has_repository?(id)
      repositories.has_key?(id.to_s)
    end

    ##
    # Returns a repository on this Sesame server.
    #
    # @param  [String] id
    # @return [Repository]
    # @see    #repositories
    # @see    #each_repository
    def repository(id)
      repositories[id.to_s]
    end

    alias_method :[], :repository

    ##
    # Returns all repositories on this Sesame server.
    #
    # @return [Hash{String => Repository}]
    # @see    #repository
    # @see    #each_repository
    # @see    http://www.openrdf.org/doc/sesame2/system/ch08.html#d0e204
    def repositories
      require 'json' unless defined?(::JSON)
      get(url(:repositories), ACCEPT_JSON) do |response|
        case response
          when Net::HTTPSuccess
            json = ::JSON.parse(response.body)
            json['results']['bindings'].inject({}) do |repositories, binding|
              repository = Repository.new({
                :server   => self,
                :uri      => (uri   = RDF::URI.new(binding['uri']['value'])),
                :id       => (id    = binding['id']['value']),
                :title    => (title = binding['title']['value']),
                :readable => binding['readable']['value'].to_s == 'true',
                :writable => binding['writable']['value'].to_s == 'true',
              })
              repositories.merge({id => repository})
            end
          else [] # FIXME
        end
      end
    end

    ##
    # Executes a SPARQL query.
    # Rewritten to use Sesame-specific connection.
    #
    # @see RDF::SPARQL::Client#query
    def query(query, options = {})
      headers['Accept'] = options[:content_type] if options[:content_type]
      url = @repository_url.dup
      url.query_values = {:query => query.to_s}
      headers = {'Accept' => "#{RESULT_JSON}, #{RESULT_XML}, text/plain"}
      get(url, headers) do |response|
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

    def get(path, headers = {}, &block) # @private
      self.connection.open do
        self.connection.get(path, headers, &block)
      end
    end

    def post(path, data, headers = {}, &block) # @private
      self.connection.open do
        self.connection.post(path, data, headers, &block)
      end
    end

    def put(path, data, headers={}, &block)
      self.connection.open do
        self.connection.put(path, data, headers, &block)
      end
    end

    def delete(path, headers = {}, &block) # @private
      self.connection.open do
        self.connection.delete(path, headers, &block)
      end
    end
  end # class Server
end # module RDF::Sesame
