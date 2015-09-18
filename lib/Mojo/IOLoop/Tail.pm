package Mojo::IOLoop::Tail;

use IO::File;

use Mojo::Base 'Mojo::EventEmitter';

use Mojo::IOLoop;

our $VERSION = '0.01';

=head1 NAME

Mojo::IOLoop::Tail - IOLoop interface to tail a file asynchronously

=head1 VERSION

0.01

=head1 DESCRIPTION

This is an IOLoop interface to tail a file asynchronously

=head1 SYNOPSIS

    use Mojo::Base -strict;

    use Mojo::IOLoop::Tail;

    my $tail = Mojo::IOLoop::Tail->new(file => "tail.me");

    $tail->on(oneline => sub {
        my $tail = shift;
        my $line = shift;

        print($line);
    });

    $tail->run;

    $tail->ioloop->start unless $tail->ioloop->is_running;

=cut

has 'ioloop' => sub { Mojo::IOLoop->singleton };
has 'file';
has 'leftovers';

sub run {
    my ($self, @args) = @_;

    my $fh = IO::File->new();
    unless ($fh->open($self->file, "r")) {
        $self->emit(error => sprintf("Can't open %s: $!", $self->file));
        return;
    }

    $fh->autoflush(1);
    $fh->sysseek(0, 2);

    my $reactor = $self->ioloop->reactor;
    $reactor->io($fh =>
        sub {
            my $reactor = shift;

            while (my $ret = sysread($fh, my $buf, 1024)) {
                if ($self->leftovers) {
                    $buf = $self->leftovers . $buf;

                    $self->{leftovers} = undef;
                }

                # eol patterns from IO::Async::Protocol::LineStream

                if ($buf !~ m/\x0d?\x0a/) {
                    $self->{leftovers} = $buf;
                    next;
                }

                while ($buf =~ m/\G(.*?)\x0d?\x0a/g) {
                    $self->emit(oneline => $1);
                }

                $self->{leftovers} = $1 if $buf =~ m/\G(.*)$/g
            }
        }
    )->watch($fh, 1, 0);

    return $self;
}

1;
