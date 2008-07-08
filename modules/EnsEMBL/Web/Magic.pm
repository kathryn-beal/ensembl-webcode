package EnsEMBL::Web::Magic;

### EnsEMBL::Web::Magic is the new module which handles
### script requests, producing the appropriate WebPage objects,
### where required... There are four exported functions:
### magic - clean up and logging; stuff - rendering whole pages;
### carpet - simple redirect handler for old script names; and
### ingredient - to create partial pages for AJAX inclusions.

use strict;
use EnsEMBL::Web::Document::WebPage;
use base qw(Exporter);
use CGI qw(redirect); # only need the redirect header stuff!
our @EXPORT = our @EXPORT_OK = qw(magic stuff carpet ingredient Gene Transcript Location menu);

### Three constants defined and exported to the parent scripts...
### To allow unquoted versions of Gene, Transcript and Location
### in the parent scripts.

sub Gene       { return 'Gene',       @_; }
sub Transcript { return 'Transcript', @_; }
sub Location   { return 'Location',   @_; }
sub Variation  { return 'Variation',  @_; }

sub magic      {
### Usage: use EnsEMBL::Web::Magic; magic stuff
###
### Postfix for all the magic actions! doesn't really do much!
### Could potentially be used as a clean up script depending
### on what the previous scripts do!
###
### In this case we use it as a way to warn lines to the error log
### to show what the script has just done!
  warn sprintf "MAGIC < %-60.60s > %s\n",$ENV{'REQUEST_URI'},shift;
}

sub carpet { 
### Usage: use EnsEMBL::Web::Magic; magic carpet Gene 'Summary'
### 
### Magically you away through the clouds away from the boring and
### mundane old existance of your 7 year old 'view' script to the
### wonderous realms of the magical new Ensembl 2.0 routing based
### 'action' script.
  my $URL         = sprintf '%s%s/%s/%s%s%s',
    '/', ## Fix this to include full path so as to replace URLs...
    $ENV{'ENSEMBL_SPECIES'},
    shift,  # object_type
    shift,  # action
    $ENV{'QUERY_STRING'}?'?':'',  $ENV{'QUERY_STRING'};
  redirect( -uri => $URL );
  return "Redirecting to $URL (taken away on the magic carpet!)";
}

sub menu {
### use EnsEMBL::Web::Magic; magic menu Gene; 
###
### Wrapper around a list of components to produce a zmenu
### for inclusion via AJAX
  warn "...CREATING WEBPAGE....";
  my $webpage     = EnsEMBL::Web::Document::WebPage->new(
    'objecttype' => shift || $ENV{'ENSEMBL_TYPE'},
    'scriptname' => 'zmenu'
  );
  warn $ENV{'ENSEMBL_TYPE'};
  warn ".... zmenu ...";
  $webpage->configure( $webpage->dataObjects->[0], 'ajax_zmenu' );
  $webpage->render;
  return "Generated magic menu ($ENV{'ENSEMBL_ACTION'})";
}

sub _parse_referer {
  warn $ENV{'HTTP_REFERER'};
  my ($url,$query_string) = split /\?/, $ENV{'HTTP_REFERER'};
  $url =~ /^https?:\/\/.*?\/(.*)$/;
  my($sp,$ot,$view) = split /\//, $1;

  my(@pairs) = split(/[&;]/,$query_string);
  my $params = {};
  foreach (@pairs) {
    my($param,$value) = split('=',$_,2);
    next unless defined $param;
    $value = '' unless defined $value;
    $param = CGI::unescape($param);
    $value = CGI::unescape($value);
    push @{$params->{$param}}, $value;
  }
  warn "";
  warn "\n";
  warn "------------------------------------------------------------------------------\n";
  warn "AJAX request (ingredient)\n";
  warn "\n";
  warn "  SPECIES: $sp\n";
  warn "  OBJECT:  $ot\n";
  warn "  VIEW:    $view\n";
  warn "  QS:      $query_string\n";
  foreach my $param( sort keys %$params ) {
    foreach my $value ( sort @{$params->{$param}} ) {
      warn sprintf( "%20s = %s\n", $param, $value );
    }
  }
  warn "------------------------------------------------------------------------------\n";

  return {
    'ENSEMBL_SPECIES' => $sp,
    'ENSEMBL_TYPE'    => $ot,
    'ENSEMBL_ACTION'  => $view,
    'params'          => $params
  };
}

sub ingredient {
### use EnsEMBL::Web::Magic; magic ingredient Gene 'EnsEMBL::Web::Component::Gene::geneview_image'
###
### Wrapper around a list of components to produce a panel or
### part thereof - for inclusion via AJAX
  my $referer_hash = _parse_referer;
  my $webpage     = EnsEMBL::Web::Document::WebPage->new(
    'objecttype' => shift || $ENV{'ENSEMBL_TYPE'},
    'scriptname' => 'component',
    'parent'     => $referer_hash
  );
  $webpage->configure( $webpage->dataObjects->[0], 'ajax_content' );
  $webpage->render;
  return "Generated magic ingredient ($ENV{'ENSEMBL_ACTION'})";
}

sub mushroom {
### use EnsEMBL::Web::Magic; magic mushroom
###
### AJAX Wrapper around pfetch to access the Mole/Mushroom requests for description

}

sub stuff {
### Usage use EnsEMBL::Web::Magic; magic stuff
###
### The stuff that dreams are made of - instead of using separate
### scripts for each view we know use a 'routing' approach which
### transmogrifies the URL and separates it into 'species', 'type' 
### and 'action' - giving nice, clean, systematic URLs for handling
### heirarchical object navigation
  my $object_type = shift || $ENV{'ENSEMBL_TYPE'};
  my $action = shift;
  my $command = shift;
  my $doctype = shift;
  my $webpage = EnsEMBL::Web::Document::WebPage->new( 
                  'objecttype' => $object_type, 
                  'doctype'    => $doctype,
                  'scriptname' => 'action',
                  'command'    => $command, 
  );
# The whole problem handling code possibly needs re-factoring 
# Especially the stuff that may end up cyclic! (History/UnMapped)
# where ID's don't exist but we have a "gene" based display
# for them.
  if( $webpage->has_a_problem ) {
    if( $webpage->has_problem_type('mapped_id') ) {
      my $feature = $webpage->factory->__data->{'objects'}[0];
      my $URL = sprintf "/%s/%s/%s?%s",
        $webpage->factory->species, $ENV{'ENSEMBL_TYPE'},$ENV{'ENSEMBL_ACTION'},
        join(';',map {"$_=$feature->{$_}"} keys %$feature );
      $webpage->redirect( $URL );
      return "Redirecting to $URL (mapped object)";
    } elsif ($webpage->has_problem_type('unmapped')) {
      my $f     = $webpage->factory;
      my $id  = $f->param('peptide') || $f->param('transcript') || $f->param('gene');
      my $type = $f->param('gene')    ? 'Gene' 
               : $f->param('peptide') ? 'ProteinAlignFeature'
           :                        'DnaAlignFeature'
           ;
      my $URL = sprintf "/%s/$object_type/Karyotype?type=%s;id=%s",
        $webpage->factory->species, $type, $id;

      $webpage->redirect( $URL );
      return "Redirecting to $URL (unmapped object)";
    } elsif ($webpage->has_problem_type('archived') ) {
      my $f     = $webpage->factory;
      my( $type, $param, $id ) = $f->param('peptide')    ? ( 'Transcript', 'peptide',    $f->param('peptide' )   )
                               : $f->param('transcript') ? ( 'Transcript', 'transcript', $f->param('transcript') )
                   :                           ( 'Gene',       'gene',       $f->param('gene')       )
                   ;
      my $URL = sprintf "/%s/%s/History?%s=%s", $webpage->factory->species, $type, $param, $id;
      $webpage->redirect( $URL );
      return "Redirecting to $URL (archived object)";
    } else {
      $webpage->render_error_page;
      return "Rendering Error page";
    }
  } else {
# This still works... (beth you may have to change the four parts that are configured - note these
# have changed from the old WebPage::simple_wrapper...
    foreach my $object( @{$webpage->dataObjects} ) {
      my @sections;
      if ($doctype && $doctype eq 'Popup') {
        @sections = qw(global_context local_context local_tools content_panel);
      }
      else {
        @sections = qw(global_context local_context local_tools context_panel content_panel);
      }
      $webpage->configure( $object, @sections );
    }
    $webpage->factory->fix_session; ## Will have to look at the way script configs are stored now there is only one script!!
    $webpage->render;
    return "Completing action";
  }
}

1;
