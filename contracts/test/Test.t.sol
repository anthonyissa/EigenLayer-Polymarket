// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "../src/HelloWorldServiceManagerWithoutEigen.sol";

contract HelloWorldServiceManagerTest is Test {
    HelloWorldServiceManagerWithoutEigen public helloWorldServiceManager;

    function setUp() public {
        helloWorldServiceManager = new HelloWorldServiceManagerWithoutEigen();
    }

    function testCreateNewBet() public {
        helloWorldServiceManager.createNewBet("Test", block.timestamp + 1 minutes);
        assertEq(helloWorldServiceManager.latestBetNum(), 1);
    }
}

