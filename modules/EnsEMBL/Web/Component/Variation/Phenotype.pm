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

package EnsEMBL::Web::Component::Variation::Phenotype;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $vf     = $self->hub->param('vf');
  my $html;
  ## first check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;

  my $data = $object->get_external_data();

  return 'We do not have any external data for this variation' unless (scalar @$data);

  my $is_somatic = $object->Obj->is_somatic;
  my $study      = $is_somatic ? 'Tumour site' : 'Study'; 

  # Select only the phenotype features which have the same coordinates as the selected variation
  my $vf_object = ($vf) ? $self->hub->database('variation')->get_VariationFeatureAdaptor->fetch_by_dbID($vf) : undef;
  if ($vf_object) {
    my $chr   = $vf_object->seq_region_name;
    my $start = $vf_object->seq_region_start;
    my $end   = $vf_object->seq_region_end;
    my @new_data = grep {$_->seq_region_name eq $chr && $_->seq_region_start == $start && $_->seq_region_end == $end} @$data;
    $data = \@new_data;
  }

  my ($table_rows, $column_flags) = $self->table_data($data);
  my $table      = $self->new_table([], [], { data_table => 1 });
     
  if (scalar keys(%$table_rows) != 0) {

    $table->add_columns(
      { key => 'disease', title => 'Disease/Trait', align => 'left', sort => 'html' },  
      { key => 'source',  title => 'Source(s)',     align => 'left', sort => 'html' },
    );
    if ($column_flags->{'s_evidence'}) {
      $table->add_columns({ key => 's_evidence', title => 'Supporting evidence(s)', align => 'left', sort => 'html' });
    }
    
    $table->add_columns({ key => 'study', title => $study, align => 'left', sort => 'html' });

    if ($column_flags->{'clin_sign'}) {
      $table->add_columns({ key => 'clin_sign', title => 'Clinical significance', align => 'left', sort => 'html' });
    }
      
    $table->add_columns(
      { key => 'genes',     title => 'Reported gene(s)',      align => 'left', sort => 'html' },
      { key => 'variant',   title => 'Associated variant(s)', align => 'left', sort => 'none' },
    );
    
    if (!$is_somatic) {
      $table->add_columns(
        { key => 'allele',  title => 'Most associated allele', align => 'left', sort => 'string'    },
        { key => 'pvalue',  title => 'P value',                align => 'left', sort => 'numeric' }
      );
    }
   
    # Odds ratio
    if ($column_flags->{'odds_ratio'}) {    
      $table->add_columns({ key => 'odds_ratio',  title => 'Odds ratio', align => 'left', sort => 'string' });
    }
    # Beta coefficient
    if ($column_flags->{'beta_coef'}) {
      $table->add_columns({ key => 'beta_coef',  title => 'Beta coefficient', align => 'left', sort => 'string' });
    }

    $table->add_rows(@$_) for values %$table_rows;
    $html .= sprintf qq{<h3>Significant association(s)</h3>};
    $html .= $table->render;
  }
  
  my $info_text = qq{
    This variant might have phenotypes with non-significant associations, which are not shown on the website. 
    However these phenotype associations are available through the <a href="/info/data/mysql.html" rel="external">Ensembl Variation databases</a>, 
    the <a href="/info/docs/api/variation/index.html" rel="external">Ensembl Variation Perl API</a> or the <a href="/biomart/martview" rel="external">Ensembl BioMart</a>.
  };
  $html .= $self->_info('Non-significant phenotype associations', $info_text);
  
  return $html;
};


sub table_data { 
  my ($self, $external_data) = @_;
  
  my $hub        = $self->hub;
  my $object     = $self->object;
  my $is_somatic = $object->Obj->is_somatic;
  my %rows;
  my %column_flags;
   
  my $mart_somatic_url = 'http://www.ensembl.org/biomart/martview?VIRTUALSCHEMANAME=default'.
                         '&ATTRIBUTES=hsapiens_snp_som.default.snp.refsnp_id|hsapiens_snp_som.default.snp.chr_name|'.
                         'hsapiens_snp_som.default.snp.chrom_start|hsapiens_snp_som.default.snp.associated_gene'.
                         '&FILTERS=hsapiens_snp_som.default.filters.phenotype_description.&quot;###PHE###&quot;'.
                         '&VISIBLEPANEL=resultspanel';
                 
                 
  foreach my $pf (@$external_data) { 
    
    my $phenotype = $pf->phenotype->description;
    my $disorder  = $phenotype;
    
    if ($is_somatic) {
      $disorder =~ s/\:/ /;
      $disorder =~ s/\:/\: /;
      $disorder =~ s/\_/ /g;
    }
    
    my @data_row;
        
    if (exists $rows{lc $disorder}) { 
      @data_row = @{$rows{lc $disorder}};
    }
    
    my $id                 = $pf->{'_phenotype_id'};
    my $source_name        = $pf->source;
    my $study_name         = $pf->study ? $pf->study->name : '';
    my $disease_url        = $hub->url({ type => 'Phenotype', action => 'Locations', ph => $id, name => $disorder }); 
    my $external_id        = ($pf->external_id) ? $pf->external_id : $study_name;
    my $source             = $self->source_link($source_name, $external_id, $pf->external_reference, 1);
    my $external_reference = $self->external_reference_link($pf->external_reference) || $pf->external_reference; # use raw value if can't be made into a link
    my $associated_studies = $pf->associated_studies; # List of Study objects
    
    my $clin_sign = $pf->clinical_significance;
    if ($clin_sign) {
      $clin_sign = qq{<span class="hidden export">$clin_sign</span><img class="_ht" style="margin-right:5px;vertical-align:top" src="/i/val/clinsig_$clin_sign.png" title="$clin_sign" />};
      $column_flags{'clin_sign'} = 1;
    }
    
    # Add the supporting evidence source(s)
    my $a_study_source = '';
    if (defined($associated_studies)) {
      $a_study_source = $self->supporting_evidence_link($associated_studies, $pf->external_reference);
    }

    if ($is_somatic) { 
      my @tumour_info      = split /\:/, $disorder;
      my $tissue           = $tumour_info[1];
      $tissue              =~ s/^\s+//;
      my $tissue_formatted = $tissue;
      my $source_study     = uc($source_name) . '_STUDY'; 
      $tissue_formatted    =~ s/\s+/\_/g; 
      $external_reference  = $hub->get_ExtURL_link($tissue, $source_study, $tissue_formatted);
    }
   
    my $gene         = $self->gene_links($pf->associated_gene);
    my $allele       = $self->allele_link($pf->external_reference, $pf->risk_allele) || $pf->risk_allele;
    my $variant_link = $self->variation_link($pf->object->stable_id);
    my $pval         = $pf->p_value;
    my $attributes   = $pf->get_all_attributes();

    my $disease  = qq{<b>$disorder</b>};
    
    # BioMart link
    my $bm_flag = 0;
    if ($disease =~ /COSMIC/) { 
      if ($pf->adaptor->count_all_by_phenotype_id($id) > 250) {
        $disease_url = $mart_somatic_url;
        $disease_url =~ s/###PHE###/$phenotype/;
        $disease .= qq{<br /><a href="$disease_url">[View list in BioMart]</a>};
        $bm_flag = 1;
      }
    }
    # Karyotype link
    if ($bm_flag == 0) {
      $disease .= qq{<br /><a href="$disease_url">[View on Karyotype]</a>} unless ($disease =~ /HGMD/);
    }

    my $row = {
      disease   => $disease,
      source    => $source,
      study     => $external_reference,
      clin_sign => $clin_sign, 
      genes     => $gene,
      allele    => $allele,
      variant   => $variant_link,
      pvalue    => $pval
    };
  
    if ($a_study_source ne ''){
      $row->{s_evidence} = $a_study_source;
      $column_flags{s_evidence} = 1;
    }

    # Odds ratio and beta coefficient
    foreach my $attr ('odds_ratio', 'beta_coef') {
      if ($attributes->{$attr}) {
        $row->{$attr} = $attributes->{$attr};
        $column_flags{$attr} = 1;
      }
    }
    
    push @data_row, $row;
    $rows{lc $pf->phenotype->description} = \@data_row;
  } 

  return \%rows,\%column_flags;
}


sub gene_links {
  my ($self, $data) = @_;
  
  return unless $data;
  
  my $hub   = $self->hub;
  my @genes = split(',', $data);
  my @links;
  
  my $gene_adaptor = $hub->get_adaptor('get_GeneAdaptor', 'core');
  my $tr_adaptor   = $hub->get_adaptor('get_TranscriptAdaptor', 'core');
  my $arch_adaptor = $hub->get_adaptor('get_ArchiveStableIdAdaptor', 'core');
  
  foreach my $g (@genes) {
    
    $g =~ s/\s//g;
    my $gname = $g; 
    my $trname;
    
    if ($g =~ /^(\S+)_(\S+)/) {
      $gname = $1;
      $trname = $2;
    }
    
    
    # try to fetch gene & transcript
    my $linkable = 0;
    my $tr_linkable = 0;
    
    # external name
    $linkable = 1 if scalar @{$gene_adaptor->fetch_all_by_external_name($gname)};
    # stable_id
    unless($linkable) {
      $linkable = 1 if $gene_adaptor->fetch_by_stable_id($gname);
    }
    # archive stable_id
    unless($linkable) {
      $linkable = 1 if $arch_adaptor->fetch_by_stable_id($gname);
    }
    
    if ($trname) {
      $tr_linkable = 1 if $tr_adaptor->fetch_by_stable_id($trname);
    }
    
    if ($linkable) {
      my %params = ( type => 'Gene', action => 'Summary', g => $gname );
      $params{t} = $trname if ($tr_linkable);
      my $url = $hub->url(\%params);
      push @links, qq{<a href="$url">$g</a>};
    } else { 
      push @links, $g;
    }
  }
  
  my $gene_links = join ', ', @links; 
  
  return $gene_links;
}


sub source_link {
  my ($self, $source, $ext_id, $ext_ref_id, $code) = @_;
  
  my $source_uc = uc $source;
  $source_uc    = 'OPEN_ACCESS_GWAS_DATABASE' if $source_uc =~ /OPEN/;
  my $url       = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{$source_uc};
  my $label     = $source;
  my $name;
  if ($url =~ /ega/) {
    my @ega_data = split('\.',$ext_id);
    $name = (scalar(@ega_data) > 1) ? $ega_data[0].'*' : $ega_data[0];
    $label = $ext_id;
  } 
  elsif ($url =~ /gwastudies/) {
    $ext_ref_id =~ s/pubmed\///; 
    $name = $ext_ref_id;
  } 
  elsif ($url =~ /clinvar/) {
    $ext_id =~ /^(.+)\.\d+$/;
    $name = ($1) ? $1 : $ext_id;
  } 
  elsif ($url =~ /omim/) {
    if ($code) {
      $name = "search?search=".$self->object->name;
    }
    else {
      $ext_ref_id =~ s/MIM\://; 
      $name = $ext_ref_id;
    }     
  } else {
    $name = $self->object->Obj->name;
  }
  
  $url =~ s/###ID###/$name/;
  
  return $source if $url eq "";
  
  return qq{<a rel="external" href="$url">[$label]</a>};
}


sub external_reference_link {
  my ($self, $study, $allele) = @_;
  my $link;
  if($study =~ /pubmed/) {
    $link = qq{http://www.ncbi.nlm.nih.gov/$study};
    $study =~ s/\//:/g;
    return qq{<a rel="external" href="$link">$study</a>};
  }
  
  elsif($study =~ /^MIM\:/) {
    foreach my $mim (split /\,\s*/, $study) {
      my $id = (split /\:/, $mim)[-1];
      my $sub_link;
      # Most associated allele
      if (defined($allele)) {
        $sub_link = $self->hub->get_ExtURL_link($mim, 'OMIM', '');
        my @parts = split /\"/, $sub_link;
        $parts[1] .= 'entry/'.$id.'#'.$allele;
        $parts[-1] =~ s/\>[^\<]+\</\>$allele\</;
        $sub_link = join('"', @parts);
      }
      # Study
      else {
        $sub_link = $self->hub->get_ExtURL_link($mim, 'OMIM', $id);
      }
      $link .= ', '.$sub_link;
      $link =~ s/^\, //g;
    }
    
    return $link;
  }
  else {
    return '';
  }
}


# Supporting evidence links
sub supporting_evidence_link {
  my ($self, $associated, $ext_id) = @_;
  my $as_html = '';
  my $count = 0;
  my $se_by_line = 2;
  foreach my $st (@{$associated}) {
    if ($as_html ne '') { $as_html .= ', '; }
    if ($count==$se_by_line) {
      $as_html .= '<br />';
      $count = 0;
    }
    my $a_url = $st->url;
    if (!defined($a_url)) {
      $as_html .= $self->source_link($st->source,$st->name,$ext_id);
    }
    # Temporary link to fix the problem of the non stable IDs for the EGA studies coming from dbGAP
    elsif ($a_url =~ /ega/ && $self->hub->species eq 'Homo_sapiens') {
      my $source = $st->source.'_SEARCH';
      $as_html .= $self->source_link($source,$st->name,$ext_id);
    }
    else {
      my $a_source = $st->source;
      if ($st->name) { $a_source = $st->name; }
      $as_html .= qq{<a rel="external" href="$a_url">[$a_source]</a>};
    }
    $count++;
  }
  return $as_html;
}


sub allele_link {
  my ($self, $study, $allele) = @_;
  
  # Only create allele-specific link if the study is a OMIM record and the allele is defined
  return '' unless ($study =~ /^MIM\:/ && defined($allele));
  return $self->external_reference_link($study,$allele);
}


sub variation_link {
  my ($self, $v) = @_;
  my $url = $self->hub->url({ type => 'Variation', action => 'Summary', v => $v });
  return qq{<a href="$url">$v</a>};
}

1;
