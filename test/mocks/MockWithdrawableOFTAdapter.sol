// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {WithdrawableOFTAdapter, Ownable} from "src/WithdrawableOFTAdapter.sol";

contract MockWithdrawableOFTAdapter is WithdrawableOFTAdapter {
    constructor(address _token, address _lzEndpoint, address _delegate, address _owner, uint256 _emergencyWithdrawDelay)
        WithdrawableOFTAdapter(_token, _lzEndpoint, _delegate, _owner, _emergencyWithdrawDelay)
    {}
}
