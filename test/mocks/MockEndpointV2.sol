// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {MessagingReceipt, MessagingFee, Origin} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";

contract MockEndpointV2 {
    uint32 public eid;
    mapping(address => address) public delegates;

    constructor(uint32 _eid) {
        eid = _eid;
    }

    function setDelegate(address _delegate) external {
        delegates[msg.sender] = _delegate;
    }

    function send(MessagingParams calldata, address) external payable returns (MessagingReceipt memory) {
        return MessagingReceipt({guid: bytes32(0), nonce: 1, fee: MessagingFee(msg.value, 0)});
    }

    function quote(MessagingParams calldata, address) external pure returns (MessagingFee memory) {
        return MessagingFee(0.01 ether, 0);
    }

    function lzReceive(Origin calldata, address, bytes32, bytes calldata, bytes calldata) external payable {}

    struct MessagingParams {
        uint32 dstEid;
        bytes32 receiver;
        bytes message;
        bytes options;
        bool payInLzToken;
    }
}
