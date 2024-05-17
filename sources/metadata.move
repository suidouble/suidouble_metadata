

module suidouble_metadata::metadata {
    // use std::debug;
    use std::vector;
    use sui::bcs;
    use sui::address;

    // use std::bcs as stdbcs;
    use std::option::{Option, none, some, is_none, destroy_some, destroy_with_default};

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

    // /// u16 is too large to be packed into u8
    // const ETOO_LARGE_U16: u64 = 0x30000;

    // /// compressed data is broken
    // const EBAD_LZW: u64 = 0x40000;


    // public fun decompress(data_ref: &vector<u16>): vector<u8> {
    //     let dic: vector<vector<u8>> = vector::empty();
    //     let i:u8 = 0;
    //     while (i < 255) {
    //         vector::push_back(&mut dic, vector::singleton(i));
    //         i = i + 1;
    //     };
    //     vector::push_back(&mut dic, vector::singleton(255));

    //     let decompressed: vector<u8> = vector::empty();
    //     let previous_code = *vector::borrow(data_ref, 0);

    //     vector::append(&mut decompressed, *vector::borrow(&dic, (previous_code as u64) ));

    //     let j:u64 = 1;
    //     let data_length = vector::length(data_ref);
    //     let entry: vector<u8> = vector::empty();
    //     while (j < data_length) {
    //         let code = *vector::borrow(data_ref, j);
    //         let cur_dic_length = vector::length(&dic);
    //         if ( (code as u64) < cur_dic_length ) {
    //             // 
    //             let entry = *vector::borrow(&dic, (code as u64) );
    //             vector::append(&mut decompressed,  entry );


    //             let to_dic = *vector::borrow(&dic, (previous_code as u64) );
    //             let first_byte_in_this_entry = *vector::borrow(&entry, 0);
    //             vector::push_back(&mut to_dic, first_byte_in_this_entry);
    //             vector::push_back(&mut dic, to_dic);

                
    //         } else if ( (code as u64) == cur_dic_length ) {
    //             // debug::print(&previous_code);
    //             let prev_entry = *vector::borrow(&dic, (previous_code as u64) );
    //             let first_byte_in_prev_entry = *vector::borrow(&prev_entry,0);
    //             vector::push_back(&mut prev_entry, first_byte_in_prev_entry);
                
    //             vector::push_back(&mut dic, prev_entry);
    //             // vector::append(&mut decompressed,  prev_entry ); 


    //             vector::append(&mut decompressed,  prev_entry ); 
    //         };


    //         // let (found, position) = vector::index_of(&dic,(code as u64) );
    //         j = j + 1;
    //         previous_code = code;
    //     };

    //     debug::print(&dic);
    //     debug::print(&decompressed);

    //     decompressed
    // }

    // public fun pack_low_u16_into_u8(data_ref: &vector<u16>): vector<u8> {
    //     let i:u64 = 0;
    //     let data_length = vector::length(data_ref);
    //     let last_upper_byte: u8 = 0;
    //     let ret: vector<u8> = vector::empty();

    //     while (i < data_length) {
    //         let code = *vector::borrow(data_ref, i);

    //         let lower_byte = ( (code & 0xFF) as u8 );
    //         let upper_byte = ( ((code >> 8) & 0xFF) as u8 );

    //         if (upper_byte == 0xFF) {
    //             abort ETOO_LARGE_U16
    //         };

    //         debug::print(&upper_byte);

    //         if (upper_byte != last_upper_byte) {
    //             vector::push_back(&mut ret, 0xFF);       // indicating upper_byte is changed
    //             vector::push_back(&mut ret, upper_byte);
    //             last_upper_byte = upper_byte;
    //         };

    //         if (lower_byte != 0xFF) {
    //             vector::push_back(&mut ret, lower_byte);
    //         } else {
    //             vector::push_back(&mut ret, 0xFF); // lower FF is represented by double FF
    //             vector::push_back(&mut ret, 0xFF);
    //         };

    //         i = i + 1;
    //     };

    //     return ret
    // }

    // public fun unpack_u8_into_u16(data_ref: &vector<u8>): vector<u16> {
    //     let i:u64 = 0;
    //     let data_length = vector::length(data_ref);
    //     let ret: vector<u16> = vector::empty();
    //     let last_upper_byte: u16 = 0;

    //     while (i < data_length) {
    //         let byte = (*vector::borrow(data_ref, i) as u16);
    //         if (byte == 0xFF) { 
    //             // special one
    //             // changes upper_byte if next one is < 0xFF
    //             i = i + 1;
    //             let control_byte = *vector::borrow(data_ref, i);
    //             if (control_byte == 0xFF) {
    //                 byte = 0xFF;
    //                 vector::push_back(&mut ret, ( last_upper_byte | byte ) );
    //             } else {
    //                 last_upper_byte = (control_byte as u16) << 8;
    //             };
    //         } else {
    //             vector::push_back(&mut ret, ( last_upper_byte | byte ) );
    //         };

    //         i = i + 1;
    //     };

    //     return ret
    // }

    // public fun decompress8(data_ref: &vector<u8>): vector<u8> {
    //     let dic: vector<vector<u8>> = vector::empty();
    //     let i:u8 = 0;
    //     while (i < 255) {
    //         vector::push_back(&mut dic, vector::singleton(i));
    //         i = i + 1;
    //     };
    //     vector::push_back(&mut dic, vector::singleton(255));

    //     let last_upper_byte: u16 = 0;
    //     let decompressed: vector<u8> = vector::empty();
    //     let first_byte = (*vector::borrow(data_ref, 0) as u16);

    //     let j:u64 = 1;

    //         debug::print(&first_byte);
    //         debug::print(&first_byte);
    //     if (first_byte == 0xFF) {
    //         // control byte
    //         let control_byte = (*vector::borrow(data_ref, 1) as u16);
    //         if (control_byte == 0xFF) {
    //             // it's just 0xFF (remember 0xFF is represented by double 0xFF in u8 stream on compression)
    //             first_byte = 0xFF;
    //         } else {
    //             // it's a control byte changing upper_byte for next bytes
    //             last_upper_byte = (control_byte as u16) << 8;
    //         };
    //         j = 2;
    //     };
    //     let previous_code = ( last_upper_byte | first_byte );

    //     vector::append(&mut decompressed, *vector::borrow(&dic, (previous_code as u64) ));

    //     let data_length = vector::length(data_ref);
    //     let entry: vector<u8> = vector::empty();
    //     while (j < data_length) {
    //         let is_control_byte = false;
    //         let byte = (*vector::borrow(data_ref, j) as u16);
    //         let code = ( last_upper_byte | byte );
    //         if (byte == 0xFF) {
    //             // control byte
    //             // changes upper_byte if next one is < 0xFF
    //             j = j + 1;
    //             let control_byte = *vector::borrow(data_ref, j);
    //             if (control_byte == 0xFF) {
    //                 code = ( last_upper_byte | 0xFF );  // already did this though
    //             } else {
    //                 // change upper byte for next bytes
    //                 last_upper_byte = (control_byte as u16) << 8;
    //                 is_control_byte = true;
    //             };
    //         };

    //         if (!is_control_byte) {
    //             debug::print(&last_upper_byte);
    //             debug::print(&code);
    //             let cur_dic_length = vector::length(&dic);
    //             if ( (code as u64) < cur_dic_length ) {
    //                 // 
    //                 let entry = *vector::borrow(&dic, (code as u64) );
    //                 vector::append(&mut decompressed,  entry );


    //                 let to_dic = *vector::borrow(&dic, (previous_code as u64) );
    //                 let first_byte_in_this_entry = *vector::borrow(&entry, 0);
    //                 vector::push_back(&mut to_dic, first_byte_in_this_entry);
    //                 vector::push_back(&mut dic, to_dic);

                    
    //             } else if ( (code as u64) == cur_dic_length ) {
    //                 // debug::print(&previous_code);
    //                 let prev_entry = *vector::borrow(&dic, (previous_code as u64) );
    //                 let first_byte_in_prev_entry = *vector::borrow(&prev_entry,0);
    //                 vector::push_back(&mut prev_entry, first_byte_in_prev_entry);
                    
    //                 vector::push_back(&mut dic, prev_entry);
    //                 // vector::append(&mut decompressed,  prev_entry ); 


    //                 vector::append(&mut decompressed,  prev_entry ); 
    //             } else {
    //                 abort EBAD_LZW
    //             };
    //             previous_code = code;
    //         };


    //         // let (found, position) = vector::index_of(&dic,(code as u64) );
    //         j = j + 1;
    //     };

    //     debug::print(&dic);
    //     debug::print(&decompressed);

    //     decompressed
    // }

    // public fun compress8(data_ref: &vector<u8>): vector<u8> {
    //     // compress vector<u8> using something like simple LZW (Lempel-Ziv-Welch) algorithm extended with u16->u8 variable-length encoding scheme
    //     // fill a dictionary and add codes for it to the result stream
    //     let dic: vector<vector<u8>> = vector::empty();
    //     let i:u8 = 0;
    //     while (i < 255) {
    //         vector::push_back(&mut dic, vector::singleton(i));
    //         i = i + 1;
    //     };
    //     vector::push_back(&mut dic, vector::singleton(255));
    //     // on the start dic is filled with vector<u8> = [n] where (n = 0..255)

    //     let current: vector<u8> = vector::empty();
    //     let compressed: vector<u8> = vector::empty();
    //     let last_upper_byte: u8 = 0; // if result stream upper byte is changed - we'll add a control char to indicate

    //     let j:u64 = 0;
    //     let data_length = vector::length(data_ref);
    //     while (j < data_length) {
    //         let byte = *vector::borrow(data_ref, j);
    //         vector::push_back(&mut current, byte);

    //         // @todo: we can optimize it getting rid of `index_of` below, as we had already did up to O(N) with `contains`
    //         if (vector::contains(&dic, &current)) {
    //             // if we have this vec of bytes in dic - we can check for more,
    //             // we'll add it to the result below after else if we can't find more
    //         } else {
    //             // we don't have the vec of bytes in dic, so:
    //             //   - we add the index to the last vec found in dic to the compressed stream 
    //             //   - add the new vec to the dic
    //             vector::pop_back(&mut current); // getting `current` back to the vec without the last byte
    //             let (found, position) = vector::index_of(&dic, &current); // get the index to it
    //             if (found) {
    //                 // it's expected to be always found here, actually, as it's the first time we are in this `else` after nuling `current` vec
    //                 // so we can add index to the compressed vec
    //                 // for vector<u8> results are u16, but we don't want to waste space for it, as most higher bytes are the same
    //                 // so lets pack them
    //                 // compressed byte is packed from u16 to u8, assuming we mostly have the same upper_byte (confirmed by tests on most data)
    //                 //    0xFF is the control byte in the u8 vec, indicating:
    //                 //     - upper byte is changed and next byte is the upper byte
    //                 //     - next byte is 0xFF too, indicating it's just 0xFF lower byte
    //                 let lower_byte = ( (position & 0xFF) as u8 );
    //                 let upper_byte = ( ((position >> 8) & 0xFF) as u8 );

    //                 if (upper_byte != last_upper_byte) {
    //                     vector::push_back(&mut compressed, 0xFF);       // indicating upper_byte is changed
    //                     vector::push_back(&mut compressed, upper_byte);
    //                     last_upper_byte = upper_byte;
    //                 };

    //                 if (lower_byte != 0xFF) {
    //                     vector::push_back(&mut compressed, lower_byte);
    //                 } else {
    //                     vector::push_back(&mut compressed, 0xFF); // lower FF is represented by double FF
    //                     vector::push_back(&mut compressed, 0xFF);
    //                 };
    //             };
    //             vector::push_back(&mut current, byte); // current = extended
    //             vector::push_back(&mut dic, current); 
                
    //             current = vector::singleton(byte);  // current = vec![byte];
    //         };

    //         j = j + 1;
    //     };

    //     debug::print(&dic);

    //     if (!vector::is_empty(&current)) {
    //         // doing th same as above for what we had left in the current vec
    //         let (found, position) = vector::index_of(&dic, &current); 
    //         if (found) {
    //             let lower_byte = ( (position & 0xFF) as u8 );
    //             let upper_byte = ( ((position >> 8) & 0xFF) as u8 );

    //             if (upper_byte != last_upper_byte) {
    //                 vector::push_back(&mut compressed, 0xFF);       // indicating upper_byte is changed
    //                 vector::push_back(&mut compressed, upper_byte);
    //                 last_upper_byte = upper_byte;
    //             };

    //             if (lower_byte != 0xFF) {
    //                 vector::push_back(&mut compressed, lower_byte);
    //             } else {
    //                 vector::push_back(&mut compressed, 0xFF); // lower FF is represented by double FF
    //                 vector::push_back(&mut compressed, 0xFF);
    //             };
    //         };
    //     };

    //     return compressed
    // }


    // public fun compress(data_ref: &vector<u8>): vector<u16> {
    //     let dic: vector<vector<u8>> = vector::empty();
    //     // let mut dict: Vec<Vec<u8>> = (0..=255).map(|i| vec![i as u8]).collect();
    //     let i:u8 = 0;
    //     while (i < 255) {
    //         vector::push_back(&mut dic, vector::singleton(i));
    //         i = i + 1;
    //     };
    //     vector::push_back(&mut dic, vector::singleton(255));

    //     let current: vector<u8> = vector::empty();
    //     let compressed: vector<u16> = vector::empty();

    //     let j:u64 = 0;
    //     let data_length = vector::length(data_ref);
    //     while (j < data_length) {
    //         let byte = *vector::borrow(data_ref, j);
    //         // let mut extended = current.clone();
    //         // extended.push(byte);
    //         vector::push_back(&mut current, byte);
    //         if (vector::contains(&dic, &current)) {
    //             // has it in dic
    //         } else {
    //             vector::pop_back(&mut current); // current = currrent
    //             let (found, position) = vector::index_of(&dic, &current); // let position = dict.iter().position(|entry| *entry == current).unwrap();
    //             if (found) {
    //                 vector::push_back(&mut compressed, (position as u16) );  // compressed.push(position as u8);
    //             };
    //             vector::push_back(&mut current, byte); // current = extended
    //             vector::push_back(&mut dic, current); 
                
    //             current = vector::singleton(byte);  // current = vec![byte];
    //         };

    //         j = j + 1;
    //     };

    //     debug::print(&dic);

    //     if (!vector::is_empty(&current)) {
    //         let (found, position) = vector::index_of(&dic, &current); // let position = dict.iter().position(|entry| *entry == current).unwrap();
    //         if (found) {
    //             vector::push_back(&mut compressed, (position as u16) );  // compressed.push(position as u8);
    //         } else {
    //             abort 3
    //         };
    //     };

    //     return compressed
    // }

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
        let i = vector::length(str_ref);
        let significant_i = i;
        if (significant_i > 4) {
            significant_i = 4;
        };

        let buffer: u32 = 0;
        let shift = 0;
        
        // first - pack first 4 chars of the string as 6-bites chars, packing them into 3 bytes
        while (significant_i > 0) {
            significant_i = significant_i - 1;
            let char = *vector::borrow(str_ref, significant_i);
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
            let sum: u32 = 0;
            while (i >= 4) {
                let char = *vector::borrow(str_ref, i);
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
        let significant_i = 4;
        let buffer: u32 = key;
        let ret = vector::empty();

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
        let ret:vector<u32> = vector::empty();
        // walk though metadata to find all chunks
        let metadata_length = vector::length(metadata_ref);
        let pos = 1;  // skip byte #0 as it's metadata version

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

        let pos = 1; // skip byte #0 as it's metadata version

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
        let as_bytes = bcs::to_bytes(value);
        let as_bytes_length = vector::length(&as_bytes);

        // check for overflow. @todo?

        if (data_length != 0) {
            // we already have metadata chunk with id of chunk_id
            if ((as_bytes_length as u32) == ((data_length as u32) - (chunk_header_length as u32)) ) {
                // and its data length is same we are going to set it to

                let current_metadata_length = vector::length(metadata);
                let piece_added_at = current_metadata_length;
                let piece_to_be_moved_to = data_offset + (data_length as u64);

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

                let item_byte_length = 1;
                let check_for_bool = false;

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
                    let i = vector::length(&vec_as_u8);
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


        let ret:vector<u8> = vector::empty();
        let i = data_offset + 8; // skip chunk header
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

        let i = offset;
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