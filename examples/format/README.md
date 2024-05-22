# suidouble_metadata::format

A module with a set of methods to perform formatting on the strings, similar to `printf`/`sprintf` functions. Trying to follow Rust formatting style and `Display` module logic.

Accepts a [metadata](../../)'s `vector<u8>` as a list of arguments.

```rust
format::format(&b"Hey {}", &metadata::single(&b"world")) == b"Hey world"
```

Multiple and named argumets support:

```rust
let mut meta:vector<u8> = b"";
metadata::set(&mut meta, metadata::key(&b"what"), &b"world");
metadata::set(&mut meta, metadata::key(&b"balance"), &91u64);

format::format(&b"Hey {}, your balance is {}", &meta) == b"Hey world, your balance is 91" 
format::format(&b"Hey {what}, your balance is {balance}", &meta) == b"Hey world, your balance is 91" 
format::format(&b"Hey {what}, your balance is {}", &meta) == b"Hey world, your balance is world"  // same as in Rust, named-nonamed flow
format::format(&b"Hey {balance}, your balance is {what}", &meta) == b"Hey 91, your balance is world" 
format::format(&b"Hey {}, your balance is {} and maybe {}", &meta) == b"Hey world, your balance is 91 and maybe {???}" 
```

On the inside it tries to guess needed output format depending on what's inside metadata, but as we don't store types directly, you may want 
to force formatting, there're tags modifiers for this:

```rust
format::format(&b"Hey {:s}", &metadata::single(&b"world")) == b"Hey world"     // string
format::format(&b"Hey {:i}", &metadata::single(&6000u128)) == b"Hey 6000"      // integer, works for any u, u8...u256 
format::format(&b"Hey {:x}", &metadata::single(&x"00fafa")) == b"Hey 0x00fafa" // as hex
format::format(&b"Hey {:X}", &metadata::single(&x"00fafa")) == b"Hey 0x00FAFA" // as hex uppercased
format::format(&b"Hey {:y}", &metadata::single(&@0xBABE) == b"Hey 0xbabe"  // as hex without leading empty bytes
format::format(&b"Hey {:Y}", &metadata::single(&@0xBABE)) == b"Hey 0xBABE" // as hex without leading empty bytes
format::format(&b"Hey {:B}", &metadata::single(&true)) == b"Hey true"      // boolean
// array of numbers:
format::format(&b"Hey {:a}", &metadata::single(&vector<u64>[1,2,3,4])) == b"Hey [1, 2, 3, 4]" 
// array of hex:
format::format(&b"Hey {:A}", &metadata::single(&vector<u64>[1,2,3,4])) == b"Hey [0x01, 0x02, 0x03, 0x04, 0xff]"
```

Named tags and formats may be combined:

```rust
format(&b"Hey {balance:i} {what:s}", &meta) == b"Hey 91 world"
```

With helping methods to format `std::acsii` and `std::string` Strings: `format_ascii` and `format_string`, which accept and return related module `String` objects.

```rust
let ascii_string = ascii::string(b"Try format as String object, {:s}, ok?");
let output_ascii_string = format::format_ascii(&ascii_string, &metadata::single(&b"world"));
assert!(output_ascii_string.into_bytes() == b"Try format as String object, world, ok?", 0);
debug::print(&output_ascii_string);


let utf8_string = string::utf8(b"Try format as String 💧 object, {:s}, ok?");
let output_utf8_string = format::format_string(&utf8_string, &metadata::single(&b"w🌐rld"));
assert!(output_utf8_string.bytes() == b"Try format as String 💧 object, w🌐rld, ok?", 0);
debug::print(&output_utf8_string);
```