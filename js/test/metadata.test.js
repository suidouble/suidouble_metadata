import { describe, expect, it } from "vitest";
import { Metadata } from "../src/Metadata";

describe("empty metadata", () => {
    const meta = new Metadata();

	it("has no chunks", () => {
		expect(meta.getChunksIds().length).toEqual(0);
	});
	it("has no chunk of id == 0", () => {
		expect(meta.hasChunk(0n)).toBeFalsy();
	});
	it("has no data for a chunkId == 0", () => {
		expect(meta.get(0n)).toEqual(null);
	});
});

describe("sample metadata", () => {
	// binary metadata generated on Move for a quick test
    const meta = new Metadata('0x00020000000900000005030000001200000009736f6d657468696e67');

	it("has chunks", () => {
		expect(meta.getChunksIds().length).toEqual(2);
	});
	it("has chunks of id 2 and 3", () => {
		expect(meta.hasChunk(2)).toBeTruthy();
		expect(meta.hasChunk(3)).toBeTruthy();
	});
	it("chunk 2 is u8", () => {
		expect(meta.hasChunkOfType(2, 'u8')).toBeTruthy();
		expect(meta.hasChunkOfType(2, 'u16')).toBeFalsy();
		expect(meta.hasChunkOfType(2, 'u32')).toBeFalsy();
		expect(meta.hasChunkOfType(2, 'u64')).toBeFalsy();
		expect(meta.hasChunkOfType(2, 'u128')).toBeFalsy();
		expect(meta.hasChunkOfType(2, 'u256')).toBeFalsy();
		expect(meta.hasChunkOfType(2, 'vector<bool>')).toBeFalsy();

        expect(meta.getAnyU256(2)).toEqual(5n);  // there's 5 inside, getAnyU256 returns bigint
        expect(meta.getU8(2)).toEqual(5);  // there's 5 inside, getU8, getU16, getU32 return number
	});
	it("chunk 3 is vector<u8>", () => {
		expect(meta.hasChunkOfType(3, 'vector<u8>')).toBeTruthy();
		expect(meta.hasChunkOfType(3, 'vector<u16>')).toBeFalsy();
		expect(meta.hasChunkOfType(3, 'vector<bool>')).toBeFalsy(); // same data length, but there're other bytes than 0..1
		expect(meta.hasChunkOfType(3, 'vector<u256>')).toBeFalsy();

		expect(meta.getVecLength(3)).toEqual(9n); // is a string of 9 bytes
    });
	it("lets set another chunk", () => {
		expect(meta.set(4, 200, 'u8')).toBeTruthy();
		expect(meta.getChunksIds().length).toEqual(3);
		expect(meta.hasChunkOfType(4, 'u8')).toBeTruthy();

        expect(meta.getAnyU256(4)).toEqual(200n);  // there's 200 inside, getAnyU256 returns bigint
        expect(meta.getU8(4)).toEqual(200);  // there's 200 inside, getU8, getU16, getU32 return number
	});
	it("lets set chunk of vector u8", () => {
		expect(meta.set(5, new Uint8Array([1,2,3]),  'vector<u8>')).toBeTruthy();
		expect(meta.hasChunkOfType(5, 'vector<u8>')).toBeTruthy();
		const getBack = meta.getVecU8(5);
		expect(getBack).toBeTruthy();
		expect(getBack.length).toEqual(3);
		expect(getBack).toEqual(new Uint8Array([1,2,3]));
	});
	it("lets set chunk of vector u16", () => {
		expect(meta.set(6, new Uint16Array([1,2,3]), 'vector<u16>')).toBeTruthy();
		expect(meta.hasChunkOfType(6, 'vector<u16>')).toBeTruthy();
		const getBack = meta.getVecU16(6);
		expect(getBack).toBeTruthy();
		expect(getBack.length).toEqual(3);
		expect(getBack).toEqual(new Uint16Array([1,2,3]));
	});
	it("lets set chunk of vector u32", () => {
		expect(meta.set(7, new Uint32Array([1,2,3,99999999]), 'vector<u32>')).toBeTruthy();
		expect(meta.hasChunkOfType(7, 'vector<u32>')).toBeTruthy();
		const getBack = meta.getVecU32(7);
		expect(getBack).toBeTruthy();
		expect(getBack.length).toEqual(4);
		expect(getBack).toEqual(new Uint32Array([1,2,3,99999999]));
	});

	it("lets set a chunk of u64", () => {
		expect(meta.set(8, BigInt(999999),  'u64')).toBeTruthy();
		expect(meta.hasChunkOfType(8, 'u64')).toBeTruthy();
		expect(meta.getU64(8)).toEqual(BigInt(999999));
        expect(meta.getAnyU256(8)).toEqual(999999n);
	});

	it("lets set a chunk of u128", () => {
		expect(meta.set(9, BigInt(999999),  'u128')).toBeTruthy();
		expect(meta.hasChunkOfType(9, 'u128')).toBeTruthy();
		expect(meta.getU128(9)).toEqual(BigInt(999999));

        expect(meta.getAnyU256(9)).toEqual(999999n);
	});

	it("lets set a chunk of u256", () => {
		expect(meta.set(10, BigInt(999999), 'u256')).toBeTruthy();
		expect(meta.hasChunkOfType(10, 'u256')).toBeTruthy();
		expect(meta.getU256(10)).toEqual(BigInt(999999));

        expect(meta.getAnyU256(10)).toEqual(999999n);
	});

	it("lets set a chunk of u16", () => {
		expect(meta.set(11, 9999, 'u16')).toBeTruthy();
		expect(meta.hasChunkOfType(11, 'u16')).toBeTruthy();
		expect(meta.getU16(11)).toEqual(9999);
        expect(meta.getAnyU256(11)).toEqual(9999n);
	});

	it("lets set a chunk of u32", () => {
		expect(meta.set(12, 9999,  'u32')).toBeTruthy();
		expect(meta.hasChunkOfType(12, 'u32')).toBeTruthy();
		expect(meta.getU32(12)).toEqual(9999);
        expect(meta.getAnyU256(12)).toEqual(9999n);
	});



	it("lets set chunk of vector u64", () => {
		expect(meta.set(13, [1n,1000n,10000000n], 'vector<u64>' )).toBeTruthy();
		expect(meta.hasChunkOfType(13, 'vector<u64>')).toBeTruthy();
		const getBack = meta.getVecU64(13);
		expect(getBack).toEqual( [1n,1000n,10000000n] );

		expect(meta.getAnyVecU256(13)).toEqual(  [1n,1000n,10000000n] );
	});


	it("lets set chunk of vector u128", () => {
		expect(meta.set(14, [1n,1000n,10000000n], 'vector<u128>' )).toBeTruthy();
		expect(meta.hasChunkOfType(14, 'vector<u128>')).toBeTruthy();
		const getBack = meta.getVecU128(14);
		expect(getBack).toEqual( [1n,1000n,10000000n] );

		expect(meta.getAnyVecU256(14)).toEqual(  [1n,1000n,10000000n] );
	});


	it("lets set chunk of vector u256", () => {
		expect(meta.set(15, [1n,1000n,10000000n], 'vector<u256>' )).toBeTruthy();
		expect(meta.hasChunkOfType(15, 'vector<u256>')).toBeTruthy();
		const getBack = meta.getVecU256(15);
		expect(getBack).toEqual( [1n,1000n,10000000n] );

		expect(meta.getAnyVecU256(15)).toEqual(  [1n,1000n,10000000n] );
	});

	it("lets set chunk of string", () => {
		expect(meta.set(16, 'Hey there!', 'string')).toBeTruthy();
		expect(meta.hasChunkOfType(16, 'string')).toBeTruthy();
		expect(meta.getString(16)).toEqual('Hey there!');
	});

	it("lets set chunk of string with unicode", () => {
		expect(meta.set(17, 'Hey 😎!', 'string')).toBeTruthy();
		expect(meta.hasChunkOfType(17, 'string')).toBeTruthy();
		expect(meta.getString(17)).toEqual('Hey 😎!');
	});

	it("gets a string added into sample by Move code", () => {
		expect(meta.hasChunkOfType(3, 'string')).toBeTruthy();
		expect(meta.getString(3)).toEqual('something');
	});


	it("lets update a chunk with same type of data", () => {
		meta.set('test', 'hey', 'string');
		expect(meta.getString('test')).toEqual('hey');
		meta.set('test', 'hay', 'string');
		expect(meta.getString('test')).toEqual('hay');
	});

	it("lets update a chunk with different type of data", () => {
		meta.set('test', 'hey', 'string');
		expect(meta.getString('test')).toEqual('hey');
		meta.set('test', 'hey bro 😎', 'string');
		expect(meta.getString('test')).toEqual('hey bro 😎');
		meta.set('test', 12,  'u8');
		expect(meta.getU8('test')).toEqual(12);
	});

	it("let add a chunk of vector<vector<u8>>", () => {
		// as array of arrays
		expect(meta.set(18, [[1,2],[2,3,4]], 'vector<vector<u8>>'  )).toBeTruthy();
		const getBack = meta.getVecVecU8(18);
		expect(getBack).toEqual([new Uint8Array([1,2]), new Uint8Array([2,3,4])] );
		// as array of Uint8Array, internally storing is the same
		expect(meta.set(18,[new Uint8Array([1,2]), new Uint8Array([2,3,4])],  'vector<vector<u8>>'  )).toBeTruthy();
		const getBack2 = meta.getVecVecU8(18);
		expect(getBack2).toEqual([new Uint8Array([1,2]), new Uint8Array([2,3,4])] );

		expect(meta.hasChunkOfType(18, 'vector<vector<u8>>')).toBeTruthy();
	});


	it("lets set a chunk of vector<bool>", () => {
		expect(meta.set(19, [true, false, true], 'vector<bool>')).toBeTruthy();
		expect(meta.hasChunkOfType(19, 'vector<bool>')).toBeTruthy();
		expect(meta.getVecBool(19)).toEqual([true, false, true]);

		expect(meta.set(19, [0,1,2],  'vector<u8>')).toBeTruthy();
		expect(meta.hasChunkOfType(19, 'vector<bool>')).toBeFalsy(); // not vector<bool> as '2' is not bool
	});


	it("lets set a chunk of address", () => {
		expect(meta.set(20, '0xfa7ac3951fdca92c5200d468d31a365eb03b2be9936fde615e69f0c1274ad3a0',  'address')).toBeTruthy(); // BLUB!
		expect(meta.getAddress(20)).toEqual('0xfa7ac3951fdca92c5200d468d31a365eb03b2be9936fde615e69f0c1274ad3a0');

		expect(meta.set(20, '0x2', 'address')).toBeTruthy(); // shorter
		expect(meta.getAddress(20)).toEqual('0x0000000000000000000000000000000000000000000000000000000000000002');
	});


	it("lets set a chunk of vector<address>", () => {
		expect(meta.set(21, ['0xfa7ac3951fdca92c5200d468d31a365eb03b2be9936fde615e69f0c1274ad3a0', '0x2'],  'vector<address>')).toBeTruthy();
		expect(meta.hasChunkOfType(21, 'vector<address>')).toBeTruthy();
		expect(meta.getVecAddress(21)).toEqual(['0xfa7ac3951fdca92c5200d468d31a365eb03b2be9936fde615e69f0c1274ad3a0', '0x0000000000000000000000000000000000000000000000000000000000000002']);
	});

	it("toBytes() and restore back", ()=>{
		const chunksLength = meta.getChunksIds().length;
		const chunksIds = meta.getChunksIds();
		const asBytes = meta.toBytes();
		const restored = new Metadata(asBytes);

		expect(restored.getChunksIds().length).toEqual(chunksLength);
		expect(restored.getChunksIds()).toEqual(chunksIds);
	});


	it("removing chunks works ok", ()=>{
		const chunksLength = meta.getChunksCount();
		expect(meta.removeChunk(21)).toBeTruthy();
		expect(meta.removeChunk(20)).toBeTruthy();
		expect(meta.removeChunk(19)).toBeTruthy();
		expect(meta.getChunksCount()).toEqual(chunksLength - 3);
	});
});