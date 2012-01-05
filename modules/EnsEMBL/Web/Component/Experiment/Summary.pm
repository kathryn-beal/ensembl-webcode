package EnsEMBL::Web::Component::Experiment::Summary;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::Experiment);

sub caption       { 'Experiment Sources Summary' }
sub short_caption { 'Experiment Sources Summary' }

sub content {
  my $self    = shift;
  my $object  = $self->object;
  my $hub     = $self->hub;

  my $grouped_feature_sets      = $object->get_grouped_feature_sets;
  my $total_actual_experiments  = $object->total_experiments;
  my $total_fetched_experiments = scalar @{$object->get_feature_sets_info};
  my $count_applied_filters     = scalar keys %{$object->applied_filters};

  my $table   = $self->new_table(
    [
      { 'key' => 'count',         'title' => 'Number of experiments', 'align' => 'right', 'width' => '150px', 'sort' => 'numeric' },
      { 'key' => 'show',          'title' => '', 'sort' => 'none' },
      { 'key' => 'filter_value',  'title' => ''             },
      { 'key' => 'filter_type',   'title' => 'Filter type'  },
      { 'key' => 'desc',          'title' => 'Description'  },
    ],
    [],
    {'data_table' => 1, 'class' => 'no_col_toggle', 'exportable' => 0}
  );

  for my $filter_type (sort keys %$grouped_feature_sets) {
    my $filter_values = $grouped_feature_sets->{$filter_type};
    while (my ($filter_value, $grouped_feature_types) = each %$filter_values) {
      my $all_count         = $grouped_feature_types->{'count'};
      my $filtered_count    = $grouped_feature_types->{'filtered'} || '0';
      my $filter_applied    = $object->is_filter_applied($filter_type, $filter_value);
      my $filter_link       = $filter_type eq 'All' || $total_actual_experiments eq $total_fetched_experiments || $object->is_single_feature_view || $filter_applied
        ? !$filter_applied
        ? $filter_type eq 'All' && $total_actual_experiments eq $total_fetched_experiments
        ? 'Displayed'
        : sprintf('<a href="%s">Show</a>', $hub->url({'ex' => $object->get_url_param({$filter_type, $filter_value})}))
        : sprintf('<a href="%s">Remove filter</a>', $hub->url({'ex' => $object->get_url_param({$filter_type, $filter_value}, -1)}))
        : sprintf('<a href="%s">Add filter</a>', $hub->url({'ex' => $object->get_url_param({$filter_type, $filter_value}, 1)}))
      ;

      $table->add_row({
        'count'         => $all_count,
        'show'          => $filter_link,
        'filter_value'  => encode_entities($filter_value),
        'filter_type'   => encode_entities($filter_type),
        'desc'          => encode_entities($grouped_feature_types->{'description'})
      });
    }
  }

  return '<p class="space-below">A summary of experimental meta data for sources used in the Ensembl regulation views.</p>'.$table->render;
}

1;