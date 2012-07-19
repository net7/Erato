# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# Predefined SPARQL 1.0 queries and other utilities for common operations on resources.
#
module Talia3::SPARQL
  class Queries

    ##
    # Query for a list of valid resource types, with pagination options.
    #
    # Valid resource types _do not_ include:
    #   * internal types as returned by {self.internal_types};
    #   * RDFS:Resource and OWL:Thing _unless_ at least a resource has one of those as its only type.
    #
    # @param  [FixNum] limit  optional, pagination limit
    # @param  [FixNum] offset optional, pagination offset
    # @return [String] the SPARQL query
    def self.types_query(limit=nil, offset=nil)
      filters = internal_types.map {|type| %[FILTER(!regex(str(?type), "#{type}")) .]}.join(' ');
      paging = limit.present? ? "LIMIT #{limit} OFFSET #{offset || 0}" : ""

      <<-EOS
        SELECT DISTINCT ?type
        WHERE {
          {?u a ?type . FILTER(!isBlank(?u)) . #{filters}}
          UNION
          {?u a ?type . FILTER(!isBlank(?u)) .?u a <#{Talia3::N::RDFS.Resource}> .
           OPTIONAL {?u a ?type2 . FILTER(?type2 != <#{Talia3::N::RDFS.Resource}>) .}
           FILTER(!BOUND(?type2)) .}
          UNION
          {?u a ?type . FILTER(!isBlank(?u)) . ?u a <#{Talia3::N::OWL.Thing}> .
           OPTIONAL {?u a ?type2 . FILTER(?type2 != <#{Talia3::N::OWL.Thing}>) .}
           FILTER(!BOUND(?type2)) .}
        }
        ORDER BY ?type #{paging}
      EOS
    end

    ##
    # Query for a list of valid resource types(*), with pagination options.
    #
    # (*)Same as {self.types_query}, with the difference that this method never returns rdfs:resource or owl:thing.
    #
    # Valid resource types _do not_ include:
    #   * internal types as returned by {self.internal_types};
    #   * RDFS:Resource and OWL:Thing.
    #
    # @param  [FixNum] limit  optional, pagination limit
    # @param  [FixNum] offset optional, pagination offset
    # @return [String] the SPARQL query
    def self.strict_types_query(limit=nil, offset=nil)
      filters = (internal_types + [Talia3::N::RDFS.Resource, Talia3::N::OWL.Thing]).map do |type|
        %[FILTER(!regex(str(?type), "#{type}")) .]
      end.join(' ');

      paging = limit.present? ? "LIMIT #{limit} OFFSET #{offset || 0}" : ""

      <<-EOS
        SELECT DISTINCT ?type
        WHERE {
          ?u a ?type . 
          #{filters}
        }
        ORDER BY ?type #{paging}
      EOS
    end

    ##
    # Query for a list of instances of the given type, with pagination options.
    #
    # @param  [Talia3::URI, #to_s] type
    # @param  [FixNum]             limit  optional, pagination limit
    # @param  [FixNum]             offset optional, pagination offset
    # @return [String] the SPARQL query
    def self.instances_query(type, limit=nil, offset=nil)
      paging = limit.present? ? "LIMIT #{limit} OFFSET #{offset || 0}" : ""

      <<-EOS
        SELECT DISTINCT ?uri 
        WHERE {?uri a <#{type}>.FILTER(!isBlank(?uri)).}
        ORDER BY ?uri #{paging}
      EOS
    end

    ##
    # Query for a list of instances whose only type is either RDFS::Resource or OWL::Thing,
    # with pagination options.
    #
    # @param  [FixNum] limit  optional, pagination limit
    # @param  [FixNum] offset optional, pagination offset
    # @return [String] the SPARQL query
    def self.untyped_instances_query(limit=nil, offset=nil)
      paging = limit.present? ? "LIMIT #{limit} OFFSET #{offset || 0}" : ""

      <<-EOS
        SELECT DISTINCT ?uri
        WHERE {
          {
            FILTER(!isBlank(?uri)) . ?uri a <#{Talia3::N::RDFS.Resource}> .
            OPTIONAL {?uri a ?type2. FILTER(?type2 != <#{Talia3::N::RDFS.Resource}>) .} .
            FILTER(!BOUND(?type2)) .
          } UNION {
            FILTER(!isBlank(?uri)) . ?uri a <#{Talia3::N::OWL.Thing}> .
            OPTIONAL {?uri a ?type2. FILTER(?type2 != <#{Talia3::N::OWL.Thing}>) .} .
            FILTER(!BOUND(?type2)) .
          }
        }
        ORDER BY ?uri #{paging}
      EOS
    end

    ##
    # (see Talia3::Namespace.internal_types)
    def self.internal_types
      Talia3::Namespace.internal_types
    end
    
  end # class Queries
end # module Talia3::SPARQL
