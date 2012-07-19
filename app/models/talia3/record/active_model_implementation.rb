# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

##
# @todo Documentation here or in Record?
module Talia3::Record::ActiveModelImplementation
  #
  # NOTE: the following includes and calls where moved back in
  # Talia3::Record because they apparently need to be included/called
  # from a class and not a module... 
  # The documentation still belongs here though
  #

  ##
  # Auto-extend:
  #  activeModel::Translation
  # TODO: adapt translation of field names to our
  #   ontology-and-namespace situation.
  # include ::ActiveModel::Validations

  # extend ::ActiveModel::Callbacks

  ##
  # Auto-includes:
  #     extend ActiveSupport::Concern
  #     include ActiveModel::AttributeMethods
  # include ::ActiveModel::Dirty
  # define_model_callbacks :create, :save, :update, :delete

  ##
  # Needed by ActiveModel::Validations.
  #
  # @param [String] key
  # @return [String, Array<Talia3::Record>, Talia3::Record]
  def read_attribute_for_validation(key)
    attribute(key)
  end

  include ::ActiveModel::Conversion
  # TODO: use ontologies for this, at least make it more
  #   intelligent...
  extend ::ActiveModel::Naming

  ##
  # Errors as handled by ActiveModel.
  # @param [ActiveModel::Errors]
  attr_reader :errors

  ##
  # TODO: rewrite methods where needed for better RDF presentations,
  #   add to_lod, to_rdf.
  include ::ActiveModel::Serialization

  ##
  # The list of attribute names defined for the current type.
  #
  # Needed by ActiveModel and Rails in general.
  # Automatically adds a :uri attribute. If not in
  # {Talia3::Resource.strict_schema?} mode :type is also added.
  #
  # @return [Array<Symbol>]
  def attributes
    properties || []
  end

  #
  # ActiveModel base requirements (to pass base ActiveModel::Lint tests)
  #

  # #persisted? is defined in Talia3::Resource

  # @todo How to implement this?
  def to_key
    persisted? ? [uri.to_key.to_s] : nil
  end

  ##
  # Returns an object for ActiveModel to use.
  #
  # Using the default for now.
  #
  # @private
  # @return [Talia3::Record]
  def to_model
    self
  end
end
