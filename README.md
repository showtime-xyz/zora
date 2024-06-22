# Zora Protocol

[![Contracts](https://github.com/ourzora/zora-protocol/actions/workflows/contracts.yml/badge.svg)](https://github.com/ourzora/zora-protocol/actions/workflows/contracts.yml)

This repository is a monorepo for the Zora Protocol

In it you will find:

- [Zora 1155 Contracts](./packages/1155-contracts)
- [Zora 1155 Deployment Scripts](./packages/1155-deployments)
- [Zora Creator Subgraph](./packages/creator-subgraph)
- [Protocol Deployments](./packages/protocol-deployments)
- [Protocol Rewards](./packages/protocol-rewards)
- [Protocol SDK](./packages/protocol-sdk)

## Official docs

[View the official docs](https://docs.zora.co/docs/smart-contracts/creator-tools/intro)

## Setup

Install prerequisites:

- [Node.js and yarn](https://classic.yarnpkg.com/lang/en/docs/install/#mac-stable)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

Install dependencies:

    yarn

Build contracts:

    yarn build

Run tests:

    yarn test

Run in development mode (watch tests):

    yarn dev

## Bug Bounty

5 ETH for any critical bugs that could result in loss of funds. Rewards will be given for smaller bugs or ideas.

## Development workflow

See [DEVELOPING.md](./DEVELOPING.md)
