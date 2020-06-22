unit module Submarine::MusicEngine::Harmony;
use ScaleVec;
use Submarine::MusicEngine::Markov;

#! ScaleVec declaration helper
our sub sv(*@vector --> ScaleVec) {
    ScaleVec.new(:@vector)
}

# Chords
constant tonic is export = sv(0, 2, 4, 7);
constant supertonic is export = tonic.transpose(1);
constant mediant is export = tonic.transpose(2);
constant subdominant is export = tonic.transpose(3);
constant dominant is export = tonic.transpose(4);
constant dominant-seventh is export = sv(7, 9, 11, 13, 14);
constant submediant is export = tonic.transpose(5);
constant leading-tone is export = tonic.transpose(6);

our class ChordNode does Submarine::MusicEngine::Markov::Node[ScaleVec] {

    #! A synonym for the generic $.values attribute
    method chord() {
        $!value
    }
}


# Create ChordNode wrappers
our $tonic = ChordNode.new( :value(tonic) );
our $supertonic = ChordNode.new( :value(supertonic) );
our $subdominant = ChordNode.new( :value(subdominant) );
our $dominant = ChordNode.new( :value(dominant) );
our $dominant-seventh = ChordNode.new( :value(dominant-seventh) );
our $submediant = ChordNode.new( :value(subdominant) );

#
# Tie chords together
#

sub chord-vertex(ChordNode $from, ChordNode $to) {
    $from.choices.push: Submarine::MusicEngine::Markov::Connection.new(:$from, :$to)
}

# Tonic
chord-vertex($tonic, $submediant);
chord-vertex($tonic, $subdominant);
chord-vertex($tonic, $supertonic);
chord-vertex($tonic, $dominant);
chord-vertex($tonic, $dominant-seventh);

# Supertonic
chord-vertex($supertonic, $dominant);
chord-vertex($supertonic, $dominant-seventh);

# Subdominant
chord-vertex($subdominant, $dominant);
chord-vertex($subdominant, $dominant-seventh);
chord-vertex($subdominant, $supertonic);
chord-vertex($subdominant, $tonic);

# Dominant
chord-vertex($dominant, $tonic);
chord-vertex($dominant, $dominant-seventh);
chord-vertex($dominant, $submediant);

# Dominant 7th
chord-vertex($dominant-seventh, $tonic);

# Submediant
chord-vertex($submediant, $tonic);
chord-vertex($submediant, $subdominant);
chord-vertex($submediant, $supertonic);
chord-vertex($submediant, $dominant);
chord-vertex($submediant, $dominant-seventh);