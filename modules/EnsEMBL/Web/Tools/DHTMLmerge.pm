#!/usr/local/bin/perl
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

###############################################################################
#   
#   Name:        EnsEMBL::Web::Tools::DHTMLmerge
#    
#   Description: Populates templates for static content.
#                Run at server startup
#
###############################################################################

package EnsEMBL::Web::Tools::DHTMLmerge;

use strict;

use Digest::MD5 qw(md5_hex);
use CSS::Minifier;
use JavaScript::Minifier;

sub merge_all {
  my $species_defs = shift;
  
  $species_defs->{'_storage'}{'ENSEMBL_CSS_NAME'} = merge($species_defs, 'css');
  $species_defs->{'_storage'}{'ENSEMBL_JS_NAME'}  = merge($species_defs, 'js');
  
  $species_defs->store;
}

sub merge {
  my ($species_defs, $type, $dir, $subdir) = @_;
  my ($contents, $jquery);
  
  if ($dir && $subdir) {
    ($contents) = get_contents($type, $dir, $subdir);
  } else {
    foreach (reverse @{$species_defs->ENSEMBL_HTDOCS_DIRS || []}) {
      next if /biomart/; # Not part of Ensembl template system
      
      my @content   = get_contents($type, $_, 'components');
         $contents .= $content[0];
         $jquery   .= $content[1] if $content[1];
    }
  }
  
  # Convert style placeholders to actual colours
  if ($type eq 'css') {
    my $sequence_markup = $species_defs->colour('sequence_markup') || {}; # Add sequence markup colours to ENSEMBL_STYLE - they are used in CSS. This smells a lot like a hack.
    my %colours         = (%{$species_defs->ENSEMBL_STYLE || {}}, map { $_ => $sequence_markup->{$_}{'default'} } keys %$sequence_markup);
       $colours{$_}     =~ s/^([0-9A-F]{6})$/#$1/i for keys %colours;
       $contents        =~ s/\[\[(\w+)\]\]/$colours{$1}||"\/* ARG MISSING DEFINITION $1 *\/"/eg; 
  }
  
  return compress($species_defs, $type, $contents, $jquery);
}

sub get_contents {
  my ($type, $root, $subdir) = @_;
  my $dir        = "$root/$subdir";
  my $components = $dir =~ /components/;
  my ($contents, $jquery);
  
  if (-e $dir && -d $dir) {
    opendir DH, $dir;
    my @files = readdir DH;
    closedir DH;
    
    foreach (sort { -d "$dir/$a" <=> -d "$dir/$b" || lc $a cmp lc $b } grep /\w/, @files) {
      if (-d "$dir/$_") {
        my @content   = get_contents($type, $root, "$subdir/$_");
           $contents .= $content[0];
           $jquery   .= $content[1] if $content[1];
      } elsif (-f "$dir/$_" && /\.$type$/) {
        next if $components && !/^\d/;
        
        open I, "$dir/$_";
        local $/ = undef;
        my $file_contents = <I>;
        close I;
        
        if (/jquery(_ui)?\.js/) {
          $jquery .= $file_contents;
        } else {
          $contents .= $file_contents;
        }
      }
    }
  }
  
  return ($contents, $jquery);
}

sub compress {
  my ($species_defs, $type, $contents, $jquery) = @_;
  my $root_dir        = $species_defs->ENSEMBL_SERVERROOT;
  my $compression_dir = "$root_dir/utils/compression/";
  my $filename        = md5_hex("$jquery$contents");
  my $minified        = "$root_dir/htdocs/minified/$filename.$type";
  my $tmp             = "$minified.tmp";
  
  if (!-e $minified) {
    open O, ">$tmp" or die "can't open $tmp for writing";    
    
    if ($type eq 'js') {
      open   J, ">$tmp.jq";
      print  J $jquery;
      close  J;
      printf O '(function($,window,document,undefined){%s})(jQuery,this,document)', $contents; # wrap javascript for extra compression
    } else {
      print O $contents;
    }
    
    close O;
   
    if ($type eq 'js') {
      my $jq = join ' ', $species_defs->ENSEMBL_JAVA, '-jar', "$compression_dir/compiler.jar", '--js', "$tmp.jq", '--compilation_level', 'WHITESPACE_ONLY',      '--warning_level', 'QUIET';
      my $js = join ' ', $species_defs->ENSEMBL_JAVA, '-jar', "$compression_dir/compiler.jar", '--js', "$tmp",    '--compilation_level', 'SIMPLE_OPTIMIZATIONS', '--warning_level', 'QUIET';

      open  O, ">$minified" or die "can't open $minified for writing";
      print O `$_` for $jq, $js;
      close O;
      unlink "$tmp.jq";
    } else {
      system $species_defs->ENSEMBL_JAVA, '-jar', "$compression_dir/yuicompressor-2.4.7.jar", '--type', 'css', '-o', $minified, $tmp;
    }
    
    unlink $tmp;
    
    if (!-s $minified) {
      open  O, ">$minified" or die "can't open $minified for writing";
      print O $type eq 'css' ? CSS::Minifier::minify(input => $contents) : JavaScript::Minifier::minify(input => "$jquery$contents");
      close O;
    }
  }
  
  return $filename;
}

1;
