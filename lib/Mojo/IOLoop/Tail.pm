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
has 'line';

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

            my $line = $self->line;

            while (my $ret = sysread($fh, my $buf, 1)) {
                $line .= $buf;

                if ("\n" eq $buf) {
                    warn("here");
                    $self->emit(oneline => $line);
                    $line = undef;
                }
            }
        }
    )->watch($fh, 1, 0);

    return $self;
}

1;
