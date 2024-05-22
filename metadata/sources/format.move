
module suidouble_metadata::format {
    // use sui::bls12381;
    // use std::debug;
    use std::string;
    use suidouble_metadata::metadata;
    // use sui::address;
    use std::ascii;
    // use std::type_name;
    use sui::hex;
    // use std::string;
    // use sui::group_ops;


    // char codes here, just as consts
    const FORMAT_DISPLAY_TYPE_x:u8 = 120; // hex, lowercased 0x0000fafafa
    const FORMAT_DISPLAY_TYPE_X:u8 = 88;  // hex, uppercased 0x0000FAFAFA
    const FORMAT_DISPLAY_TYPE_y:u8 = 121; // hex, lowercased, without first 0s - 0xfafafa
    const FORMAT_DISPLAY_TYPE_Y:u8 = 89;  // hex, uppercased, without first 0s - 0xFAFAFA
    const FORMAT_DISPLAY_TYPE_B:u8 = 66;  // bool
    const FORMAT_DISPLAY_TYPE_s:u8 = 115; // string
    const FORMAT_DISPLAY_TYPE_a:u8 = 97;  // array of numbers
    const FORMAT_DISPLAY_TYPE_A:u8 = 65;  // array of hex, lowercased
    const FORMAT_DISPLAY_TYPE_i:u8 = 105; // number

    // just a wrapper for format function accepting std::ascii String and returning it
    public fun format_ascii(ascii_str_ref: &ascii::String, meta: &vector<u8>): ascii::String {
        ascii::string(format(ascii::as_bytes(ascii_str_ref), meta))
    }

    // just a wrapper for format function accepting std::string String and returning it
    public fun format_string(string_str_ref: &string::String, meta: &vector<u8>): string::String {
        string::utf8(format(string::bytes(string_str_ref), meta))
    }

    // format a string using Rust-style format syntax, using metadata vector for arguments,
    //    like format(&"Hey {}", metadata::single(&b"world")) returns b"Hey world"
    //         format(&"Hey, your balance is {}", metadata::single(&999u64)) returns b"Hey, your balance is 999"
    //    
    //    supports keys:
    //          metadata::set(&mut bytes, metadata::key(&b"int"), &300u64);
    //          metadata::set(&mut bytes, metadata::key(&b"string"), &b"world");
    //          metadata::set(&mut bytes, metadata::key(&b"array"), &bvector<u64>[1,2,3]);
    //         format(&"Hey {string}, your balance is {int}, {array}", &bytes) returns b"Hey world, your balance is 300, [1,2,3]"
    //    
    //    supports formating flags
    //         format(&"Hey {:X}", metadata::single(&b"world")) returns b"Hey 0x05776F726C64"
    //         format(&"Hey {:x}", metadata::single(&b"world")) returns b"Hey 0x05776f726c64"
    // 
    public fun format(str_ref: &vector<u8>, meta: &vector<u8>): vector<u8> {
        // scan format string bytes, trying to find sequences of {..}
        // {{ - is escaped {     }} - is escaped }}
        let mut ret:vector<u8> = b"";
        let str_length = vector::length(str_ref);
        let mut i = 0;
        let mut was_inserted_count = 0;

        while (i < str_length) {
            let first_byte = *vector::borrow(str_ref, i);
            if (first_byte == 123 && str_length > (i+1)) {  // '{' == 123
                // check that next one is not '{'
                let second_byte = *vector::borrow(str_ref, i + 1);
                if (second_byte != 123) { // if it's not an escape for {
                    // scan for closing '}'
                    let mut piece_format_options:vector<u8> = b""; // options inside {}, like 'name' from '{name}' 
                    if (second_byte == 125) { // '}' == 125
                        // options empty, it was just {}
                        // insert into position i
                        append_format_piece(&mut ret, &piece_format_options, was_inserted_count, meta);
                        was_inserted_count = was_inserted_count + 1; // no need to check if append was not named as options were empty

                        i = i + 1;
                    } else {
                        vector::push_back(&mut piece_format_options, second_byte);
                        let mut closing_bracket_found = false;
                        let mut j = i + 2;
                        while (!closing_bracket_found && str_length > j ) {
                            let next_byte = *vector::borrow(str_ref, j);
                            if (next_byte == 125) {
                                closing_bracket_found = true;
                            } else {
                                vector::push_back(&mut piece_format_options, next_byte);
                            };

                            j = j + 1;
                        };
                        // insert into position i
                        let was_not_named = append_format_piece(&mut ret, &piece_format_options, was_inserted_count, meta);
                        if (was_not_named) {
                            was_inserted_count = was_inserted_count + 1;
                        };

                        i = j - 1;                        
                    };
                } else {
                    // just push { to the result
                    vector::push_back(&mut ret, 123);
                    i = i + 1; // skip escaped
                };
            } else {
                // just push char to results
                vector::push_back(&mut ret, first_byte);
            };

            i = i + 1;
        };

        ret
    }

    
    // convert u256 number to binary string of its representation, 98765u256 -> b"98765"
    public fun u256_to_string(v: u256): vector<u8> {
        let mut r = v;
        let mut ret = vector::empty();
        while (r != 0) {
            vector::push_back(&mut ret, ((48 + r % 10) as u8));
            r = r / 10;
        };
        vector::reverse(&mut ret);

        ret
    }

    public fun vu8_to_hex(vec_ref: &vector<u8>, skip_empties: bool, uppercase: bool): vector<u8> {
        let mut ret:vector<u8> = vector::empty();
        let mut i = 0;
        let mut letter_shift = 87;
        if (uppercase) {
            letter_shift = 55;
        };
        let vec_length = vector::length(vec_ref);
        if (vec_length == 0) {
            return ret
        };

        // check if it's metadata of vector<u8>, first byte is length of bytes
        // not the perfect catch, as  would be formatted
        let first_byte = *vector::borrow(vec_ref, 0);
        if (first_byte > 0 && (first_byte as u64) == vec_length - 1) {
            // first byte is vector length of vector < 255,
            // lets skip it from displaying
            i = 1;
        };

        let mut met_not_zero = !skip_empties;

        while (i < vec_length) {
            let byte = *vector::borrow(vec_ref, i);
            
            if (byte != 0 || met_not_zero) {
                let high_byte = (byte >> 4);
                let low_byte = (byte & 0x0F);

                if (high_byte > 9) {
                    ret.push_back(high_byte + letter_shift);
                } else {
                    ret.push_back(high_byte + 48);
                };

                if (low_byte > 9) {
                    ret.push_back(low_byte + letter_shift);
                } else {
                    ret.push_back(low_byte + 48);
                };

                met_not_zero = true;
            };

            i = i + 1;
        };

        ret
    }

    // convert u256 to binary hex string, 255u256 -> b"FF"
    public fun u256_to_hex(v: u256): vector<u8> {
        let mut bytes:vector<u8> = vector::empty();
        let mut r = v;
        let mut had_not_0 = false;
        while (r != 0) {
            let byte = ((r % 256) as u8);
            if (byte > 0 || had_not_0) {
                vector::push_back(&mut bytes, byte);
                had_not_0 = true;
            };
            r = r / 256;
        };

        hex::encode(bytes)
    }

    // converts boolean to binary string of it -> b"true"  or -> b"false"
    public fun bool_to_string(v: bool): vector<u8> {
        if (v) {
            return b"true"
        };
        b"false"
    }

    /// same as ascii::is_printable_char, but allowing "\n" too
    /// Returns `true` if `byte` is an printable ASCII character. Returns `false` otherwise.
    public fun is_printable_char(byte: u8): bool {
       byte == 10 || 
       (byte >= 0x20 && // Disallow metacharacters
       byte < 0x7E) // Don't allow DEL metacharacter
    }

    // function to check if vector<u8> looks like a printable binary string, just guessing
    public fun looks_like_a_string(meta: &vector<u8>, chunk_id: u32) : bool {
        let bytes = metadata::get_vec_u8(meta, chunk_id);
        let mut i = 0;
        let length = vector::length(&bytes);
        if (length == 0) {
            return false
        };

        while (i < length) {
            if (!is_printable_char(*vector::borrow(&bytes, i))) {
                return false
            };
            i = i + 1;
        };

        true
    }

    // get binary string of to_string for specific chunk of metadata
    //    meta - &to vector<u8> created with suidouble_metadata module
    //    chunk_id - u32 key for the chunk, mostly it's result of medatadata::key(b"propertyname")
    //    optional format_options_ref - Rust-format-style flags as binary string
    //        ":x" - hex, lowercased 0x00fafafa
    //        ":X" - hex, uppercased 0x00FAFAFA
    //        ":y" - hex, lowercased without leading empty bytes - 0xfafafa
    //        ":Y" - hex, uppercased without leading empty bytes - 0xFAFAFA
    //        ":B" - bool, "true" or "false"
    //        ":s" - binary string as in b"string"
    //        ":a" - array of numbers, for metadata set as metadata::set(&mut meta, 1, &vector<u8>[1,2,3]) -> result string is "[1,2,3]"
    //        ":A" - array of hex, for metadata set as metadata::set(&mut meta, 1, &vector<u8>[1,2,3]) -> result string is "[0x01,0x02,0x03]"
    //        ":i" - number, just an integer value as binary string
    //
    //  returns binary string representation for a chunk ( feel free to use returning vector in std::ascii or std::string )
    //     in case chunk is not found or something is wrong, returns b"{???}"
    public fun meta_chunk_to_string(meta: &vector<u8>, chunk_id: u32, format_options_ref: &vector<u8>) : vector<u8> {
        if (!metadata::has_chunk(meta, chunk_id)) {
            return b"{???}"
        };

        let mut needed_format = FORMAT_DISPLAY_TYPE_x;
        if (format_options_ref == b"") {
            // if no forced format options, lets guess needed format
            if (metadata::has_chunk_of_type<bool>(meta, chunk_id)) { 
                needed_format = FORMAT_DISPLAY_TYPE_B; // bool
            } else if (metadata::has_chunk_of_type<address>(meta, chunk_id)) {
                needed_format = FORMAT_DISPLAY_TYPE_y; // 0xfffaaa999 hex string, without zeros at the start
            } else if (metadata::has_chunk_of_type<u8>(meta, chunk_id) || 
                metadata::has_chunk_of_type<u64>(meta, chunk_id) || 
                metadata::has_chunk_of_type<u128>(meta, chunk_id) || 
                metadata::has_chunk_of_type<u256>(meta, chunk_id) 
            ) {
                needed_format = FORMAT_DISPLAY_TYPE_i; // number
            } else if (
                metadata::has_chunk_of_type<vector<u16>>(meta, chunk_id) || 
                metadata::has_chunk_of_type<vector<u32>>(meta, chunk_id) || 
                metadata::has_chunk_of_type<vector<u64>>(meta, chunk_id)
                ) 
            {
                needed_format = FORMAT_DISPLAY_TYPE_a; // vector of numbers
            } else if (metadata::has_chunk_of_type<vector<u8>>(meta, chunk_id) && looks_like_a_string(meta, chunk_id)) {
                needed_format = FORMAT_DISPLAY_TYPE_s; // binary string
            }  else if (metadata::has_chunk_of_type<vector<u128>>(meta, chunk_id) ||
                metadata::has_chunk_of_type<vector<u256>>(meta, chunk_id)
                )
            {
                // vector<address> is here too, as it's same as u256
                needed_format = FORMAT_DISPLAY_TYPE_A; // vector of hex strings
            } else {
                needed_format = FORMAT_DISPLAY_TYPE_x; // hex string
            };
        } else {
            if (*vector::borrow(format_options_ref, 0) == 58) { // ":"
                needed_format = *vector::borrow(format_options_ref, 1);
            };
        };

        if (needed_format == FORMAT_DISPLAY_TYPE_B) {
            return bool_to_string(metadata::get_bool(meta, chunk_id, false))
        } else if (needed_format == FORMAT_DISPLAY_TYPE_i) {
            // get any uNNN number as u256
            let number = metadata::get_any_u256(meta, chunk_id, 0);
            return u256_to_string(number)
        } else if (needed_format == FORMAT_DISPLAY_TYPE_s) {
            // just append binary string bytes
            let bytes = metadata::get_vec_u8(meta, chunk_id);
            return bytes
        } else if (needed_format == FORMAT_DISPLAY_TYPE_a) {
            // array of numbers
            // try to get any possible vec as vector<u256>
            let vec = metadata::get_any_vec_u256(meta, chunk_id);
            let mut ret:vector<u8> = b"[";
            let mut i = 0;
            let vec_length = vector::length(&vec);
            if (vec_length == 0) {
                return b"[]"
            };

            while (i < vec_length) {
                let as_string = u256_to_string(*vector::borrow(&vec, i));
                vector::append(&mut ret, as_string);
                vector::append(&mut ret, b", ");
                i = i + 1;
            };
            vector::pop_back(&mut ret); // remove last ", "
            vector::pop_back(&mut ret);
            vector::append(&mut ret, b"]");
            return ret
        }  else if (needed_format == FORMAT_DISPLAY_TYPE_A) {
            // array of hex, lowercased
            // try to get any possible vec as vector<u256>
            let vec = metadata::get_any_vec_u256(meta, chunk_id);
            let mut ret:vector<u8> = b"[0x";
            let mut i = 0;
            let vec_length = vector::length(&vec);
            if (vec_length == 0) {
                return b"[]"
            };

            while (i < vec_length) {
                let as_string = u256_to_hex(*vector::borrow(&vec, i));
                vector::append(&mut ret, as_string);
                vector::append(&mut ret, b", 0x");
                i = i + 1;
            };
            vector::pop_back(&mut ret); // remove last ", 0x"
            vector::pop_back(&mut ret);
            vector::pop_back(&mut ret);
            vector::pop_back(&mut ret);
            vector::append(&mut ret, b"]");

            return ret
        } else if (needed_format == FORMAT_DISPLAY_TYPE_y) {
            let opt = metadata::get(meta, chunk_id);
            let bytes = option::destroy_with_default(opt, vector::empty());

            let mut ret = b"0x";
            vector::append(&mut ret, vu8_to_hex(&bytes, true, false));

            return ret
        }  else if (needed_format == FORMAT_DISPLAY_TYPE_x) {
            let opt = metadata::get(meta, chunk_id);
            let bytes = option::destroy_with_default(opt, vector::empty());

            let mut ret = b"0x";
            vector::append(&mut ret, vu8_to_hex(&bytes, false, false));

            return ret
        }  else if (needed_format == FORMAT_DISPLAY_TYPE_Y) {
            let opt = metadata::get(meta, chunk_id);
            let bytes = option::destroy_with_default(opt, vector::empty());

            let mut ret = b"0x";
            vector::append(&mut ret, vu8_to_hex(&bytes, true, true));

            return ret
        }  else if (needed_format == FORMAT_DISPLAY_TYPE_X) {
            let opt = metadata::get(meta, chunk_id);
            let bytes = option::destroy_with_default(opt, vector::empty());

            let mut ret = b"0x";
            vector::append(&mut ret, vu8_to_hex(&bytes, false, true));

            return ret
        } else {
            let opt = metadata::get(meta, chunk_id);
            let mut ret = b"0x";
            vector::append(&mut ret, hex::encode(option::destroy_with_default(opt, vector::empty())));

            return ret
        }
    }

    // append next formatted as binary string piece into vector `to`
    //   format_options_ref string containing inside a tag, like b"key:A" for tag: "{key:A}" or b"" for empty "{}"
    //   was_inserted_count - count of not-named tags inserted in this format, so we can take next chunk from metadata
    //                        chunks are indexed in the order they inserted into metadata, not by key
    fun append_format_piece(to: &mut vector<u8>, format_options_ref: &vector<u8>, was_inserted_count: u64, meta: &vector<u8>): bool {
        // first step, check if there's named in format_options
        if (vector::length(format_options_ref) > 0) {                   // try to find tag for chunk with key     
                                                                             // as for {key:format}
            let mut possible_chunk_key:vector<u8> = b"";                     // this will hold "key"
            let mut still_after_format_flag:vector<u8> = vector::empty();    // this will hold ":format"

            if (*vector::borrow(format_options_ref, 0) != 58) { // not starting with ":", which is the flag for output format
                // get everything till the ":" or the end
                let mut i = 0;
                let format_options_length = vector::length(format_options_ref);
                let mut met_format_flag = false;
                while (i < format_options_length) {
                    let byte = *vector::borrow(format_options_ref, i);
                    if (met_format_flag) {
                        // part after "key:", so it's a output format
                        vector::push_back(&mut still_after_format_flag, byte);
                    } else {
                        if (byte == 58) { // ":"
                            met_format_flag = true;
                            vector::push_back(&mut still_after_format_flag, 58);
                        } else {
                            vector::push_back(&mut possible_chunk_key, byte);
                        };
                    };

                    i = i + 1;
                };
            };

            if (vector::length(&possible_chunk_key) > 0) {
                // if we are here, means we find {tag} with key "tag"
                if (metadata::has_chunk(meta, metadata::key(&possible_chunk_key))) {
                    // we are good
                    let chunk_as_string = meta_chunk_to_string(meta, metadata::key(&possible_chunk_key), &still_after_format_flag);
                    vector::append(to, chunk_as_string);

                    return false // returns false, means we used named tag, no need to increment used tag counter 
                } else {
                    vector::append(to, b"{???}");

                    return false // returns false, means we used named tag, no need to increment used tag counter 
                }
            };
        };

        // if we are here, means there's no named tag, but may be format, as {:A}
        let chunk_ids = metadata::get_chunks_ids(meta);
        if (was_inserted_count < vector::length(&chunk_ids)) {
            // take the next chunk from metadata
            let chunk_id = *vector::borrow(&chunk_ids, was_inserted_count);

            // to binary string it
            let chunk_as_string = meta_chunk_to_string(meta, chunk_id, format_options_ref);
            
            // and append to the mut vector
            vector::append(to, chunk_as_string);

            return true // returns true, means we used next metadata chunk, parent function has to increment counter, so we'll use next one next time 
        } else {
            // if there're no more chunks in metadata
            vector::append(to, b"{???}");

            return true // returns true, means we used next metadata chunk, parent function has to increment counter, so we'll use next one next time 
        }
    }

    #[test]
    fun test_strings_objects() {
        let ascii_string = ascii::string(b"Try format as String object, {}, ok?");
        let output_ascii_string = format_ascii(&ascii_string, &metadata::single(&b"world"));
        assert!(output_ascii_string.into_bytes() == b"Try format as String object, world, ok?", 0);

        let utf8_string = string::utf8(b"Try format as String 💧 object, {:s}, ok?");         // emoji not recognized as printable automatically, force s
        let output_utf8_string = format_string(&utf8_string, &metadata::single(&b"w🌐rld"));
        assert!(output_utf8_string.bytes() == b"Try format as String 💧 object, w🌐rld, ok?", 0);
    }

    #[test]
    fun test_format() {

        assert!(format(&b"Hey {}", &metadata::single(&b"world")) == b"Hey world", 0);            // guess arg is string
        assert!(format(&b"Hey {}", &metadata::single(&b"wor\nld")) == b"Hey wor\nld", 0);        // "\n" is allowed to be in auto-detected string
        assert!(format(&b"Hey {:s}", &metadata::single(&b"world")) == b"Hey world", 0);          // force arg as string

        // few args
        let mut meta:vector<u8> = b"";
        metadata::set(&mut meta, metadata::key(&b"what"), &b"world");
        metadata::set(&mut meta, metadata::key(&b"balance"), &91u8);

        assert!(format(&b"Hey {:s} {}", &meta) == b"Hey world 91", 0);                               // few args
        assert!(format(&b"Hey {balance:i} {what}", &meta) == b"Hey 91 world", 0);                    // key args
        assert!(format(&b"Hey {what} {balance:i}, {balance:x}", &meta) == b"Hey world 91, 0x5b", 0); // key args, few of same
        assert!(format(&b"Hey {what} {balance:i}, {}", &meta) == b"Hey world 91, world", 0); // mixed key args and N args

        // format options
        assert!(format(&b"Hey {:x}", &metadata::single(&b"world")) == b"Hey 0x776f726c64", 0); // force format as hex string
        assert!(format(&b"Hey {:X}", &metadata::single(&b"world")) == b"Hey 0x776F726C64", 0); // force format as hex string
        assert!(format(&b"Hey {}", &metadata::single(&@0xBABE)) == b"Hey 0xbabe", 0); // address
        assert!(format(&b"Hey {:A}",  &metadata::single(&vector<address>[@0xBABE]) ) == b"Hey [0xbabe]", 0); // array of addresses
        assert!(format(&b"Hey {:i}", &metadata::single(&19u128)) == b"Hey 19", 0); // number


        assert!(format(&b"Hey {:a}",  &metadata::single(&vector<u64>[1,2,3,4,9999]) ) == b"Hey [1, 2, 3, 4, 9999]", 0); // vector of numbers
        assert!(format(&b"Hey {:a}",  &metadata::single(&vector<u128>[1,2,3,4,9999]) ) == b"Hey [1, 2, 3, 4, 9999]", 0); // vector of numbers
        assert!(format(&b"Hey {:a}",  &metadata::single(&vector<u256>[1,2,3,4,9999]) ) == b"Hey [1, 2, 3, 4, 9999]", 0); // vector of numbers
        assert!(format(&b"Hey {:a}",  &metadata::single(&vector<u8>[1,2,3,4,255]) ) == b"Hey [1, 2, 3, 4, 255]", 0); // vector of numbers

        assert!(format(&b"Hey {:A}",  &metadata::single(&vector<u8>[1,2,3,4,255]) ) == b"Hey [0x01, 0x02, 0x03, 0x04, 0xff]", 0); // vector as hex values



        // edge cases
        assert!(format(&b"Hey {", &meta) == b"Hey {", 0);    
        assert!(format(&b"Hey {{", &meta) == b"Hey {", 0);     // "{{" is an escape key for "{"
        assert!(format(&b"Hey {z", &meta) == b"Hey {???}", 0);   
        assert!(format(&b"Hey {nothing}", &meta) == b"Hey {???}", 0);     // nothing is the key we don't have in metadata
        assert!(format(&b"Hey {nothing:A}", &meta) == b"Hey {???}", 0);   
        assert!(format(&b"Hey {nothing:q}", &meta) == b"Hey {???}", 0);   // q is the format key we don't have
        assert!(format(&b"Hey {{} {", &meta) == b"Hey {} {", 0);      
        assert!(format(&b"Hey {} {}", &metadata::single(&b"world")) == b"Hey world {???}", 0);    
        assert!(format(&b"Hey {} {} {}", &metadata::single(&b"world")) == b"Hey world {???} {???}", 0);    


        // debug::print(&utf8(str));
        // debug::print(&utf8(res));
    }


    
}