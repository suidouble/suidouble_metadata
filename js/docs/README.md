**suidouble_metadata** • [**Docs**](modules.md)

***

# suidouble_metadata

JavaScript/TS library implementing the logic of [Suidouble_metadata Move module](https://github.com/suidouble/suidouble_metadata), letting you storing/managing any type of primitive data inside a single Uint8Array.

The only sui dependency is `@mysten/bcs` which is quite tiny, so feel free to use this library for other chains or off-chain data serilization.

## Installation

```bash
npm install suidouble_metadata --save
```

## Usage

```javascript
import { Metadata } from 'suidouble_metadata';
const meta = new Metadata();
meta.set('chunkKey', 'chunkValue');
meta.set('chunk2Key', [2222n,333n]);
const asBytes = meta.toBytes(); // Uint8Array

const restored = new Metadata(asBytes);
const string = meta.getString('chunkKey'); // 'chunkValue'
const arr = meta.getAnyVecU256('chunk2Key'); // [2222n,333n]
```

## Add chunk to metadata

```javascript
const meta = new Metadata();
meta.set('chunk_id_as_string', value);
meta.set('chunk_id_as_string2', value, typeName);
```

typeName is optional, if no typeName passed, it tries to guess data type by value content. Though, in the perfect world, you'll probably need to force typeName if you plan to decode metadata on the Move side, just to be sure types are correct:

```javascript
meta.set('chunk_id', 200, 'u8');
meta.set('chunk_id', 'test', 'string');
meta.set('chunk_id', 999999999n, 'u256');
meta.set('chunk_id', [1, 2, 3], 'vector<u8>');
```

### String, address

Library converts strings on the fly into `vector<u8>` so you can follow the Move module logic. Strings starting with `0x` containing 0-9a-f treated as addresses ( or object ids ) by default, internally storing as `u256` following the Move logic:

```javascript
meta.set('chunk_id', 'stringlyvalue'); // string
meta.set('chunk_id', '0xfa7ac3951fdca92c5200d468d31a365eb03b2be9936fde615e69f0c1274ad3a0'); // address
```

Remember you can force the type, like saving the address as string:
```javascript
meta.set('chunk_id', '0xfa7ac3951fdca92c5200d468d31a365eb03b2be9936fde615e69f0c1274ad3a0', 'string');
```

### Supported primitive types

- `u8`, `u16`, `u32` - pass a number
- `u64`, `u128`, `u256` - pass a bigint
- `bool` - pass a boolean
- `address` - pass a string starting with 0x
- `string` - stored as `vector<u8>` with convesion on the fly
- `vector<u8>`, `vector<u32>`, `vector<u32>` - passed/returned as Uint8Array, Uint16Array, Uint32Array
- `vector<u64>`, `vector<u128>`, `vector<u256>` - passed/returned as array of bigints, e.g. [22n, 9999999n, BigInt(3232)]
- `vector<address>` - passed/returned as array of strings, e.g ['0x2', '0xfa7ac3951fdca92c5200d468d31a365eb03b2be9936fde615e69f0c1274ad3a0']
- `vector<vector<u8>>` - [new Uint8Array([1,2,3]), new Uint8Array(4,5,6)], may be used to store child metadata objects ( meta.toBytes() )
- `vector<bool>` - [true, false, true]

## Chunk keys

Chunk key is stored in metadata as `u32` and library has internal helpers to transofrm any string into it.

So this two setters are doing the same:

```javascript
import { Metadata, key, unpackKey } from 'suidouble_metadata';
meta.set('key', 'value');   
meta.set(key('key'), 'value');
```

Futhermore, you can unpack keys into human-readable format from metadata:

```javascript
unpackKey(meta.getChunksIds()[0]); // 'KEY'
```

Reminder, that metadata keys storing up to 4 chars and extra hash for a long key strings, so for longer keys output would be truncated:

```javascript
const unpacked = unpackKey(key('TEST_long_string')); // "TEST*005"
const unpacked = unpackKey(key('TEST_other_string')); // "TEST*119"
```

## Get chunk from metadata

- `.get(chunkId)` - get raw chunk of data as Uint8Array | null if there's no chunk for this chunkId
- `.getU8(chunkId, defaultValue)` `.getU16(chunkId, defaultValue)` `.getU32(chunkId, defaultValue)` - get a number from chunk, returns `defaultValue` if there's no such chunk
- `.getU64(chunkId, defaultValue)` `.getU128(chunkId, defaultValue)`  `.getU256(chunkId, defaultValue)` - get a bigint from chunk, returns `defaultValue` if there's no such chunk
- `.getAnyU256(chunkId, defaultValue)` - get a bigint from any u8..u256 chunk stored in metadata, returns `defaultValue` if there's no such chunk
- `.getBool(chunkId)` - get `bool` stored in the chunk of chunkId
- `.getAddress(chunkId)` - get object id / address as a string, stored in metadata as u256 or as .set(v:address) in Move
- `.getString(chunkId)` - get string converted from `vector<u8>` on the fly from the chunk of chunkId, returns empty string if there's no chunk
- `.getVecU8(chunkId)` - get Uint8Array from the chunk
- `.getVecU16(chunkId)` - get Uint16Array from the chunk
- `.getVecU32(chunkId)` - get Uint32Array from the chunk
- `.getVecU64(chunkId)`  `.getVecU128(chunkId)`  `.getVecU256(chunkId)` - get array of bigint from the chunk.
- `.getAnyVecU256(chunkId)` - get array of any u8...u256 as array of bigint from the chunk
- `.getVecLength(chunkId)` - get length of the vector in the chunk without deserializing it
- `.getVecVecU8(chunkId)` - get `vector<vector<u8>>` from the chunk. 

`suidouble_metadata` doesn't store data type inside of serialized vector. So it's generally your responsibility to keep type-key relation constant. Though, there're few helping methods to let you check the type of data stored in chunk:

- `.hasChunk(chunkId)` - returns true if there's chunk in metadata
- `.hasChunkOfType(chunkId, typeName)` - returns true if there's chunk in metadata and you can get it back as specified type
- `.getChunksIds()` - get array of chunkIds from the metadata
- `.getChunksCount()` - get count of chunks in metadata

### Remove a chunk from metadata

- `.removeChunk(chunkId)`

### Get binary represenation of metadata

- `.toBytes()` - returns `Uint8Array` you can use it to pass to move methods or deserialize Metadata again with `new Metadata(bytes)`

#### License

GNU AFFERO GENERAL PUBLIC LICENSE

Means, just fork this lib if you are using it for production and do some changes, don't hide it in your private project repo.
