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

package EnsEMBL::Web::Component::Help::Preview;

## This is an anti-spam measure - it should stymie robots, and by switching field names
## between the 'honeypot' ones in the form and the real ones, should stop the rest :)

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $form = $self->new_form({'id' =>'contact', 'action' => {qw(type Help action SendEmail)}, 'method' => 'post'});
  my $fieldset = $form->add_fieldset;
  
  $fieldset->add_field([{
    'type'    => 'NoEdit',
    'name'    => 'name',
    'label'   => 'Your name',
    'value'   => $hub->param('name'),
  },{
    'type'    => 'NoEdit',
    'name'    => 'address',
    'label'   => 'Your email',
    'value'   => $hub->param('address'),
  },{
    'type'    => 'NoEdit',
    'name'    => 'subject',
    'label'   => 'Subject',
    'value'   => $hub->param('subject'),
  },{
    'type'    => 'NoEdit',
    'name'    => 'message',
    'label'   => 'Message',
    'value'   => $hub->param('message'),
  }]);

  $fieldset->add_hidden([{
    'name'    => 'string',
    'value'   => $hub->param('string'),
  },{
    'name'    => 'honeypot_1',
    'value'   => $hub->param('email'),
  },{
    'name'    => 'honeypot_2',
    'value'   => $hub->param('comments'),
  }]);


  $form->add_button({
    'buttons' => [{
      'type'    => 'Submit',
      'name'    => 'submit',
      'value'   => 'Back',
    },{
      'type'    => 'Submit',
      'name'    => 'submit',
      'value'   => 'Send Email',
    }]
  });

  return $form->render;
}

1;
