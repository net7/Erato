# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# Talia3 namespace utilities.
#
# Talia3 namespaces are a simple way to write uris.
# Namespaces include all those defined by RDF with RDF::Vocabulary
# except for rdf itself. 
#
# Results are always a Talia3::URI.
# 
# @note: the main difference between RDF.rb vocabularies and Talia3
#   namespaces is that vocabularies represent uris from OWL or RDFS
#   definitions, and can have additional features related to that
#   characteristic. Namespaces work on a different context, they are
#   there to help when using uris in general and should simpler.
#   Also: you cannot use #name for vocabularies (RDF::DC.name =>
#   "RDF::DC").
#
# @note: I found the ex namespace is used a lot in examples, so I
#   added it to the predefined namespaces. Useful in tests.
#
# @example Getting a list of defined namespaces with their prefix:
#   Talia3::N.namespaces
#   => {:ex=>"http://example.org/", ...}
#
# @example Adding a new namespace:
#   Talia3::N.namespaces << {:ns => "http://ns.example.org/"}
#   => {:ex=>"http://example.org/", ...}
#
# @example Generate a uri for http://example.org/uri (ex:uri)
#   Talia3::N::EX.uri
#
# @example Generate a uri for dc:name
#   Talia3::N::DC.name
#
# @example Generate a uri for rdf:type:
#   Talia3::N::RDF.type
#
# It is possible to create special namespaces that have some specific
# behaviour. Predefined namespace include Talia3::N::LOCAL and
# Talia3::N::CONTEXTS which use some information from the Talia3
# configuration file to generate their uris. You can use those classes'
# code as reference to create others.
#
# Talia3::N::LOCAL uses Talia3.config(:base_uri) to generate
# uris for the application resources.
#
# @example Generate a local uri
#   Talia3::LOCAL.uri.to_s
#   => "http://localhost:3000/uri"
#
# Talia3::N::CONTEXTS uses Talia3.config(:contexts) to generate
# uris for contexts. Predefined contexts include "public" and
# "ontology". Any non defined context defaults to
# Talia3::N::LOCAL.#{"/contexts/<context>"}.
#
# @example Generate our uri for a public context:
#   Talia3::CONTEXT.public.to_s
#   => "http://localhost:3000/contexts/public"
#
# @example Define a new base for ontology context and generate:
#   In config/talia3.yml:
#   contexts:
#     ontology: http://mycontexts.example.org/
#
#   Talia3::N::CONTEXTS.ontology.to_s
#   => "http://mycontexts.example.org/ontology"
#
# @todo Add prefix recognition from uris to get the short form, e.g:
#   "http://example.org/uri" => "ex:uri"
class Talia3::N
  # Predefined namespaces
  @@namespaces = {
    # Use RDF vocabulary for rdf namespace
    :ex     => 'http://example.org/',
    :mview  => 'http://purl.org/net7/vocab/muruca-view/',
    :t3view => 'http://purl.org/net7/talia3/views/',
    :rdf    => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    :cs     => 'http://purl.org/vocab/changeset/schema#',
    :talia  => 'http://purl.org/net7/vocab/talia/',
    :schema => 'http://schema.org/',
    :sicart => 'http://purl.org/sicart/vocab/v1.0#',
    :gn     => 'http://geonames.org/ontology#',
    :owl    => 'http://www.w3.org/2002/07/owl#'
  }

  # Add all RDF vocabularies to @@namespaces except for RDF
  ::RDF::Vocabulary.each do |v|
    @@namespaces[v.__prefix__] = v.to_s unless v.name == "RDF"
  end

  ##
  # Returns the defined namespaces with their prefixes.
  #
  # @note Does not include "special" namespaces like
  #   Talia3::N::LOCAL.
  # @return [Hash]
  def self.namespaces
    @@namespaces
  end

  ##
  # Returns the namespace prefix for the argument URI, if possible.
  #
  # @param [String, RDF::URI] uri
  # @return [String]
  def self.prefix(uri)
    @@namespaces.each_pair do |namespace, base_uri|
      return namespace.to_s if uri.to_s.include? base_uri
    end
    ""
  end

  def self.namespace(uri)
    @@namespaces.each_pair do |namespace, base_uri|
      return base_uri if uri.to_s.include? base_uri
    end
    ""
  end

  ##
  # Returns the local name part of the URI.
  #
  # @param [String, RDF::URI] uri
  # @return [String]
  def self.local_name(uri)
    @@namespaces.each_pair do |prefix, base_uri|
      return uri.to_s.gsub(base_uri, "") if uri.to_s.include? base_uri
    end
    ""
  end

  ##
  # Returns true if the argument is a defined namespace.
  #
  # The argument will be converted to a namespace symbol
  # (i.e. :rdf) if possible.
  #
  # @param [Symbol, RDF::URI, String] a valid namespace
  #   representation (e.g.: :foaf, "http://xmlns.com/foaf/0.1/")
  def self.namespace?(namespace)
    case namespace
      when Symbol then namespaces.keys.include? namespace
      else namespaces.values.include? namespace.to_s
    end
  end

  ##
  # Adds a new namespace.
  #
  # @param [Hash]
  # @option namespace [String] :prefix
  #
  # @return [Class] self (chainable)
  # @raise [ArgumentError] For invalid namespace information
  def self.<<(namespace)
    unless namespace.is_a? Hash
      raise ArgumentError, "Namespace must be a {:prefix => \"base uri\"} Hash"
    end
    namespace.each_pair do |prefix, uri|
      @@namespaces[prefix.to_sym] = uri.to_s
    end
    self
  end

  private 
  ##
  # Interprets a constant as a namespace prefix and returns the
  # corresponding Talia3::Namespace object.
  #
  # Automatically called by Ruby if an unknown constant is used.
  #
  # @private
  # @param [String] namespace the missing constant/requested namespace
  # @return Talia3::Namespace
  # @raise [NameError] For unknown namespaces
  def self.const_missing(namespace)
    symbol = namespace.to_s.downcase.to_sym
    klass  = "Talia3::Namespace::#{namespace.to_s.upcase}"
    if namespace? symbol
      begin
        return klass.constantize.new
      rescue
        uri = @@namespaces[symbol]
        return Talia3::Namespace.new symbol, uri unless uri.nil?
      end
    end
    raise NameError, "uninitialized constant Talia3::#{namespace}"
  end
  # end private
end # Class Talia3::N

##
# Generates uris for a namespace.
#
# Probably never used directly, objects of this class are returned
# by {Talia3::N#const_missing}.
#
# By calling, for example, Talia3::N::DC.name the what happens is:
# {Talia3::N#const_missing} returns a Talia3::Namespace object, to
# which #name is applied. #methods_missing is then called, finishing
# the magic.
#
# @note Note most methods of this class are disabled to allow to use
# them to generate uris.
class Talia3::Namespace

  ##
  # Returns an array of RDF types that should not be considered user data, as they are used internally
  # or to define ontology information.
  #
  # @todo this should probably be configurable.
  # @todo right place?
  #
  # @return [Array<Talia3::URI>]
  def self.internal_types
    # Note that Talia3::N::RDFS and Talia3::N::OWL have some additional handling for untyped resources.
    [Talia3::N::RDFS, Talia3::N::OWL, Talia3::N::RDF, Talia3::N::Talia.Ontology]
  end

  ##
  # Initializes a namespace.
  # @param [Symbol] namespace prefix
  # @param [String] namespace base uri
  # @return [Talia3::Namespace]
  def initialize(prefix, uri_s)
    @prefix = prefix
    @uri    = ::Talia3::URI.new uri_s
  end
  # Keep a way to ask for this object's class
  alias_method :__class__, :class

  # Undefine all superfluous instance methods so they can be used to
  # generate more uris.
  undef_method(*(instance_methods.map(&:to_sym) - [:__id__, :__send__, :__class__, :__eval__, :object_id, :is_a?, :inspect]))

  def uri_for(local_name)
    ::Talia3::URI.new(to_s + local_name.to_s)
  end

  ##
  # Returns the namespace base uri as a string.
  #
  # @return [String]
  def to_s
    @uri.to_s
  end

  ##
  # Returns a developer-friendly representation of this namespace.
  #
  # @return [String]
  def inspect
    sprintf("#<%s:%#0x(%s)>", self.__class__.name, __id__, to_s)
  end

  ##
  # Interprets a method call as a request for a new uri for this namespace.
  # 
  # Automatically called by Ruby if an unknown method is used.
  #
  # @param [String] the method name/uri final part
  # @param [Array] must be empty
  # @yieldreturn [void] ignored
  # return [Talia3::URI] the final uri
  def method_missing(property, *args, &block)
    raise ArgumentError.new("Wrong number of arguments (#{args.size} for 0)") unless args.empty?
    uri_for property
  end

  ##
  # Registers a new namespace with {Talia3::N}
  #
  # @note Use when creating custom namespace classes.
  # @param [Symbol] prefix
  # @param [RDF::URI, String] uri
  # return [nil]
  def self.register(prefix, uri)
    Talia3::N << {prefix.to_sym => uri.to_s}
    nil
  end

  ##
  # Overwritten to stop Ruby constant searching here.
  #
  # By Ruby default if a constant is not found, this is called, then
  # *any const_missing method for nested classes/modules above this
  # one is also called*. This breaks the code when
  # Talia3.const_missing is called, as there is some special code in there.
  #
  # @private
  def self.const_missing(const)
    raise NameError, "uninitialized constant Talia3::Namespace::#{const}"
  end
end # class Talia3::Namespace

Talia3::N::const_set "RDF", Talia3::Namespace.new(:rdf, Talia3::N.namespaces[:rdf])
# Add all custom namespaces.
Dir[File.join(File.dirname(__FILE__), "namespace", "**", "*.rb")].each {|f| require f}
