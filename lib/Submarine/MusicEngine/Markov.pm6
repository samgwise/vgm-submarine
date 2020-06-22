unit module Submarine::MusicEngine::Markov;
use Random::Choice;

our class Connection { ... };

#! Represents an element of the Markov chain
our role Node[::T] {
    has T $.value is required;
    has Connection @.choices;

    method pick-next(*@parameters --> Node) {
        return Node unless @!choices;
        @!choices[ choice :p(@!choices.map( { .probability.(|@parameters) } ).List) ].to
    }
}

our class Connection {
    has Node $.from is required;
    has Node $.to is required;
    has &.probability = { 1.0 };
}