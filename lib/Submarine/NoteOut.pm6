unit module Submarine::NoteOut;

our role OscSender {
    has $.socket  = IO::Socket::Async.udp;
    has @.targets = ('127.0.0.1', '5635'), ;

    has Supplier $.record .= new;

    method send-note(Str $name, Int(Cool) $note, Int(Cool) $velocity, Int(Cool) $duration, Instant :$at) { ... }
}

our class OscSender::PD does OscSender {
    use Net::OSC::Message;

    #! send a note message to targets
    method send-note(Str $name, Int(Cool) $note, Int(Cool) $velocity, Int(Cool) $duration, Instant :$at) {
        $!record.emit: "$name, { $at ?? $at.Rat.nude !! now.Rat.nude }, $note, $velocity, $duration";

        my Net::OSC::Message $msg .= new(
            :path("/play-out/$name/note")
            :args($note, $velocity, $duration)
            :is64bit(False)
        );

        if $at {
            Promise.at($at).then: {
                $!socket.write-to($_[0], $_[1], $msg.package) for @!targets
            }
        }
        else {
            $!socket.write-to($_[0], $_[1], $msg.package) for @!targets
        }
    }
}

our class OscSender::MidiSender does OscSender {
    constant nanosecond = 1_000_000_000;
    constant millisecond = 1_000;
    use Net::OSC::Message;
    use Net::OSC::Types;

    has %.channel-map is required;
    has Proc::Async $.midi-sender;
    has Instant $!sync;

    submethod TWEAK() {
        # Trigger sync op and set internal sync time
        $!socket.write-to($_[0], $_[1], osc-message('/midi_sender/sync').package) for @!targets;
        $!sync = now;
    }

    #! send a note message to targets
    method send-note(Str $name, Int(Cool) $note, Int(Cool) $velocity, Int(Cool) $duration, Instant :$at) {
        $!record.emit: "$name, { $at ?? $at.Rat.nude !! now.Rat.nude }, $note, $velocity, $duration";

        # say "Sending to midi channel: %!channel-map{$name} for name $name";

        my $nanosecond-at = Int( ($at.defined ?? $at - $!sync !! now - $!sync).Rat * nanosecond );
        my Net::OSC::Message $msg .= new(
            :path("/midi_sender/play")
            :args(osc-int64($nanosecond-at), osc-int64( $nanosecond-at + Int(($duration / millisecond) * nanosecond) ), osc-int32(%!channel-map{$name}), $note, $velocity)
        );

        $!socket.write-to($_[0], $_[1], $msg.package) for @!targets
    }

    #! Extended behaviour to send a cancel message for a specific note for all targets.
    method cancel-note(Str $name, Int(Cool) $note, Instant :$at) {
        my $nanosecond-at = Int( ($at.defined ?? $at - $!sync !! now - $!sync).Rat * nanosecond );
        $!socket.write-to(
            $_[0], $_[1],
            osc-message( '/midi_sender/cancel',
                osc-int64($nanosecond-at),
                osc-int32(%!channel-map{$name}),
                $note
            ).package,
        ) for @!targets;
    }
}