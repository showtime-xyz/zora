# Drakula Edit

Cloned Zora Creator Subgraph and modified to index Drakula Creator contracts.
Run `yarn` and `yarn build` at root of contracts to build contracts (need `forge` installed).

Then run `NETWORK=base-sepolia yarn run build` or `NETWORK=base-mainnet yarn run build` to build subgraph in this dir.

Then run goldsky command to deploy subgraph.
`cd packages/creator-subgraph`
`goldsky subgraph deploy drakula-zora-base-sepolia/0.2.8`

And create webhook for subgraph.
`goldsky subgraph webhook create drakula-zora-base-sepolia/0.2.8 --name 1155-base-sepolia-create-token-3 --entity zora_create_token --url https://webhook.site/max`

# Zora Creator Subgraph

This subgraph indexes all Zora creator contracts (both 721 and 1155) along with creator rewards.

Main entities can be found in `schema.graphql`.

To add new chains, new configuration files can be added to the `config/` folder. The config chain name needs to match the network name in the graph indexer instance used.

This subgraph uses metadata IPFS indexing and subgraph optional features.

## Installation

The graph docs: https://thegraph.academy/developers/subgraph-development-guide/

After `git clone` run `yarn` to install dependencies.

Steps to build:

```sh
NETWORK=zora yarn run build

```

NETWORK needs to be a name of a valid network configuration file in `config/`.

After building, you can use the graph cli or goldsky cli to deploy the built subgraph for the network specified above.

## Deployment shortcuts

Only supports goldsky deploys for now:

Grafts subgraph from FROM_VERSION:

./scripts/multideploy.sh NEW_VERSION NETWORKS FROM_VERSION

./scripts/multideploy.sh 1.10.0 zora-testnet,optimism-goerli,base-goerli 1.8.0

Deploys without grafting:

./scripts/multideploy.sh NEW_VERSION NETWORKS

./scripts/multideploy.sh 1.10.0 zora-testnet,optimism-goerli,base-goerli

Deploys a new version for _all_ networks without grafting: (not typical, indexing takes a long time in many cases.)

./scripts/multideploy.sh NEW_VERSION

# ABIs

ABIs are automatically copied to the `abis` folder from the node packages on build.

ABIs that are not included in the node modules are found in the `graph-api`.
