unit module Submarine::MusicEngine::Rhythmn;
use ScaleVec;
use Submarine::MusicEngine::Markov;

#! ScaleVec declaration helper
our sub sv(*@vector --> ScaleVec) {
    ScaleVec.new(:@vector)
}

# Rhythmns
our constant on-the-beat = sv(0, 1, 2, 3);
our constant off-the-beat = sv(0.5, 1.5, 2.5, 3.5);

#! Markov model container for rhythmn structures
our class RhythmnNode does Submarine::MusicEngine::Markov::Node[ScaleVec] {

    #! A synonym for the generic $.values attribute
    method rhythmn() {
        $!value
    }
}

# Create RhythmnNode wrappers
our $on-the-beat1 = RhythmnNode.new( :value(on-the-beat) );
our $on-the-beat2 = RhythmnNode.new( :value(on-the-beat) );
our $on-the-beat3 = RhythmnNode.new( :value(on-the-beat) );
our $off-the-beat = RhythmnNode.new( :value(off-the-beat) );

#
# Tie Rhythmns together
#

# Helper sub for declaring Markov connections
sub rhythmn-vertex(RhythmnNode $from, RhythmnNode $to) {
    $from.choices.push: Submarine::MusicEngine::Markov::Connection.new(:$from, :$to)
}

rhythmn-vertex($on-the-beat1, $on-the-beat2);
rhythmn-vertex($on-the-beat2, $on-the-beat3);
rhythmn-vertex($on-the-beat3, $off-the-beat);
rhythmn-vertex($off-the-beat, $on-the-beat1);