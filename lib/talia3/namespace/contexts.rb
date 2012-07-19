# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


require 'talia3/namespace/local.rb'


##
# Special namespace to be used as contexts.
#
# Uses Talia3 configuration to determine the base uri. Defaults to
# "#{Talia3::N::LOCAL.to_s}contexts/"if no configuration is found.
#
# @example Talia::N::CONTEXT.ontology
class Talia3::Namespace::CONTEXTS < Talia3::Namespace
  register :contexts, Talia3::Namespace::LOCAL.new.uri_for("contexts/")

  ##
  # Initializes this namespace.
  #
  # @note Parameters should be ignored for explicit namespaces.
  # @param [Symbol] ignored
  # @param [String] ignored
  # @return [Talia3::Namespace::CONTEXTS]
  def initialize(prefix=nil, uri_s=nil)
    @contexts = Talia3.config(:contexts) || {}
    @uri = Talia3::Namespace::LOCAL.new.uri_for("contexts/").to_s
    @prefix = :contexts
  end

  ##
  # Returns the uri for the public context.
  #
  # @return [Talia3::URI]
  def public
    Talia3::URI.new(@contexts['public'].nil? ? "#{to_s}public" : @contexts['public'])
  end

  ##
  # Returns the uri for ontology context.
  #
  # @return [Talia3::URI]
  def ontology
    Talia3::URI.new(@contexts['ontology'].nil? ? "#{to_s}ontology" : @contexts['ontology'])
  end

  ##
  # Should return the context specific to user information.
  #
  # @todo Not implemented yet
  # @raise [NotImplementedError] always
  def user(user)
    raise NotImplementedError, "Talia::Namespace::CONTEXTS.user is a TODO!"
  end
end # class Talia3::Namespace::CONTEXTS
