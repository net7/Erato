# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# Cached ontologies model. 
#
# Cached ontologies are copies of ontologies defined somewhere else. A
# local copy is mantained locally and syncronized with the original
# every now and then.
#
# Cached ontologies can be removed at any time, they are not
# considered part of the application RDF model.
#
# Each distinct ontology is stored in its own context, such contexts
# are identified by triples in the form: 
#
#     ?o rdf:type talia:Ontology identifies 
#
# Where ?o is the URI of the context itself.
#
class Talia3::Ontology::Cache < Talia3::Ontology
  def self.exists?(context)
    not self.repository.query([Talia3::URI.new(context), Talia3::N::RDF.type, Talia3::N::Talia.Ontology]).size.zero?
  end

  def self.all
    self.repository.query([nil, Talia3::N::RDF.type, Talia3::N::Talia.Ontology]).map do |s|
      new(s.subject)
    end
  end

  def self.destroy!(context)
    context = Talia3::URI.new context
    self.cleanse_context! self.repository, context
    self.repository.delete [context, Talia3::N::RDF.type, Talia3::N::Talia.Ontology]
    self
  end

  ##
  # Imports in the local repository a new ontology from a file or remote url.
  #
  # @todo use this to refactor all the other import methods (removing when necessary).
  # @todo beter documentation (yardoc @option) for options.
  # Possible options are: :context, :original_filename (use if the file was uploaded),
  # :format, :base_uri.
  #
  # @note if no RDF::Reader is found with the information provided, the method will try
  #       to force content-type application/rdf+xml, as it is the most commonly used.
  #
  # @param [String] location
  # @param [Hash] options
  def self.import(location, options={})
    context = Talia3::URI.new(options[:context].blank? ? location : options.delete(:context))

    # See if we it makes sense to force 'application/rdf+xml' as content_type.
    unless options[:content_type]
      options[:content_type] = 'application/rdf+xml' if RDF::Format.for({:file_name => location}.merge(options)).nil?
    end

    self.repository.tap do |r|
      r.load(location, 
             :content_type => (options.delete(:content_type)),
             :context => context,
             :base_uri => options.delete(:base_uri),
             :file_name => options.delete(:original_filename))

      r << [context, Talia3::N::RDF.type, Talia3::N::Talia.Ontology]
    end
  end

  def initialize(context = nil)
    self.context = context
  end

  def load!
    clear_graph
    self.repository.query([nil, nil, nil, self.context]).each do |s|
      graph << s
    end
    self
  end

  def save!
    save_graph! self.repository
  end
end
