import { key, hexStringToUint8Array, stringToUint8Array, uint8ArrayToString, } from "./metadataUtils";
import { MetadataType, typeBinaryLength, bcsOfType, ulebDecode, guessTypeByValue } from "../src/metadataTypes";

export type ChunkId = bigint | number | string;

export class Metadata {
    public serialized: Uint8Array
    constructor(data: Uint8Array | string | undefined) {
        if (data) {
            if (typeof data == 'string') {
                this.serialized = hexStringToUint8Array(data);
            } else {
                this.serialized = new Uint8Array(data);
            }
        } else {
            this.serialized = new Uint8Array();
        }
    }

    get byteLength(): bigint {
        return BigInt(this.serialized.length);
    }

    public getChunksCount(): number {
        return (this.getChunksIds().length);
    }

    /**
     * Get binary Uint8Array of metadata
     */
    public toBytes(): Uint8Array {
        return this.serialized;
    }

    /**
     * Normalize chunkId so for any supported type, it returns bigint with max of 4 significant bytes
     * @param chunkId number, bigint or string to be hashed as key
     * @returns bigint
     */
    public normalizeChunkId(chunkId: ChunkId): bigint {
        if (typeof chunkId === 'string') {
            return key(chunkId);
        }
        return BigInt(chunkId);
    }

    /**
    *  Set metadata chunk of ChunkId to value
    */
    public set(chunkId: ChunkId, value: any, typeName: MetadataType | undefined): boolean {
        const normalizedChunkId = this.normalizeChunkId(chunkId);
        const normalizedTypeName = typeName || guessTypeByValue(value);
        const dataOffset = this.getChunkOffset(normalizedChunkId);
        const dataLength = this.getChunkLengthAtOffset(dataOffset);

        if (normalizedTypeName == 'string' && typeof(value) === 'string') {
            // for typeName == 'string' we accept string value, convert it into Uint8Array and use vector<u8> serializer
            value = stringToUint8Array(value);
        }

        const asBytes = bcsOfType(normalizedTypeName).serialize(value).toBytes();
        const asBytesLength = BigInt(asBytes.length);
        const chunkHeaderLength = 8n;
        
        if (dataLength != 0n) {
            // we already have metadata chunk with id of chunk_id
            if (asBytesLength == dataLength - chunkHeaderLength) {
                // and its data length is same we are going to set it to
                this.serialized.set(asBytes, Number(dataOffset + chunkHeaderLength));
                return true;
            } else {
                // length of current metadata chunk is different, we can not use it anymore, so lets remove old chunk
                this.clamp(dataOffset, dataLength);
            }
        }

        if (this.byteLength === 0n) {
            // if metadata is fresh and empty - add a version byte to it.
            this.addBytes((new Uint8Array([0])));
        }

        // 4 bytes  = chunk_id as u32
        const chunkIdAsBytes = bcsOfType('u32').serialize(Number(normalizedChunkId)).toBytes();
        this.addBytes(chunkIdAsBytes);

        // 4 bytes = chunk length as u32
        const chunkLength = asBytesLength + chunkHeaderLength;
        const chunkLengthAsBytes = bcsOfType('u32').serialize(Number(chunkLength)).toBytes();
        this.addBytes(chunkLengthAsBytes);

        // data itself
        this.addBytes(asBytes);

        return true;
    }

    /**
     * Remove a chunk from metadata
     */
    public removeChunk(chunkId: ChunkId): boolean {
        const normalizedChunkId = this.normalizeChunkId(chunkId);
        const dataOffset = this.getChunkOffset(normalizedChunkId);
        const dataLength = this.getChunkLengthAtOffset(dataOffset);

        if (dataLength == 0n) {
            return false; // no such chunk
        }

        this.clamp(dataOffset, dataLength);
        return true;
    }

    /**
     * Get a string from vector<u8> chunk, set as set(chunkId, 'string', 'value');
     */
    public getString(chunkId: ChunkId): string {
        return uint8ArrayToString(this.getVecU8(chunkId));
    }

    /**
     * Get a address string from chunk, set as set(chunkId, 'address', '0x25345345...');
     */
    public getAddress(chunkId: ChunkId): string | null {
        const u256 = this.getU256(chunkId, 0n);
        if (u256 == 0n) {
            return null;
        }
        return '0x'+u256.toString(16).padStart(64, '0');
    }
    /**
     * Get a vector of `address` from the chunk of metadata vector, returns empty array if there's no chunk
     */
    public getVecAddress(chunkId: ChunkId): Array<string> {
        const ret: Array<string> = [];
        this.getVecU256(chunkId).forEach((v: bigint)=>{
            ret.push( '0x'+v.toString(16).padStart(64, '0') );
        });
        return ret;
    }

    /**
     * Get a vector of `u8` (eg string) from the chunk of metadata vector, returns empty Uint8Array if there's no chunk
     */
    public getVecU8(chunkId: ChunkId): Uint8Array {
        const data = this.get(chunkId);
        if (data === null) {
            return new Uint8Array();
        }

        return new Uint8Array(bcsOfType('vector<u8>').parse(new Uint8Array(data)));
    }
    /**
     * Get a vector of `bool` from the chunk of metadata vector, returns empty array if there's no chunk
     */
    public getVecBool(chunkId: ChunkId): Array<boolean> {
        const ret: Array<boolean> = [];
        this.getVecU8(chunkId).forEach((v: number)=>{
            ret.push(!!v);
        });
        return ret;
    }

    /**
     * Get a vector of `u16`  from the chunk of metadata vector, returns empty Uint16Array if there's no chunk
     */
    public getVecU16(chunkId: ChunkId): Uint16Array {
        const data = this.get(chunkId);
        if (data === null) {
            return new Uint16Array();
        }
        return new Uint16Array(bcsOfType('vector<u16>').parse(new Uint8Array(data)));
    }
    /**
     * Get a vector of `u32`  from the chunk of metadata vector, returns empty Uint32Array if there's no chunk
     */
    public getVecU32(chunkId: ChunkId): Uint32Array {
        const data = this.get(chunkId);
        if (data === null) {
            return new Uint32Array();
        }
        return new Uint32Array(bcsOfType('vector<u32>').parse(new Uint8Array(data)));
    }
    /**
     * Get a vector of `u64` from the chunk of metadata vector, returns empty Array if there's no chunk. Array elemets are bigint
     */
    public getVecU64(chunkId: ChunkId): Array<bigint> {
        const data = this.get(chunkId);
        if (data === null) {
            return [];
        }
        return (bcsOfType('vector<u64>').parse(new Uint8Array(data))).map((i:any)=>BigInt(i)); // parse returns strings, so we map them to bigint
    }
    /**
     * Get a vector of `u128` from the chunk of metadata vector, returns empty Array if there's no chunk. Array elemets are bigint
     */
    public getVecU128(chunkId: ChunkId): Array<bigint> {
        const data = this.get(chunkId);
        if (data === null) {
            return [];
        }
        return (bcsOfType('vector<u128>').parse(new Uint8Array(data))).map((i:any)=>BigInt(i)); // parse returns strings, so we map them to bigint
    }
    /**
     * Get a vector of `u256` from the chunk of metadata vector, returns empty Array if there's no chunk. Array elemets are bigint
     */
    public getVecU256(chunkId: ChunkId): Array<bigint> {
        const data = this.get(chunkId);
        if (data === null) {
            return [];
        }
        return (bcsOfType('vector<u256>').parse(new Uint8Array(data))).map((i:any)=>BigInt(i)); // parse returns strings, so we map them to bigint
    }

    /**
     * Get any vec, vec<u8>, vec<u16>, vec<u32>, vec<u64>, vec<u128>, vec<u256>, vec<bool>, vec<address> as vec<u256>
     */
    public getAnyVecU256(chunkId: ChunkId): Array<bigint> {
        const data = this.get(chunkId);
        if (data === null) {
            return [];
        }
        const vecLength = Number(this.getVecLength(chunkId));

        if (vecLength) {
            const uleb = ulebDecode(data);
            const startPosition = uleb.length;
            const bytesLength = data.length - startPosition;

            // we expect remaining bytes length to be evenly dividable by vec_length
            if (bytesLength % vecLength != 0) {
                return [];
            }
            const itemByteLength = bytesLength / vecLength;
            const ret = [];
            let i = startPosition;

            while (i < data.length) {
                let j = 0;
                let value = 0n;
                while (j < itemByteLength) {
                    value = value | ( (BigInt(data[i+j])) << BigInt(8*j) );
                    j++;
                };
                ret.push(value);
                i+=itemByteLength;
            };
            return ret;
        } else {
            return []; // vecLength == null
        }
    }

    /**
     * Get a vector of binary Uint8Array from the chunk of metadata vector, returns empty Array if there's no chunk
     */
    getVecVecU8(chunkId: ChunkId): Array<Uint8Array> {
        const data = this.get(chunkId);
        if (data === null) {
            return [];
        }
        return (bcsOfType('vector<vector<u8>>').parse(new Uint8Array(data))).map((i:any)=>(new Uint8Array(i))); // parse returns arrays, so we map them to Uint8Array
    }

    /**
     * Get any u, u8, u16, u32, u64, u128, u256   as a single u256 from the chunk of metadata, 
     *  with default parameter in case there's no such chunk
     * @param chunkId 
     * @param defaultValue 
     * @returns 
     */
    public getAnyU256(chunkId: ChunkId, defaultValue: bigint): bigint {
        const data = this.get(chunkId);
        if (data === null) {
            return defaultValue;
        } else {
            let numberAsBytesLength = data.length;
            const dataCopy = new Uint8Array(data); // so we don't modify underlying Uint8Array
            let i = 0;
            let value = BigInt(0);
            dataCopy.reverse();
            while (i < numberAsBytesLength) {
                value = (value << 8n) | BigInt(dataCopy[i]);
                i++;
            };
            return value;
        }
    }

    /**
     * Get a number from the chunk of type = typeName, returns defaultValue if there's no chunk
     */
    private getNumberFromChunkWithDefault(chunkId: ChunkId, typeName: MetadataType, defaultValue: number): number {
        const data = this.get(chunkId);
        if (data === null) {
            return defaultValue;
        }
        return Number(bcsOfType(typeName).parse(new Uint8Array(data)));
    };
    /**
     * Get a bigint from the chunk of type = typeName, returns defaultValue if there's no chunk
     */
    private getBigIntFromChunkWithDefault(chunkId: ChunkId, typeName: MetadataType, defaultValue: bigint): bigint {
        const data = this.get(chunkId);
        if (data === null) {
            return defaultValue;
        }
        return BigInt(bcsOfType(typeName).parse(new Uint8Array(data)));
    };

    /**
     * Get a `u8` from the chunk of metadata vector, returns defaultValue if there's no chunk
     */
    public getU8(chunkId: ChunkId, defaultValue: number): number {
        return this.getNumberFromChunkWithDefault(chunkId, 'u8', defaultValue);
    }
    /**
     * Get a `bool` from the chunk of metadata vector, returns defaultValue if there's no chunk
     */
    public getBool(chunkId: ChunkId): boolean {
        return !!this.getNumberFromChunkWithDefault(chunkId, 'u8', 0);
    }
    /**
     * Get a `u16` from the chunk of metadata vector, returns defaultValue if there's no chunk
     */
    public getU16(chunkId: ChunkId, defaultValue: number): number {
        return this.getNumberFromChunkWithDefault(chunkId, 'u16', defaultValue);
    }
    /**
     * Get a `u32` from the chunk of metadata vector, returns defaultValue if there's no chunk
     */
    public getU32(chunkId: ChunkId, defaultValue: number): number {
        return this.getNumberFromChunkWithDefault(chunkId, 'u32', defaultValue);
    }


    /**
     * Get a `u64` bigint from the chunk of metadata vector, returns defaultValue if there's no chunk
     */
    public getU64(chunkId: ChunkId, defaultValue: bigint): bigint {
        return this.getBigIntFromChunkWithDefault(chunkId, 'u64', defaultValue);
    }
    /**
     * Get a `u128` bigint from the chunk of metadata vector, returns defaultValue if there's no chunk
     */
    public getU128(chunkId: ChunkId, defaultValue: bigint): bigint {
        return this.getBigIntFromChunkWithDefault(chunkId, 'u128', defaultValue);
    }
    /**
     * Get a `u256` bigint from the chunk of metadata vector, returns defaultValue if there's no chunk
     */
    public getU256(chunkId: ChunkId, defaultValue: bigint): bigint {
        return this.getBigIntFromChunkWithDefault(chunkId, 'u256', defaultValue);
    }


    /**
    *   Get Uint8Array for a chunkId from metadata, returns null if there's no data for this chunkId
    */
    public get(chunkId: ChunkId): Uint8Array | null {
        const normalizedChunkId = this.normalizeChunkId(chunkId);
        const dataOffset = this.getChunkOffset(normalizedChunkId);
        const dataLength = this.getChunkLengthAtOffset(dataOffset);
        const currentMetadataLength = this.byteLength;

        if (dataLength == 0n || currentMetadataLength < dataOffset + dataLength) {
            return null;
        }

        let from = dataOffset + 8n; // skip chunk_header
        let till = dataOffset + dataLength;
        
        return this.serialized.subarray(Number(from), Number(till));
    }



    /**
    *  Get length of metadata chunk located at metadata_offset in metadata 
    */
    public getChunkLengthAtOffset(metadataOffset: bigint): bigint {
        const metadataLength = this.byteLength;
        if (metadataOffset == metadataLength) {
            return 0n;
        }

        return this.u32FromLEBytesAtOffset(metadataOffset + 4n);
    }

    /**
    *  Returns true, if there's metadata chunk with id of chunk_id and it has type of typeName
    */
    public hasChunkOfType(chunkId: ChunkId, typeName: MetadataType): boolean {
        if (typeName == 'string') {
            // 'string' is a special type we convert into vector<u8> on the fly
            return this.hasChunkOfType(chunkId, 'vector<u8>');
        }

        const normalizedChunkId = this.normalizeChunkId(chunkId);
        if (!this.hasChunk(normalizedChunkId)) {
            return false;
        }
        const dataOffset = this.getChunkOffset(normalizedChunkId);
        const dataLength = this.getChunkLengthAtOffset(dataOffset);
        if (dataLength < 8n) { // < CHUNK_HEADER
            return false;
        };

        // const currentMetadataLength = this.byteLength;
        let chunkDataLength = dataLength - 8n; // -CHUNK_HEADER_LENGTH

        if (typeName.indexOf('vector') === 0) {
            // vector type
            const vecLength = this.getVecLength(normalizedChunkId);
            const internalType = typeName.split('vector<').slice(1).join('vector<').slice(0,-1) as MetadataType;
            if (internalType.indexOf('vector') === 0) {
                // it's vector<vector<u8>>
                // check internaly
                try {
                    const parsed = this.getVecVecU8(chunkId);

                    if (parsed && parsed.length == Number(vecLength)) {
                        return true;
                    }
                    return false;
                } catch (e) {
                    return false;
                }
            } else {
                const internalTypeBinaryLength = typeBinaryLength(internalType);
                if (vecLength) {
                    if (vecLength > 0n) {
                        if (internalTypeBinaryLength && (BigInt(internalTypeBinaryLength) * vecLength < chunkDataLength)) {
                            if (internalType == 'bool') {
                                // check if bytes are ok
                                const vec = this.getVecU8(chunkId);
                                let hasNotValidBytes = false;
                                for (const byte of vec) {
                                    if (byte !== 0 && byte !== 1) {
                                        hasNotValidBytes = true;
                                    }
                                }
                                if (hasNotValidBytes) {
                                    return false;
                                }
                            }

                            return true;
                        } else {
                            return false;
                        }
                    }

                    return true;
                }
            }
            return false;
        } else {
            if (typeBinaryLength(typeName) == Number(chunkDataLength)) {
                // @todo: check for bool if it's valid
                return true;
            } else {
                return false;
            }
        }
    }

    /**
    *  Returns true, if there's metadata chunk with id of chunkId
    */
    public hasChunk(chunkId: ChunkId): boolean {
        const normalizedChunkId = this.normalizeChunkId(chunkId);
        const dataOffset = this.getChunkOffset(normalizedChunkId);
        const dataLength = this.getChunkLengthAtOffset(dataOffset);
        const currentMetadataLength = this.byteLength;

        // // data_offset_next == 0 - we don't have ranges for this chunk_id
        // // current_metadata_length < data_offset_next - metadata is not set
        if (dataLength == 0n || currentMetadataLength < dataOffset + dataLength) {
            return false;
        }

        return true;
    }

    /**
     * Get length of vector inside chunk_id
     * @param chunkId 
     */
    public getVecLength(chunkId: ChunkId): bigint | null {
        const data = this.get(chunkId);
        if (data === null) {
            return null;
        }
        const uleb = ulebDecode(data);
        return BigInt(uleb.value);
    }

    /**
    *  Find offset at which chunk_id metadata chunk is located inside metadata
    */
    public getChunkOffset(chunkId: bigint): bigint {
        const metadataLength = this.byteLength;
        if (metadataLength <= 1n) { // should have byte #0 - version
            return 0n;
        }

        let pos = 1n;  // skip byte #0 as it's metadata version
        while (pos < metadataLength) {
            let offsetChunkId = this.u32FromLEBytesAtOffset(pos);
            if (offsetChunkId == chunkId) {
                // we found it
                return pos;
            } else {
                let offsetChunkLength = this.u32FromLEBytesAtOffset(pos + 4n); 
                pos = pos + offsetChunkLength;
            };
        };

        return BigInt(metadataLength);
    }

    /**
    *  Call callback for each chunk in metadata. Works little faster then itterating with getChunksIds() -> get..()
    * 
    *  callback - callback(chunkId, chunkUint8Array)
    */
    public forEach(callback: Function) {
        let pos = 1n; // skip byte #0 as it's metadata version
        const metadataLength = this.byteLength;

        while (pos < metadataLength) {
            let offsetChunkId = this.u32FromLEBytesAtOffset(pos);
            let offsetChunkLength = this.u32FromLEBytesAtOffset(pos + 4n); 

            let from = pos + 8n; // skip chunk_header
            let till = pos + offsetChunkLength;

            callback(Number(offsetChunkId), this.serialized.subarray(Number(from), Number(till)));

            pos = pos + offsetChunkLength;
        }
    }

    /**
    *  Get chunks ids in metadata vector<u8>
    */
    public getChunksIds(): Array<bigint> {
        const ret = [];
        const metadataLength = this.byteLength;
        let pos = 1n; // skip byte #0 as it's metadata version

        while (pos < metadataLength) {
            let offsetChunkId = this.u32FromLEBytesAtOffset(pos);
            let offsetChunkLength = this.u32FromLEBytesAtOffset(pos + 4n); 
            ret.push(offsetChunkId);
            pos = pos + offsetChunkLength;
        }

        return ret;
    }

    /**
    *   Read u32 (LE 4 bytes) from specified position in vector<u8>
    */
    public u32FromLEBytesAtOffset(offset: bigint): bigint {
        const offsetNumber = Number(offset);

        return BigInt(
            (BigInt(this.serialized[offsetNumber]) << 0n) +
            (BigInt(this.serialized[offsetNumber + 1]) << 8n) +
            (BigInt(this.serialized[offsetNumber + 2]) << 16n) +
            (BigInt(this.serialized[offsetNumber + 3]) << 24n)
        );
    }

    /**
     * Add Uint8Array to the end of serialized Uint8Array
     * @param bytes
     * @returns success flag
     */
    private addBytes(bytes: Uint8Array): boolean {
        const merged = new Uint8Array(bytes.length + Number(this.byteLength));
        merged.set(this.serialized);
        merged.set(bytes, this.serialized.length);
        this.serialized = merged;

        return true;
    }

    /**
    *  Remove a portion of metadata in offset of specific length, just following Move module logic
    */
    private clamp(offset: number | bigint, length: number | bigint) {
        const starting = Math.max(Number(offset), 0);
        const deleteCount = Math.max(Number(length), 0);

        const newSize = Number(this.byteLength) - deleteCount;
        const spliced = new Uint8Array(newSize);

        spliced.set(this.serialized.subarray(0, starting));
        spliced.set(this.serialized.subarray(starting + deleteCount), starting);

        this.serialized = spliced;
    }
}