// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MiniLendingVault, IERC20Vault} from "../src/MiniLendingVault.sol";

contract MockERC20 {
    string public name;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory name_) {
        name = name_;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 approved = allowance[from][msg.sender];
        if (approved != type(uint256).max) allowance[from][msg.sender] = approved - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MiniLendingVaultTest is Test {
    uint256 private constant WAD = 1e18;
    address private constant LENDER = address(0x1);
    address private constant BORROWER = address(0x2);
    address private constant HELPER = address(0x3);

    MockERC20 private lend;
    MockERC20 private collateralToken;
    MiniLendingVault private vault;

    function setUp() public {
        lend = new MockERC20("Lend");
        collateralToken = new MockERC20("Collateral");
        vault = new MiniLendingVault(IERC20Vault(address(lend)), IERC20Vault(address(collateralToken)), WAD);

        lend.mint(LENDER, 10_000 * WAD);
        lend.mint(BORROWER, 10_000 * WAD);
        collateralToken.mint(BORROWER, 10_000 * WAD);
        collateralToken.mint(HELPER, 10_000 * WAD);

        vm.prank(LENDER);
        lend.approve(address(vault), type(uint256).max);
        vm.prank(BORROWER);
        lend.approve(address(vault), type(uint256).max);
        vm.prank(BORROWER);
        collateralToken.approve(address(vault), type(uint256).max);
        vm.prank(HELPER);
        collateralToken.approve(address(vault), type(uint256).max);

        vm.prank(LENDER);
        vault.deposit(1_000 * WAD);
    }

    function testLenderDepositAndWithdraw() public {
        assertEq(vault.shares(LENDER), 1_000 * WAD);
        vm.prank(LENDER);
        uint256 assets = vault.withdraw(250 * WAD);
        assertEq(assets, 250 * WAD);
        assertEq(vault.totalSupplied(), 750 * WAD);
        assertEq(vault.totalShares(), 750 * WAD);
    }

    function testBorrowWithinAndAboveCollateralLimit() public {
        _depositCollateral(BORROWER, 150 * WAD);
        vm.prank(BORROWER);
        vault.borrow(100 * WAD);
        assertEq(vault.healthFactor(BORROWER), WAD);

        vm.prank(BORROWER);
        vm.expectRevert(MiniLendingVault.UnhealthyPosition.selector);
        vault.borrow(1);
    }

    function testWithdrawBlockedWhenFundsAreLentOut() public {
        _depositCollateral(BORROWER, 1_200 * WAD);
        vm.prank(BORROWER);
        vault.borrow(800 * WAD);

        vm.prank(LENDER);
        vm.expectRevert(MiniLendingVault.InsufficientLiquidity.selector);
        vault.withdraw(1_000 * WAD);
    }

    function testRepayThenWithdrawCollateral() public {
        _depositCollateral(BORROWER, 150 * WAD);
        vm.prank(BORROWER);
        vault.borrow(100 * WAD);
        vm.prank(BORROWER);
        vault.repay(100 * WAD);

        vm.prank(BORROWER);
        vault.withdrawCollateral(150 * WAD);
        assertEq(vault.collateral(BORROWER), 0);
        assertEq(vault.debt(BORROWER), 0);
    }

    function testRepayIsCappedAtOutstandingDebt() public {
        _depositCollateral(BORROWER, 150 * WAD);
        vm.prank(BORROWER);
        vault.borrow(100 * WAD);
        uint256 balanceBeforeRepay = lend.balanceOf(BORROWER);

        vm.prank(BORROWER);
        uint256 repaid = vault.repay(150 * WAD);

        assertEq(repaid, 100 * WAD);
        assertEq(lend.balanceOf(BORROWER), balanceBeforeRepay - 100 * WAD);
        assertEq(vault.debt(BORROWER), 0);
    }

    function testDonationDoesNotSkewSharePrice() public {
        lend.mint(address(vault), 10_000 * WAD);
        lend.mint(HELPER, 100 * WAD);
        vm.prank(HELPER);
        lend.approve(address(vault), type(uint256).max);

        vm.prank(HELPER);
        uint256 minted = vault.deposit(100 * WAD);
        assertEq(minted, 100 * WAD);
        assertEq(vault.totalSupplied(), 1_100 * WAD);

        vm.prank(HELPER);
        assertEq(vault.withdraw(minted), 100 * WAD);
    }

    function testPriceDropShortfallAndThirdPartyTopUp() public {
        _preparePriceDropPosition();
        vault.setCollateralPrice(3 * WAD / 4);

        assertLt(vault.healthFactor(BORROWER), WAD);
        uint256 shortfall = vault.collateralShortfall(BORROWER);
        assertEq(shortfall, 100 * WAD);

        vm.prank(HELPER);
        vault.topUpToHealthy(BORROWER);
        assertEq(vault.collateral(BORROWER), 400 * WAD);
        assertEq(vault.healthFactor(BORROWER), WAD);
    }

    function testShortfallMinusOneIsNotEnough() public {
        _preparePriceDropPosition();
        vault.setCollateralPrice(3 * WAD / 4);
        uint256 shortfall = vault.collateralShortfall(BORROWER);

        vm.prank(HELPER);
        vault.topUpCollateral(BORROWER, shortfall - 1);
        assertLt(vault.healthFactor(BORROWER), WAD);
    }

    function testCollateralShortfallRoundsUp() public {
        _preparePriceDropPositionWith150Collateral();
        vault.setCollateralPrice(9 * WAD / 10);

        uint256 shortfall = vault.collateralShortfall(BORROWER);
        assertEq(shortfall, 16_666_666_666_666_666_667);
        assertGe((vault.collateral(BORROWER) + shortfall) * vault.collateralPrice(), vault.debt(BORROWER) * 1.5e18);
        assertLt((vault.collateral(BORROWER) + shortfall - 1) * vault.collateralPrice(), vault.debt(BORROWER) * 1.5e18);
    }

    function testTopUpToHealthyRevertsIfAlreadyHealthy() public {
        vm.prank(HELPER);
        vm.expectRevert(MiniLendingVault.NothingToTopUp.selector);
        vault.topUpToHealthy(BORROWER);
    }

    function testHelperCannotWithdrawBorrowersCollateral() public {
        _preparePriceDropPosition();
        vault.setCollateralPrice(3 * WAD / 4);
        vm.prank(HELPER);
        vault.topUpToHealthy(BORROWER);

        vm.prank(HELPER);
        vm.expectRevert(MiniLendingVault.InsufficientCollateral.selector);
        vault.withdrawCollateral(1);
    }

    function testBorrowerCanWithdrawToppedUpCollateralAfterRepaying() public {
        _preparePriceDropPosition();
        vault.setCollateralPrice(3 * WAD / 4);
        vm.prank(HELPER);
        vault.topUpToHealthy(BORROWER);

        vm.prank(BORROWER);
        vault.repay(200 * WAD);
        vm.prank(BORROWER);
        vault.withdrawCollateral(400 * WAD);
        assertEq(vault.collateral(BORROWER), 0);
    }

    function testUnhealthyBorrowerCannotBorrowOrWithdrawCollateral() public {
        _preparePriceDropPosition();
        vault.setCollateralPrice(3 * WAD / 4);

        vm.prank(BORROWER);
        vm.expectRevert(MiniLendingVault.UnhealthyPosition.selector);
        vault.borrow(1);
        vm.prank(BORROWER);
        vm.expectRevert(MiniLendingVault.UnhealthyPosition.selector);
        vault.withdrawCollateral(1);
    }

    function testOnlyOwnerCanSetNonzeroPrice() public {
        vm.prank(HELPER);
        vm.expectRevert(MiniLendingVault.NotOwner.selector);
        vault.setCollateralPrice(2 * WAD);

        vm.expectRevert(MiniLendingVault.ZeroPrice.selector);
        vault.setCollateralPrice(0);
    }

    function testConstructorRejectsZeroPrice() public {
        vm.expectRevert(MiniLendingVault.ZeroPrice.selector);
        new MiniLendingVault(IERC20Vault(address(lend)), IERC20Vault(address(collateralToken)), 0);
    }

    function testZeroAmountsRevert() public {
        vm.prank(LENDER);
        vm.expectRevert(MiniLendingVault.ZeroAmount.selector);
        vault.deposit(0);
        vm.prank(LENDER);
        vm.expectRevert(MiniLendingVault.ZeroAmount.selector);
        vault.withdraw(0);
        vm.prank(BORROWER);
        vm.expectRevert(MiniLendingVault.ZeroAmount.selector);
        vault.depositCollateral(0);
        vm.prank(BORROWER);
        vm.expectRevert(MiniLendingVault.ZeroAmount.selector);
        vault.withdrawCollateral(0);
        vm.prank(BORROWER);
        vm.expectRevert(MiniLendingVault.ZeroAmount.selector);
        vault.borrow(0);
        vm.prank(BORROWER);
        vm.expectRevert(MiniLendingVault.ZeroAmount.selector);
        vault.repay(0);
        vm.prank(HELPER);
        vm.expectRevert(MiniLendingVault.ZeroAmount.selector);
        vault.topUpCollateral(BORROWER, 0);
    }

    function testFuzzTopUpToHealthyRestoresHealth(uint256 droppedPrice) public {
        _preparePriceDropPositionWith150Collateral();
        droppedPrice = bound(droppedPrice, 1, WAD - 1);
        vault.setCollateralPrice(droppedPrice);
        collateralToken.mint(HELPER, vault.collateralShortfall(BORROWER));

        vm.prank(HELPER);
        vault.topUpToHealthy(BORROWER);
        assertGe(vault.healthFactor(BORROWER), WAD);
    }

    function testFuzzDepositAndWithdrawPreserveShareAccounting(uint256 depositAmount, uint256 sharesToWithdraw) public {
        depositAmount = bound(depositAmount, 1, 10_000 * WAD);
        lend.mint(HELPER, depositAmount);
        vm.prank(HELPER);
        lend.approve(address(vault), type(uint256).max);

        uint256 suppliedBefore = vault.totalSupplied();
        uint256 sharesBefore = vault.totalShares();
        vm.prank(HELPER);
        uint256 mintedShares = vault.deposit(depositAmount);

        assertEq(mintedShares, depositAmount);
        assertEq(vault.totalSupplied(), suppliedBefore + depositAmount);
        assertEq(vault.totalShares(), sharesBefore + mintedShares);

        sharesToWithdraw = bound(sharesToWithdraw, 1, mintedShares);
        uint256 helperBalanceBefore = lend.balanceOf(HELPER);
        vm.prank(HELPER);
        uint256 withdrawnAssets = vault.withdraw(sharesToWithdraw);

        assertEq(withdrawnAssets, sharesToWithdraw);
        assertEq(lend.balanceOf(HELPER), helperBalanceBefore + withdrawnAssets);
        assertEq(vault.totalSupplied(), suppliedBefore + depositAmount - withdrawnAssets);
        assertEq(vault.totalShares(), sharesBefore + mintedShares - sharesToWithdraw);
    }

    function testFuzzBorrowAndRepayStayWithinCollateralAndLiquidity(
        uint256 collateralAmount,
        uint256 requestedBorrow,
        uint256 requestedRepay
    ) public {
        collateralAmount = bound(collateralAmount, 2 * WAD, 10_000 * WAD);
        uint256 collateralLimit = collateralAmount * WAD / vault.COLLATERAL_FACTOR();
        uint256 borrowLimit =
            collateralLimit < vault.availableLiquidity() ? collateralLimit : vault.availableLiquidity();
        requestedBorrow = bound(requestedBorrow, 1, borrowLimit);

        _depositCollateral(BORROWER, collateralAmount);
        vm.prank(BORROWER);
        vault.borrow(requestedBorrow);

        assertEq(vault.debt(BORROWER), requestedBorrow);
        assertEq(vault.totalBorrowed(), requestedBorrow);
        assertLe(vault.totalBorrowed(), vault.totalSupplied());
        assertGe(vault.healthFactor(BORROWER), WAD);

        requestedRepay = bound(requestedRepay, 1, requestedBorrow * 2);
        uint256 expectedRepay = requestedRepay < requestedBorrow ? requestedRepay : requestedBorrow;
        vm.prank(BORROWER);
        uint256 repaid = vault.repay(requestedRepay);

        assertEq(repaid, expectedRepay);
        assertEq(vault.debt(BORROWER), requestedBorrow - expectedRepay);
        assertEq(vault.totalBorrowed(), requestedBorrow - expectedRepay);
        assertGe(vault.healthFactor(BORROWER), WAD);
    }

    function testFuzzCollateralShortfallUsesCeilingRounding(uint256 price) public {
        _preparePriceDropPositionWith150Collateral();
        price = bound(price, 1, 2 * WAD);
        vault.setCollateralPrice(price);

        uint256 requiredCollateral = (vault.debt(BORROWER) * vault.COLLATERAL_FACTOR() - 1) / price + 1;
        uint256 currentCollateral = vault.collateral(BORROWER);
        uint256 expectedShortfall = requiredCollateral > currentCollateral ? requiredCollateral - currentCollateral : 0;
        uint256 shortfall = vault.collateralShortfall(BORROWER);
        assertEq(shortfall, expectedShortfall);

        if (shortfall > 0) {
            collateralToken.mint(HELPER, shortfall);
            vm.prank(HELPER);
            vault.topUpToHealthy(BORROWER);
            assertGe(vault.healthFactor(BORROWER), WAD);
        } else {
            assertGe(vault.healthFactor(BORROWER), WAD);
        }
    }

    function _preparePriceDropPosition() private {
        _depositCollateral(BORROWER, 300 * WAD);
        vm.prank(BORROWER);
        vault.borrow(200 * WAD);
    }

    function _preparePriceDropPositionWith150Collateral() private {
        _depositCollateral(BORROWER, 150 * WAD);
        vm.prank(BORROWER);
        vault.borrow(100 * WAD);
    }

    function _depositCollateral(address borrower, uint256 amount) private {
        vm.prank(borrower);
        vault.depositCollateral(amount);
    }
}
