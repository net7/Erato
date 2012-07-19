# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


require 'rdf'
# Required for we need the vocabulary *before* talia/namespace is included.
require 'rdf/rdfxml'
require 'rdf/n3'
# At the moment, Talia3 uses custom modified plugins created from RDF.rb.
require 'rdf/sparql.rb'
require 'rdf/sesame.rb'

##
# Talia3 base module and configuration handling.
#
# Allows easy access to the Talia3 configuration as defined in 
# config/talia3.yml. It also creates and caches RDF::Repository
# objects for defined repositories.
# 
# Implements the base features needed to create dynamic classes that
# extend Talia3::Record and are based on a RDF type.
# For example, the Talia3::FOAF::Agent class will be available at all
# times, even if the class is defined nowhere. It will have type#
# foaf:Agent.
# If a class with the same name and namespace as one that can be
# created dynamically is already defined (in a model file for example),
# the static class will be used instead. This allows an application to
# override this feature and define its own classes for semantic types.
# A prerequisite for the creation of a dynamic class with the correct
# type is that the type's namespace and prefix must be known to Talia3.
# See also {Talia3::N}.
#
# @example Example config/talia3.yml file:
#   application_name: Talia3 Application
#   application_url: http://localhost:3000/
#   base_uri: http://localhost:3000/
#   user_emails_enabled: true
#   api_enabled: true
#   contexts:
#     public:  
#     ontology: 
#   repositories:
#     development:
#       local: 
#           type: sesame
#           location: http://localhost:8080/openrdf-sesame/repositories/talia3
#   loose_schema: false
#
# @example Getting all configuration for Talia3:
#   Talia3.config
#   => {
#     "application_name"=>"Talia3 Application",
#     "base_uri"=>"http://localhost:3000/", 
#     "contexts"=>{"public"=>nil, "ontology"=>nil},
#     "repositories"=>{
#       "development"=>{
#         "local"=>{"type"=>"sesame",
#                   "location"=>"http://localhost:8080/openrdf-sesame/repositories/talia3"}
#       }
#     },
#     "loose_schema"=>false
#   }
#
# @example Getting the application name
#   Talia3.config(:application_name)
#   => "Talia3 Application"
#
# @example Getting the default repository for the current environment:
#   Talia3.repository(:local)
#   Talia3.repository
#   => #<RDF::Sesame::Repository:0x0000000(http://localhost:8080/openrdf-sesame/repositories/talia3)>
#
# @example Checking if a repository's name is defined in the current environment:
#   Talia3.repository_name? :zzz
#   => false
#
# @example Getting all repository names for for current environment:
#   Talia3.repository_names
#   => ["local"]
#
# @example Requesting a dynamic, specialized, Talia3::Record class with type foaf:Person:
#   p = Talia3::FOAF::Person
#   => #<Talia3::FOAF::Person:0x...>
#   p.type.to_s
#   => "http://xmlns.com/foaf/0.1/Person"
#
# @example Rails auto-load still works and has priority:
#   Talia3::Auth::User.is_a? Talia3::Record
#   => false
#
# @todo Examples for new settings
# @author Riccardo Giomi <giomi@netseven.it>
module Talia3

  # @group Plugin utilities

  ##
  # Returns the path to the Talia3 plugin root.
  #
  # @return [String]
  def self.root
    Talia3::Engine.root
    #File.join File.dirname(__FILE__), '..'
  end

  # @group Talia3 configuration and settings

  ##
  # Returns a hash with the configuration as stored in
  # config/talia3.yml.
  #
  # Optional argument allows to get the subset of configuration for
  # the required key.
  #
  # @note this method should not be used to check for configuration setting values,
  #   specific method from this class should be used.
  #
  # @param [String, Symbol] key optional configuration item key.
  # @return [Hash] The configuration hash
  def self.config(key=nil)
    key.nil? ? Talia3::Engine.config.talia3 : Talia3::Engine.config.talia3[key.to_s]
  end

  ##
  # Returns the relative path to the application configuration file.
  #
  # @return [String] The path.
  def self.config_file
    File.join "config", "talia3.yml"
  end

  ##
  # Loads configuration from the talia3.yml file.
  #
  # @return [Hash] The loaded configuration hash
  def self.load_config
    File.exists?(config_file) ? YAML.load_file(config_file) : {}
  end

  ##
  # Allows to change the Talia3 configuration hash in memory.
  #
  # Argument hash substitutes the configuration hash in its entirety.
  # Use {self.write_config} to save the new configuration to file.
  #
  # @param [Hash] new_config the new configuration hash.
  # @return [Hash] The new configuration
  def self.config=(new_config)
    Talia3::Engine.config.talia3 = new_config
    # Some options might alter Rails routes, reload them:
    Rails.application.reload_routes!
  end

  ##
  # Writes the configuration back to the talia3.yml file.
  #
  # @return [true]
  # @raise Exception if the file cannot be written. 
  def self.write_config
    #config_file is defined in lib/talia3/engine.rb.
    File.open(self.config_file, "w+") {|io| io.write YAML.dump(self.config)}
    true
  end

  # @group Application methods

  ##
  # Returns whether the application should send confirmation emails to users.
  #
  # This value is also dependent on {self.application_url} as confirmation 
  # emails need a complete link back to the application to finish the registration process.
  # 
  # For this reason, confirmation emails will be disabled if no application_url is provided.
  # @return [Boolean]
  def self.user_emails_enabled?
    self.config['user_emails_enabled'] and not self.config['application_url'].blank?
  end

  ##
  # The base url for the application.
  #
  # Needed to create back links from registration confirmation emails.
  #
  # @return [String]
  def self.application_url
    self.config['application_url']
  end

  # @group Repository methods
  
  ##
  # Returns the configured repository names for current environment.
  #
  # @return [Array<String>]
  def self.repository_names
    begin; self.config["repositories"][Rails.env].keys
    rescue NoMethodError; []; end
  end

  ##
  # Returns true if the argument is a configured repository's name
  # for the current environment.
  # 
  # @param [String, Symbol] repository name to check
  # @return [Boolean]
  def self.repository_name?(name)
    repository_names.include? name.to_s
  end

  ##
  # Returns an instanced RDF::Repository object.
  #
  # {include:Talia3.prepare_repository}
  # 
  # @param [String, Symbol] optional repository name, defaults to :local
  # @return [RDF::Repository]
  def self.repository(name=:local)
    name = name.to_s
    @repositories ||= {}
    @repositories[name] ||= self.prepare_repository name
  end

  # @group Other configuration methods

  ##
  # Returns the "application name" setting for Talia3
  #
  # This is a shortcut for {Talia3.config}(:application_name)
  # and its use should be preferred.
  #
  # @return [String]
  def self.application_name
    self.config :application_name || ""
  end

  ##
  # Returns the "base URI" setting for Talia3
  #
  # This is used as a base to build local URIs.
  #
  # This is a shortcut for {Talia3.config}(:base_uri)
  # and its use should be preferred.
  #
  # @return [String]
  def self.base_uri
    self.config :base_uri || ""
  end

  ##
  # Returns the "locales" setting for Talia3.
  #
  # With no locales in the configuration file, Talia3 will default to [:en, :none].
  # If locales is a string it will be considered as a single value array.
  #
  # While this is for use with Rails i18n, it is also used to select
  # label languages from RDF literals. In particular, the order of
  # languages in this array is the same order with which labels are
  # scanned.
  #
  # For this last use this Talia3 allows a special value "none" for
  # label with no language.
  # 
  # @return [Array<String>]
  def self.locales
    locales = self.config(:locales)
    return [:en, :none] if locales.nil? or locales.blank?
    locales.is_a?(Array) ? locales.map {|l| l.to_sym} : [locales]
  end

  ##
  # Returns true if the current configuration limits Record 
  #   attributes to the ones defined in a schema.
  #
  # This is a shortcut for !{Talia3.config}(:loose_schema) 
  # and its use should be preferred.
  #
  # @return [Boolean]
  def self.strict_schema?
    !self.config :loose_schema
  end

  ##
  # Returns true if Talia3 default APIs are enabled.
  #
  # This is a shortcut for !!{Talia3.config}(:api_enabled) 
  # and its use should be preferred.
  #
  # @return [Boolean]
  def self.api_enabled?
    !!self.config(:api_enabled)
  end

  # @endgroup

  # @group Miscellaneous

  ##
  # Defines database table prefixes for classes inside this module.
  #
  # Used by ActiveRecord to assemble the table name associated to a class. 
  # @private
  def self.table_name_prefix
    'talia3_'
  end
  # @endgroup

  ##
  # Returns the a RDF::Repository configured with the parameters found
  # in conf/talia3.yml for the given name and current environment.
  #
  # @private
  # @param [String, Symbol] repository name
  # @return RDF::Repository
  def self.prepare_repository(name)
    name = name.to_s
    begin
      repositories = self.config["repositories"][Rails.env]
      repository = repositories[name]
      return nil unless repository
    rescue
      raise StandardError, %Q(Invalid or absent configuration for repositories in "#{Rails.env}", please check your config/talia3.yml file)
    end

    case repository['type']
      when nil then raise StandardError, "Repository #{name} not configured"
      when 'sesame' then
        unless repository['location']
          raise StandardError, "No location defined, please check config/talia3.yml configuration file"
        end
        RDF::Sesame::Repository.new repository['location']

      # TODO: support for repositoris of type "file"
      when "file" then
        raise NotImplementedError, 'Repositories of "file" type are a TODO'

      # TODO: support for repositoris of type "memory"
      when "memory" then
        raise NotImplementedError, 'Repositories of "memory" type are a TODO'

      else
        raise StandardError, %Q(Unknown repository type "#{repository['type']}")
    end
  end

  ##
  # Reimplements constant missing to allow for dynamic classes like
  # Talia3::FOAF::Person.
  #
  # Note that the Rails auto-load feature for Talia3 classes and
  # modules still works and has priority, you won't get what you
  # expect if the requested class already exists. This means, though,
  # that you can always override dynamic classes by creating their
  # model file.
  #
  # @private
  # @param [Symbol] const the missing constant, in the description example
  #   that would be "FOAF"
  # @return [Class] a anonymous, intermediate class that will resolve
  #   the second constant
  #
  def self.const_missing(constant)
    begin
      super(constant)
    rescue NameError
      unless Talia3::N.namespace? constant.to_s.downcase.to_sym
        raise 
      else
        namespace = eval "Talia3::N::#{constant}"
        klass = Class.new
        klass.class_eval do
          cattr_accessor :namespace
          def self.const_missing(constant)
            Talia3::Record.class_for(namespace.__send__ constant)
          end
        end
        klass.namespace = namespace
        const_set constant, klass
      end
    end
  end
end

require 'talia3/engine'
require 'talia3/repositories'
require 'talia3/label'
require 'talia3/uri'
require 'talia3/namespace'
#require 'talia3/sparql/queries'
require 'talia3/core_ext/string.rb'
require 'talia3/core_ext/symbol.rb'
# FIXME: workaround for rdfxml missing parameter
require 'talia3/rdf_ext/xmlrdf_reader.rb'
