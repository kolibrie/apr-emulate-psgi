package APR::Emulate::PSGI;

=head1 NAME

APR::Emulate::PSGI - Class that Emulates the mod_perl2 APR Object (Apache2::RequestRec, et al)

=head1 SYNOPSIS

  use APR::Emulate::PSGI;
  my $r = APR::Emulate::PSGI->new($psgi_env);

  # Or in a CGI environment:
  my $r = APR::Emulate::PSGI->new();

=head1 DESCRIPTION

This class emulates the mod_perl2 APR object.  It expects either a
PSGI environment hashref to be passed in, or to read HTTP environment
information from the global %ENV.

Currently this module is little more than a proof of concept.  There
are rough edges.

Use at your own discretion.  Contributions welcome.

=cut

use 5.010000;
use strict;
use warnings;

use URI;
use HTTP::Headers;

# APR::MyPool defined below this package.
# APR::MyTable defined below this package.

our $VERSION = '0.01';

# TODO Replace //= with something 5.6.0 appropriate.

sub new {
    my ( $class, $env ) = @_;
    my $self = bless {
        'psgi_env' => $env,
        'cgi_mode' => ( defined($env) ? 0 : 1 ),
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
    if ($self->{'cgi_mode'}) {
        return $ENV{'PATH_INFO'};
    }
    return $self->{'psgi_env'}{'PATH_INFO'};
}

sub parsed_uri {
    my ($self) = @_;
    if ($self->{'cgi_mode'}) {
        return $self->{'uri'} //= URI->new($ENV{'REQUEST_URI'});
    }
    return $self->{'uri'} //= URI->new($self->{'psgi_env'}{'REQUEST_URI'});
}

sub args {
    my ($self) = @_;
    if ($self->{'cgi_mode'}) {
        return $ENV{'QUERY_STRING'};
    }
    return $self->{'psgi_env'}{'QUERY_STRING'};
}

sub headers_in {
    my ($self) = @_;
    return $self->{'headers_in'} if (defined($self->{'headers_in'}));

    my $environment = $self->{'cgi_mode'}
        ? \%ENV
        : $self->{'psgi_env'};

    my %headers = (
        map { $_ => $environment->{$_} }
        grep { $_ =~ /^HTTPS?_/ }
        keys %{ $environment }
    );

    foreach my $field ('CONTENT_TYPE', 'CONTENT_LENGTH') {
        $headers{$field} = $environment->{$field} if (defined($environment->{$field}));
    }

    return $self->{'headers_in'} = HTTP::Headers->new(%headers);
}

sub method {
    my ($self) = @_;
    if ($self->{'cgi_mode'}) {
        return $ENV{'REQUEST_METHOD'};
    }
    return $self->{'psgi_env'}{'REQUEST_METHOD'};
}

sub read {
    my ($self, $buffer, $length, $offset) = @_;
    $offset ||= 0;
    # We use $_[1] instead of $buffer, because we need to modify the original instead of a copy.
    if ($self->{'cgi_mode'}) {
        return CORE::read(\*STDIN, $_[1], $length, $offset);
    }
    return $self->{'psgi_env'}{'psgi.input'}->read($_[1], $length, $offset);
}

sub print {
    my ($self, @content) = @_;
    my $success = CORE::print @content;
    return $success
        ? length(join('', @content))
        : 0;
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
    if (scalar(@value)) {
        $self->{'content_type'} = $value[0];

        if ($self->{'cgi_mode'}) {
            $self->_send_http_headers();
        }
    }
    return $self->{'content_type'};
}

sub _send_http_headers {
    my ($self) = @_;
    return if ($self->{'headers_sent'});
    if (my $status = $self->status_line() || $self->status() || '200 OK') {
        my $url_scheme = uc($self->{'psgi_env'}{'psgi.url_scheme'} || 'http');
        print $url_scheme . '/1.1 ' . $status . "\n";
    }
    print 'Content-type: ' . ($self->{'content_type'} || 'text/html') . "\n";
    $self->headers_out()->do(
        sub {
            my ($key, $value) = @_;
            print join(': ', $key, $value) . "\n";
        }
    );
    print "\n\n";
    $self->{'headers_sent'} = 1;
    return 1;
}

sub rflush {}

# See APR::Table in mod_perl 2 distribution.
package APR::MyTable;

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
    my ($self, $code, @args) = @_;
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

Copyright (C) 2013, 2014 by Nathan Gray

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
