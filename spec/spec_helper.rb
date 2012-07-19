require 'rdf'
require 'rdf/sparql'
require 'rdf/sesame'
require 'rdf/spec'

RSpec.configure do |config|
  config.include(RDF::Spec::Matchers)
  config.exclusion_filter = {:ruby => lambda { |version|
      RUBY_VERSION.to_s !~ /^#{version}/
    }}
end
