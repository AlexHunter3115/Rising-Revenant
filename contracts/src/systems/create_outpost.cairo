#[system]
mod create_outpost {
    use array::ArrayTrait;
    use box::BoxTrait;
    use traits::Into;
    use dojo::world::Context;

    use RealmsRisingRevenant::components::Position;
    use RealmsRisingRevenant::components::Lifes;
    use RealmsRisingRevenant::components::Defence;
    use RealmsRisingRevenant::components::Name;
    use RealmsRisingRevenant::components::Prosperity;
    use RealmsRisingRevenant::components::Game;
    use RealmsRisingRevenant::components::Ownership;
    use RealmsRisingRevenant::utils::random::{Random, RandomImpl};

    use RealmsRisingRevenant::components::GameEntityCounter;

    // this will create a newoutpostat random coordinates
    // TODO: Add Lords Deposit
    fn execute(ctx: Context, game_id: u32) -> u128 {
        
        let mut game = get !(ctx.world, game_id, Game);

        let mut gameData = get !(
            ctx.world, game_id, GameEntityCounter
        ); 

        assert(game.status, 'game is not running');
        // check if the game has started

        gameData.outpost_count += 1;

        let mut outpost_count:u128 = gameData.outpost_count;

        let mut entity_id: u128 = outpost_count;

        // We set the lifes of the outpost
        let mut lifes = Lifes { entity_id, game_id, count: 5 };

        // We set the defence of the outpost
        let mut defence = Defence { entity_id, game_id, plague: 1 };

        // We set the name of the outpost
        let mut name = Name { entity_id, game_id, value: 'Settlement'.into() };

        // We set a random prosperity for the outpost
        let mut prosperity = Prosperity { entity_id, game_id, value: 1000 };

        // // // We set the position of the outpost
        let seed = starknet::get_tx_info().unbox().transaction_hash;
        let mut random = RandomImpl::new(seed);
        let x = random.next_u32(0, 100);
        let y = random.next_u32(0, 100);
        let mut position = Position { entity_id, game_id, x, y };

        // We set the ownership of theoutpostto the player who created it
        let mut ownership = Ownership { entity_id, game_id, address: ctx.origin.into() };

        set !(
            ctx.world,
            (lifes, defence, name, prosperity, position, ownership, gameData)
        );

        entity_id
    }
}



