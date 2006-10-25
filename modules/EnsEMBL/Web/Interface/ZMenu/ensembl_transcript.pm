package EnsEMBL::Web::Interface::ZMenu::ensembl_transcript;

use EnsEMBL::Web::Interface::ZMenu;
our @ISA = qw(EnsEMBL::Web::Interface::ZMenu);

sub populate {
  my $self = shift;
  $self->title($self->ident);
  $self->add_text('text1', "This is a ZMenu");
  $self->add_link(text => "Ensembl &hearts; AJAX", url => "http://www.ajaxian.com");
}

1;
