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

package EnsEMBL::Web::ImageConfig::contigviewtop;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    sortable_tracks  => 'drag', # allow the user to reorder tracks on the image
    opt_empty_tracks => 0,      # include empty tracks
    opt_lines        => 1,      # draw registry lines
    min_size         => 1e6 * ($self->hub->species_defs->ENSEMBL_GENOME_SIZE || 1),
  });
  
  $self->create_menus(qw(
    sequence
    marker
    transcript
    misc_feature
    synteny
    variation
    decorations
    information
  ));
  
  $self->add_track('sequence',    'contig', 'Contigs',     'contig', { display => 'normal', strand => 'f' });
  $self->add_track('information', 'info',   'Information', 'text',   { display => 'normal'                });
  
  $self->load_tracks;
  $self->image_resize = 1;
  
  $self->modify_configs([ 'transcript' ], { render => 'gene_label', strand => 'r' });
  $self->modify_configs([ 'variation',  'variation_legend', 'structural_variation_legend' ], { display => 'off', menu => 'no' });
  
  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', menu => 'no'                }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', menu => 'no', strand => 'f' }],
    [ 'draggable', '', 'draggable', { display => 'normal', menu => 'no'                }]
  );
}

1;
