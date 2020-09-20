unit module Submarine::MusicEngine::Form;
use Submarine::MusicEngine::Markov;

# A routine for taking a melody and bass contour pair and returning the central point between given points
our sub curve-center(Numeric $a, Numeric $b) {
    (max($a, $b) - min($a, $b)) / 2
}


#! A curve class for providing modulation information
our class Modulator {
    use Math::Curves;

    #! Control points for the bezier function
    has Numeric @.curve = 0, 1, 0;

    #! For t (0..1) return a point on the curve from start to finish
    method contour(Numeric $t --> Numeric) {
        bézier($t.Rat, @!curve.List)
    }

    # Return a new modulator which continues the given curve with this curve
    method extend-from(Modulator $previous --> Modulator) {
        Modulator.new(
            :curve($previous.curve.tail, |@!curve)
        )
    }
}

our sub modulator(+@curve --> Modulator) {
    Modulator.new(:@curve)
}

our constant excited-mod = modulator 1.2, 1.8, 1;
our constant subdued-mod = modulator 0.9, 0.8, 0.6, 0.9, 1;

#! Applied Role for StateMachine with Modulators
our class ModulatorNode does Submarine::MusicEngine::Markov::Node[Modulator] {

}

our $high-mod = ModulatorNode.new( :value(excited-mod) );
our $low-mod = ModulatorNode.new( :value(subdued-mod) );


sub mod-vertex(ModulatorNode $from, ModulatorNode $to, :&probability = { 1.0 }) {
    $from.choices.push: Submarine::MusicEngine::Markov::Connection.new(:$from, :$to)
}

mod-vertex($high-mod, $low-mod);
mod-vertex($low-mod, $high-mod);