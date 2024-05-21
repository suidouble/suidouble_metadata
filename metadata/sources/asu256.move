
module suidouble_metadata::asu256 {
//   vector<u8> representation inside of u256
//   - methods to push u8 bytes into u256 single value
//
//   up to 31 bytes of data
//   the highest byte is data length  
//       0x010...0000001 = vector<u8>[1]
//       0x020...0000001 = vector<u8>[0,1];

    // removes the last byte from the asu256 and returns updated asu256
    public fun asu256_shift_back(mut value_u256: u256): u256 {
        if (value_u256 == 0) {
            return 0
        };
        let byte_length: u8 = ((value_u256 >> (8*31)) as u8);
        let without_byte_length: u256 = value_u256 << 8 >> 8;
        value_u256 = ( ( (byte_length - 1) as u256) << (8*31) ) | ( without_byte_length >> 8 ); // decrease byte_length

        value_u256
    }

    // byte length of data inside asu256
    public fun asu256_length(value_u256: u256): u8 {
        let byte_length: u8 = ((value_u256 >> (8*31)) as u8);

        byte_length
    }

    // push the byte to the end of asu256 data and returns updated asu256
    public fun asu256_push_back(mut value_u256: u256, byte: u8): u256 {
        let byte_length: u8 = ((value_u256 >> (8*31)) as u8);
        value_u256 = ( value_u256 << 8 ) | ( byte as u256 );
        value_u256 = ( ( (byte_length + 1) as u256) << (8*31) ) | value_u256; // increase byte_length

        value_u256
    }

    // return asu256 for a single byte vector of v, same as vu8_to_asu256(vector[v]);
    public fun u8_to_asu256(v: u8): u256 {
        ( 1u256 << (8*31) ) | ( v as u256 )
    }

    // returns asu256 for a vector<8>.
    //   aborts if vector length > 31
    public fun vu8_to_asu256(vu8_ref: &vector<u8>): u256 {
        let mut initial_contents: u256 = 0;
        let vector_length = vector::length(vu8_ref);
        let mut i = 0;

        while (i < vector_length) {
            initial_contents = (initial_contents << 8) | (  (*vector::borrow(vu8_ref, i)) as u256  );
            i = i + 1;
        };

        // and top byte indicating significant bytes length:
        initial_contents =  ( (i as u256) << (8*31) ) | initial_contents;

        return initial_contents
    }

    // converts asu256 back to vector<8>
    public fun asu256_to_vu8(value_u256: u256): vector<u8> {
        let byte_length: u8 = ((value_u256 >> (8*31)) as u8);
        let without_byte_length: u256 = value_u256 << 8 >> 8;

        let mut ret: vector<u8> = vector::empty();
        let mut i = 0;
        while (i < byte_length) {
            let byte = ( (without_byte_length) >> (8*(byte_length - i - 1)) ) & 0xFF;
            vector::push_back(&mut ret, (byte as u8));
            i = i + 1;
        };

        ret
    }


    #[test]
    fun test_asu256() {
        let v1: vector<u8> = vector[7,200,3];
        let v2: vector<u8> = vector[7];
        let ve: vector<u8> = vector[];

        let v1_as_u256 = vu8_to_asu256(&v1);
        let v2_as_u256 = vu8_to_asu256(&v2);
        let mut ve_as_u256 = vu8_to_asu256(&ve);

        let back_v1 = asu256_to_vu8(v1_as_u256);
        let back_v2 = asu256_to_vu8(v2_as_u256);
        let mut back_ve = asu256_to_vu8(ve_as_u256);

        assert!(back_v1 == v1, 0);
        assert!(back_v2 == v2, 0);
        assert!(back_ve == ve, 0);

        // try to add bytes to empty value
        ve_as_u256 = asu256_push_back(ve_as_u256, 7);
        ve_as_u256 = asu256_push_back(ve_as_u256, 200);
        ve_as_u256 = asu256_push_back(ve_as_u256, 3);

        // it stores the same as the one from v1
        assert!(ve_as_u256 == v1_as_u256, 0);

        back_ve = asu256_to_vu8(ve_as_u256);

        assert!(back_ve == v1, 0);

        // can store up to 31 bytes
        let vlong: vector<u8> = vector[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31];
        let mut vlong_as_u256 = vu8_to_asu256(&vlong);
        let back_vlong = asu256_to_vu8(vlong_as_u256);

        assert!(back_vlong == vlong, 0);

        vlong_as_u256 = asu256_shift_back(vlong_as_u256);
        let mut back_vlong_without = asu256_to_vu8(vlong_as_u256);

        assert!(vector::length(&back_vlong_without) == 30, 0);
        vlong_as_u256 = asu256_shift_back(vlong_as_u256);
        back_vlong_without = asu256_to_vu8(vlong_as_u256);

        assert!(vector::length(&back_vlong_without) == 29, 0);

        vlong_as_u256 = asu256_shift_back(vlong_as_u256);
        back_vlong_without = asu256_to_vu8(vlong_as_u256);

        assert!(vector::length(&back_vlong_without) == 28, 0);
        let shouldbe: vector<u8> = vector[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28];

        assert!(back_vlong_without == shouldbe, 0);
    }

}