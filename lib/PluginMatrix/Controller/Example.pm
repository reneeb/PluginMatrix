package PluginMatrix::Controller::Example;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub welcome {
  my $self = shift;

  $self->render;
}

sub framework {
  my $self = shift;

  my $framework = $self->param('framework_name');

  my $fws = $self->config->{frameworks} || {};

  if ( !$fws->{$framework} ) {
      $self->redirect_to('/');
      return;
  }

  my @perls      = @{ $self->every_param('perl') };
     @perls      = $self->latest_perl( $framework )      if !@perls;
  my @frameworks = @{ $self->every_param('framework') };
     @frameworks = $self->latest_framework( $framework ) if !@frameworks;

  my @combis = map{ my $perl = $_; map{ "$perl / $_" }@frameworks }@perls;
  my %plugins = $self->get_plugins( $framework, \@perls, \@frameworks );

  $self->stash(
    combis         => \@combis,
    plugins        => \%plugins,
    versions       => [ $self->all_framework_versions( $framework ) ],
    perls          => [ reverse $self->all_perl_versions( $framework ) ],
    selected_perls => \@perls,
    selected_fws   => \@frameworks,
    framework      => $framework,
  );

  $self->render;
}

1;
