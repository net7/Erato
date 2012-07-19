# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# = Mixin for classes that can store statements.
#
# @author Riccardo Giomi <giomi@netseven.it>
# @todo describe #- method including pattern-like statements.
#
# This is a wrapper for an {RDF::Repository} in memory.
# All the methods defined allow an object to act more or less like a
# {RDF::Graph} without a fixed context  (see {HasNamedGraph} for that).
#
# @example Retrieving the graph:
#   has_graph.graph
#
# @example Adding statements:
#   has_graph << [Talia3::N::LOCAL.uri, RDF.type, Talia3::N::EX.type, Talia3::N::CONTEXTS.public]
#   has_graph2 << has_graph
#   has_graph2 + has_graph (<< and + are equivalent for HasGraph objects)
#
# @example Removing statements:
#   has_graph - [Talia3::N::LOCAL.uri, RDF.type, Talia3::N::EX.type, Talia3::N::CONTEXTS.public]
#   has_graph - has_graph2
#
# @example Overwrite all the statements (by assigning a new graph or
#   HasGraph object):
#   has_graph2 = has_graph
#
# @example Iterate over statements:
#   has_graph.each {|statement| puts statement.inspect}
#
# @example Querying and working with results:
#   result = has_graph.query([Talia3::N::LOCAL.uri, nil, nil])each do |statement|
#     pp statement
#   }
#   result.size
#
# @example Get first statement:
#   has_graph.first
# 
# @example Statements count:
#   has_graph.size
#   has_graph.count
#   has_graph.empty?
#
# @example Removing all statements:
#   has_graph.clear
#
# @example Saving the statements in a repository
#    has_graph.save_graph!(Talia3.repository(:local))
#
# @example Removing the statements from a repository
#    has_graph.delete_from_repository!(Talia3.repository(:local))
#
module Talia3::Mixin::HasGraph
  delegate :size, :empty?, :each, :query, :first, :to => :graph
  alias_method :count, :size

  ##
  # Returns all the statements as an RDF::Graph.
  #
  # @return [RDF::Repository] The statements container.
  def graph
    @graph ||= new_graph
  end

  ##
  # Deletes all the statements.
  #
  # @return [Talia3::Mixin::HasGraph] self (chainable)
  def clear_graph
    @graph = new_graph
    self
  end
  alias_method :clear, :clear_graph

  ##
  # Overwrites the current statements with ones from the argument.
  #
  # @param [#graph, RDF::Enumerable] Any statement container
  # @return [#graph, RDF::Enumerable] The argument.
  # @raise [ArgumentError] When argument is not a valid container
  def graph=(object)
    return clear_graph if object.nil?
    return self.graph = object.graph if object.respond_to? :graph
    if valid_class(object.class)
      clear_graph
      merge_graph object
    else 
      raise ArgumentError, "Argument of class #{object.class} is not a valid graph."
    end
    object
  end

  ##
  # Imports data from a RDF string.
  #
  # @todo refactor with the other import methods, using rdf.rb support.
  #   There should be only one method for this!!!
  # @todo move into a dedicated mixin, Talia3::Mixin::RDFImportable?
  # @todo refactor considering {self.read} and {Talia3::Resource.import_file}
  # @params [String] rdf the string containing the RDF triples
  # @params [Symbol, String] format optional, defaults to RDF/XML for now
  # @return [Talia3::Resource]
  # @raise [ArgumentError] for an invalid format or a missing RDF.rb reader class.
  def import_rdf(rdf, format=:rdfxml)
    #Rails.logger.info("PARAMS: #{rdf}")
    raise ArgumentError, "no RDF::Reader for specified file" unless reader = RDF::Reader.for(format)
    reader.new(rdf) do |r|
      r.each_statement do |s|
        self << s
      end
    end
    #abort(self.all_properties.inspect())
    self
  end

  ##
  # Imports data from a RDF file.
  #
  # @note Does not save in the repository.
  # @todo Add support for more formats.
  # @todo refactor considering {self.read} and {Talia3::Resource.import_rdf}
  # @todo bug in RDF::Reader#open investigate!
  # @params [String] filename
  # @params [String, Symbol] format optional, defaults to RDF/XML for now
  # @return [Talia3::Resource]
  # @raise [ArgumentError] for an invalid format or a missing RDF.rb reader class.
  def import_file(filename, format=nil)
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
          self.graph << s
        end
      end
    end
    true
  end

  ##
  # Adds one or more statements.
  #
  # @note Thanks to RDF.rb, any array object representing a triple
  # or quad is internally converted to a RDF::Statement.
  #
  # @param [#graph, RDF::Enumerable, RDF::Statement, Array] Any viable statement or statement container
  # @return [#graph, RDF::Enumerable, RDF::Statement, Array] The argument.
  # @raise [ArgumentError] When argument is not a valid container
  def <<(object)
    return self << object.graph if object.respond_to? :graph
    return self + object        if valid_class object.class
    add_statement object
  end

  ##
  # Merges two statement containers.
  #
  # @param [#graph, RDF::Enumerable] Any statement container
  # @return [Talia3::Mixin::HasGraph] self (chainable)
  # @raise [ArgumentError] When argument is not a valid container
  def +(object)
    return merge_graph object.graph if object.respond_to? :graph
    unless valid_class object.class
      raise ArgumentError, "Argument of class #{object.class} is not a valid graph."
    end
    merge_graph object
  end

  ##
  # Removes statements.
  #
  # Argument can be either a statement or a statement container. A
  # statement found in the argument is removed from the graph. 
  #
  # @note An Array is interpreted like a statement, and **not** like
  #   a container.
  #
  # @note Works with incomplete, "pattern-like" statements:
  #   graph - [*subject*, *predicate*] will delete all triples with
  #   the given subject and predicate. You can use nil to "pad"
  #   them: [*subject*, nil, *object*] will work.
  #
  # @param [#graph, RDF::Enumerable, RDF::Statement, Array] Any
  #   viable statement or statement container
  # @return [Talia3::Mixin::HasGraph] self (chainable)
  def -(object)
    object = object.graph if object.respond_to? :graph
    object.each {|statement| graph.delete(statement)} if valid_class object.class
    graph.delete(object)
    self
  end

  ##
  # Merges statements from another graph.
  #
  # @param [RDF::Graph, RDF::Repository]
  # @return [Talia3::Mixin::HasGraph] self (chainable)
  # @private
  def merge_graph(graph)
    graph.each {|statement| add_statement statement}
    self
  end

  ##
  # Saves statements in a repository.
  #
  # Configured repositories can be obtained easily with
  # Talia3#repository.
  #
  # @param [RDF::Repository] the repository to save in.
  # @return [Talia3::Mixin::HasGraph] self (chainable)
  # @raise [ArgumentError] if argument is an invalid repository
  # @raise [Exception] if repository is read-only
  def save_graph!(repository)
    raise ArgumentError, "No repository chosen" if repository.nil?
    raise ArgumentError, "Argument must be a RDF::Repository, #{repository.class} given" unless repository.is_a? RDF::Repository
    raise Exception, "Repository is read-only" unless repository.writable?
    repository << graph
    self
  end

  ##
  # Deletes the statements from a repository.
  #
  # Any statement currently present in the graph will be deleted
  # from the repository, if present. 
  #
  # @note Does not clear the local statements
  #
  # @param [RDF::Repository] the repository to save in.
  # @return [Talia3::Mixin::HasGraph] self (chainable)
  # @raise [ArgumentError] if argument is an invalid repository
  # @raise [Exception] if repository is read-only
  def delete_from_repository!(repository)
    raise ArgumentError, "No repository chosen" if repository.nil?
    raise ArgumentError, "Argument must be a RDF::Repository, #{repository.class} given" unless repository.is_a? RDF::Repository
    raise Exception, "Repository is read-only" unless repository.mutable?
    repository.delete(graph)
    self
  end

  private
  ##
  # Adds a statement.
  #
  # @private
  # @param [RDF::Statement, Array]
  # @return [Talia3::Mixin::HasGraph] self (chainable)
  # @raise [ArgumentError] for invalid statement arguments
  def add_statement(statement)
    begin
      format_statement statement if statement.is_a? RDF::Statement
      format_array     statement if statement.is_a? Array
      self.graph << statement
    rescue ArgumentError
      raise ArgumentError, "Cannot treat argument as a graph or statement: #{statement.inspect}"
    end
    self
  end

  ## 
  # Checks if the argument class is viable for use as a graph.
  #
  # Can be overridden by a child class that uses different
  # implementations for the statements container.
  #
  # @private
  # @param [Class] klass
  # @return [Boolean] whether the klass is valid
  def valid_class(klass)
    (klass == RDF::Repository or klass == RDF::Graph)
  end

  ##
  # Returns a new graph.
  #
  # Can be overridden by a child class that uses different
  # implementations for the statements container.
  #
  # @private
  # @return [RDF::Repository]
  def new_graph
    RDF::Repository.new
  end

  def format_statement(statement)
    statement.subject   = Talia3::URI.new(statement.subject)    if statement.subject.class == RDF::URI
    statement.predicate = Talia3::URI.new(statement.predicate) if statement.predicate.class == RDF::URI
    statement.object    = Talia3::URI.new(statement.object)    if statement.object.class == RDF::URI
  end

  def format_array(array)
    [0,1,2].each do |i|
      array[i] = Talia3::URI.new(array[i]) if array[i].class == RDF::URI
    end
  end
  # end private
end # module Talia3::Mixin::HasGraph
