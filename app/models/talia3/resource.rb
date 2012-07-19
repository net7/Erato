# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# = A set of statements loosely tied to a specific URI.
#
# @todo Talk about #type and Talia3::HasSchema
# @todo Talk about attribute interpretation, #[], #raw, #attributes and #
#   value.
# @todo Talk about #[]=.
#
# The resource implements Talia3::HasNamedGraph and
# Talia3::HasRepositories, which means it has both a context and one
# or more repositories. Also, any statement added to the resource will 
# have his context forced to the resource's own context.
#
# Statements can be loaded, saved and removed to/from a
# repository.
#
# *Important*: While Talia3 support RDF.rb's RDF::URI objects,
#              use of Talia3::URI should be preferred.
#
# @note Please note that this class is not Rails-friendly,
#   all ActiveModel and similar conventions are 
#   implemented in Talia3::Record.
#
# == Behaviours
#
# By default, when loaded, a resource contains
# statements which have the resource URI as either subject or object.
#
# Imagine the following triples in the repository, (ignoring contexts for now):
#   [Talia3::N::LOCAL.uri1, RDF.type, Talia3::N::EX.type1]
#   [Talia3::N::LOCAL.uri1, Talia3::N::DC.name, "name"]
#   [Talia3::N::LOCAL.uri2, RDF.type, Talia3::N::EX.type2]
#   [Talia3::N::LOCAL.uri2, Talia3::N::EX.relation, Talia3::N::LOCAL.uri1]
#
# r = Talia3::Resource.for(Talia3::N::LOCAL.uri1) would contain only the following triples:
#   [Talia3::N::LOCAL.uri1, RDF.type, Talia3::N::EX.type1]
#   [Talia3::N::LOCAL.uri1, Talia3::N::DC.name, "name"]
#   [Talia3::N::LOCAL.uri2, Talia3::N::EX.relation, Talia3::N::LOCAL.uri1]
#
# It is possible to change the loading behaviour by passing options
# either on initialization or when loading. Loading options do not
# persist, while initialization options are stored for future
# operations.
#
# The +:depth+ option allows to load more statements, including those
# related to the resource URI through another statement.
#
# With the triples of the first example in the repository:
#   r = Talia3::Resource.for(Talia3::N::LOCAL.uri1, :depth => 2)
# would return everything as the third statement is related to our
# uri through the fourth.
#
# *Note:* To avoid possible performance problems, :depth only accepts
# either 1 ora 2 as value. More will raise an exception.
#
# The +:direction+ option allows to fetch those statements that
# have the requested URI as subject only (_:right_), as object only
# (_:left_) or both (_:both_); _:both_ is the default.
#
# With the triples of the first example in the repository, the following:
#   r = Talia3::Resource.for(Talia3::N::LOCAL.uri1, :direction => :left)
# would return:
#   [Talia3::N::LOCAL.uri2, Talia3::N::EX.relation, Talia3::N::LOCAL.uri1]
# while:
#   r = Talia3::Resource.for(Talia3::N::LOCAL.uri1, :direction => :right)
# would return:
#   [Talia3::N::LOCAL.uri1, RDF.type, Talia3::N::EX.type1]
#   [Talia3::N::LOCAL.uri1, Talia3::N::DC.name, "name"]
#
# @example Create a new resource:
#   r = Talia3::Resource.new(Talia3::N::LOCAL.uri)
#
# @example Load statements for the resource from the repository:
#   r.load!
#
# @example Create and load:
#   r = Talia3::Resource.for(Talia3::N::LOCAL.uri)
#
# @example Add statemens to a resource:
#   r = Talia3::Resource.new(Talia3::N::LOCAL.uri)
#   r << [Talia3::N::LOCAL.uri1, Talia3::N::DC.description, "description"]
#
# @example Save resource statements
#   r.save!
#
# @todo Allow to change repository when saving.
#
# @example Clear resource statements:
#   r.clear
#
# @example Delete statements from repository:
#   r.delete!
#
# @example Delete statements from the repository around this resource uri:
#   Talia3::Resource.new(Talia3::N::LOCAL.uri).cleanse_uri!
#   
#   Note that this operation has nothing to do with this resource
#   current statements
#   Same as .load!(:depth => 1, :direction => :both).delete! but more efficient.
#
# @example Delete statements with our own context from the active repository:
#   Talia3::Resource.new(Talia3::N::LOCAL.uri).cleanse_context!
#   
#   Note that this operation has nothing to do with this resource
#   current statements
#
# @example Accessing resource statements:
#   r.each {|statement| puts statement.inspect}
#
# @example Accessing objects for resource URI and specific predicate:
#   r[Talia3::N::DC.name]
#   => [#<RDF::Literal:0x574f252("Example URI")>] 
class Talia3::Resource
  include Talia3::Mixin::HasNamedGraph
  include Talia3::Mixin::RDFExportable
  include Talia3::Mixin::HasRepositories
  include Talia3::Mixin::HasSchema

  ##
  # The URI for this resource.
  #
  # @return [RDF::Uri]
  attr_reader :uri

  ##
  # The options for this resource
  # @return [Hash]
  attr_reader :options

  ##
  # Default context for this class.
  # set_context :public

  ##
  # RDF Resources are loose in their schema constraints.
  loose_schema

  ##
  # Stores a default type for this class.
  #
  # Used when generating dynamic classes like Talia3::FOAF::Person.
  # @param [RDF::URI] uri
  # Moved to subclasses
  # cattr_accessor :type
  def self.type
    nil
  end

  ##
  # Quick loader, creates a new resource and loads it.
  #
  # @see Talia3::Resource#initialize
  # @param [Talia3::URI, RDF::URI]         uri           the resource URI
  # @param [Hash]                          options       new resource options
  # @option options [Array<Symbol>]        :repositories An array of repository configuration names
  # @option options [Symbol]               :repository   The repository to use as active for this resource
  # @option options [Symbol]               :context      The context for this resource
  # @option options [1,2]                  :depth        How many relations to follow when 
  #                                                      fetching statements for uri, defaults to 1
  # @option options [:right, :left, :both] :direction    When fetching statements, follow only relations where 
  #                                                      uri is the subject (:right), the object (:left) or :both
  # @return [Talia3::Resource]
  def self.for(uri, options={})
    self.new(uri, options).load!
  end

  ##
  # Creates a new resource from data acquired through a LOD URI.
  #
  # Will return an empty resource if the server response is 404 Not Found.
  #
  #
  # @todo refactor with the other import methods, using rdf.rb support.
  #   There should be only one method for this!!!
  #
  # @see Talia3::URI.fetch
  # @param [String] uri
  # @param [Integer] redirect_limit Used internally to avoid redirect loops
  # @return [Talia3::Resource]
  def self.from_lod(uri, redirect_limit = 10,escape_uri = true)
    begin
      self.new(uri).import_rdf uri.to_uri.fetch('application/rdf+xml',redirect_limit,escape_uri)
    rescue Net::HTTPServerException
      # FIXME: apparently Net::HTTP now raises only one type of exception, I'm missing somthing?
      raise if ($!.message =~ /^404 /).nil?
      return self.new(uri)
    end
  end
  
  
 
  
  ##
  # Creates a new resource from data acquired through a DESCRIBE query to a sparql endpoint.
  #
  #
  # @param  [Talia3::URI, String] sparql Sparql endpoint URL.
  # @param  [Talia3::URI, String] uri    Resource URI.
  # @return [Talia3::Resource]
  def self.from_sparql(sparql, uri)
    resource = self.new(uri)
    RDF::SPARQL::Repository.new(sparql).query("DESCRIBE <#{uri}>").each do |triple|
      resource << triple
    end
    resource
  end

  ##
  # Creates a new Resource object.
  #
  # @note uri argument is optional for test purpouses only.
  # 
  # @see self.for
  # @param [Talia3::URI, RDF::URI]           uri           the resource URI
  # @param [Hash]                            options       new resource options
  # @option options [Array<Symbol>]          :repositories An array of repository configuration names
  # @option options [Symbol]                 :repository   The repository to use as active for this resource
  # @option options [Symbol]                 :context      The context for this resource
  # @option options [1,2]                    :depth        How many relations to follow when 
  #                                                        fetching statements for uri, defaults to 1
  # @option options [:right, :left, :both]   :direction    When fetching statements, follow only relations where 
  #                                                        uri is the subject (:right), the object (:left) or :both
  # @return [Talia3::Resource]
  def initialize(uri=nil, options={})
    self.uri       = uri
    self.depth     = options.delete(:depth) || 1
    self.direction = options.delete(:direction) || :both
    self.context   = options.delete(:context) || self.class.context
    options.delete(:repositories).each {|r| add_repository r} unless options[:repositories].nil?
    use_repository options.delete(:repository)                unless options[:repository].nil?
  end

  ##
  # Returns a label for this resource.
  #
  # Will try to use rdfs:label if present, or a pretty-formatted URI.
  #
  # @return [String]
  def label
    raw(:rdfs__label).blank? ? uri.short : raw(:rdfs__label).first.to_s
  end

  ##
  # Returns a single type URI for this resource.
  #
  # Required to implement the `HasSchema` behaviour. The default
  # is the first rdf:type from the resource RDF, or Talia3::N::OWL.Thing.
  #
  # @see Talia3::HasSchema
  # @todo configurable main type
  # @return [RDF::URI, Talia3::RDF::OWL.thing]
  def type
    @type ||= self.raw(RDF.type).first || Talia3::N::OWL.Thing
    @type
  end

  ##
  # Explicitly sets the type (rdf:type) for this resource.
  #
  # @param [RDF::URI, String, nil]
  # @return [RDF::URI, String, nil] the argument in its original format
  # @raise ArgumentError if the argument is an invalid URI.
  def type=(type_uri)
    type_uri = Talia3::URI.new type_uri unless type_uri.nil?
    @type = type_uri
  end

  ##
  # Indicates whether this record is present in the store or is a new one.
  #
  # @return [Boolean]
  def persisted?
    @persisted ||= false
  end

  ##
  # Allows to change the persisted state.
  # 
  # @todo: shouldn't this be at least private?
  #
  # @param [Boolean] bool
  # @return [Boolean] the newly set value
  def persisted=(bool)
    @persisted = !!bool
  end

  ##
  # Returns the list of all properties (predicates) for this resource.
  #
  # Note that this returns only properties one step distant from the {self.uri}.
  # Predicates are converted to symbols by {Talia3::URI.to_key} before being added to the result.
  #
  # @note Does not include inverse properties
  #   (where the current resource is the object instead of the subject).
  # @ return [Array<Symbol>] The list of properties, as symbols
  def all_properties
    i = 0;
    graph.query([uri]).predicates.map do |p|
      i+=1;
      Talia3::URI.new(p).to_key
    end.compact
  end

  ##
  # Returns only "unknown" properties (those predicates we have no schema information about).
  #
  # @note Does not include inverse properties
  #   (where the current resource is the object instead of the subject).
  # @return [Array]
  def undefined_properties
    all_properties - properties 
  end

  ##
  # Returns the list of properties (predicates) that have this resource as object.
  #
  # @ return [Array<Symbol>] The list of properties, as symbols
  # @note inverse properties are not filtered by schema constraints.
  def inverse_properties
    graph.query([nil, nil, uri]).predicates.map do |p|
      Talia3::URI.new(p).to_key
    end.compact
  end

  ##
  # Interprets and returns the object of a statement given {#uri} as
  # subject and the argument as predicate.
  #
  # Results will be converted in the best way possible given the
  # resource schema and the properties' values.
  #
  # For example, Literals with language will be converted to a
  # single string choosen from the best-fitting language.
  #
  # @note For now at least, some freedom is allowed to values, so you
  # could get an array of strings and resources if the resource
  # property value is "strange".
  # 
  # @see #attribute
  # @see #raw
  #
  # @param [String, RDF::URI] predicate
  # @return [String, Array<Talia3::Resource, String>]
  # @raise [ArgumentError] if argument is not a valid URI.
  def [](predicate)
    attribute predicate
  end

  ##
  # Sets the value for a predicate.
  #
  # Replaces existing values.
  #
  # @todo support i18n: literals with different language should not
  #   be replaced if we are inserting a String literal.
  # @note This method replaces all values for the attribute.
  #
  # @see #set_attribute
  #
  # @param [RDF::URI, String, Symbol] name
  # @param  [Object] value
  # @return [Object] The value argument.
  # @raise [ArgumentError] if predicate is not a valid URI.
  def []=(name, value)
    set_attribute name, value
  end

  ##
  # Returns an attribute value given a valid attribute identifier.
  #
  # @param [RDF::URI, String, Symbol] name
  # @return [Object]
  def attribute(name)
    name = Talia3::URI.new name
    # Schema strictness issues are handled by #value
    property_value name, raw(name)
  end

  ##
  # Sets an attribute value, overwriting existing values.
  #
  # @param [RDF::URI, String, Symbol] name
  # @param [Object, Array<Object>] value
  # @return [Object] The value argument.
  def set_attribute(name, value)
    name = Talia3::URI.new name
    unless strict_schema? and not properties.include? name.to_key
      value = value.uri if value.respond_to? :uri
      value = property_value_from(name.to_key, value)
      # TODO: this should be more intelligent and less drastic.
      self - [uri, name]
      unless value.blank?
        if value.is_a?(Array)
          value.each {|v| self << [uri, name, v]}
        else
          self << [uri, name, value]
        end
      end
      value
    else
      nil
    end
  end

  ##
  # Returns values for a predicate on this resource in raw form.
  #
  # As no interpretation whatsoever is done on the values, it's
  # always assumed that there is more than one, that's why an array
  # is returned.
  #
  # @note This method always returns an array, even if there is only one object.
  # @note Given the nature of RDF terms, a single value can still
  # have more than one result, taking language in consideration, for example.
  #
  # @param [String, RDF::URI]
  # @return [Array<RDF::URI, RDF::Literal>]
  def raw(predicate)
    (graph.query([uri, Talia3::URI.new(predicate), nil]) || []).map do |statement|
      statement.object.is_a?(RDF::URI) ? Talia3::URI.new(statement.object) : statement.object
    end
  end

  ##
  # Adds a triple to the resource using its URI as *subject* and ignoring any check 
  # and schema constraints.
  #
  # @param [RDF::URI, String, Symbol] predicate
  # @param [[RDF::URI, String, Symbol]] value
  # @return [Array]
  def raw_set(predicate, value)
    graph << [uri, Talia3::URI.new(predicate), value]
  end

  ##
  # Adds a triple to the resource using its URI as *object* and ignoring any check 
  # and schema constraints.
  #
  # @param [RDF::URI, String, Symbol] predicate
  # @param [[RDF::URI, String, Symbol]] value, note that this is *always* considered 
  #   a URI and used as subject for the new triple
  # @return [Array]
  def raw_set_inverse(predicate, value)
    graph << [Talia3::URI.new(value), Talia3::URI.new(predicate), uri]
  end

  ##
  # Sets the resource URI.
  #
  # @param  [String, Talia3::URI, RDF::URI] uri a valid URI string or object
  # @return [Talia3::URI] the new URI
  # @raise  [ArgumentError] if the argument is not a valid URI.
  def uri=(uri)
    raise ArgumentError, "Cannot set URI to nil if the resource has data" unless size.zero?
    @uri = uri.nil? ? nil : Talia3::URI.new(uri)
  end

  ##
  # Sets the +:depth+ option.
  #
  # @param [Number] depth
  # @return the argument
  # @raise [ArgumentError] if argument is not an integer
  # @raise [Exception] if argument > 2 (for efficiency reasons)
  def depth=(depth)
    check_depth depth
    (@options ||= {})[:depth] = depth
    depth
  end

  ##
  # Sets the +:direction+ option
  #
  # @param [:right, :left, :both]
  # @return the argument    
  # @raise [ArgumentError] if argument is unexpected value
  def direction=(direction)
    check_direction direction
    (@options ||= {})[:direction] = direction
    direction
  end

  ##
  # Loads statements from the active repository.
  #
  # Accepts new values for +:repository+, +:depth+ and +:direction+,
  # that will be used for this operation only. 
  #
  # @note you cannot change context from here... too risky.
  # @option options [Symbol]               :repository   The repository to use as active for this resource
  # @option options [1,2]                  :depth        How many relations to follow when 
  #                                                      fetching statements for uri, defaults to 1
  # @option options [:right, :left, :both] :direction    When fetching statements, follow only relations where 
  # @return [Talia3::Resource] self (chainable)
  # @raise [Exception] if the resource has no URI set
  # @raise [Exception] if no repository is active or indicated in options
  def load!(options={})
    raise Exception, "No uri specified for resource" if uri.nil?
    check_options options
    # If a repository is indicated, it will be used for this operation only.
    old_repository = repository
    use_repository options.delete(:repository) unless options[:repository].nil?
    options.reject! {|key, value| ![:repository, :depth, :direction].include?(key)}
    options = self.options.merge options
    raise Exception, "Cannot load, no repository chosen" if repository.nil?

    clear_graph
    query = load_query(options)

    repository.query(query).each do |statement|
      graph << statement
    end
    repository = old_repository
    self.persisted = true
    self
  end

  ##
  # Saves the statements in the active repository.
  #
  # @note Saving a resource removes all triples from the store first.
  #   This means that of all triples with the resource's URI only
  #   the ones present in the resource itself at the time of saving
  #   will remain.
  #
  # @return [Talia3::Resource] self (chainable)
  # @raise [Exception] if no repository is active
  # @raise [Exception] if repository is read-only
  def save!
    raise Exception, "Cannot load, no repository chosen" if repository.nil?
    # Make sure type is saved as a triple too.
    graph << [uri, RDF.type, type]
    cleanse_uri!
    save_graph! repository
    persisted = true
    self
  end
  alias_method :update!, :save!

  ##
  # Deletes statements from the active repository that correspond to
  # this resource's statements.
  #
  # @note Does not clear local statements.
  #
  # @return [Talia3::Resource] self (chainable)
  # @raise [Exception] if no repository is active
  # @raise [Exception] if repository is read-only
  def delete!
    raise Exception, "Cannot delete, no repository chosen" if repository.nil?
    delete_from_repository! repository
  end

  ##                                                                
  # Returns a developer-friendly representation of this object.     
  #                                                                 
  # @return [String]                                                
  def inspect
    sprintf("#<%s:%#0x(%s)>", self.class.name, __id__, uri.to_s)
  end

  private
  ##
  # Prepares a RDF::Query object to load statements for this resource.
  #
  # @private
  # @param [Hash] options temporary options for load operation
  # @return [RDF::Query]
  def load_query(options)
    query = RDF::Query.new
    unless options[:direction] == :left
      (1..options[:depth]).each do |step|
        s = (step == 1) ? uri : "o1_#{step - 1}".to_sym
        p = "p1_#{step}".to_sym
        o = "o1_#{step}".to_sym
        query << RDF::Query::Pattern.new(s, p, o, :optional => (step != 1), :context => context)
      end
    end
    unless options[:direction] == :right
      (1..options[:depth]).each do |step|
        s = "s2_#{step}".to_sym
        p = "p2_#{step}".to_sym
        o = (step == 1) ? uri : "s2_#{step - 1}".to_sym
        query << RDF::Query::Pattern.new(s, p, o, :optional => (step != options[:depth]), :context => context)
      end
    end
    query
  end

  ##
  # Raises an exception if an option has invalid value.
  #
  # @private
  # @param  [Hash] options  The options to check
  # @return [nil] ignored
  # @raise  [ArgumentError] if +:depth+ is not an integer
  # @raise  [Exception]     if +:depth+ > 2 (for efficiency reasons)
  # @raise  [ArgumentError] if +:direction+ is an unexpected value
  def check_options(options)
    check_depth     options[:depth]     unless options[:depth].nil?
    check_direction options[:direction] unless options[:direction].nil?
  end

  ##
  # Raises an exception if the argument is an invalid value for :depth.
  #
  # @private
  # @param  depth
  # @return [nil] ignored
  # @raise  [ArgumentError] if +:depth+ is not an integer
  # @raise  [Exception]     if +:depth+ > 2 (for efficiency reasons)
  def check_depth(depth)
    raise ArgumentError, ":depth option must be an Integer." unless depth.is_a? Integer
    if depth > 2
      raise Exception, "More than two depth untested and not recommended. Rescue me if you want to try anyway (good luck...)"
    end
  end

  ##
  # Raises an exception if the argument is an invalid value for +:direction+.
  #
  # @private
  # @param  direction
  # @return [nil] ignored
  # @raise  [ArgumentError] if :direction is an unexpected value
  def check_direction(direction)
    unless direction == :left or direction == :right or direction == :both
      raise ArgumentError, ":direction option must be one of :left, :right or :both."
    end
  end
  # end private
end # class Talia3::Resource
