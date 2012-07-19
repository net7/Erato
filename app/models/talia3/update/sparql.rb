# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# = Implements an RDF graph "delta" using SPARQL Update format.
#
class Talia3::Update::SPARQL

  attr_accessor :data

  def initialize(data=nil)
    self.data = data
    context = nil
  end  # def initialize

  ##
  # Format for SPARQL representations.
  #
  # This value is for use in Rails controllers with the "render" method.
  # @return [Symbol]
  def format
    :text
  end # def format

  def content_type
    "application/x-www-form-urlencoded"
  end # def content_type

  def to_s
    return '' if data.empty?
    build_update_string
  end # def to_s

  private
    def build_update_string
      string = ""
      data_by_operation do |add, remove|
        string = "update=DELETE {"
        remove.each {|statement| string << format_statement(statement.tap {|s| s.context=nil})}
        string << '} INSERT {'
        add.each {|statement| string << format_statement(statement.tap {|s| s.context=nil})}
        string << '}'
      end
      string << " WHERE {}" 
    end

    def data_by_operation(&block)
      add, remove = [], []

      data.each do |operation|
        add    << operation[:insert]
        remove << operation[:delete]
      end

      yield add.compact, remove.compact
    end

    def format_statement(statement)
      case
        # This case is not handled at the moment.
        when (statement.subject.node? and statement.object.node?)
          raise NotImplementedError
        when statement.subject.node?
          RDF::Query::Pattern.from(statement.dup.tap {|s| s.subject = RDF::Query::Variable.new(statement.subject.id)}).to_s
        when statement.object.node?
          RDF::Query::Pattern.from(statement.dup.tap {|s| s.object = RDF::Query::Variable.new(statement.object.id)}).to_s
        else writer.format_statement(statement)
      end
    end # def format_statement

    def writer
      @writer ||= RDF::NTriples::Writer.new
    end

  # end private
end # class Talia3::Changeset::Changeset
