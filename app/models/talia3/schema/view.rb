# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


module Talia3::Schema::View
  def self.all
    q = RDF::SPARQL::Query.select(:c, :n, :l).distinct.from(Talia3::N::CONTEXTS.ontology).
      where([:c, :rdf__type.to_uri, :mview__ClassView.to_uri]).
      where(RDF::Query::Pattern.new :c, :mview__viewName.to_uri, :n, :optional => true).
      where(RDF::Query::Pattern.new :c, :rdfs__label.to_uri, :l, :optional => true)

    view = Struct.new :class, :name, :label

    Talia3.repository.query(q).map do |s|
      view.new(Talia3::URI.new(s.c),
               s.bound?(:n) ? s.n.to_s : nil,
               s.bound?(:l) ? s.l.to_s : nil)
    end
  end

  def self.destroy(uri)
    uri = Talia3::URI.new(uri)
    view_name = Talia3.repository.query([uri, :mview__viewName.to_uri, nil, :contexts__ontology.to_uri]).first.try :object
    unless view_name.nil?
      Talia3.repository.query([nil, :mview__viewName.to_uri, view_name.to_s, :contexts__ontology.to_uri]).subjects.each do |s|
        r = Talia3::Resource.for(s, :direction => :right, :depth => 1, :context => :contexts__ontology.to_uri)
        if r.raw(:mview__viewName).size  == 1
          Talia3.repository.delete [r.uri, nil, nil, :contexts__ontology.to_uri]
        else
          Talia3.repository.delete [r.uri, :mview__viewName.to_uri, view_name.to_s, :contexts__ontology.to_uri]
        end
      end
    end
    Talia3.repository.delete [uri]
  end

  def self.schema_for(type, context)
    @mview = Talia3::N::MVIEW
    if Talia3::URI.new(type).prefix == 't3view'
      view(type, context)
    else
      default_view(type, context)
    end
  end

  private
    def self.default_view(type, context)
      uri = default_view_uri(type, context)
      uri.nil? ? {} : view(uri.to_s, context)
    end

    def self.view(type, context)
      type_uri = Talia3::URI.new type
      properties = {}

      q = RDF::Query.new do |q|
        q << [type_uri, @mview.viewName, :view_name, context]
        q << RDF::Query::Pattern.new(type_uri, @mview.properties, :properties, :context => context, :optional => true)
        q << RDF::Query::Pattern.new(type_uri, @mview.shortProperties, :short_properties, :context => context, :optional => true)
        q << RDF::Query::Pattern.new(type_uri, @mview.editProperties, :edit_properties, :context => context, :optional => true)
        q << [:property_view, @mview.viewName, :view_name, context]
        q << [:property_view, :p, :o, context]
      end

      g = RDF::Graph.new do
        Talia3.repository.query(q).each {|s| self << s}      
      end

      order = {
        :list  => format_base_order(g.query([type_uri, @mview.properties]).first),
        :short => format_base_order(g.query([type_uri, @mview.shortProperties]).first),
        :edit  => format_base_order(g.query([type_uri, @mview.editProperties]).first)
      }

      g.subjects.each do |subj|
        unless subj.to_s == type_uri
          field = {}
          fieldname = nil
          g.query([subj]).each do |s|
            case s.predicate.to_s
              when @mview.propertyName
                fieldname = Talia3::URI.new(s.object).to_key
              when Talia3::N::RDFS.label
                value = s.object
                language = if value.respond_to? :language
                             value.language.blank? ? :none : value.language.to_sym
                           else
                             :none
                           end
                (field[:label] ||= {})[language] = value.to_s
              when @mview.propertyType
                field[:type], field[:object_type] = format_type s.object
              when @mview.cardinality
                field[:cardinality] = Talia3::URI.new(s.object).local_name.underscore.to_sym
              when @mview.listPos
                field[:listPos] = s.object.to_i
              when @mview.shortPos
                field[:shortPos] = s.object.to_i
              when @mview.editPos
                field[:editPos] = s.object.to_i
            end
          end
          properties[fieldname] = field unless fieldname.nil?
        end
      end
      properties.blank? ? {} : {:properties => properties, :order => order_properties(properties.dup, order)}
    end

    def self.default_view_uri(type, context)
      q = RDF::Query.new do |q|
        q << [:s, RDF.type, @mview.ClassView, context]
        q << [:s, @mview.default, true, context]
        q << [:s, @mview.domain, Talia3::URI.new(type), context]
      end
      Talia3.repository.query(q).first.try :subject
    end

    def self.format_type(type)
      type_uri = Talia3::URI.new(type)
      if type_uri.prefix == 'mview'
        [type_uri.local_name.underscore.to_sym, nil]
      else
        [:object, type_uri.to_key]
      end
    end

    def self.format_base_order(base_order)
      case base_order.to_s
        when @mview.ViewAllProperties.to_s then :all
        when @mview.ViewNoProperties.to_s  then :none
        else nil
      end        
    end

    def self.order_properties(properties, base_order)
      Hash[base_order.map do |key, order|
             case order
               when :all  then [key, ordered_array_from(properties, "#{key}Pos", false)]
               when :none then []
               else
                 [key, ordered_array_from(properties, "#{key}Pos")]
             end
      end]
    end

    def self.ordered_array_from(properties, sort_field, strict=true)
      sort_field = sort_field.to_sym
      properties.reject! {|k,v| v[sort_field].nil? or v[sort_field] <= 0} if strict
      Hash[properties.sort {|a,b| (a[1][sort_field] || 99999) <=> (b[1][sort_field] || 99999)}].keys
    end
  #end private
end
