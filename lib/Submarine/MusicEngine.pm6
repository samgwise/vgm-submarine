unit module Submarine::MusicEngine;
use ScaleVec;

use Submarine::Types;
use Submarine::NoteOut;
use Submarine::MusicEngine::Harmony;
use Submarine::MusicEngine::Rhythmn;
use Submarine::MusicEngine::Tempo;
use Submarine::Utils;

# Ionian
constant base-scale = sv(0, 2, 4, 5, 7, 9, 11, 12);
# Dorian
constant safe-reef-scale = sv(2, 4, 5, 7, 9, 11, 12, 14);
# lydian
constant drop-pod-scale = sv(5, 7, 9, 11, 12, 14, 16, 17);
# mixolydian
constant kelp-scale = sv(7, 9, 11, 12, 14, 16, 17, 19);
# Aeolian
constant drop-off-scale = sv(9, 11, 12, 14, 16, 17, 19, 21);
# major-minor
constant redweed-scale = sv(0, 2, 4, 5, 7, 8, 10, 12);

# Default
constant chromatic = sv(0..12);

# Tempo scales
constant slow = sv(0, 0.6);
constant nuetral = sv(0, 0.5);
constant relaxed = sv(0, 0.4);
constant lively = sv(0, 0.35);

# Time signature
constant common-time = sv(0, 2, 4, 6);
constant common-time-half-speed = sv(0, 4, 8, 12);

our class ScoreEvent {
    has Numeric $.delta = 0;
    has $.event;
}

our class ScoreState {
    has ScaleVec @.pitch-layer = [chromatic.transpose(60), chromatic, tonic];
    has ScaleVec @.rhythmn-layer = nuetral, nuetral, common-time;
    has Submarine::MusicEngine::Harmony::ChordNode @.chord-plan = [Submarine::MusicEngine::Harmony::<$tonic>];

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

    # Map two values into pitch structure and return the interval
    method map-into-pitch-interval(Numeric $a, Numeric $b --> Numeric) {
        [-] reduce { $^b.reflexive-step($^a) }, $_, |@!pitch-layer for $b, $a
    }

    # Map values into rhythmn structure
    method map-into-rhythmn(+@values) {
        eager reduce { $^b.reflexive-step($^a) }, $_, |@!rhythmn-layer for @values
    }

    # Map two values into rhythmn structure and return the interval
    method map-into-rhythmn-interval(Numeric $a, Numeric $b --> Numeric) {
        [-] reduce { $^b.reflexive-step($^a) }, $_, |@!rhythmn-layer for $b, $a
    }

    # Map values onto pitch structure
    method map-onto-pitch(+@values) {
        eager reduce { $^b.step($^a) }, $_, |@!pitch-layer.reverse for @values
    }

    # Map two values onto pitch structure and return the interval
    method map-onto-pitch-interval(Numeric $a, Numeric $b --> Numeric) {
        [-] reduce { $^b.step($^a) }, $_, |@!pitch-layer.reverse for $b, $a
    }

    # Map values onto rhythmn structure
    method map-onto-rhythmn(+@values) {
        eager reduce { $^b.step($^a) }, $_, |@!rhythmn-layer.reverse for @values
    }

    # Map values onto rhythmn structure
    method map-onto-rhythmn-interval(Numeric $a, Numeric $b --> Numeric) {
        [-] reduce { $^b.step($^a) }, $_, |@!rhythmn-layer.reverse for $b, $a
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

    # Generates a new chord plan extending from where the current plan ends.
    method plan-chords(Numeric $bars, $bar-length, Positional $environment --> Seq) {
        my $last-chord = @!chord-plan.tail // Submarine::MusicEngine::Harmony::<$tonic>;
        gather for 0..^($bars * $bar-length) {
            $last-chord .= pick-next(|$environment);
            take |($last-chord xx $last-chord.beats.($bar-length));
            say "took: $last-chord xx { $last-chord.beats.($bar-length) } chords";
        }
    }

    #! determine the tonicised transposition of the scale space given two chords
    method tonicise-scale-distance(ScaleVec $a, ScaleVec $b --> Numeric) {
        my $octave = @!pitch-layer.head.repeat-interval;
        given (5 - ([-] self.map-onto-scale($b.root, $a.root))) % $octave {
            when abs(@!pitch-layer[*-2].root + $_) > abs(@!pitch-layer[*-2].root + ($_ - $octave)) {
                $_ - $octave
            }
            default { $_ }
        }
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
    my $pitch-curve-model = Submarine::MusicEngine::Harmony::<$curve1>;
    my $pitch-curve = $pitch-curve-model.value;
    my $bass-rhythmn-model = Submarine::MusicEngine::Rhythmn::<$on-the-beat1>;
    my $arp-rhythmn-model = Submarine::MusicEngine::Rhythmn::<$quaver-pulse>;
    my Rat $phrase-length = 8.0;
    my $iterations-since-chord-change = 0;
    my $tempo-modulation-lerp = sv-lerp($score-state.rhythmn-layer[1], $score-state.rhythmn-layer[1], 0, 1);
    my $tempo-lerp = sv-lerp($score-state.rhythmn-layer[0], $score-state.rhythmn-layer[0], 0, 1);

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
                        $score-state.pitch-layer[1] = safe-reef-scale.transpose($score-state.tonicise-scale-distance: $score-state.pitch-layer[2], safe-reef-scale);
                        #$score-state.rhythmn-layer[0] = relaxed;
                        $tempo-lerp .= for-target(relaxed, $current-beat, 1/64);
                        $score-state.rhythmn-layer[2] = common-time;
                    }
                    when Environment::DropOff {
                        $score-state.pitch-layer[1] = drop-off-scale.transpose($score-state.tonicise-scale-distance: $score-state.pitch-layer[2], drop-off-scale);
                        #$score-state.rhythmn-layer[0] = slow;
                        $tempo-lerp .= for-target(slow, $current-beat, 1/96);
                        $score-state.rhythmn-layer[2] = common-time-half-speed;
                    }
                    when Environment::Kelp {
                        $score-state.pitch-layer[1] = kelp-scale.transpose($score-state.tonicise-scale-distance: $score-state.pitch-layer[2], kelp-scale);
                        #$score-state.rhythmn-layer[0] = lively;
                        $tempo-lerp .= for-target(lively, $current-beat, 1/64);
                        $score-state.rhythmn-layer[2] = common-time;
                    }
                    when Environment::RedWeed {
                        $score-state.pitch-layer[1] = redweed-scale.transpose($score-state.tonicise-scale-distance: $score-state.pitch-layer[2], redweed-scale);
                        #$score-state.rhythmn-layer[0] = nuetral;
                        $tempo-lerp .= for-target(nuetral, $current-beat, 1/64);
                        $score-state.rhythmn-layer[2] = common-time-half-speed;
                    }
                    when Environment::DropPod {
                        $score-state.pitch-layer[1] = drop-pod-scale.transpose($score-state.tonicise-scale-distance: $score-state.pitch-layer[2], drop-pod-scale);
                        #$score-state.rhythmn-layer[0] = nuetral;
                        $tempo-lerp .= for-target(nuetral, $current-beat, 1/64);
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
                        #$score-state.rhythmn-layer[1] = nuetral
                        $tempo-modulation-lerp .= for-target(nuetral, $current-beat, 1/96)
                    }
                    when GameState::Oxygen {
                        #$score-state.rhythmn-layer[1] = lively
                        $tempo-modulation-lerp .= for-target(lively, $current-beat, 1/48)
                    }
                    when GameState::Damaged {
                        #$score-state.rhythmn-layer[1] = slow
                        $tempo-modulation-lerp .= for-target(slow, $current-beat, 1/24)
                    }
                    when GameState::Danger {
                        #$score-state.rhythmn-layer[1] = lively
                        $tempo-modulation-lerp .= for-target(lively, $current-beat, 1/24)
                    }
                    default {
                        say "Ignoreing unhandled state { .perl }";
                    }
                }

                # After state checks, save the new state for next time
                $last-score-state = $game-state;

                # Update the lerp from the current beat and set tempo modulation layer.
                $score-state.rhythmn-layer[1] = $tempo-modulation-lerp.update-lerp($current-beat);

                $score-state.rhythmn-layer[0] = $tempo-lerp.update-lerp($current-beat);

                my $beats-per-bar = $score-state.rhythmn-layer[2].scale-pv.elems;
                my $beat-of-bar = $score-state.rhythmn-layer[2].reflexive-step($current-beat);
                my $is-on-beat = $beat-of-bar == $beat-of-bar.truncate;

                # Start of bar actions
                if $is-on-beat and $beat-of-bar.floor mod $beats-per-bar == 0 {
                    say "Next chord";
                    # $chord-progression-model .= pick-next($beat-of-bar.floor % $phrase-length);

                    my List $model-env = List($beat-of-bar.floor % ($phrase-length * $beats-per-bar));

                    $score-state.chord-plan.append: $score-state.plan-chords(1, $beats-per-bar, $model-env).flat;

                    $iterations-since-chord-change = 0;

                    $bass-rhythmn-model .= pick-next(|$model-env);
                    $arp-rhythmn-model .= pick-next(|$model-env);
                    $score-state.pitch-layer[2] = $chord-progression-model.chord;

                    # Start of phrase actions
                    if $beat-of-bar.floor % $phrase-length == 0 {
                        $pitch-curve-model .= pick-next;
                        $pitch-curve = $pitch-curve-model.value.extend-from($pitch-curve);
                    }
                }
                else {
                    $iterations-since-chord-change++;
                }

                # On Beat actions
                if $is-on-beat {
                    # Move the chord plan forward if there are more beats planned
                    $chord-progression-model = $_ with $score-state.chord-plan.pop;
                }

                my $beats-per-phrase = $beats-per-bar * $phrase-length;
                my $contour = $pitch-curve.contour(($beat-of-bar % $beats-per-phrase) / $beats-per-phrase).cache;
                my $rounded-contour = $score-state.map-into-pitch(|$contour.map( { $_ + 60 })).map( *.floor ).cache;
                my ($beat-window-start, $beat-window-end) = (
                    $beat-of-bar,
                    $beat-of-bar + $score-state.rhythmn-layer[2].reflexive-step(1)
                );
                say "Arragnement space: $rounded-contour for beat window: $beat-window-start, $beat-window-end";

                # Arp pattern
                my $step-down = 0;
                $out.send-note: 'track-1',
                        12 + $score-state.map-onto-pitch(($rounded-contour.tail - $step-down-- - ($iterations-since-chord-change * 2)) % $score-state.pitch-layer[2].scale-pv.elems).head,
                        120,
                        $next-beat-interval / 2,
                        :at($delta + $next-beat-interval + $score-state.map-onto-rhythmn($_ - $beat-of-bar).head)
                    for $arp-rhythmn-model.rhythmn.sub-sequence($beat-window-start, $beat-window-end);

                # Bass pattern
                $out.send-note: 'track-2',
                        $score-state.map-onto-pitch($rounded-contour.head).head + 12,
                        80, $next-beat-interval * 2,
                        :at($delta + $next-beat-interval + $score-state.map-onto-rhythmn($_ - $beat-of-bar).head)
                    for $bass-rhythmn-model.rhythmn.sub-sequence($beat-window-start, $beat-window-end);

                # Send curve values for logging
                $out.send-note: 'track-14',
                    $_, 100, $next-beat-interval,
                    :at($delta + $next-beat-interval)
                for $score-state.map-onto-pitch(|$rounded-contour);
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