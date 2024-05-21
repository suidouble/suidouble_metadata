### compressed_on_chain

Sample contract to demonstrate usage of `suidouble_metadata::compress module`.

- creates a simple CompressedStore object, with metadata vector<u8>, which can hold any values,
- and may be compressed with suidouble_metadata::compress module

For simplicity here, we make it to operate with metadata's get_u256 and get_vec_8 function, but feel free to use others 
- works ok and do 2x compression for a test metadata in the unit test of the package

 set items to metadata with:
 - set_metadata_string
 - get_metadata_u256

get metadata items with
 - get_metadata_chunk
 - get_metadata_u256

compress metadata to reduce it's byte length with
 - compress_metadata

take a look at the unit test at [the move file](sources/compressed_on_chain.move)