# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# Talia3 Universal Form service controller.
#
# @todo Add error handling page with a user-friendly explanation and a back link.
# @todo Documentation and examples!
# @todo refactor everything!
class Talia3::Universal::ServiceController < Talia3::Universal::BaseController
  before_filter :querystring_handler, :except => [:label, :bnodes, :bnode_transform]

  attr_reader :querystring

  layout "talia3/universal", :except => [:label, :bnodes]

  ##
  # Shows a list of RDF types obtained from a sparql endpoint, with links to each type's list page.
  #
  def types
    render :status => 400, :inline => "Missing parameter: sparql." and return unless @source

    RDF::SPARQL::Repository.new(URI.escape @source) do |r|
      # @types is an Array of Talia3::URIs, BNodes and others are filtered out.
      @types = r.query(types_query).map do |s|
        Talia3::URI.new(s.type) rescue nil if s[:type] and s.type.uri?
      end.compact
    end

    rdfs_resource, owl_thing = @types.delete(Talia3::N::RDFS.Resource), @types.delete(Talia3::N::OWL.Thing)

    @untyped_present = rdfs_resource.present? || owl_thing.present?

    respond_to do |format|
      format.json {render :json => @types.to_json, :callback => params[:callback]}
      format.html
    end
  end # def types

  ##
  # Shows a list of URI of the requested RDF type with links to their own edit form.
  #
  def instances
    render :status => 400, :inline => "Missing or invalid parameter(s): sparql and/or type." and return unless @source
    @repository = RDF::SPARQL::Repository.new(URI.escape @source)
    @instances  = @repository.query(instances_query).map do |s|
      Talia3::URI.new(s.uri) rescue nil
    end.compact

    respond_to do |format|
      format.json {render :json => @instances.to_json, :callback => params[:callback]}
      format.html
    end
  end # def instances

  ##
  # Returns an edit form for new resources.
  #
  # Differently from DB forms, we will need an 'id' immediately (URI) 
  # and its value will be editable in the form.
  # An URI can be provided as a parameter, and used as the new resource's 'id'. Otherwise a 
  # random URI will be generated.
  # 
  # A namespace *must* be provided, it will be used to generate the base URL part of 
  # the new resource's URI
  #
  # A SPARQL *must be provided*, it will be used to confirm that the new URI is not already used.
  # It will also be used to gain ontology information about the resource's type.
  #
  # A type parameter can be optionally provided, otherwise the default owl:Thing will be used.
  def new
    render :status => 400, :inline => "Missing parameter: sparql." and return if @source.blank?
    render :status => 400, :inline => "Missing parameter: namespace." and return if @namespace.blank?
    @uri ||= Talia3::URI.unique @namespace

    @record = Talia3::Record.new(@uri)
    @record.type = @type
    # FIXME
    @record.raw_set(Talia3::N::RDF.type, Talia3::URI.new(@type)) if @type
	
    RDF::SPARQL::Repository.new(URI.escape @source) do |r|
      @instances = r.query(instances_query).map do |s|
        Talia3::URI.new(s.uri) rescue nil # B-Nodes and the like.
      end
    end
  end

  ##
  # Saves the new resource on 
  #
  # Sesame is the only repository supported for now.
  def create
    render :status => 400, :inline => "Missing parameter: uri." and return unless params[:uri]
    if params[:sparql] and uri_in_use? params[:uri], params[:sparql]
      render :status => 400, :inline => "New record's URI is already in use"
    else
      Talia3::Update.valid?(params[:update]) ? render_new_update : render_record
    end
  end

  ##
  # Returns an edit form for the required resource.
  #
  # URI param is used to identify the resource and fetch it from a LOD service.
  def edit
    render :status => 400, :inline => "Missing parameter: uri." and return unless @uri

    @record = unless params[:sparql].blank?
                Talia3::Record.from_sparql(params[:sparql], params[:uri])
              else
                Talia3::Record.from_lod(params[:uri])
              end

  rescue ArgumentError
    render :status => 400, :inline => "Could not resolve URI."
  end # def edit

  ##
  # Update action for the form service, currently this just shows the modified rdf in n3 (text) format.
  # @todo this is RDF-oriented only!!!
  #
  def update
    params[:update].blank? ? render_record : render_update
  end # def update

  def destroy
    render :status => 400, :inline => "Missing parameter: uri." and return if @uri.blank?
    render :status => 400, :inline => "Missing parameter: sparql." and return if @source.blank?

    @record = Talia3::Record.from_sparql(@source, @uri)

    unless @record.inverse_properties.size.zero? or params[:inverse]
      # This is not really an error, but a request for an additional parameter.
      # FIXME: better status? 100 does not work as I'd hoped.
      render :status => 400, :inline => "Required inverse parameter"
    else
      remove_inverse(@record) if params[:inverse] == 'false'
      params[:update].blank? ? render_destroy : render_destroy_update
    end

  rescue ArgumentError
    render :status => 400, :inline => "Could not resolve URI."
  end

  ##
  # Returns the best label for the requested URI
  #
  # Note: no HTML in response for this request, so no layout.
  def label
    render :status => 400, :inline => "Invalid URI" and return unless Talia3::URI.valid?(params[:uri])
    @uri = params[:uri]
  end
  
  def bnodes
    @uri, @property, @source = params[:uri], params[:property], params[:sparql]
    render :status => 400, :inline => "Missing or invalid SPARQL endpoint URL" and return unless @source.present? and @source =~ ::URI.regexp
    render :status => 400, :inline => "Invalid parameters" and return  unless Talia3::URI.valid?(@uri) and Talia3::URI.valid?(@property)

    bnode_graph_query = "CONSTRUCT {?bnode ?p ?o} WHERE {<#{@uri}> <#{@property}> ?bnode . ?bnode ?p ?o . FILTER(isBlank(?bnode)) .}"

    @subgraph = RDF::Graph.new
    RDF::SPARQL::Repository.new(URI.escape @source).query(bnode_graph_query).each do |s|
      @subgraph << s
    end

    # We want to serve a javascript template always, so we force the format:
    respond_to {|format| format.js {}}
  end

  def bnode_transform
    @property, @querystring = params[:property], params[:q].to_hash.to_options
    @uri, @namespace, @source = @querystring[:uri], @querystring[:namespace], @querystring[:sparql]

    bnode_graph_query = "CONSTRUCT {?bnode ?p ?o} WHERE {<#{@uri}> <#{@property}> ?bnode. ?bnode ?p ?o. FILTER(isBlank(?bnode)).}"

    graph = RDF::Graph.new
    RDF::SPARQL::Repository.new(URI.escape @source).query(bnode_graph_query).each do |s|
      graph << s
    end

    diff = [].tap do |diff|
      graph.each_subject do |bnode|
        new_uri = Talia3::URI.unique @namespace

        diff << {
          :insert => RDF::Statement.new(@uri.to_uri, @property.to_uri, new_uri),
          :delete => RDF::Statement.new(@uri.to_uri, @property.to_uri, bnode)
        }

        graph.query([bnode]).each do |statement|
          diff << {
            :delete => statement.dup,
            :insert => statement.tap {|s| s.subject = new_uri}
          }
        end
      end
    end

    changeset = Talia3::Update.for @querystring[:update], diff
    render :inline => 'Unknown changeset format', :status => 400 and return if changeset.nil?

    unless @querystring[:cb].blank?
      send_post URI.escape(@querystring[:cb]), changeset.to_s, changeset.content_type,  talia3_universal_url(@querystring)
    else
      render changeset.format.to_sym => changeset.to_s
    end
  end # def bnode_transform

  private

    ##
    # @private
    def querystring_handler
      @source, @uri, @callback, @update, @namespace = params[:sparql], params[:uri], params[:cb], params[:update], params[:namespace]

      @type = (params[:type] and Talia3::URI.valid? params[:type]) ? Talia3::URI.new(params[:type]) : nil

      @l = params[:l].try(:to_i) || 20
      @l = 0 if @l < 0
      @o = params[:o].try(:to_i) || 0
      @o = 0 if @o < 0

      @querystring = {:sparql => @source, :type => @type.to_s, :uri => @uri, :cb => @callback, :update => @update, :namespace => @namespace}
    end

    ##
    # @private
    def format_values(values)
      values.map do |value|
        format_value value
      end.compact
    end # def format_values

    ##
    # @private
    def format_value(value)
      value['value'].try :strip!
      value['language'].try :strip!
      # Fixing problem with null values from Ajax 
      # calls that become a "null" string.
      value['language'] = nil if value['language'].blank?

      datatype = (value['datatype'] == 'custom') ? value['datatype_custom'].try(:strip) : value['datatype']
      unless value['value'].blank?
        if value['uri_literal'] == 'uri'
          Talia3::URI.new value['value']
        else
          datatype = nil if datatype.blank?
          # There are some problems with dates, at least with Ruby 1.9.2 and/or rdf.rb. 
          # This avoids an Exception.
          # Having a nil value (which will be ignored) is not exceptional but, currently, the 
          # universal form relies on javascript data verification only.
          RDF::Literal.new(value['value'], :datatype => datatype, :language => value['language']) rescue nil
        end
      end
    end # def format_value(value)

    ##
    # @private
    def labels_query(uri)
      "SELECT ?l WHERE {<#{uri.to_s}> <#{Talia3::N::RDFS.label}>  ?l}"
    end

    ##
    # @private
    def send_put(url, payload,  content_type='application/rdf+xml; charset=UTF-8', redirect=nil)
      _send('PUT', url, payload,  content_type, redirect)
    end

    ##
    # @private
    def send_post(url, payload,  content_type='application/rdf+xml; charset=UTF-8', redirect=nil)
      _send('POST', url, payload,  content_type, redirect)
    end

    ##
    # @private
    def send_delete(url, payload,  content_type='application/rdf+xml; charset=UTF-8', redirect=nil)
      _send('DELETE', url, payload,  content_type, redirect)
    end

    ##
    # @private
    def _send(method, url, payload,  content_type='application/rdf+xml; charset=UTF-8', redirect=nil)
      render :status => 500, :text => "No url to send #{method} request to" and return if url.blank?
      render :status => 200, :inline => '' and return if payload.blank?

      url = ::URI.parse url
      ::Net::HTTP.start url.host, url.port do |http|
        response = http.send_request(method, url.request_uri, payload, {'Content-Type' => content_type})
        case response
          when Net::HTTPSuccess then (redirect.nil? ? render(:status => 200, :inline => 'OK') : redirect_to(redirect, :status => 302))
          when Net::HTTPClientError then render :status => 400, :inline => "Callback complained: #{response.body}"
          else response.error!
        end
      end
    rescue SocketError
      render :status => 404, :inline => "Not found"
    rescue Timeout::Error, Errno::ETIMEDOUT
      # FIXME: not sure this is the right status.
      render :status => 504, :inline => "Request timed-out"
    rescue
      Rails.logger.info $!.inspect
      render :status => 500, :text => 'Unknown error'
    end

    ##
    # @private
    def render_record
      @record = Talia3::Record.new
      @record.uri  = params[:uri]
      @record.type = params[:type]

      params[:record].each do |name, values|
        format_values(values).each do |value|
          @record.raw_set name, value unless value.blank?
        end
      end if params[:record]


      params[:inverse].each do |name, values|
        values.each do |value|
          @record.raw_set_inverse name, value['value'] unless value['value'].blank?
        end
      end if params[:inverse]

      unless params[:cb].blank?
        send_post(URI.escape(params[:cb]), @record.to_xml, 'application/rdf+xml; charset=UTF-8', talia3_universal_url(@querystring))
      else
        render :xml => @record.to_xml
      end
    end

    ##
    # @private
    def render_destroy
      unless params[:cb].blank?
        # FIXME
        render :status => 400, :inline => "Delete operations without an update format are disabled."
        # send_delete(URI.escape(params[:cb]), @record.to_xml) and return
      else
        render :xml => @record.to_xml
      end
    end

    ##
    # @private
    # @todo refactor
    def render_new_update
      log = params.delete(:record).map do |name, values|
        format_values(values).map do |value|
Rails.logger.info value.inspect
          {:insert => RDF::Statement.new(params[:uri].to_uri, name.to_uri, value)}
        end
      end.flatten

      params.delete(:inverse).each do |name, values|
        values.each do |value|
          log << {:insert => RDF::Statement.new(value.to_uri, name.to_uri, params[:uri].to_uri)}
        end
      end if params[:inverse]

      changeset = Talia3::Update.for params[:update], log

      unless params[:cb].blank?
        send_post URI.escape(params[:cb]), changeset.to_s, changeset.content_type, talia3_universal_url(@querystring)
      else
        render changeset.format.to_sym => changeset.to_s
      end
    end

    ##
    # @private
    # @todo refactor
    def render_update
      render :inline =>  '' and return unless params[:log].try :respond_to?, :map

      log = params[:log].map do |i,l|
        {:delete => format_log_statement(l["delete"]), :insert => format_log_statement(l["insert"])}
      end

      changeset = Talia3::Update.for params[:update], log

      render :inline => 'Unknown changeset format', :status => 400 and return if changeset.nil?

      unless params[:cb].blank?
        send_post URI.escape(params[:cb]), changeset.to_s, changeset.content_type, talia3_universal_url(@querystring)
      else
        render changeset.format.to_sym => changeset.to_s
      end
    end

    ##
    # @private
    # @todo refactor
    def render_destroy_update
      log = @record.each.map do |statement|
        {:delete => statement}
      end
      changeset = Talia3::Update.for params[:update], log
      render :inline => 'Unknown changeset format', :status => 400 and return if changeset.nil?

      unless params[:cb].blank?
        send_post URI.escape(params[:cb]), changeset.to_s, changeset.content_type
      else
        render changeset.format.to_sym => changeset.to_s
      end
    end

    ##
    # @private
    def format_log_statement(statement)
      return nil if statement["property"].blank? or statement["value"].blank?
      unless statement[:inverse] == 'true'
        RDF::Statement.new Talia3::URI.new(params[:uri]), Talia3::URI.new(statement["property"]), format_value(statement)
      else
        RDF::Statement.new Talia3::URI.new(statement['value']), Talia3::URI.new(statement["property"]), Talia3::URI.new(params[:uri])
      end
    rescue
      nil
    end

    ##
    # @private
    def uri_in_use?(uri, sparql)
      RDF::SPARQL::Repository.new(URI.escape sparql) do |r|
        return r.query("SELECT ?s WHERE {{<#{uri.to_s}> ?p1 ?o} UNION {?s ?p2 <#{uri.to_s}>}} LIMIT 1").size > 0
      end
    end

    ##
    # @private
    def remove_inverse(record)
      record.graph.delete [nil, nil, record.uri]
    end

    ##
    # @private
    def types_query
      Talia3::SPARQL::Queries.types_query @l + 1, @o
    end

    ##
    # @private
    def instances_query
      return untyped_instances_query if @type.nil?
      Talia3::SPARQL::Queries.instances_query(@type, @l + 1, @o);
    end

    def untyped_instances_query
      Talia3::SPARQL::Queries.untyped_instances_query(@l + 1, @o)
    end

    ##
    # @return [Array<String>]
    # @private
    def excluded_types
      # Note that Talia3::N::RDFS and Talia3::N::OWL have some additional handling for untyped resources.
      [Talia3::N::RDFS.to_s, Talia3::N::OWL.to_s, Talia3::N::RDF.to_s, Talia3::N::Talia.Ontology.to_s]
    end

  # end private
end # class Talia3::Universal::ServiceController
