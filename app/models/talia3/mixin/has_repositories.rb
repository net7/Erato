# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

##
# This mixin allows to associate repositories to a class and it's
# objects.
#
# @author Riccardo Giomi <giomi@netseven.it>
#
# First of all the module adds methods to access Talia3 repository
# configuration directly:
#
# @example Checking if a repository name is present in the
#   configuration:
#   has_repositories.repositories.defined? :local
#   => true
#
# @example Getting all repository names from the configuration:
#   has_repositories.repositories.defined
#   => [:local, ...]
#
# It also allows to associate repositories to an object and then
# declare which one is used for read/write operations:
# 
# @example Add a repository:
#   has_repositories.add_repository(:my_repo)
#
# **Warning**: adding a repository that does not exist does not raises
#   and error. The error will be raised the first time the repository
#   is actually used with #use_repository
#
# @example Clear all repositories, except for the default :local one:
#   has_repositories.clear_repositories
#
# @example Get all repositories:
#   has_repositories.repositories
#   => #<Talia3::Repositories:0x9522e08 @names=[:local, :my_repo]>
#
# @example Get all available repository names:
#   has_repositories.repositories.names
#   => [:local, :my_repo]
#
# @example Check if a repository is available:
#   has_repositories.repositories.include? :zzz
#   => false
#
# @example Set current repository:
#   has_repositories.use_repository(:my_repo)
#   # The following is a low-level method that bypasses all checks,
#   # use with caution.
#   has_repositories.repository = RDF::Repository.new
#
# A class implementing this mixin can also have repositories. They
# can be used as default repositories for all new objects of that
# class. Also, the class has a default repository to use in all
# operations, this defaults to :local. This default repository will
# also be used by #use_repository if no name is specified.
#
# @example Set the default repository to use:
#   # Setting a default repository also does a add_repository.
#   
#   # This is not needed:
#   # HasRepositoriesClass.add_repository :my_repo 
#   HasRepositoriesClass.default_repository :my_repo
#
# @example Get the default repository name:
#   HasRepositoriesClass.default_repository
#   # => :my_repo
#
# @example You don't need to do anything for an object to use the default repository:
#   HasRepositoriesClass.repository
#   # => #<RDF::Sesame::Repository:....> # the :my_repo repository
# 
# @example HasRepositories#repositories and related examples work
#   the same way for the class as for the object:
#   
#   HasRepositoriesClass.repositories
#   => #<Talia3::Repositories:0x9522e08 @names=[:local]>
#
# @todo Add #import examples.
module Talia3::Mixin::HasRepositories
  ##
  # @private
  def self.included(base)
    base.extend ClassMethods
  end

  ##
  # Class-wide repositories.
  #
  # Can be defined for a class and be then used as default for new
  # objects of that class. 
  #
  module ClassMethods
    def repository(name=nil)
      raise Exception, "No default repository for #{name}" unless name or default_repository
      repositories[(name.nil? ? default_repository : name)]
    end

    ##
    # Returns the name of the default repository for this class.
    #
    # @return [Symbol]
    def default_repository
      @default_repository || repositories.names.first
    end

    ##
    # Sets a default repository to use for all objects of this class.
    #
    # Also adds the repository name to the class' repositories
    # list.
    #
    # **Note**: if the name does not belong to a valid repository,
    # no exceptions are raised until the repository is actually used
    # by an object with #use_repository or #get_repository.
    #
    # @param [String, Symbol] the repository name
    # @return [Symbol] the argument, as a symbol
    def default_repository=(name)
      name = name.to_sym
      repositories << name
      default_repository = name
    end
    
    ##
    # The class-defined repositories.
    #
    # @return [Talia3::Repositories] a repositories wrapper
    def repositories
      @repositories ||= Talia3::Repositories.new
    end

    ##
    # Add a repository for this class.
    #
    # @param [String, Symbol] the repository name
    # @return the argument
    def add_repository(name)
      repositories << name
    end

    ##
    # Remove all repositories for this class.
    #
    # @return [Talia3::Mixin::HasRepositories] self (chainable)
    def clear_repositories
      repositories.clear
      self
    end

    ##
    # Imports data from a RDF file to the default repository.
    #
    # @todo refactor with the other import methods, using rdf.rb support.
    #   There should be only one method for this!!!
    # @todo Find why you cannot save a graph all a once.
    # @todo Add support for more formats.
    # @todo bug in RDF::Reader#open investigate!
    # @params [String] filename
    # @params [String, Symbol] format optional, format recognition from rdf.rb 
    #   does not seem to work that well though
    # @params [RDF::URI, String, Symbol] context optional
    # @return [Boolean]
    def import(filename, format=nil, context=nil)
      # FIXME: too much code for this.
      context = self.context if context.nil? and self.respond_to? :context
      context = Talia3::URI.new(context)
      # Does not work why?
      # g = RDF::Graph.new(self.context)
      # RDF::RDFXML::Reader.open file, {:content_type => 'application/xml'} do |f|
      #   f.each_statement {|s| Rails.logger.info s.to_s;g << s}
      # end
      # Talia3.repository << g unless g.size.zero?
      format = format.nil? ? filename : format.to_sym
      raise ArgumentError, "no RDF::Reader for specified file" unless reader = RDF::Reader.for(format)
      ::RDF::Util::File.open_file(filename) do |file|
        reader.new file do |f|
          f.each_statement do |s|
            s.context = context
            self.repository << s
          end
        end
      end
      true
    end
  end # module ClassMethods



  ##
  # The object-specific repositories.
  #
  # By default an object will have access to its class repositories,
  # which in turn defaults to at least :local.
  #
  # @return [Talia3::Repositories] a repositories wrapper
  def repositories
    @repositories ||= self.class.repositories
  end

  ##
  # Returns the active repository.
  #
  # This is the repository used in any read/write operation.
  #
  # Defaults to the repository defined with self.default_repository.
  #
  # @note The method returns the repository itself, not its name.
  # @return [RDF::Repository]
  def repository
    @repository || get_repository
  end

  ##
  # Selects the active repository based on its name.
  #
  # This is will repository used in any read/write operation.
  #
  # @note Only works on repositories declared for this object.
  #
  # @param [optional, Symbol, String] the repository name; usually
  #   defaults to :local.
  # @return [RDF::Repository]
  def use_repository(name=nil)
    @repository = get_repository name
  end

  ##
  # Sets the active repository
  #
  # This will be repository used in any read/write operation.
  #
  # @note The method expects the repository itself, not its
  # name. See #use_repository for that.
  #
  # @param [RDF::Repository]
  # @return [RDF::Repository]
  def repository=(repository)
    unless repository.is_a? RDF::Repository or repository.nil?
      raise ArgumentError, "Parameter must be a RDF::Repository"
    end
    @repository = repository
  end

  ##
  # Returns a repository by name.
  #
  # If no name is given, the first repository found is returned.
  #
  # @note Only works on repositories declared for this object.
  #
  # @param [Symbol, String]
  # @return [RDF::Repository]
  # @raise [Exception] if the name is not declared
  def get_repository(name=nil)
    name ||= self.class.default_repository
    repositories[name]
  end

  ##
  # Adds a repository by name for this object.
  #
  # The name must be defined in the Talia3 configuration.
  #
  # @param [Symbol, String] repository name in configuration
  # @return [Talia3::Mixin::HasRepositories] self (chainable)
  def add_repository(name)
    repositories << name
    self
  end

  ##
  # Clears all declared repositories.
  #
  # @return [Talia3::Mixin::HasRepositories] self (chainable)
  def clear_repositories
    repositories.clear
    @repository = nil
    self
  end
end # module Talia3::Mixin::HasRepositories
