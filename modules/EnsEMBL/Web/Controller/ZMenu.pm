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

package EnsEMBL::Web::Controller::ZMenu;

### Prints the popup zmenus on the images.

use strict;

use base qw(EnsEMBL::Web::Controller);

sub init {
  my $self = shift;
  
  $self->builder->create_objects;
  
  my $hub    = $self->hub;
  my $object = $self->object;
  my $module = $self->get_module_names('ZMenu', $self->type, $self->action);
  my $menu   = $module->new($hub, $object);
  
  $self->r->content_type('text/plain');
  $menu->render if $menu;
}

1;
