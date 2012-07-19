dojo.declare("semlib.MedusaRequest", null, {
    
    clear: (type) -> jQuery(@selector+"[type-name=#{type}]").html @emptyMessage
    
    debug: false,
    selector: ".agorized-input",
    getTerm: (object) -> jQuery(object).attr "keyword",
    apiKey: jQuery('#call-api-key').attr("value"),
    userId: jQuery('#call-user-id').attr("value"),    
    emptyMessage: "Empty",
    hideCancel: (type) -> no,
    theme: "tundra",
        
    tokenForFieldType: ((type) ->
        return jQuery("#call-token-"+type).attr("value")
    ),
    
    _loadOption: ((option, options, func) -> 
        if options[option] == undefined
            return
            
        if func and typeof(options[option]) != "function"
            return
        
        this[option] = options[option]
    
    ),
    
    _loadOptions: ((options) ->
        
        this._loadOption('debug', options)
        this._loadOption('selector', options)
        this._loadOption('getTerm', options, yes)
        this._loadOption('theme', options)
        this._loadOption('type', options)
        this._loadOption('emptyMessage', options)
        this._loadOption('apiKey', options)
        this._loadOption('userId', options)
        this._loadOption('tokenForFieldType', options, yes)
        this._loadOption('hideCancel', options, yes)
            
    ),
    
    _cancelClass: "remove-metadata",
    
    _hideCancel: (obj, type) -> jQuery(".#{obj._cancelClass}[type=#{type}]").addClass("hidden") #if obj.createCancel,
    
    _showCancel: (obj, type) -> jQuery(".#{obj._cancelClass}[type=#{type}]").removeClass("hidden") #if obj.createCancel,
    
    _cancelHtml: (obj, type) -> "<span class='#{obj._cancelClass}-container'><a type='#{type}' class='#{obj._cancelClass}' href='#'>x</a></span>",
        
    constructor: ((options) ->
        
        this._loadOptions(options)
        
        jQuery('body').addClass(@theme)
        
        medReq = this
        
        jQuery(".#{@_cancelClass}").live("click", ((event) ->
            
            event.preventDefault()
            
            attr = jQuery(this).attr("type")
            
            jQuery(".metadata-uri[name=#{attr}]").val("")
            medReq._hideCancel(medReq, attr) if medReq.hideCancel(attr)
            jQuery(medReq.selector+"[type-name=#{attr}]").html medReq.emptyMessage
        
        ))
        
        #if @createCancel
        jQuery(@selector).each ((el, index) ->
            jQuery(this).after medReq._cancelHtml(medReq, jQuery(this).attr "type-name")
            if medReq.hideCancel(jQuery(this).attr "type-name")
                medReq._hideCancel(medReq, jQuery(this).attr "type-name")
        )
        
        jQuery(@selector).live "click", () ->
            document.recon.openDialog()
            document.recon.getAutocompleteSuggestions medReq.getTerm(this), this
        
        document.recon = new semlib.ReconSelector {
            debug: true, 
            url: "http://medusa.netseven.it/",
            previewArguments: ((object) ->
        
                guid = object.id
                endpoint = object.endpoint_id
        
                timestamp = Math.round(+new Date()/1000)                
        
                signature = jQuery.md5(medReq.apiKey+medReq.userId+endpoint+timestamp);
        
                return {
                    "action": "preview",
                    "endpoint_id": endpoint,
                    "id": guid,
                    "user_id": medReq.userId,
                    "timestamp": timestamp,
                    "signature": signature
                }
        
            ),
            callArguments: ((term, obj) ->
        
                timestamp = Math.round(+new Date()/1000)
        
                fieldType = jQuery(obj).attr('type-name')
                tkn = medReq.tokenForFieldType(fieldType)
        
                signature = jQuery.md5(medReq.apiKey+medReq.userId+tkn+timestamp);
        
                return {
                    "action": "search",
                    "keyword": term,
                    "token": tkn,
                    "user_id": medReq.userId,
                    "timestamp": timestamp,
                    "signature": signature
                }  
        
            )}
            
        medReq = this
            
        document.recon.onAction(((object, sender)->
            
            jQuery(sender).html jQuery(object).attr 'about'
            name = jQuery(sender).attr('type-name')

            jQuery(".metadata-uri[name=#{name}]").val jQuery(object).attr 'about'

            medReq._showCancel(medReq, name) if jQuery(object).attr('about') != ""
            medReq._hideCancel(medReq, name) if jQuery(object).attr('about') == "" and medReq.hideCancel(name)
        ))
        
    )
})