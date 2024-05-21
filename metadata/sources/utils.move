
module suidouble_metadata::utils {
    // use sui::bls12381;
    // use std::debug;
    // use sui::group_ops;

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

    
}