unit module Submarine::MusicEngine::Tempo;
use ScaleVec;
use Submarine::Utils;

#! A time based lerp between two ScaleVecs
our class SVLerp {
    has ScaleVec $.beginning is required;
    has ScaleVec $.current;
    has ScaleVec $.target is required;

    has Numeric $.beat-start is required;
    has Numeric $.change-increment is required;
    has Numeric $.beat-end;

    submethod TWEAK() {
        $!current = $!beginning;
        # Assuming the difference in the last values will be the largest.
        my $interval = $!target.scale-pv.tail - $!beginning.scale-pv.tail;
        $!beat-end = $!beat-start + ($interval.abs / $!change-increment);
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
    method for-target(ScaleVec $target, Numeric $beat-start, Numeric $change-increment) {
        self.new(
            :beginning($!current)
            :$target
            :$beat-start
            :$change-increment
        )
    }

}

#! Factory function for SVLerp objects
our sub sv-lerp(ScaleVec $beginning, ScaleVec $target, Numeric $beat-start, Numeric $change-increment) is export {
SVLerp.new(
    :$beginning
    :$target
    :$beat-start
    :$change-increment
    )
}