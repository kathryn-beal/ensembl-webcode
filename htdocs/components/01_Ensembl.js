// $Revision$

var Ensembl = new Base();

Ensembl.extend({
  constructor: null,
  
  initialize: function () {    
    var hints = this.cookie.get('ENSEMBL_HINTS');
    
    if (!window.name) {
      window.name = 'ensembl_' + new Date().getTime() + '_' + Math.floor(Math.random() * 10000);
    }
    
    this.hashRegex = new RegExp(/[\?;&]r=([^;&]+)/);
    
    if (window.location.hash) {
      $('.ajax_load').each(function () {
        this.value = Ensembl.urlFromHash(this.value);
      });
    }
    
    $(window).bind('hashchange', function (e) {
      Ensembl.setCoreParams();
      Ensembl.EventManager.trigger('hashChange', Ensembl.urlFromHash(window.location.href, true));
    });
    
    (this.ajax  = this.cookie.get('ENSEMBL_AJAX'))  || this.setAjax();
    (this.width = this.cookie.get('ENSEMBL_WIDTH')) || this.setWidth();
    
    this.hideHints = {};
    
    if (hints) {
      $.each(hints.split(/:/), function () {
        Ensembl.hideHints[this] = 1;
      });
    }
    
    var imagePanels = $('.image_panel');
    
    // Store image panel details for highlighting
    this.images = {
      total: imagePanels.length,
      last:  imagePanels.last()[0]
    };
    
    imagePanels = null;
    
    this.initialPanels = $('.initial_panel');
    
    this.setCoreParams();
    
    this.LayoutManager.initialize();
    this.PanelManager.initialize();
  },
   
  cookie: {
    set: function (name, value, expiry, unescaped) {  
      var cookie = [
        unescaped === true ? (name + '=' + (value || '')) : (escape(name) + '=' + escape(value || '')),
        '; expires=',
        (expiry == -1 ? 'Thu, 01 Jan 1970' : 'Tue, 19 Jan 2038'),
        ' 00:00:00 GMT; path=/'
      ].join('');
      
      document.cookie = cookie;
    },
    
    get: function (name, unescaped) {
      var cookie = document.cookie.match(new RegExp('(^|;)\\s*' + (unescaped === true ? name : escape(name)) + '=([^;\\s]*)'));
      return cookie ? unescape(cookie[2]) : '';
    }
  },
  
  setAjax: function () {
    this.cookie.set('ENSEMBL_AJAX', ($.ajaxSettings.xhr() || false) ? 'enabled' : 'none');
  },
  
  setWidth: function () {
    var w = Math.floor(($(window).width() - 250) / 100) * 100;
    
    this.width = w < 500 ? 500 : w;
    this.cookie.set('ENSEMBL_WIDTH', this.width);
  },
  
  setCoreParams: function () {
    var regex = '[;&?]%s=(.+?)[;&]';
    var url   = window.location.search + ';';
    var hash  = window.location.hash.replace(/^#/, '?') + ';';
    
    this.coreParams   = {};
    this.initialR     = $('input[name=r]', '#core_params').val();
    this.location     = { width: 100000 };
    this.speciesPath  = $('#species_path').val();
    this.species      = this.speciesPath.split('/').pop();
    this.multiSpecies = {};
    
    $('input', '#core_params').each(function () {
      var hashMatch = hash.match(regex.replace('%s', this.name));
      Ensembl.coreParams[this.name] = hashMatch ? unescape(hashMatch[1]) : this.value;
    });
    
    var match = (this.coreParams.r ? this.coreParams.r.match(/(.+):(\d+)-(\d+)/) : false) || ($('a', '#tab_location').html() || '').replace(/,/g, '').match(/^Location: (.+):(\d+)-(\d+)$/);
    
    if (match) {
      this.location = { name: match[1], start: parseInt(match[2], 10), end: parseInt(match[3], 10) };
      this.location.width = this.location.end - this.location.start + 1;
      
      if (this.location.width > 1000000) {
        this.location.width = 1000000;
      }
    }
    
    match = url.match(/s\d+=.+?[;&]/g);
    
    if (match) {      
      var m, i, r;
      
      $.each(match, function () {
        m = this.split('=');
        i = m[0].substr(1);
        
        Ensembl.multiSpecies[i] = {};
        
        $.each(['r', 'g', 's'], function () {
          Ensembl.multiSpecies[i][this] = url.match(regex.replace('%s', this + i));
          
          if (Ensembl.multiSpecies[i][this]) {
            Ensembl.multiSpecies[i][this] = unescape(Ensembl.multiSpecies[i][this][1]);
          }
          
          if (this == 'r' && Ensembl.multiSpecies[i].r) {
            r = Ensembl.multiSpecies[i].r.match(/(.+):(\d+)-(\d+)/);
            
            Ensembl.multiSpecies[i].location = { name: r[1], start: parseInt(r[2], 10), end: parseInt(r[3], 10) };
          }
        });
      });
    }
  },
  
  cleanURL: function (url) {
    return unescape(url.replace(/&/g, ';').replace(/#.*$/g, '').replace(/([\?;])time=[^;]+;?/g, '$1').replace(/[\?;]$/g, ''));
  },
  
  // Remove the old time stamp from a URL and replace with a new one
  replaceTimestamp: function (url) {
    var d = new Date();
    var time = d.getTime() + d.getMilliseconds() / 1000;
    
    url = this.cleanURL(url);
    url += (url.match(/\?/) ? ';' : '?') + 'time=' + time;
    
    return url;
  },
  
  redirect: function (url) {
    for (var p in this.PanelManager.panels) {
      this.PanelManager.panels[p].destructor('cleanup');
    }
    
    url = url || this.replaceTimestamp(window.location.href);
    
    if (window.location.hash) {
      url = this.urlFromHash(url);
    }
    
    window.location = url;
  },
  
  urlFromHash: function (url, paramOnly) {
    var hash  = window.location.hash.replace(/^#/, '?') + ';';
    var match = hash.match(this.hashRegex);
    var r     = match ? match[1] : this.initialR;
    
    return paramOnly ? r : url.match(this.hashRegex) ? url.replace(/([\?;]r=)[^;]+(;?)/, '$1' + r + '$2') : url + ';r=' + r;
  },
  
  loadScript: function (url, callback, caller) {
    var script = document.createElement('script');
    
    if (script.readyState) { //IE
      script.onreadystatechange = function () {
        if (script.readyState == 'loaded' || script.readyState == 'complete') {
          script.onreadystatechange = null;
          
          if (caller) {
            caller[callback]();
          } else {
            callback();
          }
        }
      };
    } else { // others
      script.onload = caller ? caller.callback : callback;
    }
    
    script.src = url;
    document.getElementsByTagName('head')[0].appendChild(script);
  }
});
