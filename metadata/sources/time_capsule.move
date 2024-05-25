
module suidouble_metadata::time_capsule {
// functions to encrypt/decrypt vector<u8> of any length into a time capsule so it can be decrypted in the future with drand signatures
//
// flow:
// drand chains: https://api.drand.sh/chains
//   select the one to use
//       quicknet network chain hash: 52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971
//  
//  this module is to work with quicknet:
//  get drand chain public_key from https://api.drand.sh/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971/info
//      it's constant and public you can hard-code it
//      let public_key = x"83cf0f2896adee7eb8b5f01fcad3912212c437e0073e911fb90022d3e760183c8c4b450b6a0a6c3ac6a5776a2d1064510d1fec758c921cc22b0e17e63aaf4bcb5ed66304de9cf809bd274ca73bab4af5a6e9c76a4bc09e76eae8991ef5ece45a";
//      or use helper of
//      let drand = time_capsule::drand_quicknet();
//      optionaly, add some randomness to the time_capsule, using sui::random module:
//      let drand = time_capsule::drand_quicknet_with_randomness(random_generator.generate_bytes(32));
//
// get the latest currently available round from:
//      drand api - https://api.drand.sh/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971/public/latest
//      or calculated with chain genesis data:
//      let latest_round:u64 = drand.latest_round(timestamp_ms);
//      you may get current timestamp_ms from sui::clock object
//
// so you can enrypt a message to the future, which will be able to be decoded when new drand signatures created on selected drand chain
//     
//    let encrypted = encrypt_for_round(&public_key, (current_latest_round + 1000), &msg);  // secret for next 1000 drand rounds
//    or 
//    let encrypted = drand.enrypt(drand.round_at(future_timestamp_ms), &msg);              // secret until future_timestamp_ms
//
//    after time, drand round will be generated for the round you wait for
//    and encrypted message may be decrypted back to original with round signature:
//      https://api.drand.sh/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971/public/7787102
//    where 7787102 == (current_latest_round + 1000) or  == (drand.round_at(future_timestamp_ms)) in this examples
//    note that you have to also remember round number or timestamp you are targeting your secret for
//
//   let decrypted = decrypt_with_round_signature(&encrypted, round_signature);
//   or
//   let decrypted = drand.decrypt(&encrypted, round_signature);
//
//   assert(!decrypted == msg);
//
//  Take a look at unit tests in the bottom, or check sample pacage for inspiration.

    #[test_only]
    use sui::clock;
    #[test_only]
    use sui::test_scenario;
    #[test_only]
    use sui::random;

    use sui::bcs;
    use suidouble_metadata::metadata;
    use std::hash;
    use sui::bls12381;
    use std::debug;
    use sui::hash::blake2b256;
    use sui::group_ops;
    

    const EInvalidLength: u64 = 0;
    const BLS12381_ORDER: vector<u8> = x"73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001";

    public struct DrandChain has drop {
        genesis_time: u64,  // note it's seconds here, not ms,  while we use ms in methods
        period: u64,
        public_key: vector<u8>,
        randomness: vector<u8>, // adds randomness to the encrypted process, you'd better use it
    }

    /// An encryption of 32 bytes message following https://eprint.iacr.org/2023/189.pdf.
    public struct IbeEncryption has store, drop, copy {
        u: group_ops::Element<bls12381::G2>,
        v: vector<u8>,
        w: vector<u8>,
    }

    public fun drand_quicknet_with_randomness(randomness_bytes: vector<u8>): DrandChain {
        let mut drand = drand_quicknet();
        drand.add_randomness(randomness_bytes);

        drand
    }

    public fun drand_quicknet(): DrandChain {
        DrandChain {
            randomness: vector::empty(),
            genesis_time: 1692803367, // note it's seconds here, not ms,  while we use ms in methods
            period: 3,
            public_key: x"83cf0f2896adee7eb8b5f01fcad3912212c437e0073e911fb90022d3e760183c8c4b450b6a0a6c3ac6a5776a2d1064510d1fec758c921cc22b0e17e63aaf4bcb5ed66304de9cf809bd274ca73bab4af5a6e9c76a4bc09e76eae8991ef5ece45a"
        }
    }

    public fun drand_with_params(genesis_time_seconds: u64, period: u64, public_key: vector<u8>, randomness: vector<u8>): DrandChain {
        DrandChain {
            randomness: randomness,
            genesis_time: genesis_time_seconds, // note it's seconds here, not ms,  while we use ms in methods
            period: period,
            public_key: public_key
        }
    }

    public fun add_randomness(self: &mut DrandChain, randomness: vector<u8>) {
        self.randomness = hash::sha2_256(randomness);
    }

    public fun public_key(self: &DrandChain): &vector<u8> {
        return &self.public_key
    }

    public fun use_randomness(self: &mut DrandChain): &vector<u8> {
        self.randomness = hash::sha2_256(self.randomness);

        &self.randomness
    }

    public fun round_at(self: &DrandChain, timestamp_ms: u64): u64 {
        let timestamp = timestamp_ms / 1000; // to seconds
        if (self.genesis_time > timestamp) {
            return 0
        };
        return ((timestamp - self.genesis_time) / self.period)
    }

    public fun latest_round(self: &DrandChain, timestamp_ms: u64): u64 {
        return self.round_at(timestamp_ms)
    }

    public fun encrypt(self: &mut DrandChain, round: u64, msg_ref: &vector<u8>): vector<u8> {
        let random_sigma_ref = self.use_randomness();
        encrypt_for_round(&self.public_key, round, msg_ref, random_sigma_ref)
    }

    public fun encrypt_for_time(self: &mut DrandChain, timestamp_ms: u64, msg_ref: &vector<u8>): vector<u8> {
        let round = self.round_at(timestamp_ms);
        let random_sigma_ref = self.use_randomness();
        encrypt_for_round(&self.public_key, round, msg_ref, random_sigma_ref)
    }

    public fun verify_signature(self: &mut DrandChain, round: u64, signature_ref: &vector<u8>): bool {
        verify_round_signature(&self.public_key, round, signature_ref)
    }

    public fun decrypt(_self: &DrandChain, encrypted_msg_ref: &vector<u8>, round_signature: vector<u8>): vector<u8> {
        decrypt_with_round_signature(encrypted_msg_ref, round_signature)
    }

    /// Convert IbeEncryption to binary format. Note that it's differenf to what Sui team uses in their code samples
    public fun ibe_encryption_to_bytes(enc: IbeEncryption): vector<u8> {
        let mut ret = vector::empty();
        metadata::set(&mut ret, metadata::key(&b"v"), &enc.v);
        metadata::set(&mut ret, metadata::key(&b"w"), &enc.w);
        metadata::set(&mut ret, metadata::key(&b"u"), group_ops::bytes(&enc.u));

        ret
    }

    // Restore IbeEncryption from binary representation
    public fun bytes_to_ibe_encryption(bytes_ref: &vector<u8>): IbeEncryption {
        IbeEncryption {
            u: bls12381::g2_from_bytes(&metadata::get_vec_u8(bytes_ref, metadata::key(&b"u"))),
            v: metadata::get_vec_u8(bytes_ref, metadata::key(&b"v")),
            w: metadata::get_vec_u8(bytes_ref, metadata::key(&b"w"))
        }
    }

    // Hash a round value to use for encryption
    public fun round_key(round: u64): vector<u8> {
        let mut as_bytes = bcs::to_bytes(&round);
        vector::reverse(&mut as_bytes);

        hash::sha2_256(as_bytes)
    }

    // Encrypt in message for specific future round
    // Quick note that don't forget that if you execute this on blockchain, there're records of msg in txs/events etc and it's not secret
    //  even if you generate msg in your code, somebody may follow that steps prior to this function and restore the message
    //  this function should be called off-chain to keep everything secure
    public fun encrypt_for_round(public_key_ref: &vector<u8>, round: u64, msg: &vector<u8>, random_sigma_ref: &vector<u8>): vector<u8> {
        let public_key = bls12381::g2_from_bytes(public_key_ref);
        let round_hash = round_key(round);
        let mut ret: vector<u8> = vector::empty();
        // split msg into 32 bytes chunks and encode it one by one:
        let mut i = 0;
        let mut piece_index: u32 = 0; 
        let msg_length = vector::length(msg);
        while (i < msg_length) {
            let mut msg_piece: vector<u8> = vector::empty();
            let mut j = 0;
            let mut chunk_length = 32;
            if (piece_index == 0) {
                // first 4 bytes on the very first chunk to encode would have u32 byte length of msg, so we can get rid of padding on decrypting
                msg_piece.append(vector[
                    (((msg_length >> 24) % 256) as u8),
                    (((msg_length >> 16) % 256) as u8),
                    (((msg_length >> 8)  % 256) as u8),
                    ((msg_length % 256) as u8)
                ]);
                chunk_length = 28;
            };

            while (j < chunk_length) {
                if ((i+j) < msg_length) {
                    msg_piece.push_back(*vector::borrow(msg, (i+j)));
                } else {
                    // pad it with random bytes
                    msg_piece.push_back(*vector::borrow(random_sigma_ref, j)); 
                };
                j = j + 1;
            };


            let msg_piece_encrypted = insecure_ibe_encrypt(&public_key, &round_hash, &msg_piece, random_sigma_ref);
            let msg_piece_encrypted_as_bytes = ibe_encryption_to_bytes(msg_piece_encrypted);

            metadata::set(&mut ret, piece_index, &msg_piece_encrypted_as_bytes);
            i = i + chunk_length;
            piece_index = piece_index + 1;
        };

        ret
    }

    public fun verify_round_signature(public_key_ref: &vector<u8>, round: u64, round_signature_ref: &vector<u8>): bool {
        let round_hash = round_key(round);
        bls12381::bls12381_min_sig_verify(round_signature_ref, public_key_ref, &round_hash)
    }

    public fun decrypt_with_round_signature(encrypted_msg_ref: &vector<u8>, round_signature: vector<u8>): vector<u8> {
        let target_key = bls12381::g1_from_bytes(&round_signature);
        let mut ret: vector<u8> = vector::empty();
        
        // encrypted message is vector<u8> oranized as metadata with structure of:
        //    0 -  first chunk of encrypted 32 bytes, when decrypted, first 4 bytes is original message length and 28 bytes of data
        //    1 -  second chunk of encrypted 32 bytes, decrypted to 32 bytes of message
        //    ....
        //    N -  last chunk of encrypted 32 bytes, 
        //         last chunk when decrypted may be padded by random bytes, so take a msg length from chunk #0 to trim it
        //    where 0..N - u32 indexes for metadata library, and chunk is to be get as metadata::get_vec_u8 with it

        // first step - get chunks count as from metadata vector<u8>
        let chunks_count = metadata::get_chunks_count(encrypted_msg_ref); // 

        debug::print(&chunks_count);
        debug::print(&chunks_count);
        debug::print(&chunks_count);
        debug::print(&chunks_count);
        debug::print(&chunks_count);
        let mut i = 0;
        let mut msg_length: u32 = 0;

        while (i < chunks_count) {
            // read and decrypt chunk one by one
            let chunk = metadata::get_vec_u8(encrypted_msg_ref, ( (i) as u32) );

            debug::print(&metadata::get_vec_length(encrypted_msg_ref, ( (i) as u32) ) );
            debug::print(&metadata::get_vec_length(encrypted_msg_ref, ( (i) as u32) ) );

            let enc = bytes_to_ibe_encryption(&chunk);
            let dec = ibe_decrypt(enc, &target_key);
            let dec_binary = option::destroy_with_default(dec, vector::empty());

            if (i == 0) {
                // very first chunk has first 4 bytes of msg_length
                msg_length = (*dec_binary.borrow(0) as u32) << 24 |
                (*dec_binary.borrow(1) as u32) << 16 |
                (*dec_binary.borrow(2) as u32) << 8 |
                (*dec_binary.borrow(3) as u32);

                let mut j = 4;
                while (j < 32) {
                    vector::push_back(&mut ret, *vector::borrow(&dec_binary, j));
                    j = j + 1;
                };
            } else {
                vector::append(&mut ret, dec_binary);
            };

            i = i + 1;
        };

        // get rid of not needed extra bytes we used for padding
        while (vector::length(&ret) > (msg_length as u64)) {
            ret.pop_back();
        };

        ret
    }

    // https://github.com/MystenLabs/sui/blob/80e63921f791a1af97342f9aa854af2804186eb2/sui_programmability/examples/crypto/sources/ec_ops.move#L256 
    // Encrypt a message 'm' for 'target'. Follows the algorithms of https://eprint.iacr.org/2023/189.pdf.
    // Note that the algorithms in that paper use G2 for signatures, where the actual chain uses G1, thus
    // the operations below are slightly different.
    // 
    fun insecure_ibe_encrypt(pk: &group_ops::Element<bls12381::G2>, target: &vector<u8>, m: &vector<u8>, sigma: &vector<u8>): IbeEncryption {
        assert!(vector::length(sigma) == 32, 0);

        // pk_rho = e(H1(target), pk)
        let target_hash = bls12381::hash_to_g1(target);
        let pk_rho = bls12381::pairing(&target_hash, pk);

        // r = H3(sigma | m) as a scalar
        assert!(vector::length(m) == vector::length(sigma), 0);
        let mut to_hash = b"HASH3 - ";
        vector::append(&mut to_hash, *sigma);
        vector::append(&mut to_hash, *m);
        let r = modulo_order(&blake2b256(&to_hash));
        let r = bls12381::scalar_from_bytes(&r);

        // U = r*g2
        let u = bls12381::g2_mul(&r, &bls12381::g2_generator());

        // V = sigma xor H2(pk_rho^r)
        let pk_rho_r = bls12381::gt_mul(&r, &pk_rho);
        let mut to_hash = b"HASH2 - ";
        vector::append(&mut to_hash, *group_ops::bytes(&pk_rho_r));
        let hash_pk_rho_r = blake2b256(&to_hash);
        let mut v = vector::empty();
        let mut i = 0;
        while (i < vector::length(sigma)) {
            vector::push_back(&mut v, *vector::borrow(sigma, i) ^ *vector::borrow(&hash_pk_rho_r, i));
            i = i + 1;
        };

        // W = m xor H4(sigma)
        let mut to_hash = b"HASH4 - ";
        vector::append(&mut to_hash, *sigma);
        let hash = blake2b256(&to_hash);
        let mut w = vector::empty();
        let mut i = 0;
        while (i < vector::length(m)) {
            vector::push_back(&mut w, *vector::borrow(m, i) ^ *vector::borrow(&hash, i));
            i = i + 1;
        };

        IbeEncryption { u, v, w }
    }

    // Decrypt an IBE encryption using a 'target_key'.
    public fun ibe_decrypt(enc: IbeEncryption, target_key: &group_ops::Element<bls12381::G1>): Option<vector<u8>> {
        // sigma_prime = V xor H2(e(target_key, u))
        let e = bls12381::pairing(target_key, &enc.u);
        let mut to_hash = b"HASH2 - ";
        vector::append(&mut to_hash, *group_ops::bytes(&e));
        let hash = blake2b256(&to_hash);
        let mut sigma_prime = vector::empty();
        let mut i = 0;
        while (i < vector::length(&enc.v)) {
            vector::push_back(&mut sigma_prime, *vector::borrow(&hash, i) ^ *vector::borrow(&enc.v, i));
            i = i + 1;
        };

        // m_prime = W xor H4(sigma_prime)
        let mut to_hash = b"HASH4 - ";
        vector::append(&mut to_hash, sigma_prime);
        let hash = blake2b256(&to_hash);
        let mut m_prime = vector::empty();
        let mut i = 0;
        while (i < vector::length(&enc.w)) {
            vector::push_back(&mut m_prime, *vector::borrow(&hash, i) ^ *vector::borrow(&enc.w, i));
            i = i + 1;
        };

        // r = H3(sigma_prime | m_prime) as a scalar (the paper has a typo)
        let mut to_hash = b"HASH3 - ";
        vector::append(&mut to_hash, sigma_prime);
        vector::append(&mut to_hash, m_prime);
        // If the encryption is generated correctly, this should always be a valid scalar (before the modulo).
        // However since in the tests we create it insecurely, we make sure it is in the right range.
        let r = modulo_order(&blake2b256(&to_hash));
        let r = bls12381::scalar_from_bytes(&r);

        // U ?= r*g2
        let g2r = bls12381::g2_mul(&r, &bls12381::g2_generator());
        if (group_ops::equal(&enc.u, &g2r)) {
            option::some(m_prime)
        } else {
            option::none()
        }
    }


    fun modulo_order(x: &vector<u8>): vector<u8> {
        let mut res = *x;
        // Since 2^256 < 3*ORDER, this loop won't run many times.
        while (true) {
            let minus_order = try_substract(&res);
            if (option::is_none(&minus_order)) {
                return res
            };
            res = *option::borrow(&minus_order);
        };
        res
    }
        

    // Returns x-ORDER if x >= ORDER, otherwise none.
    fun try_substract(x: &vector<u8>): Option<vector<u8>> {
        assert!(vector::length(x) == 32, EInvalidLength);
        let order = BLS12381_ORDER;
        let mut c = vector::empty();
        let mut i = 0;
        let mut carry: u8 = 0;
        while (i < 32) {
            let curr = 31 - i;
            let b1 = *vector::borrow(x, curr);
            let b2 = *vector::borrow(&order, curr);
            let sum: u16 = (b2 as u16) + (carry as u16);
            if (sum > (b1 as u16)) {
                carry = 1;
                let res = 0x100 + (b1 as u16) - sum;
                vector::push_back(&mut c, (res as u8));
            } else {
                carry = 0;
                let res = (b1 as u16) - sum;
                vector::push_back(&mut c, (res as u8));
            };
            i = i + 1;
        };
        if (carry != 0) {
            option::none()
        } else {
            vector::reverse(&mut c);
            option::some(c)
        }
    }


    #[test]
    fun test_raw_decryption() {
        // round  = 2000
        let key = round_key(2000);
        debug::print(&key);

        // let message = x"AA00AA00AA00AA00AA00AA00AA00AA00AA00AA00AA00AA00AA00AA00AA00AA00";
        // let public_key_bytes = x"83cf0f2896adee7eb8b5f01fcad3912212c437e0073e911fb90022d3e760183c8c4b450b6a0a6c3ac6a5776a2d1064510d1fec758c921cc22b0e17e63aaf4bcb5ed66304de9cf809bd274ca73bab4af5a6e9c76a4bc09e76eae8991ef5ece45a";
        // let public_key = bls12381::g2_from_bytes(&public_key_bytes);

        // debug::print(&public_key);

        // test_encrypt(&public_key, &key, &message);
        // debug::print(&round_key(2000));
        // debug::print(&round_key(2000));
        // debug::print(&round_key(2000));
        // debug::print(&round_key(2000));

        let round_signature = x"b6cb8f482a0b15d45936a4c4ea08e98a087e71787caee3f4d07a8a9843b1bc5423c6b3c22f446488b3137eaca799c77e";
        // let mut drand = drand_quicknet();
        // debug::print(&drand.verify_signature(2000, &round_signature));


        let target_key = bls12381::g1_from_bytes(&round_signature);

        // debug::print(&target_key);

        let mut u = x"b6884fa9bea8ff16122dfef6896fd760d3b92c8d62dff0dd16791b7f07a7ecf13a21ec3031ac4a2795f5bade9a19b497149a61de2f678bc3fc4500408282962dbd302b085fd7427c6dcb33ebbe6a3c3c113f5d51a3c7aa463ddb065e97614382";
        let mut v = x"873c5ed09b78f5895ac28f7136ae1004a9796672deecb51cf6171ef90f8ecee3";
        let mut w = x"8dcad341908b8888e0323893888ece609da31bd43bdcb7dff9dd3e6f1119acac";

        // vector::reverse(&mut v);
        // vector::reverse(&mut w);

        // let ibe = IbeEncryption {
        //     u: bls12381::g2_from_bytes(&u),
        //     v: v,
        //     w: w,
        // };
        // debug::print(&ibe_encryption_to_bytes(ibe));

        let ibe = bytes_to_ibe_encryption(&x"00370000002900000020bb6f7b200d795ecdeb5d732ba9018204d45b13991931ef65cd4e069e033e840f380000002900000020382d04b8f3d0baacdbe8c116a73d03691cc3fc9662618d96539bb97a6d84f1e23600000069000000608d894c3a4a8764b76065e2cd03120796b0e5357638242c23edde1361e3cba8dc91cfd4dd3b31e2480fed7664a8c134340a8abebc52f47d9cda6e94233544e79b08b7101543eb295dfa325ab18451c37f0aa3be948280a56e27ff3ec185b61a22");

        debug::print(&ibe);
        let decrypted = ibe_decrypt(ibe, &target_key);
        debug::print(&decrypted);


        let encrypted = x"0000000000c6000000bc01003700000029000000204498dbab6b9a9d94527c8cf76b85fc6fc8c982cc2c241375a71dcc0a63e1a19f3800000029000000204ab05055e501db77ab9380a003f88e4112a89ca1fd9b1536ac2f5c408eb11e523600000069000000609063caf8106648d6a6e7fb839caca8028b74a460471c70f9859c302fd6d6e0714394dae878d6d585625e18d76deb32a1115dcaea1d55324abc7f04c1ae242924a87e9e4cd1397d57140c92505a148d99f93c23594da4ac9a94b7c1d78ef63fa401000000c6000000bc010037000000290000002016e757bd31754f5aec069326a705c21aee370f58a32e8192a64a430c77d250e638000000290000002030645bc93d5f93c39fc8b25dda8e7a7917a23b25b33bc46dc54d92cdd3ca4366360000006900000060821e4e63417ebd08b5f25bcf8df6c317dc388259c6cd24e9e5c1b83731ad4baf33dee3d7badc693c4ef9c97f99c388c11411fd8030fa81306dfe5876ae6166bb01dee4069288dcfd83499c14a7839ef0cb7ee23afe0885e85eb5963d536810d702000000c6000000bc010037000000290000002007e3af812f1b6dbb6a91aff3a6dc1990ee90de1f0507b3f310e77a4320a7596238000000290000002096bb0e7b637f48987977f21fb4677942861414e0d6f51567d859d28f92cb37383600000069000000608f6e013bd65e4bbd851596d0bafef97d4b65fe5dcff0dc1a985491e6bc6b1641f812fb4f6911621d736c38efdbb6fd540e5150da712d650ab73d2d36c5dd0f39f0926f8106b62ad629fd62df066ec92e46a1f3b87e835d49abee34aa5847d7f603000000c6000000bc0100370000002900000020e5932a648dc221b1b3d18401f322ed20164dd867e060144c23951d220948b699380000002900000020ddac914d2c3c4efc620e7803ed9f517ff667f6a5d48bfc1e38df58ccb85a1cbb360000006900000060a1841910e321b13f036129555fced8d84d685a5125b2730f58860b8874cd8e4c9f7378d8d9ffedc5f11d16dcf49196ad03a62bb61276db7591e2b19137549270b1dd6256ff261155f12060033278204d34ca4ed7ac2a82279a6efd79f70d2a2404000000c6000000bc010037000000290000002025dba9d0cfa24ccf885d2f6f3b21976e7f6519242af5736b68e527f183e32c7b38000000290000002047e8b0b6ddf04dcaf291703ff73a1f9394dccbfd42080692834331a6ede86b5a360000006900000060ae1074fd66751500437e5f0d8959f40e5c1408a4bbabdea027740733c9dab44497bd85eb44d1e62ca4d83ad92faededb145c48b42cad42b57dc24d1b9a7130614bff7dd60c1557f15be37ae46b0309d84d5287ccabd1ca72fbfd869a9d36930f05000000c6000000bc01003700000029000000206ac400f910cddb398e458a067b4b8564d39907f6b8360d70e05cf32e2df2a8d5380000002900000020780da238744b204fa4a84aa0f69b7963ccbefcf27a32bf0c4e4d040e3a95fff03600000069000000609032e2bfd333c5cc1a875fb1c944e40703dd3943f4bb19f8fa4e8cd734468c2312ef44ca3b2a5390b4ed1d2ec569078f0de49a406b11fe7c9abf8e05411056e8db38157da1fc3eb25d4201c9995f4ac3666ef0abece61e0904b5b4991b7a385606000000c6000000bc0100370000002900000020b828644f55b98a5eb919c29d99c25f71357886621f13166085a28c33fd1d4adf380000002900000020e36a93ea9f6a2e6e2d086d52435164e8bdbf5a9f3d06604ca145b677ff2e1fcc360000006900000060954c949c62731c2ba92522dc57e4e3b4e5724a414d9f152be3438f4da5ef477def0aa9fab18495814578fc041e0aaf4b16e3dcdc87b33d3d3af02c483ec0b92db7dc69b16c7c05c64c7eb4e551f951c58e679169b9971e3b2f956645b85915df07000000c6000000bc010037000000290000002027d9b077596e552619cf8f443a5b012bcb20509f106dbbe6e8a327cc0a5fe372380000002900000020104ef975bae2f812e6b1e32a22943b953307276b38c52cca7493daccbe178926360000006900000060b32ea539badce44437b88b9a2abb24eb0b62a27fae72ea51e650be020fe34f0ecd3d12600bd183bd69d68c476a48046c0a8903608050cd751a8a2360cffec186f229e4faaafb90bda1c6c70e106e68d963b061b0c567817adb30db2b59b0c91108000000c6000000bc0100370000002900000020ae1e81e9aacb40a6ee6a446bd96920ec2f9473de81f16e55a4d87a885ef597d438000000290000002014b3754506c51d9d6c2c352234294437d06f71a8e09265bd1782aafc02305af83600000069000000608540a30ecd43a9f7f87c0f3cbbb4d412ed237e39c07d3e1e05100db6a33e892407713f699865c857eecc4a63d6cf578d15dcfff6eb74e9ee06a3c8d6f18fcf16905045033fe3938b4799da38301b1bd85906be76b69a41b6622c5b758ab17c3b09000000c6000000bc0100370000002900000020997f82e663012b5f90ee7cd191c42c5640ca615374754b151fde31cbd1bd02ca3800000029000000207a055452b6c848bc63aba1e89622110d6e8f23b5fc1f2460bb1b664f282c5837360000006900000060897dc1403d45507af58541a5900cf933c78dbd12d55a60920befee1a8674089b33a8572241a8f4b9f8e1534e2f7c31da01e3a9fb889641ac0302810bd2dd9a40a9f80f53aba5d64a88be6527013ccc79775dbfe63cd1159c5c2d19b037e228b90a000000c6000000bc0100370000002900000020a0c76882a5e9455883ece2ffcd01e96a3be75f8f50236407483d95df1178fce838000000290000002039f9e9088ba738502a801a72535ec02430566c120bfee37547789ac0b2fb976736000000690000006099da7d1c5c693b9a19f4235b8a861cdfec9bd3fb405257eed461b59c00dd511d3a51fad546c4e6eca6b495380761bcbf0fcc4cc29122b8f348afddefb0d171c5da359bc70b193b545e1b97e1b654c3d87e34b1eeceae71cdaebaec30e10115770b000000c6000000bc0100370000002900000020c87b92284f89a2082789e7d718872378b73185766cf9f25865a33e9b1676c123380000002900000020c0ea4f95a43a9eff7eba71386de40a9d196b54edf249ce18d3221188ee42e087360000006900000060ac6f80e19b29f1967f351d9baa8a9d3b68e29303a6ac16d3bc1a09601a00e2d09cab60bdff3c2fd5da1158bed4904f70178d4c603ccb407badc439fa1b2ebb3c0b4dc64e6003173316c35abd0a1b3e6c726991e39e4dd120430e528133d5fb70";

        debug::print(&encrypted);

        let mut drand = drand_quicknet();
        let decrypted = drand.decrypt(&encrypted, round_signature);
        // debug::print(&string::utf8(decrypted));

    }


    #[test]
    fun test_drand_quicknet_with_sui_random() {
        let msg: vector<u8> = b"Hey Sui Future! Are you random enough for a quick unit test?";  // > 32 bytes to be sure chunking works, more in tests below
        let round_7788475_signature = x"a17b758d8ef1a88a1e7f2db59634d5bc40f779ad44d41fe01cc0862bafb23f1510afdb12ff90985c5ed495434e4a19e5";


        
        let mut scenario = test_scenario::begin(@0x0);

        random::create_for_testing(scenario.ctx());
        scenario.next_tx(@0x0);

        let mut random_state = scenario.take_shared<random::Random>();
        random_state.update_randomness_state_for_testing(
            0,
            x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
            scenario.ctx(),
        );

        let mut gen = random_state.new_generator(scenario.ctx());
        let randomness = gen.generate_bytes(32); // it will be hashed, so length may be different actually

        let mut drand = drand_quicknet_with_randomness(randomness);
        let encrypted = drand.encrypt(7788475, &msg);  // Encrypt a message for round 7788475

        assert!(drand.verify_signature(7788475, &round_7788475_signature), 0);

        let decrypted = drand.decrypt(&encrypted, round_7788475_signature);

        assert!(decrypted == msg, 0);

        // try it with different randomness:
        let randomness2 = gen.generate_bytes(32); // new random bytes

        let mut drand2 = drand_quicknet_with_randomness(randomness2);
        let encrypted2 = drand2.encrypt(7788475, &msg);  // Encrypt a message for round 7788475
        let decrypted2 = drand2.decrypt(&encrypted2, round_7788475_signature);

        assert!(decrypted2 == msg, 0);

        // but encrypted messages itseves are different, as different sigma
        assert!(encrypted2 != encrypted, 0);

        test_scenario::return_shared(random_state);
        scenario.end();
    }

    #[test]
    fun test_drand_quicknet() {
        let mut ctx = tx_context::dummy();
        let mut clock = clock::create_for_testing(&mut ctx);
        clock.increment_for_testing(1716156290000); // Sun May 19 2024 22:04:50 GMT+0000
                                                    // latest drand quicknet round was 7784307 at Sun May 19 2024 22:04:50 GMT+0000

        let mut drand = drand_quicknet();

        assert!(drand.latest_round(clock.timestamp_ms()) == 7784307, 0);
        clock.destroy_for_testing();

        let msg: vector<u8> = b"Hey Sui Future! Hey Sui Future! How it goes?";  // > 32 bytes to be sure chunking works, more in tests below

        let encrypted = drand.encrypt_for_time(1716168794000, &msg);  // Encrypt a message for Mon May 20 2024 01:33:14 GMT+0000
        let round = drand.round_at(1716168794000); // future round is 7788475

        assert!(round == 7788475, 0); // latest round on Mon May 20 2024 01:33:14 GMT+0000

        // wait till Mon May 20 2024 01:33:14 GMT+0000 for round 7788475 to become available and get round signature for it
        //     https://api.drand.sh/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971/public/7788475
        let round_signature = x"a17b758d8ef1a88a1e7f2db59634d5bc40f779ad44d41fe01cc0862bafb23f1510afdb12ff90985c5ed495434e4a19e5";

        let decrypted = drand.decrypt(&encrypted, round_signature);

        assert!(decrypted == msg, 0);

        // test randomness, encrypting the same message should return different result, but decoded back to the same
        let encrypted2 = drand.encrypt_for_time(1716168794000, &msg);  // Encrypt a message for Mon May 20 2024 01:33:14 GMT+0000
        assert!(encrypted2 != encrypted, 0);

        // but may be decoded to the same original message
        let decrypted2 = drand.decrypt(&encrypted2, round_signature);
        assert!(decrypted2 == msg, 0);
    }


    #[test]
    fun test_encode() {
        let random_sigma = x"A123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF";
        let mut msg: vector<u8> = b"Oh Hey Sui World! How are you?";
        let mut i = 0;
        while (i < 3) { 
            vector::append(&mut msg, b"The Sui blockchain, an innovative and highly scalable layer-1 blockchain developed by Mysten Labs");
            i = i + 1;
        };

        // debug::print(&vector::length(&msg));

        //default network chain hash: 8990e7a9aaed2ffed73dbd7092123d6f289930540d7651336225dc172e51b2ce
        //quicknet network chain hash: 52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971
        // get public_key from https://api.drand.sh/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971/info
        let public_key = x"83cf0f2896adee7eb8b5f01fcad3912212c437e0073e911fb90022d3e760183c8c4b450b6a0a6c3ac6a5776a2d1064510d1fec758c921cc22b0e17e63aaf4bcb5ed66304de9cf809bd274ca73bab4af5a6e9c76a4bc09e76eae8991ef5ece45a";

        // get the latest available round from:
        // https://api.drand.sh/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971/public/latest
        // and encode a message for some round in the future:
        let future_round = 7784939;
        let encoded = encrypt_for_round(&public_key, future_round, &msg, &random_sigma);

        // debug::print(&encoded);

        // some time for future round becomes available,
        // some time for future round becomes available,
        // some time for future round becomes available,
        // some time for future round becomes available,

        //  get its signature from:
        //  https://api.drand.sh/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971/public/7784939    ( where 7784939 is future round )
        let round_signature = x"a8b3c8c59b11476b82e44b95f3fc50f854a3b8cd9e9959cb02087b27f583f9cc9d8d2dfb4d18118369404c94023f95a5";

        assert!(verify_round_signature(&public_key, future_round, &round_signature), 0); // signature is ok for the round
        let decoded = decrypt_with_round_signature(&encoded, round_signature);

        // debug::print(&msg);
        // debug::print(&decoded);

        assert!(decoded == msg, 0);
    }
}