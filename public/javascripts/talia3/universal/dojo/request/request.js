dojo.declare("semlib.MedusaRequest", null, {
  clear: function(type) {
    return jQuery(this.selector + ("[type-name=" + type + "]")).html(this.emptyMessage);
  },
  debug: false,
  selector: ".agorized-input",
  output:"",
  getTerm: function(object) {
    return jQuery(object).attr("keyword");
  },
  apiKey: jQuery('#call-api-key').attr("value"),
  userId: jQuery('#call-user-id').attr("value"),
  emptyMessage: "Empty",
  hideCancel: function(type) {
    return false;
  },
  theme: "tundra",
  tokenForFieldType: (function(type) {
    return jQuery("#call-token-" + type).attr("value");
  }),
  _loadOption: (function(option, options, func) {
     if (options[option] === void 0) {
      return;
    }
    if (func && typeof options[option] !== "function") {
      return;
    }
	return this[option] = options[option];
  }),
  _loadOptions: (function(options) {
    this._loadOption('debug', options);
    this._loadOption('selector', options);
    this._loadOption('getTerm', options, true);
    this._loadOption('theme', options);
    this._loadOption('type', options);
    this._loadOption('emptyMessage', options);
    this._loadOption('apiKey', options);
    this._loadOption('userId', options);
	this._loadOption('output',options);
    this._loadOption('tokenForFieldType', options, true);
    return this._loadOption('hideCancel', options, true);
  }),
  _cancelClass: "remove-metadata",
  _hideCancel: function(obj, type) {
  
    return jQuery("." + obj._cancelClass + "[type=" + type + "]").addClass("hidden");
  },
  _showCancel: function(obj, type) {
    return jQuery("." + obj._cancelClass + "[type=" + type + "]").removeClass("hidden");
  },
  _cancelHtml: function(obj, type) {
    return "<span class='" + obj._cancelClass + "-container'><a type='" + type + "' class='" + obj._cancelClass + "' href='#'>x</a></span>";
  },
  constructor: (function(options) {
    var medReq;
	
    this._loadOptions(options);
    jQuery('body').addClass(this.theme);
    medReq = this;
    jQuery("." + this._cancelClass).live("click", (function(event) {
      var attr;
      event.preventDefault();
      attr = jQuery(this).attr("type");
      jQuery(".metadata-uri[name=" + attr + "]").val("");
      if (medReq.hideCancel(attr)) {
        medReq._hideCancel(medReq, attr);
      }
      return jQuery(medReq.selector + ("[type-name=" + attr + "]")).html(medReq.emptyMessage);
    }));
    jQuery(this.selector).each((function(el, index) {
      jQuery(this).after(medReq._cancelHtml(medReq, jQuery(this).attr("type-name")));
      if (medReq.hideCancel(jQuery(this).attr("type-name"))) {
        return medReq._hideCancel(medReq, jQuery(this).attr("type-name"));
      }
    }));
    jQuery(this.selector).live("click", function() {
      document.recon.openDialog();
      return document.recon.getAutocompleteSuggestions(medReq.getTerm(this), this);
    });
    document.recon = new semlib.ReconSelector({
      debug: true,
      url: "http://medusa.netseven.it/",
      previewArguments: (function(object) {
        var endpoint, guid, signature, timestamp;
        guid = object.id;
        endpoint = object.endpoint_id;
        timestamp = Math.round(+new Date() / 1000);
        signature = jQuery.md5(medReq.apiKey + medReq.userId + endpoint + timestamp);
        return {
          "action": "preview",
          "endpoint_id": endpoint,
          "id": guid,
          "user_id": medReq.userId,
          "timestamp": timestamp,
          "signature": signature
        };
      }),
      callArguments: (function(term, obj) {
        var fieldType, signature, timestamp, tkn;
        timestamp = Math.round(+new Date() / 1000);
        fieldType = jQuery(obj).attr('type-name');
        tkn = medReq.tokenForFieldType(fieldType);
        signature = jQuery.md5(medReq.apiKey + medReq.userId + tkn + timestamp);
        return {
          "action": "search",
          "keyword": term,
          "token": tkn,
          "user_id": medReq.userId,
          "timestamp": timestamp,
          "signature": signature
        };
      })
    });
    medReq = this;
    return document.recon.onAction((function(object, sender) {
      var name;
      jQuery(sender).html(jQuery(object).attr('about'));
      name = jQuery(sender).attr('type-name');
      jQuery(".metadata-uri[name=" + name + "]").val(jQuery(object).attr('about'));
      if (jQuery(object).attr('about') !== "") {
        medReq._showCancel(medReq, name);
      }
      if (jQuery(object).attr('about') === "" && medReq.hideCancel(name)) {
        return medReq._hideCancel(medReq, name);
      }
    }));
  })
});