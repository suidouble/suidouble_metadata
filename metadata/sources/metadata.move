

module suidouble_metadata::metadata {
    use suidouble_metadata::compress;
    // use std::debug;
    // use std::vector;
    use sui::bcs;
    use sui::address;

    // use std::bcs as stdbcs;
    use std::option::{none, some, is_none, destroy_some, destroy_with_default};

    use std::type_name;
    use std::ascii::{as_bytes};

    // Metadata offsets:
    //   byte #1 - metadata version, for future compatibility if we'd want to add extra features.
    //           - default is 0, currently implemented is 0
    //
    // Next are MetadataChunks, one by one:
    // Metadata chunk offsets:
    //   offset - chunk_id            ( 4 bytes LE, u32 )
    //   offset + 4  - item length   ( 4 bytes LE, u32 )

    const CHUNK_HEADER_LENGTH: u32 = 8;

    /// The index into the vector is out of bounds
    const EINDEX_OUT_OF_BOUNDS: u64 = 0x20000;

    // compress vector<u8> using  LZW (Lempel-Ziv-Welch) algorithm extended with u16->u8 variable-length encoding scheme
    // does 7.5x compression on a test ascii data ( see compress_tests.move )
    public fun compress(data_ref: &vector<u8>): vector<u8> {
        compress::compress(data_ref)
    }

    // decompress compressed vector<u8> back to original
    public fun decompress(data_ref: &vector<u8>): vector<u8> {
        compress::decompress(data_ref)
    }

    /**
    *  Pack a string into u32 in a hash way, 
    *     produce different values for different strings, all unique for up to 5 chars strings:
    *       key(&b"test")  != key(&b"abba")
    *       key(&b"test2") != key(&b"test3")
    *       key(&b"1")     != key(&b"2")
    *
    *     constant
    *       key(&b"test2") == key(&b"test2")
    *
    *     different, but may be repeated values for long strings
    *       key(&b"long_string_test_1") != key(&b"long_string_test_2")
    *       key(&b"long_string_test_01") == key(&b"long_string_test_10")
    *
    *     returned u32 may be unpacked back to string using unpack_key  function     
    */
    public fun key(str_ref: &vector<u8>): u32 {
        let mut i = vector::length(str_ref);
        let mut significant_i = i;
        if (significant_i > 4) {
            significant_i = 4;
        };

        let mut buffer: u32 = 0;
        let mut shift = 0;
        
        // first - pack first 4 chars of the string as 6-bites chars, packing them into 3 bytes
        while (significant_i > 0) {
            significant_i = significant_i - 1;
            let mut char = *vector::borrow(str_ref, significant_i);
            if (char >= 97) {
                // lowercase to uppercase
                char = char - 32;
            };
            if (char >= 32) {
                // lower range of non-printable character
                char = char - 31;
            };
            buffer = buffer | ( (char as u32) << shift );
            shift = shift + 6;
        };

        // we have 1 byte left in u32 to pack everything what is left as a very simple hash, just sum up all left bytes and mod it by 256
        if (i > 4) {
            i = i - 1;
            let mut sum: u32 = 0;
            while (i >= 4) {
                let mut char = *vector::borrow(str_ref, i);
                if (char >= 97) {
                    // lowercase to uppercase
                    char = char - 32;
                };
                sum = sum + (char as u32);
                sum = sum % 256;
                i = i - 1;
            };

            if (sum == 0) {
                sum = 1;  // let's have 1 as minimum there, so we know the key was longer > 4 chars in any case
            };


            buffer = buffer | ( (sum as u32) << 24 ); // add extra hash as the 4th byte to the u32
        };

        return buffer
    }

    /**
    *   Unpack u32 key back to the string vector of it, 
    *     first 4 chars kept (though uppercased)
    *         unpack_key(key(b"TEST")) == b"TEST"
    *         unpack_key(key(b"test")) == b"TEST"
    *     may have an extra hash at the end in case long string (>4 chars) was hashed:
    *         unpack_key(key(b"TEST_long_string")) == b"TEST*005"
    *         unpack_key(key(b"TEST_other_string")) == b"TEST*119"
    */
    public fun unpack_key(key: u32): vector<u8> {
        let mut significant_i = 4;
        let mut buffer: u32 = key;
        let mut ret = vector::empty();

        // first - unpack 6bits chars to chars, assuming we have 4 chars in 3 bytes
        while (significant_i > 0) {
            let byte = ((buffer & 0x3F) as u8); // Extract 6 bits
            if (byte > 0) { // ignore empty
                vector::push_back(&mut ret, byte + 31);    // Convert back to ASCII by adding 32
            };
            buffer = buffer >> 6;
            significant_i = significant_i - 1;
        };

        // order is different
        vector::reverse(&mut ret);

        // if there's something left in buffer - 
        //    key hash was generated using the string longer than 4 chars
        //    lets add extra hash as the number after * to the ret string
        if (buffer > 0) {
            // the key was longer than 4 chars,
            // append asterisk and a last hash byte as string chars

            vector::push_back(&mut ret, 42);                                 // *
            vector::push_back(&mut ret, ( (buffer as u8) / 100) + 48 );      // '2' in 234
            vector::push_back(&mut ret, ( (buffer as u8) / 10 ) % 10 + 48 ); // '3' in 234
            vector::push_back(&mut ret, ( (buffer as u8) ) % 10 + 48 );      // '4' in 234
        };


        return ret
    }

    /**
    *  Get count of chunks in metadata vector<u8>
    */
    public fun get_chunks_count(metadata_ref: &vector<u8>): u32 {
        (vector::length(&get_chunks_ids(metadata_ref)) as u32)
    }

    /**
    *  Get chunks ids in metadata vector<u8>
    */
    public fun get_chunks_ids(metadata_ref: &vector<u8>): vector<u32> {
        let mut ret:vector<u32> = vector::empty();
        // walk though metadata to find all chunks
        let metadata_length = vector::length(metadata_ref);
        let mut pos = 1;  // skip byte #0 as it's metadata version

        while (pos < metadata_length) {
            // first byte in chunk is chunk_id
            let offset_chunk_id = u32_from_le_bytes_at_offset(metadata_ref, pos);
            let offset_chunk_length = u32_from_le_bytes_at_offset(metadata_ref, pos + 4); 

            vector::push_back(&mut ret, offset_chunk_id);

            pos = pos + (offset_chunk_length as u64);
        };

        ret
    }

    /**
    *  Find offset at which chunk_id metadata chunk is located inside metadata
    */
    fun get_chunk_offset(metadata_ref: &vector<u8>, chunk_id: u32): u64 {
        // walk though metadata to find offset needed
        let metadata_length = vector::length(metadata_ref);
        if (metadata_length <= 1) {  // may have byte #0 - version
            return 0
        };

        let mut pos = 1; // skip byte #0 as it's metadata version

        while (pos < metadata_length) {
            // first byte in chunk is chunk_id
            let offset_chunk_id = u32_from_le_bytes_at_offset(metadata_ref, pos);
            if (offset_chunk_id == chunk_id) {
                // we found it
                return pos
            } else {
                // second in chunk are 4 bytes = chunk length in bytes
                let offset_chunk_length = u32_from_le_bytes_at_offset(metadata_ref, pos + 4); 
                pos = pos + (offset_chunk_length as u64);
            };
        };

        return metadata_length
    }

    /**
    *  Get length of metadata chunk located at metadata_offset in metadata 
    */
    fun get_chunk_length_at_offset(metadata_ref: &vector<u8>, metadata_offset: u64): u32 {
        let metadata_length = vector::length(metadata_ref);

        if (metadata_offset == metadata_length) {
            return 0
        };

        return u32_from_le_bytes_at_offset(metadata_ref, metadata_offset + 4) // *vector::borrow(metadata_ref, metadata_offset + 1)
    }

    /**
    *   Remove chunk from the metadata
    */
    public fun remove_chunk(metadata: &mut vector<u8>, chunk_id: u32): bool {
        let data_offset      = get_chunk_offset(metadata, chunk_id);
        let data_length      = get_chunk_length_at_offset(metadata, data_offset);

        if (data_length == 0) {
            // no such item
            return false
        };

        clamp(metadata, data_offset, (data_length as u64));

        return true
    }


    /**
    *  Set metadata chunk of chunk_id to value
    */
    public fun set<T>(metadata: &mut vector<u8>, chunk_id: u32, value: &T): bool {
        let data_offset      = get_chunk_offset(metadata, chunk_id);
        let data_length      = get_chunk_length_at_offset(metadata, data_offset);

        let chunk_header_length : u8 = 8;
        let mut as_bytes = bcs::to_bytes(value);
        let as_bytes_length = vector::length(&as_bytes);

        // check for overflow. @todo?

        if (data_length != 0) {
            // we already have metadata chunk with id of chunk_id
            if ((as_bytes_length as u32) == ((data_length as u32) - (chunk_header_length as u32)) ) {
                // and its data length is same we are going to set it to

                let current_metadata_length = vector::length(metadata);
                let piece_added_at = current_metadata_length;
                let mut piece_to_be_moved_to = data_offset + (data_length as u64);

                // taking the last byte from data, add it to the end of metadata, swap it to needed position, and remove old byte
                while (!vector::is_empty(&as_bytes)) {
                    piece_to_be_moved_to = piece_to_be_moved_to - 1; // next byte on the next step

                    // get from the end of data and add to the end of metadata
                    vector::push_back(metadata, vector::pop_back(&mut as_bytes));
                    // swap to needed position.
                    vector::swap(metadata, piece_added_at, piece_to_be_moved_to);
                    // remove old byte from metadata
                    vector::pop_back(metadata);
                };

                vector::destroy_empty(as_bytes);
            
                return true
            } else {
                // length of current metadata chunk is different, we can not use it anymore, so lets remove old chunk
                //    and add it as of fresh
                clamp(metadata, data_offset, (data_length as u64));
            };
        };

        // if metadata is fresh and empty - add a version byte to it.
        if (vector::length(metadata) == 0) {
            vector::push_back(metadata, 0);
        };

        // here we are going to add metadata chunk to the end of metadata vector
        
        // 4 bytes  = chunk_id as u32
        let chunk_id_as_bytes = bcs::to_bytes(&chunk_id);
        vector::append(metadata, chunk_id_as_bytes);

        // 4 bytes = chunk length as u32
        let chunk_length : u32 = (as_bytes_length as u32) + (chunk_header_length as u32);
        let chunk_length_as_bytes = bcs::to_bytes(&chunk_length);
        vector::append(metadata, chunk_length_as_bytes);

        // data itself
        vector::append(metadata, as_bytes);


        return true
    }

    /**
    *  Returns true, if there's metadata chunk with id of chunk_id
    */
    public fun has_chunk(metadata_ref: &vector<u8>, chunk_id: u32): bool {
        let data_offset      = get_chunk_offset(metadata_ref, chunk_id);
        let data_length      = get_chunk_length_at_offset(metadata_ref, data_offset);

        let current_metadata_length = vector::length(metadata_ref);

        // data_offset_next == 0 - we don't have ranges for this chunk_id
        // current_metadata_length < data_offset_next - metadata is not set
        if (data_length == 0 || current_metadata_length < data_offset + (data_length as u64)) {
            return false
        };


        return true
    }

    public fun has_chunk_of_type<T>(metadata: &vector<u8>, chunk_id: u32): bool {
        let data_offset      = get_chunk_offset(metadata, chunk_id);
        let data_length      = get_chunk_length_at_offset(metadata, data_offset);

        if (data_length < CHUNK_HEADER_LENGTH) {
            return false
        };

        let tname = type_name::get<T>();
        let tname_as_string = type_name::into_string(tname);
        let as_bytes = as_bytes(&tname_as_string);

        let chunk_data_length = data_length - CHUNK_HEADER_LENGTH;
        if (as_bytes == &b"bool") {
            if (chunk_data_length == 1) { 
                if (get_u8(metadata, chunk_id, 3) > 1) { // if it's not [0,1] there
                    return false
                } else {
                    return true
                }
            };
        } else if (as_bytes == &b"u8") {
            if (chunk_data_length == 1) {
                return true
            };
        } else if (as_bytes == &b"u64") {
            if (chunk_data_length == 8) {
                return true
            };
        } else if (as_bytes == &b"u128") {
            if (chunk_data_length == 16) {
                return true
            };
        } else if (as_bytes == &b"u256") {
            if (chunk_data_length == 32) {
                return true
            };
        } else if (as_bytes == &b"address") {
            if (chunk_data_length == (address::length() as u32) ) {
                return true
            };
        } else if (vector::length(as_bytes) > 6 && 
            *vector::borrow(as_bytes, 0) == 118 &&  // ascii codes for 'vector'
            *vector::borrow(as_bytes, 1) == 101 &&
            *vector::borrow(as_bytes, 2) == 99 &&
            *vector::borrow(as_bytes, 3) == 116 &&
            *vector::borrow(as_bytes, 4) == 111 &&
            *vector::borrow(as_bytes, 5) == 114) {

                let mut item_byte_length = 1;
                let mut check_for_bool = false;

                if (*vector::borrow(as_bytes, 7) == 117) { // u
                    // so it's expected to be vector<u8> ... vector<u256>, u8, u16, u32, u64, u128, u256
                    if (as_bytes == &b"vector<u8>") { 
                        item_byte_length = 1;
                    } else if (as_bytes == &b"vector<u64>") {
                        item_byte_length = 8;
                    } else if (as_bytes == &b"vector<u32>") {
                        item_byte_length = 4;
                    } else if (as_bytes == &b"vector<u256>") {
                        item_byte_length = 32;
                    } else if (as_bytes == &b"vector<u16>") { 
                        item_byte_length = 2;
                    } else if (as_bytes == &b"vector<u128>") { 
                        item_byte_length = 16;
                    };
                } else if (as_bytes == &b"vector<address>") { // address
                    // vector<address>
                    item_byte_length = 32;
                } else if (as_bytes == &b"vector<bool>") { // bool
                    // vector<bool>
                    item_byte_length = 1;
                    check_for_bool = true;
                };

                // need to use BCS to get vector length
                let vec_length = get_vec_length(metadata, chunk_id);
                let expected_data_length_to_be_at_least = vec_length * item_byte_length;

                if ( (chunk_data_length as u64) < expected_data_length_to_be_at_least) {
                    return false
                };

                if (check_for_bool) {
                    // u8 is same length, but allows for other than 0-1 in bytes, so we get vec as u8 and check if it's ok as bool
                    let vec_as_u8 = get_vec_u8(metadata, chunk_id);
                    let mut i = vector::length(&vec_as_u8);
                    while (i > 0) {
                        i = i - 1;
                        if (*vector::borrow(&vec_as_u8, i) > 1) {  // if it's not [0,1] there
                            // invalid byte, it's not vector<bool>
                            return false
                        };
                    };
                };

                return true
        };


        return false
    }
    

    /**
    *   Get Option<vector<u8>> of metadata chunk of chunk_id
    *       with no header, binary data only
    *       - none() if there's no such chunk
    */
    public fun get(metadata_ref: &vector<u8>, chunk_id: u32): Option<vector<u8>> {
        let data_offset      = get_chunk_offset(metadata_ref, chunk_id);
        let data_length      = get_chunk_length_at_offset(metadata_ref, data_offset);

        let current_metadata_length = vector::length(metadata_ref);

        // data_offset_next == 0 - we don't have ranges for this chunk_id
        // current_metadata_length < data_offset_next - metadata is not set
        if (data_length == 0 || current_metadata_length < data_offset + (data_length as u64)) {
            return none()
        };


        let mut ret:vector<u8> = vector::empty();
        let mut i = data_offset + 8; // skip chunk header
        let till = data_offset + (data_length as u64);
        while (i < till) {
            let byte = *vector::borrow(metadata_ref, i);
            vector::push_back(&mut ret, byte);
            i = i + 1;
        };

        return some(ret)
    }

    // Get length of vector inside chunk_id
    public fun get_vec_length(metadata_ref: &vector<u8>, chunk_id: u32): u64 {
        let meta_chunk_option_binary = get(metadata_ref, chunk_id);
        if (is_none(&meta_chunk_option_binary)) {
            return 0
        };

        return bcs::peel_vec_length( &mut bcs::new( destroy_some(meta_chunk_option_binary) ) )
    }

    /// Get a vector of `u8` (eg string) from the chunk of metadata vector
    public fun get_option_vec_u8(metadata_ref: &vector<u8>, chunk_id: u32): Option<vector<u8>> {
        let meta_chunk_option_binary = get(metadata_ref, chunk_id);
        if (is_none(&meta_chunk_option_binary)) {
            return none()
        };
        // @todo: add some checks there? As sui::bcs doesn't really check anything and there may be panics on the broken binary
        return some(bcs::peel_vec_u8( &mut bcs::new( destroy_some(meta_chunk_option_binary) ) ))
    }
    public fun get_vec_u8(metadata_ref: &vector<u8>, chunk_id: u32): vector<u8> {
        return destroy_with_default(get_option_vec_u8(metadata_ref, chunk_id), vector::empty())
    }


    /// Get a `vector<vector<u8>>` (eg vec of string) from the chunk of metadata vector
    public fun get_option_vec_vec_u8(metadata_ref: &vector<u8>, chunk_id: u32): Option<vector<vector<u8>>> {
        let meta_chunk_option_binary = get(metadata_ref, chunk_id);
        if (is_none(&meta_chunk_option_binary)) {
            return none()
        };
        // @todo: add some checks there? As sui::bcs doesn't really check anything and there may be panics on the broken binary
        return some(bcs::peel_vec_vec_u8( &mut bcs::new( destroy_some(meta_chunk_option_binary) ) ))
    }
    public fun get_vec_vec_u8(metadata_ref: &vector<u8>, chunk_id: u32): vector<vector<u8>> {
        return destroy_with_default(get_option_vec_vec_u8(metadata_ref, chunk_id), vector::empty())
    }


    /// Get a vector of `bool` from the chunk of metadata vector
    public fun get_option_vec_bool(metadata_ref: &vector<u8>, chunk_id: u32): Option<vector<bool>> {
        let meta_chunk_option_binary = get(metadata_ref, chunk_id);
        if (is_none(&meta_chunk_option_binary)) {
            return none()
        };
        // @todo: add some checks there? As sui::bcs doesn't really check anything and there may be panics on the broken binary
        return some(bcs::peel_vec_bool( &mut bcs::new( destroy_some(meta_chunk_option_binary) ) ))
    }
    public fun get_vec_bool(metadata_ref: &vector<u8>, chunk_id: u32): vector<bool> {
        return destroy_with_default(get_option_vec_bool(metadata_ref, chunk_id), vector::empty())
    }

    /// Get a vector of `address` from the chunk of metadata vector
    public fun get_option_vec_address(metadata_ref: &vector<u8>, chunk_id: u32): Option<vector<address>> {
        let meta_chunk_option_binary = get(metadata_ref, chunk_id);
        if (is_none(&meta_chunk_option_binary)) {
            return none()
        };
        // @todo: add some checks there? As sui::bcs doesn't really check anything and there may be panics on the broken binary
        return some(bcs::peel_vec_address( &mut bcs::new( destroy_some(meta_chunk_option_binary) ) ))
    }
    public fun get_vec_address(metadata_ref: &vector<u8>, chunk_id: u32): vector<address> {
        return destroy_with_default(get_option_vec_address(metadata_ref, chunk_id), vector::empty())
    }

    /// Get a vector of `u64` from the chunk of metadata vector
    public fun get_option_vec_u64(metadata_ref: &vector<u8>, chunk_id: u32): Option<vector<u64>> {
        let meta_chunk_option_binary = get(metadata_ref, chunk_id);
        if (is_none(&meta_chunk_option_binary)) {
            return none()
        };
        // @todo: add some checks there? As sui::bcs doesn't really check anything and there may be panics on the broken binary
        return some(bcs::peel_vec_u64( &mut bcs::new( destroy_some(meta_chunk_option_binary) ) ))
    }
    public fun get_vec_u64(metadata_ref: &vector<u8>, chunk_id: u32): vector<u64> {
        return destroy_with_default(get_option_vec_u64(metadata_ref, chunk_id), vector::empty())
    }

    /// Get a vector of `u128` from the chunk of metadata vector
    public fun get_option_vec_u128(metadata_ref: &vector<u8>, chunk_id: u32): Option<vector<u128>> {
        let meta_chunk_option_binary = get(metadata_ref, chunk_id);
        if (is_none(&meta_chunk_option_binary)) {
            return none()
        };
        // @todo: add some checks there? As sui::bcs doesn't really check anything and there may be panics on the broken binary
        return some(bcs::peel_vec_u128( &mut bcs::new( destroy_some(meta_chunk_option_binary) ) ))
    }
    public fun get_vec_u128(metadata_ref: &vector<u8>, chunk_id: u32): vector<u128> {
        return destroy_with_default(get_option_vec_u128(metadata_ref, chunk_id), vector::empty())
    }



    /// Get `u8` from the chunk of metadata, returns Option, none() if there's no such chunk
    public fun get_option_u8(metadata_ref: &vector<u8>, chunk_id: u32): Option<u8> {
        let meta_chunk_option_binary = get(metadata_ref, chunk_id);
        if (is_none(&meta_chunk_option_binary)) {
            return none()
        };
        return some(bcs::peel_u8( &mut bcs::new( destroy_some(meta_chunk_option_binary) ) ))
    }
    /// Get `u8` from the chunk of metadata, with default parameter in case there's no such chunk
    public fun get_u8(metadata_ref: &vector<u8>, chunk_id: u32, default: u8): u8 {
        return destroy_with_default(get_option_u8(metadata_ref, chunk_id), default)
    }

    // there's no u16 and u32 in sui:bcs. Not sure why, we can possibly write them ourselves. Do we need to? @todo

    /// Get `u64` from the chunk of metadata, returns Option, none() if there's no such chunk
    public fun get_option_u64(metadata_ref: &vector<u8>, chunk_id: u32): Option<u64> {
        let meta_chunk_option_binary = get(metadata_ref, chunk_id);
        if (is_none(&meta_chunk_option_binary)) {
            return none()
        };
        return some(bcs::peel_u64( &mut bcs::new( destroy_some(meta_chunk_option_binary) ) ))
    }
    /// Get `u64` from the chunk of metadata, with default parameter in case there's no such chunk
    public fun get_u64(metadata_ref: &vector<u8>, chunk_id: u32, default: u64): u64 {
        return destroy_with_default(get_option_u64(metadata_ref, chunk_id), default)
    }


    /// Get `u128` from the chunk of metadata, returns Option, none() if there's no such chunk
    public fun get_option_u128(metadata_ref: &vector<u8>, chunk_id: u32): Option<u128> {
        let meta_chunk_option_binary = get(metadata_ref, chunk_id);
        if (is_none(&meta_chunk_option_binary)) {
            return none()
        };
        return some(bcs::peel_u128( &mut bcs::new( destroy_some(meta_chunk_option_binary) ) ))
    }
    /// Get `u128` from the chunk of metadata, with default parameter in case there's no such chunk
    public fun get_u128(metadata_ref: &vector<u8>, chunk_id: u32, default: u128): u128 {
        return destroy_with_default(get_option_u128(metadata_ref, chunk_id), default)
    }


    /// Get `u256` from the chunk of metadata, returns Option, none() if there's no such chunk
    public fun get_option_u256(metadata_ref: &vector<u8>, chunk_id: u32): Option<u256> {
        let meta_chunk_option_binary = get(metadata_ref, chunk_id);
        if (is_none(&meta_chunk_option_binary)) {
            return none()
        };
        return some(bcs::peel_u256( &mut bcs::new( destroy_some(meta_chunk_option_binary) ) ))
    }
    /// Get `u256` from the chunk of metadata, with default parameter in case there's no such chunk
    public fun get_u256(metadata_ref: &vector<u8>, chunk_id: u32, default: u256): u256 {
        return destroy_with_default(get_option_u256(metadata_ref, chunk_id), default)
    }



    /// Get `bool` from the chunk of metadata, returns Option, none() if there's no such chunk
    public fun get_option_bool(metadata_ref: &vector<u8>, chunk_id: u32): Option<bool> {
        let meta_chunk_option_binary = get(metadata_ref, chunk_id);
        if (is_none(&meta_chunk_option_binary)) {
            return none()
        };
        return some(bcs::peel_bool( &mut bcs::new( destroy_some(meta_chunk_option_binary) ) ))
    }
    /// Get `bool` from the chunk of metadata, with default parameter in case there's no such chunk
    public fun get_bool(metadata_ref: &vector<u8>, chunk_id: u32, default: bool): bool {
        return destroy_with_default(get_option_bool(metadata_ref, chunk_id), default)
    }



    /// Get `address` from the chunk of metadata, returns Option, none() if there's no such chunk
    public fun get_option_address(metadata_ref: &vector<u8>, chunk_id: u32): Option<address> {
        let meta_chunk_option_binary = get(metadata_ref, chunk_id);
        if (is_none(&meta_chunk_option_binary)) {
            return none()
        };
        return some(bcs::peel_address( &mut bcs::new( destroy_some(meta_chunk_option_binary) ) ))
    }
    /// Get `address` from the chunk of metadata, with default parameter in case there's no such chunk
    public fun get_address(metadata_ref: &vector<u8>, chunk_id: u32, default: address): address {
        return destroy_with_default(get_option_address(metadata_ref, chunk_id), default)
    }



    /**
    *   Read u32 (LE 4 bytes) from specified position in vector<u8>
    */
    public fun u32_from_le_bytes_at_offset(bytes: &vector<u8>, offset: u64): u32 {
        ((*(vector::borrow(bytes, offset)) as u32) <<  0) +
        ((*(vector::borrow(bytes, offset + 1)) as u32) <<  8) +
        ((*(vector::borrow(bytes, offset + 2)) as u32) << 16) +
        ((*(vector::borrow(bytes, offset + 3)) as u32) << 24)
    }

    /**
    *  Remove a portion of vector in offset of specific length
    */
    public fun clamp(bytes: &mut vector<u8>, offset: u64, length: u64) {
        if (length == 0) {
            return
        };

        let total_length = vector::length(bytes);
        if (offset + length > total_length) abort EINDEX_OUT_OF_BOUNDS;

        let mut i = offset;
        let move_till = total_length - length;
        // move bytes one by one to the end of the vector in O(N)
        while (i < move_till) {
            vector::swap(bytes, i, i + length);
            i = i + 1;
        };

        i = 0;
        // and remove them from the end of it
        while (i < length) {
            vector::pop_back(bytes);
            i = i + 1;
        };
    }
}