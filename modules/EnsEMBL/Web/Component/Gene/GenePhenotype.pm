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

package EnsEMBL::Web::Component::Gene::GenePhenotype;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;
use HTML::Entities qw(encode_entities);
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my $phenotype = $hub->param('sub_table');
  my $object    = $self->object;
  my ($display_name, $dbname, $ext_id, $dbname_disp, $info_text) = $object->display_xref;
  
  # Gene phenotypes
  return $self->gene_phenotypes();
}



sub source_link {
  my ($self, $source, $ext_id, $vname, $gname) = @_;
  
  my $source_uc = uc $source;
  $source_uc    = 'OPEN_ACCESS_GWAS_DATABASE' if $source_uc =~ /OPEN/;
  
  if ($ext_id) {
    $source_uc .= '_ID' if $source_uc =~ /COSMIC/;
    $source_uc  = $1 if $source_uc =~ /(HGMD)/;
  }
  my $url = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{$source_uc};

  if ($ext_id && $ext_id ne 'no-ref') {
    if ($url =~/gwastudies/) {
      $ext_id =~ s/pubmed\///; 
      $url    =~ s/###ID###/$ext_id/;
    } 
    elsif ($url =~ /omim/) {
      $ext_id    =~ s/MIM\://; 
      $url =~ s/###ID###/$ext_id/;
    } 
    else {
      $url =~ s/###ID###/$ext_id/;
    }
  } 
  elsif ($vname || $gname) {
    if ($url =~ /omim/) {
        my $search = "search?search=".($vname || $gname);
        $url =~ s/###ID###/$search/; 
    } 
    elsif ($url =~/hgmd/) {
      $url =~ s/###ID###/$gname/;
      $url =~ s/###ACC###/$vname/;
    } 
    elsif ($url =~/cosmic/) {
      if ($vname) {
	      my $cname = ($vname =~ /^COSM(\d+)/) ? $1 : $vname;
			  $url =~ s/###ID###/$cname/;
      }
      else {
			  $url =~ s/###ID###/$gname/;
      } 
		} 
    else {
      $url =~ s/###ID###/$vname/;
    }
  }
  elsif ($url =~ /(.+)\?/) { # Only general source link
    $url = $1;
  }
  else {
    $url =~ s/###ID###//;
  }
  return $url ? qq{<a rel="external" href="$url">$source</a>} : $source;
}


sub gene_phenotypes {
  my $self             = shift;
  my $object           = $self->object;
  my $obj              = $object->Obj;
  my $hub              = $self->hub;
  my $species          = $hub->species_defs->SPECIES_COMMON_NAME;
  my $g_name           = $obj->stable_id;
  my $html             = qq{<a id="gene_phenotype"></a><h2>List of phenotype(s) associated with the gene $g_name</h2>};
  my (@rows, %list, $list_html);
  
  # add rows from Variation DB, PhenotypeFeature
  if ($hub->database('variation')) {
    my $pfa = $hub->database('variation')->get_PhenotypeFeatureAdaptor;
    
    # OMIA needs tax ID
    my $tax = $hub->species_defs->TAXONOMY_ID;
    if ($species eq 'Mouse') {
      my $features;
      foreach my $pf (@{$pfa->fetch_all_by_Gene($obj)}) {
        my $phen   = $pf->phenotype->description;
        my $ext_id = $pf->external_id;
        my $source = $pf->source;
        my $strain = $pf->strain;
        my $strain_name = encode_entities($strain->name);
        my $strain_gender = $strain->gender;
        my $allele_symbol = encode_entities($pf->allele_symbol);
        if ($ext_id && $source) {
          $source = $hub->get_ExtURL_link($source, $source, { ID => $ext_id, TAX => $tax});
        }
        my $locs = sprintf(
            '<a href="%s">View on Karyotype</a>',
            $hub->url({
              type    => 'Phenotype',
              action  => 'Locations',
              ph      => $pf->phenotype->dbID
             })
        );
        # display one row for phenotype associated with male and female strain
        my $pf_id = $pf->id;
        my $key = join("\t", ($phen, $strain_name, $allele_symbol));
        $features->{$key}->{source} = $source;
        push @{$features->{$key}->{gender}}, $strain_gender;
        $features->{$key}->{locations} = $locs;
      }
      foreach my $key (sort keys %$features) {
        my ($phenotype, $strain_name, $allele_symbol) = split("\t", $key);
        push @rows, {
          source => $features->{$key}->{source},
          phenotype => $phenotype,
          allele => $allele_symbol,
          strain => $strain_name .  " (" . join(', ', sort @{$features->{$key}->{gender}}) . ")",
          locations =>  $features->{$key}->{locations},
        };
      }
    } else {    
      foreach my $pf(@{$pfa->fetch_all_by_Gene($obj)}) {
        my $phen   = $pf->phenotype->description;
        my $ext_id = $pf->external_id;
        my $source = $pf->source;
      
        if($ext_id && $source) {
          $source = $hub->get_ExtURL_link($source, $source, { ID => $ext_id, TAX => $tax});
        }
        
        my $locs = sprintf(
          '<a href="%s">View on Karyotype</a>',
          $hub->url({
            type    => 'Phenotype',
            action  => 'Locations',
            ph      => $pf->phenotype->dbID
          })
        );
      
        push @rows, { source => $source, phenotype => $phen, locations =>  $locs};
      }
    }
  }
  if ($species eq 'Mouse') {
	return $html . $self->new_table([
      { key => 'phenotype', align => 'left', title => 'Phenotype' },
      { key => 'source',    align => 'left', title => 'Source'    },
      { key => 'strain',    align => 'left', title => 'Strain'    },
      { key => 'allele',    align => 'left', title => 'Allele'    },
      { key => 'locations', align => 'left', title => 'Locations' },
    ], \@rows, { data_table => 'no_sort no_col_toggle', exportable => 1 })->render;
  } else {  
      return $html . $self->new_table([ 
      { key => 'phenotype', align => 'left', title => 'Phenotype'     },
      { key => 'source',    align => 'left', title => 'Source'        },
      { key => 'locations', align => 'left', title => 'Locations'     },
    ], \@rows, { data_table => 'no_sort no_col_toggle', exportable => 1 })->render;
  }
}

1;
