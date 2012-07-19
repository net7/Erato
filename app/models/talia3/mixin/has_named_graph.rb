# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

## 
# = Mixin for classes that can store statements with a fixed context.
#
# @author Riccardo Giomi <giomi@netseven.it>
#
# This is a wrapper for an {RDF::Graph}.
#
# The main difference with {Talia3::Mixin::HasGraph} is that that the statements
# container has a single context. <b>Any statement added to this graph
# will have the context changed accordingly.</b>
#
# Unless instructed otherwise all named graphs will default to the :public context,
# as defined in the talia3.yml configuration file.
#
# New class method #set_context also allows to declare the default
# context for all objects of this class.
#
# *Important*: Changing the context of an object, clears that object statements.
#
# *Important*: While Talia3 support RDF.rb's RDF::URI objects,
#              use of Talia3::URI should be preferred.
#
# @example Setting the default context for all HasNamedGraphClass objects:
#   HasNamedGraphClass.set_context("http://example.org/context")
#   HasNamedGraphClass.set_context(Talia3::URI.new("http://example.org/context"))
#   HasNamedGraphClass.set_context(Talia3::N::CONTEXTS.ontology)
#
# @example If a symbol is used when setting a context, it will be converted internally in Talia3::N::CONTEXTS._symbol.to_s_:
#   HasNamedGraphClass.set_context(:public)
#   is equivalent to
#   HasNamedGraphClass.set_context(Talia3::N::CONTEXTS.public)
#
# @example To set the context to nil use the symbol :null (Still valid?)
#   HasNamedGraphClass.set_context(:null)
#   has_named_graph.context = :null
#
# @example Best use for set_context is in class declaration:
#   class HasNamedGraphClass
#     include Talia3:HasNamedGraph
#     set_context :public
#     def initialize
#       self.context = self.class.context
#       #...
#     end
#   end
#
# @example Getting the current default context:
#   HasNamedGraphClass.context.to_s
#   #=> "http://example.org/context"
#
# @example Getting an object context:
#   HasNamedGraphClass.new.context.to_s
#   #=> "http://example.org/context"
#   
# @example Setting an object context:
#   has_named_graph.context = :public
#   has_named_graph.context = "http://example.org/context"
#   has_named_graph.context = Talia3::URI.new("http://example.org/context")
#   has_named_graph.context = Talia3::N::CONTEXTS.ontology
#
# @example Deleting all statements with our context from a repository:
#   has_named_graph.context = :public
#   has_named_graph.cleanse_context!(Talia3.repository)
#
# @example Deleting all statements with a given uri and our context from a repository:
#   has_named_graph.context = :public
#   has_named_graph.cleanse_uri!(Talia3::N::LOCAL.uri, Talia3.repository)
module Talia3::Mixin::HasNamedGraph
  include Talia3::Mixin::HasGraph
  delegate :context, :to => :graph

  ##
  # @private
  def self.included(base)
    base.extend ClassMethods
  end

  ##
  # Adds methods to the class to allow for shared context information.
  module ClassMethods
    ##
    # Returns the current default context for objects of this class.
    #
    # @return [Talia3::URI]
    def context
      return nil if @context.is_a? Symbol and @context == :null
      @context || format_context(:public)
    end

    ##
    # Sets the default context for new objects of this class.
    #
    # @note Use :null to set the context to nil
    #
    # @note  If the argument is a symbol, except for :null, 
    # Talia3::Namespace::CONTEXTS.<argument> is used to
    # generate the context URI.
    #
    # @param [String, Talia3::URI, Symbol, RDF::URI] any valid context URI
    #   representation
    # @return [Class] self (chainable)
    def set_context(context)
      context = format_context context
      @context = context.nil? ? :null : context
      self
    end

    ## 
    # Converts a context URI representation to a Talia3::URI.
    #
    # @note Use :null to set the context to nil
    #
    # @private
    # @param [String, Talia3::URI, Symbol, RDF::URI] any valid context URI
    #   representation 
    # @return [Talia3::URI]
    # @raise [ArgumentError] if the argument is not a valid URI.
    def format_context(context)
      return nil if context.nil? or (context.is_a?(Symbol) and context == :null)
      case context
      when Symbol then Talia3::N::CONTEXTS.__send__ context
      else Talia3::URI.new context
      end
    end

    ##
    # Removes all statements from the indicated repository and context.
    #
    # Works regardless of statements currently present in the graph.
    # Statements are *not* cleared if present.
    #
    # +repository+ can be omitted if the class responds to
    # #repository (includes {Talia3::Mixin::HasRepositories}).
    #
    # if +context+ is omitted self.context is used.
    #
    # @param [RDF::Repository] repository optional if object
    #   responds to {Talia3::Mixin::HasRepositories#repository}
    # @param [RDF::URI, String, Symbol] context optional if nil, self.context is used
    # @return [RDF::HasNamedGraph] self (chainable)
    # @raise [ArgumentError] if argument is an invalid repository
    # @raise [Exception] if repository is read-only
    def cleanse_context!(repository=nil, context=nil)
      context = self.context if context.nil?
      repository = self.repository if repository.nil? and self.respond_to? :repository
      raise ArgumentError, "No repository chosen" if repository.nil?
      raise ArgumentError, "No context chosen" if context.nil?
      raise ArgumentError, "Argument must be a RDF::Repository, #{repository.class} given" unless repository.is_a? RDF::Repository
      raise Exception, "Repository is read-only" unless repository.mutable?
      pattern = RDF::Query::Pattern.new nil, nil, nil
      pattern.context = context unless context.nil?
      repository.delete(pattern)
      self
    end
  end # module ClassMethods

  ##
  # Sets the context.
  #
  # @note Changing the context clears the current statements.
  # @param [Talia3::RDF, RDF::URI] the new context's URI
  # @return the argument
  def context=(context)
    clear_graph if graph.size # TODO: would it be better to change context to triples? How?
    graph.context = self.class.format_context context
    context
  end

  ##
  # Removes all statements with our context from the given repository.
  #
  # Works regardless of statements currently present in the graph.
  # Statements are *not* cleared if present.
  #
  # +repository+ can be omitted if the object responds to
  # #repository (includes {Talia3::Mixin::HasRepositories}).
  #
  # @param [optional, RDF::Repository] repository optional if object
  #   responds to {Talia3::Mixin::HasRepositories#repository}
  # @return [RDF::HasNamedGraph] self (chainable)
  # @raise [ArgumentError] if argument is an invalid repository
  # @raise [Exception] if repository is read-only
  def cleanse_context!(repository=nil)
    repository = self.repository if repository.nil? and self.respond_to? :repository
    context    = self.context if context.nil?
    self.class.cleanse_context! repository, context
    self
  end


  ##
  # Removes all statements that have the given URI as subject or
  # predicate from the given repository.
  #
  # Works regardless of statements currently present in the graph.
  # Statements are *not* cleared if present.
  #
  # +uri+ can be omitted if the object responds to
  # #uri
  #
  # +repository+ can be omitted if the object responds to
  # #repository (includes {HasRepositories}).
  # 
  # @param [optional, Talia3::URI, RDF::URI] uri optional if object responds to #uri
  # @param [optional, RDF::Repository] repository  optional if
  #   object responds to {HasRepositories#repository}
  # @return [RDF::HasNamedGraph] self (chainable)
  # @raise [ArgumentError] if an argument is invalid
  # @raise [Exception] if repository is read-only
  # @todo better URI validation.
  def cleanse_uri!(uri=nil, repository=nil)
    uri = self.uri if uri.nil? and self.respond_to? :uri
    repository = self.repository if repository.nil? and self.respond_to? :repository
    raise ArgumentError, "Invalud uri argument" unless uri.is_a? RDF::URI or !uri.to_s.empty?
    raise ArgumentError, "No repository chosen" if repository.nil?
    raise ArgumentError, "Argument must be a RDF::Repository, #{repository.class} given" unless repository.is_a? RDF::Repository
    raise Exception, "Repository is read-only" unless repository.mutable?
    patterns = [
                RDF::Query::Pattern.new(uri, nil, nil, :context => self.context),
                RDF::Query::Pattern.new(nil, nil, uri, :context => self.context)
               ] 
    repository.delete(*patterns)
    self
  end

  private
  ##
  # (see Talia3::Mixin::HasGraph#valid_class)
  # @return [RDF::Graph]
  def valid_class(klass)
    klass == RDF::Graph
  end

  ##
  # (see Talia3::Mixin::HasGraph#new_graph)
  # @return [RDF::Graph]
  def new_graph
    old_context = @graph.context if @graph
    RDF::Graph.new old_context
  end
  # end private
end # module Talia3::Mixin::HasNamedGraph
