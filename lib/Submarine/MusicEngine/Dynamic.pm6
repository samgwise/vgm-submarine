unit module Submarine::MusicEngine::Dynamic;
use ScaleVec;
use Submarine::Utils;

# Dynamic maps                              -, ppp, pp, p,  mp, mf, f,  ff,  fff, +
our constant dynamic-strong is export = sv( 0,  15, 25, 40, 60, 75, 95, 105, 115, 127);
our constant dynamic-weak is export   = sv( 0,  10, 20, 30, 50, 65, 87, 97,  107, 127);
# Derive moderate accent beat map to be half way between strong and week beats (Lerp with t=1/2)
our constant dynamic-accent is export = sv(
    |zip(dynamic-weak.scale-pv, dynamic-strong.scale-pv,
        :with(-> $a, $b { (1 - 0.5) * $a + 0.5 * $b })
    )
);

# Expression steps
our constant dynamic-pp is export = 2;
our constant dynamic-p is export = 3;
our constant dynamic-mp is export = 4;
our constant dynamic-mf is export = 5;
our constant dynamic-f is export = 6;
our constant dynamic-ff is export = 7;

#! A time based lerp between two Numerics with a variable number of modulation values
our class Lerp {
    has Numeric $.beginning is required;
    has Numeric $.current;
    has Numeric $.target is required;
    has Numeric @.modulation = [1.0];

    has Numeric $.beat-start is required;
    has Numeric $.change-increment is required;
    has Numeric $.beat-end;

    submethod TWEAK() {
        $!current = $!beginning;
        my $interval = self.modulated-target - $!beginning;
        $!beat-end = $!beat-start + ($interval.abs / $!change-increment);
    }

    has method modulated-target() {
        $!target * ([*] @!modulation);
    }

    method update-lerp(Numeric $current-beat) {
        if $current-beat > $!beat-end or $current-beat <= $!beat-start {
            # No update needed
            $!current
        }
        else {
            my $t = ($current-beat - $!beat-start) / ($!beat-end - $!beat-start);
            $!current = (1 - $t) * $!beginning + $t * self.modulated-target();
        }
    }

    # Returns a new lerp for the given target
    method for-target(Numeric $target, Numeric $beat-start, Numeric $change-increment) {
        self.new(
            :beginning($!current)
            :target($target)
            :$beat-start
            :$change-increment
            :@!modulation
        )
    }

    # Returns a new lerp for the given modulation
    method for-modulation(@dyanmic-modulation, Numeric $beat-start, Numeric $change-increment) {
        self.new(
            :beginning($!current)
            :target($!target)
            :$beat-start
            :$change-increment,
            :modulation(@dyanmic-modulation)
        )
    }
}