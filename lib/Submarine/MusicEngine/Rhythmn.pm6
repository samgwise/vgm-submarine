unit module Submarine::MusicEngine::Rhythmn;
use ScaleVec;
use Submarine::MusicEngine::Markov;
use Submarine::Utils;

our class Pattern {
    has List $.kernal = $(0, );

    #! pattern-duration in beats from 0
    method iteration-duration() {
        $.kernal[*-1]
    }

    #! Infinite cersion of the pattern
    method sequence($start = 0 --> Seq) {
        my $kernal-length = $!kernal.elems;
        ($start.floor..Inf).map( { $!kernal[$_ mod $kernal-length] * ($_ / $kernal-length).floor } )
    }

    #! returns sub sequence of elements within a given range
    method sub-sequence(Numeric $l, Numeric $r --> Seq) {
        return Seq unless $l < $r;
        gather for self.sequence($l).grep( { $_ >= $l } ) {
            last if $_ >= $r;
            take $_
        }
    }
}

sub pattern(+@kernal) {
    Pattern.new( :@kernal )
}

# Rhythmns
our constant on-the-beat = pattern(0, 1, 2, 3);
our constant off-the-beat = pattern(0.5, 1.5, 2.5, 3.5);
our constant quaver-pulse = pattern(0, 0.5, 1, 1.5, 2, 2.5, 3);

#! Markov model container for rhythmn structures
our class RhythmnNode does Submarine::MusicEngine::Markov::Node[Pattern] {

    #! A synonym for the generic $.values attribute
    method rhythmn() {
        $!value
    }
}

# Create RhythmnNode wrappers
our $on-the-beat1 = RhythmnNode.new( :value(quaver-pulse) );
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