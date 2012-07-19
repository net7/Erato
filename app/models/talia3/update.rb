# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# = Represents RDF modification information.
#
# Supported formats currently include:
# *  Changesets: http://docs.api.talis.com/getting-started/changesets/
# *  SPARQL update(for SESAME, at least): http://www.w3.org/Submission/SPARQL-Update/
# *  SESAME transaction XML document
#
class Talia3::Update
  def self.valid?(format)
    format and [:sparql, :changeset, :sesame_transaction].include? format.to_sym
  end # def self.valid?

  def self.for(format, data=nil)
    data = remove_useless data
    case format.to_sym
      when :sparql then Talia3::Update::SPARQL.new(data)
      when :changeset then Talia3::Update::Changeset.new(data)
      when :sesame_transaction then Talia3::Update::SesameTransaction.new(data)
      else nil
    end

  rescue NotImplementedError
    nil
  end # def self.for

  protected
    ##
    # Removes updates that remove and reinsert the same information.
    #
    # @param [Array<Hash>] data
    # @return [Array<Hash>]
    def self.remove_useless(data)
      data.dup.select do |a|
        not_useless?(a, data)
      end
    end

    def self.not_useless?(element, data)
      return false if element[:insert].nil? and element[:delete].nil?
      return false if same_element?(element[:insert], element[:delete])
      data.each do |other_element|
        # FIXME horrible!
        return false if really_useless?(element[:insert], other_element[:delete]) or really_useless?(element[:delete], other_element[:insert])
      end
      true
    end

    def self.really_useless?(element1, element2)
      (element1.nil? or element2.nil?) ? false : same_element?(element1, element2)
    end

    # FIXME RDF::Statement#== behaviour is erratic, depending on type. This is better for this situation.
    def self.same_element?(element1, element2)
      element1 == element2 and same_literal?(element1.object, element2.object)
    end


    def self.same_literal?(literal1, literal2)
      if literal1.literal? and literal2.literal?
        literal1.class == literal2.class and literal1.datatype.to_s == literal1.datatype.to_s
      else
        true
      end
    end
  # end protected
end
