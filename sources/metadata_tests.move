
#[test_only]
module suidouble_metadata::metadata_tests {

    // use sui::test_scenario as ts;
    // use sui::transfer;
    use suidouble_metadata::metadata;
    use std::vector;
    use std::option;
    // use std::debug;

    // use sui::bcs;
    // use std::string;

    #[test]
    fun test_key_hash() {

        assert!(  metadata::key(&b"") == metadata::key(&b"")  , 0);
        assert!( b"" == metadata::unpack_key( metadata::key(&b"") ) , 0);

        assert!(  metadata::key(&b"a") == metadata::key(&b"a")  , 0);
        assert!(  metadata::key(&b"aaaa") == metadata::key(&b"aaaa")  , 0);

        // key hash function is case-insensitive
        assert!(  metadata::key(&b"aaaa") == metadata::key(&b"aAAa")  , 0);
        assert!(  metadata::key(&b"AAAA") == metadata::key(&b"aAAa")  , 0);
        assert!(  metadata::key(&b"Z872") == metadata::key(&b"z872")  , 0);

        // any string length is supported ( though only first chars generates 100% unique u32 )
        assert!(  metadata::key(&b"test_long_string") == metadata::key(&b"test_long_string")  , 0);
        // long part is case-insensitive too
        assert!(  metadata::key(&b"test_long_string") == metadata::key(&b"test_long_STRING")  , 0);
        // still, it works in a hash-like way, taking all chars into account:
        assert!(  metadata::key(&b"test_long_string1") != metadata::key(&b"test_long_string2")  , 0);
        assert!(  metadata::key(&b"test_long_stringK") != metadata::key(&b"test_long_stringU")  , 0);
        // may generate same hash with long strings though:  !!!!!  it's only u32, so
        assert!(  metadata::key(&b"test_long_string01") == metadata::key(&b"test_long_string10")  , 0);

        // u32 hash may be decoded back to string:   
        assert!( b"TEST" == metadata::unpack_key( metadata::key(&b"TEST") ) , 0);
        assert!( b"TEST" == metadata::unpack_key( metadata::key(&b"test") ) , 0);
        assert!( b"H1" == metadata::unpack_key( metadata::key(&b"h1") ) , 0);
        assert!( b" " == metadata::unpack_key( metadata::key(&b" ") ) , 0);
        assert!( b"! !" == metadata::unpack_key( metadata::key(&b"! !") ) , 0);

        // adds extra hash to the end of unpacked vector:
        // debug::print(&string::utf8(metadata::unpack_key( metadata::key(&b"test_long_string01") )));
        assert!( b"TEST*197" == metadata::unpack_key( metadata::key(&b"TEST_long_string") ) , 0);
        assert!( b"TEST*023" == metadata::unpack_key( metadata::key(&b"TEST_other_string") ) , 0);
        assert!( b"TEST*033" == metadata::unpack_key( metadata::key(&b"TEST!") ) , 0);

        // note, it may unpack to the same string, even though long part of the string was different ( it's only u32, sorry )
        assert!( b"TEST*038" == metadata::unpack_key( metadata::key(&b"test_long_string01") ) , 0);
        assert!( b"TEST*038" == metadata::unpack_key( metadata::key(&b"test_long_string10") ) , 0);

        // so you can use strings as keys for metadata chunks:
        let metadata: vector<u8> = vector[];
        metadata::set(&mut metadata, metadata::key(&b"test"), &(5 as u64));
        metadata::set(&mut metadata, metadata::key(&b"abba"), &(6 as u64));
        metadata::set(&mut metadata, metadata::key(&b"someproperty"), &(6 as u64));
        metadata::set(&mut metadata, metadata::key(&b"cmon!cmon!ccccccmoon"), &(3 as u8));

        assert!(metadata::get_chunks_count(&metadata) == 4, 0);

        metadata::set(&mut metadata, metadata::key(&b"someproperty"), &(6 as u64));  // same id

        assert!(metadata::get_chunks_count(&metadata) == 4, 0);

        // executed ok, but tooooooo slow
        // uncomment and run with 
        //     sui move test --gas-limit 50000000000000   
        // to check it yourself
        // please feel free to rewrite this test optimized

        // let twiced_hashes = 0;
        // let total_hashes = 0;

        // let i1: u8 = 48;
        // let i2: u8 = 48;
        // let i3: u8 = 48;
        // let i4: u8 = 48;
        // while (i1 <= 90) {
        //     i2 = 48;
        //     while (i2 <= 90) {
        //         i3 = 48;
        //         while (i3 <= 90) {
        //             i4 = 48;
        //             while (i4 <= 90) {
        //                 let vect = vector[i1, i2, i3, i4];
        //                 let key = metadata::key( &vect );

        //                 let back_to_vect = metadata::unpack_key( key );
        //                 debug::print(&string::utf8(back_to_vect));
        //                 assert!(vect == back_to_vect, 0);

        //                 total_hashes = total_hashes + 1;

        //                 i4 = i4 + 1;
        //             };
        //             i3 = i3 + 1;
        //         };

        //         i2 = i2 + 1;
        //     };
        //     i1 = i1 + 1;
        // };

        // debug::print(&total_hashes);

    }

    #[test]
    fun test_of_type_checks() {
        let metadata: vector<u8> = vector[];
        let test_chunk_id : u32 = metadata::key(&b"some_chunk_id_to_hash"); // any u32 would work

        metadata::set(&mut metadata, test_chunk_id, &(1234567890u256));
        assert!(metadata::has_chunk_of_type<u256>(&metadata, test_chunk_id) == true, 0);
        assert!(metadata::has_chunk_of_type<u8>(&metadata, test_chunk_id) == false, 0);

        metadata::set(&mut metadata, test_chunk_id, &(1234567890u128));
        assert!(metadata::has_chunk_of_type<u128>(&metadata, test_chunk_id) == true, 0);
        assert!(metadata::has_chunk_of_type<u64>(&metadata, test_chunk_id) == false, 0);

        metadata::set(&mut metadata, test_chunk_id, &(1234567890u64));
        assert!(metadata::has_chunk_of_type<u64>(&metadata, test_chunk_id) == true, 0);
        assert!(metadata::has_chunk_of_type<u128>(&metadata, test_chunk_id) == false, 0);

        metadata::set(&mut metadata, test_chunk_id, &(123u8));
        assert!(metadata::has_chunk_of_type<u8>(&metadata, test_chunk_id) == true, 0);
        assert!(metadata::has_chunk_of_type<u256>(&metadata, test_chunk_id) == false, 0);
        // special case there, it should return false for <bool> as it may throw an error
        // if you are going to peel it and there's bytes other than 0 and 1 inside
        assert!(metadata::has_chunk_of_type<bool>(&metadata, test_chunk_id) == false, 0);


        metadata::set(&mut metadata, test_chunk_id, &(true));
        assert!(metadata::has_chunk_of_type<bool>(&metadata, test_chunk_id) == true, 0);
        assert!(metadata::has_chunk_of_type<u256>(&metadata, test_chunk_id) == false, 0);

        metadata::set(&mut metadata, test_chunk_id, &(@0xC0FFEE));
        assert!(metadata::has_chunk_of_type<address>(&metadata, test_chunk_id) == true, 0); // address is 32 bytes, same as u256
        assert!(metadata::has_chunk_of_type<u128>(&metadata, test_chunk_id) == false, 0);

        metadata::set(&mut metadata, test_chunk_id, &(vector[1u8, 2u8, 3u8]));
        assert!(metadata::has_chunk_of_type<vector<u8>>(&metadata, test_chunk_id) == true, 0);
        assert!(metadata::has_chunk_of_type<vector<u16>>(&metadata, test_chunk_id) == false, 0);
        assert!(metadata::has_chunk_of_type<vector<u32>>(&metadata, test_chunk_id) == false, 0);

        // special case there, it should return false for vector<bool> as it may throw an error
        // if you are going to peel it and there's bytes other than 0 and 1 inside
        assert!(metadata::has_chunk_of_type<vector<bool>>(&metadata, test_chunk_id) == false, 0);

        metadata::set(&mut metadata, test_chunk_id, &(vector[@0xC0FFEE, @0xABBA]));
        assert!(metadata::has_chunk_of_type<vector<address>>(&metadata, test_chunk_id) == true, 0);
        // address and u256 are the largest primitives, so you can also peel other primitive vector types out of it, 
        // so it doesn't return false for other vec types

        metadata::set(&mut metadata, test_chunk_id, &(vector[1u16, 2u16, 3u16]));
        assert!(metadata::has_chunk_of_type<vector<u16>>(&metadata, test_chunk_id) == true, 0);

        metadata::set(&mut metadata, test_chunk_id, &(vector[1u32, 2u32, 3u32]));
        assert!(metadata::has_chunk_of_type<vector<u32>>(&metadata, test_chunk_id) == true, 0);

        metadata::set(&mut metadata, test_chunk_id, &(vector[1u64, 2u64, 3u64]));
        assert!(metadata::has_chunk_of_type<vector<u64>>(&metadata, test_chunk_id) == true, 0);

        metadata::set(&mut metadata, test_chunk_id, &(vector[1u128, 2u128, 3u128]));
        assert!(metadata::has_chunk_of_type<vector<u128>>(&metadata, test_chunk_id) == true, 0);

        metadata::set(&mut metadata, test_chunk_id, &(vector[1u256, 2u256, 3u256]));
        assert!(metadata::has_chunk_of_type<vector<u256>>(&metadata, test_chunk_id) == true, 0);
    }

    #[test]
    fun test_vec_u8() {
        let metadata: vector<u8> = vector[];
        
        let test_chunk_id = 3; // any u32 would work
        let test_data: vector<u8> = vector[0,1,2,3,4,5,6,7,8,9];

        let set_success = metadata::set(&mut metadata, test_chunk_id, &test_data);
        assert!(set_success == true, 0);
        assert!(metadata::get_chunks_count(&metadata) == 1, 0);

        let back_from_metadata = metadata::get_vec_u8(&metadata, test_chunk_id);
        assert!(back_from_metadata == test_data, 0);

        // try to update it to different length
        let updated_test_data: vector<u8> = b"the data of love";
        let set_updated_success = metadata::set(&mut metadata, test_chunk_id, &updated_test_data);
        assert!(set_updated_success == true, 0);
        assert!(metadata::get_chunks_count(&metadata) == 1, 0);

        let back_from_metadata_updated = metadata::get_vec_u8(&metadata, test_chunk_id);
        assert!(back_from_metadata_updated == updated_test_data, 0);
    }

    #[test]
    fun test_vec_u64_and_u128() {
        let metadata: vector<u8> = vector[];
        
        let test_chunk_id_64 = 3; // any u32 would work
        let test_chunk_id_128 = 4; // any u32 would work
        let test_data_64: vector<u64> = vector[0,1,2,3,4,5,6,7,8,9];
        let test_data_128: vector<u128> = vector[0,1,2,3,4,5,6,7,8,9];

        let set_success_64 = metadata::set(&mut metadata, test_chunk_id_64, &test_data_64);
        let set_success_128 = metadata::set(&mut metadata, test_chunk_id_128, &test_data_128);
        assert!(set_success_64 == true, 0);
        assert!(set_success_128 == true, 0);
        assert!(metadata::get_chunks_count(&metadata) == 2, 0);

        let count_of_items_in_vec_in_metadata_64 = metadata::get_vec_length(&metadata, test_chunk_id_64);
        let count_of_items_in_vec_in_metadata_128 = metadata::get_vec_length(&metadata, test_chunk_id_128);

        assert!(count_of_items_in_vec_in_metadata_64 == vector::length(&test_data_64), 0);
        assert!(count_of_items_in_vec_in_metadata_128 == vector::length(&test_data_128), 0);
    }

    #[test]
    fun test_vec_bool() {
        let metadata: vector<u8> = vector[];
        
        let test_chunk_id = 3; // any u32 would work
        let test_data: vector<bool> = vector[true, false, false, true];

        let set_success = metadata::set(&mut metadata, test_chunk_id, &test_data);
        assert!(set_success == true, 0);
        assert!(metadata::get_chunks_count(&metadata) == 1, 0);

        let back_from_metadata = metadata::get_vec_bool(&metadata, test_chunk_id);
        assert!(back_from_metadata == test_data, 0);

        let count_of_items_in_vec_in_metadata = metadata::get_vec_length(&metadata, test_chunk_id);
        assert!(count_of_items_in_vec_in_metadata == vector::length(&test_data), 0);
    }

    #[test]
    fun test_vec_address() {
        let metadata: vector<u8> = vector[];
        
        let test_chunk_id = 3; // any u32 would work
        let test_data: vector<address> = vector[@0xC0FFEE, @0xABBA, @0xBABE, @0xC0DE1, @0xBEEF];

        let set_success = metadata::set(&mut metadata, test_chunk_id, &test_data);
        assert!(set_success == true, 0);
        assert!(metadata::get_chunks_count(&metadata) == 1, 0);

        let back_from_metadata = metadata::get_vec_address(&metadata, test_chunk_id);
        assert!(back_from_metadata == test_data, 0);

        let count_of_items_in_vec_in_metadata = metadata::get_vec_length(&metadata, test_chunk_id);
        assert!(count_of_items_in_vec_in_metadata == vector::length(&test_data), 0);
    }

    #[test]
    fun test_vec_vec_u8() {
        let metadata: vector<u8> = vector[];
        
        let test_chunk_id = 3; // any u32 would work
        let test_data: vector<vector<u8>> = vector[
            b"first_item",
            vector[0,1,2,3,4,5],
            b"second_item",
        ];

        let set_success = metadata::set(&mut metadata, test_chunk_id, &test_data);
        assert!(set_success == true, 0);
        assert!(metadata::get_chunks_count(&metadata) == 1, 0);

        let count_of_items_in_vec_in_metadata = metadata::get_vec_length(&metadata, test_chunk_id);
        assert!(count_of_items_in_vec_in_metadata == vector::length(&test_data), 0);

        let back_from_metadata = metadata::get_vec_vec_u8(&metadata, test_chunk_id);
        assert!(back_from_metadata == test_data, 0);
    }



    #[test]
    fun test_vector_clamp() {
        let metadata: vector<u8> = vector[0,1,2,3,4,5,6,7,8,9];
        metadata::clamp(&mut metadata, 1, 0); // clamp length of 0 do nothing
        assert!(metadata == vector[0,1,2,3,4,5,6,7,8,9], 0);

        metadata::clamp(&mut metadata, 1, 3);
        assert!(metadata == vector[0,4,5,6,7,8,9], 0);

        metadata::clamp(&mut metadata, 0, 1);
        assert!(metadata == vector[4,5,6,7,8,9], 0);

        metadata::clamp(&mut metadata, 4, 2);
        assert!(metadata == vector[4,5,6,7], 0);

        metadata::clamp(&mut metadata, 0, 4);
        assert!(metadata == vector[], 0);
    }


    #[test]
    fun let_update_metadata_with_different_type() {
        let metadata: vector<u8> = vector[];

        // metadata lets you update metadata chunk assigning different data type to it
        let very_first = metadata::get(&metadata, 0);
        assert!(option::is_none(&very_first), 0);

        let value_u8 : u8 = 5;
        let ok_success = metadata::set(&mut metadata, 2, &value_u8);
        assert!(ok_success == true, 0);

        metadata::set(&mut metadata, 3, &b"something");

        let value_u16 : u16 = 5;
        let change_type_success = metadata::set(&mut metadata, 2, &value_u16);
        assert!(change_type_success == true, 0);

        metadata::set(&mut metadata, 2, &value_u8);
    }

    #[test]
    fun test_u8() {
        let metadata: vector<u8> = vector[];
        
        let value_u8 : u8 = 222;
        let set_success = metadata::set(&mut metadata, 3, &value_u8);
        assert!(set_success == true, 0);
        assert!(metadata::get_chunks_count(&metadata) == 1, 0);

        assert!(metadata::has_chunk_of_type<u8>(&metadata, 3) == true, 0);
        assert!(metadata::has_chunk_of_type<u64>(&metadata, 3) == false, 0);

        let set_success = metadata::set(&mut metadata, 4, &value_u8);
        assert!(set_success == true, 0);
        assert!(metadata::get_chunks_count(&metadata) == 2, 0);

        let set_success = metadata::set(&mut metadata, 4, &value_u8);
        assert!(set_success == true, 0);
        assert!(metadata::get_chunks_count(&metadata) == 2, 0); // still 2
    }


    #[test]
    fun initialization() {
        let metadata: vector<u8> = vector[];

        assert!(!metadata::has_chunk(&metadata, 0), 0);
        let very_first = metadata::get(&metadata, 0);
        assert!(option::is_none(&very_first), 0);

        assert!(!metadata::has_chunk(&metadata, 1), 0);
        let the_second = metadata::get(&metadata, 1);
        assert!(option::is_none(&the_second), 0);

        assert!(!metadata::has_chunk(&metadata, 2), 0);
        let the_third = metadata::get(&metadata, 2);
        assert!(option::is_none(&the_third), 0);

        let the_second_as_value = metadata::get_u64(&metadata,  1, 777);
        assert!(the_second_as_value == 777, 0);

        let success_the_second = metadata::set(&mut metadata, 1, &999);
        assert!(success_the_second, 0);

        assert!(metadata::has_chunk(&metadata, 1), 0);

        let the_second_updated = metadata::get(&metadata, 1);
        assert!(option::is_some(&the_second_updated), 0);

        let the_second_updated_as_value = metadata::get_u64(&metadata, 1, 777);
        assert!(the_second_updated_as_value == 999, 0);

        let test_address = @0xC0FFEE;

        let success_the_first = metadata::set(&mut metadata, 0, &test_address);
        assert!(success_the_first, 0);

        let the_first_as_option = metadata::get_option_address(&metadata, 0);
        assert!(option::is_some(&the_first_as_option), 0);

        let the_first_as_value = option::destroy_some(the_first_as_option);
        // debug::print(&the_first_as_value);
        // debug::print(&TEST_SENDER_ADDR);
        assert!(the_first_as_value == @0xC0FFEE, 0);


        assert!(metadata::has_chunk(&metadata, 0), 0);

        let remove_chunk_success = metadata::remove_chunk(&mut metadata, 0);
        assert!(remove_chunk_success, 0);

        assert!(!metadata::has_chunk(&metadata, 0), 0);

        let very_first_removed = metadata::get(&metadata, 0);
        assert!(option::is_none(&very_first_removed), 0);

        let remove_chunk_wrong_id_success = metadata::remove_chunk(&mut metadata, 222);
        assert!(remove_chunk_wrong_id_success == false, 0);


        let success_the_first_re_added = metadata::set(&mut metadata, 0, &test_address);
        assert!(success_the_first_re_added, 0);

        let the_first_re_added_as_option = metadata::get_option_address(&metadata, 0);
        assert!(option::is_some(&the_first_re_added_as_option), 0);

        let the_first_re_added_as_value = option::destroy_some(the_first_re_added_as_option);
        assert!(the_first_re_added_as_value == @0xC0FFEE, 0);
    }

    #[test]
    fun dont_throw_anything() {
        let metadata: vector<u8> = vector[];

        let very_first = metadata::get(&metadata, 0);
        assert!(option::is_none(&very_first), 0);

        let wrong_index = metadata::get(&metadata, 20);
        assert!(option::is_none(&wrong_index), 0);

        let value_u64 : u64 = 777;
        let ok_success = metadata::set(&mut metadata, 2, &value_u64);
        assert!(ok_success == true, 0);

        let the_ok_as_value = metadata::get_u64(&metadata, 2, 555);
        assert!(the_ok_as_value == value_u64, 0);

        let four_bytes = x"1223";

        let other_type_value_success = metadata::set(&mut metadata, 2, &four_bytes);
        assert!(other_type_value_success == true, 0);
    }

}