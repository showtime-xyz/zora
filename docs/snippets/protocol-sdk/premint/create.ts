import { createCreatorClient } from "@zoralabs/protocol-sdk";
import { walletClient, chainId, publicClient, creatorAccount } from "./config";

const creatorClient = createCreatorClient({ chainId, publicClient });

const {
  // the premint that was created
  premintConfig,
  // collection address of the premint
  collectionAddress,
  // used to sign and submit the premint to the Zora Premint API
  signAndSubmit,
} = await creatorClient.createPremint({
  // collection info of collection to create.  The combination of these fields will determine the
  // deterministic collection address.
  contract: {
    // the account that will be the admin of the collection.  Must match the signer of the premint.
    contractAdmin: creatorAccount,
    contractName: "Testing Contract",
    contractURI:
      "ipfs://bafkreiainxen4b4wz4ubylvbhons6rembxdet4a262nf2lziclqvv7au3e",
  },
  // token info of token to create
  token: {
    tokenURI:
      "ipfs://bafkreice23maski3x52tsfqgxstx3kbiifnt5jotg3a5ynvve53c4soi2u",

    payoutRecipient: creatorAccount,
  },
});

// sign the new premint, and submit it to the Zora Premint API
await signAndSubmit({
  walletClient,
});

export const uid = premintConfig.uid;
export const collection = collectionAddress;
