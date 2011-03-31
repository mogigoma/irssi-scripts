################################################################################
# Imports
################################################################################

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;

################################################################################
# Signal Handling
################################################################################

$VERSION = '1.00';
%IRSSI = (
	authors		=> 'Mak Kolybabi',
	contact		=> 'mak@kolybabi.com',
	name		=> 'Shut The Fuck Up',
	description	=> 'This plugin prevents you from accidentally ' .
			   'talking in certain channels.',
	license		=> 'BSD 2-Clause'
);

################################################################################
# Global Variables
################################################################################

# When trying to post to a channel that is in ask mode, all posts are buffered
# here.
my %buf = ();

################################################################################
# Utility Functions
################################################################################

sub settings_init_str {
	my ($key, $value) = @_;

	# Don't initilize a key that already exists.
	return if Irssi::settings_get_str($key);

}

sub action_allow {
	my ($line, $srv, $win) = @_;

	# Do nothing.
}

sub action_ask {
	my ($line, $srv, $win) = @_;

	# Save what the user was trying to do in the buffer.
	push(@{$buf{$win->{name}}}, $line);

	# Notify the user that they have been buffered.
	$win->print('STFU: Your configuration prevents freely talking in ' .
	  'channel ' . $win->{name} . '. The following has been buffered:');
	$win->print($line);

	# Prevent the signal from propagating.
	Irssi::signal_stop();
}

sub action_deny {
	my ($line, $srv, $win) = @_;

	$win->print('STFU: Your configuration does not allow talking in ' .
	  'channel ' . $win->{name} . '.');

	# Prevent the signal from propagating.
	Irssi::signal_stop();
}

################################################################################
# Commands
################################################################################

sub cmd_stfu {
	my ($line, $srv, $chan) = @_;

	#return if undef $chan;
	#return if $chan->{type} ne 'CHANNEL';

	if ($line eq 'display') {
		Irssi::active_win->print("STFU: This channel's buffer:");
		foreach (@{$buf{$chan->{name}}}) {
			Irssi::active_win->print($_);
		}
	}

	elsif ($line eq 'flush') {
		foreach (@{$buf{$chan->{name}}}) {
			$srv->command("MSG $chan->{name} $_");
		}
	}

	elsif ($line eq 'purge') {
		# Empty the buffer for this channel.
		$buf{$chan->{name}} = [];

		Irssi::active_win->print("STFU: Purged this channel's buffer.");
	}

	else {
		Irssi::active_win->print("STFU: $line not understood.");
	}
}

################################################################################
# Signal Handlers
################################################################################

sub hook_sync {
	my ($chan) = @_;

	# Retrieve current default mode, which may have been changed by the
	# user.
	my $mode = Irssi::settings_get_str('default_mode');

	# Set mode of channel to default, unless it's already been set by the
	# user.
	Irssi::settings_add_str('stfu', $chan->{name}, $mode);

	# Create the buffer for this channel.
	$buf{$chan->{name}} = [];
}

sub hook_talk {
	my ($line, $srv, $win) = @_;

	# Don't execute hook in query windows.
	return if $win->{type} ne 'CHANNEL';

	# Don't execute hook unless the user is trying to talk.
	return if $line !~ m!^([^/]|/(me|say))!;

	# Dispatch to appropriate handler for this channel's mode.
	my $mode = Irssi::settings_get_str($win->{name}) || 'allow';
	my %actions = (
		allow	=> \&action_allow,
		ask	=> \&action_ask,
		deny	=> \&action_deny
	);
	$actions{$mode}(@_);
};

################################################################################
# Script Initialization
################################################################################

# Permit talking in all channels by default.
Irssi::settings_add_str('stfu', 'default_mode', 'allow');

# Apply default mode to each channel that doesn't already have its mode set.
foreach (Irssi::channels) {
	hook_sync($_);
}

# Create the commands.
Irssi::command_bind('stfu' => \&cmd_stfu);

# Hook all signals that result in the user talking in a channel.
Irssi::signal_add_first('send text', 'hook_talk');
Irssi::signal_add_first('send command', 'hook_talk');

# Hook all signals that are raised on channel sync.
Irssi::signal_add_first('channel sync', 'hook_sync');
