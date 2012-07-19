dojo.require('dojo.io.script');
dojo.require("dijit.Dialog");
dojo.require("dijit.layout.BorderContainer");
dojo.require("dijit.layout.ContentPane");
dojo.require("dojo.behavior");
dojo.require("dojo.NodeList-traverse");
dojo.declare("semlib.ReconSelector", null, {
  debug: false,
  url: "http://medusa.netseven.it/",
  closeOnAction: true,
  previewArguments: function(object) {},
  callArguments: function(arg, obj) {},
  _actions: [],
  _preview: {},
  _term: "",
  _sender: void 0,
  _clicked: false,
  _currentId: void 0,
  _setCurrentId: function(a) {
    return this._currentId = a;
  },
  _loadOption: function(option, options, func) {
    if (options[option] === void 0) {
      return;
    }
    if (func && typeof options[option] !== "function") {
      return;
    }
    return this[option] = options[option];
  },
  constructor: (function(options) {
    var self;
    this._loadOption("debug", options);
    this._loadOption("url", options);
    this._loadOption("action", options, true);
    this._loadOption("callArguments", options, true);
    this._loadOption("previewArguments", options, true);
    this.limit = 100;
    this.guidSelected = null;
    this.guidDisplayed = null;
    this.initDialog();
    this.onOkCallbacks = [];
    this.objects = [];
    this.moreInfoTips = [];
    this.moreInfoLongTips = [];
    this.keyInputTimerLenght = 500;
    this.keyInputTimer = null;
    self = this;
    $('#suggestionContainer ul li').live("click", function() {
      if (self._clicked) {
        return;
      }
      self._clicked = true;
      if (document.recon.closeOnAction) {
        document.recon.suggestionsDialog.hide();
      }
      document.recon._setCurrentId(jQuery(this).attr("about"));
      document.recon._fireActions(this, self._sender);
      return self._clicked = false;
    });
    $("<div id='suggestionsDialog'></div>").appendTo($('body'));
  }),
  initDialog: (function() {
    var c, self;
    self = this;
    c = "        \n    <div dojoType=\"dijit.layout.ContentPane\" style=\"margin:0; padding: 0px; height:410px;\">\n        <div dojoType=\"dijit.layout.BorderContainer\" style=\"padding: 0; margin: 0\">\n            <div dojoType=\"dijit.layout.ContentPane\" splitter=\"true\" region=\"center\" style=\"overflow:auto\">\n                <span class=\"no_results hidden\">No results found.</span>\n                <div id=\"suggestionContainer\"><ul class=\"suggestedTagList\"></ul></div>\n            </div>\n        <div dojoType=\"dijit.layout.ContentPane\" splitter=\"true\" region=\"trailing\" style=\"width: 300px\"><div class=\"moreInfoPane\"></div></div>\n        </div>\n    </div>\n";
    self.suggestionsDialog = new dijit.Dialog({
      title: "Search entities in Freebase",
      style: "width: 600px; height: 450px",
      content: c
    });
    return dojo.behavior.add({
      '#suggestionContainer li': {
        'onmouseover': (function() {
          if (!$('#suggestionContainer').hasClass('loading')) {
            self.guidSelected = $(this).attr('about');
            self.addAndDisplayMoreInfo(self.guidSelected);
          }
          $('#suggestionContainer li').addClass("baseTag");
          $('#suggestionContainer li').removeClass("selectedTag");
          $(this).removeClass("baseTag");
          return $(this).addClass("selectedTag");
        })
      }
    });
  }),
  onAction: function(f) {
    if (typeof f === 'function') {
      return this._actions.push(f);
    }
  },
  _fireActions: function(obj, sender) {
    var func, _i, _len, _ref, _results;
    _ref = this._actions;
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      func = _ref[_i];
      _results.push(func.call(this, obj, sender));
    }
    return _results;
  },
  openDialog: (function() {
    document.clicked = false;
    return this.suggestionsDialog.show();
  }),
  getAutocompleteSuggestions: (function(term, sender) {
    this._sender = sender;
    this.getSuggestionsForTerm(term, sender);
    return $('#suggestionContainer').addClass('loading');
  }),
  getSuggestionsForTerm: (function(term, sender) {
    var self;
    self = this;
    return dojo.io.script.get({
      callbackParamName: "jsonp",
      url: this.url,
      content: this.callArguments(term, sender),
      load: function(r) {
        return self.displaySuggestions(r);
      },
      error: function(response, ioArgs) {
        return self.log("getSuggestionsForTerm got an error :(");
      }
    });
  }),
  addAndDisplayMoreInfo: (function(guid) {
    var elem, id, self, tip;
    self = this;
    elem = this.moreInfoLongTips[guid] || this.moreInfoTips[guid];
    id = guid.split('/')[guid.split('/').length - 1];
    tip = "\n   <div class=\"preview\" id=\"preview-" + id + "\">\n       <div class=\"moreInfoTitle\"><div class='thumbImageDiv'></div>\n       <h3>" + elem.name + "</h3>\n       <a href='" + guid + "' target='_blank'>Più informazioni.</a></div>\n       <span id='moreInfo' class='getMoreInfo'></span></br>\n   </div>   ";
    if ($("#preview-" + id)[0] === void 0) {
      $(tip).hide().appendTo('.moreInfoPane');
    }
    $('.moreInfoPane .preview').hide();
    $('.moreInfoPane #preview-' + id).show();
    if (this._preview[guid]) {
      return;
    }
    return dojo.io.script.get({
      callbackParamName: "jsonp",
      url: this.url,
      content: this.previewArguments(self.objects[guid]),
      load: (function(r) {
        var abs, thumb;
        thumb = false;
        if (r.thumbnail) {
          thumb = r.thumbnail;
        }
        abs = r.abstract;
        self._preview[guid] = {
          thumbnail: thumb,
          abstract: abs
        };
        if (self._preview[guid].thumbnail) {
          $('#preview-' + id + ' .thumbImageDiv').html("<img src='" + self._preview[guid].thumbnail + "'>");
        }
        $('#preview-' + id + ' #moreInfo').html(self._preview[guid].abstract);
        $('#preview-' + id + ' .moreInfoPane h3').html(elem.name);
        return $('#preview-' + id + ' .moreInfoPane a').attr("href", guid);
      }),
      error: function(response, ioArgs) {
        return self.log("getSuggestionsForTerm got an error :(");
      }
    });
  }),
  displaySuggestions: (function(r) {
    var content, counter, i, id, more, name, results, self, _i, _len;
    content = "";
    self = this;
    self.moreInfoTips = {};
    results = r.result;
    counter = -1;
    for (_i = 0, _len = results.length; _i < _len; _i++) {
      i = results[_i];
      counter = counter + 1;
      name = i.name;
      id = i.id;
      more = "";
      if (id === this._currentId) {
        more = "class='selected'";
        content = ("<li " + more + " about='") + id + "'>" + name + "</li>" + content;
      } else {
        content += "<li about='" + id + "'>" + name + "</li>";
      }
      self.moreInfoTips[id] = {
        name: name
      };
      self.objects[id] = i;
    }
    if (content === "") {
      $('.no_results').removeClass("hidden");
      dojo.empty('suggestionContainer');
    } else {
      $('#suggestionContainer').html("<ul>" + content + "</ul>");
      $('.no_results').addClass("hidden");
    }
    $('#suggestionContainer').removeClass("loading");
    $('#suggestionContainer').addClass("baseTag");
    return dojo.behavior.apply();
  }),
  clearDialog: (function() {
    dojo.query("#addedTagsList *").forEach(dojo.destroy);
    dojo.query("div#suggestionContainer *").forEach(dojo.destroy);
    dojo.query("div.moreInfoPane *").forEach(dojo.destroy);
    return this._preview = {};
  }),
  log: (function(w) {
    if (!this.debug) {
      return;
    }
    if (typeof console !== 'undefined') {
      return console.log('#ReconSelector# ' + w);
    }
  })
});