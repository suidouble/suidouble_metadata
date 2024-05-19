
module suidouble_metadata::pack_vector {
// function to pack vector<u16> into vector<u8> using u16->u8 variable-length encoding scheme
//   useful in combination with compress module functions
//   in most cases pack_u16_into_u8() produces vector<u8> shorter than (length(vector<u16>)*2)
//
//   - if variable-length encoding is not possible or vector is too random - goes with basic 2 bytes encoding
//   - the first byte in result vector<u8> is control byte:
//       1 - variable-length encoding
//       0 - basic u16->two bytes

    // pack vector<u16> into vector<u8> with variable-length encoding 
    public fun pack_u16_into_u8(data_ref: &vector<u16>): vector<u8> {
        let mut i:u64 = 0;
        let data_length = vector::length(data_ref);
        let mut last_upper_byte: u8 = 0;
        let mut ret: vector<u8> = vector::empty();
        let mut has_too_large_u16 = false;

        vector::push_back(&mut ret, 0x01);  // first byte of 1 indicates we are trying to use variable-length encoding scheme
                            // on most test data it produces byte length < byte length of input
                            // though on very random sets - result may come up larger, in that case - we'll switch it to basic u16->two bytes later

        while (i < data_length && has_too_large_u16 == false) {
            let code = *vector::borrow(data_ref, i);

            let lower_byte = ( (code & 0xFF) as u8 );
            let upper_byte = ( ((code >> 8) & 0xFF) as u8 );

            if (upper_byte == 0xFF) {
                // we can not encode values greater than 0xFEFF as variable-length encoding, so we'll go with basic two-bytes encoding
                has_too_large_u16 = true;
            } else {

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
        };

        if (has_too_large_u16 == true || vector::length(&ret) > (1 + vector::length(data_ref)*2)) {
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

    // unpack the vector produced by pack_u16_into_u8 back into vector<u16>
    public fun unpack_u8_into_u16(data_ref: &vector<u8>): vector<u16> {
        let data_length = vector::length(data_ref);
        let mut ret: vector<u16> = vector::empty();

        if (data_length <= 1) { // as we have control byte #0
            return vector::empty()
        };

        let encoding_scheme_type = *vector::borrow(data_ref, 0);
        let mut i:u64 = 1;
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
            let mut last_upper_byte: u16 = 0;

            while (i < data_length) {
                let mut byte = (*vector::borrow(data_ref, i) as u16);
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

    #[test]
    fun test_vec_packing() {
        let mut vec16: vector<u16> = vector[255];
        let mut i = 0;
        while (i < 50) {
            vector::append(&mut vec16, vector[(i%255), (i%255)]);
            i = i + 1;
        };

        let original_vector_length = vector::length(&vec16);
        let original_vector_length_in_bytes = original_vector_length * 2;

        let packed: vector<u8> = pack_u16_into_u8(&vec16);

        let packed_vector_length = vector::length(&packed);

        // be sure we saved some space
        assert!(packed_vector_length < original_vector_length_in_bytes, 0);

        // try to restore u16 vector
        let restored_vec16: vector<u16> = unpack_u8_into_u16(&packed);

        // same length
        assert!((vector::length(&restored_vec16)) == vector::length(&vec16), 0);

        // same data restored:
        assert!(restored_vec16 == vec16, 0);
    }
}