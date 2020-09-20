unit module Submarine::MusicEngine::Harmony;
use ScaleVec;
use Submarine::MusicEngine::Markov;
use Submarine::Utils;

# Chords
constant tonic is export = sv(0, 2, 4, 7);
constant tonic-sus4 is export = sv(0, 3, 4, 7);
constant tonic-sus2 is export = sv(0, 1, 2, 4, 7);
constant supertonic is export = tonic.transpose(1);
constant mediant is export = tonic.transpose(2);
constant subdominant is export = tonic.transpose(3);
constant dominant is export = tonic.transpose(4);
constant dominant-sus4 is export = tonic-sus4.transpose(4);
constant dominant-sus2 is export = tonic-sus2.transpose(4);
constant dominant-seventh is export = sv(7, 9, 11, 13, 14);
constant submediant is export = tonic.transpose(5);
constant leading-tone is export = tonic.transpose(6);

#! Markov model container for chord structures
our class ChordNode does Submarine::MusicEngine::Markov::Node[ScaleVec] {

    has &.beats = sub (Numeric $bar-length) {
        $bar-length
    }

    #! A synonym for the generic $.values attribute
    method chord() {
        $!value
    }
}

# Half bar functions for distributing durations of even and odd bar lengths
my &half-bar-start = -> Numeric $bar-length { floor($bar-length / 2) }
my &half-bar-end = -> Numeric $bar-length { ceiling($bar-length / 2) }

# Create ChordNode wrappers
our $tonic = ChordNode.new( :value(tonic) );
our $tonic-sus4 = ChordNode.new( :value(tonic-sus4), :beats(&half-bar-start) );
our $tonic-resolution = ChordNode.new( :value(tonic), :beats(&half-bar-end) );
our $supertonic = ChordNode.new( :value(supertonic) );
our $subdominant = ChordNode.new( :value(subdominant) );
our $dominant = ChordNode.new( :value(dominant) );
our $dominant-seventh = ChordNode.new( :value(dominant-seventh) );
our $submediant = ChordNode.new( :value(subdominant) );

#
# Tie chords together
#

# Helper sub for declaring Markov connections
sub chord-vertex(ChordNode $from, ChordNode $to, :&probability = { 1.0 }) {
    $from.choices.push: Submarine::MusicEngine::Markov::Connection.new(:$from, :$to)
}

my &end-of-phrase = -> $beat-of-phrase { ($beat-of-phrase/ 32) * 4 }

# Tonic
chord-vertex($tonic, $submediant);
chord-vertex($tonic, $subdominant);
chord-vertex($tonic, $supertonic);
chord-vertex($tonic, $dominant, :probability(&end-of-phrase));
chord-vertex($tonic, $dominant-seventh, :probability(&end-of-phrase));

# Tonic Resolution
chord-vertex($tonic-resolution, $submediant);
chord-vertex($tonic-resolution, $subdominant);
chord-vertex($tonic-resolution, $supertonic);
chord-vertex($tonic-resolution, $dominant, :probability(&end-of-phrase));
chord-vertex($tonic-resolution, $dominant-seventh, :probability(&end-of-phrase));

# Tonic-sus-4
chord-vertex($tonic-sus4, $tonic-resolution);

# Supertonic
chord-vertex($supertonic, $dominant);
chord-vertex($supertonic, $dominant-seventh, :probability(&end-of-phrase));

# Subdominant
chord-vertex($subdominant, $dominant, :probability(&end-of-phrase));
chord-vertex($subdominant, $dominant-seventh, :probability(&end-of-phrase));
chord-vertex($subdominant, $supertonic);
chord-vertex($subdominant, $tonic);
chord-vertex($subdominant, $tonic-sus4);

# Dominant
chord-vertex($dominant, $tonic);
chord-vertex($dominant, $dominant-seventh, :probability(&end-of-phrase));
chord-vertex($dominant, $submediant);

# Dominant 7th
chord-vertex($dominant-seventh, $tonic);
chord-vertex($dominant, $tonic-sus4);

# Submediant
chord-vertex($submediant, $tonic);
chord-vertex($submediant, $subdominant);
chord-vertex($submediant, $supertonic);
chord-vertex($submediant, $dominant, :probability(&end-of-phrase));
chord-vertex($submediant, $dominant-seventh, :probability(&end-of-phrase));

#
# Arrangment curve
#

#! Container class for curve parameters
our class Curve {
    use Math::Curves;

    has Numeric @.curve-upper is rw = 0, 0;
    has Numeric @.curve-lower is rw = -12, -12;

    #! select a pair of pitch bounds from a context given a transition
    method contour(Numeric:D $t) {
        sort bézier($t.Rat, @!curve-upper.List), bézier($t.Rat, @!curve-lower.List)
    }

    #! Extends this curve from the end of another curve
    method extend-from(Curve $previous --> Curve) {
        Curve.new(
            :curve-upper($previous.curve-upper.tail, |@!curve-upper)
            :curve-lower($previous.curve-lower.tail, |@!curve-lower)
        )
    }
}

#! Factory sub for declaring curve pairs
our sub curve(@curve-upper, @curve-lower) {
    Curve.new(:@curve-upper, :@curve-lower)
}

our constant curve1 = curve [0, 40, 30, 20], [-12, -5, -12, -5];
our constant curve2 = curve [25, 30, 25, 20, 15], [-12, -24, -17];
our constant curve3 = curve [10, 15, 30, 45, 30], [-17, -12, -17];
our constant curve4 = curve [25, 30, 20, 7, 12], [-24, -17, -29];

#! Markov model container for curve parameters
our class CurveNode does Submarine::MusicEngine::Markov::Node[Curve] {

}

our $curve1 = CurveNode.new( :value(curve1) );
our $curve2 = CurveNode.new( :value(curve2) );
our $curve3 = CurveNode.new( :value(curve3) );
our $curve4 = CurveNode.new( :value(curve4) );

#! Helper sub for declaring Markov connections
sub curve-vertex(CurveNode $from, CurveNode $to) {
    $from.choices.push: Submarine::MusicEngine::Markov::Connection.new(:$from, :$to)
}

#
# Tie curves together
#
curve-vertex($curve1, $curve2);
curve-vertex($curve1, $curve4);

curve-vertex($curve2, $curve3);
curve-vertex($curve2, $curve1);

curve-vertex($curve3, $curve4);
curve-vertex($curve3, $curve2);

curve-vertex($curve4, $curve1);
curve-vertex($curve4, $curve3);