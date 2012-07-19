require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/repository'

describe RDF::Sesame::Repository do
  before :each do
    @url        = RDF::URI(ENV['SESAME_URL'] || "http://localhost:8080/openrdf-sesame/repositories/test")
    @repository = RDF::Sesame::Repository.new @url
    @repository.clear
  end

  context "when tested" do
    after :each do
      @repository.clear
    end

    # @see lib/rdf/spec/repository.rb in rdf-spec
    it_should_behave_like RDF_Repository
  end
end
