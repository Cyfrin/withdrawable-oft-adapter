// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "src/WithdrawableOFTAdapter.sol";
import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";

contract MockOFT is OFT {
    constructor(string memory _name, string memory _symbol, address _lzEndpoint, address _delegate)
        OFT(_name, _symbol, _lzEndpoint, _delegate)
        Ownable(_delegate)
    {}

    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }
}
