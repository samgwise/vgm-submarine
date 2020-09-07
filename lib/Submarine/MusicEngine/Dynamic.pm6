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