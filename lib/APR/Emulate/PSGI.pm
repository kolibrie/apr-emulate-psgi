package APR::Emulate::PSGI;

=head1 NAME

APR::Emulate::PSGI - Class that Emulates the mod_perl2 APR Object

=head1 SYNOPSIS

  use APR::Emulate::PSGI;
  my $r = APR::Emulate::PSGI->new($psgi_env);

=head1 DESCRIPTION

This class emulates the mod_perl2 APR object, given a PSGI environment.

Currently this module is a proof of concept.  There are rough edges.
I would recommend not using it until it at least has a test suite.
Contributions welcome.

=cut

use 5.010000;
use strict;
use warnings;

use URI;
use HTTP::Headers;
# APR::MyTable defined below this package.

our $VERSION = '0.01';

# TODO Replace //= with something 5.6.0 appropriate.

sub new {
    my ( $class, $env ) = @_;
    my $self = bless {
        'psgi_env' => $env,
    }, $class;
    return $self;
}

sub no_cache {
    return 1;
}

sub headers_out {
    my ($self) = @_;
    return $self->{'headers_out'} //= APR::MyTable::make();
}

sub err_headers_out {
    my ($self) = @_;
    return $self->{'err_headers_out'} //= APR::MyTable::make();
}

sub pool {
    my ($self) = @_;
    return $self->{'pool'} //= APR::MyPool->new();
}

sub uri {
    my ($self) = @_;
    return $self->{'psgi_env'}{'PATH_INFO'};
}

sub parsed_uri {
    my ($self) = @_;
    return $self->{'uri'} //= URI->new($self->{'psgi_env'}{'REQUEST_URI'});
}

sub args {
    my ($self) = @_;
    return $self->{'psgi_env'}{'QUERY_STRING'};
}

sub headers_in {
    my ($self) = @_;
    return $self->{'headers_in'} //= HTTP::Headers->new($ENV{'headers'});
}

sub status {
    my ($self, @value) = @_;
    $self->{'status'} = $value[0] if scalar(@value);
    return $self->{'status'};
}

sub status_line {
    my ($self, @value) = @_;
    $self->{'status_line'} = $value[0] if scalar(@value);
    return $self->{'status_line'};
}

sub content_type {
    my ($self, @value) = @_;
    $self->{'content_type'} = $value[0] if scalar(@value);
    $self->rflush();
    return $self->{'content_type'};
}

sub rflush {
    my ($self) = @_;
    if (defined($self->status())) {
        print 'HTTP/1.1 ' . $self->status() . ' ' . $self->status_line() . "\n";
    }
    print 'Content-type: ' . ($self->{'content_type'} || 'text/html') . "\n";
    $self->headers_out()->do(
        sub {
            my ($key, $value) = @_;
            print join(': ', $key, $value) . "\n";
        }
    );
    print "\n\n";
    return 1;
}

# See APR::Table in mod_perl 2 distribution.
package APR::Table;

sub make {
    return bless {}, __PACKAGE__;
}

sub copy {
    my ($self) = @_;
    my %copy = %$self;
    return bless \%copy, ref($self);
}

sub clear {
    my ($self) = @_;
    my (@keys) = keys %$self;
    foreach my $key (@keys) {
        delete $self->{$key};
    }
    return 1;
}

sub set {
    my ($self, @pairs) = @_;
    while (@pairs) {
        my ($key, $value) = splice(@pairs, 0, 2);
        $self->{$key} = $value;
    }
    return 1;
}

sub unset {
    my ($self, @keys) = @_;
    foreach my $key (@keys) {
        delete $self->{$key};
    }
    return 1;
}

sub add {
    # TODO: When implemented properly, this should allow duplicate keys.
    my ($self, $key, $value) = @_;
    $self->{$key} = $value;
    return 1;
}

sub get {
    # TODO: When implemented properly, this should allow duplicate keys.
    my ($self, $key) = @_;
    return $self->{$key};
}

sub merge {
    # TODO: Not yet implemented.
    return undef;
}

sub do {
    my ($self, $code, @keys) = @_;
    @keys = keys %$self if (scalar(@keys) == 0);
    foreach my $key (@keys) {
        $code->($key, $self->{$key});
    }
    return 1;
}

package APR::MyPool;

sub new {
    bless {}, $_[0];
}

sub cleanup_register {
    my ($self, $code, $args) = @_;
    foreach my $arg (@args) {
        $code->($arg);
    }
    return 1;
}

1;
__END__

=head1 SEE ALSO

=over 4

=item Plack

=item CGI::Emulate::PSGI

=back

=head1 AUTHOR

Nathan Gray, E<lt>kolibrie@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Nathan Gray

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
