package Slim::Buttons::Common;

# $Id: Common.pm,v 1.21 2003/11/25 07:10:40 grotus Exp $

# SlimServer Copyright (c) 2001, 2002, 2003 Sean Adams, Slim Devices Inc.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;
use File::Spec::Functions qw(:ALL);
use File::Spec::Functions qw(updir);
use Slim::Buttons::Power;
use Slim::Player::Client;
use Slim::Utils::Strings qw (string);
use Slim::Utils::Misc;
use Slim::Buttons::Plugins;
use Slim::Buttons::Input::Text;
use Slim::Buttons::Input::List;
use Slim::Display::Display;

# hash of references to functions to call when we leave a mode
my %leaveMode = ();

#references to mode specific function hashes
my %modeFunctions = ();

my $SCAN_RATE_MULTIPLIER = 2;

# hash of references to functions to call when we enter a mode
# Note:  don't add to this list, rather use the addMode() function 
#below to have the module add its mode itself
# TODO: get rid of this initialization and do what it says in the line above.
my %modes = (		
	'bass' =>					\&Slim::Buttons::Settings::setBassMode,
	'block' => 					\&Slim::Buttons::Block::setMode,
	'browse' => 				\&Slim::Buttons::Browse::setMode,
	'browseid3' => 				\&Slim::Buttons::BrowseID3::setMode,
	'browsemenu' => 			\&Slim::Buttons::BrowseMenu::setMode,
	'home' => 					\&Slim::Buttons::Home::setMode,
	'INPUT.Text' =>				\&Slim::Buttons::Input::Text::setMode,
	'INPUT.List' =>				\&Slim::Buttons::Input::List::setMode,
	'moodlogic_instant_mix' =>	\&Slim::Buttons::InstantMix::setMode,
	'moodlogic_mood_wheel' =>	\&Slim::Buttons::MoodWheel::setMode,
	'off' => 					\&Slim::Buttons::Power::setMode,
	#'offdisplaysize' =>			\&Slim::Buttons::Settings::setOffDisplaySettingsMode,
	'playlist' => 				\&Slim::Buttons::Playlist::setMode,
	'plugins' => 				\&Slim::Buttons::Plugins::setMode,
	#'repeat' =>					\&Slim::Buttons::Settings::setRepeatMode,
	'screensaver' =>			\&Slim::Buttons::ScreenSaver::setMode,
	'search' => 				\&Slim::Buttons::Search::setMode,
	'searchfor' =>  			\&Slim::Buttons::SearchFor::setMode,
	'settings' =>				\&Slim::Buttons::Settings::setMode,
	'shooter' =>  				\&Slim::Buttons::Shooter::setMode,
	#'shuffle' =>				\&Slim::Buttons::Settings::setShuffleMode,
	'slimtris' =>  				\&Slim::Buttons::SlimTris::setMode,
	'synchronize' =>			\&Slim::Buttons::Synchronize::setMode,
	#'textsize' =>				\&Slim::Buttons::Settings::setTextSizeMode,
	'titleformat' =>			\&Slim::Buttons::Settings::setTitleFormatMode,
	'trackinfo' => 				\&Slim::Buttons::TrackInfo::setMode,
	'treble' =>					\&Slim::Buttons::Settings::setTrebleMode,
	'volume' =>					\&Slim::Buttons::Settings::setVolumeMode,
);

#
# The address of the function hash is set at run time rather than compile time
# so initialize the modeFunctions hash here
sub init {
	$modeFunctions{'home'} = Slim::Buttons::Home::getFunctions();
	$modeFunctions{'block'} = Slim::Buttons::Block::getFunctions();
	$modeFunctions{'browse'} = Slim::Buttons::Browse::getFunctions();
	$modeFunctions{'browsemenu'} = Slim::Buttons::BrowseMenu::getFunctions();
	$modeFunctions{'browseid3'} = Slim::Buttons::BrowseID3::getFunctions();
	$modeFunctions{'playlist'} = Slim::Buttons::Playlist::getFunctions();
	$modeFunctions{'plugins'} = Slim::Buttons::Plugins::getFunctions();
	$modeFunctions{'off'} = Slim::Buttons::Power::getFunctions();
	$modeFunctions{'screensaver'} = Slim::Buttons::ScreenSaver::getFunctions();
	$modeFunctions{'search'} = Slim::Buttons::Search::getFunctions();
	$modeFunctions{'searchfor'} = Slim::Buttons::SearchFor::getFunctions();
	$modeFunctions{'settings'} = Slim::Buttons::Settings::getFunctions();
	$modeFunctions{'synchronize'} = Slim::Buttons::Synchronize::getFunctions();
	$modeFunctions{'trackinfo'} = Slim::Buttons::TrackInfo::getFunctions();
	#$modeFunctions{'repeat'} = Slim::Buttons::Settings::getRepeatFunctions();
	#$modeFunctions{'shuffle'} = Slim::Buttons::Settings::getShuffleFunctions();
	#$modeFunctions{'textsize'} = Slim::Buttons::Settings::getTextSizeFunctions();
	#$modeFunctions{'offdisplaysize'} = Slim::Buttons::Settings::getOffDisplaySettingsFunctions();
	$modeFunctions{'titleformat'} = Slim::Buttons::Settings::getTitleFormatFunctions();
	$modeFunctions{'bass'} = Slim::Buttons::Settings::getBassFunctions();
	$modeFunctions{'treble'} = Slim::Buttons::Settings::getTrebleFunctions();
	$modeFunctions{'volume'} = Slim::Buttons::Settings::getVolumeFunctions();
	$modeFunctions{'moodlogic_mood_wheel'} = Slim::Buttons::MoodWheel::getFunctions();
	$modeFunctions{'moodlogic_instant_mix'} = Slim::Buttons::InstantMix::getFunctions();
	$modeFunctions{'INPUT.Text'} = Slim::Buttons::Input::Text::getFunctions();
	$modeFunctions{'INPUT.List'} = Slim::Buttons::Input::List::getFunctions();
	Slim::Buttons::Plugins::getPluginModes(\%modes);
	Slim::Buttons::Plugins::getPluginFunctions(\%modeFunctions);
}

 sub addMode {
 	my $name = shift;
 	my $buttonFunctions = shift;
 	my $setModeFunction = shift;
 	my $leaveModeFunction = shift;
 	$modeFunctions{$name} = $buttonFunctions;
 	$modes{$name} = $setModeFunction;
 	$leaveMode{$name} = $leaveModeFunction;
 }
 	
# Common functions for more than one mode:
my %functions = (
	'dead' => sub  {},
	'fwd' => sub  {
		my $client = shift;
		# ignore if we aren't playing anything or if we're scanning
		my $playlistlen = Slim::Player::Playlist::count($client);
		my $rate = Slim::Player::Source::rate($client);
		
		if ($playlistlen == 0 || ($rate != 0 && $rate != 1)) {
			return;
		}
		Slim::Control::Command::execute($client, ["playlist", "jump", "+1"]);
		Slim::Display::Animation::showBriefly($client, (Slim::Buttons::Playlist::currentSongLines($client))[0..1]);
	},
	'rew' => sub  {
		my $client = shift;
		# ignore if we aren't playing anything or if we're scanning
		my $playlistlen = Slim::Player::Playlist::count($client);
		my $rate = Slim::Player::Source::rate($client);
		
		if ($playlistlen == 0 || ($rate != 0 && $rate != 1)) {
			return;
		}
		
		if (Time::HiRes::time() - Slim::Hardware::IR::lastIRTime($client) < 1.0) {  #  less than second, jump back to the previous song
			Slim::Control::Command::execute($client, ["playlist", "jump", "-1"]);
		} else {
			# otherwise, restart this song.
			Slim::Control::Command::execute($client, ["playlist", "jump", "+0"]);
		}
		#either starts the same song over, or the previous one, depending on whether we jumped back.
		Slim::Control::Command::execute($client, ["play"]);
		Slim::Display::Animation::showBriefly($client, (Slim::Buttons::Playlist::currentSongLines($client))[0..1]);
	},
	
	'jump' => sub  {
		my $client = shift;
		my $funct = shift;
		my $functarg = shift;
		# ignore if we aren't playing anything or if we're scanning
		my $playlistlen = Slim::Player::Playlist::count($client);
		my $rate = Slim::Player::Source::rate($client);
		
		if (!defined $functarg) { $functarg = ''; }

		if ($playlistlen == 0) {
			return;
		}
		# ignore if we're scanning that way already			
		if ($rate > 1 && $functarg eq 'fwd') {
			return;
		}
		if ($rate < 0 && $functarg eq 'rew') {
			return;
		}
		# if we aren't scanning that way, then use it to stop scanning  and just play.
		if ($rate != 0 && $rate != 1) {
			Slim::Control::Command::execute($client, ["play"]);
			return;	
		}
		

		if ($functarg eq 'rew') { 
			my $now = Time::HiRes::time();
			if (Slim::Player::Source::songTime($client) < 5 || Slim::Player::Source::playmode($client) eq "stop") {
				#jump back a song if stopped, invalid songtime, or current song has been playing less
				#than 5 seconds (use modetime instead of now when paused)
				Slim::Control::Command::execute($client, ["playlist", "jump", "-1"]);
			} else { #restart current song
				Slim::Control::Command::execute($client, ["playlist", "jump", "+0"]);
			}
			
		} elsif ($functarg eq 'fwd') { # jump to next song
			Slim::Control::Command::execute($client, ["playlist", "jump", "+1"]);
		} else { #restart current song
			Slim::Control::Command::execute($client, ["playlist", "jump", "+0"]);
		}

		#either starts the same song over, or the previous one, or the next one depending on whether/how we jumped
		Slim::Control::Command::execute($client, ["play"]);
		Slim::Display::Animation::showBriefly($client, (Slim::Buttons::Playlist::currentSongLines($client))[0..1]);
	},
	'jumpinsong' => sub {
		my ($client,$funct,$functarg) = @_;
		my $dir;
		my $timeinc = 1;
		if (!defined $functarg) {
			return;
		} elsif ($functarg =~ /(.+?)_(\d+)_(\d+)/) {
			$dir = ($1 eq 'fwd' ? '+' : '-') . "$2";
		} elsif ($functarg eq 'fwd') {
			$dir = "+$timeinc";
		} elsif ($functarg eq 'rew') {
			$dir = "-$timeinc";
		} else {
			return;
		}
		Slim::Control::Command::execute($client, ['gototime', $dir]);
	},
	'scan' => sub {
		my ($client,$funct,$functarg) = @_;
		my $rate = Slim::Player::Source::rate($client);
		if (!defined $functarg) {
			return;
		} elsif ($functarg eq 'fwd') {
			Slim::Buttons::Common::pushMode($client, 'playlist');
			if ($rate < 0) { $rate = 1; }
			Slim::Control::Command::execute($client, ['rate', $rate * $SCAN_RATE_MULTIPLIER]);
		} elsif ($functarg eq 'rew') {
			Slim::Buttons::Common::pushMode($client, 'playlist');
			if ($rate > 0) { $rate = 1; }
			Slim::Control::Command::execute($client, ['rate', -abs($rate * $SCAN_RATE_MULTIPLIER)]);
		}
		$client->update();

	},
	'pause' => sub  {
		my $client = shift;
		# ignore if we aren't playing anything
		my $playlistlen = Slim::Player::Playlist::count($client);
		if ($playlistlen == 0) {
			return;
		}
		Slim::Control::Command::execute($client, ["pause"]);
		if (Slim::Player::Source::playmode($client) eq 'play' && Slim::Player::Source::rate($client) != 1) {
			Slim::Player::Source::rate($client,1);
		}
		Slim::Display::Animation::showBriefly($client, (Slim::Buttons::Playlist::currentSongLines($client))[0..1]);
	},
	'stop' => sub  {
		my $client = shift;
		if (Slim::Player::Playlist::count($client) == 0) {
			Slim::Display::Animation::showBriefly($client, string('PLAYLIST_EMPTY'), "");
		} else {
			Slim::Control::Command::execute($client, ["stop"]);
			Slim::Buttons::Common::pushMode($client, 'playlist');
			Slim::Display::Animation::showBriefly($client, string('STOPPING'), "");
		}
	},
	'menu_pop' => sub  {
		my $client = shift;
		Slim::Buttons::Common::popMode($client);
		$client->update();
	},
	'menu' => sub  {
		my $client = shift;
		my $button = shift;
		my $buttonarg = shift;
		my $jump = undef;
		my @oldlines = Slim::Display::Display::curLines($client);
		Slim::Buttons::Common::setMode($client, 'home');
		if ($button eq 'menu_playlist') {
			Slim::Buttons::Common::pushMode($client, 'playlist');
			$jump = 'NOW_PLAYING';
		} elsif ($button eq 'menu_browse_genre') {
			Slim::Buttons::Common::pushMode($client, 'browseid3',{});
			$jump = 'BROWSE_BY_GENRE';
		} elsif ($button eq 'menu_browse_artist') {
			Slim::Buttons::Common::pushMode($client, 'browseid3',{'genre'=>'*'});
			$jump = 'BROWSE_BY_ARTIST';
		} elsif ($button eq 'menu_browse_album') {
			Slim::Buttons::Common::pushMode($client, 'browseid3', {'genre'=>'*', 'artist'=>'*'});
		} elsif ($button eq 'menu_browse_song') {
			Slim::Buttons::Common::pushMode($client, 'browseid3', {'genre'=>'*', 'artist'=>'*', 'album'=>'*'});
			$jump = 'BROWSE_BY_SONG';
			$jump = 'BROWSE_BY_ALBUM';
		} elsif ($button eq 'menu_browse_music') {
			Slim::Buttons::Common::pushMode($client, 'browse');
			Slim::Buttons::Browse::loadDir($client, '', undef, \@oldlines);
			$jump = 'BROWSE_MUSIC_FOLDER';
		} elsif ($button eq 'menu_synchronize') {
			Slim::Buttons::Common::pushMode($client, 'settings');
			$jump = 'SETTINGS';
			Slim::Buttons::Common::pushModeLeft($client, 'synchronize');
		} elsif ($button eq 'menu_search_artist') {
			Slim::Buttons::SearchFor::searchFor($client, 'ARTISTS');
			Slim::Buttons::Common::pushMode($client, 'searchfor');
			$jump = 'SEARCH_FOR_ARTISTS';
		} elsif ($button eq 'menu_search_album') {
			Slim::Buttons::SearchFor::searchFor($client, 'ALBUMS');
			Slim::Buttons::Common::pushMode($client, 'searchfor');
			$jump = 'SEARCH_FOR_ALBUMS';
		} elsif ($button eq 'menu_search_song') {
			Slim::Buttons::SearchFor::searchFor($client, 'SONGS');
			Slim::Buttons::Common::pushMode($client, 'searchfor');
			$jump = 'SEARCH_FOR_SONGS';
		} elsif ($button eq 'menu_browse_playlists' && Slim::Utils::Prefs::get('playlistdir')) {
			Slim::Buttons::Common::pushMode($client, 'browse');
			Slim::Buttons::Browse::loadDir($client, '__playlists', undef, \@oldlines);
			$jump = 'SAVED_PLAYLISTS';
		} elsif ($buttonarg =~ /^plugin/i) {
			if (exists($modes{$buttonarg})) {
				Slim::Buttons::Common::pushMode($client, $buttonarg);
			} else {
				Slim::Buttons::Common::pushMode($client, 'plugins');
			}
			$jump = 'PLUGINS';
		} elsif ($button eq 'menu_settings') {
			Slim::Buttons::Common::pushMode($client, 'settings');
			$jump = 'SETTINGS';
		}
		Slim::Buttons::Home::jump($client,$jump);
		$client->update();
	},
	'brightness' => sub  {
		my $client = shift;
		my $button = shift;
		my $buttonarg = shift;
		unless (defined $buttonarg) { return; }
		my $brightmode = 'power' . ((mode($client) eq 'off') ? 'Off' : 'On') . 'Brightness';
		my $newBrightness;
		if ($buttonarg eq 'toggle') {
			$newBrightness = Slim::Hardware::VFD::vfdBrightness($client) - 1;
			if ($newBrightness < 0) {
				$newBrightness = $Slim::Hardware::VFD::MAXBRIGHTNESS;
			}
		} else {
			$newBrightness = ($buttonarg eq 'down') ? Slim::Hardware::VFD::vfdBrightness($client) - 1 : Slim::Hardware::VFD::vfdBrightness($client) + 1;
			if ($newBrightness > $Slim::Hardware::VFD::MAXBRIGHTNESS) { $newBrightness = $Slim::Hardware::VFD::MAXBRIGHTNESS;}
			if ($newBrightness < 0) { $newBrightness = 0;}
		}
		Slim::Utils::Prefs::clientSet($client, $brightmode,$newBrightness);
	},
	'playdisp' => sub  {
		my $client = shift;
		my $button = shift;
		my $buttonarg = shift;
		my $playdisp = undef;
		if (mode($client) eq 'playlist') {
			Slim::Buttons::Playlist::playdisp($client,$button, $buttonarg);
			return;
		}
		unless (defined $buttonarg) { $buttonarg = 'toggle'; };
		if ($buttonarg eq 'toggle') {
			$::d_files && msg("Switching to playlist view\n");
			if (Slim::Player::Playlist::count($client) == 0) {
				Slim::Display::Animation::showBriefly($client, string('PLAYLIST_EMPTY'), "");
			} else {
				Slim::Buttons::Common::pushMode($client, 'playlist');
				Slim::Display::Animation::showBriefly($client, string('VIEWING_PLAYLIST'), "");
			}
		} else {
			if ($buttonarg =~ /^[0-5]$/) {
				Slim::Utils::Prefs::clientSet($client, "playingDisplayMode", $buttonarg);
			}
		}
	},
	'search' => sub  {
		my $client = shift;
		my $button = shift;
		my $buttonarg = shift;
		my $playdisp = undef;
		if (mode($client) ne 'search') {
			Slim::Buttons::Common::pushMode($client, 'search');
			$client->update();
		}
	},	
	'repeat' => sub  {
		# pressing recall toggles the repeat.
		my $client = shift;
		my $button = shift;
		my $buttonarg = shift;
		my $repeat = undef;
		if (defined $buttonarg && $buttonarg =~ /^[0-2]$/) {
			$repeat = $buttonarg;
		}
		Slim::Control::Command::execute($client, ["playlist", "repeat",$repeat]);
		# display the fact that we are (not) repeating
		if (Slim::Player::Playlist::repeat($client) == 0) {
			Slim::Display::Animation::showBriefly($client, string('REPEAT_OFF'), "");
		} elsif (Slim::Player::Playlist::repeat($client) == 1) {
			Slim::Display::Animation::showBriefly($client, string('REPEAT_ONE'), "");
		} elsif (Slim::Player::Playlist::repeat($client) == 2) {
			Slim::Display::Animation::showBriefly($client, string('REPEAT_ALL'), "");
		}
	},
	'volume' => sub {
		my $client = shift;
		my $button = shift;
		my $buttonarg = shift;
		my $inc = 1;
		my $volcmd;
		my $rate = 50; #Hz maximum
		my $accel = 15; #Hz/s
		
		if (Slim::Hardware::IR::holdTime($client) > 0) {
			$inc *= Slim::Hardware::IR::repeatCount($client,$rate,$accel);
		} else {
			$inc = 2.5;
		}
		if ($buttonarg  eq 'up') {
			$volcmd = "+$inc";
		} elsif ($buttonarg eq 'down') {
			$volcmd = "-$inc";
		} elsif ($buttonarg =~ /(\d+)/) {
			$volcmd = $1;
		} else {
			Slim::Display::Display::volumeDisplay($client);
			return;
		}
		if (!$inc && $buttonarg =~ /up|down/) {
			return;
		}
		Slim::Control::Command::execute($client, ["mixer", "volume", $volcmd]);
		Slim::Display::Display::volumeDisplay($client);
	},
	'muting' => sub  {
		my $client = shift;
		Slim::Control::Command::execute($client, ["mixer", "muting"]);
	},
	'sleep' => sub  {
		my $client = shift;
		my @sleepChoices = (0,15,30,45,60,90);
		my $i;
		# find the next value for the sleep timer
		for ($i = 0; $i <= $#sleepChoices; $i++) {
			if ( $sleepChoices[$i] > $client->currentSleepTime() ) {
				last;
			}
		}
		if ($i > $#sleepChoices) {
			$i = 0;
		}
		my $sleepTime = $sleepChoices[$i];
		if ($sleepTime == 0) {
			Slim::Display::Animation::showBriefly($client, string('CANCEL_SLEEP') , '');
		} else {
			Slim::Display::Animation::showBriefly($client, string('SLEEPING_IN') . ' ' . $sleepTime . ' ' . string('MINUTES'),'');
		}

		Slim::Control::Command::execute($client, ["sleep", $sleepTime * 60]);
		$client->currentSleepTime($sleepTime);
	},
	'power' => sub  {
		my $client = shift;
		my $button = shift;
		my $power= undef;
		if ($button eq 'power_on') {
			$power = $client->power(1);
		} elsif ($button eq 'power_off') {
			$power = $client->power(0);
		} else {
			$power = $client->power(!$client->power);
		}
	},
	'shuffle' => sub  {
		my $client = shift;
		my $button = shift;
		my $shuffle = undef;
		if ($button eq 'shuffle_on') {
			$shuffle = 1;
		} elsif ($button eq 'shuffle_off') {
			$shuffle = 0;
		}
		Slim::Control::Command::execute($client, ["playlist", "shuffle" , $shuffle]);
		
		if (Slim::Player::Playlist::shuffle($client) == 2) {
				Slim::Display::Animation::showBriefly($client, string('SHUFFLE_ON_ALBUMS'), "");
		} elsif (Slim::Player::Playlist::shuffle($client) == 1) {
				Slim::Display::Animation::showBriefly($client, string('SHUFFLE_ON_SONGS'), "");
		} else {
				Slim::Display::Animation::showBriefly($client, string('SHUFFLE_OFF'), "");
		}
	},
	'titleFormat' => sub  {
		# rotate the titleFormat
		my $client = shift;
		Slim::Utils::Prefs::clientSet($client, "titleFormatCurr"
				, (Slim::Utils::Prefs::clientGet($client, "titleFormatCurr") + 1) % (Slim::Utils::Prefs::clientGetArrayMax($client, "titleFormat") + 1));
		$client->update();
	},
 	'datetime' => sub  {
 		# briefly display the time/date
 		Slim::Display::Animation::showBriefly(shift,dateTime(),3);
 	},
	'textsize' => sub  {
		my $client = shift;
		my $button = shift;
		my $doublesize = Slim::Utils::Prefs::clientGet($client, "doublesize") ? 0 : 1;
		if ($button eq 'textsize_large') {
			$doublesize = 1;
		} elsif ($button eq 'textsize_small') {
			$doublesize = 0;
		}
		Slim::Utils::Prefs::clientSet($client, "doublesize", $doublesize);
		$client->update();
	},
	'clearPlaylist' => sub {
		my $client = shift;
		Slim::Display::Animation::showBriefly($client, string('CLEARING_PLAYLIST'), '');
		Slim::Control::Command::execute($client, ['playlist', 'clear']);
	},
	'modefunction' => sub {
		my ($client,$funct,$functarg) = @_;
		return if !$functarg;
		my ($mode,$modefunct) = split('->',$functarg);
		return if !exists($modeFunctions{$mode});
		my $coderef = $modeFunctions{$mode}{$modefunct};
		my $modefunctarg;
 		if (!$coderef && ($modefunct =~ /(.+?)_(.+)/) && ($coderef = $modeFunctions{$mode}{$1})) {
 			$modefunctarg = $2;
 		}
		&$coderef($client,$modefunct,$modefunctarg) if $coderef;
	}

);

 sub getFunction {
 	my $client = shift;
 	my $function = shift;
 	my $clientMode = shift;
 	my $coderef;
 	$clientMode = mode($client) unless defined($clientMode);
 	if ($coderef = $modeFunctions{$clientMode}{$function}) {
 		return $coderef;
 	} elsif (($function =~ /(.+?)_(.+)/) && ($coderef = $modeFunctions{$clientMode}{$1})) {
 		return $coderef,$2;
 	} elsif ($coderef = $functions{$function}) {
 		return $coderef;
 	} elsif (($function =~ /(.+?)_(.+)/) && ($coderef = $functions{$1})) {
 		return $coderef,$2
 	} else {
 		return;
 	}
}

sub pushButton {
	my $sub = shift;
	my $client = shift;

	no strict 'refs';
	my ($subref,$subarg) = getFunction($client,$sub);
	&$subref($client,$sub,$subarg);
}

sub scroll {
	scroll_dynamic(@_);
}

# Minimum Velocity for scrolling, in items/second
my $minimumVelocity = 2;

# Time that you must hold the scroll button before the automatic
# scrolling and acceleration starts. 
# in seconds.
my $holdTimeBeforeScroll = 0.300;  

my $scrollClientHash = {};

sub scroll_dynamic {
	my $client = shift;
	my $direction = shift;
	my $listlength = shift;
	my $currentPosition = shift;
	my $newposition;
	my $holdTime = Slim::Hardware::IR::holdTime($client);
	# Set up initial conditions
	if (!defined $scrollClientHash->{$client}) {
		#$client->{scroll_params} =
		$scrollClientHash->{$client}{scrollParams} = 
			scroll_getInitialScrollParams(
										  $minimumVelocity, 
										  $listlength, 
										  $direction
										  );
	}
	my $scrollParams = $scrollClientHash->{$client}{scrollParams};

	my $result = undef;
	if ($holdTime == 0) {
		# define behavior for button press, before any acceleration
		# kicks in.
		
		# if at the end of the list, and down is pushed, go to the beginning.
		if ($currentPosition == $listlength-1  && $direction > 0) {
			# if at the end of the list, and down is pushed, go to the beginning.
			$currentPosition = -1; # Will be added to later...
			$scrollParams->{estimateStart} = 0;
			$scrollParams->{estimateEnd}   = $listlength - 1;
		} elsif ($currentPosition == 0 && $direction < 0) {
			# if at the beginning of the list, and up is pushed, go to the end.
			$currentPosition = $listlength;  # Will be subtracted from later.
			$scrollParams->{estimateStart} = 0;
			$scrollParams->{estimateEnd}   = $listlength - 1;
		}
		# Do the standard operation...
		$scrollParams->{lastHoldTime} = 0;
		$scrollParams->{V} = $scrollParams->{minimumVelocity} *
			$direction;
		$scrollParams->{A} = 0;
		$result = $currentPosition + $direction;
		if ($direction > 0) {
			$scrollParams->{estimateStart} = $result;
			if ($scrollParams->{estimateEnd} <
				$scrollParams->{estimateStart}) {
				$scrollParams->{estimateEnd} =
					$scrollParams->{estimateStart} + 1; 
			}
		} else {
			$scrollParams->{estimateEnd} = $result;
			if ($scrollParams->{estimateStart} >
				$scrollParams->{estimateEnd}) {
				$scrollParams->{estimateStart} =
					$scrollParams->{estimateEnd} - 1;
			}
		}
		scroll_resetScrollRange($result, $scrollParams, $listlength);
		$scrollParams->{lastPosition} = $result;
	} elsif ($holdTime < $holdTimeBeforeScroll) {
		# Waiting until holdTimeBeforeScroll is exceeded
		$result = $currentPosition;
	} else {
		# define behavior for scrolling, i.e. after the initial
		# timeout.
		$scrollParams->{A} = scroll_calculateAcceleration
			(
			 $direction, 
			 $scrollParams->{estimateStart},
			 $scrollParams->{estimateEnd},
			 $scrollParams->{Tc}
			 );
		my $accel = $scrollParams->{A};
		my $time = $holdTime - $scrollParams->{lastHoldTime};
		my $velocity = $scrollParams->{A} * $time + $scrollParams->{V};
		my $pos = ($scrollParams->{lastPositionReturned} == $currentPosition) ? 
			$scrollParams->{lastPosition} : 
			$currentPosition;
		my $X = 
			(0.5 * $scrollParams->{A} * $time * $time) +
			($scrollParams->{V} * $time) + 
			$pos;
		$scrollParams->{lastPosition} = $X; # Retain the last floating
		                                    # point value of $X
		                                    # because it's needed to
   		                                    # maintain the proper
		                                    # acceleration when
		                                    # $minimumVelocity is
		                                    # small and not much
		                                    # motion happens between
		                                    # successive calls.
		$result = int(0.5 + $X);
		scroll_resetScrollRange($result, $scrollParams, $listlength);
		$scrollParams->{V} = $velocity;
		$scrollParams->{lastHoldTime} = $holdTime;
	}
	if ($result >= $listlength) {
		$result = $listlength - 1;
	}
	if ($result < 0) {
		$result = 0;
	}
	$scrollParams->{lastPositionReturned} = $result;
	$scrollParams->{lastDirection}        = $direction;
	return $result;
}

sub scroll_resetScrollRange
{
	my $currentPosition = shift;
	my $scrollParams    = shift;
	my $listlength      = shift;

	my $delta = ($scrollParams->{estimateEnd} - $scrollParams->{estimateStart})+1;
	if ($currentPosition > $scrollParams->{estimateEnd}) {
	    $scrollParams->{estimateEnd} = $scrollParams->{estimateEnd} + $delta;
	    if ($scrollParams->{estimateEnd} >= $listlength) {
			$scrollParams->{estimateEnd} = $listlength-1;
	    }
	} elsif ($currentPosition < $scrollParams->{estimateStart}) {
	    $scrollParams->{estimateStart} = $scrollParams->{estimateStart} - $delta;
	    if ($scrollParams->{estimateStart} < 0) {
			$scrollParams->{estimateStart} = 0;
		}
	}
}

sub scroll_calculateAcceleration 
{
	my ($direction, $estimatedStart, $estimatedEnd, $Tc)  = @_;
	my $deltaX = $estimatedEnd - $estimatedStart;
	my $acceleration = 
		2.0 * $deltaX / ($Tc * $Tc) * $direction;
	return $acceleration;
}
sub scroll_getInitialScrollParams {
	my $minimumVelocity = shift; 
	my $listLength      = shift;
	my $direction       = shift;

	my $result = {};
	$result = {
			#
			# Constants.
			#

            # Items/second.  Don't go any slower than this under any circumstances. 
			minimumVelocity => $minimumVelocity,  
			                        
			# seconds.  Finishs a list in this many seconds. 
			Tc              => 5,   
			                        
			# 
			# Variables
			#

			# Starting estimate of target space.
			estimateStart   => 0,   

			
			# Ending estimate of target space
			estimateEnd     => $listLength, 
			                        
			
			# The current velocity.  account for direction
			V               => $minimumVelocity * $direction,
			
			# The current acceleration.
			A               => 0,

			# The 'hold Time' value the last time we were called.
			# a negative number means it hasn't been called before, or
			# the button has been released.
			lastHoldTime    => -1,

			# To make the 
			lastPosition    => 0,      # Last calculated position (floating point)
			lastPositionReturned => 0, # Last returned position   (integer), used to detect when $currentPosition has been modified outside the scroll routines.
			
			# Maintain the last direction, so that we can implement a
			# slowdown when the user hits  the same direciton twice.
			# i.e. he's almost to where he wants to go, but not quite
			# there yet.  Slow velocity by half, and don't wait for
			# pause. 
#			lastDirection   => 0,      

		};
	return $result;
}

# scroll with acceleration based on list length and stop at the end if we're accelerating...
sub scroll_original {
	my $client = shift;
	my $direction = shift;
	my $listlength = shift;
	my $currentlistposition = shift;
	my $newposition;
	my $holdtime = Slim::Hardware::IR::holdTime($client);

	if (!$listlength) {
		return 0;
	}
	
	my $i = 1;
	my $rate; # Hz
	my $accel; #Hz/s
	$i *= $direction;

	if ($holdtime > 0) {
		if ($listlength < 21 || $holdtime < 1) {
			$rate = 3; # constant rate for short lists
			$accel = 0;
		} elsif ($holdtime < 2.5) {
			$rate = 5;
		} else { 
			$accel = 0.06 * $listlength; 
			# should span in 5 seconds with constant acceleration after initial slowness
		}
		$i *= Slim::Hardware::IR::repeatCount($client,$rate,$accel);
	}

	if (($currentlistposition + $i) >= $listlength) {
		if ($holdtime > 0) {
			$newposition = $listlength - 1;
		} else {
			$newposition = 0;
		}
	} elsif (($currentlistposition + $i) < 0) {
		if ($holdtime > 0) {
			$newposition = 0;
		} else {
			$newposition = $listlength - 1;
		}
	} else {
		$newposition = $currentlistposition + $i;
	}

	return $newposition;
}

sub mixer {
	my $client = shift;
	my $feature = shift; # bass/treble
	my $setting = shift; # up/down/value
	
	my $accel = 8; # Hz/sec
	my $rate = 50; # Hz
	my $inc = 1;
	my $cmd;
	if (Slim::Hardware::IR::holdTime($client) > 0) {
		$inc *= Slim::Hardware::IR::repeatCount($client,$rate,$accel);
	} else {
		$inc = 2.5;
	}
	if ((!$inc && $setting =~ /up|down/) || $feature !~ /bass|treble/) {
		return;
	}
	my $currVal = Slim::Utils::Prefs::clientGet($client,$feature);
	if ($setting  eq 'up') {
		$cmd = "+$inc";
		if ($currVal < 48.5 && ($currVal + $inc) >= 48.5) {
			# make the midpoint sticky by resetting the start of the hold
			$cmd = 50;
			Slim::Hardware::IR::resetHoldStart($client);
		}
	} elsif ($setting eq 'down') {
		$cmd = "-$inc";
		if ($currVal > 51.5 && ($currVal - $inc) <= 51.5) {
			# make the midpoint sticky by resetting the start of the hold
			$cmd = 50;
			Slim::Hardware::IR::resetHoldStart($client);
		}
	} elsif ($setting =~ /(\d+)/) {
		$cmd = $1;
	} else {
		return;
	}
		
	Slim::Control::Command::execute($client, ["mixer", $feature, $cmd]);
	#TO DO: make a function like Slim::Display::Display::volumeDisplay for bass/treble
	#       so that this function can work from anywhere and not just settings
	$client->update();
}

my @numberLetters = ([' ','0'], # 0
					 ['.',',',"'",'?','!','@','-','1'], # 1
					 ['A','B','C','2'], 				# 2
					 ['D','E','F','3'], 				# 3
					 ['G','H','I','4'], 				# 4
					 ['J','K','L','5'], 				# 5
					 ['M','N','O','6'], 				# 6
					 ['P','Q','R','S','7'], 	# 7
					 ['T','U','V','8'], 				# 8
					 ['W','X','Y','Z','9']); 			# 9

sub numberLetter {
	my $client = shift;
	my $digit = shift;
	my $table = shift || \@numberLetters;
	my $letter;
	my $index;

	my $now = Time::HiRes::time();
	# if the user has hit new button or hasn't hit anything for 1.0 seconds, use the first letter
	if (($digit ne $client->lastLetterDigit) ||
		($client->lastLetterTime + Slim::Utils::Prefs::get("displaytexttimeout") < $now)) {
		$index = 0;
	} else {
		$index = $client->lastLetterIndex + 1;
		$index = $index % (scalar(@{$table->[$digit]}));
	}

	$letter = $table->[$digit][$index];
	$client->lastLetterDigit($digit);
	$client->lastLetterIndex($index);
	$client->lastLetterTime($now);
	return $letter;
}

sub testSkipNextNumberLetter {
	my $client = shift;
	my $digit = shift;
	return (($digit ne $client->lastLetterDigit) && (($client->lastLetterTime + Slim::Utils::Prefs::get("displaytexttimeout")) > Time::HiRes::time()));
}

sub numberScroll {
	my $client = shift;
	my $digit = shift;
	my $listref = shift;
	my $sorted = shift; # is the list sorted?

	# optional reference to subroutine that takes a single parameter
	# of an index and returns the value for the item in the array we're searching.
	my $lookupsubref = shift;

	my $listsize = scalar @{$listref};

	if ($listsize <= 1) {
		return 0;
	}
	my $i;
	if (!$sorted) {
		if ($digit == 0) { $digit = 10; }
		$digit -= 1;
		if ($listsize < 10) {
			$i = $digit;
			if ($i > $listsize - 1) { $i = $listsize - 1; }
		} else {
			$i = int(($listsize - 1) * $digit/9);
		}
	} else {

		if (!defined($lookupsubref)) {
			$lookupsubref = sub { return $listref->[shift]; }
		}

		my $letter = numberLetter($client, $digit);
		# binary search	through the diritems, assuming that they are sorted...
		$i = firstIndexOf($letter, $lookupsubref, $listsize);


		# reset the scroll parameters so that the estimated start and end are at the previous letter and next letter respectively.
		$scrollClientHash->{$client}{scrollParams}{estimateStart} =
			firstIndexOf(chr(ord($letter)-1), $lookupsubref, $listsize);
		$scrollClientHash->{$client}{scrollParams}{estimateEnd} = 
			firstIndexOf(chr(ord($letter)+1), $lookupsubref, $listsize);
	}
	return $i;
}
# 
# utility function for numberScroll.  Does binary search for $letter,
# using $lookupsubref to lookup where we are.
# 
sub firstIndexOf
{
	my ($letter, $lookupsubref, $listsize)  = @_;

	my $high = $listsize;
	my $low = -1;
	my $i = -1;
	for ( $low = -1; $high - $low > 1; ) {
		$i = int(($high + $low) / 2);
		my $j = uc(substr($lookupsubref->($i), 0, 1));
		if ($letter eq $j) {
			last;
		} elsif ($letter lt $j) {
			$high = $i;
		} else {
			$low = $i;
		}
	}
	
	# skip back to the first matching item.
	while ($i > 0 && $letter eq uc(substr($lookupsubref->($i-1), 0, 1))) {
		$i--;
	}
	return $i;

}

sub mode {
	my $client = shift;
	Slim::Utils::Misc::assert($client);
	return $client->modeStack(-1);
}

sub param {
	my $client = shift;
	my $paramname = shift;
	my $paramvalue = shift;
	if (defined $paramvalue) {
		${$client->modeParameterStack(-1)}{$paramname} = $paramvalue;
	} else {
		return ${$client->modeParameterStack(-1)}{$paramname};
	}
}

# pushMode takes the following parameters:
#   client - reference to a client structure
#   setmode - name of mode we are pushing into
#   paramHashRef - reference to a hash containing the parameters for that mode
sub pushMode {
	my $client = shift;
	my $setmode = shift;
	my $paramHashRef = shift;
	$::d_files && msg("pushing button mode: $setmode\n");
	my $oldmode =mode($client);
	if ($oldmode) {
		my $exitFun = $leaveMode{$oldmode};
		if ($exitFun) {
			&$exitFun($client, 'push');
		}
	}
	# reset the scroll parameters
	push (@{$scrollClientHash->{$client}{scrollParamsStack}}, 
		  $scrollClientHash->{$client}{scrollParams});
	
	$scrollClientHash->{$client}{scrollParams} = scroll_getInitialScrollParams($minimumVelocity, 1, 1);
	push @{$client->modeStack}, $setmode;

	if (!defined($paramHashRef)) {
		$paramHashRef = {};
	}

	push @{$client->modeParameterStack}, $paramHashRef;
	my $fun = $modes{$setmode};
	&$fun($client,'push');
}

sub popMode {
	my $client = shift;
	if (scalar(@{$client->modeStack}) < 1) {
		return undef;
	}

	my $oldMode = mode($client);
	if ($oldMode) {
		my $exitFun = $leaveMode{$oldMode};
		if ($exitFun) {
			&$exitFun($client, 'pop');
		}
	}
	
	pop @{$client->modeStack};
	pop @{$client->modeParameterStack};
	$scrollClientHash->{$client}{scrollParams} = pop @{$scrollClientHash->{$client}{scrollParamsStack}};
	
	my $newmode = mode($client);
	if ($newmode) {
		my $fun = $modes{$newmode};
		&$fun($client,'pop');
	}
	$::d_files && msg("popped to button mode: " . mode($client) . "\n");
	
	return $oldMode
}

sub setMode {
	my $client = shift;
	my $setmode = shift;
	while (popMode($client)) {};
	pushMode($client, $setmode);
}

sub pushModeLeft {
	my $client = shift;
	my $setmode = shift;
	my $paramHashRef = shift;

	my @oldlines = Slim::Display::Display::curLines($client);
	pushMode($client, $setmode, $paramHashRef);
	Slim::Display::Animation::pushLeft($client, @oldlines, Slim::Display::Display::curLines($client));
}

sub popModeRight {
	my $client = shift;
	my @oldlines = Slim::Display::Display::curLines($client);
	Slim::Buttons::Common::popMode($client);
	Slim::Display::Animation::pushRight($client, @oldlines, Slim::Display::Display::curLines($client));
}

sub dateTime {
	my $client = shift;
	my @line = (Slim::Utils::Misc::longDateF(), Slim::Utils::Misc::timeF());
	for my $i (0..$#line) {
		# center the strings on the display by space padding them
		$line[$i] = Slim::Display::Display::center($line[$i]);
	}
	return @line;
}

1;
__END__

# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:
