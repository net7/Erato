require 'net/http'
require 'rdf/ntriples'
require 'rdf/repository'

module RDF
  module SPARQL
    autoload :Query,      'rdf/sparql/query'
    autoload :Repository, 'rdf/sparql/repository'
    autoload :Client,     'rdf/sparql/client'
    autoload :VERSION,    'rdf/sparql/version'
  end
end
