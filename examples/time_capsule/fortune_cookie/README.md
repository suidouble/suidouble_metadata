### fortune_cookie

Sample contract to demonstrate usage of `suidouble_metadata::time_capsule module`.

    - encrypts a list of prophecies for the future using drand randomness
        - see `get_encrypted_prophecies`, should be generated off-chain for 100% secret
        - merges encrypted messages into single `metadata` vector<u8>
        - there is a test method of `get_pre_encrypted`
    - encrypted prophecies are stored in contract shared store as metadata
        - attached to store with `attach_future_prophecies` method
    - each day, a new prophecy may be minted as NFT by anyone
        - anyone have to execute `mint_fortune_cookie` method with drand signature for the round of `FortuneCookieStore.waiting_for_drand_round`
    - unit tests assumes contract was deployed on May 01 2024, so we already now some "future" drand signatures to use for minting `FortuneCookie`

#### generating encryption

If `get_encrypted_prophecies` unit test goes timeout, increase gas limit for testing:

```bash
sui move test --gas-limit=50000000000
```