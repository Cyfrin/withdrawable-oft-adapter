// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    OFTCore,
    OFTLimit,
    SendParam,
    OFTFeeDetail,
    OFTReceipt,
    MessagingFee,
    MessagingReceipt,
    Origin
} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {DisableableOFTCore, Ownable, OFT} from "src/DisableableOFTCore.sol";

/**
 * @title DisableableOFT Contract
 * @dev DisableableOFT is an ERC-20 token that can disable the layer zero functionality in emergency or migration scenarios.
 */
abstract contract DisableableOFT is DisableableOFTCore, OFT {
    /**
     * @dev Constructor for the OFT contract.
     * @param __name The name of the OFT.
     * @param __symbol The symbol of the OFT.
     * @param __lzEndpoint The LayerZero endpoint address.
     * @param __delegate The delegate capable of making OApp configurations inside of the endpoint.
     * @param __owner The owner capable of disabling the OFT functionality.
     */
    constructor(string memory __name, string memory __symbol, address __lzEndpoint, address __delegate, address __owner)
        OFT(__name, __symbol, __lzEndpoint, __delegate)
        DisableableOFTCore(__owner)
    {}

    /*//////////////////////////////////////////////////////////////
                               OVERRIDES
    //////////////////////////////////////////////////////////////*/
    // @inheritdoc OFTCore
    function _send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        internal
        virtual
        override(DisableableOFTCore, OFTCore)
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        return DisableableOFTCore._send(_sendParam, _fee, _refundAddress);
    }

    // @inheritdoc OFTCore
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address, /*_executor*/ // @dev unused in the default implementation.
        bytes calldata _extraData // @dev unused in the default implementation.
    ) internal virtual override(DisableableOFTCore, OFTCore) {
        return DisableableOFTCore._lzReceive(_origin, _guid, _message, address(0), _extraData);
    }
}
