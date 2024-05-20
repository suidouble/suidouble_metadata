# suidouble_metadata::time_capsule

Timelock Encryption (TLE) is a cryptographic primitive with which ciphertexts can only be decrypted after the specified time. There's a module in metadata package to create TimeCapsules using randomness of [DRand chain](https://drand.love/).

`suidouble_metadata::time_capsule` is a module for optional binary primitive. Feel free to use it for metadata chunks, the whole metadata vector, or your own vector<u8> as a library.

There're [few drand chains](https://api.drand.sh/chains), this library has helpers to work with `quicknet` one, which has a hash of [52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971](https://api.drand.sh/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971/info)

### basic usage

Assume you want to encrypt a message to be kept as a secret until `Mon May 20 2024 01:33:14 GMT+0000`

```rust
let drand = time_capsule::drand_quicknet();
let msg:vector<u8> = b"Hey Sui Future! Hey Bright Future! How it goes? Is everything fine?";
let encrypted:vector<u8> = drand.encrypt_for_time(1716168794000, &msg);
```

Message is encrypted. And there's no drand signature yet to decrypt it. All you can do is wait for `May 20 2024` to arrive.

*Note for readers from the future*: you can skip this step, as drand signature may be already available for you.

So after `Mon May 20 2024 01:33:14 GMT+0000` you can decrypt it:

```rust
let drand = time_capsule::drand_quicknet();
let round_n = drand.round_at(1716168794000); // timestamp used for encryption, you can save round_n somewhere on the encryption step
                                              // round_n is 7788475  for   1716168794000
```

Get drand signature from
`https://api.drand.sh/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971/public/7788475` ( this URL was 404 before `Mon May 20 2024 01:33:14 GMT+0000` ) and decrypt the message with it:

```rust
let round_signature = x"a17b758d8ef1a88a1e7f2db59634d5bc40f779ad44d41fe01cc0862bafb23f1510afdb12ff90985c5ed495434e4a19e5";
let decrypted:vector<u8> = drand.decrypt(&encrypted, round_signature);
assert!(decrypted == msg, 0); // decrypted back to the original message
```

### encrypting for the specific drand round

You can find the latest currently available round on drand via [drand api endpoint](https://api.drand.sh/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971/public/latest) or suidouble_metadata::time_capsule 's helper method:

```rust
let drand = time_capsule::drand_quicknet();
let latest_round = drand.latest_round(current_timestamp_ms); // you can get current_timestamp_ms with Sui's clock object
```

And you can encrypt a message to be secret for next 100 rounds:

```rust
let encrypted = drand.encrypt((latest_round+100), &b"secret");
```

Round is 3 seconds on quicknet, 100 rounds is 5 minutes, so in five minutes, you can get drand signature at: `https://api.drand.sh/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971/public/ROUNDNYOUNEED` and decrypt a message with it:

```rust
let round_signature = x"a17b758d8ef1a88a1e7f2db59634d5bc40f779ad44d41fe01cc0862bafb23f1510afdb12ff90985c5ed495434e4a19e5";
let decrypted:vector<u8> = drand.decrypt(&encrypted, round_signature);
assert!(decrypted == msg, 0); // decrypted back to the original message
```

### add some extra randomness

There's a random sigma involved in encryption algorythm, and random bytes padding. You can optionaly randomize encryption using sui::random or any other source of randomness:

```rust
let mut gen = sui::random::new_generator(...);
let drand1 = time_capsule::drand_quicknet(gen.generate_bytes(32));
let drand2 = time_capsule::drand_quicknet(gen.generate_bytes(32));
// drand1 and drand2 produce different results with same inputs
assert!(drand1.encrypt_for_time(1716168794000, &msg) != drand2.encrypt_for_time(1716168794000, &msg), 0);
// still both may be decrypted to same original message
assert!(drand1.decrypt(&encrypted1, round_signature) != drand2.decrypt(&encrypted1, round_signature), 0);
```

No need to store randomness for decryption, actually, you don't even need drand chain settings for it, only drand's chain public key is needed.

### verifying a round signature

```rust
let drand = time_capsule::drand_quicknet();
let round_signature = x"a17b758d8ef1a88a1e7f2db59634d5bc40f779ad44d41fe01cc0862bafb23f1510afdb12ff90985c5ed495434e4a19e5";
assert(drand.verify_signature(7784307, &round_signature) == true); // round_signature is good for round 7784307
assert(drand.verify_signature(7784206, &round_signature) == false); // but not for different round
```


