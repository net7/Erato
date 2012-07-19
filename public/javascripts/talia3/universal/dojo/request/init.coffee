dojo.require 'dojo.io.script'
dojo.require "dijit.Dialog"               
dojo.require "dijit.layout.BorderContainer"
dojo.require "dijit.layout.ContentPane"
dojo.require "dojo.behavior"              
dojo.require "dojo.NodeList-traverse"

dojo.declare "semlib.ReconSelector", null, {
    
    debug: false,
    url: "http://medusa.netseven.it/",
    closeOnAction: true,
    previewArguments: (object) ->,
    callArguments: (arg, obj) ->,
    
    _actions: [],
    _preview: {},
    _term: "",
    _sender: undefined,
    _clicked: false,
    _currentId: undefined,
    
    _setCurrentId: (a) -> @_currentId = a,
    
    _loadOption: (option, options, func) -> 
        if options[option] == undefined
            return
            
        if func and typeof(options[option]) != "function"
            return
        
        this[option] = options[option]
    
    ## Costruttore.
    constructor: ((options) ->
        
        @_loadOption("debug", options)
        @_loadOption("url", options)
        @_loadOption("action", options, yes)
        @_loadOption("callArguments", options, yes)
        @_loadOption("previewArguments", options, yes)
        
        @limit = 100
        @guidSelected = null
        @guidDisplayed = null
        @initDialog()
        @onOkCallbacks = []
        @objects = []
        @moreInfoTips = []
        @moreInfoLongTips = []
        @keyInputTimerLenght = 500
        @keyInputTimer = null
        
        self = this
        
        $('#suggestionContainer ul li').live "click", () ->
            if self._clicked 
                return
            self._clicked = true
            
            if document.recon.closeOnAction
                document.recon.suggestionsDialog.hide()
                
            document.recon._setCurrentId(jQuery(this).attr "about")
            document.recon._fireActions(this, self._sender)
            
            self._clicked = false
        
        $("<div id='suggestionsDialog'></div>").appendTo $('body')
        
        return
        
    ), # End of constructor()
    
    initDialog: (() ->
        
        self = this
        
        c = """
                
            <div dojoType="dijit.layout.ContentPane" style="margin:0; padding: 0px; height:410px;">
                <div dojoType="dijit.layout.BorderContainer" style="padding: 0; margin: 0">
                    <div dojoType="dijit.layout.ContentPane" splitter="true" region="center" style="overflow:auto">
                        <span class="no_results hidden">No results found.</span>
                        <div id="suggestionContainer"><ul class="suggestedTagList"></ul></div>
                    </div>
                <div dojoType="dijit.layout.ContentPane" splitter="true" region="trailing" style="width: 300px"><div class="moreInfoPane"></div></div>
                </div>
            </div>
        
        """
        
        self.suggestionsDialog = new dijit.Dialog {
            title: "Agorized",
            style: "width: 600px; height: 450px",
            content: c
        }
        
        dojo.behavior.add {
            '#suggestionContainer li': {
                
                'onmouseover': (() ->
                    if not $('#suggestionContainer').hasClass('loading')
                        self.guidSelected = $(this).attr 'about'
                        self.addAndDisplayMoreInfo self.guidSelected
                    
                    $('#suggestionContainer li').addClass "baseTag"
                    $('#suggestionContainer li').removeClass "selectedTag"
                    $(this).removeClass "baseTag"
                    $(this).addClass "selectedTag"
                )
            }
            
        }
        
        
    ), # End of initDialog()
    
    onAction: (f) -> @_actions.push f if typeof f == 'function',
    
    _fireActions: (obj, sender) -> func.call(this, obj, sender) for func in @_actions,
    
    openDialog: (() -> 
        document.clicked = false
        this.suggestionsDialog.show()),
    
    getAutocompleteSuggestions: ((term, sender) -> 
        @_sender = sender
        @getSuggestionsForTerm term, sender
        $('#suggestionContainer').addClass 'loading'
    ),
    
    getSuggestionsForTerm: ((term, sender) ->
      
        self = this
        
        dojo.io.script.get {
            callbackParamName: "jsonp",
            url: @url,
            content: @callArguments(term, sender),
            load: (r) -> self.displaySuggestions(r),
            error: (response, ioArgs) -> self.log("getSuggestionsForTerm got an error :(")
            
        }     
    ),
    
    addAndDisplayMoreInfo: ((guid) ->
        
        self = this
        elem = @moreInfoLongTips[guid] or @moreInfoTips[guid]
        
        id = guid.split('/')[guid.split('/').length-1]
        
        tip = """
         
            <div class="preview" id="preview-#{id}">
                <div class="moreInfoTitle"><div class='thumbImageDiv'></div>
                <h3>#{elem.name}</h3>
                <a href='#{guid}' target='_blank'>Più informazioni.</a></div>
                <span id='moreInfo' class='getMoreInfo'></span></br>
            </div>   
        """
        
        if $("#preview-#{id}")[0] == undefined
            $(tip).hide().appendTo('.moreInfoPane')
            
        $('.moreInfoPane .preview').hide()
        $('.moreInfoPane #preview-'+id).show()
        
        if @_preview[guid]
            return
        
        dojo.io.script.get {
            callbackParamName: "jsonp",
            url: @url,
            content: @previewArguments(self.objects[guid]),
            load: ((r) ->

                thumb = no
                thumb = r.thumbnail if r.thumbnail
                    
                abs = r.abstract
                self._preview[guid] = {
                    thumbnail: thumb,
                    abstract: abs
                }
                
                if self._preview[guid].thumbnail
                    $('#preview-'+id+' .thumbImageDiv').html "<img src='"+self._preview[guid].thumbnail+"'>"

                $('#preview-'+id+' #moreInfo').html self._preview[guid].abstract
                $('#preview-'+id+' .moreInfoPane h3').html elem.name
                $('#preview-'+id+' .moreInfoPane a').attr "href", guid
                
            ),
            error: (response, ioArgs) -> self.log("getSuggestionsForTerm got an error :(")
        
        }
        
    ),
    
    displaySuggestions: ((r) ->
        
        content = ""
        self = this
        self.moreInfoTips = {}
        
        results = r.result
        
        counter = -1
        
        for i in results
            counter = counter + 1
            name = i.name
            id = i.id
            more = ""
            
            if id == @_currentId
                more = "class='selected'"
                content = "<li #{more} about='"+id+"'>"+name+"</li>" + content
            else
                content += "<li about='"+id+"'>"+name+"</li>"            
            
            self.moreInfoTips[id] = {name: name}
            self.objects[id] = i
            
        if content == ""
            $('.no_results').removeClass "hidden"
            dojo.empty('suggestionContainer')
        else
            $('#suggestionContainer').html "<ul>#{content}</ul>"
            $('.no_results').addClass "hidden"
            
        $('#suggestionContainer').removeClass "loading"
        $('#suggestionContainer').addClass "baseTag"
        dojo.behavior.apply()
           
    ), # End of displaySuggestions()
    
    clearDialog: (() ->
        dojo.query("#addedTagsList *").forEach(dojo.destroy)
        dojo.query("div#suggestionContainer *").forEach(dojo.destroy)
        dojo.query("div.moreInfoPane *").forEach(dojo.destroy)
        @_preview = {}
    ),
    
    log: ((w) ->
        if not this.debug 
            return
        
        if typeof console != 'undefined'
            console.log('#ReconSelector# '+w)
    )
}
    
    