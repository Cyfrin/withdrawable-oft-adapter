// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DisableableOFT} from "src/DisableableOFT.sol";

contract MockDisableableOFT is DisableableOFT {
    constructor(string memory _name, string memory _symbol, address _lzEndpoint, address _delegate, address _owner)
        DisableableOFT(_name, _symbol, _lzEndpoint, _delegate, _owner)
    {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
