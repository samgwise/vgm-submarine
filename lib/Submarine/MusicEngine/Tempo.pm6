unit module Submarine::MusicEngine::Tempo;
use ScaleVec;
use Submarine::Utils;

#! A time based lerp between two ScaleVecs
our class SVLerp {
    has ScaleVec $.beginning is required;
    has ScaleVec $.current;
    has ScaleVec $.target is required;

    has Numeric $.beat-start is required;
    has Numeric $.beat-end is required;

    submethod TWEAK() {
        $!current = $!beginning;
    }

    method update-lerp(Numeric $current-beat) {
        if $current-beat > $!beat-end or $current-beat <= $!beat-start {
            # No update needed
            $!current
        }
        else {
            my $t = ($current-beat - $!beat-start) / ($!beat-end - $!beat-start);
            $!current = sv(
                |zip($!beginning.scale-pv, $!target.scale-pv,
                    :with(-> $a, $b { (1 - $t) * $a + $t * $b })
                )
            )
        }
    }

    # Returns a new lerp for the given target
    method for-target(ScaleVec $target, Numeric $beat-start, Numeric $beat-end) {
        self.new(
            :beginning($!current)
            :$target
            :$beat-start
            :$beat-end
        )
    }
}

#! Factory function for SVLerp objects
our sub sv-lerp(ScaleVec $beginning, ScaleVec $target, Numeric $beat-start, Numeric $beat-end) is export {
SVLerp.new(
    :$beginning
    :$target
    :$beat-start
    :$beat-end
    )
}