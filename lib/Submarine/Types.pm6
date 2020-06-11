unit module Submarine::Types;

# Game State representation
our enum Player is export <Active Paused>;
our enum GameState is export <Danger Damaged Safe Oxygen>;
our enum Environment is export <DropPod SafeReef Kelp RedWeed DropOff>;
our enum EnvMod is export <Underwater Surface Base Vehicle>;

#! A class for holding the state of the game
our class CurrentState is export {
    has Player:D $.player = Player::Active;
    has GameState:D $.game-state = GameState::Safe;
    has Environment:D $.environment = Environment::DropPod;
    has EnvMod:D $.env-mod = EnvMod::Vehicle;

    #
    # State transformations
    #
    method transform-player(Player:D $player --> CurrentState) {
        self.clone(:$player)
    }

    method transform-game-state(GameState:D $game-state --> CurrentState) {
        self.clone(:$game-state)
    }

    method transform-environment(Environment:D $environment --> CurrentState) {
        self.clone(:$environment)
    }

    method transform-env-mod(EnvMod:D $env-mod --> CurrentState) {
        self.clone(:$env-mod)
    }
}