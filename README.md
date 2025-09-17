> [!WARNING]
> If you use this package, it is imperative that you understand all the inner workings of LayerZero and this codebase, as there are many pitfalls to shutting off the LayerZero functionality.

# Withdrawable OFT Adapter

If you choose to launch with the LayerZero architecture, you're locking your contracts into a single cross-chain vendor that is very difficult to migrate from and adds a lot of complexity to your token contracts. The LayerZero default install of lockboxes locks asset issuers in, and we have worked with experienced users who have regretted this. This project is a version of the OFTAdpater, which enables permissioned withdrawal of funds for migration or recovery.

This project is a minimal package that can be used to help opt-out of the LayerZero OFT system at some point down the line. Even though this codebase has been audited, during an audit, you should include the code from this package in scope as well as there are many pitfalls with integrating a package like this and LayerZero, which is not designed for people to opt-out.

We have seen some examples of this in the wild, such as with:

- [CAKE](https://bscscan.com/address/0xb274202daba6ae180c665b4fbe59857b7c3a8091#code) (fallbackWithdraw + dropFailedMessage)
- [VIRTUALS](https://github.com/twx-virtuals/virtual-oft-adapter/blob/main/contracts/VirtualOFTAdapter.sol) (fallbackWithdraw without the function to drop a message that needs withdrawal)

This package allows users to withdraw or opt out of the OFT system.

# Table of Contents
- [Withdrawable OFT Adapter](#withdrawable-oft-adapter)
- [Table of Contents](#table-of-contents)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
- [Comparison to Default OFTAdapter](#comparison-to-default-oftadapter)
  - [Known Issues](#known-issues)
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
| ✅ quoteSend((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),bool)                                 | 3b6f743b   |
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

## Known Issues
- We use `__` instead of `_` prefixes sometimes to avoid shadowing variables.
- Anything in the `report.md` report from Aderyn is known.

# User notes

- Do not use this package if you already have tokens deployed across multiple chains. You'd need a custom `MintBurnOFTAdpater` as well.
- Do not use this package if you want more flexible options for migration off of LayerZero. A proxy of the OFTAdapter is a better solution for that.
- If you choose to disable the LayerZero/OFT functionality, you will not be able to re-enable it on these contracts. You'd have to deploy a new set of adapters to do so.
- The owners of this codebase essentially have the power to rug users on all destination chains at any time if they choose to do so.
- Understand that when you migrate, you should [clear](https://docs.layerzero.network/v2/developers/evm/troubleshooting/debugging-messages#clearing-message) any messages that have not been delivered yet.
- This codebase is not compatible with rebasing tokens.
- If you use the adapter with OFT tokens and disable the source and destination chains, in order to "restart" with OFT functionality, you'd need to deploy a new adapter for your token, and then you'd need to wrap the OFT tokens in mint and burn adapters (not in this repo). 
- This pacakge is meant to be deployed when you already have a token on a main chain, but do not have tokens on any other chains other than your tokens home base. If you already have tokens on multiple chains, you will need a custom `MintBurnOFTAdapter` as well, which is not in this repo.
- If you wish to use any functionality outside of this repo, it is recommended you use a proxy instead. Using either this repo or a proxy **will mean there are strong centralization vectors on your token.** This is a blessing and a curse, if your team is compromised or you make a mistake you can do a lot of damage to token holders.
