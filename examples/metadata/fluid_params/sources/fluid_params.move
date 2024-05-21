module suidouble_metadata::fluid_params {
// smart contract showing pattern of passing multiple parameters for a function in a single metadata argument
// you may build your own logic, make some params required (aborting if they are undefined), support multiple data types etc
//   take a look at set(..) method and unit test below for inspiration

    use suidouble_metadata::metadata;

    use sui::test_scenario as ts;
    use sui::test_utils as sui_tests;
    // use sui::event;

    public struct FLUID_PARAMS has drop {} /// One-Time-Witness for the module.

    public struct Person has key {
        id: UID,
        age: u64,
        female: bool, // false - male, true - female
        name: vector<u8>,
        sui_address: address,
    }

    fun init(_otw: FLUID_PARAMS, ctx: &mut TxContext) {
        let person = Person {
            id: object::new(ctx),
            age: 18,
            female: false,
            sui_address: @0xABBA,
            name: b""
        };

        transfer::share_object(person);
    }

    public entry fun set(person: &mut Person, params: &vector<u8>, _ctx: &mut TxContext) {
        if (metadata::has_chunk_of_type<u64>(params, metadata::key(&b"age"))) {
            person.age = metadata::get_u64(params, metadata::key(&b"age"), 0); // 0 - default
        } else if (metadata::has_chunk_of_type<u8>(params, metadata::key(&b"age"))) { // just a helper so you can pass age as u8 too
            person.age = (metadata::get_u8(params, metadata::key(&b"age"), 0) as u64); // 0 - default
        };

        if (metadata::has_chunk_of_type<bool>(params, metadata::key(&b"female"))) {
            person.female = metadata::get_bool(params, metadata::key(&b"female"), false); // false - default
        };
        if (metadata::has_chunk_of_type<address>(params, metadata::key(&b"sui_address"))) {
            person.sui_address = metadata::get_address(params, metadata::key(&b"sui_address"), @0xABBA); // 0 - default
        };
        if (metadata::has_chunk_of_type<vector<u8>>(params, metadata::key(&b"name"))) {
            person.name = metadata::get_vec_u8(params, metadata::key(&b"name"));
        };
    }

    const TEST_SENDER_ADDR: address = @0x1;

    #[test]
    fun test_contract() {
        let mut scenario = ts::begin(TEST_SENDER_ADDR);
        init(sui_tests::create_one_time_witness<FLUID_PARAMS>(), ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, TEST_SENDER_ADDR);

        let mut person: Person = ts::take_shared(&scenario);

        // update its field passing params as single metadata object
        let mut params:vector<u8> = vector::empty();
        metadata::set(&mut params, metadata::key(&b"female"), &true);
        metadata::set(&mut params, metadata::key(&b"age"), &(93 as u64));
        metadata::set(&mut params, metadata::key(&b"sui_address"), &@0xBBBAAA);
        metadata::set(&mut params, metadata::key(&b"name"), &b"Master of Karate");
        set(&mut person, &params, ts::ctx(&mut scenario));

        // assert properties set correctly
        assert!(person.age == 93, 0);
        assert!(person.female == true, 0);
        assert!(person.sui_address == @0xBBBAAA, 0);
        assert!(person.name == b"Master of Karate", 0);

        // try with skipped fields, test that set() method accept age as u8 too
        let mut params:vector<u8> = vector::empty();
        metadata::set(&mut params, metadata::key(&b"age"), &(17 as u8));
        set(&mut person, &params, ts::ctx(&mut scenario));

        // age updated, other fields are same
        assert!(person.age == 17, 0);
        assert!(person.female == true, 0);
        assert!(person.sui_address == @0xBBBAAA, 0);
        assert!(person.name == b"Master of Karate", 0);

        // others are just ignored
        metadata::set(&mut params, metadata::key(&b"kakaha"), &(17 as u64));
        // as long as needed name, but wrong type
        metadata::set(&mut params, metadata::key(&b"sui_address"), &(99 as u64));
        set(&mut person, &params, ts::ctx(&mut scenario));

        // still same
        assert!(person.age == 17, 0);
        assert!(person.female == true, 0);
        assert!(person.sui_address == @0xBBBAAA, 0);
        assert!(person.name == b"Master of Karate", 0);

        ts::return_shared(person);
        ts::next_tx(&mut scenario, TEST_SENDER_ADDR);
        ts::end(scenario);
    }

}