##
# Talia3 support for RDF labels (properties with rdfs:label predicate).
#
class Talia3::Label
  attr_accessor :language, :value

  def initialize(language, value)
    self.language, self.value = language, value    
  end

  ##
  # Chooses the best candidate from a set of labels, taking locale preferences in consideration.
  #
  # @param [Hash] labels
  # @param [Array] locales optional list of languages in their preferred order, defaults to Talia3.locales.
  # @return [Talia3::Label]
  def self.choose(labels, locales=nil)
    return new :none, "" if labels.size.zero?
    collect(labels, locales).first
  end

  ##
  # Converts a Hash of language => value duples to an Talia3::Label array, 
  # ordering the elements according to locale preferences.
  #
  # Note that you can choose the best candidate by calling #first on the list, no need to use Talia3::Label.choose,
  # that is used when labels are stored in a unordered-by-definition Hash.
  #
  # @param [Hash] labels
  # @param [Array] locales optional list of languages in their preferred order, defaults to Talia3.locales.
  # @yield [labels]
  # @yieldparam [Talia3::Label] label
  # @return [Array<Talia3::Label>]
  def self.collect(labels, locales=nil, &block)
    locales ||= Talia3.locales
    results = ((labels.keys & locales) + (locales - labels.keys)).map do |language|
      new language, labels[language] unless labels[language].nil?
    end.compact

    block_given? ? results.each {|result| block.call(result)} : results
  end
end
