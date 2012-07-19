# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


module Talia3::Schema::Ontology

  def self.schema_for(type, context=nil)
    properties = single_domain_properties(type, context).merge(multi_domain_properties(type, context))
    properties.blank? ? {} : {:properties => properties, :order => nil}
  end

  private
    ##
    # @private
    # @param [Talia3::URI, Symbol, String] type
    # @param [Talia3::URI, Symbol, String] context
    # @return Hash<Symbol=>Hash>
    def self.single_domain_properties(type, context)
      self.fetch_properties_info single_domain_properties_query(type, context)
    end

    ##
    # @private
    # @param [Talia3::URI, Symbol, String] type
    # @param [Talia3::URI, Symbol, String] context
    # @return Hash<Symbol=>Hash>
    def self.multi_domain_properties(type, context)
      self.fetch_properties_info self.multi_domain_properties_query(type, context)
    end

    def self.single_domain_properties_query(type, context=nil)
      unless Talia3.repository.supports? :sparql
        raise NotImplementedError, "Not implemented for non-sparql repositories" 
      end
      type = Talia3::URI.new type
      rdfs = Talia3::N::RDFS
      rdf  = Talia3::N::RDF
      RDF::SPARQL::Query.select(:uri, :range, :label).distinct.from(context).
        where([:uri, rdf.type, rdf.Property]).
        where([type, rdfs.subClassOf, :t]).where([:uri, rdfs.domain, :t]).
        optional([:uri, rdfs.range, :range]).
        optional([:uri, rdfs.label, :label])
    end

    def self.multi_domain_properties_query(type, context=nil, depth=5)
      type = Talia3::URI.new type
      rdfs = Talia3::N::RDFS
      rdf  = Talia3::N::RDF
      owl  = Talia3::N::OWL

      unions = (0..depth-1).map do |i|
        union = "  {?uri <#{rdfs.domain}> ?b . ?b <#{owl.unionOf}> ?b#{i} . ?b#{i}"
        i.downto(1).each {|j| union << " <#{rdf.rest}> ?b#{j-1} . ?b#{j-1}"} if i > 0
        union << " <#{rdf.first}> ?type}"
      end

      q  = "SELECT DISTINCT ?uri ?range ?label "
      q << "WHERE {"
      q << "  ?uri <#{rdf.type}> <#{rdf.Property}> ."
      q << "  <#{type}> <#{rdfs.subClassOf}> ?type ."
      q << unions.join(' UNION ')
      q << "  OPTIONAL {?uri <#{rdfs.range}> ?range}"
      q << "  OPTIONAL {?uri <#{rdfs.label}> ?label}"
      q << "}"
    end # def self.single_domain_properties_query

    def self.fetch_properties_info(properties_query)
      {}.tap do |properties|
        Talia3.repository.query properties_query do |solution|
          begin
            key = Talia3::URI.new(solution.uri).to_key
            type, object_type = format_range solution
            label, language   = format_label solution

            properties[key] = {:type => type, :object_type => object_type} unless properties[key]
            (properties[key][:label] ||= {})[language] = label if label
          rescue
          end # begin
        end # Talia3.repository.query
      end # {}.tap
    end # def fetch_properties_info

    def self.format_range(solution)
      case
        when solution.range == Talia3::N::RDFS.Literal then [:string, nil]
        when solution.range.to_s.starts_with?(Talia3::N::XSD.to_s) then [:string, nil]
        else [:object, Talia3::URI.new(solution.range).to_key]
      end
    rescue
      [:object, nil]
    end

    def self.format_label(solution)
      label = solution.label
      language = (label.respond_to? :language and not label.language.nil?) ? label.language.to_sym : :none 
      text     = label.to_s || ""
      [text, language]
    rescue
      [nil, nil]
    end
  #end private
end
