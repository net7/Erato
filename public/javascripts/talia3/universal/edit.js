var url_regexp = /^(ftp|http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?$/;
var mail_regexp = /^mailto:([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
var formLog = [];
// code to handle the medusa library 

(function(){
  var interval;
  jQuery.fn.contentchange = function(fn) {
    return this.bind('contentchange', fn);
  };
  jQuery.event.special.contentchange = {
    setup: function(data, namespaces) {
      var self = this,
      $this = $(this),
      $originalContent = $this.text();
      interval = setInterval(function() {
        if ($originalContent != $this.text()) {
          $originalContent = $this.text();
          jQuery.event.special.contentchange.handler.call(self);
        }
      }, 100);
    },
    teardown: function(){ clearInterval(interval); },
    handler: function(event) { jQuery.event.handle.call(this, {type:'contentchange'}); }
  };
})();

// If set to true, form submission will ignore the callback URL and
// display the update information instead of submitting it.
// Set by the #preview_save submit and reset by submit event.
var preview = false;
var tempKeyword ="";
$(document).ready(function() {
  // Only for new resources and with a namespace declared.
  $("#uri_local_name").change(function(e) {
    if($("#namespace").val() != "")
      $("#uri").val($("#namespace").val() + $(this).val());
    $("#uri").val($("#namespace").val() + $(this).val());
  });

  $(".record_attribute input").live("change", function(e) {
    var me   = $(this);
    var type = fetchAttributeType(me.parent()).val();

    if(type == 'uri') {
      agorizedinput_show(me.parent());

      if($("#namespace").val() && me.val().indexOf($("#namespace").val()) < 0) {
        edit_hide(me.parent());
      } else {
        edit_show(me.parent());
      }
    }

    checkChange(me)
    logUpdate(me.parent());
    me.attr("data-value", me.val());
  });

  
  $(".record_attribute select").live("change", function(e) {
    checkChange($(this));
    logUpdate($(this).parent());
    $(this).attr("data-value", $("option:selected", this).val());
  });

  $("#preview_save").click(function(e) {
    preview = true;
  });

  $("#talia3_record").submit(function(e) {
    var errors = false;
    if($("#uri").size() && !validURI($("#uri").val())) {
      signalError($("#uri"), 'This property must be a valid URI (URL or "mailto:<valid email>")');
      errors = true;
    }

    var elements = update_with_log() ? $("span.record_attribute[data-logid]") : $("span.record_attribute");

    elements.each(function() {
      value = $.trim(fetchAttributeValue($(this)).val());
      if(value) {
        type = $.trim(fetchAttributeType($(this)).val());
        if(type == 'uri') {
          if(!validURI(value)) {
            errors = true;
            signalError(fetchAttributeValue($(this)), 'This property must be a valid URI (URL or "mailto:<valid email>"');
          }
        } else {
          datatype = $.trim(fetchAttributeDatatype($(this)).val());
          if(datatype == 'custom') {
            customDatatypeValue = $.trim(fetchAttributeDatatypeCustom($(this)).val());
            if(customDatatypeValue && !validURI(customDatatypeValue)) {
              errors = true;
              signalError(fetchAttributeDatatypeCustom($(this)), "This property's datatype is not a valid URL");
            }
          }
          if(!checkValueAndDatatype(fetchAttributeValue($(this)), fetchAttributeRealDatatype($(this)), true)) errors = true;
        }
      }
    });

    if(errors) {alert('Errors during insertion.'); return false;}
    else if($("#cb").val() && !preview) callback($(this), update_with_log());
    else if($("#update").val()) showUpdateText($(this), update_with_log());
    else {preview=false; return true;}

    preview = false;
    return false;
  });

  $("input").live('focus', function(e) {resetError($(this))});

  $("select.record_attribute_datatype").live("change", function() {
    datatype_custom_touch($(this).parent());
  });


  // function to get the keyword to use for medusa
  
  $(".agorized-input").live("click",function(){
    tempKeyword =$(".keyword" ,$(this).parent()).val();
  });
  
  /**
   * The language menu is valid only with literal of type string, and it should be hidden in the other cases.
   */
  $(".record_attribute_datatype").live("change", function(e) {
    
    if($('.info', $(this).parent())) $('.info').popover('hide');
    
    if($("option:selected", this).text() != 'string') {
      language_hide($(this).parent());
    } else {
      language_show($(this).parent());
    }

    // Remove previous information buttons for this element.
    $('.info', $(this).parent()).remove();
    if(($("option:selected", this).text() == 'date') ||($("option:selected", this).text() == 'date/time') ) {
      var message="Date note";
      var content='Properties of type Date must follow this specification: http://www.w3.org/TR/xmlschema-2/#date. A simple valid format would be: yyyy-mm-dd, e.g 2011-09-09';
      
      if($("option:selected", this).text() == 'date/time') {
        message="Date/Time note";
        content='Properties of type Date/time must follow this specification: http://www.w3.org/TR/xmlschema-2/#dateTime. A simple valid format would be: yyyy-mm-ddThh:mm:ss, e.g 2002-10-10T12:00:00 ';
      }
      
      var explanation = $('<a class="info"  href="#" onclick="return false;"><img src="/images/information.png"/></a>')
      explanation.attr("alt", message).attr("title", message).attr("data-content",content);
      $(".record_attribute_value", $(this).parent()).after(explanation);
      $('.info').popover({'placement': 'above', 'trigger':'manual'});
    }
  });

  $(".record_attribute_value").live("focus", function(e) {
    $('.info', $(this).parent()).popover('show');
    checkChange($(this));
  });
  
  $(".record_attribute_value").live("blur", function(e) {
    checkChange($(this));
    $('.info', $(this).parent()).popover('hide');
  });

  /**
   * "Edit" link handling.
   * From every property value that is URI, it is possible to open the edit window 
   * for the resource pointed to by that specific URI. Provided that:
   *  - the URI is valid;
   *  - if a base namespace for URIs is specified, the URI beginsa with the aforementioned 
   *  namespace;
   *  - the user confirms the passage to the new form;
   */
  $(".navigate-to").live("click", function(e) {
    e.preventDefault();
    var uri = $(this).parent().find(".record_attribute_value").val();
    
    //var uri = $(this).next().val();
    var error = "You cannot edit the resource "+uri+".\nIt does not belong to the editable namespace.";
    
    if($("#namespace").val() && uri.indexOf($("#namespace").val()) < 0)
    {
      $('#modal-from-dom .modal-body #modal_text').empty()
      $('#modal-from-dom .modal-body').append("<p id='modal_text'>"+error+"</p>")
      $('#modal-from-dom .primary').live('click', function(){
        
        $("#modal-from-dom").modal('hide'); //Close the modal
      });
      $('#modal-from-dom .secondary').css('display','none');
    }
    else if(!url_regexp.test(uri)) {
      $('#modal-from-dom .modal-body #modal_text').empty()
      $('#modal-from-dom .modal-body').append("<p id='modal_text'> Value cannot be used to retrieve a LOD resource. </p>")
      $('#modal-from-dom .primary').live('click', function(){
        
        $("#modal-from-dom").modal('hide'); //Close the modal
      });
      $('#modal-from-dom .secondary').css('display','none');
      
    } else {
      $('#modal-from-dom .modal-body #modal_text').empty()
      $('#modal-from-dom .modal-body').append("<p id='modal_text'>Navigating to the new resource will negate all unsaved changes, proceed? </p>")
      var href = $(this).attr("href");
      $('#modal-from-dom .primary').live('click', function(){
        
        $("#modal-from-dom").modal('hide'); //Close the modal
      });
      $('#modal-from-dom .secondary').live('click', function() {
        window.location = href+"&uri="+encodeURIComponent(uri);
        $("#modal-from-dom").modal('hide');
        return false;
      });
    }   
    return false;    
  });
  
  
  
  /* original
     
     $(".navigate-to").live("click", function(e) {
     e.preventDefault();
     var uri = $(this).next().val();
     var error = "You cannot edit the resource "+uri+".\nIt does not belong to the editable namespace.";
     if($("#namespace").val() && uri.indexOf($("#namespace").val()) < 0) alert(error);
     else if(!url_regexp.test(uri)) alert("Value cannot be used to retrieve a LOD resource.");
     else if(formLog.length == 0 || confirm("Navigating to the new resource will negate all unsaved changes, proceed?")) {
     window.location = $(this).attr("href")+"&uri="+uri;
     }
     });*/

  /**
   * The "Edit" this URI link for a property value should not appear
   * if the value is not, in fact, a URI.
   * The link should then be hidden when a value changes from URI to
   * Literal, and magically reappear when the opposit occurs.
   */
  $(".record_attribute_type").live("change", function(e) {
    if($("option:selected", this).val() == 'uri') {
      
      var uri = $(this).parent().find(".record_attribute_value").val();

      if(!($("#namespace").val() && uri.indexOf($("#namespace").val()) < 0))
      {
        edit_show($(this).parent());
      }
      
      language_hide($(this).parent());
      datatype_hide($(this).parent());
      info_hide($(this).parent());
      agorizedinput_show($(this).parent());
    } else {
      $($(this).parent().find(".navigate-to"), $(this).parent()).attr("hidden", "hidden");

      edit_hide($(this).parent());
      language_show($(this).parent());
      datatype_show($(this).parent());
      agorizedinput_hide($(this).parent());
    }
  });

  $(".attribute_remove").live('click', function(e) {
    e.preventDefault();
    logDelete($(this).parent());
    //  $(this).parent().parent().find($("br:last"))
    $(this).parent().prev('br').remove();
    $(this).parent().remove();
    
  });
  
  $(".clear-field").live('click', function(e) {
    e.preventDefault();
    $(".record_attribute_value", $(this).parent()).val('');
    $(this).addClass("hidden");
    $(".agorized-input", $(this).parent()).removeClass('hidden');
    
    
  });

  $('.agorized-input').bind('contentchange',function(e){
    $('.keyword', $(this).parent()).val($(this).text())
    $('.clear-field', $(this).parent()).removeClass("hidden");
    $(".agorized-input", $(this).parent()).addClass('hidden');
    logUpdate($(this).parent());
    resetError($('.keyword', $(this).parent()));
  });

  $(".attribute_clone").live('click', function(e) {
    e.preventDefault();
    new_fields = $(this).next(".attribute_prototype").clone().
      removeAttr('id').removeAttr('hidden').removeClass('attribute_prototype').addClass('record_attribute').
      attr("data-attribute", $(this).attr("data-attribute"));

    $('*', new_fields).each(function() {$(this).removeAttr('disabled')});
    new_fields.insertBefore($(this));
    
    $("<br/>").insertBefore(new_fields);
    //activation of bind to handle medusa
    
    $('.agorized-input', new_fields).bind('contentchange',function(e){
      $('.keyword', new_fields).val($(this).text())
      $('.clear-field', new_fields).removeClass("hidden");
      $(".agorized-input", new_fields).addClass('hidden');
      logUpdate($(this).parent());
      resetError($('.keyword', new_fields));
    });  
    
    // If there are previous values, set the same type to the new field;
    // In other words, if previous values were literals, auto-select Literal 
    // from the type select.
    //
    // Also, why not set the same datatype, as we are there?
    //
    // Ignore hidden selectes, these are from prototype attributes or fixed-type 
    // properties.
    var otherTypeSelects = $(".record_attribute_type:visible", $(this).parent());
    
    // There must be one more attribute present in addition to the one we just added.
    if(otherTypeSelects.length > 1 && $("option:selected", otherTypeSelects.first()).val() == 'literal') {
      $(".record_attribute_type", new_fields).first().val('literal').change();
      var datatype = $(".record_attribute_datatype:first option:selected", $(this).parent()).val();
      $(".record_attribute_datatype", new_fields).first().val(datatype).change();
    }
  });

  $("#new_row_label").keypress(function(e) {
    if(e.which == 13) {
      $("#add_row").click();
      return false;
    }
  });

  $("#add_row").bind('click', function(e) {
    e.preventDefault();
    e.stopPropagation();

    var uri = $.trim($("#new_row_label").val());
    var label;

    if(!url_regexp.test(uri)) {
      signalError($("#new_row_label"), "A property name must be a valid URL");
    } else {
      // Ask the server for a proper label for this new attribute.
      // Note that, if an error or empty value is received then the full uri will be used.
      $.ajax({
        url: $("body").attr("data-edit_url")+"/label",
        data: {uri: uri},
        complete: function(response, status) {
          label =  (status == 'success' && response.responseText != "") ? $.trim(response.responseText) : uri;
          resetError($("#new_row_label"));
          new_row = $("#new_row_prototype").clone();
          $("td:first", new_row).html('<span title="'+uri+'">'+label+"</span>");
          $(".attribute_clone", new_row).attr("data-attribute", uri);
          $(".attribute_prototype *", new_row).each(function() {
            old_name = $(this).attr("name");
            if(old_name) $(this).attr("name", old_name.replace("[new]", "[" + uri + "]"));
          });
          new_row.removeAttr("id").removeAttr("hidden");
          new_row.insertBefore($("#new_row_interface"));
          $(".attribute_clone", new_row).click();
        },
      });
    }
  });
});

/**
 * Submit operations.
 */
/***/
function callback(form, update_with_log) {
  if(update_with_log && formLog.length == 0) {alert("No changes to save."); return false;}
  data = update_with_log ? data_for_update() : form.serialize();
  $.ajax({
    type: 'POST',
    async: false,
    url: form.attr("action"),
    data: data,
    success: function(response) {
      if(response == '' || response.responseText == '') alert('No relevant changes to save where found.');
      else alert("Operation successful");
      /// Reset the formLog.
      resetFormLog();
    },
    error: function(response) {
      switch(response.status) {
        case 302:
          window.location = response.responseText;
          break;
        case 404:
          alert("URL for update request not found.");
          break;
        case 504:
          alert("Update request timed-out.");
          break;
        default:
          alert("Unknown server error.");
      }
    }
  });
}

function showUpdateText(form, update_with_log) {
  if(update_with_log && formLog.length == 0) {alert("No changes to be saved."); return false;}

  var clearLog = !preview;

  // FIXME (?) need to to this here because of form.serialize() returns a querystring instead of an object
  if(preview) {
    var cbBackup = $("#cb").val();
    $("#cb").val("");
  }
  data = update_with_log ? data_for_update() : form.serialize();

  if(preview) {
    $("#cb").val(cbBackup);
  }

  $.ajax({
    type: 'POST',
    url: form.attr("action"),
    data: data,
    success: function(response) {
      if(clearLog) resetFormLog();
      if(response == '' || response.responseText == '') alert('No relevant changes to save where found.');
      else alert(response.responseText);
    },
    error: function(response, b, c) {
      /// Strange: if I receive xml with 200 ok status, it is still an error because "No conversion from xml to string"
      ///   yet, when looking at response.responseText there it is! XML in string format...
      ///   That's the reason for this little hack:
      if(response.status == '200') {
        if(clearLog) resetFormLog();
        if(response.responseText == '') alert('No relevant changes to save where found.');
        else alert(response.responseText);
      }
      else alert("Error in request: \n Status: " + response.status + " \n Message: " + response.responseText)
    },
    dataType: 'string'
  });
  return false;
}

function update_with_log() {
  return !$("body").attr("data-new") && $("#update").val() != '';
}

/**
 * Error Handling functions.
 */
function validURI(uri) {
  var uri = $.trim(uri);
  return (url_regexp.test(uri) || mail_regexp.test(uri));
}

function validInteger(x) {
  return /^[+-]?\d+/.test(x);
}

function validDecimal(x) {
  return /^[-+]?\d+(\.\d+)?$/.test(x);
}

function validFloat(x) {
  return /[-+]?\d+(\.\d+)?([eE]?[+-]?\d+)?$/.test(x);
}

function validDouble(x) {
  return validFloat(x);
}

function validBoolean(x) {
  return /true|false|[01]/.test(x);
}

function validDate(x) {
  return /^-?\d{4}-\d{2}-\d{2}(([\+\-]\d{2}:\d{2})|UTC|Z)?$/.test(x);
}

function validDateTime(x) {
  return /^-?\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(([\+\-]\d{2}:\d{2})|UTC|Z)?$/.test(x);
}

function checkChange(element) {
  var type = fetchAttributeType(element.parent()).val();
  var value = $.trim(fetchAttributeValue(element.parent()).val());
  if(value != "") {
    if(checkValueAndType(fetchAttributeValue(element.parent()), type)) {
      if(type == 'literal') checkValueAndDatatype(fetchAttributeValue(element.parent()), fetchAttributeRealDatatype(element.parent()));
    }
  }
}

function checkValueAndType(valueElement, type, asError) {
  var issueAs = asError ? 'error' : 'warning';

  var value = $.trim(valueElement.val());
  if(type == 'uri' && !validURI(value)) {
    signal(issueAs, valueElement, 'You inserted an invalid URI, you might want to switch to a literal instead.');
    edit_hide($(valueElement).parent());
    return false;
  }
  if(type == 'literal' && validURI(value)) {
    signal(issueAs, valueElement, 'You typed a valid URI, you might want to switch to a URI instead.');
    return false;
  }
  if(type == 'uri' && validURI(value)) {
    if(!($("#namespace").val() && value.indexOf($("#namespace").val()) < 0))
    edit_show(valueElement.parent())
  }
  
  unsignal(valueElement);
  return true;
}

function checkValueAndDatatype(valueElement, datatype, asError) {
  var issueAs = asError ? 'error' : 'warning';
  var ok = true;
  var value = $.trim(valueElement.val());

  switch(datatype) {

  case "http://www.w3.org/2001/XMLSchema#int":
    if(!validInteger(value)) {
      signal(issueAs, valueElement, 'This value does not look like an integer, you might want to change it\'s datatype.');
      ok = false;
    }
    break;

  case "http://www.w3.org/2001/XMLSchema#double":
    if(!validFloat(value)) {
      signal(issueAs, valueElement, 'This value does not look like a double, you might want to change it\'s datatype.');
      ok = false;
    }
    break;

  case "http://www.w3.org/2001/XMLSchema#float":
    if(!validFloat(value)) {
      signal(issueAs, valueElement, 'This value does not look like a float, you might want to change it\'s datatype.');
      ok = false;
    }
    break;

  case "http://www.w3.org/2001/XMLSchema#boolean":
    if(!validBoolean(value)) {
      signal(issueAs, valueElement, 'This value does not look like a boolean, you might want to change it\'s datatype.');
      ok = false;
    }
    break;

  case "http://www.w3.org/2001/XMLSchema#date":
    if(!validDate(value)) {
      signal(issueAs, valueElement, 'This value does not look like a date, you might want to change it\'s datatype.');
      ok = false;
    }
    break;

  case "http://www.w3.org/2001/XMLSchema#dateTime":
    if(!validDateTime(value)) {
      signal(issueAs, valueElement, 'This value does not look like a date/time, you might want to change it\'s datatype.');
      ok = false;
    }
    break;
  }
  if(ok) unsignal(valueElement);
  return ok;
}

function signalError(element, message, options) {
  options = options || {};
  resetError(element);
  element.css('background-color', (options.bgcolor || 'red'));
  element.css('color', (options.fgcolor || 'white'));
  if(message) {
    var explanation = $('<a class="explanation expl_warning"  href="#" onclick="return false;"><img src="/images/error.png"/></a>')
    explanation.attr("alt", message).attr("title", message)
    element.attr("alt", message).attr("title", message).after(explanation);
    explanation.addClass("explanation");
    $('.expl_warning').twipsy({'placement': 'left'});
  }
}

function signalWarning(element, message) {
  signalError(element, message, {bgcolor: 'yellow', fgcolor: 'black'});
}

function signal(as, element, message) {
  (as == 'error') ? signalError(element, message) : signalWarning(element, message)
}

function resetError(element) {
  element.css('background-color', '');
  element.css('color', '');
  element.removeAttr("alt").removeAttr("title")
  $(".explanation", element.parent()).remove();
}

function resetWarning(element) {
  resetError(element);
}

function unsignal(element) {
  resetError(element);
}

/**
 * Logging functions.
 */
// Argument "element" is the container for all form elements that constitute a single triple.
function logUpdate(element) {
  var logId = element.attr("data-logid")
  if(!logId) {
    logId = newLogId();
    createLogDeleteEntry(logId, oldDataForLog(element));
    element.attr("data-logid", logId);
  }
  updateLogInsertEntry(logId, newDataForLog(element));
}

function logDelete(element) {
  var logId = element.attr("data-logid") || newLogId();
  createLogDeleteEntry(logId, oldDataForLog(element));
}

function resetFormLog() {
  $(".record_attribute[data-logid]").removeAttr("data-logid");
  formLog = [];
  return true;
}

function newDataForLog(element) {
  var language = $(".record_attribute_language option:selected", element).val();
  if(language == "none") language = "";

  return { 
    property        : element.attr("data-attribute"),
    value           : $(".record_attribute_value", element).first().val() || "",
    language        : language,
    uri_literal     : $(".record_attribute_type option:selected", element).val() || "",
    datatype        : $(".record_attribute_datatype option:selected", element).val() || "",
    datatype_custom : $(".record_attribute_datatype_custom", element).first().val() || "",
    inverse         : $(element).hasClass('inverse')
  };
}

function oldDataForLog(element) {
  var language = $(".record_attribute_language", element).first().attr("data-value");
  if(language == 'none') language = "";

  return { 
    property        : element.attr("data-attribute"),
    value           : $(".record_attribute_value", element).first().attr("data-value") || "",
    language        : language,
    uri_literal     : $(".record_attribute_type", element).first().attr("data-value") || "",
    datatype        : $(".record_attribute_datatype", element).first().attr("data-value") || "",
    datatype_custom : $(".record_attribute_datatype_custom", element).first().attr("data-value") || "",
    inverse         : $(element).hasClass('inverse')
  };
}

function newLogId() {
  return new Date().valueOf();
}

function updateLogInsertEntry(logId, data) {
  for(var i = 0; i < formLog.length; i++) {
    if(formLog[i].logId == logId) {
      formLog[i].insert = data;
      return true;
    }
  }
  return false;
}

function createLogDeleteEntry(logId, data) {
  formLog.push({
    logId: logId,
    delete: data,
    insert: null
  });
  return true;
}

/**
 * Element behaviours.
 *
 */

/**
 * Hides the medusa search field.
 */
function agorizedinput_hide(parent) {
  $(".clear-field", parent).addClass("hidden");
  $(".agorized-input", parent).addClass("hidden");
}


/**
 * Shows the medusa search field.
 */
function agorizedinput_show(parent) {
   if($(".record_attribute_value",parent).val() != "") {
    $(".clear-field", parent).removeClass("hidden"); 
  } else {
    $(".agorized-input", parent).removeClass("hidden");
    $(".clear-field", parent).addClass("hidden"); 
  }
}


/**
 * Hides the information element.
 */
function info_hide(parent) {
  $(".info:first", parent).remove();
}


/**
 * Hides the language choice element.
 */
function language_hide(parent) {
  //$(".record_attribute_language:first", parent).attr("hidden", "hidden");
  $(".record_attribute_language:first", parent).addClass("hidden");
}


/**
 * Shows the language choice element.
 */
function language_show(parent) {
  // $(".record_attribute_language:first", parent).removeAttr("hidden");
  $(".record_attribute_language:first", parent).removeClass("hidden");
}

/**
 * Hides datatype elements (datatype, custom datatype).
 */
function datatype_show(parent) {
  $(".record_attribute_datatype:first", parent).removeClass("hidden");
  datatype_custom_touch(parent);
}

/**
 * Shows datatype elements (datatype, custom datatype).
 */
function datatype_hide(parent) {
  //$(".record_attribute_datatype:first", parent).attr("hidden", "hidden");
  $(".record_attribute_datatype:first", parent).addClass("hidden");
  
  //  $(".record_attribute_datatype_custom:first", parent).attr("hidden", "hidden");
  $(".record_attribute_datatype_custom:first", parent).addClass("hidden");
}

function edit_hide(parent){
  $(".navigate-to", parent).addClass("hidden");
}
function edit_show(parent){
  $(".navigate-to", parent).removeClass("hidden");
}
/**
 * Changes the visibility of the custom datatype element.
 *
 * This depends on the value of the current selection for the datatype element.
 */
function datatype_custom_touch(parent) {
  var datatype = $(".record_attribute_datatype option:selected", parent);
  if(datatype.val() == 'custom')
    $(".record_attribute_datatype_custom:first", parent).removeClass("hidden");
  else
    $(".record_attribute_datatype_custom:first", parent).addClass("hidden");
}

/**
 * Miscellaneous functions.
 *
 */

/**
 * Returns the textbox containing a property's value.
 * Requires the parent containing the element we want.
 */
function fetchAttributeValue(parent) {
  return $("input.record_attribute_value:first", parent);
}

/**
 * Returns the type select of a property.
 * Requires the parent containing the element we want.
 */
function fetchAttributeType(parent) {
  return $("select.record_attribute_type:first option:selected", parent);
}

/**
 * Returns the datatype select of a property.
 * Requires the parent containing the element we want.
 */
function fetchAttributeDatatype(parent) {
  return $("select.record_attribute_datatype:first option:selected", parent);
}

/**
 * Returns the custom-datatype textbox of a property.
 * Requires the parent containing the element we want.
 */
function fetchAttributeDatatypeCustom(parent) {
  return $("input.record_attribute_datatype_custom:first", parent);
}


/**
 * Returns the custom-datatype textbox of a property.
 * Requires the parent containing the element we want.
 */
function fetchAttributeRealDatatype(parent) {
  datatype = fetchAttributeDatatype(parent).val();
  return (datatype == 'custom') ? $.trim(fetchAttributeDatatypeCustom(parent).val()) : datatype;
}


/**
 * Prepares Form data for use with an Ajax request.
 *
 */
function data_for_update() {
  return {
    cb: $("#cb").val(),
    update: $("#update").val(),
    sparql: $("#sparql").val(),
    namespace: $("#namespace").val(),
    type: $("#type").val(),
    log: formLog
  };
}