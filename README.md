# suidouble_metadata
Move library and a set of tools to store/retrieve/manage any type of data as chunks in u8 vector.

#### Usage

The first step is to have `vector<u8>` ready to store metadata. 
Declare it anywhere, assign to the `struct` you are going to use in your package, like:

```rust
struct YourPerfectNFT has key, store {
    // ...,
    metadata: vector<u8>,
}
```

and don't have any issues with contract upgrades anymore. 
You'll be able to store/manage any primitive data in that metadata vector. 

And here's the library to help you with this.

```rust
use suidouble_metadata::metadata;
```

#### Quick usage example

```rust
let meta: vector<u8> = vector::empty();

metadata::set(&mut meta, metadata::key(b"your_age"), &(27u8));
metadata::set(&mut meta, metadata::key(b"your_mood"), b"happy");

if (!metadata::get_bool(&meta, metadata::key(b"to_the_moon?"), false)) {
    metadata::set(&mut meta, metadata::key(b"to_the_moon?"), true);

    let adjust_to_the_moon_flag_times = metadata::get_u256(&meta, metadata::key(b"adjust_to_the_moon_flag_times?"), 0);
    metadata::set(&mut meta, metadata::key(b"adjust_to_the_moon_flag_times?"), &(adjust_to_the_moon_flag_times + 1));
};

if (!metadata::has_chunk(&meta, metadata::key(b"once"))) {
    metadata::set(&mut meta, metadata::key(b"once"), &(vector::singleton<u256>(4234234)));
}

if (!metadata::has_chunk_of_type<vector<address>>(&meta, metadata::key(b"once"))) {
    let haha: vector<address> = vector[@0xC0FFEE, @0xABBA, @0xBABE, @0xC0DE1, @0xBEEF];
    metadata::set(&mut meta, metadata::key(b"once"), &haha);
}
```

 - [Set metadata data](#set-metadata-data)
 - [Get data from metadata](#get-data-from-metadata)
 - [Get information from metadata/Check chunks](#get-information-from-metadata)
 - [Remove data from metadata](#remove-chunk-from-metadata)
 - [Key hash function](#key-hash-function)
 - [Unpacking the key back to vector<u8>/string](#unpacking-the-key-back-to-vectorstring)
 - [Running unit tests](#running-unit-tets)


#### Set metadata data

```rust
public fun set<T>(metadata: &mut vector<u8>, chunk_id: u32, value: &T): bool {
```

set function accepts any primitive data type for a value:

 - bool
 - u8, u64, u128, u256
 - address
 - vector<bool>
 - vector<u8>, vector<u64>, vector<u128> 
 - vector<address>
 - vector<vector<u8>>

letting you store any primitive data you can imagine. 
Futhermore, there's compress function to help you fit everything into 250KB Sui's object size limit.

Function signature is the same for all value types, so would work:

```rust
metadata::set(&mut meta, metadata::key(b"property"), &(27u8));
metadata::set(&mut meta, metadata::key(b"property"), &(vector_of_u8_u8));
```
#### Get data from metadata

Basic `get` function returs an `Option<vector<u8>>`, and there're a lot of extra methods to get each data type:
```rust
metadata::get_option_bool(&meta, metadata::key(b"key"))    : Option<bool>;
metadata::get_option_u8(&meta, metadata::key(b"key"))      : Option<u8>;
metadata::get_option_u64(&meta, metadata::key(b"key"))     : Option<u64>;
metadata::get_option_u128(&meta, metadata::key(b"key"))    : Option<u128>;
metadata::get_option_u256(&meta, metadata::key(b"key"))    : Option<u256>;
metadata::get_option_address(&meta, metadata::key(b"key")) : Option<address>;
metadata::get_option_vec_bool(&meta, metadata::key(b"key"))     : Option<vector<bool>>;
metadata::get_option_vec_u8(&meta, metadata::key(b"key"))       : Option<vector<u8>>;
metadata::get_option_vec_u64(&meta, metadata::key(b"key"))      : Option<vector<u64>>;
metadata::get_option_vec_u128(&meta, metadata::key(b"key"))     : Option<vector<u128>>;
metadata::get_option_vec_address(&meta, metadata::key(b"key"))  : Option<vector<address>>;
metadata::get_option_vec_vec_u8(&meta, metadata::key(b"key"))   : Option<vector<vector<u8>>>;
```

and additional unwrappers to let you easly get with default, if there's no data:
```rust
metadata::get_bool(&meta, metadata::key(b"key"), false)      : bool;  // default is false
metadata::get_u8(&meta, metadata::key(b"key"), 111)          : u8;  // default is 111
metadata::get_u64(&meta, metadata::key(b"key"), 999)         : u64;  // default is 999
metadata::get_u128(&meta, metadata::key(b"key"), 111)        : u128;  // default is 111
metadata::get_u256(&meta, metadata::key(b"key"), 111)        : u256;  // default is 111
metadata::get_address(&meta, metadata::key(b"key"), @0xBEEF) : address;  // default is @0xBEEF

metadata::get_vec_bool(&meta, metadata::key(b"key"))     : vector<bool>;  // get_vec_* returns empty vector if there's nothing
metadata::get_vec_u8(&meta, metadata::key(b"key"))       : vector<u8>;
metadata::get_vec_u64(&meta, metadata::key(b"key"))      : vector<u64>;
metadata::get_vec_u128(&meta, metadata::key(b"key"))     : vector<u128>;
metadata::get_vec_address(&meta, metadata::key(b"key"))  : vector<address>;
metadata::get_vec_vec_u8(&meta, metadata::key(b"key"))   : vector<vector<u8>>;
```

#### Get information from metadata

It's generally your responsibility to keep `key -> data type` relation constant, 
but there're few helpful methods if you get lost and want to double-check:

Get total count of chunks in metadata vector:
```rust
metadata::get_chunks_count(&meta): u32
``` 

Get vector of chunk_id from metadata vector: 
```rust
metadata::get_chunks_ids(&meta): vector<u32>
```
NB: remember you can [convert that u32's to strings](#unpacking-the-key-back-to-vectorstring)  if you were used [`key` method](#key-hash-function) 

Check if specific chunk exists/set:
```rust
metadata::has_chunk(&meta, metadata::key(b"chunk_id")): bool
``` 

Check if specific chunk exists/set and has needed data type:
```rust
metadata::has_chunk_of_type<u64>(&meta, metadata::key(b"chunk_id")): bool
metadata::has_chunk_of_type<vector<address>>(&meta, metadata::key(b"chunk_id")): bool
// would work for any data type we have a getter for
``` 

If specific chunk stores vector, you can get count of elements in it without deserializing all chunk:
```rust
metadata::get_vec_length(&meta, metadata::key(b"chunk_id")): u64
```

#### Remove chunk from metadata

Simple as is:
```rust
metadata::remove_chunk(&mut meta, metadata::key(b"chunk_id")): bool
```

#### Key hash function

Each chunk in the metadata vector has unique chunk_id of `u32`, you can use it as number directly:

```rust
metadata::set(&mut meta, 777, &(b"something"));
metadata::get_vec_u8(&meta, 777);
```

or use a helping `key` hash function, transforming vector<u8> (in-code strings mostly) to u32:

```rust
metadata::set(&mut meta, metadata::key(&b"propertyname"), &(b"something"));
metadata::get_vec_u8(&meta, metadata::key(&b"propertyname"), 777);
```

`key` function produces different u32 values for different strings, 
all unique for up to 5 chars strings:
 - key(&b"test")  != key(&b"abba")
 - key(&b"test2") != key(&b"test3")
 - key(&b"1")     != key(&b"2")

constant
 - key(&b"test2") == key(&b"test2")

case-insensitive
 - key(&b"TEST") == key(&b"test")

different, but may be repeated values for long strings
 - key(&b"long_string_test_1") != key(&b"long_string_test_2")
 - key(&b"long_string_test_01") == key(&b"long_string_test_10")

returned u32 may be unpacked back to string using [`unpack_key` function](#unpacking-the-key-back-to-vectorstring)  

#### Unpacking the key back to vector<u8>/string

u32 created with `key` function may be unpacked back to string using `unpack_key`:

```rust
metadata::unpack_key(key: u32): vector<u8>
```

first 4 chars kept (though uppercased)
 - unpack_key(key(b"TEST")) == b"TEST"
 - unpack_key(key(b"test")) == b"TEST"

may have an extra hash at the end in case long string (>4 chars) was hashed:
 - unpack_key(key(b"TEST_long_string")) == b"TEST*005"
 - unpack_key(key(b"TEST_other_string")) == b"TEST*119"

#### Compress vector<u8>

You may optionally compress all metadata or specific chunk in it.
There's function to compress vector<u8> using sort of LZW (Lempel-Ziv-Welch) algorithm extended with u16->u8 variable-length encoding scheme:

```rust
let compressed: vector<u8> = metadata::compress(&rawvetoru8);
```

and decompress back to original:

```rust
let decompressed: vector<u8> = metadata::decompress(&compressed);
```

Compressing is slow and expensive. Decompressing is ok. So as a general advice, it would be better to compress the data on the client side if you plan to store something heavy to use as data in your package code.

#### Running unit tets

Compressing function is expensive and slow. If unit test fails with timeout, increase gas for it:

```bash
sui move test --gas-limit 5000000000
```

#### License

GNU AFFERO GENERAL PUBLIC LICENSE