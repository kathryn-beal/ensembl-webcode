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

package EnsEMBL::Web::Configuration::StructuralVariation;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = 'Explore';
}


sub populate_tree {
  my $self = shift;
  
  $self->create_node('Explore', 'Explore this SV',
    [qw(
      explore EnsEMBL::Web::Component::StructuralVariation::Explore
    )],
    { 'availability' => 'structural_variation' }
  );
  
  
  my $context_menu = $self->create_node('Context', 'Genomic context',
    [qw( context  EnsEMBL::Web::Component::StructuralVariation::Context)],
    { 'availability' => 'structural_variation', 'concise' => 'Context' }
  );

  $context_menu->append($self->create_node('Mappings', 'Genes and regulation',
    [qw( mappings EnsEMBL::Web::Component::StructuralVariation::Mappings )],
    { 'availability' => 'has_transcripts', 'concise' => 'Genes and regulation' }
  ));
  
  $self->create_node('Evidence', 'Supporting evidence ([[counts::supporting_structural_variation]])',
    [qw( evidence  EnsEMBL::Web::Component::StructuralVariation::SupportingEvidence)],
    { 'availability' => 'has_supporting_structural_variation', 'concise' => 'Supporting evidence' }
  );
  
  $self->create_node('Phenotype', 'Phenotype Data',
    [qw( 
        phenotype EnsEMBL::Web::Component::StructuralVariation::Phenotype  
        genes     EnsEMBL::Web::Component::StructuralVariation::LocalGenes 
    )],
    { 'availability' => 'has_phenotype', 'concise' => 'Phenotype Data' }
  );
  
}
1;
