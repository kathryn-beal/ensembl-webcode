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

package Bio::EnsEMBL::GlyphSet::structural_variation;

use strict;

use List::Util qw(min max);

use Bio::EnsEMBL::Variation::StructuralVariationFeature;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub somatic { return $_[0]->{'my_config'}->id =~ /somatic/; }
sub class   { return 'group' if $_[0]{'display'} eq 'compact'; }
sub depth   { return $_[0]{'display'} eq 'compact' ? 1 : $_[0]{'container'}->length <= 2e5 && $_[0]->my_config('max_size') ? undef : $_[0]->SUPER::depth; }

sub colour_key {
  my ($self, $f) = @_;
  
  if (!$self->{'colours_keys'}{$f}) {
    return $self->{'colours_keys'}{$f} = 'copy_number_variation'      if $self->{'display'} eq 'compact';
    return $self->{'colours_keys'}{$f} = 'somatic_breakpoint_variant' if $f->is_somatic && $f->breakpoint_order;
    
    if ($f->class_SO_term eq 'copy_number_variation') {
      my $ssv_class = $f->get_all_supporting_evidence_classes;
      return $self->{'colours_keys'}{$f} = $ssv_class->[0] if scalar @$ssv_class == 1;
    }
    
    $self->{'colours_keys'}{$f} = $f->class_SO_term;
  }
  
  return $self->{'colours_keys'}{$f};
}

sub render_compact {
  my $self = shift;
  $self->{'my_config'}->set('height', 12);
  return $self->render_normal;
}

sub features {
  my $self   = shift; 
  my $config = $self->{'config'};
  my $id     = $self->type;
  
  if (!$self->cache($id)) {
    my $slice      = $self->{'container'};
    my $set_name   = $self->my_config('set_name');
    my $study_name = $self->my_config('study_name');
    my $var_db     = $self->my_config('db') || 'variation';
    my ($features, %colours);
    
    if ($set_name) {
      $features = $slice->get_all_StructuralVariationFeatures_by_VariationSet($self->{'config'}->hub->get_adaptor('get_VariationSetAdaptor', $var_db)->fetch_by_name($set_name), $var_db);
    } elsif ($study_name) {
      $features = $slice->get_all_StructuralVariationFeatures_by_Study($self->{'config'}->hub->get_adaptor('get_StudyAdaptor', $var_db)->fetch_by_name($study_name), undef, $var_db);
    }
    else {
      my $source     = $self->my_config('source');
      my $min_size = $self->my_config('min_size');
      my $max_size = $self->my_config('max_size');
      my $start    = $slice->start;
      my $end      = $slice->end;
      my @display_features;
      
      # By source
      if ($source) {
        my $func  = $self->somatic ? 'get_all_somatic_StructuralVariationFeatures_by_source' : 'get_all_StructuralVariationFeatures_by_source';
        $features = $slice->$func($source, undef, $var_db);
      }
      else {
        my $func  = $self->somatic ? 'get_all_somatic_StructuralVariationFeatures' : 'get_all_StructuralVariationFeatures';
        $features = $slice->$func(undef, $var_db);
      }
      
      if ($min_size || $max_size) {
        for (my $i = 0; $i < scalar @$features; $i++) {
          my $length = $features->[$i]->length;
          push @display_features, $features->[$i] if ($max_size && $length <= $max_size) || ($min_size && $length >= $min_size);
        }
        
        # Generate blocks when the track is compacted in one line (except for the Larger Structural Variants track)
        if ($max_size && $self->{'display'} eq 'compact') {
          my $slice_adaptor    = $self->{'container'}->adaptor->db->get_db_adaptor('core')->get_SliceAdaptor;
          my @list             = sort { $a->seq_region_start <=> $b->seq_region_start } @display_features;
          my $block_nb         = 1;
             @display_features = ();
          
          for (my $i = 0; $i < scalar @list; $i++) {
            my $svf     = $list[$i];
            my $start   = $svf->seq_region_start;
            my $end     = $svf->seq_region_end;
            my $b_start = $start;
            my $b_end   = $end;
            
            while ($b_end >= $start) {
              last if $i == scalar @list - 1;
              
              my $svf2  = $list[$i+1];
                 $b_end = $end if $b_end < $end;
                 $start = $svf2->seq_region_start;
                 $end   = $svf2->seq_region_end;
              
              $i ++ if $b_end >= $start;
            }
            
            $b_end = $self->{'container'}{'end'} if $b_end > $self->{'container'}{'end'};
            
            my $sv_block = Bio::EnsEMBL::Variation::StructuralVariationFeature->new(
              -start => $b_start - $slice->start + 1,
              -end   => $b_end   - $slice->start + 1,
              -slice => $slice
            );
            
            $block_nb++;
            
            push @display_features, $sv_block;
          }
        }
        
        $features = \@display_features;
      } elsif ($self->somatic) { # Display only the correct breakpoint (somatic data)
        for (my $i = 0; $i < scalar @$features; $i++) {
          if (!$features->[$i]{'breakpoint_order'}) {
            push @display_features, $features->[$i];
            next;
          }
          
          my $seq_start = $features->[$i]->seq_region_start;
          my $seq_end   = $features->[$i]->seq_region_end;
          
          push @display_features, $features->[$i] if ($seq_start >= $start && $seq_start <= $end) || ($seq_end >= $start && $seq_end <= $end);
        }
        
        $features = \@display_features;
      }
    }
    
    foreach (@$features) {
      my $colour_key = $self->colour_key($_);
      $self->{'legend'}{'structural_variation_legend'}{$colour_key} = $colours{$colour_key} ||= $self->my_colour($colour_key);
    }
    
    $self->cache($id, $features);
  }
      
  return $self->cache($id) || [];
}

sub tag {
  my ($self, $f) = @_;
  my $colour = $self->my_colour($self->colour_key($f), 'tag');
  my @tags;
  
  if ($f->is_somatic && $f->breakpoint_order) {
    foreach my $coords ([ $f->start, $f->seq_region_start ], $f->start != $f->end ? [ $f->end, $f->seq_region_end ] : ()) {
      next if $coords->[0] < 0;
      
      push @tags, {
        style       => 'somatic_breakpoint',
        colour      => 'gold',
        border      => 'black',
        start       => $coords->[0],
        slice_start => $coords->[1]
      };
    }
  } else {
    my $border         = 'dimgray';
    my $inner_crossing = $f->inner_start && $f->inner_end && $f->inner_start >= $f->inner_end ? 1 : 0;
    
    if ($inner_crossing && $f->inner_start == $f->seq_region_end) {
      return {
        style  => 'rect',
        colour => $colour,
        border => $border,
        start  => $f->start,
        end    => $f->end
      };
    }
    
    return if $self->{'display'} eq 'compact';
    
    # start of feature
    if ($f->outer_start && $f->inner_start) {
      if ($f->outer_start != $f->inner_start && !$inner_crossing) {
        push @tags, {
          style => 'rect',
          start => $f->start,
          end   => $f->inner_start - $f->seq_region_start + $f->start
        };
      }
    } elsif ($f->outer_start) {
      if ($f->outer_start == $f->seq_region_start || $inner_crossing) {
        push @tags, {
          style => 'bound_triangle_right',
          start => $f->start,
          out   => 1
        };
      }
    } elsif ($f->inner_start) {
      if ($f->inner_start == $f->seq_region_start && !$inner_crossing) {
        push @tags, {
          style => 'bound_triangle_left',
          start => $f->start
        };
      }
    }
  
    # end of feature
    if ($f->outer_end && $f->inner_end) {
      if ($f->outer_end != $f->inner_end && !$inner_crossing) {
        push @tags, {
          style => 'rect',
          start => $f->end - $f->seq_region_end + $f->inner_end,
          end   => $f->end
        };
      }
    } elsif ($f->outer_end) {
      if ($f->outer_end == $f->seq_region_end || $inner_crossing) {
        push @tags, {
          style => 'bound_triangle_left',
          start => $f->end,
          out   => 1
        };
      }
    } elsif ($f->inner_end) {
      if ($f->inner_end == $f->seq_region_end && !$inner_crossing) {
        push @tags, {
          style => 'bound_triangle_right',
          start => $f->end
        };
       }
    }
  
    foreach (@tags) {
      $_->{'colour'} = $colour;
      $_->{'border'} = $border;
    }
  }
  
  return @tags;
}

sub render_tag {
  my ($self, $tag, $composite, $slice_length, $width, $start, $end, $img_start, $img_end) = @_;
  my $pix_per_bp = $self->scalex;
  my @glyph;

  if ($tag->{'style'} =~ /^bound_triangle_(\w+)$/ && $img_start < $tag->{'start'} && $img_end > $tag->{'end'}) {
    my $pix_per_bp = $self->scalex;
    my $x          = $tag->{'start'} + ($tag->{'out'} == ($1 eq 'left') ? 1 : -1) * (($tag->{'out'} ? 1 : ($width / 2) + 1) / $pix_per_bp);
    my $y          = $width / 2;
    
    # Triangle returns an array: the triangle, and an invisible rectangle behind it for clicking purposes
    @glyph = $self->Triangle({
      mid_point    => [ $x, $y ],
      colour       => $tag->{'colour'},
      bordercolour => $tag->{'border'},
      absolutey    => 1,
      width        => $width,
      height       => $y / $pix_per_bp,
      direction    => $1,
      z            => 10
    });
    
    $composite->push(pop @glyph);
  } elsif ($tag->{'style'} eq 'somatic_breakpoint') {
    my $slice = $self->{'container'};
    
    if ($tag->{'slice_start'} >= $slice->start && $tag->{'slice_start'} <= $slice->end) {
      my $x     = $tag->{'start'};
      my $y     = 2 * ($self->my_config('height') || [$self->get_text_width(0, 'X', '', $self->get_font_details($self->my_config('font') || 'innertext'), 1)]->[3] + 2);
      my $scale = 1 / $pix_per_bp;
      
      @glyph = $self->Poly({
        z            => 10,
        colour       => $tag->{'colour'},
        bordercolour => $tag->{'border'},
        points       => [
          $x - 0.5 * $scale, 1,
          $x + 4.5 * $scale, 1,
          $x + 2.5 * $scale, $y / 3 + 1,
          $x + 5.5 * $scale, $y / 3 + 1,
          $x,                $y, 
          $x + 0.5 * $scale, $y * 2 / 3 - 1,
          $x - 3.5 * $scale, $y * 2 / 3 - 1
        ],
      });
      
      $composite->push($self->Rect({
        z         => 1,
        x         => $x - 3.5 * $scale,
        width     => 9 * $scale,
        height    => $y,
        absolutey => 1,
      }));
    }
  }
  
  return @glyph;
}

sub href {
  my ($self, $f) = @_;
  
  return $self->_url({
    type => 'StructuralVariation',
    sv   => $f->variation_name,
    svf  => $f->dbID,
    vdb  => $self->my_config('db')
  });
}

sub title {
  my ($self, $f) = @_;
  my $id     = $f->variation_name;
  my $start  = $self->{'container'}->start + $f->start -1;
  my $end    = $self->{'container'}->end + $f->end;
  my $pos    = 'Chr ' . $f->seq_region_name . ":$start-$end";
  my $source = $f->source;

  return "Structural variation: $id; Source: $source; Location: $pos";
}

sub highlight {
  my ($self, $f, $composite, $pix_per_bp, $h, undef, @tags) = @_;
  
  return if     $self->{'display'} eq 'compact';
  return unless $self->core('sv') eq $f->variation_name;
  
  my $width = max(map $_->width, $composite, @tags);
  my $x     = min(map $_->x,     $composite, @tags);
  
  $self->unshift($self->Rect({
    x            => $x - 1/$pix_per_bp,
    y            => $composite->y - 1,
    width        => $width + 2/$pix_per_bp,
    height       => $h * ($f->is_somatic && $f->breakpoint_order ? 2 : 1) + 2,
    bordercolour => 'green',
    absolutey    => 1,
  }));
}

1;
