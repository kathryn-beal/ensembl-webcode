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

package EnsEMBL::Web::ViewConfig::Gene::SpeciesTree;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  my $hash = $self->species_defs->multi_hash->{'DATABASE_COMPARA'}{'SPECIES_SET'} || {}; 
  
  my $defaults = {
    collapsability => 'gene',
  };
     
  #getting the clade colour for each species type (tree background colour based on the species type)
  foreach my $name (grep $hash->{$_}{'genetree_display'}, keys %$hash) {
    while (my ($key, $value) = each %{$hash->{$name}}) {
      $key   =~ s/^genetree_//;
      $value = join '_', @$value if ref $value eq 'ARRAY';
      $defaults->{"group_${name}_$key"} = $value;
    }
  }
  
  $self->set_defaults($defaults);
  $self->add_image_config('speciestreeview', 'nodas');
  $self->code  = join '::', grep $_, 'Gene::SpeciesTree', $self->hub->referer->{'ENSEMBL_FUNCTION'};  
  $self->title = 'Species Tree';
}

sub form {
  my $self = shift;
  
  $self->add_fieldset('Display options');
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'collapsability',
    label  => 'Viewing options for tree image',
    values => [ 
      { value => 'all',  caption => 'View full species tree' },
      { value => 'part', caption => 'View minimal species tree' }
    ]
  });    
}

1;
