Changes to RDF library
======================

RDF::SPARQL
-----------
This is a complete copy and rehaul of the sparql-client code.
Changes include:
* Added support for contextes.
* RDF::SPARQL::Query Allows to create a string sparql query using the
  old sparql-client methods. It also accepts RDF::Query and
  RDF::Patterns as parameters.
* BGP patterns better translated in SPARQL.
* RDF::SPARQL::Repository should be a proper RDF.rb
  Repository. Extend to have SPARQL-endpoints support in other
  repositories. See my version of RDF::Sesame::Repository for an
  example. You will need to extend RDF::SPARQL::Client to have more
  options when connecting to the server though. See
  RDF::Sesame::Server as an example.
* implements? :sparql => true

RDF::Sesame
-----------
Some changes to the original rdf-sesame code.
* RDF::Sesame::Repository now extends RDF::SPARQL::Repository, and
  RDF::Sesame::Server extends RDF::SPARQL::Client.
* This means sparql support sparql-client-like but also via
  RDF::Repository#query.
* Unfortunately the possibility to use a single server for more than
  one repository is kinda lost. This was needed to keep the
  repository.client functionalities. All queries to the repository
  still work though.
* Bulk insert when using insert_statements
* implements #delete_pattern that uses subj, pred and obj DELETE parameters to
  delete groups of triples in one request.
  E.g.: RDF::Sesame::Repository.new(<repo>).delete_pattern [<uri>, nil, nil, <c>]
  would delete all triples with <uri> as subject in context <c> in one http request.
