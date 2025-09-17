// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DisableableOFTAdapter} from "src/DisableableOFTAdapter.sol";

/**
 * @title WithdrawableOFTAdapter Contract
 * @dev WithdrawableOFTAdapter is a contract that adapts an ERC-20 token to the OFT functionality.
 *
 * @dev For existing ERC20 tokens, this can be used to convert the token to crosschain compatibility.
 * @dev WARNING: ONLY 1 of these should exist for a given global mesh,
 * unless you make a NON-default implementation of OFT and needs to be done very carefully.
 * @dev WARNING: The default WithdrawableOFTAdapter implementation assumes LOSSLESS transfers, ie. 1 token in, 1 token out.
 * IF the 'innerToken' applies something like a transfer fee, the default will NOT work...
 * a pre/post balance check will need to be done to calculate the amountSentLD/amountReceivedLD.
 */
abstract contract WithdrawableOFTAdapter is DisableableOFTAdapter {
    error EmergencyWithdrawDelayNotPassed();
    error MustNotBeZeroAddress();
    error EmergencyWithdrawNotInitialized();
    error EmergencyWithdrawAlreadyInitialized();

    using SafeERC20 for IERC20;

    uint256 internal immutable i_emergencyWithdrawDelay;

    uint256 internal s_emergencyWithdrawInitializedAt;
    address internal s_pendingWithdrawTo;

    event TokensWithdrawn(address indexed to);
    event EmergencyWithdrawInitialized(address indexed to, uint256 indexed timestamp);
    event EmergencyWithdrawCancelled();

    /**
     * @dev Constructor for the EWithdrawableOFTAdapter contract.
     * @param _token The address of the ERC-20 token to be adapted.
     * @param _lzEndpoint The LayerZero endpoint address.
     * @param _delegate The delegate capable of making OApp configurations inside of the endpoint.
     * @param __owner The owner capable of withdrawing tokens.
     * @param _emergencyWithdrawDelay The delay (in seconds) before emergency withdraw can be executed.
     *
     * @dev The emergency delay has pros and cons to shorter or longer timeframes.
     * A shorter timeframe (eg. 0 seconds) allows for quicker response to emergencies (ie, oracle failure), but less time for users to react to a hostile takeover.
     * A longer timeframe (eg. 1 week) allows for more time for users to react to a hostile takeover, but less time for the owner to respond to an emergency (ie, oracle failure).
     */
    constructor(
        address _token,
        address _lzEndpoint,
        address _delegate,
        address __owner,
        uint256 _emergencyWithdrawDelay
    ) DisableableOFTAdapter(_token, _lzEndpoint, _delegate, __owner) {
        i_emergencyWithdrawDelay = _emergencyWithdrawDelay;
    }

    /*//////////////////////////////////////////////////////////////
                            EMERGENCY POWERS
    //////////////////////////////////////////////////////////////*/
    /* 
     * @dev In case of an emergency or migration, owners can withdraw tokens but only after a delay so users can opt out
     * @dev This function will initialize the emergency withdraw process
     * @dev WARNING: Once tokens are withdrawn, lzReceive calls will fail due to not enough liquidity
     * @dev Essentially "bricking" this contract until liquidity is restored, or migrating to another edition
     * 
     * @notice Ideally you would also disable OFT Send powers while the delay is counting down
     */
    function initializeEmergencyWithdraw(address _to) external onlyOwner {
        if (_to == address(0)) {
            revert MustNotBeZeroAddress();
        }
        if (s_emergencyWithdrawInitializedAt != 0) {
            revert EmergencyWithdrawAlreadyInitialized();
        }
        s_pendingWithdrawTo = _to;
        s_emergencyWithdrawInitializedAt = block.timestamp;
        emit EmergencyWithdrawInitialized(_to, block.timestamp);
    }

    /*
     * @dev Cancel the emergency withdraw process
     */
    function cancelEmergencyWithdraw() external onlyOwner {
        if (s_emergencyWithdrawInitializedAt == 0) {
            revert EmergencyWithdrawNotInitialized();
        }
        s_pendingWithdrawTo = address(0);
        s_emergencyWithdrawInitializedAt = 0;
        emit EmergencyWithdrawCancelled();
    }

    /*
     * @dev In case of an emergency or migration, owners can withdraw tokens after delay has passed
     * @dev WARNING: Once tokens are withdrawn, lzReceive calls will fail due to not enough liquidity
     */
    function emergencyWithdraw() external onlyOwner {
        if (
            s_emergencyWithdrawInitializedAt == 0
                || block.timestamp <= s_emergencyWithdrawInitializedAt + i_emergencyWithdrawDelay
        ) {
            revert EmergencyWithdrawDelayNotPassed();
        }
        address to = s_pendingWithdrawTo;
        s_pendingWithdrawTo = address(0);
        s_emergencyWithdrawInitializedAt = 0;
        emit TokensWithdrawn(to);

        uint256 innerTokenBalance = innerToken.balanceOf(address(this));
        innerToken.safeTransfer(to, innerTokenBalance);
    }

    /*//////////////////////////////////////////////////////////////
                                  VIEW
    //////////////////////////////////////////////////////////////*/
    function getWithdrawInformation()
        external
        view
        returns (uint256 emergencyWithdrawInitializedAt, uint256 emergencyWithdrawDelay, address pendingWithdrawTo)
    {
        return (s_emergencyWithdrawInitializedAt, i_emergencyWithdrawDelay, s_pendingWithdrawTo);
    }
}
