/*
 * Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// $Revision$

Ensembl.Panel.MultiSelector = Ensembl.Panel.extend({
  constructor: function (id, params) {
    this.base(id);
    this.urlParam = params.urlParam;
    
    Ensembl.EventManager.register('updateConfiguration', this, this.updateSelection);
    Ensembl.EventManager.register('modalPanelResize',    this, this.style);
  },
  
  init: function () {
    var panel = this;
    
    this.base();
    
    this.initialSelection = '';
    this.selection        = [];
    
    this.elLk.content = $('.modal_wrapper',       this.el);
    this.elLk.list    = $('.multi_selector_list', this.elLk.content);
    
    var ul    = $('ul', this.elLk.list);
    var spans = $('span', ul);
    
    this.elLk.spans    = spans.filter(':not(.switch)');
    this.elLk.form     = $('form', this.elLk.content);
    this.elLk.included = ul.filter('.included');
    this.elLk.excluded = ul.filter('.excluded');
    
    this.setSelection(true);
    
    this.elLk.included.sortable({
      containment: this.elLk.included.parent(),
      stop: $.proxy(this.setSelection, this)
    });
    
    this.buttonWidth = spans.filter('.switch').on('click', function () {
      var li = $(this).parent();
      var excluded, i;
      
      if (li.parent().hasClass('included')) {
        excluded = $('li', panel.elLk.excluded);
        i = excluded.length;

        while (i--) {
          if ($(excluded[i]).text() < li.text()) {
            $(excluded[i]).after(li);
            break;
          }
        }
        
        // item to be added is closer to the start of the alphabet than anything in the excluded list
        if (i === -1) {
          panel.elLk.excluded.prepend(li);
        }
        
        panel.setSelection();
        
        excluded = null;
      } else {
        panel.elLk.included.append(li);
        panel.selection.push(li.attr('class'));
      }
      
      li = null;
    }).width();
    
    this.style();
    
    $('.select_by select', this.el).on('change', function () {
      var toAdd, toRemove;
      
      switch (this.value) {
        case ''    : break;
        case 'all' : toAdd    = panel.elLk.excluded.children(); break;
        case 'none': toRemove = panel.elLk.included.children(); break;
        default    : toAdd    = panel.elLk.excluded.children(':contains(' + this.options[this.selectedIndex].innerHTML + ')'); 
                     toRemove = panel.elLk.included.children().not(':contains(' + this.options[this.selectedIndex].innerHTML + ')'); break;
      }
      
      if (toAdd) {
        panel.elLk.included.append(toAdd);
      }
      
      if (toRemove) {
        toRemove.add(panel.elLk.excluded.children()).detach().sort(function (a, b) { return $(a).text() > $(b).text(); }).appendTo(panel.elLk.excluded);
      }
      
      panel.setSelection();
      
      toAdd = toRemove = null;
    });
    
    
    ul = null;
  },
  
  style: function () {
    var width = 0;
    var initialWidth = this.elLk.list.removeClass('multi_selector_list_wide').width();
    
    this.elLk.list.addClass('multi_selector_list_wide');
    
    this.elLk.spans.each(function () {
      var w = $(this).width();
      
      if (w > width) {
        width = w;
      }
    });
    
    if (initialWidth > width + this.buttonWidth) {
      this.elLk.list.removeClass('multi_selector_list_wide');
    }
  },
  
  setSelection: function (init) {
    this.selection = $.map($('li', this.elLk.included), function (li, i) {
      return li.className;
    });
    
    if (init === true) {
      this.initialSelection = this.selection.join(',');
    }
  },
  
  updateSelection: function () {
    var params = [];
    var i;
    
    for (i = 0; i < this.selection.length; i++) {
      params.push(this.urlParam + (i + 1) + '=' + this.selection[i]);
    }
    
    if (this.selection.join(',') !== this.initialSelection) {
      Ensembl.redirect(this.elLk.form.attr('action') + '?' + Ensembl.cleanURL(this.elLk.form.serialize() + ';' + params.join(';')));
    }
    
    return true;
  }
});