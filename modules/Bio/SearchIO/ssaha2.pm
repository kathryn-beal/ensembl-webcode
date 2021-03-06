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


# Let the code begin...



package Bio::SearchIO::ssaha2;
use strict;
use vars qw(@ISA %MAPPING %MODEMAP $DEFAULT_BLAST_WRITER_CLASS );
use Bio::SearchIO;
use Bio::SearchIO::blast;

@ISA = qw(Bio::SearchIO );


BEGIN {
    # mapping of SSAHA terms to Bioperl hash keys
    %MODEMAP = 
      (
       'Result' => 'result',
       'Hit'    => 'hit',
       'Hsp'    => 'hsp'
		);
    
    
    %MAPPING = 
      (
       'algorithm_name'   => 'RESULT-algorithm_name',
       'query_name'       => 'RESULT-query_name',
       'query_acc'        => 'RESULT-query_accession',

       'hsp_score'        => 'HSP-score',
       'hsp_identical'    => 'HSP-identical',
       'hsp_length'       => 'HSP-hsp_length',
       'hsp_length'       => 'HSP-hsp_length',
       'hsp_conserved'    => 'HSP-conserved',
       'hsp_query_seq'    => 'HSP-query_seq',
       'hsp_hit_seq'      => 'HSP-hit_seq',
       'hsp_homology_seq' => 'HSP-homology_seq',
       'hsp_query_start'  => 'HSP-query_start',
       'hsp_query_end'    => 'HSP-query_end',
       #'hsp_query_strand' => 'HSP-query_strand',
       'hsp_hit_start'    => 'HSP-hit_start',
       'hsp_hit_end'      => 'HSP-hit_end',
       #'hsp_hit_strand'   => 'HSP-hit_strand',

       'hit_name'         => 'HIT-name',
       'hit_length'       => 'HIT-length',
       'hit_score'        => 'HIT-score',
       'hit_desc'         => 'HIT-description',
      );

    $DEFAULT_BLAST_WRITER_CLASS = 'Bio::Search::Writer::HitTableWriter';    
}

#----------------------------------------------------------------------

=head2 new

 Title   : new
 Usage   : my $obj = new Bio::SearchIO::ssaha();
 Function: Builds a new Bio::SearchIO::ssaha object 
 Returns : Bio::SearchIO::ssaha
 Args    : -fh/-file => filehandle/filename to SSAHA file
           -format   => 'ssaha'

=cut

sub _initialize {
  my ($self,@args) = @_;
  $self->SUPER::_initialize(@args);
  return 1;
}

#----------------------------------------------------------------------

=head2 next_result

 Title   : next_result
 Usage   : my $hit = $searchio->next_result;
 Function: Returns the next Result from a search
 Returns : Bio::Search::Result::ResultI object
 Args    : none

=cut

sub next_result{

  my $self = shift;
  my $data = '';

  # Assume single result set for SSAHA
  if( ref($self->{_elements}) eq 'ARRAY' ){ return }

  $self->start_document();

  my $qname_old = '';
  my $hname_old = '';
  my $hits = {};

  while( defined( my $line = $self->_readline )) { 
    next if( /^\s+$/); # skip empty lines

    if( $line =~ /^\d+/ ) { #Got a new result
      my( $score, $qname, $hname, $qstart, $qend, $hstart, $hend, $dir, $ident, $percent, $length ) = split /\s+/, $line;
      warn "SSAHA2: $score, $qname, $hname, $qstart, $qend, $hstart, $hend, $dir, $ident, $percent, $length\n"; 
      if( substr( $dir, 0, 1 ) eq 'C' ) { ($qstart,$qend)=($qend,$qstart) }
      if( $qname ne $qname_old ){ # New result
        if( $self->in_element('result') &&
            $self->end_result( $hits ) ){
          # End this result!
          $self->_pushback( $_ );
          last;
        }

        $qname_old = $qname;
        $self->start_result;
        $self->element({ Name => 'query_name',     Data => $qname });
        $self->element({ Name => 'algorithm_name', Data => 'FASTN' });
      }
      # Create and populate new hsp
      $hits->{$hname} ||= {};
      $hits->{$hname}->{hit_name} ||= $hname;
      my $hsp = {};
      $hsp->{hsp_identical}   = $ident;
      $hsp->{hsp_length}      = $length;
      $hsp->{hsp_conserved}   = $ident;
      $hsp->{hsp_query_start} = $qstart;
      $hsp->{hsp_query_end}   = $qend;
      $hsp->{hsp_hit_start}   = $hstart;
      $hsp->{hsp_hit_end}     = $hend;

      my $oscore = $hits->{$hname}->{hit_score} || 0;
      $hits->{$hname}->{hit_score} = $score > $oscore ? $score : $oscore;
      $hsp->{hsp_score} = $score;

      my $len;
      while( $_=$self->_readline() ){
        next if /^\s+$/;

        if( /^(Query\s+\d+\s+)(\S+)\s+(\d+)/ ) {
          $len = length( $1 );
          $hsp->{hsp_query_seq} .= $2;
          $_=$self->_readline();
        } else {
          $self->_pushback($_);
          last;
        }
        if( defined( $_ ) && defined( $len ) ) {
          chomp;
          $hsp->{hsp_homology_seq} .= substr( $_, $len );
          $_ = $self->_readline();
        } else {
          $self->throw("no data for midline $_");
        }
        if( /^(Sbjct\s+\d+)\s+(\S+)\s+(\d+)/ ) {
          $hsp->{hsp_hit_seq} .= $2;
          $_=$self->_readline();
        } else {
          $self->throw("no data for hitline $_");
        }
      }
      $hits->{$hname}->{hsps} ||= [];
      push( @{$hits->{$hname}->{hsps}}, $hsp );

    }
  } # while

  $self->in_element('result') && $self->end_result( $hits );
  return $self->end_document();
}

#----------------------------------------------------------------------
=head2 start_element

 Title   : start_element
 Usage   : $eventgenerator->start_element
 Function: Handles a start element event
 Returns : none
 Args    : hashref with at least 2 keys 'Data' and 'Name'


=cut

sub start_element{
  my ($self,$data) = @_;

  # Only deal with $MODEMAP mappings
  my $nm = $data->{'Name'};    
  my $type = $MODEMAP{$nm} || return;

  # New result/hit/hsp
  if( $self->_eventHandler->will_handle($type) ) {
    my $func = sprintf("start_%s",lc $type);
    $self->_eventHandler->$func($data->{'Attributes'});
  }

  unshift @{$self->{'_elements'}}, $type;
  if( $type eq 'result') {
    $self->{'_values'} = {};
    $self->{'_result'}= undef;
  } 

  else { 
    # cleanup some things
    if( defined $self->{'_values'} ) {
      foreach my $k ( grep { /^\U$type\-/ } 
		      keys %{$self->{'_values'}} ) { 
	delete $self->{'_values'}->{$k};
      }
    }
  }
}

#----------------------------------------------------------------------=
=head2 end_element

 Title   : start_element
 Usage   : $eventgenerator->end_element
 Function: Handles an end element event
 Returns : none
 Args    : hashref with at least 2 keys 'Data' and 'Name'


=cut

sub end_element {
  my ($self,$data) = @_;
  my $nm = $data->{'Name'};
  my $rc;

  # Hsp are sort of weird, in that they end when another
  # object begins so have to detect this in end_element for now
  if( $nm eq 'Hsp' ) {
    foreach ( qw(hsp_query_seq hsp_hit_seq hsp_homology_seq) ) {
      $self->element({'Name' => $_,
                      'Data' => $self->{'_last_hspdata'}->{$_}});
    }
    $self->{'_last_hspdata'} = {};
  }

  # Handle MODEMAP types (result, hit, hsp)
  if( my $type = $MODEMAP{$nm} ) {
    if( $self->_eventHandler->will_handle($type) ) {
      my $func = sprintf("end_%s",lc $type);
      $rc = $self->_eventHandler->$func($self->{'_reporttype'},
                                        $self->{'_values'});	    
    }
    $self->{'_result'} = $rc if( $type eq 'result' );
    shift @{$self->{'_elements'}};
  } 
  
  # Handle MAPPING types
  elsif( $MAPPING{$nm} ) { 	
    
    if ( ref($MAPPING{$nm}) =~ /hash/i ) {
      # this is where we shove in the data from the 
      # hashref info about params or statistics
      my $key = (keys %{$MAPPING{$nm}})[0];
      $self->{'_values'}->{$key}->{$MAPPING{$nm}->{$key}} = $self->{'_last_data'};
    } 
    else {
      $self->{'_values'}->{$MAPPING{$nm}} = $self->{'_last_data'};
    }
  }

  # Handle unknown types
  else { 
    $self->debug( "unknown nm $nm, ignoring\n");
  }

  $self->{'_last_data'} = ''; # remove read data if we are at 
  # end of an element
  return $rc;

}

#----------------------------------------------------------------------
sub start_result{
  my $self = shift;
  my $data = {};
  $data->{Name} = 'Result';
  return $self->start_element( $data );
}

#----------------------------------------------------------------------
sub end_result{
  my $self = shift;
  my $hits = shift;
  
  # Loop for each hit
  foreach my $hit( sort{ $b->{hit_score}<=>$a->{hit_score}} values( %$hits ) ){
    
    # Extract array of hsps
    my @hsps = @{$hit->{hsps}};
    delete $hit->{hsps};

    # Add hit data to new hit
    $self->start_element({ Name=>'Hit' });
    foreach my $name( keys %$hit ){
      $self->element({ Name=>$name, Data=>$hit->{$name} })
    }

    # Loop for each HSP
    foreach my $hsp( @hsps ){
      # Add hsp data to new hsp
      $self->start_element({ Name=>'Hsp' });
      foreach my $name( keys %$hsp ){
	$self->element({ Name=>$name, Data=>$hsp->{$name} })
      }
      $self->end_element({ Name=>'Hsp' });
    }
    $self->end_element({ Name=>'Hit' });
  }
  return $self->end_element({ Name=>'Result' });
}

#----------------------------------------------------------------------
=head2 element

 Title   : element
 Usage   : $eventhandler->element({'Name' => $name, 'Data' => $str});
 Function: Convience method that calls start_element, characters, end_element
 Returns : none
 Args    : Hash ref with the keys 'Name' and 'Data'


=cut

sub element{
   my ($self,$data) = @_;
   $self->start_element($data);       
   $self->characters($data);
   $self->end_element($data);
}

#----------------------------------------------------------------------
=head2 characters

 Title   : characters
 Usage   : $eventgenerator->characters($str)
 Function: Send a character events
 Returns : none
 Args    : string


=cut

sub characters{
   my ($self,$data) = @_;   

   if( $self->in_element('hsp') && 
       $data->{'Name'} =~ /hsp_(query_seq|hit_seq|homology_seq)/ ) {
     $self->{'_last_hspdata'}->{$data->{'Name'}} .= $data->{'Data'} || '';
   }  
   return unless ( defined $data->{'Data'} && $data->{'Data'} !~ /^\s+$/ );
   $self->{'_last_data'} = $data->{'Data'}; 
}

#----------------------------------------------------------------------
=head2 within_element

 Title   : within_element
 Usage   : if( $eventgenerator->within_element($element) ) {}
 Function: Test if we are within a particular element
           This is different than 'in' because within can be tested
           for a whole block.
 Returns : boolean
 Args    : string element name 


=cut

sub within_element{
   my ($self,$name) = @_;  
   return 0 if ( ! defined $name &&
		 ! defined  $self->{'_elements'} ||
		 scalar @{$self->{'_elements'}} == 0) ;
   foreach (  @{$self->{'_elements'}} ) {
       if( $_ eq $name  ) {
	   return 1;
       } 
   }
   return 0;
}

#----------------------------------------------------------------------
=head2 in_element

 Title   : in_element
 Usage   : if( $eventgenerator->in_element($element) ) {}
 Function: Test if we are in a particular element
           This is different than 'in' because within can be tested
           for a whole block.
 Returns : boolean
 Args    : string element name 


=cut

sub in_element{
   my ($self,$name) = @_;  
   return 0 if ! defined $self->{'_elements'}->[0];
   return ( $self->{'_elements'}->[0] eq $name)
}

#----------------------------------------------------------------------
=head2 start_document

 Title   : start_document
 Usage   : $eventgenerator->start_document
 Function: Handle a start document event
 Returns : none
 Args    : none


=cut

sub start_document{
  my ($self) = @_;
  $self->{'_lasttype'} = '';
  $self->{'_values'} = {};
  $self->{'_result'}= undef;
  $self->{'_elements'} = [];
}

#----------------------------------------------------------------------

=head2 end_document

 Title   : end_document
 Usage   : $eventgenerator->end_document
 Function: Handles an end document event
 Returns : Bio::Search::Result::ResultI object
 Args    : none


=cut

sub end_document{
  my ($self,@args) = @_;
  return $self->{'_result'};
}

#----------------------------------------------------------------------

sub write_result {
   my ($self, $blast, @args) = @_;

   if( not defined($self->writer) ) {
       $self->warn("Writer not defined. Using a $DEFAULT_BLAST_WRITER_CLASS");
       $self->writer( $DEFAULT_BLAST_WRITER_CLASS->new() );
   }
   $self->SUPER::write_result( $blast, @args );
}

sub result_count {
    my $self = shift;
    return $self->{'_result_count'};
}

sub report_count { shift->result_count }

#----------------------------------------------------------------------
1;
