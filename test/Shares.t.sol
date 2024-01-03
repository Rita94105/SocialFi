// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {SharesProxy} from "../src/SharesProxy.sol";
import {Shares} from "../src/Shares.sol";
import {QQToken} from "../src/QQToken.sol";

contract SharesTest is Test{
    address owner = makeAddr("owner");
    address protocolFeeDestination = makeAddr("protocolFeeDestination");
    address user1 = makeAddr("user1");

    Shares public shares;
    Shares public proxyShare;
    SharesProxy public proxy;
    QQToken public token;
    function setUp() public{
        deal(owner, 100 ether);
        deal(protocolFeeDestination, 100 ether);
        deal(user1, 100 ether);
        vm.startPrank(owner);
        shares = new Shares(owner, "Rita", "RT");
        proxy = new SharesProxy(address(shares), abi.encodeWithSignature("initialize(address,string,string,string,address,address,uint256)", owner, "Rita", "RT", "https://ipfs.io/ipfs/QmXeqeiCJNdnpZsvLLbh3PaPs5nSEpcP2xkhqcrDQhEioQ", owner, protocolFeeDestination, 1600));
        proxyShare = Shares(address(proxy));
        
        token = new QQToken();
        token.mint(owner, 100 ether);

        vm.stopPrank();
    }

    function testMintFirst() public{
        vm.startPrank(owner);
        string memory symbol = proxyShare.symbol();
        string memory name = proxyShare.name();
        string memory baseUri = proxyShare.tokenURI(0);
        uint256 supply = proxyShare.totalSupply();
        uint256 buyprice = proxyShare.getBuyPriceAfterFee();
        console2.log("symbol: %s", symbol);
        console2.log("name: %s", name);
        console2.log("baseUri: %s", baseUri);
        console2.log("supply: %s", supply);
        console2.log("buyprice: %s", buyprice);
        uint price = proxyShare.getBuyPriceAfterFee();
        proxyShare.mintShare();
        require(proxyShare.balanceOf(owner) == 1, "balanceOf should be 1");
        require(proxyShare.totalSupply() == 1, "totalSupply should be 1");
        require(proxyShare.ownerOf(0) == owner, "token 0 should be belong to owner");
        vm.stopPrank();
    }

    function testUserMintSecond() public{
        vm.startPrank(owner);
        proxyShare.mintShare();
        vm.stopPrank();
        vm.startPrank(user1);
        uint256 supply = proxyShare.totalSupply();
        uint256 buyprice = proxyShare.getBuyPriceAfterFee();
        console2.log("supply: %s", supply);
        console2.log("buy1price: %s", buyprice);
        proxyShare.mintShare{value: buyprice}();
        require(proxyShare.balanceOf(user1) == 1, "balanceOf should be 1");
        require(proxyShare.totalSupply() == 2, "totalSupply should be 2");
        require(proxyShare.ownerOf(1) == user1, "token 1 should be belong to user1");
        console2.log("buy2price:%s", proxyShare.getBuyPriceAfterFee());
        vm.stopPrank();
    }

    function testUserBurn() public{
        vm.startPrank(owner);
        proxyShare.mintShare();
        vm.stopPrank();
        vm.startPrank(user1);
        proxyShare.mintShare{value: proxyShare.getBuyPriceAfterFee()}();
        proxyShare.mintShare{value: proxyShare.getBuyPriceAfterFee()}();
        uint beforeBalance = user1.balance;
        uint sellprice = proxyShare.getSellPriceAfterFee();
        proxyShare.burnShare(1);
        require(user1.balance == beforeBalance + sellprice, "user1 balance should be added sellprice");
        vm.stopPrank();
    }

    function testAirDropTokens() public{
        vm.startPrank(owner);
        require(token.balanceOf(owner)>= 100 ether,"Not enough tokens to approve");
        token.approve(address(proxyShare), 100 ether);
        address payable [] memory receivers = new address payable[](1);
        receivers[0] = payable(user1);
        uint[] memory amounts = new uint256[](1);
        amounts[0] = 10 ether;
        proxyShare.multiTransferToken(address(token), receivers, amounts);
        assertEq(token.balanceOf(user1),10 ether, " AirDrop tokens failed");
        assertEq(token.balanceOf(owner),90 ether, " AirDrop tokens failed");
        vm.stopPrank();
    }

    function testAirDropEth() public{
        vm.startPrank(owner);
        address payable[] memory receivers = new address payable[](1);
        receivers[0]= payable(user1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10 ether;
        proxyShare.multiTransferETH{value:10 ether}(receivers, amounts);
        assertEq(user1.balance,110 ether,"AirDrop ETH failed");
        assertEq(owner.balance,90 ether,"AirDrop ETH failed");
        vm.stopPrank();
    }
}