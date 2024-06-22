# @zoralabs/zora-1155-contracts

## 2.10.1

### Patch Changes

- 368940ba: Change removePermission behavior to allow a user to remove their own permission

## 2.10.0

### Minor Changes

- 43a394ab: `ERC20PremintConfig` replaced by a more general purpose `PremintConfigV3`, which instead of having erc20 premint specific properties, as an abi encoded `premintSalesConfig`, that is passed to the function `setPremintSale` on the corresponding minter contract.

  The new `TokenCreationConfigV3` looks like:

  ```solidity
  struct TokenCreationConfigV3 {
    // Metadata URI for the created token
    string tokenURI;
    // Max supply of the created token
    uint256 maxSupply;
    // RoyaltyBPS for created tokens. The royalty amount in basis points for secondary sales.
    uint32 royaltyBPS;
    // The address that the will receive rewards/funds/royalties.
    address payoutRecipient;
    // The address that referred the creation of the token.
    address createReferral;
    // The start time of the mint, 0 for immediate.
    uint64 mintStart;
    // The address of the minter module.
    address minter;
    // The abi encoded data to be passed to the minter to setup the sales config for the premint.
    bytes premintSalesConfig;
  }
  ```

  where the `premintSalesConfig` is an abi encoded struct that is passed to the minter's function `setPremintSale`:

  ```solidity
  ERC20Minter.PremintSalesConfig memory premintSalesConfig = ERC20Minter.PremintSalesConfig({
              currency: address(mockErc20),
              pricePerToken: 1e18,
              maxTokensPerAddress: 5000,
              duration: 1000,
              payoutRecipient: collector
          });


  // this would be set as the property `premintSalesConfig` in the `TokenCreationConfigV3`
  bytes memory encodedPremintSalesConfig = abi.encode(premintSalesConfig);
  ```

  Correspondingly, new minters must implement the new interface `ISetPremintSale` to be compatible with the new `TokenCreationConfigV3`:

  ```solidity
  interface ISetPremintSale {
    function setPremintSale(uint256 tokenId, bytes calldata salesConfig) external;
  }

  // example implementation:
  contract ERC20Minter is ISetPremintSale {
    struct PremintSalesConfig {
      address currency;
      uint256 pricePerToken;
      uint64 maxTokensPerAddress;
      uint64 duration;
      address payoutRecipient;
    }

    function buildSalesConfigForPremint(
      PremintSalesConfig memory config
    ) public view returns (ERC20Minter.SalesConfig memory) {
      uint64 saleStart = uint64(block.timestamp);
      uint64 saleEnd = config.duration == 0
        ? type(uint64).max
        : saleStart + config.duration;

      return
        IERC20Minter.SalesConfig({
          saleStart: saleStart,
          saleEnd: saleEnd,
          maxTokensPerAddress: config.maxTokensPerAddress,
          pricePerToken: config.pricePerToken,
          fundsRecipient: config.payoutRecipient,
          currency: config.currency
        });
    }

    function toSaleConfig(
      bytes calldata encodedPremintSalesConfig
    ) private returns (IERC20Minter.SalesConfig memory) {
      PremintSalesConfig memory premintSalesConfig = abi.decode(
        encodedPremintSalesConfig,
        (PremintSalesConfig)
      );

      return buildSalesConfigForPremint(premintSalesConfig);
    }

    mapping(address => mapping(uint256 => IERC20Minter.SalesConfig)) public sale;

    function setPremintSale(
      uint256 tokenId,
      bytes calldata premintSalesConfig
    ) external override {
      IERC20Minter.SalesConfig memory salesConfig = toSaleConfig(
        premintSalesConfig
      );

      sale[msg.sender][tokenId] = salesConfig;
    }
  }
  ```

- 2475a4c9: Updates to Premint that enables preminting against contracts that were not created via premint, as well as adding collaborators to premint contracts by being able specify an array of additionalAdmins in a premint's contract creation config.

  #### No breaking changes

  These updates are fully backwards compatible; the old functions on the contracts are still intact and will work. Additionally, these updates dont require a new premint config version to be signed; the only thing that could be affected is the deterministic address to be signed against, in the case there are additional contract admins.

  #### Ability to add contract-wide additional admins with premint

  There is a new struct called `ContractWithAdditionalAdminsCreationConfig` that replaces `ContractCreationConfig`. This contains, in addition to the existing fields, a new array `address[] additionalAdmins` - these addresses are added as additional admins when a contract is created by converting each address into a setup action that adds the contract-wide role `PERMISSION_BIT_ADMIN` to that account.

  ```solidity
  // new struct:
  struct ContractWithAdditionalAdminsCreationConfig {
    // Creator/admin of the created contract.  Must match the account that signed the message
    address contractAdmin;
    // Metadata URI for the created contract
    string contractURI;
    // Name of the created contract
    string contractName;
    // additional accounts that will be added as admins
    // to the contract
    address[] additionalAdmins;
  }

  // existing struct that is replaced:
  struct ContractCreationConfig {
    address contractAdmin;
    string contractURI;
    string contractName;
  }
  ```

  Having a list of `additionalAdmins` results in the 1155 contract having a different deterministic address, based on a `salt` made from a hash of the array of `setupActions` that are generated to add those additional accounts as admins. As a result, the creator and additional admins would be signing a message against an address expected to be deterministic with consideration for those additional admins.

  To get the address in consideration of the new admins, there is a new function on the preminter contract:

  ```solidity
  // new function that takes into consideration the additional admins:
  function getContractWithAdditionalAdminsAddress(
    ContractWithAdditionalAdminsCreationConfig calldata contractConfig
  ) public view override returns (address);

  // existing function can be called if there are no additional admins:
  function getContractAddress(
    ContractCreationConfig calldata contractConfig
  ) public view override returns (address);
  ```

  This should be called to get the expected contract address when there are additional admins.

  To determine if an address is authorized to create a premint when there are additional admins, there is a new function:

  ```solidity
  // new function that takes into consideration the additional admins:
  function isAuthorizedToCreatePremintWithAdditionalAdmins(
    address signer,
    address premintContractConfigContractAdmin,
    address contractAddress,
    address[] calldata additionalAdmins
  ) public view returns (bool isAuthorized);

  // existing function can be called if there are no additional admins:
  function isAuthorizedToCreatePremint(
    address signer,
    address premintContractConfigContractAdmin,
    address contractAddress
  ) public view returns (bool isAuthorized);
  ```

  If any account in those `additionalAdmins`, it is considered authorized and can also sign a premint against the contract address of the original premint, before the contract is created. The collaborator's premint can be brought onchain first, and the original admin will be set as the admin along with all the `additionalAdmins`.

  #### New ability to do premints against existing contracts

  Executing premint against contracts not created via premint can be done with by passing a `premintCollection` argument to the new `premint` function:

  ```solidity
  function premint(
    ContractWithAdditionalAdminsCreationConfig memory contractConfig,
    address premintCollection,
    PremintConfigEncoded calldata encodedPremintConfig,
    bytes calldata signature,
    uint256 quantityToMint,
    MintArguments calldata mintArguments,
    address firstMinter,
    address signerContract
  ) external payable returns (uint256 tokenId);
  ```

  This premint collection's address must be a zora creator 1155 contract that already supports premint, which is version 2.0.0 and up.

  #### New single shared function for executing a premint, which works with all versions of premint configs

  In order to avoid having to create one function each for premint v1, v2, and future versions of premint, the new function `premint` takes a struct `PremintConfigEncoded` that contains common properties for premint: `uid`, `version`, and `deleted`, an abi encoded `tokenConfig` and a `premintConfigVersion`; the abi encoded token config can be a `TokenCreationConfigV1`, `TokenCreationConfigV2`, or `TokenCreationConfigV3`.

  Correspondingly the existing `premintV1/premintV2/premintERC20` functions are deprecated in favor of this new function `premint` that takes a `PremintConfigEncoded` for the premintConfig, and the `contractCreationConfig` as the first argument. If the `premintCollection` parameter is set to a zeroAddress, the function will get or create a contract with an address determined by the contractCreationConfig. This single function works with all versions of premint configs:

  ```solidity
  struct PremintConfigEncoded {
    // Unique id of the token, used to ensure that multiple signatures can't be used to create the same intended token.
    // only one signature per token id, scoped to the contract hash can be executed.
    uint32 uid;
    // Version of this premint, scoped to the uid and contract.  Not used for logic in the contract, but used externally to track the newest version
    uint32 version;
    // If executing this signature results in preventing any signature with this uid from being minted.
    bool deleted;
    // abi encoded token creation config
    bytes tokenConfig;
    // hashed premint config version
    bytes32 premintConfigVersion;
  }

  function premint(
    ContractWithAdditionalAdminsCreationConfig memory contractConfig,
    address premintCollection,
    PremintConfigEncoded calldata encodedPremintConfig,
    bytes calldata signature,
    uint256 quantityToMint,
    MintArguments calldata mintArguments,
    address firstMinter,
    address signerContract
  ) external payable returns (uint256 tokenId);
  ```

  `premintV2WithSignerContract` has been removed from the preminter contract to save contract size.

  #### 1155 factory's createContractDeterministic resulting address is affected by `setupActions`

  The FactoryProxy's `createContractDeterministic` function now takes into consideration the `bytes[] calldata setupActions` when creating the contract at the deterministic address. This won't affect contracts that don't have any setup actions, as their address will be the same as it was before.

## 2.9.1

### Patch Changes

- cd6c6361: ERC20 Minter V2 Changes:
  - Adds a flat ETH fee that goes to Zora (currently this fee is 0.000111 ETH but the contract owner can change this fee at any time)
  - Reward recipients will still receive ERC20 rewards however this percentage can now be changed at any time by the contract owner
  - Adds an `ERC20MinterConfig` struct which contains `zoraRewardRecipientAddress`, `rewardRecipientPercentage`, and `ethReward`
  - Zora Reward Recipient Address can now be changed at any time by the contract owner as well
  - `mint` function is now payable
  - New functions:
    - `function ethRewardAmount() external view returns (uint256)`
    - `function setERC20MinterConfig(ERC20MinterConfig memory config) external`
    - `function getERC20MinterConfig() external view returns (ERC20MinterConfig memory)`
  - New events:
    - `event ERC20MinterConfigSet(ERC20MinterConfig config)`
  - Removed events:
    - `event ZoraRewardsRecipientSet(address indexed prevRecipient, address indexed newRecipient)`
    - `event ERC20MinterInitialized(uint256 rewardPercentage)`

## 2.9.0

### Minor Changes

- 50a4e09:
  - Zora Creator 1155 contracts use the MINTs contracts to get the mint fee, mint, and redeem a mint ticket upon minting.
  - `ZoraCreator1155Impl` adds a new method `mintWithMints` that allows for minting with MINTs that are already owned.
  - 50a4e09: - Zora Creator 1155 contracts no longer have a public facing function `computeFreeMintRewards` and `computePaidMintRewards`
  - protocol rewards calculation logic has been refactored and moved from the RewardSplits contract to the ZoraCreator1155Impl itself to save on contract size.
  - remove `ZoraCreator1155Impl.adminMintBatch` to save contract size
  - 50a4e09: - To support the MINTs contract passing the first minter as an argument to `premintV2WithSignerContract` - we add the field `firstMinter` to `premintV2WithSignerContract`, and then in the 1155 check that the firstMinter argument is not address(0) since it now can be passed in manually.

### ZoraCreator1155Impl rewards splits are percentage based instead of a fixed value.

Prior to 2.9.0, rewards were distributed based on a fixed value in ETH per token minted. From 2.9.0 rewards are distributed based on a percentage of the total reward collected for a mint. The following table breaks down the reward splits for both free and paid mints before and after 2.9.0:

| Reward Type            | Free Mints (Prior to 2.9.0) | Paid Mints (Prior to 2.9.0) | Free Mints (After 2.9.0) | Paid Mints (After 2.9.0) |
| ---------------------- | --------------------------- | --------------------------- | ------------------------ | ------------------------ |
| Creator Reward         | 0.000333 ETH per token      | -                           | 42.8571% of total reward | -                        |
| First Minter Reward    | 0.000111 ETH                | 0.000111 ETH per token      | 14.2285%                 | 28.5714% of total reward |
| Create Referral Reward | 0.000111 ETH                | 0.000222 ETH                | 14.2285%                 | 28.5714%                 |
| Mint Referral Reward   | 0.000111 ETH                | 0.000222 ETH                | 14.2285%                 | 28.5714%                 |
| Zora Platform Reward   | 0.000111 ETH                | 0.000222 ETH                | 14.2285%                 | 28.5714%                 |

## 2.8.1

### Patch Changes

- c2a0a2b: Moved dev time dependencies to devDependencies since they are not needed by external users of the package, they are only used for codegen

## 2.8.0

### Minor Changes

- 13a4785: Adds ERC20 Minter contract which enables zora 1155 creator NFTs to be minted with ERC20 tokens

### Patch Changes

- 13a4785: Adds first minter reward to ERC20 Minter
- 1cf02a4: Add ERC7572 ContractURIUpdated() event for indexing
- 079a596: Moved shared functionality into shared-contracts. premintWithSignerContract takes firstMinter as an argument

## 2.8

- 13a4785: Adds ERC20 Minter which allows users to mint NFTs with ERC20 tokens.

## 2.7.3

### Patch Changes

- 52b16aa: Publishing package in format that supports commonjs imports by specifying exports.

## 2.7.2

### Patch Changes

- acf21c0:
  - `ZoraCreator1155PremintExecutorImpl` and `ZoraCreator1155Impl` support EIP-1271 based signatures for premint token creation, by taking in an extra param indicating the signing contract, and if that parameter is passed, calling a function on that contract address to validate the signature. EIP-1271 is not supported with PremintV1 signatures.
  - `ZoraCreator1155Impl` splits out `supportsInterface` check for premint related functionality into two separate interfaces to check for, allowing each interface to be updated independently.

## 2.7.1

### Patch Changes

- 8107ffe: Preminter impl disables initializers

## 2.7.0

### Minor Changes

- e990b9d: Remove platform referral from RewardsSplits. Use new signature for 1155 for `mint` which takes an array of reward recipients.

### Patch Changes

- Updated dependencies [e990b9d]
  - @zoralabs/protocol-rewards@1.2.3

## 2.5.4

### Patch Changes

- 7e00197: \* For premintV1 and V2 - mintReferrer has been changed to an array `mintRewardsRecipients` - which the first element in array is `mintReferral`, and second element is `platformReferral`. `platformReferral is not used by the premint contract yet`.

## 2.5.3

### Patch Changes

- d9f3596: For premint - fix bug where fundsRecipient was not set on the fixed price minter. Now it is properly set to the royaltyRecipient/payoutRecipient

## 2.5.2

### Patch Changes

- e4edaac: fixed bug where premint config v2 did not have correct eip-712 domain. fixed bug in CreatorAttribution event where structHash was not included in it

## 2.5.1

### Patch Changes

- 18de283: Fixed setting uid when doing a premint v1

## 2.5.0

### Minor Changes

- d84721a: # Premint v2

  ### New fields on signature

  Adding a new `PremintConfigV2` struct that can be signed, that now contains a `createReferral`. `ZoraCreator1155PremintExecutor` recognizes new version of the premint config, and still works with the v1 (legacy) version of the `PremintConfig`. Version one of the premint config still works and is still defined in the `PremintConfig` struct.

  Additional changes included in `PremintConfigV2`:

  - `tokenConfig.royaltyMintSchedule` has been removed as it is deprecated and no longer recognized by new versions of the 1155 contract
  - `tokenConfig.royaltyRecipient` has been renamed to `tokenConfig.payoutRecipient` to better reflect the fact that this address is used to receive creator rewards, secondary royalties, and paid mint funds. This is the address that will be set on the `royaltyRecipient` for the created token on the 1155 contract, which is the address that receives creator rewards and secondary royalties for the token, and on the `fundsRecipient` on the ZoraCreatorFixedPriceSaleStrategy contract for the token, which is the address that receives paid mint funds for the token.

  ### New MintArguments on premint functions, specifying `mintRecipient` and `mintReferral`

  `mintReferral` and `mintRecipient` are now specified in the premint functions on the `ZoraCreator1155PremintExecutor`, via the `MintArguments mintArguments` param; new `premintV1` and `premintV2` functions take a `MintArguments` struct as an argument which contains `mintRecipient`, defining which account will receive the minted tokens, `mintComment`, and `mintReferral`, defining which account will receive a mintReferral reward, if any. `mintRecipient` must be specified or else it reverts.

  ### Replacing external signature validation and authorization check with just authorization check

  `ZoraCreator1155PremintExecutor`'s function `isValidSignature(contractConfig, premintConfig)` is deprecated in favor of:

  ```solidity
  isAuthorizedToCreatePremint(
        address signer,
        address premintContractConfigContractAdmin,
        address contractAddress
  ) public view returns (bool isAuthorized)
  ```

  which instead of validating signatures and checking if the signer is authorized to create premints, just checks if an signer is authorized to create premints on the contract. This offloads signature decoding/validation to calling clients offchain, and reduces needing to create different signatures for this function on the contract for each version of the premint config. It also allows Premints to be validated on contracts that were not created using premints, such as contracts that are upgraded, and contracts created directly via the factory.

  ### Changes to handling of setting of fundsRecipient

  Previously the `fundsRecipient` on the fixed priced minters' sales config for the token was set to the signer of the premint. This has been changed to be set to the `payoutRecipient` of the premint config on `PremintConfigV2`, and to the `royaltyRecipient` of the premint config for v1 of the premint config, for 1155 contracts that are to be newly created, and for existing 1155 contracts that are upgraded to the latest version.

  ### Changes to 1155's `delegateSetupNewToken`

  `delegateSetupNewToken` on 1155 contract has been updated to now take an abi encoded premint config, premint config version, and send it to an external library to decode the config, the signer, and setup actions. Previously it took a non-encoded PremintConfig. This new change allows this function signature to support multiple versions of a premint config, while offloading decoding of the config and the corresponding setup actions to the external library. This ultimately allows supporting multiple versions of a premint config and corresponding signature without increasing codespace.

  `PremintConfigV2` are updated to contain `createReferral`, and now look like:

  ```solidity
  struct PremintConfigV2 {
    // The config for the token to be created
    TokenCreationConfigV2 tokenConfig;
    // Unique id of the token, used to ensure that multiple signatures can't be used to create the same intended token.
    // only one signature per token id, scoped to the contract hash can be executed.
    uint32 uid;
    // Version of this premint, scoped to the uid and contract.  Not used for logic in the contract, but used externally to track the newest version
    uint32 version;
    // If executing this signature results in preventing any signature with this uid from being minted.
    bool deleted;
  }

  struct TokenCreationConfigV2 {
    // Metadata URI for the created token
    string tokenURI;
    // Max supply of the created token
    uint256 maxSupply;
    // Max tokens that can be minted for an address, 0 if unlimited
    uint64 maxTokensPerAddress;
    // Price per token in eth wei. 0 for a free mint.
    uint96 pricePerToken;
    // The start time of the mint, 0 for immediate.  Prevents signatures from being used until the start time.
    uint64 mintStart;
    // The duration of the mint, starting from the first mint of this token. 0 for infinite
    uint64 mintDuration;
    // RoyaltyBPS for created tokens. The royalty amount in basis points for secondary sales.
    uint32 royaltyBPS;
    // The address that will receive creatorRewards, secondary royalties, and paid mint funds.  This is the address that will be set on the `royaltyRecipient` for the created token on the 1155 contract, which is the address that receives creator rewards and secondary royalties for the token, and on the `fundsRecipient` on the ZoraCreatorFixedPriceSaleStrategy contract for the token, which is the address that receives paid mint funds for the token.
    address payoutRecipient;
    // Fixed price minter address
    address fixedPriceMinter;
    // create referral
    address createReferral;
  }
  ```

  `PremintConfig` fields are **the same as they were before, but are treated as a version 1**:

  ```solidity
  struct PremintConfig {
    // The config for the token to be created
    TokenCreationConfig tokenConfig;
    // Unique id of the token, used to ensure that multiple signatures can't be used to create the same intended token.
    // only one signature per token id, scoped to the contract hash can be executed.
    uint32 uid;
    // Version of this premint, scoped to the uid and contract.  Not used for logic in the contract, but used externally to track the newest version
    uint32 version;
    // If executing this signature results in preventing any signature with this uid from being minted.
    bool deleted;
  }

  struct TokenCreationConfig {
    // Metadata URI for the created token
    string tokenURI;
    // Max supply of the created token
    uint256 maxSupply;
    // Max tokens that can be minted for an address, 0 if unlimited
    uint64 maxTokensPerAddress;
    // Price per token in eth wei. 0 for a free mint.
    uint96 pricePerToken;
    // The start time of the mint, 0 for immediate.  Prevents signatures from being used until the start time.
    uint64 mintStart;
    // The duration of the mint, starting from the first mint of this token. 0 for infinite
    uint64 mintDuration;
    // deperecated field; will be ignored.
    uint32 royaltyMintSchedule;
    // RoyaltyBPS for created tokens. The royalty amount in basis points for secondary sales.
    uint32 royaltyBPS;
    // The address that will receive creatorRewards, secondary royalties, and paid mint funds.  This is the address that will be set on the `royaltyRecipient` for the created token on the 1155 contract, which is the address that receives creator rewards and secondary royalties for the token, and on the `fundsRecipient` on the ZoraCreatorFixedPriceSaleStrategy contract for the token, which is the address that receives paid mint funds for the token.
    address royaltyRecipient;
    // Fixed price minter address
    address fixedPriceMinter;
  }
  ```

  ### Changes to `ZoraCreator1155PremintExecutorImpl`:

  - new function `premintV1` - takes a `PremintConfig`, and premint v1 signature, and executes a premint, with added functionality of being able to specify mint referral and mint recipient
  - new function `premintV2` - takes a `PremintConfigV2` signature and executes a premint, with being able to specify mint referral and mint recipient
  - deprecated function `premint` - call `premintV1` instead
  - new function

  ```solidity
  isAuthorizedToCreatePremint(
          address signer,
          address premintContractConfigContractAdmin,
          address contractAddress
  ) public view returns (bool isAuthorized)
  ```

  takes a signer, contractConfig.contractAdmin, and 1155 address, and determines if the signer is authorized to sign premints on the given contract. Replaces `isValidSignature` - by putting the burden on clients to first decode the signature, then pass the recovered signer to this function to determine if the signer has premint authorization on the contract.

  - deprecated function `isValidSignature` - call `isAuthorizedToCreatePremint` instead

### Patch Changes

- 885ffa4: Premint executor can still execute premint mints that were created with V1 signatures for `delegateSetupNewToken`
- ffb5cb7: Premint - added method getSupportedPremintSignatureVersions(contractAddress) that returns an array of the premint signature versions an 1155 contract supports. If the contract hasn't been created yet, assumes that when it will be created it will support the latest versions of the signatures, so the function returns all versions.
- ffb5cb7: Added method `IZoraCreator1155PremintExecutor.supportedPremintSignatureVersions(contractAddress)` that tells what version of the premint signature the contract supports, and added corresponding method `ZoraCreator1155Impl.supportedPremintSignatureVersions()` to fetch supported version. If premint not supported, returns an empty array.
- cacb543: Added impl getter to premint executor

## 2.4.1

### Patch Changes

- 63ef7f6: Added missing functions to IZoraCreator1155

## 2.4.0

### Minor Changes

- 366ac20: Fix broken storage layout by not including an interface on CreatorRoyaltiesControl
- e25ac54: ignore nonzero supply royalty schedule

## 2.3.1

### Patch Changes

- e6f61a9: Include all minter and royalty errors in erc1155 and premint executor abis

## 2.3.0

### Minor Changes

- 4afa879: Creator reward recipient can now be defined on a token by token basis. This allows for multiple creators to collaborate on a contract and each to receive rewards for the token they created. The royaltyRecipient storage field is now used to determine the creator reward recipient for each token. If that's not set for a token, it falls back to use the contract wide fundsRecipient.

## 2.1.0

### Minor Changes

- 9495c34: Supply royalties are no longer supported

## 2.0.4

### Patch Changes

- 64da698: Exporting abi

## 2.0.3

### Patch Changes

- d3ddfbb: fix version packages tests

## 2.0.2

### Patch Changes

- 9207e8f: Deployed determinstic proxies and latest versions to mainnet, goerli, base, base goerli, optimism, optimism goerli

## 2.0.1

### Patch Changes

- 35db763: Adding in built artifacts to package

## 2.0.0

### Major Changes

- 82f6506: Premint with Delegated Minting
  Determinstic Proxy Addresses
  Premint deployed to zora and zora goerli

## 1.6.1

### Patch Changes

- b83e1b6: Add first minter payouts as chain sponsor

## 1.6.0

### Minor Changes

- 399b8e6: Adds first minter rewards to zora 1155 contracts.
- 399b8e6: Added deterministic contract creation from the Zora1155 factory, Preminter, and Upgrade Gate
- 399b8e6: Added the PremintExecutor contract, and updated erc1155 to support delegated minting

* Add first minter rewards
* [Separate upgrade gate into new contract](https://github.com/ourzora/zora-1155-contracts/pull/204)

## 1.5.0

### Minor Changes

- 1bf2d52: Add TokenId to redeemInstructionsHashIsAllowed for Redeem Contracts
- a170f1f: - Patches the 1155 `callSale` function to ensure that the token id passed matches the token id encoded in the generic calldata to forward
  - Updates the redeem minter to v1.1.0 to support b2r per an 1155 token id

### Patch Changes

- b1dbb47: Fix types reference for package export
- 4cb56d4: - Ensures sales configs can only be updated for the token ids specified
  - Deprecates support with 'ZoraCreatorRedeemMinterStrategy' v1.0.1

## 1.4.0

### Minor Changes

- 5b3fafd: Change permission checks for contracts – fix allowing roles that are not admin assigned to tokenid 0 to apply those roles to any token in the contract.
- 9f6510d: Add support for rewards

  - Add new minting functions supporting rewards
  - Add new "rewards" library

## 1.3.3

### Patch Changes

- 498998f: Added pgn sepolia
  Added pgn mainnet
- cc3b55a: New base mainnet deploy
