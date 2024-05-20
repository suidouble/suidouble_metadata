
#[test_only]
module suidouble_metadata::compress_tests {

    use suidouble_metadata::compress;
    // use std::vector;
    // use std::debug;
    use std::hash;

    #[test_only]
    #[allow(unused_function)]
    fun get_test_vec_u8_of_1000_bytes(): vector<u8> {
        let mut bytevec: vector<u8> = b"Oh Hey Sui World! How are you?";
        let mut i = 0;
        while (i < 10) { // sui move test --gas-limit 50000000     if you want more
            vector::append(&mut bytevec, b"The Sui blockchain, an innovative and highly scalable layer-1 blockchain developed by Mysten Labs");
            i = i + 1;
        };

        bytevec
    }

    #[test_only]
    #[allow(unused_function)]
    fun get_test_vec_u8_of_10kb_random(): vector<u8> {
        // random-like values, not suitable for compression
        // try it to check it generates compressed of larger size, 1.2x as of my tests
        let mut bytevec: vector<u8> = b"";
        let mut to_hash: vector<u8> = b"";
        let mut i = 0;
        while (vector::length(&bytevec) < 10*1024) {
            // fill some bytes till the end
            to_hash.push_back((((i as u16) % 255) as u8));
            let hash = hash::sha2_256(to_hash);

            vector::append(&mut bytevec, hash);
            // vector::push_back(&mut bytevec, 3u8);
            i = i + 1;
        };

        bytevec
    }

    #[test_only]
    #[allow(unused_function)]
    fun get_test_vec_u8_of_50kb(): vector<u8> {
        // using this would require you to increase gas limit for tests:
        //     sui move test --gas-limit 50000000
        let mut bytevec: vector<u8> = b"Oh Hey Sui World! How are you?";
        let mut i = 0;
        while (i < 500) { 
            vector::append(&mut bytevec, b"The Sui blockchain, an innovative and highly scalable layer-1 blockchain developed by Mysten Labs");
            i = i + 1;
        };

        while (vector::length(&bytevec) < 50*1024) {
            // fill some bytes till the end
            bytevec.push_back((((i as u16) % 255) as u8));
            // vector::push_back(&mut bytevec, 3u8);
            i = i + 1;
        };

        bytevec
    }

    #[test]
    fun test_compress16_pack() {
        // with get_test_vec_u8_of_50kb -> makes 51200 bytes -> 6825 bytes
        // most optimized combination by tests,
        //    does 
        //      pack_vector::pack_u16_into_u8(&compress_map_16(data_ref))  for compressing
        //    and
        //      decompress16(&pack_vector::unpack_u8_into_u16(data_ref))  for decompressing

        let bytevec = get_test_vec_u8_of_1000_bytes();

        let compressed = compress::compress(&bytevec);
        let decompressed_back = compress::decompress(&compressed);
        assert!(decompressed_back == bytevec, 0);

        // debug::print(&(compressed.length())); // as it's u8
        // debug::print(&bytevec.length());


        assert!(compressed.length() < bytevec.length(), 0);
    }

    #[test]
    fun test_compress_map_16() {
        let bytevec = get_test_vec_u8_of_1000_bytes();

        let compressed = compress::compress_map_16(&bytevec);
        let decompressed_back: vector<u8> = compress::decompress16(&compressed);
        assert!(decompressed_back == bytevec, 0);

        // debug::print(&(compressed.length()*2)); // as it's u16
        // debug::print(&bytevec.length());

        assert!(compressed.length()*2 < bytevec.length(), 0);
    }

    #[test]
    fun test_compress8() {
        let bytevec = get_test_vec_u8_of_1000_bytes();

        let compressed = compress::compress8(&bytevec);
        let decompressed_back = compress::decompress8(&compressed);

        // debug::print(&(compressed.length())); // as it's u8
        // debug::print(&bytevec.length());

        assert!(decompressed_back == bytevec, 0);

        assert!(compressed.length() < bytevec.length(), 0);
    }


}