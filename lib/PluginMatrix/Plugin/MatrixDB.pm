package PluginMatrix::Plugin::MatrixDB;

use Mojo::Base 'Mojolicious::Plugin';

use DBI;
use List::Util qw/max/;

sub register {
    my ($self, $app, $config) = @_;

    my %dbs;
    my $fws = $app->config->{frameworks} || {};
    
    for my $fw ( keys %{ $fws } ) {
        my $db_path = $app->home . '/public/' . $fws->{$fw}->{db};
        $dbs{$fw} = DBI->connect( "DBI:SQLite:$db_path" ) or $app->log->error( $DBI::errstr );
    }

    $app->helper( 'latest_perl' => sub {
        my ($c, $fw) = @_;
    
        my $select = 'SELECT distinct(perl_version) FROM matrix';
        my $sth    = $dbs{$fw}->prepare( $select );
        $sth->execute;
    
        my @perls;
        while ( my ($perl) = $sth->fetchrow_array() ) {
            my ($major, $minor, $patch, @rest) = split /[\.-]/, $perl;
            next if @rest;
            next if $minor % 2;
            push @perls, [ $perl, sprintf "%s%03s%03s", $major, $minor, $patch ];
        }
    
        my ($latest) = map { $_->[0] }sort{ $b->[1] <=> $a->[1] }@perls;
        return $latest;
    });
    
    $app->helper( 'latest_framework' => sub {
        my ($c, $fw) = @_;
    
        my $select = 'SELECT distinct(' . $fws->{$fw}->{column} . ') FROM matrix';
        my $sth    = $dbs{$fw}->prepare( $select );
        $sth->execute;
    
        my @versions;
        while ( my ($version) = $sth->fetchrow_array() ) {
            push @versions, $version;
        }
    
        my @sorted = sort{ $b <=> $a }@versions;
        return $sorted[0];
    });
    
    $app->helper( 'all_perl_versions' => sub {
        my ($c, $fw) = @_;
    
        my $select = 'SELECT distinct(perl_version) FROM matrix';
        my $sth    = $dbs{$fw}->prepare( $select );
        $sth->execute;
    
        my @perls;
        while ( my ($perl) = $sth->fetchrow_array() ) {
            my ($major, $minor, $patch, @rest) = split /[\.-]/, $perl;
            push @perls, [ $perl, sprintf "%s%03s%03s", $major, $minor, $patch ];
        }
    
        my @all = map { $_->[0] }sort{ $b->[1] <=> $a->[1] }@perls;
        return @all;
    });
    
    $app->helper( 'all_framework_versions' => sub {
        my ($c, $fw) = @_;
    
        my $select = 'SELECT distinct(' . $fws->{$fw}->{column} . ') FROM matrix';
        my $sth    = $dbs{$fw}->prepare( $select );
        $sth->execute;
    
        my @versions;
        while ( my ($version) = $sth->fetchrow_array() ) {
            push @versions, $version;
        }
    
        my @all = sort{ $a <=> $b }@versions;
        return @all;
    });

    $app->helper( get_plugins => sub {
      my ($c, $framework, $perls, $versions) = @_;

      my $column  = $fws->{$framework}->{column};
      my $perl_ph = join ', ', ('?') x @{ $perls || [] };
      my $fw_ph   = join ', ', ('?') x @{ $versions || [] };

      my $select  = qq~
          SELECT pname, pversion, abstract, perl_version, $column, result, author
          FROM matrix ~;
#          WHERE pversion IN ( $perl_ph ) OR
#              $column IN ( $fw_ph );
#      ~;
    
      my $sth = $dbs{$framework}->prepare( $select );
#      $sth->execute( @{ $perls }, @{ $versions } );
      $sth->execute;
    
      my %results = ( 0 => 'nok', 1 => 'ok', -1 => 'requires greater version of ' . ucfirst $framework );

      my %combis;

      for my $perl ( @{ $perls } ) {
          for my $fw ( @{ $versions } ) {
              $combis{ "$perl / $fw" } = 1;
          }
      }
    
      my %plugins;

      ROW:
      while ( my @row = $sth->fetchrow_array ) {
          $plugins{$row[0]}->{$row[1]}->{abstract} = $row[2];
          $plugins{$row[0]}->{$row[1]}->{author}   = $row[6];

          # save only requested perl/framework version combination
          next ROW if !$combis{ "$row[3] / $row[4]" };

          $plugins{$row[0]}->{$row[1]}->{"$row[3] / $row[4]"} = $results{$row[5]};
      }

      # delete all version that is not the latest version
      for my $plugin ( keys %plugins ) {
          my @keys = sort keys %{ $plugins{$plugin} };
          next if @keys == 1;

          pop @keys;

          delete @{ $plugins{$plugin} }{@keys};
      }
    
      return %plugins;
    });

    $app->helper( error_for => sub {
      my ($c, %param) = @_;

      my $framework = $param{framework};
      my $column    = $fws->{$framework}->{column};

      my $select  = qq~
          SELECT error_log
          FROM matrix
          WHERE perl_version = ? AND
                pversion     = ? AND
                $column      = ? AND
                pname        = ?
      ~;
    
      my $dbh = $dbs{$framework};
      my $sth = $dbs{$framework}->prepare( $select ) or die $dbh->errstr;
      $sth->execute(
        $param{perl},
        $param{version},
        $param{framework_version},
        $param{plugin},
      ) or die $dbh->errstr;

      my $error;
      while ( my ($log) = $sth->fetchrow_array ) {
        $error = $log;
      }

      return $error;
    });
}

1;
