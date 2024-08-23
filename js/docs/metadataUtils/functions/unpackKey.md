[**suidouble_metadata**](../../README.md) • **Docs**

***

[suidouble_metadata](../../modules.md) / [metadataUtils](../README.md) / unpackKey

# Function: unpackKey()

> **unpackKey**(`key`): `string`

Unpack key back to the string vector of it, 
    first 4 chars kept (though uppercased)
        unpack_key(key("TEST")) == "TEST"
        unpack_key(key("test")) == "TEST"
    may have an extra hash at the end in case long string (>4 chars) was hashed:
        unpack_key(key("TEST_long_string")) == "TEST*005"
        unpack_key(key("TEST_other_string")) == "TEST*119"

## Parameters

• **key**: `number` \| `bigint`

## Returns

`string`

## Defined in

metadataUtils.ts:42
