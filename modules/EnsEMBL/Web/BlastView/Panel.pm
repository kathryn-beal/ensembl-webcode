=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

#----------------------------------------------------------------------
#
# Base class for Mart system panel builders
#
# How does the Mart panel system work?
#
# The logical units in each Mart panel are:
#   The Panel
#     containing none or more 'blocks'
#       containing none or more 'entries'
#         containing none or more 'forms'
#
# Each logical unit is made up of table rows
# Each table row contains the same number of table cells
#
# Table cells are defined by HTML strings.
# These HTML strings come in two main forms:
#   padding/border cells, where formatting can be via <TMPL_VAR ...> tags.
#     <TMPL_VAR ...> tags are substituted by the HTML::Template calls
#   entry cells, where the entry placeholder is '%s'.
#     The '%s' placeholder is substituted using sprintf calls.
# Each cell is identified by a /single/ letter
#
# Table rows are defined by equal-length text strings.
#   Each letter of the text string refers to an individual table cell.
#   The table row is generated by concatenating appropriate table cells.
#
# Built panels for any combination of 'top-level' cgi params are cached
#----------------------------------------------------------------------

package EnsEMBL::Web::BlastView::Panel;

use strict;
use Carp;
use Data::Dumper;

use EnsEMBL::Web::BlastView::PanelCache;

use vars  qw( @ISA @EXPORT $SPECIES_DEFS );
@ISA    = qw( Exporter );
@EXPORT = ( 
	   "get_panel_warning", 
	  );

use EnsEMBL::Web::SpeciesDefs;
$SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new;

# Setup cache (can be accessed using $EnsEMBL::Web::BlastView::Panel::CACHE
use vars qw( $CACHE );
$CACHE = EnsEMBL::Web::BlastView::PanelCache->new();

use constant IMG_ROOT       => '/img/blastview';
use constant IMG_ROOT_ROVER => IMG_ROOT;
use constant IMG_BLANK      => '/img/blank.gif';
use constant IMG_WARN       => IMG_ROOT.'/warn.gif';

use vars qw( $PAGE_COLOR $BORDER_COLOR $MAIN_BG_COLOR 
	     $DARK_BG_COLOR $VDARK_BG_COLOR );

my $palette_ref = $SPECIES_DEFS->ENSEMBL_COLOURS || {};
my $palette_ref = $SPECIES_DEFS->ENSEMBL_STYLE || {};

my %palette = %{$palette_ref};
map{ $palette{$_} = "#".$palette{$_} } keys %palette;
$PAGE_COLOR     = '#FFFFFF';
$BORDER_COLOR   = '#999999';
$MAIN_BG_COLOR  = $palette{BACKGROUND3} || '#FFFFFF';
$DARK_BG_COLOR  = $palette{BACKGROUND1} || '#FFFFFF';
$VDARK_BG_COLOR = $palette{BACKGROUND1} || '#FFFFFF';

use constant TABLE => qq(
<TABLE cellspacing=0 cellpadding=0 border=0>%s
</TABLE> );

use constant ROW => qq(
 <TR>%s
 </TR> );

use constant CELL => qq(
  <TD>%s
  </TD> );

#----------------------------------------------------------------------
#----------------------------------------------------------------------
#
=head2 

  Arg [1]   : class
  Arg [2]   : hashref containing 2 hashrefs
              $arg->{celldefs} contains a hash of cell definitions
              $arg->{rowdefs}  contains a hash of row definitions
  Function  : Constructor method for MartPanel object
              Object populated with celldefs, rowdefs and generated rows.
  Returntype: MartPanel object
  Exceptions: Incorrect args (i.e. celldefs or rowdefs missing)
  Caller    : 
  Example   : my $panel = EnsEMBL::Web::BlastView::Panel->new({celldefs=>\%cells, rowdefs=>\%rows})

=cut
#
sub new{

  my $class = shift;
  my $args  = shift;

  if( ref( $args             ) ne 'HASH' ){ croak('Argument not a hashref') };
  if( ref( $args->{celldefs} ) ne 'HASH' ){ croak('No cell definitions'   ) };
  if( ref( $args->{rowdefs } ) ne 'HASH' ){ croak('No cell definitions'   ) };

  my $self = $args;
  bless $self, $class;
  $self->generate_rows();

  return $self;
}

#----------------------------------------------------------------------
#
=head2 generate_rows

  Arg [1]   : self
  Function  : Uses object row and cell definitions to genetate row html
  Returntype: boolean
  Exceptions: Rows do not all contain the same number of cells
              Rows refer to non-existent cells
  Caller    :
  Example   : $panel->generate_rows()

=cut
#
sub generate_rows{
  my $self = shift;

  my %rowlengths;
  foreach my $row ( keys %{$self->{rowdefs}} ){
    my $rowstr = $self->{rowdefs}->{$row}; # A text str representing the row
    $rowlengths{length($_)} ++; # Add length of this rowstr to rowlength hash

    my @cells = ();
    my $cell_counter = 0;
    my $span_counter = 0;
    foreach( split( '', $rowstr ) ){ # Each char of $rowstr maps to a cell

      my $previous_char = $cell_counter > 0 ? 
                          substr( $rowstr, $cell_counter-1, 1 ) : 
                          ''; 

      if( $previous_char ne $_ ){ # Not 'same as last' => new cell; reset span
	my $cell = $self->{celldefs}->{$_} 
	  || croak("No cell referenced by '$_'");
	push @cells, $cell;
	$span_counter = 1; 
      }
      else{ # 'same as last' => add to colspan
	$span_counter ++;
	unless( $cells[$#cells] =~ s/colspan=\d+/colspan=$span_counter/ ){
	  # Could not find colspan - add one after <TD 
	  unless( $cells[$#cells] =~ s/<TD /<TD colspan=$span_counter/ ){
	    # Give up - this ain't a table cell!
	    croak("Cell referenced by '$_' is not a table cell!");
	  }
	}
      }
      $cell_counter ++;
    }
    # Update self with generated row
    $self->{rows}->{$row} = sprintf( EnsEMBL::Web::BlastView::Panel::ROW, join( '', @cells ) );
  }

  # Check that all rows are the same length
  if( scalar( keys( %rowlengths ) ) > 1 ){ croak('Rows are different lengths') };
  return 1;
}

#----------------------------------------------------------------------
#
=head2 get_row

  Arg [1]   : self
  Arg [2]   : string - row name
  Function  : Accessor function for panel rows
  Returntype: string
  Exceptions: Arg [2] does not reference a valid row
  Caller    :
  Example   : $panel->get_row()

=cut
#
sub get_row{
  my $self = shift;
  my $name = shift;

  if( exists( $self->{rows} ) ){
    return $self->{rows}->{$name} || 
      croak("No row found with name '$name'");
  }
  elsif( exists( $self->{panel}->{rows} ) ){
    return $self->{panel}->{rows}->{$name} ||
      croak("No row found with name '$name'. Called from ", 
	  (caller)[1], " line ", (caller)[2]);    
  }
  else{ croak("No row found with name '$name'") }

}
1;

#----------------------------------------------------------------------
#
=head2 _gen_base_form

  Arg [1]   : string - type of form to generate (checkbox, radio...)
  Arg [2]   : string - form name
  Function  : Generates HTML forms for the MartPanel system
              The returned HTML contains HTML::Template variables that must
              be substituted using other MartPanel functions.
              In brief, the form 'name' is converted to <TMPL_VAR _$name>.
              Other form attributes (e.g. value. checked, selected) are 
              converted to <TMPL_VAR __$name-attribute>.
              The name can therefore be set separately to the attributes,
              thereby allowing for caching of part-generated panels.
  Returntype: string - HTML form (using HTML::Template variables)
  Exceptions: Incorrect args
  Caller    :
  Example   : my $form_tmpl = _gen_form( $type, $name );

=cut
#
sub _gen_base_form{

  use constant FORMS => 
    {
     CHECKBOX => qq(
        <INPUT type='checkbox'
               name='%s'
	       value='%s'
               <TMPL_VAR %s!!%s!!checked> %s /> ),

     CHECKBOX_OFF => qq(
	<IMG SRC='/img/blastview/checkbox_off.gif' 
             ALT='This selection is unavailable' onClick="javascript:alert(This selection is unavailable)" /> ),		

     RADIO => qq(
        <INPUT type='radio'
               name='%s'
	       value='%s'
               <TMPL_VAR %s!!%s!!checked> %s /> ),

     RADIO_OFF => qq(
	<IMG SRC='/img/blastview/radio_off.gif' ALT='This selection is unavailable' onClick="javascript:alert(This selection is unavailable)" /> ),		

     BUTTON => qq(
        <INPUT type='button'
               name='%s'
	       value='%s' %s />),

     SELECT => qq(
	<SELECT name='%s' %s> %s
        </SELECT> ),

     TEXT => qq(
        <INPUT type='text'
               name='%s'
               value='<TMPL_VAR %s!!value>' %s />),

     FILE => qq(
        <INPUT type='file'
               name='%s'
               value='<TMPL_VAR %s!!value>' %s />),

     TEXTAREA => qq(
        <TEXTAREA type='textarea'
               name='%s' wrap='off' %s ><TMPL_VAR %s!!value></TEXTAREA>),

     OPTION => qq(
          <OPTION value='%s' <TMPL_VAR %s!!%s!!selected> > %s </OPTION> ),

     IMAGE => qq(<INPUT type='image' 
                        name='%s_%s' 
                        src='%s' 
                        border=0 %s />),

     IMAGE2 => "<INPUT type='image' 
		       name='%s_%s' 
		       src = '".IMG_ROOT_ROVER."/%s_%s<TMPL_VAR %s!!%s!!selected>.gif' border=0 %s />",


     WARNING => qq(<TMPL_VAR %s!!warning>%s),

     HIDDEN  => qq(<INPUT type='hidden', 
		          name='%s', 
                          value='%s' %s />),

     HIDDEN2 => qq(<INPUT type='hidden', 
		          name='%s', 
		          value='<TMPL_VAR %s!!value>' %s />),
     
    };

  my $self = shift;
  my %args = @_;
  my $type    = $args{-type}    || croak( "No form type provided" );
  my $name    = $args{-name}    || confess( "No form name provided" );
  my $value   = defined( $args{-value} ) ? $args{-value} : $args{-name};
  my $src     = $args{-src}     || '';
  my $optref  = $args{-options} || [];
  my $option  = $args{-option};

  # Any additional args?
  my $multiple;
  if( $args{-multiple} ){ $multiple = 'MULTIPLE' }
  delete( @args{qw(-type -name -value -src -options -option -multiple ) } );
  my $extra = ( join ' ', 
                map{ /^-(.+)/ ? uc($1). "='$args{$_}'" : '' } 
                keys %args );
  $extra .= ' MULTIPLE="MULTIPLE"' if $multiple;
  my $tmpl = FORMS->{uc($type)} || croak( "Don't have a form of type '$type'" );

  if( uc( $type ) eq 'TEXTAREA' ){
    return sprintf( $tmpl, $name, $extra, $value );
  }
  
  if( uc( $type ) eq 'SELECT' ){
#    warn Dumper( $optref );
    my @optelems;
    if( ref($optref->[0]) eq 'ARRAY' ){
      # Option elements are name/value pairs
      @optelems = map{ $self->_gen_base_form( -type   =>'OPTION',
					      -name   =>$name,
					      -value  =>$_->[0],
					      -option =>$_->[1]) } @$optref;
    }
    else{
      # Option elements use the same value for name and value
      @optelems = map{ $self->_gen_base_form( -type   =>'OPTION',
					      -name   =>$name,
					      -value  =>$_,
					      -option =>$_ ) } @$optref; 
    }
    my $optstr   = join( '', @optelems );
    return sprintf( $tmpl, $name, $extra, $optstr );
  }

  if( uc( $type ) eq 'RADIO' ){
    return sprintf( $tmpl, $name, $value, $name, $value, $extra );
  }
  if( uc( $type ) eq 'CHECKBOX' ){
    my $check = sprintf( $tmpl, $name, $value, $name, $value, $extra );
    #my $maintain = $self->_gen_base_form( -type=>'HIDDEN', 
	#				  -name=>'_RECOVER', 
	#				  -value=>$name );
    my $maintain = $self->_gen_base_form( -type=>'HIDDEN', 
					  -name=>"_DEF_$name", 
					  -value=>0 );
    return $check.$maintain;
  }
  
  if( uc( $type ) eq 'BUTTON' ){
    return sprintf( $tmpl, $name, $value, $extra );
  }
  if( uc( $type ) eq 'OPTION' ){
    $value =~ s/\s+//g;
    return sprintf( $tmpl, $value, $name, $value, $option );
  }
  if( uc( $type ) eq 'IMAGE' ){
    return sprintf( $tmpl, $name, $value, $src, $extra );
  }
  if( uc( $type ) eq 'IMAGE2' ){
    return sprintf( $tmpl, $name, $value, $name, $value, $name, $value, 
		    $src, $extra );
  }
  if( uc( $type ) eq 'HIDDEN' ){
    return sprintf( $tmpl, $name, $value, $extra );
  }
  else{
    my @names = $tmpl =~ /\%s/g;
    @names = map{ $name } @names;
    pop @names;
    push @names, $extra;
    return sprintf( $tmpl, @names );
  }
}

#----------------------------------------------------------------------
#
=head2 _populate_base_forms

  Arg [1]   : HTML::Template object
  Arg [2]   : hashref of form name->value pairs
  Function  : Leaves   '<TMPL_VAR $name>' unchanged
              Replaces '<TMPL_VAR _$name>' with '_$value'
              Replaces '<TMPL_VAR __$name-$attr>' to '<TMPL_VAR _$value-$atr>'
  Returntype: HTML::Template object (populated)
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _populate_base_forms{
  my $tmpl = shift;
  my $meta = shift;

  # Create a template
  my $t = HTML::Template->new( scalarref => \$tmpl,
			       croak_on_bad_params => 0,
			       case_sensitive => 1 );

  # Build template params hash.
  my %params;
  my $VAR = '<TMPL_VAR %s>';
  foreach my $p( $t->query() ){ # loop for each param in tmpl
    my $value = $p;
    my $num;
    foreach ( keys %$meta ){ # loop for each key in $meta
      my $name = lc($_);
      my $newval = $meta->{$_};
      $value =~ s/_$name/$newval/;
    }

    # Peform the substitutions
    if( $value =~ s/^_// || $value eq $p ){ # retain TMPL_VAR
      $params{$p} = sprintf( $VAR, $value ) 
    } 
    else{ $params{$p} = $value } # replace TMPL_VAR
  }
  # Populate template
  $t->param( %params );
  return $t->output();
}

#----------------------------------------------------------------------
#
#
sub add_panel_header{
  my $self = shift;
  my $meta = shift || croak( 'Need meta data for this header' );
  ref( $meta ) eq 'HASH' || croak( 'First arg must be a hashref' );

  $self->add_block( sprintf( $self->get_row('panel_header'),
			     $meta->{LABEL} || '' ) );

  return 1;
}

#----------------------------------------------------------------------
#
#
sub add_block_header{
  my $self = shift;
  my $meta = shift || croak( 'Need meta data for this header' );
  ref( $meta ) eq 'HASH' || croak( 'First arg must be a hashref' );

  # Dereference
  my %meta = %$meta;

  # Get the label
  my $tmpl = $meta{LABEL} || croak ( 'Need a label for this header' );

  # Do the template substitution stuff
  my $t =  HTML::Template->new( scalarref => \$tmpl,
				die_on_bad_params => 0,
				case_sensitive => 1 );
  my %params;
  map{ $params{$_}="<TMPL_VAR $_>" } $t->query;
  $t->param(%params);
  $t->param(%meta);
  $self->add_entry( sprintf( $self->get_row('block_header'),
			     $t->output || '' ) );
  
  return 1;
}

#----------------------------------------------------------------------
#
#
sub add_entry_header{
  my $self = shift;
  my $meta = shift || croak( 'Need meta data for this header' );
  ref( $meta ) eq 'HASH' || croak( 'First arg must be a hashref' );

  $self->add_entry( sprintf( $self->get_row('entry_header'),
			     $meta->{LABEL} || '' ) );

  return 1;
}

#----------------------------------------------------------------------
#
#
sub add_entry_footer{
  my $self = shift;
  my $meta = shift || croak( 'Need meta data for this header' );
  ref( $meta ) eq 'HASH' || croak( 'First arg must be a hashref' );

  $self->add_entry( sprintf( $self->get_row('entry_footer'),
			     $meta->{LABEL} || '' ) );

  return 1;
}

#----------------------------------------------------------------------
#
#
sub add_warning{
  my $self = shift;
  my $meta = shift || croak( 'Need meta data for this header' );
  ref( $meta ) eq 'HASH' || croak( 'First arg must be a hashref' );

  $self->add_entry( sprintf( $self->get_row('warning'),
			     $meta->{LABEL} || '' ) );

  return 1;
}


#----------------------------------------------------------------------
#
=head2 add_block

  Arg [1]   : 
  Function : Adds a new block to the Panel object, and updates the
             block pointer. Returns the current block pointer(idx+1),
             equivalent to the total number of blocks.
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut
#
sub add_block{
  my $self  = shift;
  my $entry = shift || [];
  push( @{$self->{data}}, $entry );
  my $current_block = scalar( @{$self->{data}} );
  $self->{pointers}->{block} = $current_block;
  $self->{pointers}->{entry} = 0;
  $self->{pointers}->{form } = 0;
  return $current_block;
}

#----------------------------------------------------------------------
#
=head2 add_entry

  Arg [1]   : 
  Function  : Adds a new entry to the current block, and makes this the 
              current entry. Returns the current entry (idx+1),
              equivalent to the total number of entries for this block
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut
#
sub add_entry{
  my $self  = shift;
  my $entry = shift || [];
  my $current_block = $self->{pointers}->{block} || croak( 'Need new block' );
  push( @{$self->{data}->[$current_block-1]}, $entry );
  my $current_entry = scalar( @{$self->{data}->[$current_block-1]} );
  $self->{pointers}->{entry} = $current_entry;
  $self->{pointers}->{form}  = 0;
  return $current_entry;
}

#----------------------------------------------------------------------
#
=head2 add_form

  Arg [1]   : 
  Function  : Adds a new form to the current entry. Returns the current 
              entry (idx+1), equivalent to the total number of forms
              for this entry
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut
#
sub add_form{
  my $self = shift;
  my $form = shift || croak( 'Need some form data' ) ;

  my $current_block = $self->{pointers}->{block} || croak( 'Need new block' );
  my $current_entry = $self->{pointers}->{entry} || croak( 'Need new entry' );
  push( @{$self->{data}->[$current_block-1]->[$current_entry-1]}, $form );
  my $current_form  = 
    scalar( @{$self->{data}->[$current_block-1]->[$current_entry-1]} );
  $self->{pointers}->{form} = $current_form;
  return $current_form;
}

#----------------------------------------------------------------------
#
#
sub set_avail{
  my $self = shift;
  $self->{avail} = ( $_[0] eq 'off' ? 'off' : 'on'  );
  return( $self->{avail} );
}

sub output_simple{
  my $self = shift;
  foreach my $blockref( @{$self->{data}} ){
    ref( $blockref ) eq 'ARRAY' || next;

    foreach my $entryref( @$blockref ){
      ref( $entryref ) eq 'ARRAY' || next;
      $entryref = join( '', 
			$self->{entry_top_row},
			join( $self->{entry_padding_row},
			      @$entryref ),
			$self->{entry_base_row});	
    }
    $blockref = join( '',
		      $self->{block_top_row},
		      join( $self->{block_padding_row},
			    @$blockref ),
		      $self->{block_base_row});
  }
  
  return( "<TABLE cellspacing=0 cellpadding=0 border=0>\n".
	  $self->{panel_top_row}.
	  join( $self->{panel_padding_row},
		@{$self->{data}} ).
	  $self->{panel_base_row}.
	  "</TABLE>" );
}

#----------------------------------------------------------------------
# Generates the page HTML from $self->{data}
# $self->{data} is a nested array structure: blocks->entries->forms
#
sub output(){
  my $self = shift;
  my $extra = shift;
  my $tab_block = 0;
  my @blocks;
 
  foreach my $blockref( @{$self->{data}} ){
    if( ! ref( $blockref ) ){ # then this is a page label
      push @blocks, $blockref;
    }
    elsif( ref($blockref) eq 'ARRAY' ){ # then this is a block collection
      my @entries;
      foreach my $entryref( @$blockref ){

	if( ! ref($entryref) ){ # then this is a block label
	  #fix for tab block at top of export page
	  if ($entryref =~ /Select output type/){
	    $tab_block = 1;
	  }
	  else{
	    push @entries, $entryref;
	  }
	}
	elsif( ref($entryref) eq 'ARRAY' ){ # then this is a form collection
	  my @forms = @$entryref;
	  if ($tab_block == 1){ #fix for tab block
	    push @entries, join( '',@forms);
	  }
	  else{
	    push @entries, join( '',
			       $self->{entry_top_row},
			       join( $self->{entry_padding_row},
				     @forms ),
			       $self->{entry_base_row});
	  }
	}
      }
      if ($tab_block == 1){#fix for tab block
	push @blocks, join('',@entries);
	$tab_block = 0;
      }
      else{
	push @blocks, join( '',
			  $self->{block_top_row},
			  join( $self->{block_padding_row},
				@entries ),
			  $self->{block_base_row});
      }
    }
  }

  my $tmpl = sprintf( EnsEMBL::Web::BlastView::Panel::TABLE,
		      join( '',
			    $self->{panel_top_row},
			    join( $self->{panel_padding_row},
				  @blocks ),
			    $self->{panel_base_row} ) );

  my $t =  HTML::Template->new( scalarref => \$tmpl,
				die_on_bad_params => 0,
				case_sensitive => 1 );

  my %params;
  map{ $params{$_}="<TMPL_VAR $_>" } $t->query;
  $t->param(%params);

  $t->param( 
	    BORDER_COLOR   => $EnsEMBL::Web::BlastView::Panel::BORDER_COLOR,
	    PAGE_COLOR     => $EnsEMBL::Web::BlastView::Panel::PAGE_COLOR,
	    MAIN_BG_COLOR  => $EnsEMBL::Web::BlastView::Panel::MAIN_BG_COLOR,
	    DARK_BG_COLOR  => $EnsEMBL::Web::BlastView::Panel::DARK_BG_COLOR,
	    VDARK_BG_COLOR => $EnsEMBL::Web::BlastView::Panel::VDARK_BG_COLOR,
	    NORMAL_TEXT    => $self->{avail} eq 'off' ? 'text_off': 'text',
	    HEADER_TEXT    => $self->{avail} eq 'off' ? 'head_off': 'head',
	    INITIALISED    => $self->{avail} eq 'off' ? 'off'     : '',
	    %$extra
	   );

  return( $t->output );
}
#----------------------------------------------------------------------

=head2 get_panel_warning

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub get_panel_warning {
  my $tmpl = qq(<IMG src='%s' height=15 width=15> %s);
  my $text = shift || 'Unknown';
  return sprintf( $tmpl, IMG_WARN, $text );
  
}




1;
