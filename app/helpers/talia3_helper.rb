module Talia3Helper
  # @group URI helpers

  ##
  # Returns a list of labels for a URI as present in the local repository.
  #
  # @param [RDF::URI, Symbol, String] uri A valid URI representation.
  # @param [RDF::Repository] repository optional looks up labels on a different repository
  # @return [Array<Talia3::Label>] A list of labels with language information
  def talia3_uri_labels(uri, repository=nil)
    uri = Talia3::URI.new uri
    return [Talia3::Label.new(:none, uri.to_s || "")] unless uri.respond_to? :labels
    Talia3::Label.collect uri.labels(repository)
  end # def talia3_uri_labels
end # module Talia3Helper
