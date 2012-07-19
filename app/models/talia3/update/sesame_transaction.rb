# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# = Implements an RDF graph "delta" using SESAME x-rdftransaction format.
#
class Talia3::Update::SesameTransaction

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
    "application/x-rdftransaction; charset=UTF-8"
  end # def content_type

  def to_s
    return '' if data.size.zero?
    Nokogiri::XML::Builder.new do |xml|
      xml.transaction {
        self.data.each do |op|
          xml.remove {
            xml.uri {xml.text op[:delete].subject.to_s}
            xml.uri {xml.text op[:delete].predicate.to_s}
            value = op[:delete].object
            if value.is_a? RDF::Literal
              xml.literal  value.to_s, literal_attributes(value)
            else
              xml.uri value.to_s
            end
          } if op[:delete]
          xml.add {
            xml.uri {xml.text op[:insert].subject.to_s}
            xml.uri {xml.text op[:insert].predicate.to_s}
            value = op[:insert].object
            if value.is_a? RDF::Literal
              xml.literal  value.to_s, literal_attributes(value)
            else
              xml.uri value.to_s
            end
          } if op[:insert]
        end
      }
    end.to_xml
  end # def to_s

  private
    def literal_attributes(literal)
      result = {}
      result["xml:lang"] = literal.language unless literal.language.blank?
      result["datatype"] = literal.datatype unless literal.datatype.blank?
      result
    end
  # end private

end # class Talia3::Changeset::Changeset
