# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

 
##
# = Mixin for classes that can be exported in xml.
#
# @todo more documentation! More examples!
#
# @note Requires the class to include {Talia3::HasGraph} or implement
# a #graph method that returns an RDF::Graph object.
module Talia3::Mixin::RDFExportable

  ##
  #
  def to_rdf
    must_implement_graph
    RDF::RDFXML::Writer.buffer :base_uri => Talia3.base_uri.dup, :prefixes => Talia3::N.namespaces.dup do |writer|
      writer << self.graph
    end
  end
  alias :to_xml :to_rdf

  private
    ##
    #
    def must_implement_graph
      raise Exception, "Object must implement a #graph method" unless respond_to? :graph
    end
  #end private
end
