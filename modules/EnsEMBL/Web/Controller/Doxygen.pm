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

# $Id$

package EnsEMBL::Web::Controller::Doxygen;

use strict;

use base qw(EnsEMBL::Web::Controller::SSI);

sub content {
  my $self = shift;
  
  if (!$self->{'content'}) {
    # Read html file into memory
    {
      local($/) = undef;
      open FH, $self->r->filename;
      $self->{'content'} = <FH>;
      close FH;
    }
  }
  
  return $self->{'content'};
}

sub render_page {
  my $self     = shift;
  my $page     = $self->page;
  my $hub      = $self->hub;
  my $func     = $self->renderer->{'_modal_dialog_'} ? 'get_json' : 'content';
  my $elements = $page->elements;
  my @order    = map $_->[0], @{$page->head_order}, @{$page->body_order};
  my $content  = {};
  
  foreach my $element (@order) {
    my $module = $elements->{$element};
    $module->init($self) if $module->can('init');
  }
  
  $elements->{'body_javascript'}->add_source('/info/docs/Doxygen/doxygen.js');
  $elements->{'stylesheet'}{'media'}{'all'} = [ grep /^\//, @{$elements->{'stylesheet'}{'media'}{'all'}} ];
  
  foreach my $element (@order) {
    my $module = $elements->{$element};
    $content->{$element} = $module->$func();
  }
  
  my $page_content = $page->render($content);
  
  $self->set_cached_content($page_content) if $page->{'format'} eq 'HTML' && !$self->hub->has_a_problem;
}

1;
