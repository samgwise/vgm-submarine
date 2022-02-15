NAME
====

VGM::Submarine - A prototype dynamic soundtrack for Subnautica

SYNOPSIS
========

    raku -Ilib bin/submarine.raku --midi-sender="./utils/midi_sender.exe" ./res/clip1

DESCRIPTION
===========

VGM::Submarine is a prototype dynamic soundtrack for the game Subnautica by Unknown Worlds Entertainment. I created this soundtrack as part of the research presented in my thesis: _Applying Transformational Music Theory to Dynamic Music Composition for Game Soundtracks: A practice-based investigation_

The prototype is written in _Raku_, see the https://rakudo.org/ site for more information on setting up with a _Raku_ interpreter.

It is recommended to use the midi_sender backend when running this (as shown in the synopsis example), see the midi_sender repo for more details: https://github.com/samgwise/midi_sender

This prototype is designed to follow playback from _Reaper_ (https://www.reaper.fm/). _Reaper_ allows for hosting virtual instruments and video playback which is useful for rendering the soundtrack and playing sample game-play footage. This prototype depends on _Reaper_'s OSC remote interface (https://www.reaper.fm/sdk/osc/osc.php).

See the `./res` folder for example event files.

AUTHOR
======

Sam Gillespie <samgwise@gmail.com>

COPYRIGHT AND LICENSE
=====================

Copyright 2020 Sam Gillespie

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.
