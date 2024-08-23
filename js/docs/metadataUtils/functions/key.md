[**suidouble_metadata**](../../README.md) • **Docs**

***

[suidouble_metadata](../../modules.md) / [metadataUtils](../README.md) / key

# Function: key()

> **key**(`str`): `bigint`

Pack a string into the number holding a maximum of 4 bytes of data 
    produce different values for different strings, all unique for up to 5 chars strings:
      key("test")  != key("abba")
      key("test2") != key("test3")
      key("1")     != key("2")

    constant
      key("test2") == key("test2")

    different, but may be repeated values for long strings
      key("long_string_test_1") != key("long_string_test_2")
      key("long_string_test_01") == key("long_string_test_10")

    returned number may be unpacked back to string using unpackKey  function

## Parameters

• **str**: `string`

## Returns

`bigint`

## Defined in

[metadataUtils.ts:91](https://github.com/suidouble/suidouble_metadata/blob/c8de98ef7d95eb7a554d8420554b54fe98e6d77e/js/src/metadataUtils.ts#L91)
