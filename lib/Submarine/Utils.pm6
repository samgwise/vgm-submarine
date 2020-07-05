unit module Submarine::Utils;

use ScaleVec;

#! ScaleVec declaration helper
our sub sv(*@vector --> ScaleVec) is export {
    ScaleVec.new(:@vector)
}

#! Returns a sequence of values with defined mappings between the given two points with a [..) relationship.
our sub defined-steps(ScaleVec $scale, Numeric $l, Numeric $r --> Seq) is export {
    my $range = ( ($l % $scale.repeat-interval), ($r % $scale.repeat-interval) );
    $scale.scale-pv.grep( { $_ >= $range.min and $_ < $range.max } )
}