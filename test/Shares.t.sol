// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Shares} from "../src/Shares.sol";
import {QQToken} from "../src/QQToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IUniswapV2Router02 } from "v2-periphery/interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "v2-core/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SharesTest is Test{
    address owner = makeAddr("owner");
    address protocolFeeDestination = makeAddr("protocolFeeDestination");
    address user1 = makeAddr("user1");

    Shares public shares;
    Shares public proxyShare;
    ERC1967Proxy public proxy;
    QQToken public token;

    address public constant MTM=0x6F02055E3541DD74A1aBD8692116c22fFAFaDc5D;
    address public constant TST=0xf67041758D3B6e56D6fDafA5B32038302C3634DA;
    address public constant DAI=0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    function setUp() public{
        vm.createSelectFork("mainnet");
        vm.roll(block.number);
        vm.startPrank(owner);
        shares = new Shares(owner, "Rita", "RT");
        
        token = new QQToken();
        token.mint(owner, 100 ether);
        vm.stopPrank();
    
        deal(owner, 100 ether);
        deal(protocolFeeDestination, 100 ether);
        deal(user1, 100 ether);
    }

    function testMintFirst() public{
        vm.startPrank(owner);
        proxy = new ERC1967Proxy(address(shares),
            abi.encodeWithSignature("initialize(address,string,string,string,address,address,uint256,address,address,uint256)",
             owner, "Rita", "RT", 
             "https://ipfs.io/ipfs/QmXeqeiCJNdnpZsvLLbh3PaPs5nSEpcP2xkhqcrDQhEioQ", 
             owner, protocolFeeDestination, 1600, MTM, TST, 8000));
        proxyShare = Shares(payable(address(proxy)));
        proxyShare.mintShare();
        require(proxyShare.balanceOf(owner) == 1, "balanceOf should be 1");
        require(proxyShare.totalSupply() == 1, "totalSupply should be 1");
        require(proxyShare.ownerOf(0) == owner, "token 0 should be belong to owner");
        vm.stopPrank();
    }

    function testUserMintSecond() public{
        vm.startPrank(owner);
        proxy = new ERC1967Proxy(address(shares),
        abi.encodeWithSignature("initialize(address,string,string,string,address,address,uint256,address,address,uint256)",
        owner, "Rita", "RT", 
        "https://ipfs.io/ipfs/QmXeqeiCJNdnpZsvLLbh3PaPs5nSEpcP2xkhqcrDQhEioQ", 
        owner, protocolFeeDestination, 1600, MTM, TST, 8000));
        proxyShare = Shares(payable(address(proxy)));
        proxyShare.mintShare();
        vm.stopPrank();

        vm.startPrank(user1);
        proxyShare.mintShare{value: proxyShare.getBuyPriceAfterFee()}();
        require(proxyShare.balanceOf(user1) == 1, "balanceOf should be 1");
        require(proxyShare.totalSupply() == 2, "totalSupply should be 2");
        require(proxyShare.ownerOf(1) == user1, "token 1 should be belong to user1");
        vm.stopPrank();
    }

    function testUserBurn() public{
        vm.startPrank(owner);
        proxy = new ERC1967Proxy(address(shares),
        abi.encodeWithSignature("initialize(address,string,string,string,address,address,uint256,address,address,uint256)",
        owner, "Rita", "RT", 
        "https://ipfs.io/ipfs/QmXeqeiCJNdnpZsvLLbh3PaPs5nSEpcP2xkhqcrDQhEioQ", 
        owner, protocolFeeDestination, 1600, MTM, TST, 8000));
        proxyShare = Shares(payable(address(proxy)));
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

    function testSwapExactTokensForTokens() public{
        // for testSwapExactTokensForTokens() and testSwapTokensForExactTokens()
        vm.startPrank(owner);
        proxy = new ERC1967Proxy(address(shares),
            abi.encodeWithSignature("initialize(address,string,string,string,address,address,uint256,address,address,uint256)",
                owner, "Rita", "RT", 
                "https://ipfs.io/ipfs/QmXeqeiCJNdnpZsvLLbh3PaPs5nSEpcP2xkhqcrDQhEioQ", 
                owner, protocolFeeDestination, 1600, MTM, TST, 8000));
        proxyShare = Shares(payable(address(proxy)));
        vm.stopPrank();

        deal(MTM,user1,10 ether);
        vm.startPrank(user1);
        uint256 fee = 5 ether * 8000 / 1e12;
        IERC20(MTM).approve(address(proxyShare), type(uint256).max);
        uint256 amountOut = proxyShare.getAmountOut(5 ether - fee);
        proxyShare.swapExactTokensForTokens(5 ether, 0);
        require(5 ether == IERC20(MTM).balanceOf(user1), "amountOut not equal");
        require(amountOut == IERC20(TST).balanceOf(user1), "amountOut not equal");
        require(fee == IERC20(MTM).balanceOf(address(proxyShare)), "fee not equal");
        vm.stopPrank();
    }

    function testSwapTokensForExactTokens() public{
        // for testSwapExactETHForTokens() and swapETHForExactTokens() 
        vm.startPrank(owner);
        proxy = new ERC1967Proxy(address(shares),
        abi.encodeWithSignature("initialize(address,string,string,string,address,address,uint256,address,address,uint256)",
            owner, "Rita", "RT", 
            "https://ipfs.io/ipfs/QmXeqeiCJNdnpZsvLLbh3PaPs5nSEpcP2xkhqcrDQhEioQ", 
            owner, protocolFeeDestination, 1600, MTM, TST, 8000));
        proxyShare = Shares(payable(address(proxy)));
        vm.stopPrank();

        deal(MTM,user1,10 ether);
        vm.startPrank(user1);
        uint256 amountIn = proxyShare.getAmountIn(5 ether);
        uint256 fee = amountIn * 8000 / 1e12;
        IERC20(MTM).approve(address(proxyShare),type(uint256).max);
        proxyShare.swapTokensForExactTokens(5 ether, amountIn + fee);
        require(5 ether == IERC20(TST).balanceOf(user1), "amountOut not equal");
        require(fee == IERC20(MTM).balanceOf(address(proxyShare)), "fee not equal");
        require(10 ether - amountIn - fee == IERC20(MTM).balanceOf(user1), "amountOut not equal");
        vm.stopPrank(); 
    }

    function testSwapExactETHForTokens() public{
        // for testSwapExactETHForTokens() and swapETHForExactTokens() 
        vm.startPrank(owner);
        proxy = new ERC1967Proxy(address(shares),
        abi.encodeWithSignature("initialize(address,string,string,string,address,address,uint256,address,address,uint256)",
            owner, "Rita", "RT", 
            "https://ipfs.io/ipfs/QmXeqeiCJNdnpZsvLLbh3PaPs5nSEpcP2xkhqcrDQhEioQ", 
            owner, protocolFeeDestination, 1600, WETH, DAI, 8000));
        proxyShare = Shares(payable(address(proxy)));
        vm.stopPrank();

        deal(user1,10 ether);
        vm.startPrank(user1);
        uint256 fee = 5 ether * 8000 / 1e12;
        uint256 amountOut = proxyShare.getAmountOut(5 ether - fee);
        proxyShare.swapExactETHForTokens{value:5 ether}(0);
        require(fee == address(proxyShare).balance, "fee not equal");
        require(5 ether == user1.balance, "Ether balance should be 5 ether");
        require(amountOut == IERC20(DAI).balanceOf(user1), "DAI amountOut not equal");
        vm.stopPrank();
    }

    function testSwapETHForExactTokens() public{
        // for testSwapExactETHForTokens() and swapETHForExactTokens() 
        vm.startPrank(owner);
        proxy = new ERC1967Proxy(address(shares),
            abi.encodeWithSignature("initialize(address,string,string,string,address,address,uint256,address,address,uint256)",
            owner, "Rita", "RT", 
            "https://ipfs.io/ipfs/QmXeqeiCJNdnpZsvLLbh3PaPs5nSEpcP2xkhqcrDQhEioQ", 
            owner, protocolFeeDestination, 1600, WETH, DAI, 8000));
        proxyShare = Shares(payable(address(proxy)));
        vm.stopPrank();

        deal(user1,10 ether);
        vm.startPrank(user1);
        uint256 amountIn = proxyShare.getAmountIn(5 ether);
        uint256 fee = amountIn * 8000 / 1e12;
        proxyShare.swapETHForExactTokens{value:amountIn + fee}(5 ether);
        require(fee == address(proxyShare).balance, "fee not equal");
        require(5 ether == IERC20(DAI).balanceOf(user1), "DAI balance should be 5 ether");
        require(10 ether - amountIn - fee == user1.balance, "user1 Ether balance error");
        vm.stopPrank();
    }

    function testSwapTokensForExactETH() public{
        //for testSwapTokensForExactETH() and testSwapExactTokensForETH()
        vm.startPrank(owner);
        proxy = new ERC1967Proxy(address(shares),
        abi.encodeWithSignature("initialize(address,string,string,string,address,address,uint256,address,address,uint256)",
            owner, "Rita", "RT", 
            "https://ipfs.io/ipfs/QmXeqeiCJNdnpZsvLLbh3PaPs5nSEpcP2xkhqcrDQhEioQ", 
            owner, protocolFeeDestination, 1600, DAI, WETH,  8000));
        proxyShare = Shares(payable(address(proxy)));
        vm.stopPrank();

        deal(DAI,user1,5000 ether);
        vm.startPrank(user1);
        uint256 amountIn = proxyShare.getAmountIn(1 ether);
        uint256 fee = amountIn * 8000 / 1e12;
        IERC20(DAI).approve(address(proxyShare),type(uint256).max);
        proxyShare.swapTokensForExactETH(1 ether);
        require(101 ether == user1.balance, "Ether balance should be 1 ether");
        require(5000 ether - amountIn - fee == IERC20(DAI).balanceOf(user1), "amountOut not equal");
        require(fee == IERC20(DAI).balanceOf(address(proxyShare)), "fee not equal");
        vm.stopPrank();
    }

    function testSwapExactTokensForETH() public{
        //for testSwapTokensForExactETH() and testSwapExactTokensForETH()
        proxy = new ERC1967Proxy(address(shares),
        abi.encodeWithSignature("initialize(address,string,string,string,address,address,uint256,address,address,uint256)",
        owner, "Rita", "RT", 
        "https://ipfs.io/ipfs/QmXeqeiCJNdnpZsvLLbh3PaPs5nSEpcP2xkhqcrDQhEioQ", 
        owner, protocolFeeDestination, 1600, DAI, WETH,  8000));
        proxyShare = Shares(payable(address(proxy)));
        vm.stopPrank();

        deal(DAI,user1,1000 ether);
        vm.startPrank(user1);
        uint256 fee = 500 ether * 8000 / 1e12;
        IERC20(DAI).approve(address(proxyShare), type(uint256).max);
        uint256 amountOut = proxyShare.getAmountOut(500 ether - fee);
        proxyShare.swapExactTokensForETH(500 ether, amountOut*95/100);
        require(100 ether + amountOut == user1.balance, "Ether balance error");
        require(500 ether == IERC20(DAI).balanceOf(user1), "DAI balance not equal");
        require(fee == IERC20(DAI).balanceOf(address(proxyShare)), "fee not equal");
        vm.stopPrank();
    }

    function testSnapShot() public{
        vm.startPrank(owner);
        proxy = new ERC1967Proxy(address(shares),
            abi.encodeWithSignature("initialize(address,string,string,string,address,address,uint256,address,address,uint256)",
            owner, "Rita", "RT", 
            "https://ipfs.io/ipfs/QmXeqeiCJNdnpZsvLLbh3PaPs5nSEpcP2xkhqcrDQhEioQ", 
            owner, protocolFeeDestination, 1600, MTM, TST, 8000));
        proxyShare = Shares(payable(address(proxy)));
        vm.stopPrank();

        deal(MTM,user1,10000 ether);
        vm.startPrank(user1);
        uint256 fee = 900 ether * 8000 / 1e12;
        IERC20(MTM).approve(address(proxyShare), type(uint256).max);
        proxyShare.swapExactTokensForTokens(900 ether, 0);
        assertEq(fee, IERC20(MTM).balanceOf(address(proxyShare)), "fee not equal");
        uint256 snapshot = vm.snapshot();
        vm.warp(12345);
        proxyShare.swapExactTokensForTokens(900 ether, 0);
        vm.revertTo(snapshot);
        assertEq(fee, IERC20(MTM).balanceOf(address(proxyShare)), "fee not equal");
        vm.stopPrank();
    }

    /*function testAirDropEth() public{
        vm.startPrank(owner);
        address payable[] memory receivers = new address payable[](1);
        receivers[0]= payable(user1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10 ether;
        proxyShare.multiTransferETH{value:10 ether}(receivers, amounts);
        assertEq(user1.balance,110 ether,"AirDrop ETH failed");
        assertEq(owner.balance,90 ether,"AirDrop ETH failed");
        vm.stopPrank();
    }*/
}