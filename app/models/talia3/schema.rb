# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

# Example schema
# { :properties => {
#     Talia3::N::FOAF.Person.to_s => {
#       :properties => {
#         'foaf__firstName' => {
#           :label => 'First name',
#           :type  => :string,
#           :object_type => nil
#           :cardinalty => :zero_or_one
#         }
#         'foaf__knows' => {
#           :label => 'Knows',
#           :type  => :object,
#           :object_type => Talia3::URI.new(:foaf__Person)
#           :cardinalty => :zero_or_more
#         }
#       }
#     }
#   }
#   :order => [:foaf__firstName, :foaf__knows]
# }
class Talia3::Schema
  attr_reader :type

  # @return [Array<Hash>] {<uri.short> => <uri.to_key>}
  def self.classes(strict=nil)
    strict = !Talia3.config(:loose_schema) if strict.nil?
    result = fetch_classes(view_classes_query)
    result |= fetch_classes(present_classes_query) unless strict
    result
  end
  
  def self.all_classes
    fetch_classes(all_classes_query)
  end

  ##
  # Schemas cache.
  #
  # @return [Hash]
  def self.schemas
    @schemas ||= {}
  end

  #**
  def self.for(type)
    unless type.nil?
      type = type.to_s
      return nil unless Talia3::URI.valid? type
      fetch_schema_for type
    end
    self.new type
  end

  def self.reset
    @schemas = {}
  end

  ##
  # Returns the list of cached types.
  #
  # @return [Array<String>] the cached type URI strings.
  def self.types
    schemas.keys
  end

  #**
  def self.clear
    @schemas = {}
    self
  end

  #**
  def initialize(type)
    @type = type
  end

  #**
  def schema
    self.class.schemas[@type]
  end
  alias :to_h :schema

  #**
  def property_names(view=:list, strict=true)
    names = begin
              schema[:order][:list] || []
            rescue
              []
            end
    properties.keys.each {|name| names |= [name]} unless properties.nil? or strict
    names
  end

  #**
  def properties
    begin
      schema[:properties]
    rescue
      {}
    end
  end

  #**
  def property(name)
    properties[name.to_sym]
  end

  ##
  # Returns a human readable label for a property, taking locale information in consideration.
  # 
  # If possible the label is obtained from the property schema information.
  #
  # @todo when using ontologies, the label should be taken from the property own ontology
  #   which might be different from the _resource_ ontology
  # @param [Symbol] name the property identifier
  # @param [Symbol, Array<Symbol>] language_or_locales if a symbol, returns the label for that specific locale;
  #   an array should contain a list of locales, in order of preference
  # @return [String]
  def property_label(name, language_or_locales=nil)
    begin
      labels = property(name)[:label] || {}
    rescue
      labels = {}
    end

    label = case language_or_locales
      when Symbol, String then labels[language_or_locales.to_sym] || ""
      when nil, Array then Talia3::Label.choose(labels, language_or_locales).value
    end
    
    label || (name.to_uri.respond_to?(:short) ? name.to_uri.short : name.to_uri.to_s)
  end

  ##
  # Returns a list of all defined labels for the property, ordered by locale preferences.
  #
  # @param [Symbol] name the property identifier
  # @param [Array<Symbol>] locales a list of locales, in order of preference
  # @return [Array<Talia3::Literal>]
  def property_labels(name, locales=nil)
    begin
      labels = property(name)[:label] || {}
    rescue
      labels = {}
    end
    Talia3::Label.collect labels, locales
  end

  #**
  def property_type(name)
    begin
      property(name)[:type]
    rescue
      nil
    end
  end

  #**
  def property_object_type(name)
    begin
      property(name)[:object_type]
    rescue
      nil
    end
  end

  ##
  # Returns the cardinality of a property as defined in this resource's schema.
  #
  # @param [Talia3::URI, String, Symbol] the property to check cardinality for
  # @return [Symbol, nil] one of ::zero_or_more, :zero_or_one, nil
  def property_cardinality(name)
    begin
      property(name.to_sym)[:cardinality]
    rescue
      nil
    end
  end

  #
  # ACTIVERECORD-LIKE BEHAVIOURS
  #

  ##
  # Returns the schema information in the same format as ActiveRecord#columns.
  #
  # @todo all this, better.
  def columns
    column = Struct.new(:name, :type, :limit, :default, :null, :primary)
    property_names.map do |p|
      c_type = column_type p
      c_type.nil? ? nil : column.new(p, c_type, 255, '', true, false)
    end.compact
  end

  #**
  def column_type(name)
    return nil if property_cardinality(name) != :zero_or_one

    case property_type name
      when nil then nil
      when :object then nil
      when :image then :string
      when :email then :string
      else property_type name
    end
  end

  #**
  def table_exists?
    true
  end

  #**
  def reflect_on_all_associations
    []
  end

  private
    #**
    # @todo Exception for improper values sometimes encountered.
    #   The resulting exceptions are ignored for now.
    def self.fetch_classes(query)
      Talia3.repository.query(query).map do |s|
        # FIXME: sometimes we get an exception here. Find out why.
        begin
          uri = Talia3::URI.new s.c
          Struct.new(:key, :short).new(uri.to_key, uri.short)
        rescue Exception => e
          nil
        end
      end.compact
    end

    #**
    def self.view_classes_query
      mview = Talia3::N::MVIEW
      RDF::SPARQL::Query.select(:c, :p).distinct.from(Talia3::N::CONTEXTS.ontology).
        where([:v, RDF.type, mview.ClassView]).where([:v, mview.domain, :c])
    end

    #**
    def self.present_classes_query
      mview = Talia3::N::MVIEW
      RDF::SPARQL::Query.select(:c).distinct.from(Talia3::N::CONTEXTS.public).
        where([nil, RDF.type, :c])
    end

    #**
    def self.all_classes_query
      RDF::SPARQL::Query.select(:c).distinct.from(Talia3::N::CONTEXTS.ontology).
        where([:c, :rdf__type.to_uri, :rdfs__Class.to_uri])
    end

    #**
    def self.fetch_schema_for(type)
      return true if types.include? type
      schemas[type] = 
        merge_schemas(Talia3::Schema::Ontology.schema_for(type, nil),
                      Talia3::Schema::View.schema_for(type, Talia3::N::CONTEXTS.ontology))
    end

    #**
    def self.merge_schemas(*args)
      result = {}
      merger = proc {|key,v1,v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2}
      args.each {|schema| result = result.merge(schema, &merger)}
      result
    end
  # end private
end
