# suidouble_metadata
Move library and a set of tools to store/retrieve/manage any type of data inside u8 vector

#### Using

The first step is to have `vector<u8>` ready to store metadata. 
Declare it anywhere, assign to the `struct` you are going to use in your package, like:

```move
    struct YourPerfectNFT has key, store {
        ...,
        metadata: vector<u8>,
    }
```

and don't think about any issues with contract upgrades in the future. 
You'll be able to store/manage any primitive data in vector as chunks. 

And here's the library to help you with this.

```move
    use suidouble_metadata::metadata;
```

#### quick usage example

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

#### key

Each chunk in the metadata vector has unique chunk_id of `u32`, you can use it as number directly:

```move
    metadata::set(&mut meta, 777, &(b"something"));
    metadata::get_vec_u8(&meta, 777);
```

or use a helping `key` hash function, transforming vector<u8> (in-code strings mostly) to u32:

```move
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

returned u32 may be unpacked back to string using `unpack_key` function   

```move
    metadata::unpack_key(key: u32): vector<u8>
```

first 4 chars kept (though uppercased)
 - unpack_key(key(b"TEST")) == b"TEST"
 - unpack_key(key(b"test")) == b"TEST"

may have an extra hash at the end in case long string (>4 chars) was hashed:
 - unpack_key(key(b"TEST_long_string")) == b"TEST*005"
 - unpack_key(key(b"TEST_other_string")) == b"TEST*119"

#### set metadata

```move
    public fun set<T>(metadata: &mut vector<u8>, chunk_id: u32, value: &T): bool {
```


#### Runnin unit tets

Compressing function is expensive and slow. If unit test fails with timeout, increase gas for it:

```bash
sui move test --gas-limit 5000000000
```