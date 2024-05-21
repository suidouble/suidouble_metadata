module suidouble_metadata::metadata_property {
// just add a:
//     metadata: vector<u8>  property
// to any Struct you use, and you can add as many as you want properties into it with package upgrades
//
// use suidouble_metadata::metadata;  is not required, as it's just binary operations helper,
//  just add metadata: vector<u8> and use suidouble_metadata::metadata over it in the future if you need it there.

    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use suidouble_metadata::metadata;

    use sui::test_scenario as ts;
    use sui::test_utils as sui_tests;
    // use sui::event;

    public struct METADATA_PROPERTY has drop {} /// One-Time-Witness for the module.

    public struct SomeStore has key {
        id: UID,
        balance: Balance<SUI>,
        metadata: vector<u8>,   // just add a metadata vector<u8> in case for any possible package upgrade you may need
    }

    fun init(_otw: METADATA_PROPERTY, ctx: &mut TxContext) {
        let store = SomeStore {
            id: object::new(ctx),
            balance: balance::zero<SUI>(),
            metadata: vector::empty()
        };

        transfer::share_object(store);
    }

    // we had a simple function to do a purchase with fixed hard-coded price,
    // imagine we'd have a little pain in the bottom of the back if we'd need to have price as adjusted property on the next package upgrade?
    // with metadata module, there is no need to update function signature if you want to add new function and new properties to metadata:
    //
    // old function:
    // entry fun purchase_from(store: &mut SomeStore, coin: Coin<SUI>): bool {
    //     coin::put(&mut store.balance, coin); // we'd probably don't want to take money if we return false
    //     let sui_amount = coin::value(&coin);
    //     if (sui_amount < 1_000_000_000) {
    //         return false
    //     };
    //     // create some goods and send to tx_sender...
    //     true
    // }

    // is very compatible with updated logic:
    entry fun purchase_from(store: &mut SomeStore, coin: Coin<SUI>): bool {
        let price = metadata::get_u64(&store.metadata, metadata::key(&b"price"), 1_000_000_000); // 1_000_000_000 - default
        let sui_amount = coin::value(&coin);
        coin::put(&mut store.balance, coin); // we'd probably don't want to take money if we return false
        if (sui_amount < price) {
            return false
        };

        // create some goods and send to tx_sender...
        true
    }

    // and new function just updates metadata, no need for new structs
    entry fun adjust_price(store: &mut SomeStore, new_price: u64) {
        metadata::set(&mut store.metadata, metadata::key(&b"price"), &new_price);
    }



    const TEST_SENDER_ADDR: address = @0x1;

    #[test]
    fun test_contract() {
        let mut scenario = ts::begin(TEST_SENDER_ADDR);
        init(sui_tests::create_one_time_witness<METADATA_PROPERTY>(), ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, TEST_SENDER_ADDR);

        let mut store: SomeStore = ts::take_shared(&scenario);
        adjust_price(&mut store, 2_000_000_000);

        let coin1 = coin::mint_for_testing<SUI>(1_500_000_000 , ts::ctx(&mut scenario));
        let purchased = purchase_from(&mut store, coin1);

        assert!(purchased == false, 0);  // as 1_500_000_000 < 2_000_000_000 we set with adjust_price

        let coin2 = coin::mint_for_testing<SUI>(2_500_000_000 , ts::ctx(&mut scenario));
        let purchased2 = purchase_from(&mut store, coin2);

        assert!(purchased2 == true, 0);

        ts::return_shared(store);
        ts::next_tx(&mut scenario, TEST_SENDER_ADDR);
        ts::end(scenario);
    }

}