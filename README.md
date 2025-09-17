> [!WARNING] If you use this package, it is imperitive that you understand all the inner workings of layerzero and this codebase, as there are many pitfalls to shutting off the LayerZero functionality.

# Withdrawable OFT Adapter

If you choose to launch with the LayerZero achitecture, you're locking your contracts into a single cross-chain vendor that is very difficult to migrate from, and adds a lot of complexity to your token contracts. The LayerZero default install of lockboxes locks asset issuers in, and we have worked with experienced users who have regretted this. This project is a version of the OFTAdpater, which enables permissioned withdrawal of funds for migration or recovery.

This project is a minimal package that can be used to help opt-out of the LayerZero OFT system at some point down the line. Even though this codebase has been audited, during an audit, you should include the code from this package in scope as well as there are many pitfalls with integrating a package like this and LayerZero, which is not designed for people to opt-out.

We have seen some examples of this in the wild, such as with:

- [CAKE](https://bscscan.com/address/0xb274202daba6ae180c665b4fbe59857b7c3a8091#code) (fallbackWithdraw + dropFailedMessage)
- [VIRTUALS](https://github.com/twx-virtuals/virtual-oft-adapter/blob/main/contracts/VirtualOFTAdapter.sol) (fallbackWithdraw without the function to drop a message that needs withdrawal)

This package allows users to withdraw or opt-out of the OFT system.

# Table of Contents
- [Withdrawable OFT Adapter](#withdrawable-oft-adapter)
- [Table of Contents](#table-of-contents)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
- [Comparison to Default OFTAdapter](#comparison-to-default-oftadapter)
- [Audit Information](#audit-information)
  - [Known Issues](#known-issues)
  - [Audit Notes](#audit-notes)
  - [What to look for](#what-to-look-for)
- [User notes](#user-notes)

# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`
- [just](https://github.com/casey/just)

## Quickstart

```
git clone https://github.com/Cyfrin/withdrawable-oft-adapter
cd withdrawable-oft-adapter
just test
```

# Comparison to Default OFTAdapter

Here is a list of functions the default OFTAdapter has, and therefore also our OFT adapter, and what we've assessed we should do with these functions in our codebase.

- 👀: Means the function is a view function, and doesn't need to be addressed
- ⭐️: Means the function is new
- ✅: Means the function has been addressed by the new codebase
- 👌: Means the function is acceptable in the new codebase

```
% forge inspect EWithdrawableOFTAdapter methods

╭----------------------------------------------------------------------------------------------------+------------╮
| Method                                                                                             | Identifier |
+=================================================================================================================+
| 👀 SEND()                                                                                             | 1f5e1334   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 SEND_AND_CALL()                                                                                    | 134d4f25   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 allowInitializePath((uint32,bytes32,uint64))                                                       | ff7bd03d   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 approvalRequired()                                                                                 | 9f68b964   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 combineOptions(uint32,uint16,bytes)                                                                | bc70b354   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 decimalConversionRate()                                                                            | 963efcaa   |
|----------------------------------------------------------------------------------------------------+------------|
| ⭐️ emergencyWithdrawTokens(address,uint256)                                                           | 917bb998   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 endpoint()                                                                                         | 5e280f11   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 enforcedOptions(uint32,uint16)                                                                     | 5535d461   |
|----------------------------------------------------------------------------------------------------+------------|
| ⭐️ initializeEmergencyWithdraw()                                                                      | 8c923dae   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 isComposeMsgSender((uint32,bytes32,uint64),bytes,address)                                          | 82413eac   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 isPeer(uint32,bytes32)                                                                             | 5a0dfe4d   |
|----------------------------------------------------------------------------------------------------+------------|
| ✅ lzReceive((uint32,bytes32,uint64),bytes32,bytes,address,bytes)                                     | 13137d65   |
|----------------------------------------------------------------------------------------------------+------------|
| 👌 lzReceiveAndRevert(((uint32,bytes32,uint64),uint32,address,bytes32,uint256,address,bytes,bytes)[]) | bd815db0   |
|----------------------------------------------------------------------------------------------------+------------|
| 👌 lzReceiveSimulate((uint32,bytes32,uint64),bytes32,bytes,address,bytes)                             | d045a0dc   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 msgInspector()                                                                                     | 111ecdad   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 nextNonce(uint32,bytes32)                                                                          | 7d25a05e   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 oApp()                                                                                             | 52ae2879   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 oAppVersion()                                                                                      | 17442b70   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 oftVersion()                                                                                       | 156a0d0f   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 owner()                                                                                            | 8da5cb5b   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 peers(uint32)                                                                                      | bb0b6a53   |
|----------------------------------------------------------------------------------------------------+------------|
| 👌 preCrime()                                                                                         | b731ea0a   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 quoteOFT((uint32,bytes32,uint256,uint256,bytes,bytes,bytes))                                       | 0d35b415   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 quoteSend((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),bool)                                 | 3b6f743b   |
|----------------------------------------------------------------------------------------------------+------------|
| 👌 renounceOwnership()                                                                                | 715018a6   |
|----------------------------------------------------------------------------------------------------+------------|
| ✅ send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)                 | c7c7f5b3   |
|----------------------------------------------------------------------------------------------------+------------|
| 👌 setDelegate(address)                                                                               | ca5eb5e1   |
|----------------------------------------------------------------------------------------------------+------------|
| 👌 setEnforcedOptions((uint32,uint16,bytes)[])                                                        | b98bd070   |
|----------------------------------------------------------------------------------------------------+------------|
| 👌 setMsgInspector(address)                                                                           | 6fc1b31e   |
|----------------------------------------------------------------------------------------------------+------------|
| 👌 setPeer(uint32,bytes32)                                                                            | 3400288b   |
|----------------------------------------------------------------------------------------------------+------------|
| 👌 setPreCrime(address)                                                                               | d4243885   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 sharedDecimals()                                                                                   | 857749b0   |
|----------------------------------------------------------------------------------------------------+------------|
| 👀 token()                                                                                            | fc0c546a   |
|----------------------------------------------------------------------------------------------------+------------|
| 👌 transferOwnership(address)                                                                         | f2fde38b   |
╰----------------------------------------------------------------------------------------------------+------------╯
```

# Audit Information

- Commit Hash: Coming soon...
```
src
├── DisableableOFT.sol
├── DisableableOFTAdapter.sol
├── DisableableOFTCore.sol
└── WithdrawableOFTAdapter.sol
```
- Solc Version: ^0.8.20 (These are intentially not specific!)
- Chain(s) to deploy contracts [see list here](https://docs.layerzero.network/v2/deployments/deployed-contracts):
    - (Developers should be aware of their EVM settings before deploying to each chain, so issues with unsupported opcodes like PUSH0 due to different solidity versions is not valid here)
  - Abstract Mainnet
  - Animechain Mainnet
  - Ape Mainnet
  - Apex Fusion Nexus Mainnet
  - Aptos
  - Arbitrum Mainnet
  - Arbitrum Nova Mainnet
  - Astar Mainnet
  - Astar zkEVM Mainnet
  - Avalanche Mainnet
  - Bahamut Mainnet
  - Base Mainnet
  - Beam Mainnet
  - Berachain Mainnet
  - Bevm Mainnet
  - Bitlayer Mainnet
  - Blast Mainnet
  - BNB Smart Chain (BSC) Mainnet
  - BOB Mainnet
  - Bouncebit Mainnet
  - Botanix
  - Canto Mainnet
  - Celo Mainnet
  - Codex Mainnet
  - Concrete
  - Conflux eSpace Mainnet
  - CoreDAO Mainnet
  - Corn Mainnet
  - Cronos EVM Mainnet
  - Cronos zkEVM Mainnet
  - Cyber Mainnet
  - Degen Mainnet
  - Dexalot Subnet Mainnet
  - DFK Chain
  - DM2 Verse Mainnet
  - DOS Chain Mainnet
  - EDU Chain Mainnet
  - Ethereum Mainnet
  - Etherlink Mainnet
  - EVM on Flow Mainnet
  - Fantom Mainnet
  - Flare Mainnet
  - Fraxtal Mainnet
  - Fuse Mainnet
  - Glue Mainnet
  - Gnosis Mainnet
  - Goat Mainnet
  - Gravity Mainnet
  - Gunz Mainnet
  - Harmony Mainnet
  - Hedera Mainnet
  - Hemi Mainnet
  - Homeverse Mainnet
  - Humanity Mainnet
  - Horizen EON Mainnet
  - Hubble Mainnet
  - HyperEVM Mainnet
  - inEVM Mainnet
  - Initia Mainnet
  - Ink Mainnet
  - Iota Mainnet
  - Japan Open Chain Mainnet
  - Kaia Mainnet (formerly Klaytn)
  - Kava Mainnet
  - Katana
  - Lens Mainnet
  - Lightlink Mainnet
  - Linea Mainnet
  - Lisk Mainnet
  - Loot Mainnet
  - Lyra Mainnet
  - Manta Pacific Mainnet
  - Mantle Mainnet
  - Merlin Mainnet
  - Meter Mainnet
  - Metis Mainnet
  - Mode Mainnet
  - Moonbeam Mainnet
  - Moonriver Mainnet
  - Morph Mainnet
  - Movement Mainnet
  - Near Aurora Mainnet
  - Nibiru Mainnet
  - OKX Mainnet
  - opBNB Mainnet
  - Optimism Mainnet
  - Orderly Mainnet
  - Otherworld Space Mainnet
  - Peaq Mainnet
  - Plume Mainnet
  - Polygon Mainnet
  - Polygon zkEVM Mainnet
  - Rari Chain Mainnet
  - re.al Mainnet
  - Reya Mainnet
  - Rootstock Mainnet
  - Sanko Mainnet
  - Scroll Mainnet
  - Sei Mainnet
  - Shimmer Mainnet
  - Silicon Mainnet
  - Skale Mainnet
  - Solana Mainnet
  - Soneium Mainnet
  - Sonic Mainnet
  - Sophon Mainnet
  - Somnia Mainnet
  - Story Mainnet
  - Subtensor EVM Mainnet
  - Superposition Mainnet
  - Swell Mainnet
  - Tac
  - Taiko Mainnet
  - TelosEVM Mainnet
  - Tenet Mainnet
  - Tiltyard Mainnet
  - TON Mainnet
  - Tron Mainnet
  - Unichain Mainnet
  - Vana Mainnet
  - Viction Mainnet
  - Worldchain Mainnet
  - X Layer Mainnet
  - Xai Mainnet
  - XChain Mainnet
  - XDC Mainnet
  - XPLA Mainnet
  - Zircuit Mainnet
  - zkLink Mainnet
  - zkSync Era Mainnet
  - Zora Mainnet

## Known Issues
- We use `__` instead of `_` prefixes sometimes to avoid shadowing variables.
- Anything in the `report.md` report from Aderyn is known.

## Audit Notes

1. There are two distinct layer zero packages, `devtools` and `layerzero-v2`, please ensure we are working with the correct implementations for our use case.
2. We used `Ownable` over `Ownable2Step` to reduce complexity. Base contracts already use `Ownable`.
3. Openzeppelin's `Ownable` v4 defaults `msg.sender` to the `owner`, while v5 forces you to initialize with an owner, we wish to use v5.
4. To disable layerzero functionality in the future, we essentially have a flag to revert all `_send` calls and all `lzReceive` calls. In a scenario where layerzero is compromised, this should be sufficient to stop layerzero from stealing any funds. If you find a way for layerzero to steal funds or interfere with users even after these flags are set to disable layer zero, please flag it in the audit.

## What to look for

The point of this codebase is to enable projects to not have to be stuck in vendor lock-in to a cross chain solution if they choose to go with LayerZero at the start. Pay special attention to anything that would make it difficult or impossible to migrate from the OFT/LayerZero setup to Chainlink CCIP (it will be helpful to read up on their documentation).

If a more complex setup is required, a proxy on the original OFTAdapter contracts might be the best solution, let's try to not make something overly complex.

Lows are important to find on this codebase.

# User notes

- Do not user this package if you already have tokens deployed across multiple chains. You'd need a custom MintBurnOFTAdpater as well.
- Do not use this package if you want more flexible options for migration off of LayerZero. A proxy of the OFTAdapter is a better solution for that.
- If you choose to disable the LayerZero/OFT functionality, you will not be able to re-enable it on these contracts. You'd have to deploy a new set of adapters to do so.
- The owners of this codebase essentially have the power to rug users on all destination chains at any time if they choose to do so.
- Understand that when you migrate, you should [clear](https://docs.layerzero.network/v2/developers/evm/troubleshooting/debugging-messages#clearing-message) any messages that have not been delivered yet.
- This codebase is not compatible with rebasing tokens.