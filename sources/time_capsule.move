
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
//  Take a look at unit tests in the bottom, or check some more code for your inspiration:
//  https://github.com/MystenLabs/sui/blob/80e63921f791a1af97342f9aa854af2804186eb2/sui_programmability/examples/crypto/sources/ec_ops.move

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
    // use std::debug;
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
        // debug::print(&self.randomness); // tested it gets different

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
        // encrypted message if metadata with structure of:
        //    0 -  u64 of chunks count
        //    1 -  first chunk
        //    ....
        //    N -  last chunk
        
        // first step - get chunks count
        let chunks_count = metadata::get_chunks_count(encrypted_msg_ref); // 
        let mut i = 0;
        let mut msg_length: u32 = 0;

        while (i < chunks_count) {
            // read and decrypt chunk one by one
            let chunk = metadata::get_vec_u8(encrypted_msg_ref, ( (i) as u32) );
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