import { describe, expect, it } from "vitest";

import { typeBinaryLength } from "../src/metadataTypes";

describe("typeBinaryLength", () => {
	it("basic types", () => {
		expect(typeBinaryLength('u8')).toEqual(1);
		expect(typeBinaryLength('u16')).toEqual(2);
		expect(typeBinaryLength('u32')).toEqual(4);
		expect(typeBinaryLength('u64')).toEqual(8);
		expect(typeBinaryLength('u128')).toEqual(16);
		expect(typeBinaryLength('u256')).toEqual(32);
		expect(typeBinaryLength('bool')).toEqual(1);
		expect(typeBinaryLength('address')).toEqual(32);
	});
});
