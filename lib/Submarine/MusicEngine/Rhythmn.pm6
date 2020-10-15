unit module Submarine::MusicEngine::Rhythmn;
use ScaleVec;
use Submarine::MusicEngine::Markov;
use Submarine::Utils;

our class Pattern {
    has ScaleVec $.kernal = sv(0, );

    #! pattern-duration in beats from 0
    method iteration-duration() {
        $.kernal.repeat-interval
    }

    #! Infinite version of the pattern
    method sequence($start = 0 --> Seq) {
        ($!kernal.reflexive-step($start).floor.Int .. Inf).map( { $!kernal.step: $_ } )
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
    Pattern.new( :kernal(sv |@kernal) )
}

# Rhythmns
our constant hold = pattern(0, 3.5, 4); # Now with upbeat
our constant on-the-beat = pattern(0, 1, 2, 3);
our constant minum-triplet = pattern(0, 1 + 1/3, 2 + 2/3, 4);
our constant off-the-beat = pattern(0.5, 1.5, 2.5, 3.5, 4);
our constant quaver-pulse = pattern(0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 3.75, 4); # Now with upbeat
our constant semiquaver-pulse = pattern |(0..16).map( { $_ / 4 } );

#! Markov model container for rhythmn structures
our class RhythmnNode does Submarine::MusicEngine::Markov::Node[Pattern] {

    #! A synonym for the generic $.values attribute
    method rhythmn() {
        $!value
    }
}

#
# Create RhythmnNode wrappers
#

# Bass nodes
our $on-the-beat1 = RhythmnNode.new( :value(on-the-beat) );
our $on-the-beat2 = RhythmnNode.new( :value(on-the-beat) );
our $on-the-beat3 = RhythmnNode.new( :value(on-the-beat) );
our $off-the-beat = RhythmnNode.new( :value(off-the-beat) );
our $fast-bass = RhythmnNode.new( :value(quaver-pulse) );

# Arp nodes
our $pause = RhythmnNode.new( :value(hold) );
our $crotchet-pulse = RhythmnNode.new( :value(on-the-beat) );
our $three-four = RhythmnNode.new( :value(minum-triplet) );
our $quaver-pulse = RhythmnNode.new( :value(quaver-pulse) );
our $semiquaver-pulse = RhythmnNode.new( :value(semiquaver-pulse) );

#
# Tie Rhythmns together
#

# Helper sub for declaring Markov connections
sub rhythmn-vertex(RhythmnNode $from, RhythmnNode $to, :&probability = -> *@ { 1.0 }) {
    $from.choices.push: Submarine::MusicEngine::Markov::Connection.new(:$from, :$to, :&probability)
}

my &end-of-phrase = -> $beat-of-phrase, $ { ($beat-of-phrase < 28) ?? 0.0 !! 10.0 }

# Returns a callable around the given function combined with a form modulation
sub form-probability-combinator(Rat $form-wieght, &probability --> Callable) {
    -> *@args {
        probability(|@args)
        * ( 1 - abs($form-wieght - @args[1]) )
    }
}

# Probabilty for high quadrant of form
my &active = form-probability-combinator(0.8, -> *@ { 1.4 });
my &calm = form-probability-combinator(0.2, -> *@ { 1.4 });

# Bass network
rhythmn-vertex($on-the-beat1, $on-the-beat2);
rhythmn-vertex($on-the-beat2, $on-the-beat3);
rhythmn-vertex($on-the-beat3, $off-the-beat);
rhythmn-vertex($on-the-beat3, $fast-bass, :probability(&active));
rhythmn-vertex($off-the-beat, $on-the-beat1);
rhythmn-vertex($fast-bass, $on-the-beat1);


# Arp network
rhythmn-vertex($quaver-pulse, $semiquaver-pulse, :probability(&active));
rhythmn-vertex($quaver-pulse, $crotchet-pulse, :probability(&calm));
rhythmn-vertex($quaver-pulse, $pause, :probability(&end-of-phrase));
# rhythmn-vertex($quaver-pulse, $three-four);

# rhythmn-vertex($three-four, $pause);
# rhythmn-vertex($three-four, $semiquaver-pulse);

rhythmn-vertex($crotchet-pulse, $quaver-pulse);
rhythmn-vertex($crotchet-pulse, $pause, :probability(&end-of-phrase));

rhythmn-vertex($pause, $quaver-pulse);
rhythmn-vertex($pause, $semiquaver-pulse, :probability(&active));

rhythmn-vertex($semiquaver-pulse, $quaver-pulse);
rhythmn-vertex($semiquaver-pulse, $semiquaver-pulse, :probability(&active));