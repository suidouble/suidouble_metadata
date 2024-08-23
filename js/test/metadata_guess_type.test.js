import { describe, expect, it } from "vitest";
import { Metadata } from "../src/Metadata";


describe("setting values with no type force", () => {
    const meta = new Metadata();
	it("u8-u32", () => {
		expect(meta.set('key8', 1)).toBeTruthy();
		expect(meta.set('key16', 2)).toBeTruthy();
		expect(meta.set('key32', 3)).toBeTruthy();

        expect(meta.getAnyU256('key8')).toEqual(1n);
        expect(meta.getAnyU256('key16')).toEqual(2n);
        expect(meta.getAnyU256('key32')).toEqual(3n);
	});

	it("u64-u256", () => {
		expect(meta.set('key64', 1000000000n)).toBeTruthy();
		expect(meta.set('key128', 1000000000n)).toBeTruthy();
		expect(meta.set('key256', 1000000000n)).toBeTruthy();

        expect(meta.getAnyU256('key64')).toEqual(1000000000n);
        expect(meta.getAnyU256('key128')).toEqual(1000000000n);
        expect(meta.getAnyU256('key256')).toEqual(1000000000n);
	});

	it("bool", () => {
		expect(meta.set('boolkey', true)).toBeTruthy();
        expect(meta.getBool('boolkey')).toEqual(true);
		expect(meta.set('boolkey', false)).toBeTruthy();
        expect(meta.getBool('boolkey')).toEqual(false);
    });

	it("string", () => {
		expect(meta.set('stringkey', 'Hey 😎!')).toBeTruthy();
        expect(meta.getString('stringkey')).toEqual('Hey 😎!');
    });

	it("address", () => {
		expect(meta.set('addresskey', '0x2')).toBeTruthy();
        expect(meta.getAddress('addresskey')).toEqual('0x0000000000000000000000000000000000000000000000000000000000000002');
    });

	it("vector<address>", () => {
		expect(meta.set('addresskey', ['0x2', '0x3'])).toBeTruthy();
        expect(meta.getVecAddress('addresskey')).toEqual(['0x0000000000000000000000000000000000000000000000000000000000000002','0x0000000000000000000000000000000000000000000000000000000000000003']);
    });

	it("vector<u8>", () => {
		expect(meta.set('vu8key', new Uint8Array([1,2,3]))).toBeTruthy();
        expect(meta.getVecU8('vu8key')).toEqual(new Uint8Array([1,2,3]));
    });

	it("vector<u16>", () => {
		expect(meta.set('vu16key', new Uint16Array([1,2,3]))).toBeTruthy();
        expect(meta.getVecU16('vu16key')).toEqual(new Uint16Array([1,2,3]));
    });

	it("vector<u32>", () => {
		expect(meta.set('vu32key', new Uint32Array([1,2,3]))).toBeTruthy();
        expect(meta.getVecU32('vu32key')).toEqual(new Uint32Array([1,2,3]));
    });

	it("vector<bool>", () => {
		expect(meta.set('vecboolkey', [true, true, false])).toBeTruthy();
        expect(meta.getVecBool('vecboolkey')).toEqual([true, true, false]);
    });

	it("vector<u256>", () => {
		expect(meta.set('vec256key', [1n,2n,9999999999n])).toBeTruthy();
        expect(meta.getAnyVecU256('vec256key')).toEqual([1n,2n,9999999999n]);
    });

	it("vector<vector<u8>>", () => {
        const childMeta = new Metadata();
        childMeta.set('key', 2);

		expect(meta.set('vecveckey', [childMeta.toBytes(), childMeta.toBytes()])).toBeTruthy();
        const internals = meta.getVecVecU8('vecveckey');

        const restoredMeta = new Metadata(internals[0]);
        expect(restoredMeta.getU8('key')).toEqual(2);

        const restoredMeta2 = new Metadata(internals[1]);
        expect(restoredMeta2.getU8('key')).toEqual(2);
        // expect(restoredMeta.getU32('key')).toEqual(2);
        // expect(restoredMeta.getU32('key')).toEqual(2);
    });

});