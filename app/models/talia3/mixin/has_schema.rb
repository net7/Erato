# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.
##
# Implements minimum ontologies reasoning in a resource.
#
# @todo better documentation + examples.
#
# The class implementing this behaviour is expected to implement a
# #type method that returns a valid ontology type.
#
# Requires implementation of Talia3::Mixin::HasNamedGraph and
# Talia3::Mixin::HasRepositories.
#
# @see Talia3::Schema
module Talia3::Mixin::HasSchema
  ##
  # @private
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    #**
    def loose_schema
      @strict_schema = false
    end

    def strict_schema
      @strict_schema = true
    end

    def strict_schema?
      @strict_schema
    end

    def schema
      unless self.respond_to? :type
        raise Exception, "Class must implement the #type method to inherit this behaviour"
      end
      @schema ||= Talia3::Schema.for self.type 
    end
  end # module ClassMethods

  def strict_schema?
    self.class.strict_schema?
  end

  ##
  # Returns a Talia3::Schema object for the current type.
  #
  # @return [Talia3::Schema, nil] returns nil if no type is defined.
  def schema
    unless self.respond_to? :type
      raise Exception, "Object must implement the #type method to inherit this behaviour"
    end
    return self.class.schema if self.type == self.class.type
    if @schema.nil? or self.type != @schema.type
      @schema = Talia3::Schema.for self.type 
    end
    @schema
  end

  ##
  # Returns schema information about properties for the current type.
  #
  # Wrapper for {Talia3::Schema.properties}.
  #
  # @return [Hash, nil]
  def properties_schema
    schema.try(:properties) || {}
  end

  ##
  # Returns properties information on the requested property URI.
  #
  # @param [RDF::URI, String, Symbol] name
  # @return [Hash]
  # @raise ArgumentError if the argument is not a valid URI
  def property_schema(name)
    begin
      properties_schema[Talia3::URI.new(name).to_key]
    rescue
      {}
    end
  end

  delegate :property_labels, :property_label, :property_type, :property_object_type, :property_cardinality, :to => :schema

  def properties(view=:list)
    schema.try(:property_names, view, strict_schema?) || []
  end

  ##
  # Tries to reason the best way to interpret a property value given
  # a schema and the property value.
  #
  # When using loose schemas, the value currently held by a property is
  # always "right", even when it clashes with the property's schema
  # definition. 
  #
  # Schema information for resource values will be used when the
  # property is empty.
  #
  # @param [RDF::URI] the URI for the property we will interpret the value of
  # @param [Array<Statements>] The current value(s) for the property,
  #   must be an Array of RDF::Statements
  # @return [String, Array<Talia3::Resource, String>]
  # 
  # @todo TODO!!!!
  def property_value(name, current_value)
    property = Talia3::URI.new(name).to_key

    if current_value and current_value.size > 0
      reason_property_value property, current_value
    else
      reason_empty_property_value property
    end
  end

  def property_value_from(name, value)
    return nil if value.blank?
    reason_property_value_from(name, value)
  end

  private
    def reason_property_value(property, current_value)
      values = current_value.is_a?(Array) ? current_value : [current_value]
      values.map! do |value|
        case property_type(property)
          when :string then value.to_s
          when :object then Talia3::URI.new(value.to_s).to_key
          when nil then 
            return nil if strict_schema?
            reason_property_value_from_value(value)
        end
      end.compact!
      property_cardinality(property) == :zero_or_one ? values.first : values
    end

    def reason_property_value_from_value(value)
      case value
        when RDF::Literal then value.to_s
        when String then value.to_s
        when RDF::URI then Talia3::URI.new(value).to_key
        when Symbol then value
        else []
      end
    end

    def reason_empty_property_value(property)
      #**
      # HERE
      return nil if strict_schema? and property_type(property).nil?
      case property_cardinality property
        when :zero_or_one
          case property_type property
            when :string then ""
            else nil
          end
        else []
      end
      # info = property property_uri
      # (info and info[:range] == Talia3::N::RDFS.Literal.to_s) ? "" : []
    end

    def reason_property_value_from(name, value)
      property_cardinality = property_cardinality name
      property_type = property_type name

      # TODO: this is very approximate!
      #   consider strict_schema?
      #   more types!
      values = value.is_a?(Array) ? value : [value]
      values.map! do |v|
        if v.blank?
          nil
        else
          case property_type
            when :string then v.to_s
            when :object then Talia3::URI.new v
            else (v.is_a? Symbol or v.is_a? RDF::URI) ? Talia3::URI.new(v) : v.to_s
          end
        end
      end.compact!
      property_cardinality == :zero_or_one ? values.first : values
    end

    # @todo other values than String for literals?
    def single_value?(values)
      values.size == 1 and [String].include? values.first.class
    end
  # end private
end # end module Talia3::Mixin::HasOntology
