#[allow(duplicate_alias)]
module suidouble_metadata::compress {
    use std::vector; 
    // use std::debug; 

    use suidouble_metadata::asu256;
    use suidouble_metadata::indexed_vector;
    use suidouble_metadata::pack_vector;

    /// compressed data is broken
    const EBAD_LZW: u64 = 0x40000;

    // optimized based on tests ( see unit test )
    public fun compress(data_ref: &vector<u8>): vector<u8> {
        pack_vector::pack_u16_into_u8(&compress_map_16(data_ref))
    }

    // optimized based on tests ( see unit test )
    public fun decompress(data_ref: &vector<u8>): vector<u8> {
        decompress16(&pack_vector::unpack_u8_into_u16(data_ref))
    }

    /**
    *   compress vector<u8> using some LZW (Lempel-Ziv-Welch) algorithm extended with u16->u8 variable-length encoding scheme
    *      up to 8x compression on the test ascii data (see unit test)
    *      may get longer vec on shorter input vec or very random data though
    *
    *   result vector<u8> may be decoded back to original vector<u8> using `decompress` function
    *
    *    note: `sui move test --gas-limit 5000000000` is your friend
    */
    public fun compress8(data_ref: &vector<u8>): vector<u8> {
        // compress vector<u8> using something like simple LZW (Lempel-Ziv-Welch) algorithm extended with u16->u8 variable-length encoding scheme
        // fill a dictionary and add codes for it to the result stream

        // on the start dic is filled with vector<u8> = [n] where (n = 0..255)
        let mut dic = indexed_vector::new_with_bytes();

        // let mut dic: vector<vector<u8>> = vector::empty();
        // let mut i:u8 = 0;
        // while (i < 255) {
        //     vector::push_back(&mut dic, vector::singleton(i));
        //     i = i + 1;
        // };
        // vector::push_back(&mut dic, vector::singleton(255));

        let mut current:u256 = 0;
        // let mut current: vector<u8> = vector::empty();
        let mut compressed: vector<u8> = vector::empty();
        let mut last_upper_byte: u8 = 0; // if result stream upper byte is changed - we'll add a control char to indicate
        // let mut last_index_of: u64 = 0;

        let mut j:u64 = 0;
        let data_length = vector::length(data_ref);
        while (j < data_length) {
            let byte = *vector::borrow(data_ref, j);
            current = asu256::asu256_push_back(current, byte);
            // vector::push_back(&mut current, byte);

            // let (found, position) = vector::index_of(&dic, &current); // get the index to it

            // @todo: we can optimize it getting rid of `index_of` below, as we had already did up to O(N) with `contains`
            // if (found) { // if (vector::contains(&dic, &current)) {
            if (dic.contains(&current)) {
                // if we have this vec of bytes in dic - we can check for more,
                // we'll add it to the result below after else if we can't find more
                // last_index_of = position;
            } else {
                // we don't have the vec of bytes in dic, so:
                //   - we add the index to the last vec found in dic to the compressed stream 
                //   - add the new vec to the dic
                current = asu256::asu256_shift_back(current);
                // vector::pop_back(&mut current); // getting `current` back to the vec without the last byte
                
                let (found, position) = dic.index_of(&current); 
                // let (found, position) = vector::index_of(&dic, &current); // get the index to it
                if (found) {
                    // for vector<u8> results are u16, but we don't want to waste space for it, as most higher bytes are the same
                    // so lets pack them
                    // compressed byte is packed from u16 to u8, assuming we mostly have the same upper_byte (confirmed by tests on most data)
                    //    0xFF is the control byte in the u8 vec, indicating:
                    //     - upper byte is changed and next byte is the upper byte
                    //     - next byte is 0xFF too, indicating it's just 0xFF lower byte
                    let lower_byte = ( (position & 0xFF) as u8 );
                    let upper_byte = ( ((position >> 8) & 0xFF) as u8 );

                    if (upper_byte != last_upper_byte) {
                        vector::push_back(&mut compressed, 0xFF);       // indicating upper_byte is changed
                        vector::push_back(&mut compressed, upper_byte);
                        last_upper_byte = upper_byte;
                    };

                    if (lower_byte != 0xFF) {
                        vector::push_back(&mut compressed, lower_byte);
                    } else {
                        vector::push_back(&mut compressed, 0xFF); // lower FF is represented by double FF
                        vector::push_back(&mut compressed, 0xFF);
                    };
                };

                if (asu256::asu256_length(current) < 30) {
                    current = asu256::asu256_push_back(current, byte);
                    dic.push_back(current);
                };

                current =  asu256::u8_to_asu256(byte);
                // if (vector::length(&dic) < 5000) {
                //     vector::push_back(&mut current, byte); // current = extended
                //     vector::push_back(&mut dic, current); 
                // };
                
                // current = vector::singleton(byte);  // current = vec![byte];
                // last_index_of = (byte as u64);
            };

            j = j + 1;
        };

        if (current != 0) {
        // if (!vector::is_empty(&current)) {
            // doing th same as above for what we had left in the current vec
            // let (found, position) = vector::index_of(&dic, &current); 
            let (found, position) = dic.index_of(&current); //
            if (found) {
                let lower_byte = ( (position & 0xFF) as u8 );
                let upper_byte = ( ((position >> 8) & 0xFF) as u8 );

                if (upper_byte != last_upper_byte) {
                    vector::push_back(&mut compressed, 0xFF);       // indicating upper_byte is changed
                    vector::push_back(&mut compressed, upper_byte);
                    // last_upper_byte = upper_byte;
                };

                if (lower_byte != 0xFF) {
                    vector::push_back(&mut compressed, lower_byte);
                } else {
                    vector::push_back(&mut compressed, 0xFF); // lower FF is represented by double FF
                    vector::push_back(&mut compressed, 0xFF);
                };
            };
        };

        return compressed
    }

    /**
    *  Similar compression algo as `compress`, returning compressed result as vector<u16>
    *    (more bytes than u8's one returned by `compress`, as there's no variable-length encoding packing.
    *    !!! Results are not the same with result of compress8 on the byte level
    *    Little faster to run though.
    */
    public fun compress16(data_ref: &vector<u8>): vector<u16> {
        let mut dic: vector<vector<u8>> = vector::empty();
        let mut i:u8 = 0;
        while (i < 255) {
            vector::push_back(&mut dic, vector::singleton(i));
            i = i + 1;
        };
        vector::push_back(&mut dic, vector::singleton(255));

        let mut current: vector<u8> = vector::empty();
        let mut compressed: vector<u16> = vector::empty();

        let mut j:u64 = 0;
        let data_length = vector::length(data_ref);
        while (j < data_length) {
            let byte = *vector::borrow(data_ref, j);
            vector::push_back(&mut current, byte);
            if (vector::contains(&dic, &current)) {
                // has it in dic
            } else {
                vector::pop_back(&mut current); 
                let (found, position) = vector::index_of(&dic, &current); 
                if (found) {
                    vector::push_back(&mut compressed, (position as u16) ); 
                };
                
                vector::push_back(&mut current, byte);
                vector::push_back(&mut dic, current); 
                
                current = vector::singleton(byte); 
            };

            j = j + 1;
        };

        if (!vector::is_empty(&current)) {
            let (found, position) = vector::index_of(&dic, &current); 
            if (found) {
                vector::push_back(&mut compressed, (position as u16) ); 
            } else {
                abort EBAD_LZW
            };
        };

        return compressed
    }

    /**
    *  Same compression algo as `compress16`, optimized using indexed_vector and asu256 modules,
    *    runs much faster/cheaper, producing the same result as compress16
    */
    public fun compress_map_16(data_ref: &vector<u8>): vector<u16> {
        let mut dic = indexed_vector::new_with_bytes();
        let mut current:u256 = 0;
        let mut compressed: vector<u16> = vector::empty();

        let mut j:u64 = 0;
        let data_length = vector::length(data_ref);
        while (j < data_length) {
            let byte = *vector::borrow(data_ref, j);
            current = asu256::asu256_push_back(current, byte);

            if (dic.contains(&current)) {
                // has it in dic
            } else {
                current = asu256::asu256_shift_back(current);

                let (found, position) = dic.index_of(&current); 
                if (found) {
                    vector::push_back(&mut compressed, (position as u16) );
                };
                
                current = asu256::asu256_push_back(current, byte);

                if (asu256::asu256_length(current) < 30) {
                    dic.push_back(current);
                };
                
                current =  asu256::u8_to_asu256(byte);
            };

            j = j + 1;
        };

        if (current != 0) {
            let (found, position) = dic.index_of(&current); //
            if (found) {
                vector::push_back(&mut compressed, (position as u16) );  
            } else {
                abort EBAD_LZW
            };
        };

        return compressed
    }


    public fun decompress8(data_ref: &vector<u8>): vector<u8> {
        let mut dic: vector<vector<u8>> = vector::empty();
        let mut i:u8 = 0;
        while (i < 255) {
            vector::push_back(&mut dic, vector::singleton(i));
            i = i + 1;
        };
        vector::push_back(&mut dic, vector::singleton(255));

        let mut last_upper_byte: u16 = 0;
        let mut decompressed: vector<u8> = vector::empty();
        let mut first_byte = (*vector::borrow(data_ref, 0) as u16);

        let mut j:u64 = 1;

        if (first_byte == 0xFF) {
            // control byte
            let control_byte = (*vector::borrow(data_ref, 1) as u16);
            if (control_byte == 0xFF) {
                // it's just 0xFF (remember 0xFF is represented by double 0xFF in u8 stream on compression)
                first_byte = 0xFF;
            } else {
                // it's a control byte changing upper_byte for next bytes
                last_upper_byte = (control_byte as u16) << 8;
            };
            j = 2;
        };
        let mut previous_code = ( last_upper_byte | first_byte );

        vector::append(&mut decompressed, *vector::borrow(&dic, (previous_code as u64) ));

        let data_length = vector::length(data_ref);
        // let entry: vector<u8> = vector::empty();
        while (j < data_length) {
            let mut is_control_byte = false;
            let byte = (*vector::borrow(data_ref, j) as u16);
            let mut code = ( last_upper_byte | byte );
            if (byte == 0xFF) {
                // control byte
                // changes upper_byte if next one is < 0xFF
                j = j + 1;
                let control_byte = *vector::borrow(data_ref, j);
                if (control_byte == 0xFF) {
                    code = ( last_upper_byte | 0xFF );  // already did this though
                } else {
                    // change upper byte for next bytes
                    last_upper_byte = (control_byte as u16) << 8;
                    is_control_byte = true;
                };
            };

            if (!is_control_byte) {
                let cur_dic_length = vector::length(&dic);
                if ( (code as u64) < cur_dic_length ) {
                    // 
                    let entry = *vector::borrow(&dic, (code as u64) );
                    vector::append(&mut decompressed,  entry );


                    let mut to_dic = *vector::borrow(&dic, (previous_code as u64) );
                    let first_byte_in_this_entry = *vector::borrow(&entry, 0);
                    vector::push_back(&mut to_dic, first_byte_in_this_entry);
                    
                    if (vector::length(&to_dic) < 31) {
                        vector::push_back(&mut dic, to_dic);
                    };

                    
                } else if ( (code as u64) == cur_dic_length ) {
                    let mut prev_entry = *vector::borrow(&dic, (previous_code as u64) );
                    let first_byte_in_prev_entry = *vector::borrow(&prev_entry,0);
                    vector::push_back(&mut prev_entry, first_byte_in_prev_entry);
                    
                    if (vector::length(&prev_entry) < 31) {
                        vector::push_back(&mut dic, prev_entry);
                    };
                    vector::append(&mut decompressed,  prev_entry ); 
                } else {
                    abort EBAD_LZW
                };
                previous_code = code;
            };

            j = j + 1;
        };

        decompressed
    }

    public fun decompress16(data_ref: &vector<u16>): vector<u8> {
        let mut dic: vector<vector<u8>> = vector::empty();
        let mut i:u8 = 0;
        while (i < 255) {
            vector::push_back(&mut dic, vector::singleton(i));
            i = i + 1;
        };
        vector::push_back(&mut dic, vector::singleton(255));

        let mut decompressed: vector<u8> = vector::empty();
        let mut previous_code = *vector::borrow(data_ref, 0);

        vector::append(&mut decompressed, *vector::borrow(&dic, (previous_code as u64) ));

        let mut j:u64 = 1;
        let data_length = vector::length(data_ref);
        // let entry: vector<u8> = vector::empty();
        while (j < data_length) {
            let code = *vector::borrow(data_ref, j);
            let cur_dic_length = vector::length(&dic);
            if ( (code as u64) < cur_dic_length ) {
                // 
                let entry = *vector::borrow(&dic, (code as u64) );
                vector::append(&mut decompressed,  entry );


                let mut to_dic = *vector::borrow(&dic, (previous_code as u64) );
                let first_byte_in_this_entry = *vector::borrow(&entry, 0);
                vector::push_back(&mut to_dic, first_byte_in_this_entry);

                if (vector::length(&to_dic) < 30) {
                    vector::push_back(&mut dic, to_dic);
                };                
            } else if ( (code as u64) == cur_dic_length ) {
                let mut prev_entry = *vector::borrow(&dic, (previous_code as u64) );
                let first_byte_in_prev_entry = *vector::borrow(&prev_entry,0);
                vector::push_back(&mut prev_entry, first_byte_in_prev_entry);
                
                if (vector::length(&prev_entry) < 30) {
                    vector::push_back(&mut dic, prev_entry);
                };
                vector::append(&mut decompressed,  prev_entry ); 

            };

            j = j + 1;
            previous_code = code;
        };

        decompressed
    }



}