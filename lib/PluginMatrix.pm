package PluginMatrix;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  push @{ $self->plugins->namespaces }, 'PluginMatrix::Plugin';

  $self->plugin('Config' => { file => $self->home . '/conf/plugin_matrix.conf' });
  $self->plugin('MatrixDB');

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('example#welcome');
  $r->any('/:framework_name')->to('example#framework');
}

1;
