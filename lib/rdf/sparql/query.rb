module RDF::SPARQL
  ##
  # A SPARQL query builder.
  #
  # @example Iterating over all found solutions
  #   query.each_solution { |solution| puts solution.inspect }
  #
  class Query < RDF::Query
    ##
    # @return [Symbol]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#QueryForms
    attr_reader :form

    ##
    # @return [Hash{Symbol => Object}]
    attr_reader :options

    ##
    # @return [Array<[key, RDF::Value]>]
    attr_reader :values

    ##
    # BY RIK
    # transforms a RDF::Query or RDF::Query::Pattern in a RDF::SPARQL::Query
    # Note: unless pattern is already a RDF::SPARQL::Query, this will always
    # return a construct query.
    def self.from(pattern)
      case pattern
        # A SPARQL query:
        when RDF::SPARQL::Query then pattern
        # A basic graph pattern (BGP):
        when RDF::Query
          result = self.new(:construct)
          pattern.patterns.each do |query_pattern|
            query_pattern = clean_pattern query_pattern
            (result.options[:template] ||= []) << query_pattern
            result.where query_pattern
          end
          result
          # A simple triple/quad pattern query:
        else
          pattern = RDF::Query::Pattern.from pattern
          pattern = clean_pattern pattern
          self.construct(pattern).where pattern
      end
    end

    ##
    # Creates a boolean `ASK` query.
    #
    # @param  [Hash{Symbol => Object}] options
    # @return [Query]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#ask
    def self.ask(options = {})
      self.new(:ask, options)
    end

    ##
    # Creates a tuple `SELECT` query.
    #
    # @param  [Array<Symbol>]          variables
    # @param  [Hash{Symbol => Object}] options
    # @return [Query]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#select
    def self.select(*variables)
      options = variables.last.is_a?(Hash) ? variables.pop : {}
      self.new(:select, options).select(*variables)
    end

    ##
    # Creates a `DESCRIBE` query.
    #
    # @param  [Array<Symbol, RDF::URI>] variables
    # @param  [Hash{Symbol => Object}]  options
    # @return [Query]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#describe
    def self.describe(*variables)
      options = variables.last.is_a?(Hash) ? variables.pop : {}
      self.new(:describe, options).describe(*variables)
    end

    ##
    # Creates a graph `CONSTRUCT` query.
    #
    # @param  [Array<RDF::Query::Pattern, Array>] patterns
    # @param  [Hash{Symbol => Object}]            options
    # @return [Query]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#construct
    def self.construct(*patterns)
      options = patterns.last.is_a?(Hash) ? patterns.pop : {}
      self.new(:construct, options).construct(*patterns) # FIXME
    end

    ##
    # @param  [Symbol, #to_s]          form
    # @param  [Hash{Symbol => Object}] options
    # @yield  [query]
    # @yieldparam [Query]
    def initialize(form = :ask, options = {}, &block)
      @form = form.respond_to?(:to_sym) ? form.to_sym : form.to_s.to_sym
      super(options.dup, &block)
    end

    ##
    # @see RDF::Query#<<
    def <<(pattern)
      @patterns << self.class.clean_pattern(Pattern.from(pattern))
      self
    end

    ##
    # @return [Query]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#ask
    def ask
      @form = :ask
      self
    end

    ##
    # @param  [Array<Symbol>] variables
    # @return [Query]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#select
    def select(*variables)
      @values = variables.map { |var| [var, RDF::Query::Variable.new(var)] }
      self
    end

    ##
    # @param  [Array<Symbol>] variables
    # @return [Query]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#describe
    def describe(*variables)
      @values = variables.map { |var|
        [var, var.is_a?(RDF::URI) ? var : RDF::Query::Variable.new(var)]
      }
      self
    end

    ##
    # @param  [Array<RDF::Query::Pattern, Array>] patterns
    # @return [Query]
    def construct(*patterns)
      options[:template] = build_patterns(patterns)
      self
    end

    # @param RDF::URI uri
    # @return [Query]
    # @see http://www.w3.org/TR/rdf-sparql-query/#specDataset
    def from(uri)
      options[:from] = uri
      self
    end

    ##
    # @param  [Array<RDF::Query::Pattern, Array>] patterns
    # @return [Query]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#GraphPattern
    def where(*patterns)
      @patterns += build_patterns(patterns)
      self
    end
    alias_method :whether, :where

    ##
    # @param  [Array<Symbol, String>] variables
    # @return [Query]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#modOrderBy
    def order(*variables)
      options[:order_by] = variables
      self
    end

    alias_method :order_by, :order

    ##
    # @return [Query]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#modDistinct
    def distinct(state = true)
      options[:distinct] = state
      self
    end

    ##
    # @return [Query]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#modReduced
    def reduced(state = true)
      options[:reduced] = state
      self
    end

    ##
    # @param  [Integer, #to_i] start
    # @return [Query]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#modOffset
    def offset(start)
      slice(start, nil)
    end

    ##
    # @param  [Integer, #to_i] length
    # @return [Query]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#modResultLimit
    def limit(length)
      slice(nil, length)
    end

    ##
    # @param  [Integer, #to_i] start
    # @param  [Integer, #to_i] length
    # @return [Query]
    def slice(start, length)
      options[:offset] = start.to_i if start
      options[:limit] = length.to_i if length
      self
    end

    ##
    # @return [Query]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#prefNames
    def prefix(string)
      (options[:prefixes] ||= []) << string
      self
    end

    ##
    # @return [Query]
    # @see    http://www.w3.org/TR/rdf-sparql-query/#optionals
    def optional(*patterns)
      # (options[:optionals] ||= []) << build_patterns(patterns)
      # BY RIK
      @patterns += build_patterns(patterns).map do |pattern|
        pattern.options[:optional] = true
        pattern
      end
      self
    end

    ##
    # @private
    def build_patterns(patterns)
      patterns.map do |pattern|
        pattern = case pattern
          when RDF::Query::Pattern then pattern
          else RDF::Query::Pattern.from(pattern)
        end
        self.class.clean_pattern pattern
      end
    end

    ##
    # @private
    def filter(string)
      (options[:filters] ||= []) << string
      self
    end

    ##
    # @return [Boolean]
    def true?
      case result
        when TrueClass, FalseClass then result
        when Enumerable then !result.empty?
        else false
      end
    end

    ##
    # @return [Boolean]
    def false?
      !true?
    end

    ##
    # @return [Enumerable<RDF::Query::Solution>]
    def solutions
      result
    end

    ##
    # @yield  [statement]
    # @yieldparam [RDF::Statement]
    # @return [Enumerator]
    def each_statement(&block)
      result.each_statement(&block)
    end

    ##
    # @return [Object]
    def result
      @result ||= execute
    end

    ##
    # @return [Object]
    def execute
      raise NotImplementedError
    end

    ##
    # BY RIK: changed to allow for contexts, optional patterns and advanced pattern querying.
    # Returns the string representation of this query.
    #
    # @return [String]
    def to_s
      buffer = [form.to_s.upcase]
      case form
        when :select, :describe
          buffer << 'DISTINCT' if options[:distinct]
          buffer << 'REDUCED'  if options[:reduced]
          buffer << (values.empty? ? '*' : values.map { |v| serialize_value(v[1]) }.join(' '))
        when :construct
          templates = serialize_patterns(options[:template], false)
          # Special case: if template contained only patterns with blank nodes,
          # then there is nothing here. Adding a default template to avoid an error.
          templates = ['?_s', '?_p', '?_o'] if templates.empty?
          buffer << '{'
          buffer += templates
          buffer << '}'
      end
      buffer << "FROM #{serialize_value(options[:from])}" if options[:from]

      unless patterns.empty?
        buffer << 'WHERE {'
        buffer << where_clause
        
        if options[:filters]
          buffer += options[:filters].map { |filter| "FILTER(#{filter})" }
        end
        buffer << '}'
      end

      if options[:order_by]
        buffer << 'ORDER BY'
        buffer += options[:order_by].map { |var| var.is_a?(String) ? var : "?#{var}" }
      end

      buffer << "OFFSET #{options[:offset]}" if options[:offset]
      buffer << "LIMIT #{options[:limit]}"   if options[:limit]
      options[:prefixes].reverse.each {|e| buffer.unshift("PREFIX #{e}") } if options[:prefixes]

      buffer.join(' ')
    end

    ## 
    # BY RIK
    # Prepare patterns for WHERE clause, using UNION when necessary.
    def where_clause
      return serialize_patterns(patterns, true) if form == :select
      groups = group_patterns
      return serialize_patterns(groups.values.first, true) if groups.count <= 1
      groups.values.map {|patterns| "{#{serialize_patterns(patterns, true).join(' ')}}"}.join ' UNION '
    end

    ## 
    # BY RIK
    # Divides patterns in groups that have variables in common.
    # The result will be used in #where_clause to build UNION clauses.
    # FIXME: does not really work...
    def group_patterns
      groups = {}
      patterns.each do |pattern|
        unless pattern.has_variables?
          (groups[[]] ||= []) << pattern
        else
          variables = pattern.variables.keys
          found = false
          groups.each_key {|keys| found = keys unless (keys & variables).empty?}
          if found
            groups[variables | found] = (groups.delete(found) << pattern)
          else
            groups[variables] = [pattern]
          end
        end
      end
      groups.dup.each_pair do |keys, patterns|
        if keys != [] and patterns.count == 1
          (groups[[]] ||= []).concat groups.delete(keys)
        end
      end
    end

    ##
    # BY RIK: added optional? and context handling, 
    # new option allows not to use them 
    # (e.g.: for construct templates).
    # @private
    def serialize_patterns(patterns, extended=false)
      return [] if patterns.nil? or patterns.empty?
      patterns.map do |p|
        # No blank nodes in CONSTRUCT clause.
        unless p.has_blank_nodes? and !extended
          serialized = p.to_triple.map { |v| serialize_value(v) }.join(' ') + " ."
          if extended
            serialized = "OPTIONAL {#{serialized}} ." if p.optional?
            unless p.context.nil?
              graph = p.context.is_a?(Symbol)? "?#{p.context.to_s}" : "<#{p.context}>"
              serialized = "GRAPH #{graph} {#{serialized}} ."
            end
          end
          serialized
        end
      end.compact
    end

    ##
    # Outputs a developer-friendly representation of this query to `stderr`.
    #
    # @return [void]
    def inspect!
      warn(inspect)
      self
    end

    ##
    # Returns a developer-friendly representation of this query.
    #
    # @return [String]
    def inspect
      sprintf("#<%s:%#0x(%s)>", self.class.name, __id__, to_s)
    end

    ##
    # Serializes an RDF::Value into a format appropriate for select, construct, and where clauses
    #
    # @param  [RDF::Value]
    # @return [String]
    # @private
    def serialize_value(value)
      # SPARQL queries are UTF-8, but support ASCII-style Unicode escapes, so
      # the N-Triples serializer is fine unless it's a variable:
      value = RDF::Query::Variable.new if value.nil?
      case
        when value.variable? then value.to_s
        else RDF::NTriples.serialize(value)
      end
    end

    def self.clean_pattern(pattern)
      pattern.subject   ||= RDF::Query::Variable.new
      pattern.predicate ||= RDF::Query::Variable.new
      pattern.object    ||= RDF::Query::Variable.new
      pattern
    end

  end # class Query
end # module RDF::SPARQL
