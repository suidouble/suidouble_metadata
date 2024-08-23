

/**
 * Convert a string into Uint8Array representation
 */
export const stringToUint8Array = (str: string): Uint8Array => {
    return new TextEncoder().encode(str);
}

export const uint8ArrayToString = (arr: Uint8Array): string => {
    return new TextDecoder().decode(arr);
}

export const keyLooksPacked = (key: bigint | number): boolean => {
    const unpacked = unpackKey(key);
    // check if unpackedKey looks printable
    //  1st char is alfa
    //  2nd char is alfanumeric
    if (unpacked.length < 2) {
        return false;
    }
    const charCodeAt0 = unpacked.charCodeAt(0);
    const charCodeAt1 = unpacked.charCodeAt(1);
    if (charCodeAt0 >= 65 && charCodeAt0 <= 90) {
        if ((charCodeAt1 >= 65 && charCodeAt1 <= 90) || (charCodeAt1 >= 48 && charCodeAt1 <= 57)) {
            return true;
        }
    }

    return false;
}

/**
* Unpack key back to the string vector of it, 
*     first 4 chars kept (though uppercased)
*         unpack_key(key("TEST")) == "TEST"
*         unpack_key(key("test")) == "TEST"
*     may have an extra hash at the end in case long string (>4 chars) was hashed:
*         unpack_key(key("TEST_long_string")) == "TEST*005"
*         unpack_key(key("TEST_other_string")) == "TEST*119"
*/
export const unpackKey = (key: bigint | number): string => {
    let significant_i = 4;
    let buffer = BigInt(key);
    let ret = '';

    // first - unpack 6bits chars to chars, assuming we have 4 chars in 3 bytes
    while (significant_i > 0) {
        let byte = Number(buffer & 63n); // Extract 6 bits, 63 == 0x3F == 0b00111111
        if (byte > 0) { // ignore empty
            ret = String.fromCharCode(byte + 31) + ret; // Convert back to ASCII by adding 32   
            // NOTE order is different compared to Move, so we don't need array.reverse later
        };
        buffer = buffer >> BigInt(6);
        significant_i = significant_i - 1;
    };

    // if there's something left in buffer - 
    //    key hash was generated using the string longer than 4 chars
    //    lets add extra hash as the number after * to the ret string
    if (buffer > 0n) {
        // the key was longer than 4 chars,
        // append asterisk and a last hash byte as string chars

        ret = ret + '*';                                // *
        ret = ret + String.fromCharCode( Number( (buffer % 256n) / 100n) + 48 );      // '2' in 234
        ret = ret + String.fromCharCode( Number( (buffer % 256n) / 10n ) % 10 + 48 ); // '3' in 234
        ret = ret + String.fromCharCode( Number( (buffer % 256n) ) % 10 + 48 );      // '4' in 234
    };

    return ret;
};


/**
*  Pack a string into the number holding a maximum of 4 bytes of data 
*     produce different values for different strings, all unique for up to 5 chars strings:
*       key("test")  != key("abba")
*       key("test2") != key("test3")
*       key("1")     != key("2")
*
*     constant
*       key("test2") == key("test2")
*
*     different, but may be repeated values for long strings
*       key("long_string_test_1") != key("long_string_test_2")
*       key("long_string_test_01") == key("long_string_test_10")
*
*     returned number may be unpacked back to string using unpackKey  function     
*/
export const key = (str: string): bigint => {
    let i = str.length;
    let significant_i = i;
    if (significant_i > 4) {
        significant_i = 4;
    }

    let buffer = BigInt(0);
    let shift = BigInt(0);

    // first - pack first 4 chars of the string as 6-bites chars, packing them into 3 bytes
    while (significant_i > 0) {
        significant_i = significant_i - 1;
        let char =  BigInt(str.charCodeAt(significant_i) & 0xff);
        if (char >= 97n) {
            // lowercase to uppercase
            char = char - 32n;
        };
        if (char >= 32n) {
            // lower range of non-printable character
            char = char - 31n;
        };
        buffer = buffer | ( char << shift );
        shift = shift + 6n;
    };

    // we have 1 byte left in u32 to pack everything what is left as a very simple hash, just sum up all left bytes and mod it by 256
    if (i > 4) {

        i = i - 1;
        let sum = BigInt(0);
        while (i >= 4) {
            let char = BigInt(str.charCodeAt(i) & 0xff);
            if (char >= 97n) {
                // lowercase to uppercase
                char = char - 32n;
            };
            sum = sum + char;
            sum = sum % 256n;
            i = i - 1;
        };

        if (sum == 0n) {
            sum = 1n;  // let's have 1 as minimum there, so we know the key was longer > 4 chars in any case
        };

        buffer = buffer | ( sum << 24n ); // add extra hash as the 4th byte to the u32
    };

    return buffer;
};

/**
 * Convert hex string into Uint8Array, useful to quickly add Move debug::print(&var) into js 
 * @param hexString 
 * @returns Uint8Array
 */
export const hexStringToUint8Array = (hexString: string): Uint8Array => {
    if (hexString.indexOf('0x') !== -1) {
        // remove 0x from the start if it's there
        hexString = hexString.split('0x').join('');
    }

    if (hexString.length % 2 !== 0) {
        throw new Error('Hex string must have an even number of characters');
    }
    
    let array = new Uint8Array(hexString.length / 2);
    for (let i = 0; i < hexString.length; i += 2) {
        array[i / 2] = parseInt(hexString.substr(i, 2), 16);
    }
    return array;
}