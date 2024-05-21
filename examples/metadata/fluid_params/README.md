### fluid_params

Pattern to pass multiple params to function as a single argument of metadata vector.

```rust
public entry fun set(person: &mut Person, params: &vector<u8>) {
    if (metadata::has_chunk_of_type<u64>(params, metadata::key(&b"age"))) {
        person.age = metadata::get_u64(params, metadata::key(&b"age"), 0); // 0 - default
    } else if (metadata::has_chunk_of_type<u8>(params, metadata::key(&b"age"))) { // just a helper so you can pass age as u8 too
        person.age = (metadata::get_u8(params, metadata::key(&b"age"), 0) as u64); // 0 - default
    };

    if (metadata::has_chunk_of_type<bool>(params, metadata::key(&b"female"))) {
        person.female = metadata::get_bool(params, metadata::key(&b"female"), false); // false - default
    };
    if (metadata::has_chunk_of_type<address>(params, metadata::key(&b"sui_address"))) {
        person.sui_address = metadata::get_address(params, metadata::key(&b"sui_address"), @0xABBA); // 0 - default
    };
    if (metadata::has_chunk_of_type<vector<u8>>(params, metadata::key(&b"name"))) {
        person.name = metadata::get_vec_u8(params, metadata::key(&b"name"));
    };
}

let mut params:vector<u8> = vector::empty();
metadata::set(&mut params, metadata::key(&b"female"), &true);
metadata::set(&mut params, metadata::key(&b"age"), &(93 as u64));
metadata::set(&mut params, metadata::key(&b"sui_address"), &@0xBBBAAA);
metadata::set(&mut params, metadata::key(&b"name"), &b"Master of Karate");

set(&mut person, &params);
```

you may build your own logic, make some params required (aborting if they are undefined), support multiple data types etc.

Take a look at example code and unit test inside of it.