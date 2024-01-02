// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {QQToken} from "../src/QQToken.sol";

contract QQTokenTest is Test{
    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");

    QQToken public token;
    function setUp() public{
        vm.startPrank(owner);
        token = new QQToken();
        console2.log("token name:", token.name());
        console2.log("token symbol:", token.symbol());
        token.mint(owner, 100 ether);
        vm.stopPrank();
    }

    function testTransfer() public{
        vm.startPrank(owner);
        token.transfer(user1, 10 ether);
        require(token.balanceOf(owner) == 90 ether, "balanceOf should be 90 ether");
        require(token.balanceOf(user1) == 10 ether, "balanceOf should be 10 ether");
        vm.stopPrank();
    }

    function testBurn() public{
        vm.startPrank(owner);
        console2.log("owner balance:", token.balanceOf(owner));
        token.burn(owner, 10e18);
        require(token.balanceOf(owner) == 90 ether, "balanceOf should be 90 ether");
        vm.stopPrank();
    }
}