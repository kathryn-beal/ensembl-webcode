package Bio::EnsEMBL::GlyphSet::riken_prot;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Riken prots"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimilarityFeatures(
        "riken_prot", 80
    );
}

sub href {
    my ( $self, $id ) = @_;
    return $self->ID_URL('EMBL', $id );
}

sub zmenu {
    my ($self, $id ) = @_;
    $id =~ s/(.*)\.\d+/$1/o;
    return { 'caption' => "$id", "Protein homology" => $self->href( $id ) };
}
1;
