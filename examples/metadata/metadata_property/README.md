### metadata_property

Just add a:

```rust
    metadata: vector<u8>
```

property to any Struct you use, and you can use it to store additional properties you may need in your next package versions

### Quick example

Imagine you have a very simple module with a store and purchase method with hard-coded price:

```rust
public struct SomeStore has key {
    id: UID,
    balance: Balance<SUI>,
}
entry fun purchase_from(store: &mut SomeStore, coin: Coin<SUI>): bool {
    coin::put(&mut store.balance, coin); 
    let sui_amount = coin::value(&coin);
    if (sui_amount < 1_000_000_000) {
        return false
    };
    // create some goods and send to tx_sender...
    true
}
```

And once in a while you'd want to do discount for few days, and sell goods for 0.5 SUI. Of course you can just change that `1_000_000_000` to `500_000_000` and deploy new package version. Or add extra object holding the price, like:

```rust
public struct SomeStoreNewProperties has key {
    price: u256
}
entry fun purchase_from(store: &mut SomeStore, coin: Coin<SUI>): bool {
    abort EPleaseSirUseNewFunctionIAmSorrySirThankYouILoveYou
}
entry fun purchase_from_with_properites(store: &mut SomeStore, properties: &SomeStoreNewProperties, coin: Coin<SUI>): bool {
    ...
}
```

But wouldn't it be better if you'd have a place to store some property in Struct just in case?

```rust
public struct SomeStore has key {
    id: UID,
    balance: Balance<SUI>,
    metadata: vector<u8>,   // just add a metadata vector<u8> in case for any possible package upgrade you may need
}
```

And no more pain:

```rust
let price = metadata::get_u64(&store.metadata, metadata::key(&b"price"), 1_000_000_000); // 1_000_000_000 - default
```

```rust
// and new function just updates metadata, no need for new structs
entry fun adjust_price(store: &mut SomeStore, new_price: u64) {
    metadata::set(&mut store.metadata, metadata::key(&b"price"), &new_price);
}
```

suidouble_metadata::metadata lets you store and retrieve anything, from `bool` to `vector<vector<u8>>` into/from single `vector<u8>`. So don't forget to add it to your `Struct`. Thank us later.