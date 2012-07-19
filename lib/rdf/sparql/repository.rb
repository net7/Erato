module RDF::SPARQL
  ##
  # A read-only repository view of a SPARQL endpoint.
  #
  # @see RDF::Repository
  class Repository < RDF::Repository

    # @return [RDF::SPARQL::Client]
    attr_reader :client

    ##
    # BY RIK: made more compatible with RDF::Repository
    # TODO: are options ever even used?
    # @overload initialize(url)
    #   @param  [String, RDF::URI] url
    #   @yield  [repository]
    #   @yieldparam [Repository]
    #
    # @overload initialize(options = {})
    #   @param  [Hash{Symbol => Object}] options
    #   @option options [Server] :server (nil)
    #   @option options [String] :id (nil)
    #   @option options [String] :title (nil)
    #   @yield  [repository]
    #   @yieldparam [Repository]
    def initialize(url_or_options, &block)
      if url_or_options.is_a? Hash
        @options = url_or_options.dup
        @client = RDF::SPARQL::Client.new(@options.delete(:endpoint), options)
      else
        unless url_or_options.is_a? String or url_or_options.is_a? RDF::URI
          raise ArgumentError, "expected String, RDF::URI or Hash, but got #{url_or_options.inspect}"
        end
        @client = RDF::SPARQL::Client.new(url_or_options, options)
        @options = {}
      end

      if block_given?
        case block.arity
        when 1 then block.call(self)
        else instance_eval(&block)
        end
      end
    end

    ##
    # Returns `false` to indicate that this is a read-only repository.
    #
    # @return [Boolean]
    # @see    RDF::Mutable#mutable?
    def writable?
      false
    end

    ##
    # @private
    # @see RDF::Repository#supports?
    def supports?(feature)
      case feature.to_sym
        when :context then true # statement contexts / named graphs
        when :sparql then true # BY RIK, supports sparql queries
        else super
      end
    end

    ##
    # @private
    # @see RDF::Enumerable#each_statement
    # @see http://www.openrdf.org/doc/sesame2/system/ch08.html#d0e304
    def each_statement(&block)
      return enum_statement unless block_given?
      # Client will raise his own exceptions if there is an error.
      results = client.query "SELECT DISTINCT * WHERE {{?s ?p ?o} UNION {GRAPH ?g {?s ?p ?o}}}"
      results.each do |result|
        block.call RDF::Statement.new result.s, result.p, result.o, :context => result[:g]
      end
    end
    alias_method :each, :each_statement

    ##
    # Returns `true` if this repository contains the given subject.
    #
    # @param  [RDF::Resource]
    # @return [Boolean]
    # @see    RDF::Repository#has_subject?
    def has_subject?(subject)
      client.ask.whether([subject, :p, :o]).true?
    end

    ##
    # Returns `true` if this repository contains the given predicate.
    #
    # @param  [RDF::URI]
    # @return [Boolean]
    # @see    RDF::Repository#has_predicate?
    def has_predicate?(predicate)
      client.ask.whether([:s, predicate, :o]).true?
    end

    ##
    # TODO: context? (Not in original...)
    # Returns `true` if this repository contains the given object.
    #
    # @param  [RDF::Value]
    # @return [Boolean]
    # @see    RDF::Repository#has_object?
    def has_object?(object)
      client.ask.whether([:s, :p, object]).true?
    end

    ##
    # @private
    # @see RDF::Enumerable#has_context?
    def has_context?(context)
      client.ask.whether([:s, :p, :o, context]).true?
    end

    ##
    # TODO: context? (Not in original...)
    # Iterates over each subject in this repository.
    #
    # @yield  [subject]
    # @yieldparam [RDF::Resource] subject
    # @return [Enumerator]
    # @see    RDF::Repository#each_subject?
    def each_subject(&block)
      unless block_given?
        RDF::Enumerator.new(self, :each_subject)
      else
        client.select(:s).distinct.where([:s, :p, :o]).execute.each { |solution| block.call(solution[:s]) }
      end
    end

    ##
    # TODO: context? (Not in original...)
    # Iterates over each predicate in this repository.
    #
    # @yield  [predicate]
    # @yieldparam [RDF::URI] predicate
    # @return [Enumerator]
    # @see    RDF::Repository#each_predicate?
    def each_predicate(&block)
      unless block_given?
        RDF::Enumerator.new(self, :each_predicate)
      else
        client.select(:p).distinct.where([:s, :p, :o]).execute.each { |solution| block.call(solution[:p]) }
      end
    end

    ##
    # TODO: context? (Not in original...)
    # Iterates over each object in this repository.
    #
    # @yield  [object]
    # @yieldparam [RDF::Value] object
    # @return [Enumerator]
    # @see    RDF::Repository#each_object?
    def each_object(&block)
      unless block_given?
        RDF::Enumerator.new(self, :each_object)
      else
        client.select(:o).distinct.where([:s, :p, :o]).execute.each { |solution| block.call(solution[:o]) }
      end
    end

    ##
    # @private
    # @see RDF::Enumerable#each_context
    def each_context(&block)
      return enum_context unless block_given?
      require 'json' unless defined?(::JSON)
      # Client will raise his own exceptions if there is an error.
      client.query("SELECT DISTINCT ?g WHERE{GRAPH ?g{?s ?p ?o}}").each do |result|
        block.call result.g
      end
    end

    ##
    # Returns `true` if this repository contains the given `triple`.
    #
    # @param  [Array<RDF::Resource, RDF::URI, RDF::Value>] triple
    # @return [Boolean]
    # @see    RDF::Repository#has_triple?
    def has_triple?(triple)
      client.ask.whether(triple.to_a[0...3]).true?
    end

    ##
    # Returns `true` if this repository contains the given `statement`.
    #
    # @param  [RDF::Statement] statement
    # @return [Boolean]
    # @see    RDF::Repository#has_statement?
    # @see RDF::Enumerable#has_quad?
    def has_statement?(statement)
      client.ask.whether(statement).true?
    end
    alias_method :has_quad?, :has_statement?

    ##
    # TODO: maybe contextes should be factored in?
    # Returns the number of statements in this repository.
    #
    # @return [Integer]
    # @see    RDF::Repository#count?
    def count
      begin
        binding = client.query("SELECT COUNT(*) WHERE { ?s ?p ?o }").first.to_hash
        binding[binding.keys.first].value.to_i
      rescue RDF::SPARQL::Client::MalformedQuery => e
        # SPARQL 1.0 does not include support for aggregate functions:
        count = 0
        each_statement { count += 1 } # TODO: optimize this
        count
      end
    end

    alias_method :size,   :count
    alias_method :length, :count

    ##
    # Returns `true` if this repository contains no statements.
    #
    # @return [Boolean]
    # @see    RDF::Repository#empty?
    def empty?
      client.ask.whether([:s, :p, :o]).false?
    end

    ##
    # @see RDF::Queryable#Query
    # Note that this method is compatible with RDF::Queryable#query but also supports
    # additional features (sparql queries directly as String or represented by a 
    # RDF::SPARQL::Query object). Rememeber to always check if the repository #supports?(:sparql)
    # before using the additional features.
    def query(pattern, &block)
      raise TypeError, "#{self} is not readable" if respond_to?(:readable?) && !readable?
      return enum_for(:query, pattern).extend(RDF::Queryable, RDF::Enumerable) unless block_given?

      # Allow for direct SPARQL queries:
      sparql = pattern.is_a?(String) ? pattern : RDF::SPARQL::Query.from(pattern)

      results = client.query(sparql.to_s)
      results = [results] unless results.respond_to? :each
      results.each do |result|
        block.call result
      end
    end

  end # class Repository
end # module RDF::SPARQL
