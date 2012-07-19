# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# Represents a set of repositories.
#
# Repositories are stored and accessed through the name (symbol)
# associated with them in the Talia3 configuration.
#
# Repositories will always include the name :local, which is Talia3
# default repository.
#
# Should mostly be used through methods of HasRepositories
# mixin.
#
class Talia3::Repositories
  ##
  # Repository names currently stored.
  #
  # @return [Array<Symbol>]
  def names
    @names ||= [:local]
  end

  ##
  # The number of repositories stored.
  #
  # @return [Number]
  def size
    names.size
  end
  alias_method :count, :size

  ##
  # True if there are no repositories stored.
  #
  # @return [Boolean]
  def empty?
    names.empty?
  end

  ##
  # Allows to treat this as a Hash: given me a name, it will return its RDF::Repository.
  #
  # @param [Symbol, String]
  # @return RDF::Repository
  # @raise [Exception] if the name is not stored
  def [](name)
    raise Exception, "Repository #{name} not declared for this object." unless include? name
    raise Exception, "Repository :#{name} is not defined in talia3.yml for env #{Rails.env}." unless self.defined? name
    Talia3.repository name
  end

  ##
  # Return the RDF::Repository associated with the first name stored.
  #
  # @return [RDF::Repository]
  # @raise [Exception] if no name is stored
  def first
    raise Exception, "No repositories declared for this object." if empty?
    self[@names.first]
  end

  ##
  # Allows to cyvle through the stored repositories.
  #
  # @yield  [repository]
  # @yieldparam  [RDF::Repository] repository
  # @yieldreturn [void] ignored
  # @return [Array] the stored names
  def each(&block)
    names.each {|name| block.call Talia3.repository(name)}
  end

  ##
  # Adds a name to the set.
  #
  # @param [Symbol, String]
  # @return [Talia3::Repositories] self (chainable)
  # @raise [Exception] if the name is not defined in the configuration
  def <<(name)
    add(name)
  end

  ##
  # Adds names to the set.
  #
  # @param [#each]
  # @return [Array] the stored names
  # @raise [Exception] if one of the names is not defined in the configuration
  def +(names)
    names.each {|name| add name}
  end

  ##
  # Adds a name to the set.
  #
  # @private
  # @param [Symbol, String]
  # @return [Talia3::Repositories] self (chainable)
  def add(name)
    names << name unless names.include? name
    self
  end

  ##
  # Removes a name from the set.
  #
  # :local is the internal default and cannot be removed.
  #
  # @param [Symbol, String]
  # @return the argument
  def delete(name)
    names.delete name unless name.to_sym == :local
  end

  ##
  # Removes all names from the set.
  #
  # @return [Talia3::Repositories] self (chainable)
  def clear
    @names = [:local]
    self
  end

  ##
  # Returns true if the name is present in the set.
  #
  # @param [Symbol, String]
  # @return [Boolean]
  def include?(name)
    names.include? name
  end

  ##
  # Returns all names defined in the configuration.
  #
  # @return [Array<Symbol>]
  def defined
    Talia3.repository_names
  end

  ##
  # Returns true if the name is defined in the configuration.
  #
  # __Note:__ always referenct the class when calling
  #   (e.g. self.defined?), as defined? already exists as a Kernel
  #   method.
  # 
  # @param [Symbol, String]
  # @return [Boolean]
  def defined?(name)
    Talia3.repository_name? name
  end
end # class Talia3::Repositories
