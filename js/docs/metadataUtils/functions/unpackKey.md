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

[metadataUtils.ts:42](https://github.com/suidouble/suidouble_metadata/blob/c8de98ef7d95eb7a554d8420554b54fe98e6d77e/js/src/metadataUtils.ts#L42)
