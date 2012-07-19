module Talia3
  module ResourceHelper

    include Talia3Helper

    ##
    # @param [Array<Talia3::URI>] namespaces
    # @param [Array<#to_uri>] *property_lists
    def talia3_regroup_properties(namespaces, *property_lists)
      first_group = extract_with_namespaces! namespaces, *property_lists
      group_by_namespace! *property_lists
      [first_group, *property_lists]
    end

    ##
    # Returns a good label representation for a resource attribute.
    #
    # @param [Talia3::Resource] resource
    # @param [#to_uri] property
    # @return [String] the choosen label
    def talia3_resource_property_label(resource, property)
      talia3_main_label property.to_uri, resource.property_labels(property)
    end # talia3_resource_property_label

    ##
    # Renders a good label presentation for a URI.
    #
    # This method expects labels to be returned by Talia3Helper.talia3_uri_labels.
    # That helper already takes care of i18n-related issues.
    #
    # @param [Talia3::URI] uri
    # @param [Array<Struct>] labels optional structures as defined in Talia3Helper.talia3_uri_labels;
    #   Will use that method if this is omitted.
    # @return [String] the choosen label
    def talia3_main_label(uri, labels=nil)
      labels ||= talia3_uri_labels(uri)
      label = labels.empty? ? talia3_uri_fallback_label(uri) : labels.first.value
      label.size < 51 ? label : "#{label[0..20]} ... #{label[-30..-1]}"
    end # talia3_format_label

    ##
    # Last ditch effort to create a human-readable label for a URI.
    #
    # Uses the result of Talia3::URI.local_name if possible, otherwise tries some regexp magic.
    # The full URI is returned if everything else fails.
    #
    # @param [Talia3::URI] uri
    # @return [String]
    def talia3_uri_fallback_label(uri)
      uri = Talia3::URI.new uri
      uri.local_name unless uri.local_name.blank?
      # This regexp identifies the local name part of a URI string.
      /[\/#]([^\/#]+)$/ =~ uri.to_s ? $~[1].capitalize : uri.to_s
    end

    ##
    # Renders a HTML select control for the "nature" (URI or literal) of a RDF statement's object.
    #
    # @param [String, Symbol, RDF::URI] predicate the statement's predicate. Can be nil.
    # @param [RDF::Literal, RDF:URI] object the statement's object
    # @param [Hash] options options for either the resulting select input tag or the method itself:
    #   @option options [:uri, :literal] :force locks the control to one of the two types. The control is also hidden.
    #   @option options [String, Symbol] :name input tag name
    #   @option options [String, Symbol] :selected
    # @return [String]
    def talia3_literal_uri_selection(predicate, object, options={})
      o = options.dup.to_options!
      force  = o.delete(:force) if o[:force].present?
      name   = o.delete(:name) || "record[#{predicate}][][uri_literal]"
      values = [['Literal', 'literal'], ['URI', 'uri']]

      begin
        object_type = object.present? ? (object.try(:literal?) ? 'literal' : 'uri') : nil
        selected = force || object_type.presence || o.delete(:selected).presence || 'uri'
      rescue
        selected = 'uri'
      end

      o = {
        :id           => nil,
        :class        => "record_attribute_type #{(force.present?) ? 'hidden' : ''}",
        #:disabled     => (not force.nil?),
        :"data-value" => selected.to_s
      }.merge o

      select_tag name, options_for_select(values, selected.to_s), o
    end # def literal_uri_selection_for

    ##
    # Renders the HTML elements needed to choose a datatype for literal values. Includes a text field for custom datatypes.
    #
    # @param [String, Symbol, RDF::URI] predicate the statement's predicate. Can be nil.
    # @param [RDF::Literal, RDF:URI] object the statement's object
    # @param [Hash] options options for either the resulting select input tag or the method itself:
    #   @option options [String, Symbol] :name intput tag name for the main datatype selection control.
    #   @option options [String, Symbol] :custom_name intput tag name for the custom datatype specification control.
    #   @option options [String, Symbol] :default default datatype for a nil value.
    #   @option options [:literal, :uri] :force forces the controls to always behave like the value is a literal or URI.
    #   @option options [String, #to_s]  :selected forces the datatype to the requested value, unless :force == 'uri'
    #   @option options [String, Symbol] :hide_all forces both controls to start hidden.
    #   @option options [String, Symbol] :disable_all forces both controls to start disabled.
    # @param [Hash] custom_options options for the custom datatype textarea
    # @return [String]
    def talia3_datatype_selection(predicate, object, options={}, custom_options={})
      o = options.dup.to_options!
      force, hide_all, disable_all = o.delete(:force), o.delete(:selected), o.delete(:hide_all), o.delete( :disable_all)
      name, custom_name = (o.delete(:name) || "record[#{predicate}][][datatype]").to_s,
                          (o.delete(:custom_name) || "record[#{predicate}][][datatype_custom]").to_s

      selected = o.delete(:selected).to_s if o[:selected].present?

      datatype = case object
                   when RDF::Literal then object.datatype.to_s
                   when RDF::URI then nil
                   when Talia3::URI then nil
                   else
                     if force == :uri
                       nil
                     else
                       selected.presence || o.delete(:default).presence || ""
                     end
                 end

      if not datatype.blank? and datatypes_list.find_index {|e| e[1] == datatype}.nil?
        custom_datatype, datatype = datatype, :custom
      else
        custom_datatype = nil
      end

      o = {
        :id => nil,
        :class => "record_attribute_datatype  #{( hide_all || force == :uri || datatype.nil?) ? 'hidden' : ''}",
        :"data-value" => datatype,
        :hidden => hide_all || force == :uri || datatype.nil?,
        :disabled => disable_all
      }.merge o

      result = select_tag name, options_for_select(datatypes_list), o

      o = {
        :id => nil,
        :class => "record_attribute_datatype_custom #{(hide_all || force == :uri || custom_datatype.nil?) ? 'hidden' : ''}",
        :"data-value" => custom_datatype,
        :hidden => hide_all || force == :uri || custom_datatype.nil?,
        :disabled => disable_all
      }.merge custom_options

      result << text_field_tag(custom_name, custom_datatype, o)
    end # def datatype_selection_for

    ##
    # Renders the HTML elements needed to choose a language for literal values.
    #
    # @todo document!
    #
    # @todo implement and replace in partials.
    def talia3_language_selection(predicate, object, type)
      select_tag "record[#{predicate}][][language]", options_for_select(languages_list, object.to_s.presence), {
        :class => "record_attribute_language #{(type!="literal") ? 'hidden' : ''}",
        :"data-value" => object.to_s
      }
    end

    private

      ##
      # List of predefined datatypes and their label in options_for_select format.
      #
      # @see http://www.w3.org/TR/2001/REC-xmlschema-2-20010502/#built-in-primitive-datatypes for a good starting list.
      # @return [Array<Array<String>>]
      def languages_list
        [[nil, 'none']] + Talia3::locales.map do |lang|
          [lang, lang] unless lang == :none
        end.compact
      end

      ##
      # List of predefined datatypes and their label in options_for_select format.
      #
      # @see http://www.w3.org/TR/2001/REC-xmlschema-2-20010502/#built-in-primitive-datatypes for a good starting list.
      # @return [Array<Array<String>>]
      def datatypes_list
        [
         ["string",    ""  ],
         ["integer",   "#{Talia3::N::XSD}int"     ],
         ["date",      "#{Talia3::N::XSD}date"     ],
         ["date/time", "#{Talia3::N::XSD}dateTime" ],
         ["decimal",   "#{Talia3::N::XSD}decimal" ],
         ["float",     "#{Talia3::N::XSD}float"   ],
         ["boolean",   "#{Talia3::N::XSD}boolean" ],
         ["double",    "#{Talia3::N::XSD}double"  ],
         ["custom",    "custom"                   ]
        ]
      end

      def extract_with_namespaces!(namespaces, *property_lists)
        [].tap do |extracted|
          namespaces.each do |namespace|
            property_lists.each do |candidates|
              candidates.dup.each do |candidate|

                extracted << candidates.delete(candidate) if candidate.to_s.starts_with?(namespace.to_s)

              end # candidates.each
            end # property_lists.each
          end # namespaces.each
        end # [].tap
      end # def extract_with_namespaces!

      def group_by_namespace!(*property_lists)
        property_lists.map do |properties|
          {}.tap do |groups|
            properties.each do |property|
              (groups[property.to_uri.namespace] ||= []) << property
            end
          end.values.flatten
        end
      end
    # end private
  end
end
