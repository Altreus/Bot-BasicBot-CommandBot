package Bot::BasicBot::CommandBot;

use strict;
use warnings;
use 5.014;

use Tie::RegexpHash 0.16;
use List::Util qw(any);

use Exporter 'import';
use base qw/Bot::BasicBot/;

our @EXPORT_OK = qw(command);

my %command;

sub command {
    (caller)[0]->declare_command(@_);
}

sub declare_command {
    my $package = shift;
    my $sub = pop;
    my $command = pop;

    my %options = @_;

    $options{events} //= ['said'];

    if (not exists $command{$package}) {
        $command{$package} = {};
        tie %{$command{$package}}, 'Tie::RegexpHash';
    }

    $command{$package}{$command} = {
        sub => $sub,
        %options,
    };
}


sub new {
    my $class = shift;
    my %opts = @_;

    my $address = delete $opts{address};
    my $trigger = delete $opts{trigger};

    my $self = $class->SUPER::new(%opts);
    $self->{trigger} = $trigger if defined $trigger;
    $self->{address} = $address if defined $address;

    return $self;
}

sub said {
    my $self = shift;
    my ($data) = @_;

    $self->{command} = $data;
    my $package = ref $self;

    if (my @auto = $self->_auto($data->{body})) {
        return join " ", @auto;
    }

    if ($self->{address} and not $data->{address}) {
        return;
    }

    if ($self->{trigger} and $data->{body} !~ s/^\Q$self->{trigger}//) {
        return;
    }

    my ($cmd, $message) = split ' ', $data->{body}, 2;
    my $found = $command{$package}{$cmd} or return "What is $cmd?";

    any { $_ eq 'said' } @{$found->{events}} or return;

    $found->{sub}->($self, $cmd, $message);
}

sub emoted {
}

sub noticed {
}

sub _auto { }

1;

__END__

=head1 NAME

Bot::BasicBot::CommandBot

=head1 DESCRIPTION

Simple declarative syntax for an IRC bot that responds to commands.

=head1 SYNOPSIS

    command hello => sub {
        my ($self, $cmd, $message) = @_;
        return "Hello world!"
    }

    command qr/^a+/ => sub {
        return 'a' x rand 6;
    }

    sub _auto {
        return "hi" if shift =~ /hello/;
    }

=head1 CONSTRUCTION

Construction of the bot is the same as Bot::BasicBot, as is running it.

CommandBot takes two new options to C<new>:

=over

=item C<trigger>

If provided, this string will be required at the start of any message for it to
be considered a bot command. Common examples include C<!>, C<?> and C<@>.

This string will be removed from the command.

=item C<address>

If provided and a true value, the bot will only respond if directly addressed.
"Addressed" is actually defined by Bot::BasicBot, so if the bot is not
addressed, nothing will happen.

=back

Despite the above, the C<_auto> method will always be called, regardless.

If both options are provided, the bot must be addressed I<and> the command must
be prefixed with the trigger for a response to happen.

=head1 COMMANDS

A command is considered to be the first contiguous string of non-whitespace
after the preprocessing done by the address and trigger detection.

    !command text text
    Commandbot: command text text
    Commandbot: !command text text

In all these cases, C<command> is the B<command>. C<text text> is then a single string, regardless of how long it is.
This is the B<message>.

The command string is then looked up in the list of declared commands. If it is
exactly equal to a command declared as a string, or matches a command declared
with a regex, the associated subref is run.

If it does not match, the bot says "What is $command?".

=head1 DECLARING COMMANDS

=head2 command

The C<command> function declares a command. It accepts either a string or a
regex and a subref. The subref will be called whenever the bot is activated
with a matching string.

The subref receives C<$self>, C<$cmd> and C<$message>: The bot object, the
matched command and the rest of the message.

    command qr/^./ => sub {
        ...
    };

The return value from this subref is then spoken in the same place the
original message was received.

C<$self> is an instance of Bot::BasicBot::CommandBot, which of course extends
Bot::BasicBot, and therefore all things that can do, your bot can do.

=head2 declare_command

This function is called by C<command>. It is a package method. It takes the
same arguments as C<command>, but it is called on a package:

    __PACKAGE__->declare_command(qr/^./, sub { ... });

This can be helpful if you don't want to put all your commands in the same
module - you can declare them all on the same package.

=head2 _auto

C<_auto> is a plain method on your bot. It is called before anything else is
done, and if it returns anything, that is said and nothing else is done.

As mentioned this is a normal method, so it receives C<$self> first, and then
C<$message>.  There is no C<$cmd> because no command was involved.

This sub is intended as a hook for you to perform any actions necessary as a
result of people talking in general, or for bots that think they're human and
want to join in.

It is called in list context, so remember not to return undef.
