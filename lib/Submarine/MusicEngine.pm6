unit module Submarine::MusicEngine;
use ScaleVec;

use Submarine::Types;
use Submarine::NoteOut;
use Submarine::MusicEngine::Harmony;

#! ScaleVec declaration helper
our sub sv(*@vector --> ScaleVec) {
    ScaleVec.new(:@vector)
}

# Ionian
constant base-scale = sv(0, 2, 4, 5, 7, 9, 11, 12);
# Dorian
constant safe-reef-scale = sv(2, 4, 5, 7, 9, 11, 12, 14);
# lydian
constant drop-pod-scale = sv(5, 7, 9, 11, 12, 14, 16, 17);
# mixolydian
constant kelp-scale = sv(7, 9, 11, 12, 14, 16, 17, 19);
# Aolian
constant drop-off-scale = sv(9, 11, 12, 14, 16, 17, 19, 21);
# major-minor
constant redweed-scale = sv(0, 2, 4, 5, 7, 8, 10, 12);

# Default
constant chromatic = sv(1..12);

# Tempo scales
constant slow = sv(0, 0.6);
constant nuetral = sv(0, 0.5);
constant relaxed = sv(0, 0.4);
constant lively = sv(0, 0.35);

# Time signiture
constant common-time = sv(0, 2, 4, 6);
constant common-time-half-speed = sv(0, 4, 8, 12);

our class ScoreEvent {
    has Numeric $.delta = 0;
    has $.event;
}

our class ScoreState {
    has ScaleVec @.pitch-layer = [chromatic.transpose(60), chromatic, tonic];
    has ScaleVec @.rhythmn-layer = nuetral, nuetral, common-time;

    has ScoreEvent @!event-queue;
    has ScoreEvent @!unsorted-events;
    method queue(Numeric $beat, $event) {
        @!unsorted-events.push: ScoreEvent.new(:delta(self.map-onto-rhythmn($beat).head), :$event);
        #@!event-queue .= sort( { $^a.delta <=> $^b.delta } )
    }
    method poll($delta --> Seq) {
        # Consolidate new events
        @!event-queue = (|@!event-queue, |@!unsorted-events.splice)
                            .sort( { $^a.delta <=> $^b.delta } )
                            if @!unsorted-events;

        # Collect events which are ready to send off for play out
        do while @!event-queue.grep( { $delta > .delta } ).head {
            @!event-queue.shift
        }
    }

    # Map values into pitch structure
    method map-into-pitch(+@values) {
        eager reduce { $^b.reflexive-step($^a) }, $_, |@!pitch-layer for @values
    }

    # Map values into rhythmn structure
    method map-into-rhythmn(+@values) {
        eager reduce { $^b.reflexive-step($^a) }, $_, |@!rhythmn-layer for @values
    }

    # Map values onto pitch structure
    method map-onto-pitch(+@values) {
        eager reduce { $^b.step($^a) }, $_, |@!pitch-layer.reverse for @values
    }

    # Map values onto rhythmn structure
    method map-onto-rhythmn(+@values) {
        eager reduce { $^b.step($^a) }, $_, |@!rhythmn-layer.reverse for @values
    }

    # Calculate absolute interval in scale terms
    method scale-interval(Numeric $a, Numeric $b --> Numeric) {
        [-] do reduce { $^b.reflexive-step($^a) }, $_, |@!pitch-layer[0..*-2] for $b, $a
    }

    method map-into-scale(+@values) {
        eager reduce { $^b.reflexive-step($^a) }, $_, |@!pitch-layer[0..*-2] for @values
    }

    method map-onto-scale(+@values) {
        eager reduce { $^b.step($^a) }, $_, |@!pitch-layer[0..*-2].reverse for @values
    }

    # Map values onto rhythmn structure
    method map-onto-tempo(+@values) {
        eager reduce { $^b.step($^a) }, $_, |@!rhythmn-layer[0..1].reverse for @values
    }
}

our sub music-engine-runtime(Submarine::NoteOut::OscSender $out, &get-state, &is-playing) is export
#: Runtime block for the music engine, to be called by the game state handler
{
    my $delta = now;
    my $score-epoch = $delta;
    my ScoreState $score-state .= new;
    my $last-score-state = CurrentState.new;
    my Int $scale-test = 0;
    my $chord-progression-model = Submarine::MusicEngine::Harmony::<$tonic>;
    my $phrase-length = 8;
    my $bar-length = 4;
    # my $chord-plan = do gather for 0..^$phrase-length {
    #     take ($chord-progression-model.value, $chord-progression-model) for 0..^$bar-length;
    #     $chord-progression-model .= pick-next;
    # }

    my $current-beat = 0;

    # Scheduling and event handler loop
    for 0..Inf {
        #
        # Process, ready for the next tick
        #
        # my $next-beat-interval = [-] ($current-beat + 1, $current-beat).map( { $score-state.rhythmn-layer[0].step: $_ } );
        my $next-beat-interval = [-] $score-state.map-onto-tempo($current-beat + 1, $current-beat);

        if is-playing() == 1 {
            await Promise.at($delta).then: {
                my $game-state = get-state;
                say $game-state.perl;

                # Update score structure from Envirionment
                given $game-state.environment {
                    when * ~~ $last-score-state.environment {
                        # No change
                    }
                    when Environment::SafeReef {
                        $score-state.pitch-layer[1] = safe-reef-scale;
                        $score-state.rhythmn-layer[0] = relaxed;
                        $score-state.rhythmn-layer[2] = common-time;
                    }
                    when Environment::DropOff {
                        $score-state.pitch-layer[1] = drop-off-scale;
                        $score-state.rhythmn-layer[0] = slow;
                        $score-state.rhythmn-layer[2] = common-time-half-speed;
                    }
                    when Environment::Kelp {
                        $score-state.pitch-layer[1] = kelp-scale;
                        $score-state.rhythmn-layer[0] = lively;
                        $score-state.rhythmn-layer[2] = common-time;
                    }
                    when Environment::RedWeed {
                        $score-state.pitch-layer[1] = redweed-scale;
                        $score-state.rhythmn-layer[0] = nuetral;
                        $score-state.rhythmn-layer[2] = common-time-half-speed;
                    }
                    when Environment::DropPod {
                        $score-state.pitch-layer[1] = drop-pod-scale;
                        $score-state.rhythmn-layer[0] = nuetral;
                        $score-state.rhythmn-layer[2] = common-time-half-speed;
                    }
                    default {
                        say "Setting unhandled state { .perl } to chromatic";
                        $score-state.pitch-layer[1] = chromatic
                    }
                }

                # Update score structure from GameState
                given $game-state.game-state {
                    when * ~~ $last-score-state.game-state {
                        # No change
                    }
                    when * ~~ GameState::Safe {
                        $score-state.rhythmn-layer[1] = nuetral
                    }
                    when GameState::Oxygen {
                        $score-state.rhythmn-layer[1] = lively
                    }
                    when GameState::Damaged {
                        $score-state.rhythmn-layer[1] = slow
                    }
                    when GameState::Danger {
                        $score-state.rhythmn-layer[1] = lively
                    }
                    default {
                        say "Ignoreing unhandled state { .perl }";
                    }
                }

                # After state checks, save the new state for next time
                $last-score-state = $game-state;

                my $beats-per-bar = $score-state.rhythmn-layer[2].scale-pv.elems;
                my $beat-of-bar = $score-state.rhythmn-layer[2].reflexive-step($current-beat);
                my $is-on-beat = $beat-of-bar == $beat-of-bar.truncate;
                # Start of bar actions
                if $is-on-beat and $beat-of-bar.floor mod $beats-per-bar == 0 {
                    say "Next chord";
                    $chord-progression-model .= pick-next;
                    $score-state.pitch-layer[2] = $chord-progression-model.chord;
                }

                $out.send-note: 'track-1',
                        $score-state.map-onto-pitch(++$scale-test mod $score-state.pitch-layer[2].repeat-interval).head,
                        120, $next-beat-interval / 2,
                        :at($delta + $next-beat-interval);

                $out.send-note: 'track-1',
                        $score-state.map-onto-pitch(++$scale-test mod $score-state.pitch-layer[2].repeat-interval).head,
                        120, $next-beat-interval / 2,
                        :at($delta + $next-beat-interval + ($next-beat-interval/2));

                $out.send-note: 'track-2',
                    $score-state.map-onto-pitch($score-state.pitch-layer[2].vector.head).head - 12,
                    80, $next-beat-interval * 2,
                    :at($delta + $next-beat-interval)
                    if $is-on-beat;

                # my $quaver-count = floor($event-window[0] / 0.5) * 0.5;
                # if $quaver-count >= $event-window[0] and $quaver-count = $event-window[1] {
                #     say "Accepted $quaver-count with window of { $event-window.perl }";
                #     $out.send-note: 'track-1',
                #         $score-state.map-onto-pitch(++$scale-test mod 12).head,
                #         120,
                #         0.5,
                #         :at($delta + chunk-size + ([-] $score-state.map-onto-rhythmn($quaver-count, $event-window[0])));
                # }
                # else {
                #     say "Ignored $quaver-count with window of { $event-window.perl }";
                # }

            }
        }
        else {
            await Promise.at($delta)
        }

        # Move forward one beat
        $delta += $next-beat-interval;
        $current-beat += 1;
    }

}