# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# @todo description and examples here.
# @todo remember ActiveModel stuff: Dirty, Validations, callbacks
#   and so on.
# @todo note how #[] and #[]= are different because #attribute and
#   #set_attribute are rewritten.
#
# @todo A record *requires* a uri before you can read or write
#   attributes, it this a problem for ActiveModel?
#
# @note ActiveModel::AttributeMethods uses some of the same tricks
#   and methods that I use for dynamic attributes. For this reason,
#   Talia3::Record **does not** support
#   ActiveModel::AttributeMethods as its features are overwritten by
#   Talia3's.
#
# @note On the same note, ActiveModel::Dirty features might not work
#   100% correctly as its interface with
#   ActiveModel::AttributeMethods had to be rewritten and something
#   could have been missed.
class Talia3::Record < Talia3::Resource
  #set_context :public

  include Talia3::Record::ActiveModelImplementation
  include Talia3::Record::ActiveRecordImplementation

  # The following should be in Talia3::Record::ActiveModelImplementation
  # unfortunately they don't like it there...
  # Please consider the following four lines as being in the *other* file.
  extend ActiveModel::Callbacks
  include ActiveModel::Dirty
  define_model_callbacks :create, :save, :update, :delete
  include ActiveModel::Validations

  # @todo See if this can be moved in record/active_model_implementation.rb
  def self.model_name
    unless type.nil?
      @_model_name ||= ActiveModel::Name.new Struct.new(:name).new(type.to_class_name)
    else
      super
    end
  end

  # include Talia3::Record::ActiveModelImplementation

  ##
  # Returns a ActiveRecord-like table name for this class.
  #
  # @example Works with dynamic classes as well:
  #   Talia3::FOAF::Person.table_name
  #   #=> "foaf_person"
  #
  # @return [String]
  def self.table_name
    (name.underscore.split('/')[1..-1] * '_').to_sym
  end
  
  ##
  # Records are are rigid by default when considering 
  # schema constraints. May be changed via configuration.
  strict_schema unless Talia3.config :loose_schema

  # Basic validations for records.
  # @todo add uri format validation via Talia3::URI#valid?
  validates :uri, :presence => true
  validates :type, :presence => true

  ##
  # Creates a new Record object.
  #
  # @note You probably won't want to use this method, but use the
  #   dynamic class generation feature of Talia3.
  #
  # @todo Possibly change arguments so that you can use new({*attributes*})?
  # @param [Hash, Talia3::URI, RDF::URI] uri_or_param the resource URI or an hash of values to set.
  # @param [nil] options *ignored*
  # @return [Talia3::Record]
  def initialize(uri_or_params=nil, options=nil)
    @errors = ActiveModel::Errors.new(self)
    # TODO: use this somehow if present? Atm just avoiding it to generate an error.
    uri_or_params.delete :type if uri_or_params.is_a?(Hash)
    new_uri = uri_or_params.is_a?(Hash) ? uri_or_params.delete(:uri) : uri_or_params
    super make_uri(new_uri)
    fill_from_params(uri_or_params) if uri_or_params.is_a?(Hash)
  end

  def self.from_type(type)
    eval(Talia3::URI.new(type).to_class_name)
  end

  def self.create(attributes)
    raise Exception, "No type for this class" if self.type.nil?
    self.from_type(self.type).fill_from_params attributes
  end

  def update_attributes(attributes)
    fill_from_params attributes
    save
  end

  ##
  # (see Talia3::Resource#set_attribute)
  # @note Adds support for ActiveModel::Dirty for schema-defined attributes
  def set_attribute(name, value)
    name = Talia3::URI.new name
    if attributes.include?(name.to_key) and not attribute(name) == value
      attribute_will_change! name.to_key
    end
    super name, value
  end

  def id
    self.to_key.nil? ? nil : self.to_key.first
  end


  ##
  # (see Talia3::Resource#type)
  # @note overwritten from Talia3::Resource to account for
  #   class-defined type.
  def type
    return @type = self.class.type if @type.nil? and not self.class == Talia3::Record
    super
  end

  def create
    run_callbacks :create do
    end
  end

  ##
  # Saves the record.
  #
  # Implements callbacks and ActiveModel::Dirty#previous_changes.
  #
  # @todo implement options (validations for one).
  # @see Talia3::Resource#save
  # @param [Hash] options optional TODO!
  # @return [Talia3::Record] self
  def save(options={})
    run_callbacks :save do
      @previously_changed = changes
      @changed_attributes.clear
      save!
    end
    self
  end
  
  ##
  # Updates the record.
  #
  # As there is no difference between saved and updated records for
  # Talia3::Records, this is the same as #save!.
  # The distinction could be useful to use different callbacks
  # though.
  #
  # @return [Talia3::Record] self
  def update!
    run_callbacks :update do
      @previously_changed = changes
      @changed_attributes.clear
      super
    end
    self
  end
  alias_method :update, :update!

  def delete
    run_callbacks :delete do
      delete!
    end
  end
  alias :destroy :delete

  ##
  # Adds dynamic methods to the list of methods an instance responds
  # to.
  #
  # @private
  # @param [Symbol] method
  # @return [Boolean]
  def respond_to?(method)
    method = (method.to_s =~ /=$/) ? method.to_s[0..-2].to_sym : method
    super method or attributes.include? method
  end

  private

    def fill_from_params(params)
      params.each {|name, value| set_attribute name.to_sym, value}
    end

    ##
    # Creates and returns a dynamic class for the required type.
    #
    # Returns *self* if the type is nil.
    # A constant for the new class is created as well.
    #
    # @example This will create and return a Talia3::FOAF::Person
    #   class:
    #    Talia3::Record.from_type Talia3::N::FOAF.Person
    #
    # @example This will return Talia3::Record (self):
    #    Talia3::Record.from_type nil
    #
    # @example This method is part of a larger, more intelligent
    #   system. This will also work:
    #     Talia3::FOAF::Person
    #
    # @private
    # @param [RDF::URI, String, nil] type a valid URI or nil
    # @return [Class]
    def self.class_for(type)
      # TODO: better!
      begin
        type = Talia3::URI.new type
      rescue
        return self
      end

      class_name = type.to_class_name
      return class_name.constantize if type.class_defined?

      eval <<-EOS
        class #{class_name} < Talia3::Record
          cattr_accessor :type
        end
      EOS

      klass = eval "#{class_name}"
      klass.type = type
      klass.strict_schema if strict_schema?
      klass
    end

    ##
    # Modified "method missing" handling that allows for dynamic
    # attributes.
    #
    # @todo There *MUST* be a better way to write this... Refactor!
    # @private
    def method_missing(*args)
      case args.size
      when 1
        return attribute args[0]                                    if attributes.include? args[0]
        return attribute_changed? args[0].to_s[0..-10].to_sym       if args[0].to_s =~ /_changed\?$/
        return attribute_change args[0].to_s[0..-8].to_sym          if args[0].to_s =~ /_change$/
        return attribute_was args[0].to_s[0..-5].to_sym             if args[0].to_s =~ /_was$/
        return reset_attribute args[0].to_s[6..args[0].size].to_sym if args[0].to_s =~ /^reset_/
      when 2
        if args[0].to_s =~ /=$/ and attributes.include? args[0].to_s[0..-2].to_sym
          set_attribute args[0].to_s[0..-2].to_sym, args[1]
          return args[1]
        end
      end
      super(*args)
    end

    def make_uri(new_uri)
      new_uri.nil? ? generate_unique_uri : new_uri
    end

    def generate_unique_uri
      Talia3::URI.unique.to_sym
    end
  #end private
end # class Talia3::Record
