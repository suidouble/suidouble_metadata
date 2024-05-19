
module suidouble_metadata::indexed_vector {
/// Vector-like implementation for vector<u256>, optimized for `index_of` and `contains` methods.
///    - faster than native Sui vector for index_of and contains calls
///    - slower than native Sui vector for borrow calls, you can take out vector with .as_vector() for faster borrow
///
///    - on the inner side, it keeps records as sorted vector and have an additional one with indexes to it
    // use std::vector;
    use suidouble_metadata::asu256;

    /// The index into the vector is out of bounds, same const as in vector module
    const EINDEX_OUT_OF_BOUNDS: u64 = 0x20000;

    public struct IndexedVector has drop {
        indexes: vector<u64>,
        records: vector<u256>,
    }

    // returns empty IndexedVector
    public fun empty(): IndexedVector {
        IndexedVector {
            records: vector::empty(),
            indexes: vector::empty()
        }
    }

    // helping method for compressing function. Returns an IndexedVector filled with
    //     asu256 of single bytes in range of [0..255]
    public fun new_with_bytes(): IndexedVector {
        let mut ret = IndexedVector {
            records: vector::empty(),
            indexes: vector::empty()
        };

        let mut i:u16 = 0;
        while (i <= 255) {
            vector::push_back(&mut ret.records, asu256::u8_to_asu256( (i as u8) ));
            vector::push_back(&mut ret.indexes, (i as u64));
            i = i + 1;
        };

        ret
    }

    // get length of it
    public fun length(self: &IndexedVector): u64 {
        vector::length(&self.records)
    }

    /// Return `(true, i)` if `e` is in the IndexedVector at index `i`.
    /// Otherwise, returns `(false, 0)`.
    public fun index_of(self: &IndexedVector, v_ref: &u256): (bool, u64) {
        let (found, in_of) = binary_search_value(&self.records, v_ref);   // found value
        if (!found) {
            return (false, 0)
        };

        let index = *vector::borrow(&self.indexes, in_of);  // take its position from indexes

        (true, index)
    } 

    /// Return true if `e` is in the IndexedVector.
    /// Otherwise, returns false.
    public fun contains(self: &IndexedVector, v_ref: &u256): bool {
        let (found, _) = index_of(self, v_ref);

        found
    }

    // returns inner vector as vector<u256> not caring about elements positions, they are sorted by value
    public fun raw(self: &IndexedVector): vector<u256> {
        self.records
    }

    /// Acquire an immutable reference to the `i`th element of the IndexedVector.
    /// Aborts if `i` is out of bounds.
    public fun borrow(self: &IndexedVector, i: u64): &u256 {
        let (found, found_index) = vector::index_of(&self.indexes, &i);   // found index
        if (found) {
            return vector::borrow(&self.records, found_index)
        };

        abort EINDEX_OUT_OF_BOUNDS
    }

    /// Return a mutable reference to the `i`th element in the IndexedVector.
    /// Aborts if `i` is out of bounds.
    public fun borrow_mut(self: &mut IndexedVector, i: u64): &mut u256 {
        let (found, found_index) = vector::index_of(&self.indexes, &i);   // found index
        if (found) {
            return vector::borrow_mut(&mut self.records, found_index)
        };

        abort EINDEX_OUT_OF_BOUNDS
    }


    // returns inner vector ordered with respect to positions, slow getter
    public fun as_vector(self: &IndexedVector): vector<u256> {
        let mut i = 0;
        let length = self.length();
        let mut ret: vector<u256> = vector::empty();

        while (i < length) {
            i = i + 1;

            let (found, found_index) = vector::index_of(&self.indexes, &i);   // found index
            if (found) {
                let record = *vector::borrow(&self.records, found_index);
                ret.push_back(record);
            }
        };

        ret
    }

    /// Add element to the end of the IndexedVector.
    public fun push_back(self: &mut IndexedVector, v: u256) {
        let cur_length = vector::length(&self.records);

        let place_to_push = binary_search_place_for(&self.records, &v);

        if (place_to_push != cur_length) {
            // need to insert at position
            vector::insert(&mut self.records, v, place_to_push);
            vector::insert(&mut self.indexes, cur_length, place_to_push);
        } else {
            // just push to the end
            vector::push_back(&mut self.records, v);
            vector::push_back(&mut self.indexes, cur_length);
        }
    }

    // Appends sorted vector of u256 to the end of IndexedVector. 
    //   !!!!! It's your responsibility !!! to be sure
    //         values are sorted, as it would brake everything if they are not
    public fun append_sorted(self: &mut IndexedVector, values: vector<u256>) {
        let mut i:u64 = 0; // self.length();
        let till_add = values.length();
        let cur_length = self.length();

        while (i < till_add) {
            vector::push_back(&mut self.records, *values.borrow(i));
            vector::push_back(&mut self.indexes, ((cur_length + i) as u64));
            i = i + 1;
        };
    }

    /// Search for a I to insert element into the sorted vector
    public fun binary_search_place_for(vec_ref: &vector<u256>, v_ref: &u256): u64 {
        let len = vector::length(vec_ref);
        if (len == 0) {
            return 0
        };
        let mut left = 0;
        let mut right = len - 1;

        while (left <= right) {
            let mid = (left + right) / 2;
            let item_at_mid = *vector::borrow(vec_ref, mid);
            if (item_at_mid == *v_ref) {
                return mid
            } else if (item_at_mid < *v_ref) {
                left = mid + 1;
            } else { 
                if (mid == 0) {
                    return 0
                };
                right = mid - 1;
            };
        };

        left
    }

    /// Search for a position of the element in the sorted vector<u256>
    public fun binary_search_value(vec_ref: &vector<u256>, v_ref: &u256): (bool, u64) {
        let mut left = 0;
        let len = vector::length(vec_ref);
        if (len == 0) {
            return (false, 0)
        };
        let mut right = len - 1;

        while (left <= right) {
            let mid = (left + right) / 2;
            let item_at_mid = *vector::borrow(vec_ref, mid);

            if (item_at_mid == *v_ref) {
                return (true, mid)
            } else if (item_at_mid < *v_ref) {
                left = mid + 1;
            } else { 
                if (mid == 0) {
                    return (false, 0)
                };
                right = mid - 1;
            };
        };

        (false, left)
    }


    #[test]
    fun test_new_with_bytes() {
        // helping methods for compressing functions
        let with_bytes = new_with_bytes();
        assert!(with_bytes.length() == 256, 0);
        assert!(*with_bytes.borrow(0) == asu256::u8_to_asu256(0) , 0);
        assert!(*with_bytes.borrow(255) == asu256::u8_to_asu256(255) , 0);

        // all asu256 vectors are singletons
        assert!(asu256::asu256_length(*with_bytes.borrow(0)) == 1, 0);
        assert!(asu256::asu256_length(*with_bytes.borrow(255)) == 1, 0);
    }

    #[test]
    fun test_basic() {
        let mut indexed_vector = empty();
        assert!(indexed_vector.length() == 0, 0);

        indexed_vector.push_back(255);
        indexed_vector.push_back(250);
        indexed_vector.push_back(2);
        indexed_vector.push_back(44444);

        assert!(indexed_vector.length() == 4, 0);

        assert!(indexed_vector.contains(&255) == true, 0);
        assert!(indexed_vector.contains(&250) == true, 0);
        assert!(indexed_vector.contains(&2) == true, 0);
        assert!(indexed_vector.contains(&44444) == true, 0);

        // not found
        assert!(indexed_vector.contains(&55555) == false, 0);

        // positions
        let (found, pos) = indexed_vector.index_of(&255);
        assert!(found == true, 0);  assert!(pos == 0, 0);

        let (found, pos) = indexed_vector.index_of(&250);
        assert!(found == true, 0);  assert!(pos == 1, 0);

        let (found, pos) = indexed_vector.index_of(&2);
        assert!(found == true, 0);  assert!(pos == 2, 0);

        let (found, pos) = indexed_vector.index_of(&44444);
        assert!(found == true, 0);  assert!(pos == 3, 0);

        // not found
        let (found, _pos) = indexed_vector.index_of(&55555);
        assert!(found == false, 0);


        // check that values are sorted inside raw inner vector
        let inner = indexed_vector.raw();
        let (_found, pos) = inner.index_of(&2);
        assert!(pos == 0, 0);
        let (_found, pos) = inner.index_of(&250);
        assert!(pos == 1, 0);
        let (_found, pos) = inner.index_of(&255);
        assert!(pos == 2, 0);
        let (_found, pos) = inner.index_of(&44444);
        assert!(pos == 3, 0);





    }

    #[test]
    fun test_append_sorted() {
        let mut indexed_vector = empty();
        indexed_vector.append_sorted(vector[1,2,2000,3000,4000]);
        assert!(indexed_vector.length() == 5, 0);

        assert!(*indexed_vector.borrow(0) == 1, 0);
        assert!(*indexed_vector.borrow(1) == 2, 0);
        assert!(*indexed_vector.borrow(2) == 2000, 0);
        assert!(*indexed_vector.borrow(3) == 3000, 0);
        assert!(*indexed_vector.borrow(4) == 4000, 0);
    }





}