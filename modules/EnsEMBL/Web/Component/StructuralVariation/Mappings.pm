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

package EnsEMBL::Web::Component::StructuralVariation::Mappings;

use strict;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object         = $self->object;
  my $hub           = $self->hub;
  my $slice_adaptor = $hub->get_adaptor('get_SliceAdaptor');
  my %mappings      = %{$object->variation_feature_mapping};  # first determine correct SNP location 
  my $v;
  
  if (keys %mappings == 1) {
    ($v) = values %mappings;
  } elsif (!$hub->param('svf')){
    return $self->_info(
      'A unique location can not be determined for this variation',
      $object->not_unique_location);
  } else { 
    $v = $mappings{$hub->param('svf')};
  }
  
  if (!$v) { 
    return $self->_info(
      'Location problem',
      "<p>Unable to draw structural variant neighbourhood as we cannot uniquely determine the structural variant's location</p>"
    );
  }
  
  # get SVFs for all SSVs
  my @svfs = grep {
    $v->{start} == $_->seq_region_start &&
    $v->{end} == $_->seq_region_end &&
    $v->{Chr} == $_->seq_region_name
  } map {@{$_->get_all_StructuralVariationFeatures}}
  @{$object->Obj->get_all_SupportingStructuralVariants};
  
  return
    '<h2>Gene and Transcript consequences</h2>'.$self->gene_transcript_table(\@svfs).
    '<h2>Regulatory consequences</h2>'.$self->regfeat_table(\@svfs);
}

sub gene_transcript_table {
  my $self = shift;
  my $svfs = shift;
  
  my $hub = $self->hub;
  
  my $columns = [
    { key => 'gene',      sort => 'string',   title => 'Gene',                   width => '1u' },
    { key => 'trans',     sort => 'string',   title => 'Transcript (strand)',    width => '1u' },
    { key => 'allele',    sort => 'string',   title => 'Allele type',            width => '1u' },
    { key => 'type',      sort => 'string',   title => 'Consequence types',      width => '2u' },
    { key => 'trans_pos', sort => 'position', title => 'Position in transcript', width => '1u' },
    { key => 'cds_pos',   sort => 'position', title => 'Position in CDS',        width => '1u' },
    { key => 'prot_pos',  sort => 'position', title => 'Position in protein',    width => '1u' },
    { key => 'exons',     sort => 'string',   title => 'Exons',                  width => '1u' },
    { key => 'coverage',  sort => 'none',     title => 'Transcript coverage',    width => '1u' },
  ];
  
  my $rows = [];
  my $ga = $hub->get_adaptor('get_GeneAdaptor');
  
  foreach my $svf(@$svfs) {
    foreach my $tsv(@{$svf->get_all_TranscriptStructuralVariations}) {
      
      my $t = $tsv->transcript;
      my $g = $ga->fetch_by_transcript_stable_id($t->stable_id);
      
      my $gene_name  = $g ? $g->stable_id : '';
      my $trans_name = $t->stable_id;
      my $trans_type = '<b>biotype: </b>' . $t->biotype;
      my @entries    = grep $_->database eq 'HGNC', @{$g->get_all_DBEntries};
      my $gene_hgnc  = scalar @entries ? '<b>HGNC: </b>' . $entries[0]->display_id : '';
      my $strand     = $t->strand;
      my $exon       = $tsv->exon_number;
      $exon         =~ s/\// of /;
      my $allele    = sprintf('<p><span class="structural-variation-allele" style="background-color:%s"></span>%s</p>',
        $self->object->get_class_colour($svf->class_SO_term),
        $svf->var_class
      );
      
      my ($gene_url, $transcript_url);
      
      # Create links to non-LRG genes and transcripts
      if ($trans_name !~ m/^LRG/) {
        $gene_url = $hub->url({
          type   => 'Gene',
          action => 'Summary',
          db     => 'core',
          r      => undef,
          g      => $gene_name,
        });
      
        $transcript_url = $hub->url({
          type   => 'Transcript',
          action => 'Summary',
          db     => 'core',
          r      => undef,
          t      => $trans_name,
        });
      } else {
        $gene_url = $hub->url({
          type     => 'LRG',
          action   => 'Summary',
          function => 'Table',
          db       => 'core',
          r        => undef,
          lrg      => $gene_name,
          __clear  => 1
        });
      
        $transcript_url = $hub->url({
          type     => 'LRG',
          action   => 'Summary',
          function => 'Table',
          db       => 'core',
          r        => undef,
          lrg      => $gene_name,
          lrgt     => $trans_name,
          __clear  => 1
        });
      }
      
      foreach my $tsva(@{$tsv->get_all_StructuralVariationOverlapAlleles}) {
        
        my $type = join ', ',
          map { $hub->get_ExtURL_link($_->label, 'SEQUENCE_ONTOLOGY', $_->SO_accession) }
          sort {$a->rank <=> $b->rank}
          @{$tsva->get_all_OverlapConsequences};
        
        my %row = (
          gene      => qq{<a href="$gene_url">$gene_name</a><br/><span class="small" style="white-space:nowrap;">$gene_hgnc</span>},
          trans     => qq{<nobr><a href="$transcript_url">$trans_name</a> ($strand)</nobr><br/><span class="small" style="white-space:nowrap;">$trans_type</span>},
          allele    => $allele,
          type      => $type,
          trans_pos => $self->_sort_start_end($tsv->cdna_start,        $tsv->cdna_end),
          cds_pos   => $self->_sort_start_end($tsv->cds_start,         $tsv->cds_end),
          prot_pos  => $self->_sort_start_end($tsv->translation_start, $tsv->translation_end),
          exons     => $exon || '-',
          coverage  => $self->_coverage_glyph($t, $svf),
        );
        
        push @$rows, \%row;
      }
    }
  }

  return @$rows ? $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'gene asc' ], data_table_config => {iDisplayLength => 25} })->render : '<p>No Gene or Transcript consequences</p>';
}

sub regfeat_table {
  my $self = shift;
  my $svfs = shift;
  
  my $hub = $self->hub;
  
  my $columns = [
    { key => 'rf',       title => 'Feature',           sort => 'html'          },
    { key => 'ftype',    title => 'Feature type',      sort => 'string'        },
    { key => 'allele',   title => 'Allele type',       sort => 'string'        },
    { key => 'type',     title => 'Consequence types', sort => 'position_html' },
    { key => 'coverage', title => 'Feature coverage',  sort => 'string',       },
  ];
  
  my $rows = [];
  
  foreach my $svf(@$svfs) {
    foreach my $rsv(@{$svf->get_all_RegulatoryFeatureStructuralVariations}) {
      
      my $rf        = $rsv->feature->stable_id;
      my $ftype     = 'Regulatory feature';
      my $allele    = sprintf('<p><span class="structural-variation-allele" style="background-color:%s"></span>%s</p>',
        $self->object->get_class_colour($svf->class_SO_term),
        $svf->var_class
      );
      
      # create a URL
      my $url = $hub->url({
        type   => 'Regulation',
        action => 'Cell_line',
        rf     => $rsv->feature->stable_id,
        fdb    => 'funcgen',
      });
      
      foreach my $rsva(@{$rsv->get_all_StructuralVariationOverlapAlleles}) {
        my $type  = join ', ',
          map { $hub->get_ExtURL_link($_->label, 'SEQUENCE_ONTOLOGY', $_->SO_accession) }
          sort {$a->rank <=> $b->rank}
          @{$rsva->get_all_OverlapConsequences};
        
        my %row = (
          rf       => sprintf('<a href="%s">%s</a>', $url, $rf),
          ftype    => $ftype,
          allele   => $allele,
          type     => $type,
          coverage => $self->_coverage_glyph($rsv->feature, $svf),
        );
        
        push @$rows, \%row;
      }
    }
  }
  
  
  my $rfa = $hub->get_adaptor('get_RegulatoryFeatureAdaptor', 'funcgen');
  
  foreach my $svf(@$svfs) {
    foreach my $msv(@{$svf->get_all_MotifFeatureStructuralVariations}) {
      
      my $mf = $msv->feature;
      
      # check that the motif has a binding matrix, if not there's not 
      # much we can do so don't return anything
      next unless defined $mf->binding_matrix;
      my $matrix = $mf->display_label;
      
      # get the corresponding regfeat
      my $rf = $rfa->fetch_all_by_attribute_feature($mf)->[0];
  
      next unless $rf;
  
      # create a URL
      my $url = $hub->url({
        type   => 'Regulation',
        action => 'Cell_line',
        rf     => $rf->stable_id,
        fdb    => 'funcgen',
      });
      
      my $ftype     = 'Motif feature';
      my $allele    = sprintf('<p><span class="structural-variation-allele" style="background-color:%s"></span>%s</p>',
        $self->object->get_class_colour($svf->class_SO_term),
        $svf->structural_variation->var_class
      );
      
      foreach my $msva(@{$msv->get_all_StructuralVariationOverlapAlleles}) {
        my $type  = join ', ',
          map { $hub->get_ExtURL_link($_->label, 'SEQUENCE_ONTOLOGY', $_->SO_accession) }
          sort {$a->rank <=> $b->rank}
          @{$msva->get_all_OverlapConsequences};
        
        my %row = (
          rf       => sprintf('%s<br/><span class="small" style="white-space:nowrap;"><a href="%s">%s</a></span>', $mf->binding_matrix->name, $url, $rf->stable_id),
          ftype    => $ftype,
          allele   => $allele,
          type     => $type,
          coverage => $self->_coverage_glyph($mf, $svf),
        );
        
        push @$rows, \%row;
      }
    }
  }
  
  return @$rows ? $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'rf asc' ], data_table_config => {iDisplayLength => 25} })->render : '<p>No overlap with Ensembl Regulatory features</p>';
}

sub _coverage_glyph {
  my $self = shift;
  my $f    = shift;
  my $v    = shift;
  
  my $html  = '';
  my $width = 100;
  my ($f_s, $f_e, $v_s, $v_e) = (
    $f->seq_region_start,
    $f->seq_region_end,
    $v->seq_region_start,
    $v->seq_region_end,
  );
  
  # flip if on reverse strand
  if($f->strand == -1) {
    $f_e -= $f_s;
    $_ = $f_e - ($_ - $f_s) for ($v_s, $v_e);
    ($v_s, $v_e) = ($v_e, $v_s);
    $f_s = 0;
  }
  
  return '-' unless $v_s <= $f_e && $v_e >= $f_s;
  
  my $scale = 100 / ($f_e - $f_s + 1);
  my ($bp, $pc);
  
  $html .= '<div style="float: left; width:'.$width.'px; height: 10px; border: 1px solid black;">';
  
  # left part
  if($v_s > $f_s) {
    my $w = sprintf("%.0f", ($v_s - $f_s) * $scale);
    $html .= '<div style="width:'.$w.'px; height: 10px; float: left;"></div>';
  }
  
  # middle part
  if($v_s <= $f_e && $v_e >= $f_s) {
    my $s = (sort {$a <=> $b} ($v_s, $f_s))[-1];
    my $e = (sort {$a <=> $b} ($v_e, $f_e))[0];
    
    $bp = ($e - $s) + 1;
    $pc = sprintf("%.2f", 100 * ($bp / ($f->feature_Slice->length)));
    
    my $w = sprintf("%.0f", $bp * $scale);
    $html .= '<div style="width:'.$w.'px; height: 10px; background-color: '.$self->object->get_class_colour($v->class_SO_term).'; float: left;"></div>';
  }
  
  $html .= '</div>';
  
  # container for glyph and direction indicator
  $html = '<div style="width:'.($width + 12).'px; height: 10px;">'.$html.'</div>';
  
  return
    '<div style="width:'.($width + 12).'px">'.
      $html.
      sprintf("<span class='small' style='float:right'>%ibp, %s\%</span>", $bp, $pc).
    '</div>';;
}

sub _sort_start_end {
  my ($self, $start, $end) = @_;
  
  if ($start || $end) { 
    if ($start == $end) {
      return $start;
    } else {
      $start ||= '?';
      $end   ||= '?';
      return "$start-$end";
    }
  } else {
    return '-';
  };
}
1;
