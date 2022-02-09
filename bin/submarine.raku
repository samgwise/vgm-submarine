#! /usr/bin/env perl6
use v6.d;

use ScaleVec;
use Math::Curves;
use Reaper::Control;
use VGM::Scene::Events;
use Config::TOML; # Used for interfacing with midi_sender.exe

use Submarine::Types;
use Submarine::NoteOut;
use Submarine::MusicEngine;

unit sub MAIN(Str $scene, Str :$reaper-host = '127.0.0.1:9000', Str :$midi-sender, Bool :$midi-sender-remote);

#
# Setup reaper interface
#

# Shared state variables
constant state-history-length = 64;
my atomicint $state-index = 0;

# State of reaper
my atomicint $is-playing = 0;

my $listener = reaper-listener(:host($_[0]), :port($_[1].Int)) given $reaper-host.split(':', :skip-empty);

# Link reaper interface to events, see final react block for actions
my $scene-config = load-scene-config($scene);

my CurrentState @state-history = (0..^state-history-length).map( { CurrentState.new });

# State access closures
my &get-current-state = -> {
    @state-history[atomic-fetch($state-index) mod state-history-length]
}

my &update-current-state = -> CurrentState:D $state {
    @state-history[atomic-inc-fetch($state-index) mod state-history-length] = $state
}

#
# Setup note out
#

# Set up midi out based on arguments and environment
constant midi-sender-config = 'midi_sender.toml';
my Submarine::NoteOut::OscSender $out = do if $midi-sender-remote or $midi-sender.defined and $midi-sender.IO.f {
    my $config = do if midi-sender-config.IO.f {
        midi-sender-config.IO.slurp.&from-toml
    }
    else {
        midi-sender-config.IO.spurt: q:to<TOML>;
        listen_address = "127.0.0.1:10009"
        midi_port = 0
        TOML

        midi-sender-config.IO.slurp.&from-toml
    }

    my $sender-handle;
    $sender-handle = Proc::Async.new($midi-sender) if $midi-sender.defined;
    .start with $sender-handle;

    say "Using osc-interface MidiSender with { $midi-sender.defined ?? $midi-sender !! "remote: $config<listen_address>" }";
    my %channel-map = |(0..15).map( { "track-$_" => $_ + 1 } );
    say "Using channel map: { %channel-map.perl }";

    Submarine::NoteOut::OscSender::MidiSender.new(
        :targets( [$config<listen_address>.split(':', :skip-empty).head(2), ] ),
        |($midi-sender.defined ?? :midi-sender( $sender-handle ) !! ()),
        :%channel-map
    )
}
else {
    say "Using osc-interface PD";
    Submarine::NoteOut::OscSender::PD.new
}

start music-engine-runtime $out, &get-current-state, sub { atomic-fetch $is-playing };

# Handle events
react {
    whenever signal(SIGINT) {
        put "exiting...";
        exit
    }
    whenever $listener.reaper-events {
        when Reaper::Control::Event::Play {
            $is-playing ⚛= 1;
            $out.send-note: 'track-0', 36 + 14, 120, 0.5
        }
        when Reaper::Control::Event::Stop {
            $is-playing ⚛= 0;
            $out.send-note: 'track-0', 36 + 14, 120, 0.5
        }
    }
    whenever sync-scene-events($listener, $scene-config) {
        given .<path> {
            when '/Player/Active' {
                put .path;
                $out.send-note: 'track-0', 36 + 14, 120, 0.5;
                update-current-state get-current-state.transform-player(Player::Active)
            }
            when '/Player/Paused' {
                put .path;
                $out.send-note: 'track-0', 36 + 14, 120, 0.5;
                update-current-state get-current-state.transform-player(Player::Paused)
            }

            # Environment
            when '/Environment/DropPod' {
                put .path;
                $out.send-note: 'track-0', 36 + 2, 120, 0.5;
                update-current-state get-current-state.transform-environment(Environment::DropPod)
            }
            when '/Environment/SafeReef' {
                put .path;
                $out.send-note: 'track-0', 36 + 8, 120, 0.5;
                update-current-state get-current-state.transform-environment(Environment::SafeReef)
            }
            when '/Environment/DropOff' {
                put .path;
                $out.send-note: 'track-0', 36 + 9, 120, 0.5;
                update-current-state get-current-state.transform-environment(Environment::DropOff)
            }
            when '/Environment/RedWeed' {
                put .path;
                #$out.send-note: 'track-1', 48, 60, 4;
                update-current-state get-current-state.transform-environment(Environment::RedWeed)
            }

            # GameState
            when '/GameState/Safe' {
                put .path;
                $out.send-note: 'track-0', 36 + 13, 120, 0.5;
                update-current-state get-current-state.transform-game-state(GameState::Safe)
            }
            when '/GameState/Oxygen' {
                put .path;
                $out.send-note: 'track-0', 36 + 3, 120, 0.5;
                update-current-state get-current-state.transform-game-state(GameState::Oxygen)
            }
            when '/GameState/Damaged' {
                put .path;
                $out.send-note: 'track-0', 36 + 6, 120, 0.5;
                update-current-state get-current-state.transform-game-state(GameState::Damaged)
            }
            when '/GameState/Danger' {
                put .path;
                $out.send-note: 'track-0', 36 + 4, 120, 0.5;
                update-current-state get-current-state.transform-game-state(GameState::Danger)
            }

            # EnvMods
            when '/EnvMods/Vehicle' {
                put .path;
                $out.send-note: 'track-0', 36 + 15, 120, 0.5;
                update-current-state get-current-state.transform-env-mod(EnvMod::Vehicle)
            }
            when '/EnvMods/Surface' {
                put .path;
                $out.send-note: 'track-0', 36 + 13, 120, 0.5;
                update-current-state get-current-state.transform-env-mod(EnvMod::Surface)
            }
            when '/EnvMods/Underwater' {
                put .path;
                $out.send-note: 'track-0', 36 + 0, 120, 0.5;
                update-current-state get-current-state.transform-env-mod(EnvMod::Underwater)
            }
            default { put "Skipped event { .perl }" }
        }
    }
}