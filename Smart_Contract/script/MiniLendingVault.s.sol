// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MiniLendingVault, IERC20Vault} from "../src/MiniLendingVault.sol";

contract CounterScript is Script {
    MiniLendingVault public vault;

    function setUp() public {}

    function run() public {
        address lendTokenAddress = vm.envAddress("LEND_TOKEN");
        address collateralTokenAddress = vm.envAddress("COLLATERAL_TOKEN");
        uint256 initialPrice = vm.envUint("INITIAL_COLLATERAL_PRICE");

        vm.startBroadcast();

        vault = new MiniLendingVault(
            IERC20Vault(lendTokenAddress),
            IERC20Vault(collateralTokenAddress),
            initialPrice
        );

        vm.stopBroadcast();
    }
}
