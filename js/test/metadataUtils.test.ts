import { describe, expect, it } from "vitest";

import { key, unpackKey } from "../src/metadataUtils";


describe("key", () => {
	// following test from Move package:
	//   https://github.com/suidouble/suidouble_metadata/blob/main/metadata/sources/metadata_tests.move
	//   test_key_hash()

	it("basic key hashing", () => {
		expect(key("")).toEqual(key(""));
		expect(key("aaaa")).toEqual(key("aAAa"));
		expect(key("aaaa")).toEqual(key("AAAA"));
		expect(key("Z872")).toEqual(key("z872"));
	});

	it("long key hashing", () => {
        // // any string length is supported ( though only first chars generates 100% unique u32 )
		expect(key("test_long_string")).toEqual(key("test_long_string"));
        // // long part is case-insensitive too
		expect(key("test_long_string")).toEqual(key("test_long_STRING"));
        // // still, it works in a hash-like way, taking all chars into account:
		expect(key("test_long_string1")).not.toEqual(key("test_long_string2"));
		expect(key("test_long_stringK")).not.toEqual(key("test_long_stringU"));

        // // may generate same hash with long strings though:  !!!!!  it's only u32, so
		expect(key("test_long_string01")).toEqual(key("test_long_string10"));
	});


	it("unpacking keys", () => {
        // // u32 hash may be decoded back to string:   
		expect(unpackKey(key("TEST"))).toEqual('TEST');
		expect(unpackKey(key("test"))).toEqual('TEST');
		expect(unpackKey(key("h1"))).toEqual('H1');
		expect(unpackKey(key(" "))).toEqual(' ');
		expect(unpackKey(key("! !"))).toEqual('! !');

	});

	it("unpacking long keys", () => {
		expect(unpackKey(key("TEST_long_string"))).toEqual('TEST*197');
		expect(unpackKey(key("TEST_other_string"))).toEqual('TEST*023');
		expect(unpackKey(key("TEST!"))).toEqual('TEST*033');

        // // note, it may unpack to the same string, even though long part of the string was different ( it's only u32, sorry )
		expect(unpackKey(key("test_long_string01"))).toEqual('TEST*038');
		expect(unpackKey(key("test_long_string10"))).toEqual('TEST*038');
	});
});
