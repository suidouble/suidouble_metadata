import { bcs, BcsType } from '@mysten/bcs';

export type MetadataType = 
    'u8' | 'u16' | 'u32' | 'u64' | 'u128' | 'u256' | 
    'bool' | 'address' | 
    'vector<u8>' | 'vector<u16>' |  'vector<u32>' |  'vector<u64>' |  'vector<u128>' |  'vector<u256>' | 
    'vector<bool>' | 'vector<address>' | 
    'string' | // string is an alias for vector<u8>, adjusting input/output on the fly from/into js strings
    'vector<vector<u8>>';

export const typeBinaryLength = (typeName: MetadataType): number | null => {
    if (typeName == 'bool' || typeName == 'u8') {
        return 1;
    } else if (typeName == 'address') {
        return 32;
    } else if (typeName.indexOf('u') === 0) { // u8...u256
        return (Number(typeName.split('u')[1]) / 8);
    } else { // probably a vector?
        return null;
    }
};

export const guessTypeByValue = (v: any): MetadataType => {
    if (typeof(v) === 'string') {
        if (v.indexOf('0x') === 0 && v.length > 2 && v.length <= 66 && /^[0-9a-fA-Fx]+$/.test(v)) {
            return 'address';
        }
        return 'string';
    } else if (v.constructor && v.constructor === Uint8Array) {
        return 'vector<u8>';
    } else if (v.constructor && v.constructor === Uint16Array) {
        return 'vector<u16>';
    } else if (v.constructor && v.constructor === Uint32Array) {
        return 'vector<u32>';
    } else if (typeof(v) === 'boolean') {
        return 'bool';
    } else if (typeof v === 'number' && !isNaN(v) && v >= 0) {
        return 'u32';
    } else if (Array.isArray(v)) {
        if (v[0]) {
            return ('vector<'+guessTypeByValue(v[0])+'>') as MetadataType;
        }
    } else if (typeof(v) === 'bigint') {
        return 'u256';
    }

    return 'vector<u8>';
};

export const bcsOfType = (typeName: MetadataType): BcsType<any> => {
    let serializer = null;
    switch (typeName) {
        case 'u8':
            serializer = bcs.u8(); break;
        case 'u16':
            serializer = bcs.u16(); break;
        case 'u32':
            serializer = bcs.u32(); break;
        case 'u64':
            serializer = bcs.u64(); break;
        case 'u128':
            serializer = bcs.u128(); break;
        case 'u256':
            serializer = bcs.u256(); break;
        case 'bool':
            serializer = bcs.bool(); break;
        case 'address': // address is same as u256
            serializer = bcs.u256(); break;
        case 'vector<u8>':
            serializer = bcs.vector(bcs.u8()); break;
        case 'string':
            serializer = bcs.vector(bcs.u8()); break;
        case 'vector<bool>':
            serializer = bcs.vector(bcs.bool()); break;
        case 'vector<address>':
            serializer = bcs.vector(bcs.u256()); break;
        case 'vector<u16>':
            serializer = bcs.vector(bcs.u16()); break;
        case 'vector<u32>':
            serializer = bcs.vector(bcs.u32()); break;
        case 'vector<u64>':
            serializer = bcs.vector(bcs.u64()); break;
        case 'vector<u128>':
            serializer = bcs.vector(bcs.u128()); break;
        case 'vector<u256>':
            serializer = bcs.vector(bcs.u256()); break;
        case 'vector<vector<u8>>':
            serializer = bcs.vector(bcs.vector(bcs.u8())); break;
        default:
            serializer = bcs.vector(bcs.u8());
    };

    return serializer;
};

/**
 * Helper utility: decode ULEB as an array of numbers.
 * Taken from sui/bcs library
 * Original code is taken from: https://www.npmjs.com/package/uleb128 (no longer exists)
 * @param data 
 * @returns 
 */
export const ulebDecode = (data: Uint8Array): {
	value: number;
	length: number;
} => {
	let total = 0;
	let shift = 0;
	let len = 0;

	// eslint-disable-next-line no-constant-condition
	while (true) {
		let byte = data[len];
		len += 1;
		total |= (byte & 0x7f) << shift;
		if ((byte & 0x80) === 0) {
			break;
		}
		shift += 7;
	}

	return {
		value: total,
		length: len,
	};
};
