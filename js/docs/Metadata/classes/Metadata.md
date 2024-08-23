[**suidouble_metadata**](../../README.md) • **Docs**

***

[suidouble_metadata](../../modules.md) / [Metadata](../README.md) / Metadata

# Class: Metadata

## Constructors

### new Metadata()

> **new Metadata**(`data`): [`Metadata`](Metadata.md)

#### Parameters

• **data**: `undefined` \| `string` \| `Uint8Array`

#### Returns

[`Metadata`](Metadata.md)

#### Defined in

Metadata.ts:8

## Properties

### serialized

> **serialized**: `Uint8Array`

#### Defined in

Metadata.ts:7

## Accessors

### byteLength

> `get` **byteLength**(): `bigint`

#### Returns

`bigint`

#### Defined in

Metadata.ts:20

## Methods

### get()

> **get**(`chunkId`): `null` \| `Uint8Array`

Get Uint8Array for a chunkId from metadata, returns null if there's no data for this chunkId

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`null` \| `Uint8Array`

#### Defined in

Metadata.ts:359

***

### getAddress()

> **getAddress**(`chunkId`): `null` \| `string`

Get a address string from chunk, set as set(chunkId, 'address', '0x25345345...');

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`null` \| `string`

#### Defined in

Metadata.ts:123

***

### getAnyU256()

> **getAnyU256**(`chunkId`, `defaultValue`): `bigint`

Get any u, u8, u16, u32, u64, u128, u256   as a single u256 from the chunk of metadata, 
 with default parameter in case there's no such chunk

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

• **defaultValue**: `bigint`

#### Returns

`bigint`

#### Defined in

Metadata.ts:271

***

### getAnyVecU256()

> **getAnyVecU256**(`chunkId`): `bigint`[]

Get any vec, vec<u8>, vec<u16>, vec<u32>, vec<u64>, vec<u128>, vec<u256>, vec<bool>, vec<address> as vec<u256>

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`bigint`[]

#### Defined in

Metadata.ts:217

***

### getBool()

> **getBool**(`chunkId`): `boolean`

Get a `bool` from the chunk of metadata vector, returns defaultValue if there's no chunk

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`boolean`

#### Defined in

Metadata.ts:319

***

### getChunkLengthAtOffset()

> **getChunkLengthAtOffset**(`metadataOffset`): `bigint`

Get length of metadata chunk located at metadata_offset in metadata

#### Parameters

• **metadataOffset**: `bigint`

#### Returns

`bigint`

#### Defined in

Metadata.ts:380

***

### getChunkOffset()

> **getChunkOffset**(`chunkId`): `bigint`

Find offset at which chunk_id metadata chunk is located inside metadata

#### Parameters

• **chunkId**: `bigint`

#### Returns

`bigint`

#### Defined in

Metadata.ts:501

***

### getChunksCount()

> **getChunksCount**(): `number`

#### Returns

`number`

#### Defined in

Metadata.ts:24

***

### getChunksIds()

> **getChunksIds**(): `bigint`[]

Get chunks ids in metadata vector<u8>

#### Returns

`bigint`[]

#### Defined in

Metadata.ts:525

***

### getString()

> **getString**(`chunkId`): `string`

Get a string from vector<u8> chunk, set as set(chunkId, 'string', 'value');

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`string`

#### Defined in

Metadata.ts:116

***

### getU128()

> **getU128**(`chunkId`, `defaultValue`): `bigint`

Get a `u128` bigint from the chunk of metadata vector, returns defaultValue if there's no chunk

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

• **defaultValue**: `bigint`

#### Returns

`bigint`

#### Defined in

Metadata.ts:345

***

### getU16()

> **getU16**(`chunkId`, `defaultValue`): `number`

Get a `u16` from the chunk of metadata vector, returns defaultValue if there's no chunk

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

• **defaultValue**: `number`

#### Returns

`number`

#### Defined in

Metadata.ts:325

***

### getU256()

> **getU256**(`chunkId`, `defaultValue`): `bigint`

Get a `u256` bigint from the chunk of metadata vector, returns defaultValue if there's no chunk

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

• **defaultValue**: `bigint`

#### Returns

`bigint`

#### Defined in

Metadata.ts:351

***

### getU32()

> **getU32**(`chunkId`, `defaultValue`): `number`

Get a `u32` from the chunk of metadata vector, returns defaultValue if there's no chunk

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

• **defaultValue**: `number`

#### Returns

`number`

#### Defined in

Metadata.ts:331

***

### getU64()

> **getU64**(`chunkId`, `defaultValue`): `bigint`

Get a `u64` bigint from the chunk of metadata vector, returns defaultValue if there's no chunk

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

• **defaultValue**: `bigint`

#### Returns

`bigint`

#### Defined in

Metadata.ts:339

***

### getU8()

> **getU8**(`chunkId`, `defaultValue`): `number`

Get a `u8` from the chunk of metadata vector, returns defaultValue if there's no chunk

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

• **defaultValue**: `number`

#### Returns

`number`

#### Defined in

Metadata.ts:313

***

### getVecAddress()

> **getVecAddress**(`chunkId`): `string`[]

Get a vector of `address` from the chunk of metadata vector, returns empty array if there's no chunk

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`string`[]

#### Defined in

Metadata.ts:133

***

### getVecBool()

> **getVecBool**(`chunkId`): `boolean`[]

Get a vector of `bool` from the chunk of metadata vector, returns empty array if there's no chunk

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`boolean`[]

#### Defined in

Metadata.ts:155

***

### getVecLength()

> **getVecLength**(`chunkId`): `null` \| `bigint`

Get length of vector inside chunk_id

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`null` \| `bigint`

#### Defined in

Metadata.ts:489

***

### getVecU128()

> **getVecU128**(`chunkId`): `bigint`[]

Get a vector of `u128` from the chunk of metadata vector, returns empty Array if there's no chunk. Array elemets are bigint

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`bigint`[]

#### Defined in

Metadata.ts:196

***

### getVecU16()

> **getVecU16**(`chunkId`): `Uint16Array`

Get a vector of `u16`  from the chunk of metadata vector, returns empty Uint16Array if there's no chunk

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`Uint16Array`

#### Defined in

Metadata.ts:166

***

### getVecU256()

> **getVecU256**(`chunkId`): `bigint`[]

Get a vector of `u256` from the chunk of metadata vector, returns empty Array if there's no chunk. Array elemets are bigint

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`bigint`[]

#### Defined in

Metadata.ts:206

***

### getVecU32()

> **getVecU32**(`chunkId`): `Uint32Array`

Get a vector of `u32`  from the chunk of metadata vector, returns empty Uint32Array if there's no chunk

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`Uint32Array`

#### Defined in

Metadata.ts:176

***

### getVecU64()

> **getVecU64**(`chunkId`): `bigint`[]

Get a vector of `u64` from the chunk of metadata vector, returns empty Array if there's no chunk. Array elemets are bigint

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`bigint`[]

#### Defined in

Metadata.ts:186

***

### getVecU8()

> **getVecU8**(`chunkId`): `Uint8Array`

Get a vector of `u8` (eg string) from the chunk of metadata vector, returns empty Uint8Array if there's no chunk

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`Uint8Array`

#### Defined in

Metadata.ts:144

***

### getVecVecU8()

> **getVecVecU8**(`chunkId`): `Uint8Array`[]

Get a vector of binary Uint8Array from the chunk of metadata vector, returns empty Array if there's no chunk

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`Uint8Array`[]

#### Defined in

Metadata.ts:256

***

### hasChunk()

> **hasChunk**(`chunkId`): `boolean`

Returns true, if there's metadata chunk with id of chunkId

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`boolean`

#### Defined in

Metadata.ts:470

***

### hasChunkOfType()

> **hasChunkOfType**(`chunkId`, `typeName`): `boolean`

Returns true, if there's metadata chunk with id of chunk_id and it has type of typeName

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

• **typeName**: [`MetadataType`](../../metadataTypes/type-aliases/MetadataType.md)

#### Returns

`boolean`

#### Defined in

Metadata.ts:392

***

### normalizeChunkId()

> **normalizeChunkId**(`chunkId`): `bigint`

Normalize chunkId so for any supported type, it returns bigint with max of 4 significant bytes

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

number, bigint or string to be hashed as key

#### Returns

`bigint`

bigint

#### Defined in

Metadata.ts:40

***

### removeChunk()

> **removeChunk**(`chunkId`): `boolean`

Remove a chunk from metadata

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

#### Returns

`boolean`

#### Defined in

Metadata.ts:100

***

### set()

> **set**(`chunkId`, `value`, `typeName`): `boolean`

Set metadata chunk of ChunkId to value

#### Parameters

• **chunkId**: [`ChunkId`](../type-aliases/ChunkId.md)

• **value**: `any`

• **typeName**: `undefined` \| [`MetadataType`](../../metadataTypes/type-aliases/MetadataType.md)

#### Returns

`boolean`

#### Defined in

Metadata.ts:50

***

### toBytes()

> **toBytes**(): `Uint8Array`

Get binary Uint8Array of metadata

#### Returns

`Uint8Array`

#### Defined in

Metadata.ts:31

***

### u32FromLEBytesAtOffset()

> **u32FromLEBytesAtOffset**(`offset`): `bigint`

Read u32 (LE 4 bytes) from specified position in vector<u8>

#### Parameters

• **offset**: `bigint`

#### Returns

`bigint`

#### Defined in

Metadata.ts:543
