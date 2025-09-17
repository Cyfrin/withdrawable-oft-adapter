// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {WithdrawableOFTAdapter, Ownable} from "src/WithdrawableOFTAdapter.sol";
import {DisableableOFTCore} from "src/DisableableOFTCore.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {
    SendParam, MessagingFee, MessagingReceipt, OFTReceipt
} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockEndpointV2} from "test/mocks/MockEndpointV2.sol";
import {MockOFT} from "test/mocks/MockOFT.sol";

contract TestableWithdrawableOFTAdapter is WithdrawableOFTAdapter {
    constructor(address _token, address _lzEndpoint, address _delegate, address _owner, uint256 _emergencyWithdrawDelay)
        WithdrawableOFTAdapter(_token, _lzEndpoint, _delegate, _owner, _emergencyWithdrawDelay)
    {}
}

contract WithdrawableOFTAdapterTest is Test {
    using OptionsBuilder for bytes;

    TestableWithdrawableOFTAdapter adapter;
    MockERC20 token;
    MockEndpointV2 endpointA;
    MockEndpointV2 endpointB;
    MockOFT oftB;

    address owner = address(0x1);
    address alice = address(0x2);
    address bob = address(0x3);
    address delegate = address(0x4);

    uint32 constant EID_A = 1;
    uint32 constant EID_B = 2;
    uint256 constant EMERGENCY_DELAY = 7 days;

    event EmergencyWithdrawInitialized(address indexed to, uint256 indexed timestamp);
    event TokensWithdrawn(address indexed to);
    event EmergencyWithdrawCancelled();
    event SetOFTSend(bool indexed isOFTEnabled);
    event SetOFTReceive(bool indexed isOFTReceiveEnabled);

    function setUp() public {
        // Setup endpoints
        endpointA = new MockEndpointV2(EID_A);
        endpointB = new MockEndpointV2(EID_B);

        // Deploy token
        token = new MockERC20();

        // Deploy adapter on chain A
        adapter =
            new TestableWithdrawableOFTAdapter(address(token), address(endpointA), delegate, owner, EMERGENCY_DELAY);

        // Deploy OFT on chain B
        oftB = new MockOFT("OFT B", "OFTB", address(endpointB), owner);

        // Setup peers
        vm.prank(owner);
        adapter.setPeer(EID_B, bytes32(uint256(uint160(address(oftB)))));

        vm.prank(owner);
        oftB.setPeer(EID_A, bytes32(uint256(uint160(address(adapter)))));

        // Fund test accounts
        token.mint(alice, 1000 ether);
        token.mint(address(adapter), 500 ether); // Pre-fund adapter for testing

        vm.deal(alice, 10 ether);
        vm.deal(owner, 10 ether);
    }

    // ============= Emergency Withdrawal Tests =============

    function testFuzz_InitializeEmergencyWithdraw(address recipient) public {
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawInitialized(recipient, block.timestamp);

        vm.prank(owner);
        adapter.initializeEmergencyWithdraw(recipient);

        (uint256 initializedAt, uint256 delay, address to) = adapter.getWithdrawInformation();

        assertEq(initializedAt, block.timestamp);
        assertEq(delay, EMERGENCY_DELAY);
        assertEq(to, recipient);
    }

    function test_RevertInitializeEmergencyWithdraw_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(WithdrawableOFTAdapter.MustNotBeZeroAddress.selector);
        adapter.initializeEmergencyWithdraw(address(0));
    }

    function test_RevertInitializeEmergencyWithdraw_AlreadyInitialized() public {
        // First initialization
        vm.prank(owner);
        adapter.initializeEmergencyWithdraw(alice);

        // Try to initialize again - should revert
        vm.prank(owner);
        vm.expectRevert(WithdrawableOFTAdapter.EmergencyWithdrawAlreadyInitialized.selector);
        adapter.initializeEmergencyWithdraw(bob);
    }

    function test_RevertInitializeEmergencyWithdraw_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        adapter.initializeEmergencyWithdraw(alice);
    }

    function testFuzz_EmergencyWithdraw_Success() public {
        uint256 initialBalance = token.balanceOf(alice);
        uint256 adapterInitialBalance = token.balanceOf(address(adapter));

        // Initialize withdrawal
        vm.prank(owner);
        adapter.initializeEmergencyWithdraw(alice);

        // Warp time to after delay
        vm.warp(block.timestamp + EMERGENCY_DELAY + 1);

        // Execute withdrawal
        vm.expectEmit(true, false, false, true);
        emit TokensWithdrawn(alice);

        vm.prank(owner);
        adapter.emergencyWithdraw();

        // Verify balances
        assertEq(token.balanceOf(alice), initialBalance + adapterInitialBalance);
        assertEq(token.balanceOf(address(adapter)), 0);

        // Verify state is reset
        (uint256 initializedAt,,) = adapter.getWithdrawInformation();
        assertEq(initializedAt, 0);
    }

    function test_RevertEmergencyWithdraw_DelayNotPassed() public {
        // Initialize withdrawal
        vm.prank(owner);
        adapter.initializeEmergencyWithdraw(alice);

        // Try to withdraw before delay
        vm.prank(owner);
        vm.expectRevert(WithdrawableOFTAdapter.EmergencyWithdrawDelayNotPassed.selector);
        adapter.emergencyWithdraw();

        // Even at exact delay time should fail
        vm.warp(block.timestamp + EMERGENCY_DELAY);
        vm.prank(owner);
        vm.expectRevert(WithdrawableOFTAdapter.EmergencyWithdrawDelayNotPassed.selector);
        adapter.emergencyWithdraw();
    }

    function test_RevertEmergencyWithdraw_NotInitialized() public {
        vm.prank(owner);
        vm.expectRevert(WithdrawableOFTAdapter.EmergencyWithdrawDelayNotPassed.selector);
        adapter.emergencyWithdraw();
    }

    function test_RevertEmergencyWithdraw_NotOwner() public {
        // Initialize withdrawal
        vm.prank(owner);
        adapter.initializeEmergencyWithdraw(alice);

        // Warp time to after delay
        vm.warp(block.timestamp + EMERGENCY_DELAY + 1);

        // Try to withdraw as non-owner
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        adapter.emergencyWithdraw();
    }

    // ============= Cancel Emergency Withdrawal Tests =============

    function test_CancelEmergencyWithdraw() public {
        // Initialize withdrawal
        vm.prank(owner);
        adapter.initializeEmergencyWithdraw(alice);

        (uint256 initializedAt,,) = adapter.getWithdrawInformation();
        assertGt(initializedAt, 0);

        // Cancel the withdrawal
        vm.expectEmit(false, false, false, true);
        emit EmergencyWithdrawCancelled();

        vm.prank(owner);
        adapter.cancelEmergencyWithdraw();

        // Verify state is reset
        (initializedAt,,) = adapter.getWithdrawInformation();
        assertEq(initializedAt, 0);
    }

    function test_RevertCancelEmergencyWithdraw_NotInitialized() public {
        vm.prank(owner);
        vm.expectRevert(WithdrawableOFTAdapter.EmergencyWithdrawNotInitialized.selector);
        adapter.cancelEmergencyWithdraw();
    }

    function test_RevertCancelEmergencyWithdraw_NotOwner() public {
        // Initialize withdrawal first
        vm.prank(owner);
        adapter.initializeEmergencyWithdraw(alice);

        // Try to cancel as non-owner
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        adapter.cancelEmergencyWithdraw();
    }

    // ============= DisableableOFTCore Tests =============

    function test_InitialState_OFTEnabled() public view {
        assertTrue(adapter.isOFTSendEnabled());
        assertTrue(adapter.isOFTReceiveEnabled());
    }

    function test_DisableOFTSend() public {
        vm.expectEmit(true, false, false, false);
        emit SetOFTSend(false);

        vm.prank(owner);
        adapter.disableOFTSend();

        assertFalse(adapter.isOFTSendEnabled());
        assertTrue(adapter.isOFTReceiveEnabled());
    }

    function test_DisableOFTReceive() public {
        vm.expectEmit(true, false, false, false);
        emit SetOFTReceive(false);

        vm.prank(owner);
        adapter.disableOFTReceive();

        assertFalse(adapter.isOFTReceiveEnabled());
        assertTrue(adapter.isOFTSendEnabled());
    }

    function test_RevertSetOFTSend_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        adapter.disableOFTSend();
    }

    function test_RevertSetOFTReceive_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        adapter.disableOFTReceive();
    }

    // ============= Cross-chain Transfer Tests =============

    function testFuzz_SendTokens_BeforeEmergencyWithdraw(uint256 sendAmount) public {
        uint256 aliceBalance = token.balanceOf(alice);
        sendAmount = ((bound(sendAmount, 1 ether, aliceBalance)) / adapter.decimalConversionRate())
            * adapter.decimalConversionRate();
        uint256 adapterInitialBalance = token.balanceOf(address(adapter));

        // Approve adapter to spend tokens
        vm.prank(alice);
        token.approve(address(adapter), sendAmount);

        // Prepare send parameters
        bytes memory options = OptionsBuilder.newOptions();

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
        MessagingFee memory fee = adapter.quoteSend(sendParam, false);

        // Send tokens
        vm.prank(alice);
        adapter.send{value: fee.nativeFee}(sendParam, fee, alice);

        // Verify balances
        assertEq(token.balanceOf(alice), aliceBalance - sendAmount);
        assertEq(token.balanceOf(address(adapter)), adapterInitialBalance + sendAmount);
    }

    function testFuzz_RevertSendTokens_WhenDisabled(uint256 sendAmount) public {
        uint256 aliceBalance = token.balanceOf(alice);
        sendAmount = ((bound(sendAmount, 1 ether, aliceBalance)) / adapter.decimalConversionRate())
            * adapter.decimalConversionRate();

        // Disable OFT sending
        vm.prank(owner);
        adapter.disableOFTSend();

        // Approve adapter to spend tokens
        vm.prank(alice);
        token.approve(address(adapter), sendAmount);

        // Prepare send parameters
        bytes memory options = OptionsBuilder.newOptions();

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
        adapter.quoteSend(sendParam, false);

        // Make some mock fee
        MessagingFee memory fee = MessagingFee(1, 1);

        // Should revert with OFTSendDisabled
        vm.prank(alice);
        vm.expectRevert(DisableableOFTCore.OFTSendDisabled.selector);
        adapter.send{value: fee.nativeFee}(sendParam, fee, alice);

        // Balance should remain unchanged
        assertEq(token.balanceOf(alice), aliceBalance);
    }

    function testFuzz_SendTokens_DuringEmergencyGracePeriod(uint256 sendAmount) public {
        uint256 aliceBalance = token.balanceOf(alice);
        sendAmount = ((bound(sendAmount, 1 ether, aliceBalance / 2)) / adapter.decimalConversionRate())
            * adapter.decimalConversionRate();

        // Initialize emergency withdrawal
        vm.prank(owner);
        adapter.initializeEmergencyWithdraw(owner);

        // During grace period, sends should still work
        vm.prank(alice);
        token.approve(address(adapter), sendAmount);

        bytes memory options = OptionsBuilder.newOptions();

        SendParam memory sendParam = SendParam({
            dstEid: EID_B,
            to: bytes32(uint256(uint160(bob))),
            amountLD: sendAmount,
            minAmountLD: sendAmount,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory fee = adapter.quoteSend(sendParam, false);

        // Should work normally during grace period
        vm.prank(alice);
        adapter.send{value: fee.nativeFee}(sendParam, fee, alice);

        assertEq(token.balanceOf(alice), aliceBalance - sendAmount);
    }

    // ============= Ownership Tests =============

    function test_TransferOwnership() public {
        vm.prank(owner);
        adapter.transferOwnership(alice);

        assertEq(adapter.owner(), alice);

        // Now alice can initialize emergency withdrawal
        vm.prank(alice);
        adapter.initializeEmergencyWithdraw(bob);

        (,, address withdrawTo) = adapter.getWithdrawInformation();
        assertEq(withdrawTo, bob);
    }

    // ============= View Function Tests =============

    function test_GetWithdrawInformation() public {
        // Before initialization
        (uint256 initAt, uint256 delay, address to) = adapter.getWithdrawInformation();
        assertEq(initAt, 0);
        assertEq(delay, EMERGENCY_DELAY);
        assertEq(to, address(0));

        // After initialization
        vm.prank(owner);
        adapter.initializeEmergencyWithdraw(alice);

        (initAt, delay, to) = adapter.getWithdrawInformation();
        assertEq(initAt, block.timestamp);
        assertEq(delay, EMERGENCY_DELAY);
        assertEq(to, alice);
    }

    // ============= Combined Migration Scenario Tests =============

    function test_CompleteEmergencyMigrationScenario() public {
        // Scenario: Protocol wants to migrate away from LayerZero

        // Step 1: Normal operations
        assertTrue(adapter.isOFTSendEnabled());
        assertTrue(adapter.isOFTReceiveEnabled());

        // Step 2: Disable sending first (stop new transfers)
        vm.prank(owner);
        adapter.disableOFTSend();
        assertFalse(adapter.isOFTSendEnabled());

        // Step 3: Initialize emergency withdrawal with delay
        uint256 withdrawAmount = token.balanceOf(address(adapter));
        vm.prank(owner);
        adapter.initializeEmergencyWithdraw(owner);

        // Step 4: During grace period, receives still work for in-flight messages
        assertTrue(adapter.isOFTReceiveEnabled());

        // Step 5: Optionally disable receives if oracle issues
        vm.prank(owner);
        adapter.disableOFTReceive();
        assertFalse(adapter.isOFTReceiveEnabled());

        // Token still works as normal ERC20
        vm.prank(alice);
        token.transfer(bob, 10 ether);

        // Step 6: After delay, execute withdrawal
        vm.warp(block.timestamp + EMERGENCY_DELAY + 1);

        uint256 ownerBalanceBefore = token.balanceOf(owner);
        vm.prank(owner);
        adapter.emergencyWithdraw();

        assertEq(token.balanceOf(owner), ownerBalanceBefore + withdrawAmount);
        assertEq(token.balanceOf(address(adapter)), 0);
    }

    function test_EmergencyWithdrawWithDisabledOFT() public {
        // Disable both send and receive (full emergency mode)
        vm.startPrank(owner);
        adapter.disableOFTSend();
        adapter.disableOFTReceive();

        // Initialize and execute emergency withdrawal
        adapter.initializeEmergencyWithdraw(owner);
        vm.stopPrank();

        // Token still functions as ERC20 during delay
        vm.prank(alice);
        token.transfer(bob, 5 ether);

        // After delay, withdraw
        vm.warp(block.timestamp + EMERGENCY_DELAY + 1);
        vm.prank(owner);
        adapter.emergencyWithdraw();

        // Verify OFT is still disabled after withdrawal
        assertFalse(adapter.isOFTSendEnabled());
        assertFalse(adapter.isOFTReceiveEnabled());
    }

    // ============= Fuzz Tests =============

    function testFuzz_EmergencyWithdrawDelay(uint256 delay) public {
        // Test with different delay values (bounded to reasonable range)
        delay = bound(delay, 1 hours, 30 days);

        // Deploy new adapter with custom delay
        TestableWithdrawableOFTAdapter customAdapter =
            new TestableWithdrawableOFTAdapter(address(token), address(endpointA), delegate, owner, delay);

        token.mint(address(customAdapter), 100 ether);

        vm.prank(owner);
        customAdapter.initializeEmergencyWithdraw(alice);

        // Should fail before delay
        vm.warp(block.timestamp + delay - 1);
        vm.prank(owner);
        vm.expectRevert(WithdrawableOFTAdapter.EmergencyWithdrawDelayNotPassed.selector);
        customAdapter.emergencyWithdraw();

        // Should work after delay
        vm.warp(block.timestamp + 2);
        vm.prank(owner);
        customAdapter.emergencyWithdraw();
    }
}
