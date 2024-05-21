
module suidouble_metadata::compressed_on_chain {
// creates a simple CompressedStore object, with metadata vector<u8>, which can hold any values,
//  and may be compressed with suidouble_metadata::compress module
//  for simplicity here, we make it to operate with metadata's get_u256 and get_vec_8 function, but feel free to use others 
//  works ok and do 2x compression for a test metadata in the unit test here
//  
//  set items to metadata with:
//         set_metadata_string and get_metadata_u256
//  get metadata items with
//         get_metadata_chunk and get_metadata_u256
//  compress metadata to reduce it's byte length with
//         compress_metadata
//
//  take a look at the unit test at the bottom of this module

    use suidouble_metadata::metadata;
    // use suidouble_metadata::compress;  // - has ::compress() and ::decompress() methods too if you need it wihtout metadata module
    use std::string::{utf8};
    use std::debug;

    use sui::test_scenario as ts;
    use sui::test_utils as sui_tests;
    // use sui::event;

    public struct COMPRESSED_ON_CHAIN has drop {} /// One-Time-Witness for the module.

    public struct CompressedStore has key {
        id: UID,
        metadata: vector<u8>,
        compressed: bool
    }

    fun init(_otw: COMPRESSED_ON_CHAIN, ctx: &mut TxContext) {
        let compressed_store = CompressedStore {
            id: object::new(ctx),
            metadata: vector::empty(),
            compressed: false
        };

        transfer::share_object(compressed_store);
    }

    fun get_metadata_chunk(compressed_store: &CompressedStore, key: vector<u8>): vector<u8> {
        let metadata = get_metadata(compressed_store); // lazy get it decompressed

        metadata::get_vec_u8(&metadata, metadata::key(&key))
    }

    fun get_metadata_u256(compressed_store: &CompressedStore, key: vector<u8>): u256 {
        let metadata = get_metadata(compressed_store); // lazy get it decompressed

        metadata::get_u256(&metadata, metadata::key(&key), 0) // default = 0
    }

    fun get_metadata(compressed_store: &CompressedStore): vector<u8> {
        if (compressed_store.compressed) {
            // return decompressed
            return metadata::decompress(&compressed_store.metadata)
        } else {
            return compressed_store.metadata
        }
    }

    entry fun set_metadata_u256(compressed_store: &mut CompressedStore, key: vector<u8>, value: u256, _ctx: &mut TxContext) {
        if (compressed_store.compressed) {
            // you can not directly use compressed for metadata manupulation. You have to decompress it first
            let mut decompressed = get_metadata(compressed_store);
            metadata::set(&mut decompressed, metadata::key(&key), &value);
            compressed_store.compressed = false;
            compressed_store.metadata = decompressed; 
            // you can compress it here. Though it's expensive to do each time
        } else {
            metadata::set(&mut compressed_store.metadata, metadata::key(&key), &value);
        }
    }

    entry fun set_metadata_string(compressed_store: &mut CompressedStore, key: vector<u8>, value: vector<u8>, _ctx: &mut TxContext) {
        if (compressed_store.compressed) {
            // you can not directly use compressed for metadata manupulation. You have to decompress it first
            let mut decompressed = get_metadata(compressed_store);
            metadata::set(&mut decompressed, metadata::key(&key), &value);
            compressed_store.compressed = false;
            compressed_store.metadata = decompressed; 
            // you can compress it here. Though it's expensive to do each time
        } else {
            metadata::set(&mut compressed_store.metadata, metadata::key(&key), &value);
        }
    }

    entry fun compress_metadata(compressed_store: &mut CompressedStore, _ctx: &mut TxContext) {
        if (compressed_store.compressed == false) {
            // let had_byte_length = vector::length(&compressed_store.metadata);
            let compressed = metadata::compress(&compressed_store.metadata);
            // let compressed_byte_length = vector::length(&compressed);

            compressed_store.metadata = compressed;
            compressed_store.compressed = true;
        }
    }

    const TEST_SENDER_ADDR: address = @0x1;

    #[test]
    fun test_contract() {
        let mut scenario = ts::begin(TEST_SENDER_ADDR);
        init(sui_tests::create_one_time_witness<COMPRESSED_ON_CHAIN>(), ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, TEST_SENDER_ADDR);

        let mut store: CompressedStore = ts::take_shared(&scenario);
        set_metadata_string(&mut store, b"test1", b"value", ts::ctx(&mut scenario));
        set_metadata_u256(&mut store, b"u256", 777, ts::ctx(&mut scenario)); // just so you know any primitive type work
        set_metadata_string(&mut store, b"test2", b"value maybe different", ts::ctx(&mut scenario));
        set_metadata_string(&mut store, b"test3", b"value maybe anything", ts::ctx(&mut scenario));
        set_metadata_string(&mut store, b"test4", b"value", ts::ctx(&mut scenario));
        set_metadata_string(&mut store, b"test5", b"value", ts::ctx(&mut scenario));

        let mut  i = 0;
        while (i < 100) {
            // just filling it with some repeative values, so expect it to be compressed ok
            set_metadata_string(&mut store, vector[i], b"value", ts::ctx(&mut scenario));
            i = i + 1;
        };

        let metadata_size_with_values = vector::length(&store.metadata);

        compress_metadata(&mut store, ts::ctx(&mut scenario));

        let metadata_size_compressed = vector::length(&store.metadata);

        debug::print(&utf8(b"raw metadata size:"));
        debug::print(&metadata_size_with_values);
        debug::print(&utf8(b"compressed metadata size:"));
        debug::print(&metadata_size_compressed);

        assert!(metadata_size_compressed < metadata_size_with_values, 0);
        ts::next_tx(&mut scenario, TEST_SENDER_ADDR);

        // can set again
        set_metadata_string(&mut store, b"test1", b"other value", ts::ctx(&mut scenario));
        // should be decompressed and be larger now    
        let metadata_size_decompressed = vector::length(&store.metadata);


        assert!(metadata_size_decompressed > metadata_size_compressed, 0);

        // original metadata values are still there:
        let value_from_metadata = get_metadata_chunk(&store, b"test2");
        assert!(value_from_metadata == b"value maybe different", 0);

        let u256_from_metadata = get_metadata_u256(&store, b"u256");
        assert!(u256_from_metadata == 777, 0);

        ts::return_shared(store);
        ts::next_tx(&mut scenario, TEST_SENDER_ADDR);
        ts::end(scenario);
    }

}