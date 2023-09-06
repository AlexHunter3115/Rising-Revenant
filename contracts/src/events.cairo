use dojo::world::{Context, IWorldDispatcherTrait};
use serde::Serde;
use array::{ArrayTrait, SpanTrait};
use starknet::ContractAddress;
use RealmsRisingRevenant::components::Position;
use RealmsRisingRevenant::components::WorldEvent;

fn emit(ctx: Context, name: felt252, values: Span<felt252>) {
    let mut keys = array::ArrayTrait::new();
    keys.append(name);
    ctx.world.emit(keys, values);
}


#[derive(Drop, Serde)]
struct SetWorldEvent {
   world_event: WorldEvent,
   position: Position
}
