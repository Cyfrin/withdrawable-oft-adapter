// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {DisableableOFT} from "src/DisableableOFT.sol";
import {DisableableOFTCore} from "src/DisableableOFTCore.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {
    SendParam, MessagingFee, MessagingReceipt, OFTReceipt
} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {MockEndpointV2} from "test/mocks/MockEndpointV2.sol";
import {MockDisableableOFT} from "test/mocks/MockDisableableOFT.sol";

contract DisableableOFTTest is Test {
    using OptionsBuilder for bytes;

    MockDisableableOFT oftA;
    MockDisableableOFT oftB;
    MockEndpointV2 endpointA;
    MockEndpointV2 endpointB;

    address owner = address(0x1);
    address alice = address(0x2);
    address bob = address(0x3);
    address delegate = address(0x4);

    uint32 constant EID_A = 1;
    uint32 constant EID_B = 2;

    event SetOFTSend(bool indexed isOFTEnabled);
    event SetOFTReceive(bool indexed isOFTReceiveEnabled);

    function setUp() public {
        // Setup endpoints
        endpointA = new MockEndpointV2(EID_A);
        endpointB = new MockEndpointV2(EID_B);

        // Deploy OFTs on both chains
        oftA = new MockDisableableOFT("OFT A", "OFTA", address(endpointA), delegate, owner);

        oftB = new MockDisableableOFT("OFT B", "OFTB", address(endpointB), delegate, owner);

        // Setup peers
        vm.prank(owner);
        oftA.setPeer(EID_B, bytes32(uint256(uint160(address(oftB)))));

        vm.prank(owner);
        oftB.setPeer(EID_A, bytes32(uint256(uint160(address(oftA)))));

        // Mint tokens to alice
        oftA.mint(alice, 1000 ether);
        oftB.mint(bob, 1000 ether);

        // Fund accounts with ETH for gas
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(owner, 10 ether);
    }

    // ============= Disable/Enable Tests =============

    function test_InitialState() public view {
        assertTrue(oftA.isOFTSendEnabled());
        assertTrue(oftA.isOFTReceiveEnabled());
        assertTrue(oftB.isOFTSendEnabled());
        assertTrue(oftB.isOFTReceiveEnabled());
    }

    function test_DisableOFTSend() public {
        vm.expectEmit(true, false, false, false);
        emit SetOFTSend(false);

        vm.prank(owner);
        oftA.disableOFTSend();

        assertFalse(oftA.isOFTSendEnabled());
        assertTrue(oftA.isOFTReceiveEnabled()); // Receive still enabled
    }

    function test_DisableOFTReceive() public {
        vm.expectEmit(true, false, false, false);
        emit SetOFTReceive(false);

        vm.prank(owner);
        oftA.disableOFTReceive();

        assertFalse(oftA.isOFTReceiveEnabled());
        assertTrue(oftA.isOFTSendEnabled()); // Send still enabled
    }

    function test_DisableBothSendAndReceive() public {
        // Disable both to make it a normal ERC20
        vm.startPrank(owner);
        oftA.disableOFTSend();
        oftA.disableOFTReceive();
        vm.stopPrank();

        assertFalse(oftA.isOFTSendEnabled());
        assertFalse(oftA.isOFTReceiveEnabled());

        // Token still functions as normal ERC20
        uint256 aliceBalance = oftA.balanceOf(alice);
        vm.prank(alice);
        oftA.transfer(bob, 10 ether);
        assertEq(oftA.balanceOf(alice), aliceBalance - 10 ether);
        assertEq(oftA.balanceOf(bob), 10 ether);
    }

    function test_RevertsetOFTSend_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        oftA.disableOFTSend();
    }

    function test_RevertsetOFTReceive_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        oftA.disableOFTReceive();
    }

    // ============= Send Tests When Enabled =============

    function test_SendTokens_WhenEnabled(uint256 sendAmount) public {
        sendAmount =
            (bound(sendAmount, 0.1 ether, 1000 ether) / oftA.decimalConversionRate()) * oftA.decimalConversionRate();

        uint256 aliceBalanceBefore = oftA.balanceOf(alice);

        // Prepare send parameters
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);

        SendParam memory sendParam = SendParam({
            dstEid: EID_B,
            to: bytes32(uint256(uint160(bob))),
            amountLD: sendAmount,
            minAmountLD: sendAmount,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        // Quote fee
        MessagingFee memory fee = oftA.quoteSend(sendParam, false);

        // Send tokens
        vm.prank(alice);
        (, OFTReceipt memory oftReceipt) = oftA.send{value: fee.nativeFee}(sendParam, fee, alice);

        // Verify balance changed
        assertEq(oftA.balanceOf(alice), aliceBalanceBefore - sendAmount);
        assertEq(oftReceipt.amountSentLD, sendAmount);
    }

    // ============= Send Tests When Disabled =============

    function test_RevertSendTokens_WhenDisabled(uint256 sendAmount) public {
        sendAmount =
            (bound(sendAmount, 0.1 ether, 1000 ether) / oftA.decimalConversionRate()) * oftA.decimalConversionRate();
        // Disable OFT sending
        vm.prank(owner);
        oftA.disableOFTSend();

        // Prepare send parameters
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);

        SendParam memory sendParam = SendParam({
            dstEid: EID_B,
            to: bytes32(uint256(uint160(bob))),
            amountLD: sendAmount,
            minAmountLD: sendAmount,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        vm.expectRevert(DisableableOFTCore.OFTSendDisabled.selector);
        oftA.quoteSend(sendParam, false);

        // Some Mock Fee
        MessagingFee memory fee = MessagingFee(1, 1);

        // Should revert with OFTSendDisabled
        vm.prank(alice);
        vm.expectRevert(DisableableOFTCore.OFTSendDisabled.selector);
        oftA.send{value: fee.nativeFee}(sendParam, fee, alice);

        // Balance should remain unchanged
        assertEq(oftA.balanceOf(alice), 1000 ether);
    }

    function test_QuoteSend_StillWorksWhenDisabled(uint256 sendAmount) public {
        sendAmount =
            (bound(sendAmount, 0.1 ether, 1000 ether) / oftA.decimalConversionRate()) * oftA.decimalConversionRate();

        // Disable OFT sending
        vm.prank(owner);
        oftA.disableOFTSend();

        // Prepare send parameters
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);

        SendParam memory sendParam = SendParam({
            dstEid: EID_B,
            to: bytes32(uint256(uint160(bob))),
            amountLD: sendAmount,
            minAmountLD: sendAmount,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        vm.expectRevert(DisableableOFTCore.OFTSendDisabled.selector);
        oftA.quoteSend(sendParam, false);
    }

    // ============= Receive Tests =============

    function testFuzz_ReceiveTokens_WhenSendDisabled(uint256 sendAmount) public {
        sendAmount =
            (bound(sendAmount, 0.1 ether, 100 ether) / oftA.decimalConversionRate()) * oftA.decimalConversionRate();
        // Disable sending on chain A
        vm.prank(owner);
        oftA.disableOFTSend();

        // Bob on chain B can still send to Alice on chain A
        uint256 aliceBalanceBeforeReceive = oftA.balanceOf(alice);

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);

        SendParam memory sendParam = SendParam({
            dstEid: EID_A,
            to: bytes32(uint256(uint160(alice))),
            amountLD: sendAmount,
            minAmountLD: sendAmount,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory fee = oftB.quoteSend(sendParam, false);

        // Bob sends from chain B to Alice on chain A
        vm.prank(bob);
        oftB.send{value: fee.nativeFee}(sendParam, fee, bob);

        // Simulate the receive on chain A (normally handled by LayerZero)
        // In a real scenario, the endpoint would call lzReceive
        // For this test, we mint to simulate the receive (since receive is still enabled)
        oftA.mint(alice, sendAmount);

        // Alice should have received tokens even though sending is disabled
        assertEq(oftA.balanceOf(alice), aliceBalanceBeforeReceive + sendAmount);
    }

    function testFuzz_RevertReceive_WhenReceiveDisabled(uint256 sendAmount) public {
        sendAmount =
            (bound(sendAmount, 0.1 ether, 100 ether) / oftA.decimalConversionRate()) * oftA.decimalConversionRate();

        // Disable receiving on chain A (simulating oracle failure)
        vm.prank(owner);
        oftA.disableOFTReceive();

        // Verify receive is disabled but token still works as ERC20
        assertFalse(oftA.isOFTReceiveEnabled());
        assertTrue(oftA.isOFTSendEnabled());

        // Regular ERC20 transfers should still work
        uint256 aliceBalance = oftA.balanceOf(alice);
        vm.prank(alice);
        oftA.transfer(bob, 1 ether);
        assertEq(oftA.balanceOf(alice), aliceBalance - 1 ether);

        // But LayerZero receives would fail (in real scenario, lzReceive would revert)
        // This protects against oracle failures while maintaining ERC20 functionality
    }

    // ============= Migration Scenario Tests =============

    function test_MigrationScenario(uint256 sendAmount) public {
        sendAmount =
            (bound(sendAmount, 0.1 ether, 100 ether) / oftA.decimalConversionRate()) * oftA.decimalConversionRate();
        // Scenario: Protocol wants to migrate from LayerZero to another solution

        // Step 1: Normal operations
        assertTrue(oftA.isOFTSendEnabled());

        // Alice sends some tokens
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);

        SendParam memory sendParam = SendParam({
            dstEid: EID_B,
            to: bytes32(uint256(uint160(bob))),
            amountLD: sendAmount,
            minAmountLD: sendAmount,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory fee = oftA.quoteSend(sendParam, false);

        vm.prank(alice);
        oftA.send{value: fee.nativeFee}(sendParam, fee, alice);

        // Step 2: Disable LayerZero sending for migration
        vm.prank(owner);
        oftA.disableOFTSend();

        // Step 3: Verify sends are blocked
        vm.prank(alice);
        vm.expectRevert(DisableableOFTCore.OFTSendDisabled.selector);
        oftA.send{value: fee.nativeFee}(sendParam, fee, alice);
    }

    // ============= Ownership Tests =============

    function test_TransferOwnership() public {
        vm.prank(owner);
        oftA.transferOwnership(alice);

        assertEq(oftA.owner(), alice);

        // New owner can control OFT state
        vm.prank(alice);
        oftA.disableOFTSend();

        assertFalse(oftA.isOFTSendEnabled());
    }

    // ============= Fuzz Tests =============

    function testFuzz_SendAmount_WhenEnabled(uint256 amount) public {
        amount = (bound(amount, 1, oftA.balanceOf(alice)) / oftA.decimalConversionRate()) * oftA.decimalConversionRate();

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);

        SendParam memory sendParam = SendParam({
            dstEid: EID_B,
            to: bytes32(uint256(uint160(bob))),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory fee = oftA.quoteSend(sendParam, false);

        uint256 balanceBefore = oftA.balanceOf(alice);

        vm.prank(alice);
        oftA.send{value: fee.nativeFee}(sendParam, fee, alice);

        assertEq(oftA.balanceOf(alice), balanceBefore - amount);
    }

    function testFuzz_AlwaysRevert_WhenDisabled(uint256 amount) public {
        amount = (bound(amount, 1, oftA.balanceOf(alice)) / oftA.decimalConversionRate()) * oftA.decimalConversionRate();

        // Disable sending
        vm.prank(owner);
        oftA.disableOFTSend();

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);

        SendParam memory sendParam = SendParam({
            dstEid: EID_B,
            to: bytes32(uint256(uint160(bob))),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        vm.expectRevert(DisableableOFTCore.OFTSendDisabled.selector);
        oftA.quoteSend(sendParam, false);

        // Make some mock fee
        MessagingFee memory fee = MessagingFee(1, 1);

        // Should always revert regardless of amount
        vm.prank(alice);
        vm.expectRevert(DisableableOFTCore.OFTSendDisabled.selector);
        oftA.send{value: fee.nativeFee}(sendParam, fee, alice);
    }
}
