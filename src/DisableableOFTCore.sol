// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {
    OFTCore,
    SendParam,
    OFTReceipt,
    MessagingFee,
    MessagingReceipt,
    Origin
} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DisableableOFTCore Contract
 * @dev DisableableOFTCore has the ability to disable the layer zero functionality in emergency or migration scenarios.
 */
abstract contract DisableableOFTCore is OFTCore {
    error OFTSendDisabled();
    error OFTReceiveDisabled();

    event SetOFTSend(bool indexed isOFTEnabled);
    event SetOFTReceive(bool indexed isOFTReceiveEnabled);

    bool internal s_isOFTSendEnabled;
    bool internal s_isOFTReceiveEnabled;

    /**
     * @dev Constructor for the OFT contract.
     * @param _owner The owner capable of disabling the OFT functionality.
     */
    constructor(address _owner) Ownable(_owner) {
        s_isOFTSendEnabled = true;
        s_isOFTReceiveEnabled = true;
    }

    /* 
     * @dev In case of an emergency or migration, owners can disable the OFT functionality
     * @notice Mostly likely this would be disabled during a migration
     */
    function setOFTSend(bool oftSendEnabled) external onlyOwner {
        s_isOFTSendEnabled = oftSendEnabled;
        emit SetOFTSend(oftSendEnabled);
    }

    /*
     * @dev In case of an emergency or migration, owners can disable the OFT receive functionality
     * @notice Mostly likely this would be disabled during an oracle failure with LayerZero
     */
    function setOFTReceive(bool oftReceiveEnabled) external onlyOwner {
        s_isOFTReceiveEnabled = oftReceiveEnabled;
        emit SetOFTReceive(oftReceiveEnabled);
    }

    /*//////////////////////////////////////////////////////////////
                               OVERRIDES
    //////////////////////////////////////////////////////////////*/
    // @inheritdoc OFTCore
    function _send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        internal
        virtual
        override
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        if (!s_isOFTSendEnabled) revert OFTSendDisabled();
        return super._send(_sendParam, _fee, _refundAddress);
    }

    // @inheritdoc OFTCore
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address, /*_executor*/ // @dev unused in the default implementation.
        bytes calldata _extraData // @dev unused in the default implementation.
    ) internal virtual override {
        if (!s_isOFTReceiveEnabled) revert OFTReceiveDisabled();
        super._lzReceive(_origin, _guid, _message, address(0), _extraData);
    }

    /*//////////////////////////////////////////////////////////////
                                  VIEW
    //////////////////////////////////////////////////////////////*/
    function isOFTSendEnabled() external view returns (bool) {
        return s_isOFTSendEnabled;
    }

    function isOFTReceiveEnabled() external view returns (bool) {
        return s_isOFTReceiveEnabled;
    }
}
