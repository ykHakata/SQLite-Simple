use strict;
use warnings;
use utf8;
use Test::More;
use FindBin;
use lib ( "$FindBin::RealBin/../lib", "$FindBin::RealBin/../local/lib/perl5" );
use Data::Dumper;
use SQLite::Simple;
use File::Spec;
use File::Temp qw/ tempfile tempdir /;
use File::Path qw(make_path remove_tree);

subtest 'Class and Method' => sub {
    new_ok('SQLite::Simple');
};

subtest 'args' => sub {
    my $obj = new_ok(
        'SQLite::Simple' => [
            { db_file_path => 'db/sample.db', sql_file_path => 'sample.sql', }
        ]
    );
    is( $obj->db_file_path,  'db/sample.db', "db_file_path" );
    is( $obj->sql_file_path, 'sample.sql',   "sql_file_path" );
};

subtest 'build insert dump restore' => sub {
    my $temp = File::Temp->newdir( DIR => $FindBin::RealBin, CLEANUP => 1, );
    my $test_dir = $temp->dirname;
    my $dump     = File::Spec->catfile( $test_dir,         'sample.dump' );
    my $db       = File::Spec->catfile( $test_dir,         'sample.db' );
    my $sql      = File::Spec->catfile( $FindBin::RealBin, 'test.sql' );
    my $csv      = File::Spec->catfile( $FindBin::RealBin, 'test.csv' );
    my $args     = +{
        db_file_path   => $db,
        sql_file_path  => $sql,
        dump_file_path => $dump,
    };
    my $obj       = new_ok( 'SQLite::Simple' => [$args] );
    my $build_msg = $obj->build();
    like( $build_msg->{message}, qr/success/, 'success init' );
    like( $build_msg->{message}, qr/sample/,  'success init' );
    my $params = +{
        csv   => $csv,
        table => 'user',
        cols  => [
            'loginid',    'password', 'approved', 'deleted',
            'created_ts', 'modified_ts',
        ],
        time_stamp => [ 'created_ts', 'modified_ts', ],
    };
    my $insert_msg = $obj->build_insert($params);
    like( $insert_msg->{message}, qr/success/, 'success insert' );
    my $dump_msg = $obj->build_dump();
    like( $dump_msg->{message}, qr/success/, 'success dump' );
    my $restore = $obj->build_restore();
    like( $restore->{message}, qr/success/, 'success restore' );
};

subtest 'db access' => sub {
    my $temp = File::Temp->newdir( DIR => $FindBin::RealBin, CLEANUP => 1, );
    my $test_dir = $temp->dirname;
    my $dump     = File::Spec->catfile( $test_dir,         'sample.dump' );
    my $db       = File::Spec->catfile( $test_dir,         'sample.db' );
    my $sql      = File::Spec->catfile( $FindBin::RealBin, 'test.sql' );
    my $args     = +{
        db_file_path   => $db,
        sql_file_path  => $sql,
        dump_file_path => $dump,
    };
    my $obj = new_ok( 'SQLite::Simple' => [$args] );
    $obj->build();
    subtest 'insert to update' => sub {
        my $table  = 'user';
        my $params = +{
            loginid     => 'sample@gmail.com',
            password    => 'sample',
            approved    => '1',
            deleted     => '0',
            created_ts  => '2022-03-17 17:25:58',
            modified_ts => '2022-03-17 17:25:58',
        };
        my $insert = $obj->insert( $table, $params );
        while ( my ( $key, $val ) = each %{$params} ) {
            is( $insert->{$key}, $params->{$key}, $key );
        }
        my $db_obj =
          $obj->single_to( $table, { loginid => $params->{loginid} } );
        my $update_ref;
        my $update_params = { password => 'sampleupdate', };
        if ( $db_obj->exist_params ) {
            $update_ref = $db_obj->update($update_params);
        }
        is( $update_ref->{password}, $update_params->{password}, 'password' );
        my @dummy_single = ( $table, { loginid => 'dummy' } );
        my $dummy_update = { password => 'sampledummy', };
        my $fail = $obj->single_to(@dummy_single)->update($dummy_update);
        is( $fail, undef, 'to_update' );
    };
    subtest 'search' => sub {
        $obj->build();
        my $table  = 'user';
        my $common = +{
            approved    => '1',
            deleted     => '0',
            created_ts  => '2022-03-17 17:25:58',
            modified_ts => '2022-03-17 17:25:58',
        };
        my $user_list = [
            { loginid => 'sample1@gmail.com', password => 'sample1', },
            { loginid => 'sample2@gmail.com', password => 'sample2', }
        ];
        for my $user ( @{$user_list} ) {
            my $insert = { %{$user}, %{$common}, };
            $obj->insert( $table, $insert );
        }
        my $arrey_ref =
          $obj->search( $table, { approved => '1', deleted => '0', } );
        is( @{$arrey_ref}, 2, 'search' );
        my $fail = $obj->search( $table, { approved => '1', deleted => '1', } );
        is( $fail, undef, 'search' );
    };
};

done_testing;

__END__

package Beauth::DB;
use parent 'SQLite::Simple';

sub db {
  my ($self, $args) = @_;
  my $simple = SQLite::Simple->new({
    db_file_path => 'db/sample.db',
    sql_file_path => 'sample.sql',
    %{$args},
  });
  return $simple;
}

# $self->db->build();
# $self->db->build_insert();
# $self->db->build_dump();
# $self->db->build_restore();

# my $hash_ref = $self->db->insert($table, \%params);
# my $hash_ref = $self->db->single($table, \%params);
# my $arrey_ref = $self->db->search($table, \%params);
# my $obj = $self->db->single_to($table, \%params);
# if ($obj->exist_params) {
#   $obj->update(\%set_params);
# }
# my $update_ref = $self->db->single_to($table, \%params)->update(\%set_params);
