require 'rdf/sparql/repository'
require 'pathname' unless defined?(Pathname)
module RDF
  module Sesame
    ##
    # TODO: change examples to reflect new server url logic.
    # A repository on a Sesame 2.0-compatible HTTP server.
    #
    # Instances of this class represent RDF repositories on Sesame-compatible
    # servers.
    #
    # This class implements the [`RDF::Repository`][RDF::Repository]
    # interface; refer to the relevant RDF.rb API documentation for further
    # usage instructions.
    #
    # [RDF::Repository]: http://rdf.rubyforge.org/RDF/Repository.html
    #
    # @example Opening a Sesame repository (1)
    #   url = "http://localhost:8080/openrdf-sesame/repositories/SYSTEM"
    #   repository = RDF::Sesame::Repository.new(url)
    #
    # @example Opening a Sesame repository (2)
    #   server = RDF::Sesame::Server.new("http://localhost:8080/openrdf-sesame")
    #   repository = RDF::Sesame::Repository.new(:server => server, :id => :SYSTEM)
    #
    # @example Opening a Sesame repository (3)
    #   server = RDF::Sesame::Server.new("http://localhost:8080/openrdf-sesame")
    #   repository = server.repository(:SYSTEM)
    #
    # @see http://www.openrdf.org/doc/sesame2/system/ch08.html
    # @see http://rdf.rubyforge.org/RDF/Repository.html
    class Repository < RDF::SPARQL::Repository
      # @return [RDF::URI]
      attr_reader  :url
      alias_method :uri, :url

      # @return [String]
      attr_reader :id

      # @return [Server]
      attr_reader :server

      ##
      # Initializes this `Repository` instance.
      #
      # BY RIK: pretty big change: #server now gets the full repository url, 
      # instead of the server url; this is needed to make it compatibile 
      # with RDF::SPARQL::Client.
      # 
      # @overload initialize(url)
      #   @param  [String, RDF::URI] url
      #   @yield  [repository]
      #   @yieldparam [Repository]
      #
      # @overload initialize(options = {})
      #   @param  [Hash{Symbol => Object}] options
      #   @option options [Server] :server (nil)
      #   @option options [String] :title (nil)
      #   @yield  [repository]
      #   @yieldparam [Repository]
      #
      def initialize(url_or_options, &block)
        case url_or_options
        when String
          initialize(RDF::URI.new(url_or_options), &block)

        when RDF::URI
          @options = {}
          @server  = Server.new(url_or_options)
          @uri     = url_or_options

        when Hash
          @options = url_or_options.dup
          @server  = @options.delete(:server)
          @uri     = @options.delete(:uri) || server.url
        else
          raise ArgumentError, "expected String, RDF::URI or Hash, but got #{url_or_options.inspect}"
        end

        if block_given?
          case block.arity
            when 1 then block.call(self)
            else instance_eval(&block)
          end
        end
      end
      
      ##
      # For compatibility with RDF::SPARQL::Repository
      def client
        @server
      end

      def id
        Pathname.new(@uri.path).basename
      end

      ##
      # Sesame repositories are writable.
      # TODO: always writable?
      # @return [Boolean]
      # @see    RDF::Mutable#mutable?
      def writable?
        true
      end

      ##
      # @private
      # @see RDF::Repository#supports?
      def supports?(feature)
        super
      end

      ##
      # Returns the URL for the given repository-relative `path`.
      #
      # @param  [String, #to_s]        path
      # @param  [Hash, RDF::Statement] query
      # @return [RDF::URI]
      def url(path = nil, query = {})
        url = path ? RDF::URI.new("#{@uri}/#{path}") : @uri.dup # FIXME
        unless query.nil?
          case query
          when RDF::Statement
            writer = RDF::NTriples::Writer.new
            query  = {
              :subj    => writer.format_value(query.subject),
              :pred    => writer.format_value(query.predicate),
              :obj     => writer.format_value(query.object),
              :context => query.has_context? ? writer.format_value(query.context) : 'null',
            }
            url.query_values = query
          when Hash
            url.query_values = query unless query.empty?
          end
        end
        return url
      end
      alias_method :uri, :url

      ##
      # @private
      # @see RDF::Durable#durable?
      def durable?
        true # TODO: would need to query the SYSTEM repository for this information
      end
      
      ##
      # @private
      # FIXME: for repository types with inference this is different from
      #        counting all triples, as Sesame silently adds more than a hundred 
      #        triples on its own _which are NOT counted by /size_.
      # @see RDF::Countable#count
      # @see http://www.openrdf.org/doc/sesame2/system/ch08.html#d0e569
      def count
        server.get(url(:size)) do |response|
          case response
            when Net::HTTPSuccess
              size = response.body
              size.to_i rescue 0
            else -1 # FIXME: raise error
          end
        end
      end
      alias_method :size, :count

      ##
      # @private
      # @see RDF::Enumerable#has_triple?
      def has_triple?(triple)
        has_statement?(RDF::Statement.from(triple))
      end

      ##
      # @private
      # @see RDF::Enumerable#has_quad?
      def has_quad?(quad)
        has_statement?(RDF::Statement.new(quad[0], quad[1], quad[2], :context => quad[3]))
      end

      ##
      # @private
      # @see RDF::Enumerable#has_statement?
      # @see http://www.openrdf.org/doc/sesame2/system/ch08.html#d0e304
      def has_statement?(statement)
        server.get(url(:statements, statement), 'Accept' => 'text/plain') do |response|
          case response
          when Net::HTTPSuccess
            !response.body.empty?
          else false
          end
        end
      end

      ##
      # @private
      # @see RDF::Enumerable#each_statement
      # @see http://www.openrdf.org/doc/sesame2/system/ch08.html#d0e304
      def each_statement(&block)
        return enum_statement unless block_given?
        [nil, *enum_context].uniq.each do |context|
          ctxt = context ? RDF::NTriples.serialize(context) : 'null'
          server.get(url(:statements, :context => ctxt), 'Accept' => 'text/plain') do |response|
            case response
            when Net::HTTPSuccess
              reader = RDF::NTriples::Reader.new(response.body)
              reader.each_statement do |statement|
                statement.context = context
                block.call(statement)
              end
            end
          end
        end
      end

      alias_method :each, :each_statement

      ##
      # @private
      # @see RDF::Enumerable#each_context
      def each_context(&block)
        return enum_context unless block_given?

        require 'json' unless defined?(::JSON)
        server.get(url(:contexts), Server::ACCEPT_JSON) do |response|
          case response
          when Net::HTTPSuccess
            json = ::JSON.parse(response.body)
            json['results']['bindings'].map { |binding| binding['contextID'] }.each do |context_id|
              context = case context_id['type'].to_s.to_sym
                when :bnode then RDF::Node.new(context_id['value'])
                when :uri   then RDF::URI.new(context_id['value'])
              end
              block.call(context) if context
            end
          end
        end
      end

      ##
      # BY RIK
      # Allow for sesame bulk delete if we get patterns. 
      # @see RDF::Mutable#delete
      def delete(*statements)
        raise TypeError.new("#{self} is immutable") if immutable?
        statements.map! do |value|
          case
            when value.respond_to?(:each_statement)
              delete_statements(value)
              nil
            when pattern_variable?(pattern = RDF::Query::Pattern.from(value))
              delete_pattern pattern
              nil
            when (statement = RDF::Statement.from(value)).valid?
              statement
            else raise ArgumentError, "Cannot treat argument #{value.class} as a statement or set of statements"
          end
        end
        statements.compact!
        delete_statements(statements) unless statements.empty?

        return self
      end

      protected

      ##
      # @private
      # @see RDF::Writable#insert_statements
      def insert_statements(statements)
        contexts = {}
        # Group statements by context
        statements.each do |s|
          (contexts[s.context] ||= []) << s.to_triple
        end
        contexts.each do |c, ss|
          # Create a ntriples string for this context
          payload = RDF::Writer.for(:ntriples).buffer do |writer|
            ss.each do |s|
              writer << s
            end
          end
          context = c.nil? ? 'null' : RDF::NTriples.serialize(c)
          headers = {'Content-type' => 'text/plain'}

          # PUT to sesame for bulk insert.
          response = server.post url(:statements, :context => context), payload, headers
          unless response.is_a? Net::HTTPNoContent
            raise Exception, "Could not save all, got a #{response.class.name}: #{response.body}" 
          end
        end
        true
      end

      ##
      # @private
      # @see RDF::Mutable#insert
      # @see http://www.openrdf.org/doc/sesame2/system/ch08.html#d0e304
      def insert_statement(statement)
        ctxt = statement.has_context? ? RDF::NTriples.serialize(statement.context) : 'null'
        data = RDF::NTriples.serialize(statement)
        server.post(url(:statements, :context => ctxt), data, 'Content-Type' => 'text/plain') do |response|
          case response
            when Net::HTTPSuccess then true
            else false
          end
        end
      end

      ##
      # BY RIK
      def delete_pattern(pattern)
        pattern = RDF::Query::Pattern.from pattern
        return delete_statement pattern if pattern.constant? 
        query = {
          :context => pattern.has_context? ? RDF::NTriples.serialize(pattern.context) : 'null'
        }
        variables = pattern.variable_terms
        query[:subj] = RDF::NTriples.serialize(pattern.subject)   unless variables.include? :subject   or pattern.subject.nil?
        query[:pred] = RDF::NTriples.serialize(pattern.predicate) unless variables.include? :predicate or pattern.predicate.nil?
        query[:obj]  = RDF::NTriples.serialize(pattern.object)    unless variables.include? :object    or pattern.object.nil?

        response = server.delete url(:statements, query)
      end

      ##
      # @private
      # @see RDF::Mutable#delete
      # @see http://www.openrdf.org/doc/sesame2/system/ch08.html#d0e304
      def delete_statement(statement)
        server.delete(url(:statements, statement)) do |response|
          case response
            when Net::HTTPSuccess then true
            else false
          end
        end
      end

      ##
      # @private
      # @see RDF::Mutable#clear
      # @see http://www.openrdf.org/doc/sesame2/system/ch08.html#d0e304
      def clear_statements
        server.delete(url(:statements)) do |response|
          case response
            when Net::HTTPSuccess then true
            else false
          end
        end
      end

      ##
      # BY RIK
      # Correcting what I think is a mistake in RDF::Query::Pattern#variable?.
      # Context.nil? should not be considered a variable.
      def pattern_variable?(pattern)
        pattern.subject.nil? || pattern.predicate.nil? || pattern.object.nil? || pattern.has_variables?
      end

    end #End class Repository
  end #End module RDF::Sesame
end #End module RDF
