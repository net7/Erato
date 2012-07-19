# (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# Extends RDF::URI with methods useful for Talia3
#
# URI format check, for one...
#
# Also allows to convert an URI to a attribute-name-like string
# representation and do the opposite.
#
# @example Get a field name from a URI:
#     uri        = Talia3::URI.new('http://xmlns.com/foaf/0.1/name')
#     uri.to_key
#     # => "foaf__name"
#
# @example Get a uri from a field name:
#     uri = Talia3::URI.from_key("foaf__name")
#     # => #<Talia3::URI:0x...(http://xmlns.com/foaf/0.1/name)>
#
# @todo Examples for all the other utility methods (#labels, #to_class, etc.).
#
class Talia3::URI < RDF::URI

  ##
  # Generates an URI using the provided namespace as base.
  #
  # Namespace defaults to local if not provided.
  # @param[RDF::URI, String] namespace defaults to Talia3::N::LOCAL
  # @return [Talia3::URI]
  # @todo Probably not unique enough...
  def self.unique(namespace=nil)
    namespace = Talia3::N::LOCAL.to_s if namespace.blank?
    Talia3::URI.new "#{namespace.to_s}_#{Time.now.to_f.to_s.gsub('.','')}"
  end

  ##
  # Creates a new URI object.
  #
  # Argument can be another URI class (RDF::URI, Talia3::URI), a
  # string or a symbol. A Symbol is converted to a URI via the
  # {self.from_key} method.
  #
  # @param [RDF::URI, String, Symbol] uri
  # @return [Talia3::URI]
  # @raise ArgumentError if the URI is invalid and exception is true
  def initialize(uri)
    uri = self.class.from_key(uri) if uri.is_a? Symbol or (uri.is_a? String and self.class.is_key? uri)
    raise ArgumentError, "Invalid URI: #{uri.inspect}" if uri.nil? or not self.class.valid? uri
    super uri.to_s
  end

  ##
  # Returns the URI as a URL-encoded string that can be used as parameter in URL querystrings.
  #
  # In particular this can safely be used as a parameter for Rails routes.
  # @return [String]
  def url_encoded
    ::URI.escape(to_s, /[^[:alnum:]]/)
  end
  alias_method :to_param, :url_encoded

  ##
  # Creates a new URI from a attribute-name-like string.
  #
  # Conversion rule is:
  #     *namespace*__*field name*
  #     converts to:
  #     *namespace*:*field name*
  #
  # @param [Symbol, String] key
  # @return [RDF::URI, nil] returns nil if the namespace is
  #   unknown. 
  def self.from_key(key)
    if valid_key? key
      self.from_string(key, '__')
    elsif valid_string? key
      self.new(key.to_s)
    else
      raise ArgumentError, "Invalid key: #{key.inspect}"
    end
  end

  ##
  # Creates a new URI from a string representing its short form.
  #
  # @param [Symbol, String] short
  # @return [RDF::URI, nil] returns nil if the namespace is
  #   unknown. 
  def self.from_short(short)
    self.from_string(short, ':')
  end

  ##
  # Creates a new URI from a string representing its short form as "underscored".
  #
  # This is useful when ducktyping for ActiveRecord.
  #
  # @param [String] name
  # @return [RDF::URI, nil] returns nil if the namespace is
  #   unknown. 
  def self.from_table(name)
    elements = name.to_s.split('_')
    return nil if elements.size < 2
    prefix = elements[0].upcase
    local_name = elements[1..-1].join('_').camelize
    "Talia3::N::#{prefix}".constantize.__send__ local_name.to_sym
  rescue
    nil
  end

  ##
  # Generic method to obtain an URI from a string given a separator
  # between its namespace and local_name.
  #
  # @param [String] string
  # @param [String] separator
  # @return [RDF::URI, nil] returns nil if the namespace is
  #   unknown. 
  def self.from_string(string, separator=':')
    elements = string.to_s.split(separator)
    return nil if elements.size < 2
    prefix = elements[0]
    local_name = elements[1]
    Talia3::N.namespace?(prefix.to_sym) ? "Talia3::N::#{prefix.upcase}".constantize.__send__(local_name.to_sym) : nil
  rescue
    nil
  end
  
  ##
  # Returns true if the value can represent an URI.
  #
  # A valid key is either a symbol or string in the form "xxx__yyy",
  # where xxx is the short form for a namespace (i.e. "foaf", "rdfs")
  # and yyy is the local name.
  #
  # @param [Symbol, String]
  # @return [Boolean]
  def self.is_key?(value)
    valid_key? value
  end

  ##
  # Returns the short form of the URI, for example "foaf:Person".
  #
  # Requires the URI namespace to be known by Talia3::Namespace. If it
  # is not the case the full URL will be returned.
  #
  # @return [String]
  def short
    return to_s if prefix.blank? or local_name.blank?
    "#{prefix.downcase}:#{local_name}"
  end

  ##
  # Returns the labels assigned to this URI.
  #
  # Labels literals assigned by statements like [<uri>, rdfs:label,
  # <label>]
  #
  # Talia3 uses the :none symbol for language if the label has no language.
  #
  # @param [RDF::Repository] repository optional, Talia3 default repository is used otherwise.
  # @return [Hash] a Hash whose keys are Symbols for the language and the value is the label string.
  def labels(repository=nil)
    r = repository.nil? ? Talia3.repository : repository
    @labels ||= Hash[r.query([self, Talia3::N::RDFS.label]).map do |s|
        if s.object.literal?
          [s.object.language || :none, s.object.to_s]
        end
      end.compact]
  end

  ##
  # Returns Rails-friendly, attribute-name-like version of itself.
  #
  # Conversion rule is:
  #     *namespace*:*field name*
  #     converts to:
  #     *namespace*__*field name*
  #
  # @return [Symbol]
  def to_key
    return to_s.to_sym if prefix.blank? or local_name.blank?
    "#{prefix}__#{local_name}".to_sym
  end
  alias_method :to_sym, :to_key

  def to_table
    "#{prefix.downcase}_#{local_name.underscore}".to_sym
  end

  def to_class
    Talia3::Record.class_for self
  end

  def to_class_name
    "Talia3::#{prefix.upcase}::#{local_name.capitalize}"
  end

  def class_defined?
    Talia3.const_defined? prefix.upcase and "Talia3::#{prefix.upcase}".constantize.const_defined? local_name.capitalize
  end

  ##
  # Returns this URI's information in json format.
  #
  def as_json(options={})
    {:url => to_s, :short => short}
  end

  ##
  # The namespace prefix of this URI.
  #
  # @return [String]
  def prefix
    Talia3::N.prefix to_s
  end

  ##
  # The local name part of the URI.
  #
  # @return [String]
  def local_name
    Talia3::N.local_name to_s
  end

  def namespace
    if Talia3::N.namespace(to_s).present?
      Talia3::N.namespace(to_s)
    else
      to_s.match(/^(.*[#\/])([^#\/]+)/) {|match| return match[1]}
    end
  end

  ##
  # Returns true if the URI is valid.
  #
  # @param [RDF::URI, String] uri
  # @return [Boolean]
  # @see self#valid?
  def valid?(uri)
    self.class.valid? uri
  end

  ##
  # Returns true if the URI is valid.
  #
  # @param [RDF::URI, String] uri
  # @return [Boolean]
  def self.valid?(uri)
    # Hook to RDF::URI validation in case 
    # that is implemented someday.
    begin
      RDF::URI.new(uri).validate!
    rescue
      return false
    end
    case uri
    when RDF::URI, String then ;
    when RDF::Literal then return false unless uri.respond_to? :to_s
    else return false
    end
    # TODO: better regexp
    #       a possibility could be here:
    #       http://snipplr.com/view/6889/regular-expressions-for-uri-validationparsing/
    valid_string? uri.to_s
  end

  def self.valid_key?(key)
    key.to_s =~ /^[^_:]+__.+/
  end

  def self.valid_string?(string)
    string.to_s.start_with?('mailto:') or (string.to_s =~ /:\/\//) != nil
  end

  ##
  # Makes a HTTP GET request using this URI as URL and returns the response body.
  #
  # @todo refactor with the other import methods, using rdf.rb support.
  #   There should be only one method for this!!!
  #
  # @param [String] accept_header optional, will be used in the request header
  # @param [Fixnum] redirect_limit optional, used internally to avoid redirect loops
  # @return [String] The requests body
  # @raise [Net::HTTPClientError]
  # @raise [ArgumentError] if there are problem resolving the URI
  def fetch(accept_header='text/plain', redirect_limit=10, escape_uri = true)
    raise ArgumentError, 'HTTP redirect too deep' if redirect_limit == 0
    begin
      url = ::URI.parse(escape_uri ? ::URI.escape(to_s) : to_s)
      Rails.logger.info('Here: '+escape_uri.to_s+" "+url.inspect);
      ::Net::HTTP.start url.host, url.port do |http|
        response = http.get url.request_uri, {'Accept' => accept_header}

        case response
        when Net::HTTPSuccess then response.body
        #when Net::HTTPRedirection then ::URI.decode(response['location']).to_uri.fetch(accept_header, redirect_limit - 1,escape_uri)
        when Net::HTTPRedirection then response['location'].to_uri.fetch(accept_header, redirect_limit - 1,escape_uri)
        when Net::HTTPClientError then response.error!
        else raise ::ArgumentError, "Unexpected response from '#{to_s}'"
        end
      end
    rescue SocketError
      raise ::ArgumentError, "Cannot resolve address '#{to_s}'"
    end
  end
end # class Talia3::URI
