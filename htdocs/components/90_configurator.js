var next_menu_node_id = 1;

function _menu_create_node( n, n_id, current_state ) {
/* 
  Function to create a hide/show link on a node...
*/
  var q = Builder.node('span',
    { id: n_id, className: 'menu_help' },
    [ current_state ? 'Hide info' : 'Show info' ]
  );
  n.appendChild(q);
  Event.observe(q,'click',function(e){
    remove_grey_box();
    var me = Event.findElement(e,'SPAN');
    var n  = me.parentNode;
    var t = me.id;
    var x = t+'_dd';
    me.remove();
    if( $(x) ) {
      $(x).toggle();
      _menu_create_node( n, t, $(x).visible() );
    }

  });
}

var current_menu_id = '';
var current_link_id = '';
var current_selected_node = '';
var initial_configuration = false;

function __init_config_menu() {
/*
  Section 1)
  Loop through all the track configuration links on the left hand side of the
  configuration box, remove the link (so the href doesn't get fired (yuk!)
  add an onclick event to show the appropriate menu and hide the menu
*/
  if( ! initial_configuration ) { 
    initial_configuration = $('config') ? $('config').serialize(true) : false;
  }

  var has_configuration = $$('.track_configuration').length > 0;
  if( has_configuration ) {
    if($('modal_tabs')) { // This is in the AJAX mode!!
      $$('modal_tabs a').each(function(n){
        alert( n.innerHTML );
        Event.observe(n,'click',configurator_submit_form);
      });
      Event.observe( $('modal_close'),'click',function(e){
        configurator_submit_form();
        modal_dialog_close();
      });
    }
  }
  $$('.track_configuration dd').each(function(n) {
    var link_id = n.id;
    var menu_id = 'menu_'+link_id.substr(5);
    if( n.hasClassName('active') ) {
      current_menu_id = menu_id;
      current_link_id = link_id;
    } else {
      $(menu_id).hide();
    }
    var an = n.select('a')[0]; 
    if( an ) {
      var txt =an.innerHTML;
      an.remove();
      n.appendChild(Builder.node('span', { className: 'fake_link' }, [ txt ] ));
    }
    Event.observe( n, 'click', function(e) {
      remove_grey_box();
      var dd_n = Event.findElement(e,'DD');
      var link_id = dd_n.id;
      var menu_id = 'menu_'+link_id.substr(5);
      if( current_menu_id ) {
        $(current_menu_id).hide();
        $(current_link_id).removeClassName('active');
      }
      $(menu_id).show();
      dd_n.addClassName('active');
      current_menu_id=menu_id;
      current_link_id=link_id;
    });
  });
/*
  Section 2)
  Add a hide/show link to each of the menu items on the right handside...
*/
  $$('.config_menu').each(function(menu_n){
    var col          = 1;
    var current_node = 0;
    menu_n.childElements().each(function(n){
      if(n.nodeName == 'DT') {
        col = 3-col;
        n.addClassName('col'+col);
	if( ! n.hasClassName( 'title' ) && !n.hasClassName('munged') ) {
	  n.addClassName( 'munged' ); // Stop a double rendering of the links!
          _menu_create_node( n, 'mn_'+next_menu_node_id, 0 );
	}
        current_node = next_menu_node_id;
        next_menu_node_id++;
        n.select('select').each(function(sn){
	  if(sn.visible()) {
            var current_selected = 'off';
            sn.hide();
            sn.select('option').each(function(on){
              if(on.selected) {
                var x = on.value;
                var i = Builder.node('img',{
                  src:'/i/render/'+x+'.gif', title:on.text,
                  cursor: 'hand',
                  id:'gif_'+sn.id
                });
                n.insertBefore(i,sn.nextSibling);
                Event.observe(i,'click',change_img_value);
             }
            });
	  }
        });
      } else if(n.nodeName == 'DD' && current_node) {
        n.setAttribute('id','mn_'+current_node+'_dd');
        n.addClassName('col'+col);
        n.hide();
      }
    });
  });
  if( $('config') ) {
    Event.observe( $('config'), 'submit', function(f){
      alert($('config').serialize());
    });
  }
}

function configurator_submit_form() {
  remove_grey_box();
  var final_configuration = $('config') ? $('config').serialize(true) : {};
  initial_configuration = false;
  var diff_configuration = {};
  final_configuation.each(function(pair){
    if( pair.value != inital_configuration[pair.key] ) {
      diff_configuration[ pair.key ] = pair.value;
    }
  });
  alert( diff_config.toQueryString() );
}

function remove_grey_box() {
  if( $('s_menu') ) $('s_menu').remove();
  current_selected_index = 0;
}

function change_img_value(e) {
  var i_node = Event.element(e);
  var select_id = i_node.id.substr(4);
      current_selected_index = select_id;
  var value     = i_node.src;
  if($('s_menu')) $('s_menu').remove();
//  i_node.absolutize();
  var x = Position.cumulativeOffset(i_node);
  var select_menu = Builder.node('dl',{
    id:       's_menu',
    className:'popup_menu',
    style:    'position:absolute;top:'+(x[1]+15)+'px;left:'+(x[0]+10)+'px;z-index: 1000000;'
  });
  $$('body')[0].appendChild(select_menu);

  $(select_id).select('option').each(function(on){
    dt_node = Builder.node('dt',
      [ Builder.node('img',  {title: on.text,src:'/i/render/'+on.value+'.gif'}),on.text ]
    )
    select_menu.appendChild(dt_node);
    Event.observe(dt_node,'click',function(e){
      var value = Event.findElement(e,'DT').select('img')[0].title;
      dt_node.parentNode.remove();
      $(current_selected_index).select('option').each(function(on){
        if(on.text == value) {
          on.selected = "selected";
          $('gif_'+current_selected_index).src = '/i/render/'+on.value+'.gif';
          current_selected_index = 0; return;
        }
      });
    });
  });
//  i_node.relativize();
}

addLoadEvent(__init_config_menu);
