#[cfg(test)]
mod tests {
    use array::ArrayTrait;
    use option::OptionTrait;
    use box::BoxTrait;
    use clone::Clone;
    use debug::PrintTrait;
    use traits::{TryInto, Into};

    use starknet::{ContractAddress, syscalls::deploy_syscall};

    use dojo::world::{IWorldDispatcherTrait, IWorldDispatcher};

    use dojo::test_utils::spawn_test_world;

    // components
    use RealmsRisingRevenant::components::{game, Game};
    use RealmsRisingRevenant::components::{game_tracker, GameTracker};
    use RealmsRisingRevenant::components::outpost::{
        outpost, Outpost, OutpostStatus, OutpostImpl, OutpostTrait
    };
    use RealmsRisingRevenant::components::revenant::{
        revenant, Revenant, RevenantStatus, RevenantImpl, RevenantTrait
    };
    use RealmsRisingRevenant::components::world_event::{world_event, WorldEvent};

    use RealmsRisingRevenant::constants::{EVENT_INIT_RADIUS, OUTPOST_INIT_LIFE};
    // systems
    use RealmsRisingRevenant::systems::create::create_game;
    use RealmsRisingRevenant::systems::create_revenant::create_revenant;
    use RealmsRisingRevenant::systems::purchase_reinforcement::purchase_reinforcement;
    use RealmsRisingRevenant::systems::reinforce_outpost::reinforce_outpost;
    use RealmsRisingRevenant::systems::set_world_event::set_world_event;
    use RealmsRisingRevenant::systems::destroy_outpost::destroy_outpost;

    const EVENT_BLOCK_INTERVAL: u64 = 3;
    const PREPARE_PHRASE_INTERVAL: u64 = 10;

    fn mock_game() -> (IWorldDispatcher, u32, felt252) {
        let caller = starknet::contract_address_const::<0x0>();

        // components
        let mut components = array![
            game::TEST_CLASS_HASH,
            game_tracker::TEST_CLASS_HASH,
            outpost::TEST_CLASS_HASH,
            revenant::TEST_CLASS_HASH,
            world_event::TEST_CLASS_HASH
        ];

        // systems
        let mut systems = array![
            create_game::TEST_CLASS_HASH,
            create_revenant::TEST_CLASS_HASH,
            purchase_reinforcement::TEST_CLASS_HASH,
            reinforce_outpost::TEST_CLASS_HASH,
            set_world_event::TEST_CLASS_HASH,
            destroy_outpost::TEST_CLASS_HASH
        ];

        // deploy executor, world and register components/systems
        let world = spawn_test_world(components, systems);

        let calldata = array![PREPARE_PHRASE_INTERVAL.into(), EVENT_BLOCK_INTERVAL.into()];
        let mut res = world.execute('create_game'.into(), calldata);
        let game_id = serde::Serde::<u32>::deserialize(ref res)
            .expect('spawn deserialization failed');
        assert(game_id == 1, 'game id incorrect');

        (world, game_id, caller.into())
    }

    fn create_starter_revenant() -> (IWorldDispatcher, u32, felt252, u128, u128) {
        let (world, game_id, caller) = mock_game();

        let mut array = array![
            game_id.into(), 5937281861773520500
        ]; // 5937281861773520500 => 'Revenant'
        let mut res = world.execute('create_revenant'.into(), array);
        let (revenant_id, outpost_id) = serde::Serde::<(u128, u128)>::deserialize(ref res)
            .expect('id deserialization fail');

        (world, game_id, caller, revenant_id, outpost_id)
    }

    #[test]
    #[available_gas(30000000)]
    fn test_create_game() {
        let (world, _, _) = mock_game();
    }

    #[test]
    #[available_gas(3000000000)]
    fn test_create_revenant() {
        let (world, game_id, caller, revenant_id, outpost_id) = create_starter_revenant();
    }

    #[test]
    #[available_gas(3000000000)]
    fn test_reinforce_outpost() {
        let (world, game_id, caller, revenant_id, outpost_id) = create_starter_revenant();
        let mut purchase_event = world
            .execute('purchase_reinforcement'.into(), array![game_id.into(), 10]);
        let purchase_result = serde::Serde::<bool>::deserialize(ref purchase_event)
            .expect('Purchase d fail');
        assert(purchase_result == true, 'Failed to purchase');

        starknet::testing::set_block_number(PREPARE_PHRASE_INTERVAL + 1);

        let reinforce_array = array![outpost_id.into(), game_id.into()];
        world.execute('reinforce_outpost'.into(), reinforce_array);

        let g_id: felt252 = game_id.into();
        let s_id: felt252 = outpost_id.into();
        let compound_key_array = array![s_id, g_id];

        // assert plague value increased
        let outpost = world
            .entity(
                'Outpost'.into(), compound_key_array.span(), 0, dojo::SerdeLen::<Outpost>::len()
            );
        assert(*outpost[4] == 6, 'life value is wrong');
    }

    #[test]
    #[available_gas(3000000000)]
    fn test_set_world_event() {
        let (world, game_id, _, _, _) = create_starter_revenant();
        starknet::testing::set_block_number(PREPARE_PHRASE_INTERVAL + 1);
        let mut event = world.execute('set_world_event'.into(), array![game_id.into()]);
        let world_event = serde::Serde::<WorldEvent>::deserialize(ref event)
            .expect('Event deserialization fail');

        assert(world_event.radius == EVENT_INIT_RADIUS, 'event radius is wrong');
    }

    #[test]
    #[available_gas(3000000000)]
    fn test_destroy_outpost() {
        let (world, game_id, caller, revenant_id, outpost_id) = create_starter_revenant();
        let mut block_number = PREPARE_PHRASE_INTERVAL + 1;
        starknet::testing::set_block_number(block_number);
        let mut event = world.execute('set_world_event'.into(), array![game_id.into()]);
        let world_event = serde::Serde::<WorldEvent>::deserialize(ref event)
            .expect('W event deserialization fail');
        let mut result = world
            .execute(
                'destroy_outpost'.into(),
                array![outpost_id.into(), game_id.into(), world_event.entity_id.into()]
            );

        let destoryed = serde::Serde::<bool>::deserialize(ref result)
            .expect('destory deserialization fail');

        let g_id: felt252 = game_id.into();
        let s_id: felt252 = outpost_id.into();
        let compound_key_array = array![s_id, g_id];

        // assert plague value decreased
        let outpost = world
            .entity(
                'Outpost'.into(), compound_key_array.span(), 0, dojo::SerdeLen::<Outpost>::len()
            );

        if destoryed {
            assert(*outpost[4] == (OUTPOST_INIT_LIFE - 1).into(), 'life value is wrong');
        } else {
            assert(*outpost[4] == OUTPOST_INIT_LIFE.into(), 'life value is wrong');
        }

        block_number += EVENT_BLOCK_INTERVAL + 1;
        starknet::testing::set_block_number(block_number);
        // Check the next world event's radius
        let mut event2 = world.execute('set_world_event'.into(), array![game_id.into()]);
        let world_event2 = serde::Serde::<WorldEvent>::deserialize(ref event2)
            .expect('W event deserialization fail');
        if destoryed {
            assert(world_event2.radius == EVENT_INIT_RADIUS, 'radius value is wrong');
        } else {
            assert(world_event2.radius == EVENT_INIT_RADIUS + 1, 'radius value is wrong');
        }
    }
}
