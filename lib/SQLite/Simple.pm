package SQLite::Simple;
use 5.10.1;
use strict;
use warnings;
use utf8;
use DBI;
use Data::Dumper;
use Time::Piece;
use Text::CSV;
use File::Path qw(make_path remove_tree);
use File::Basename;

our @ISA = qw();
our $VERSION = '0.01';

sub new {
    my $class = shift;
    my $args  = shift || {};
    return bless $args, $class;
}

sub db_file_path   { shift->{db_file_path}; }
sub sql_file_path  { shift->{sql_file_path}; }
sub dump_file_path { shift->{dump_file_path}; }

sub single_result {
    my $self = shift;
    if (@_) {
        $self->{single_result} = $_[0];
    }
    return $self->{single_result};
}

sub exist_params {
    my $self = shift;
    if (@_) {
        $self->{exist_params} = $_[0];
    }
    return $self->{exist_params};
}

sub time_stamp { localtime->datetime( 'T' => ' ' ); }

sub build_dbh {
    my ( $self, @args ) = @_;
    my $db   = $self->db_file_path;
    my $attr = +{
        RaiseError     => 1,
        AutoCommit     => 1,
        sqlite_unicode => 1,
    };
    my $dbh = DBI->connect( "dbi:SQLite:dbname=$db", "", "", $attr );
    return $dbh;
}

sub build {
    my ( $self, @args ) = @_;
    my $db      = $self->db_file_path;
    my $sql     = $self->sql_file_path;
    my $db_file = basename($db);
    die "not file: $!: $sql" if !-e $sql;
    my $dirname = dirname($db);
    if ( !-d $dirname ) {
        make_path($dirname);
    }

    # example: sqlite3 sample.db < sample.sql
    my $cmd = "sqlite3 $db < $sql";
    system $cmd and die "Couldn'n run: $cmd ($!)";
    return +{ message => qq{build success $db_file} };
}

sub build_insert {
    my ( $self, @args ) = @_;
    my $params = shift @args;
    my $path   = $params->{csv};
    my $fh     = IO::File->new( $path, "<:encoding(utf8)" );
    die "not file: $!" if !$fh;
    my $cols = $params->{cols};
    my $col  = join( ',', @{$cols} );
    my $q    = [];

    for my $int ( @{$cols} ) {
        push( @{$q}, '?' );
    }
    my $table  = $params->{table};
    my $values = join( ',', @{$q} );
    my $sql    = qq{INSERT INTO $table ($col) VALUES ($values)};
    my $dbh    = $self->build_dbh;
    my $csv    = Text::CSV->new();

    # time stamp の指定
    my ( $is_stamp, $stamp_int, $dt ) = $self->_time_stamp($params);

    # 上書きの値
    my ( $is_rewrite, $rewrite_params ) = $self->_rewrite($params);
    while ( my $row = $csv->getline($fh) ) {
        my $data = $row;
        if ($is_stamp) {
            for my $int ( @{$stamp_int} ) {
                $data->[$int] = $dt;
            }
        }
        if ($is_rewrite) {
            for my $rewrite_param ( @{$rewrite_params} ) {
                for my $key ( keys %{$rewrite_param} ) {
                    my $val = $rewrite_param->{$key};
                    $data->[$key] = $params->{rewrite}->{$val};
                }
            }
        }
        my $sth = $dbh->prepare($sql);
        $sth->execute( @{$data} ) or die $dbh->errstr;
    }
    $fh->close;
    return +{ message => qq{insert success $path} };
}

sub _time_stamp {
    my ( $self, @args ) = @_;
    my $params     = shift @args;
    my $is_stamp   = 0;
    my $cols       = $params->{cols};
    my $stamp_cols = $params->{time_stamp};
    return ( $is_stamp, undef, undef ) if !$stamp_cols;
    return ( $is_stamp, undef, undef ) if scalar( @{$stamp_cols} ) eq 0;

    my $stamp_int = [];
    my $int       = 0;
    for my $col ( @{$cols} ) {
        if ( grep { $_ eq $col } @{$stamp_cols} ) {
            push @{$stamp_int}, $int;
        }
        $int += 1;
    }
    my $dt = $self->time_stamp;
    $is_stamp = 1;
    return ( $is_stamp, $stamp_int, $dt );
}

sub _rewrite {
    my ( $self, @args ) = @_;
    my $params     = shift @args;
    my $is_rewrite = 0;
    my $cols       = $params->{cols};
    my $rewrite    = $params->{rewrite};
    return ( $is_rewrite, undef, undef ) if !$rewrite;
    return ( $is_rewrite, undef, undef ) if !%{$rewrite};
    my @keys           = keys %{$rewrite};
    my $rewrite_params = [];
    my $int            = 0;

    for my $col ( @{$cols} ) {
        if ( grep { $_ eq $col } @keys ) {
            push @{$rewrite_params}, { $int => $col };
        }
        $int += 1;
    }
    $is_rewrite = 1;
    return ( $is_rewrite, $rewrite_params );
}

sub build_dump {
    my ( $self, @args ) = @_;
    my $db        = $self->db_file_path;
    my $dump      = $self->dump_file_path;
    my $dump_file = basename($dump);
    die "not file: $!: $db" if !-e $db;

    # 例: sqlite3 sample.db .dump > sample.dump
    my $cmd = "sqlite3 $db .dump > $dump";
    system $cmd and die "Couldn'n run: $cmd ($!)";
    return +{ message => qq{dump success $dump_file} };
}

sub build_restore {
    my ( $self, @args ) = @_;
    my $db      = $self->db_file_path;
    my $dump    = $self->dump_file_path;
    my $db_file = basename($db);
    die "not file: $!: $dump" if !-e $dump;
    if ( -e $db ) {
        unlink $db;
    }

    # example: sqlite3 sample.db < sample.dump
    my $cmd = "sqlite3 $db < $dump";
    system $cmd and die "Couldn'n run: $cmd ($!)";
    return +{ message => qq{restore success $db_file} };
}

# $self->db->insert($table, \%params);
sub insert {
    my ( $self, @args )    = @_;
    my ( $table, $params ) = @args;
    my $cols = [];
    my $data = [];
    while ( my ( $key, $val ) = each %{$params} ) {
        push @{$cols}, $key;
        push @{$data}, $val;
    }
    my $col    = join ",", @{$cols};
    my $values = join ",", map { '?' } @{$cols};
    my $sql    = qq{INSERT INTO $table ($col) VALUES ($values)};
    my $dbh    = $self->build_dbh;
    my $sth    = $dbh->prepare($sql);
    $sth->execute( @{$data} ) or die $dbh->errstr;
    my $id     = $dbh->last_insert_id( undef, undef, undef, undef );
    my $create = $self->single( $table, { id => $id } );
    return $create;
}

# $self->db->single($table, \%params);
sub single {
    my ( $self,  @args )   = @_;
    my ( $table, $params ) = @args;
    my $sql_q = [];
    while ( my ( $key, $val ) = each %{$params} ) {
        if ( !defined $val ) {
            $val = '';
        }
        push @{$sql_q}, qq{$key = "$val"};
    }
    my $sql_clause = join " AND ", @{$sql_q};
    my $sql        = qq{SELECT * FROM $table WHERE $sql_clause};
    my $dbh        = $self->build_dbh;
    return $dbh->selectrow_hashref($sql);
}

# my $arrey_ref = $self->db->search($table, \%params, \%opt);
sub search {
    my ( $self, @args ) = @_;
    my ( $table, $params, $opt ) = @args;
    my $sql_q = [];
    my $cond  = $opt->{cond};
    while ( my ( $key, $val ) = each %{$params} ) {
        if ( $cond && $cond eq 'LIKE%' ) {
            push @{$sql_q}, qq{$key LIKE "$val%"};
        }
        else {
            push @{$sql_q}, qq{$key = "$val"};
        }
    }
    my $sql_clause = join " AND ", @{$sql_q};
    my $sql        = qq{SELECT * FROM $table WHERE $sql_clause};
    my $dbh        = $self->build_dbh;
    my $hash       = $dbh->selectall_hashref( $sql, 'id' );
    return if !%{$hash};
    my $arrey_ref = [];
    for my $key ( sort keys %{$hash} ) {
        push @{$arrey_ref}, $hash->{$key};
    }
    return $arrey_ref;
}

# my $obj = $self->db->single_to($table, \%params);
sub single_to {
    my ( $self,  @args )   = @_;
    my ( $table, $params ) = @args;
    my $hash = $self->single( $table, $params );
    $self->exist_params(0);
    if ($hash) {
        $self->exist_params(1);
    }
    $self->single_result( { table => $table, params => $hash } );
    return $self;
}

# my $update_ref = $self->db->single_to($table, \%params)->update(\%set_params);
sub update {
    my ( $self, @args ) = @_;
    my $params        = shift @args;
    my $single_result = $self->single_result;
    return if !$single_result;
    return if !$self->exist_params;
    my $update_id    = $single_result->{params}->{id};
    my $table        = $single_result->{table};
    my $set_clause   = $self->set_clause($params);
    my $where_clause = $self->where_clause( { id => $update_id } );
    my $sql          = qq{UPDATE $table SET $set_clause WHERE $where_clause};
    my $dbh          = $self->build_dbh;
    my $sth          = $dbh->prepare($sql);
    $sth->execute() or die $dbh->errstr;
    my $update = $self->single( $table, { id => $update_id } );
    return $update;
}

sub set_clause {
    my ( $self, @args ) = @_;
    my $params = shift @args;
    my $set_q  = [];
    while ( my ( $key, $val ) = each %{$params} ) {
        push @{$set_q}, qq{$key = "$val"};
    }
    my $set_clause = join ",", @{$set_q};
    return $set_clause;
}

sub where_clause {
    my ( $self, @args ) = @_;
    my $params  = shift @args;
    my $where_q = [];
    while ( my ( $key, $val ) = each %{$params} ) {
        push @{$where_q}, qq{$key = "$val"};
    }
    my $where_clause = join " AND ", @{$where_q};
    return $where_clause;
}
1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

SQLite::Simple - Perl extension for blah blah blah

=head1 SYNOPSIS

  use SQLite::Simple;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for SQLite::Simple, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.


=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

yk, E<lt>yk@localE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 by yk

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.34.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
