
module suidouble_metadata::compress {
    use std::vector;
    friend suidouble_metadata::metadata;
    use std::debug;

    /// u16 is too large to be packed into u8
    const ETOO_LARGE_U16: u64 = 0x30000;

    /// compressed data is broken
    const EBAD_LZW: u64 = 0x40000;

    public fun compress(data_ref: &vector<u8>): vector<u8> {
        pack_u16_into_u8(&compress16(data_ref))
    }

    public fun decompress(data_ref: &vector<u8>): vector<u8> {
        decompress16(&unpack_u8_into_u16(data_ref))
    }

    /**
    *   compress vector<u8> using some LZW (Lempel-Ziv-Welch) algorithm extended with u16->u8 variable-length encoding scheme
    *      up to 8x compression on the test ascii data (see unit test)
    *      2.7x - 9066 bytes -> 3381 bytes on SVG of "sui" from sui's site logo: https://assets-global.website-files.com/6425f546844727ce5fb9e5ab/65690e5e73e9e2a416e3502f_sui-mark.svg
    *      may get longer vec on shorter input vec though
    *
    *   result vector<u8> may be decoded back to original vector<u8> using `decompress` function
    *
    *   It's expensive!!! Confider compressing data on the client side and pass to contract methods already compressed. 
    *   Decompressing is much faster/cheaper. 
    *
    *    note: `sui move test --gas-limit 5000000000` is your friend
    *
    *   @todo: would be much cheaper with some sort of HashMap instead of vector<vector<u8>> for dictionary.
    */
    public fun compress8(data_ref: &vector<u8>): vector<u8> {
        // compress vector<u8> using something like simple LZW (Lempel-Ziv-Welch) algorithm extended with u16->u8 variable-length encoding scheme
        // fill a dictionary and add codes for it to the result stream
        let dic: vector<vector<u8>> = vector::empty();
        let i:u8 = 0;
        while (i < 255) {
            vector::push_back(&mut dic, vector::singleton(i));
            i = i + 1;
        };
        vector::push_back(&mut dic, vector::singleton(255));
        // on the start dic is filled with vector<u8> = [n] where (n = 0..255)

        let current: vector<u8> = vector::empty();
        let compressed: vector<u8> = vector::empty();
        let last_upper_byte: u8 = 0; // if result stream upper byte is changed - we'll add a control char to indicate
        let last_index_of: u64 = 0;

        let j:u64 = 0;
        let data_length = vector::length(data_ref);
        while (j < data_length) {
            let byte = *vector::borrow(data_ref, j);
            vector::push_back(&mut current, byte);

            let (found, position) = vector::index_of(&dic, &current); // get the index to it

            // @todo: we can optimize it getting rid of `index_of` below, as we had already did up to O(N) with `contains`
            if (vector::contains(&dic, &current)) {
                // if we have this vec of bytes in dic - we can check for more,
                // we'll add it to the result below after else if we can't find more
                last_index_of = position;
            } else {
                // we don't have the vec of bytes in dic, so:
                //   - we add the index to the last vec found in dic to the compressed stream 
                //   - add the new vec to the dic
                vector::pop_back(&mut current); // getting `current` back to the vec without the last byte
                let (found, position) = vector::index_of(&dic, &current); // get the index to it
                if (found) {
                    if (position != last_index_of) {
                        debug::print(&position);
                        debug::print(&last_index_of);
                        debug::print(&0);
                    };
                    // it's expected to be always found here, actually, as it's the first time we are in this `else` after nuling `current` vec
                    // so we can add index to the compressed vec
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

                if (vector::length(&dic) < 5000) {
                    vector::push_back(&mut current, byte); // current = extended
                    vector::push_back(&mut dic, current); 
                };
                
                current = vector::singleton(byte);  // current = vec![byte];
                last_index_of = (byte as u64);
            };

            j = j + 1;
        };

        if (!vector::is_empty(&current)) {
            // doing th same as above for what we had left in the current vec
            let (found, position) = vector::index_of(&dic, &current); 
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
    *  Same compression algo as `compress`, returning little result as vector<u16> 
    *    (more bytes than u8's one returned by `compress`, as there's no variable-length encoding packing.
    *    Little faster to run though.
    */
    public fun compress16(data_ref: &vector<u8>): vector<u16> {
        let dic: vector<vector<u8>> = vector::empty();
        // let mut dict: Vec<Vec<u8>> = (0..=255).map(|i| vec![i as u8]).collect();
        let i:u8 = 0;
        while (i < 255) {
            vector::push_back(&mut dic, vector::singleton(i));
            i = i + 1;
        };
        vector::push_back(&mut dic, vector::singleton(255));

        let current: vector<u8> = vector::empty();
        let compressed: vector<u16> = vector::empty();

        let j:u64 = 0;
        let data_length = vector::length(data_ref);
        while (j < data_length) {
            let byte = *vector::borrow(data_ref, j);
            // let mut extended = current.clone();
            // extended.push(byte);
            vector::push_back(&mut current, byte);
            if (vector::contains(&dic, &current)) {
                // has it in dic
            } else {
                vector::pop_back(&mut current); // current = currrent
                let (found, position) = vector::index_of(&dic, &current); // let position = dict.iter().position(|entry| *entry == current).unwrap();
                if (found) {
                    vector::push_back(&mut compressed, (position as u16) );  // compressed.push(position as u8);
                };
                
                vector::push_back(&mut current, byte); // current = extended
                vector::push_back(&mut dic, current); 
                
                current = vector::singleton(byte);  // current = vec![byte];
            };

            j = j + 1;
        };

        if (!vector::is_empty(&current)) {
            let (found, position) = vector::index_of(&dic, &current); // let position = dict.iter().position(|entry| *entry == current).unwrap();
            if (found) {
                vector::push_back(&mut compressed, (position as u16) );  // compressed.push(position as u8);
            } else {
                abort EBAD_LZW
            };
        };

        return compressed
    }

    public fun decompress8(data_ref: &vector<u8>): vector<u8> {
        let dic: vector<vector<u8>> = vector::empty();
        let i:u8 = 0;
        while (i < 255) {
            vector::push_back(&mut dic, vector::singleton(i));
            i = i + 1;
        };
        vector::push_back(&mut dic, vector::singleton(255));

        let last_upper_byte: u16 = 0;
        let decompressed: vector<u8> = vector::empty();
        let first_byte = (*vector::borrow(data_ref, 0) as u16);

        let j:u64 = 1;

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
        let previous_code = ( last_upper_byte | first_byte );

        vector::append(&mut decompressed, *vector::borrow(&dic, (previous_code as u64) ));

        let data_length = vector::length(data_ref);
        // let entry: vector<u8> = vector::empty();
        while (j < data_length) {
            let is_control_byte = false;
            let byte = (*vector::borrow(data_ref, j) as u16);
            let code = ( last_upper_byte | byte );
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


                    if (vector::length(&dic) < 5000) {
                        let to_dic = *vector::borrow(&dic, (previous_code as u64) );
                        let first_byte_in_this_entry = *vector::borrow(&entry, 0);
                        vector::push_back(&mut to_dic, first_byte_in_this_entry);
                        vector::push_back(&mut dic, to_dic);

                    };

                    
                } else if ( (code as u64) == cur_dic_length ) {
                    let prev_entry = *vector::borrow(&dic, (previous_code as u64) );
                    let first_byte_in_prev_entry = *vector::borrow(&prev_entry,0);
                    vector::push_back(&mut prev_entry, first_byte_in_prev_entry);
                    
                    if (vector::length(&dic) < 5000) {
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
        let dic: vector<vector<u8>> = vector::empty();
        let i:u8 = 0;
        while (i < 255) {
            vector::push_back(&mut dic, vector::singleton(i));
            i = i + 1;
        };
        vector::push_back(&mut dic, vector::singleton(255));

        let decompressed: vector<u8> = vector::empty();
        let previous_code = *vector::borrow(data_ref, 0);

        vector::append(&mut decompressed, *vector::borrow(&dic, (previous_code as u64) ));

        let j:u64 = 1;
        let data_length = vector::length(data_ref);
        // let entry: vector<u8> = vector::empty();
        while (j < data_length) {
            let code = *vector::borrow(data_ref, j);
            let cur_dic_length = vector::length(&dic);
            if ( (code as u64) < cur_dic_length ) {
                // 
                let entry = *vector::borrow(&dic, (code as u64) );
                vector::append(&mut decompressed,  entry );


                let to_dic = *vector::borrow(&dic, (previous_code as u64) );
                let first_byte_in_this_entry = *vector::borrow(&entry, 0);
                vector::push_back(&mut to_dic, first_byte_in_this_entry);
                vector::push_back(&mut dic, to_dic);

                
            } else if ( (code as u64) == cur_dic_length ) {
                let prev_entry = *vector::borrow(&dic, (previous_code as u64) );
                let first_byte_in_prev_entry = *vector::borrow(&prev_entry,0);
                vector::push_back(&mut prev_entry, first_byte_in_prev_entry);
                
                vector::push_back(&mut dic, prev_entry);
                vector::append(&mut decompressed,  prev_entry ); 
            };

            j = j + 1;
            previous_code = code;
        };

        decompressed
    }

    public fun pack_u16_into_u8(data_ref: &vector<u16>): vector<u8> {
        let i:u64 = 0;
        let data_length = vector::length(data_ref);
        let last_upper_byte: u8 = 0;
        let ret: vector<u8> = vector::empty();

        vector::push_back(&mut ret, 0x01);  // first byte of 1 indicates we are trying to use variable-length encoding scheme
                            // on most test data it produces byte length < byte length of input
                            // though on very random sets - result may come up larger, in that case - we'll switch it to basic u16->two bytes later

        while (i < data_length) {
            let code = *vector::borrow(data_ref, i);

            let lower_byte = ( (code & 0xFF) as u8 );
            let upper_byte = ( ((code >> 8) & 0xFF) as u8 );

            if (upper_byte == 0xFF) {
                abort ETOO_LARGE_U16
            };

            if (upper_byte != last_upper_byte) {
                vector::push_back(&mut ret, 0xFF);       // indicating upper_byte is changed
                vector::push_back(&mut ret, upper_byte);
                last_upper_byte = upper_byte;
            };

            if (lower_byte != 0xFF) {
                vector::push_back(&mut ret, lower_byte);
            } else {
                vector::push_back(&mut ret, 0xFF); // lower FF is represented by double FF
                vector::push_back(&mut ret, 0xFF);
            };

            i = i + 1;
        };

        if (vector::length(&ret) > (1 + vector::length(data_ref)*2)) {
            ret = vector::empty();
            vector::push_back(&mut ret, 0x00); // first byte of 0 indicates we were not lucky with variable-length encoding and use basic u16->two bytes

            i = 0;
            while (i < data_length) {
                let code = *vector::borrow(data_ref, i);
                vector::push_back(&mut ret, ( ((code >> 8) & 0xFF) as u8 )); // upper_byte
                vector::push_back(&mut ret, ( (code & 0xFF) as u8 )); // lower_byte
                i = i + 1;
            };
        };

        return ret
    }

    public fun unpack_u8_into_u16(data_ref: &vector<u8>): vector<u16> {
        let data_length = vector::length(data_ref);
        let ret: vector<u16> = vector::empty();

        if (data_length <= 1) { // as we have control byte #0
            return vector::empty()
        };

        let encoding_scheme_type = *vector::borrow(data_ref, 0);
        let i:u64 = 1;
        if (encoding_scheme_type == 0x00) {
            // basic u16->u8 conversion
            while (i < data_length) {
                let upper_byte = (*vector::borrow(data_ref, i) as u16)  << 8;
                let lower_byte = (*vector::borrow(data_ref, i + 1) as u16);
                vector::push_back(&mut ret, ( upper_byte | lower_byte ) );

                i = i + 2;
            };
        } else if (encoding_scheme_type == 0x01) {
            // variable-length encoding scheme
            let last_upper_byte: u16 = 0;

            while (i < data_length) {
                let byte = (*vector::borrow(data_ref, i) as u16);
                if (byte == 0xFF) { 
                    // special one
                    // changes upper_byte if next one is < 0xFF
                    i = i + 1;
                    let control_byte = *vector::borrow(data_ref, i);
                    if (control_byte == 0xFF) {
                        byte = 0xFF;
                        vector::push_back(&mut ret, ( last_upper_byte | byte ) );
                    } else {
                        last_upper_byte = (control_byte as u16) << 8;
                    };
                } else {
                    vector::push_back(&mut ret, ( last_upper_byte | byte ) );
                };

                i = i + 1;
            };
        };
        // can abort an error on else here, but I personally don't need this, it would just return empty array if input is broken
        // you can add wrapper function to check result and abort

        return ret
    }


}