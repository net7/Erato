# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# = Implements an RDF graph "delta" using Changeset rdf+xml format.
#
class Talia3::Update::Changeset

  include Talia3::Mixin::HasNamedGraph
  include Talia3::Mixin::RDFExportable

  attr_accessor :data

  def initialize(data=nil)
    self.data = data
    context = nil
  end  # def initialize

  ##
  # Format for changeset representations.
  #
  # This value is for use in Rails controllers with the "render" method.
  # @return [Symbol]
  def format
    data.size.zero? ? :text : :xml
  end # def format

  def content_type
    "application/rdf+xml; charset=UTF-8"
  end # def content_type

  def to_s
    return '' if data.size.zero?
    build_graph
    to_xml
  end # def to_s

  private
    def build_graph
      rdf = Talia3::N::RDF
      cs  = Talia3::N::CS
      # FIXME: should be a single changeset, with everything inside.
      # FIXME: if :delete == :insert, ignore.
      changeset_uri = "#{Talia3::N::LOCAL.to_s}_#{Time.now.to_f.to_s.gsub('.','')}".to_uri
      graph << [changeset_uri, rdf.type, cs.ChangeSet]
      graph << [changeset_uri, cs.createdDate, RDF::Literal::Date.new(Time.now)]


      data.each do |op|
        uri = op[:delete].try(:subject) || op[:insert].try(:subject)
        unless uri.blank?
          graph << [changeset_uri, cs.subjectOfChange, uri]
          # cs.creatorName
          # cs.changeReason
          if op[:delete]
            bnode = RDF::Node.new
            graph << [bnode, rdf.type, rdf.Statement]
            graph << [bnode, rdf.subject, op[:delete].subject]
            graph << [bnode, rdf.predicate, op[:delete].predicate]
            graph << [bnode, rdf.object, op[:delete].object]
            graph << [changeset_uri, cs.removal, bnode]
          end
          if op[:insert]
            bnode = RDF::Node.new
            graph << [bnode, rdf.type, rdf.Statement]
            graph << [bnode, rdf.subject, op[:insert].subject]
            graph << [bnode, rdf.predicate, op[:insert].predicate]
            graph << [bnode, rdf.object, op[:insert].object]
            graph << [changeset_uri, cs.addition, bnode]
          end
        end
      end
    end # def build_graph
  # end private
end # class Talia3::Changeset::Changeset
