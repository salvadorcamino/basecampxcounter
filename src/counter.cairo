#[starknet::interface]
pub trait ICounter <T> {
    fn get_counter(self: @T) -> u32;
    fn increase_counter(ref self: T); 
}


#[starknet::contract]
pub mod counter_contract {
    use kill_switch::{IKillSwitchDispatcher, IKillSwitchDispatcherTrait};
    use starknet::event::EventEmitter;
    use workshop::counter::ICounter;
    use starknet::ContractAddress;
    use openzeppelin::access::ownable::OwnableComponent;


    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);


    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;



    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }



    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u32, kill_switch: ContractAddress, initial_owner: ContractAddress) {
        self.counter.write(initial_value);
        self.kill_switch.write(kill_switch);
        self.ownable.initializer(initial_owner);
    }

    

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        #[key]
        pub value : u32,
    }


    #[abi(embed_v0)]
    impl CounterImpl of ICounter<ContractState>{
        
        fn get_counter(self: @ContractState) -> u32{
            self.counter.read()
        }
        
        fn increase_counter(ref self: ContractState){

            self.ownable.assert_only_owner();

            let is_active: bool = IKillSwitchDispatcher {
                contract_address: self.kill_switch.read()
            }
            .is_active();
            assert!(!is_active, "Kill Switch is active");

            // Increment counter
            let current_value: u32 = self.counter.read();
            self.counter.write(current_value + 1);

            // Emit event for counter increment
            self.emit(Event::CounterIncreased(CounterIncreased { value: self.counter.read() }));
            
        }
    }

}
