// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {SimpleSwap} from "../src/SimpleSwap.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Router02 } from "v2-periphery/interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "v2-core/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SimpleSwapTest is Test{
    address owner = makeAddr("owner");
    address feeReceiver = makeAddr("feeReceiver");
    address user1 = makeAddr("user1");

    SimpleSwap public swap;
    SimpleSwap public proxySwap;
    ERC1967Proxy public proxy;
    address public constant MTM=0x6F02055E3541DD74A1aBD8692116c22fFAFaDc5D;
    address public constant TST=0xf67041758D3B6e56D6fDafA5B32038302C3634DA;
    address public constant DAI=0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    
    function setUp() public{
        vm.createSelectFork("mainnet");
        vm.roll(block.number);
        swap = new SimpleSwap();
    }

    function testSwapExactTokensForTokens() public{
        // for testSwapExactTokensForTokens() and testSwapTokensForExactTokens()
        proxy = new ERC1967Proxy(payable(address(swap)), abi.encodeWithSignature("initialize(address,address,address,address,uint256)", owner, MTM, TST, feeReceiver, 8000));
        proxySwap = SimpleSwap(payable(address(proxy)));
        deal(MTM,user1,10 ether);
        vm.startPrank(user1);
        uint256 fee = 5 ether * 8000 / 1e12;
        IERC20(MTM).approve(address(proxySwap), 10 ether);
        uint256 amountOut = proxySwap.getAmountOut(5 ether - fee);
        proxySwap.swapExactTokensForTokens(5 ether, 0);
        require(5 ether == IERC20(MTM).balanceOf(user1), "amountOut not equal");
        require(amountOut == IERC20(TST).balanceOf(user1), "amountOut not equal");
        require(fee == IERC20(MTM).balanceOf(feeReceiver), "fee not equal");
        vm.stopPrank();
    }

    function testSwapTokensForExactTokens() public{
        // for testSwapExactTokensForTokens() and testSwapTokensForExactTokens()
        proxy = new ERC1967Proxy(payable(address(swap)), abi.encodeWithSignature("initialize(address,address,address,address,uint256)", owner, MTM, TST, feeReceiver,8000));
        proxySwap = SimpleSwap(payable(address(proxy)));
        deal(MTM,user1,10 ether);
        vm.startPrank(user1);
        uint256 amountIn = proxySwap.getAmountIn(5 ether);
        uint256 fee = amountIn * 8000 / 1e12;
        require(IERC20(MTM).balanceOf(user1) >= amountIn + fee, "balance not enough");
        IERC20(MTM).approve(address(proxySwap), 10 ether);
        proxySwap.swapTokensForExactTokens(5 ether, amountIn + fee);
        require(5 ether == IERC20(TST).balanceOf(user1), "amountOut not equal");
        require(fee == IERC20(MTM).balanceOf(feeReceiver), "fee not equal");
        require(10 ether - amountIn - fee == IERC20(MTM).balanceOf(user1), "amountOut not equal");
        vm.stopPrank();
    }

    function testSwapExactETHForTokens() public{
        // for testSwapExactETHForTokens() and swapETHForExactTokens() 
        proxy = new ERC1967Proxy(payable(address(swap)), abi.encodeWithSignature("initialize(address,address,address,address,uint256)", owner, WETH, DAI, feeReceiver, 8000));
        proxySwap = SimpleSwap(payable(address(proxy)));
        deal(user1,10 ether);
        vm.startPrank(user1);
        uint256 fee = 5 ether * 8000 / 1e12;
        uint256 amountOut = proxySwap.getAmountOut(5 ether - fee);
        proxySwap.swapExactETHForTokens{value:5 ether}(0);
        require(fee == feeReceiver.balance, "fee not equal");
        require(5 ether == user1.balance, "Ether balance should be 5 ether");
        require(amountOut == IERC20(DAI).balanceOf(user1), "DAI amountOut not equal");
        vm.stopPrank();
    }

    function testSwapETHForExactTokens() public{
        // for testSwapExactETHForTokens() and swapETHForExactTokens() 
        proxy = new ERC1967Proxy(payable(address(swap)), abi.encodeWithSignature("initialize(address,address,address,address,uint256)", owner, WETH, DAI, feeReceiver,8000));
        proxySwap = SimpleSwap(payable(address(proxy)));
        deal(user1,10 ether);
        vm.startPrank(user1);
        uint256 amountIn = proxySwap.getAmountIn(5 ether);
        uint256 fee = amountIn * 8000 / 1e12;
        require(user1.balance >= amountIn + fee, "balance not enough");
        proxySwap.swapETHForExactTokens{value:amountIn + fee}(5 ether);
        require(fee == feeReceiver.balance, "fee not equal");
        require(5 ether == IERC20(DAI).balanceOf(user1), "DAI balance should be 5 ether");
        require(10 ether - amountIn - fee == user1.balance, "user1 Ether balance error");
        vm.stopPrank();
    }

    function testSwapTokensForExactETH() public{
        //for testSwapTokensForExactETH() and testSwapExactTokensForETH()
        proxy = new ERC1967Proxy(payable(address(swap)), abi.encodeWithSignature("initialize(address,address,address,address,uint256)", owner, DAI, WETH, feeReceiver, 8000));
        proxySwap = SimpleSwap(payable(address(proxy)));
        deal(DAI,user1,5000 ether);
        vm.startPrank(user1);
        uint256 amountIn = proxySwap.getAmountIn(1 ether);
        uint256 fee = amountIn * 8000 / 1e12;
        require(IERC20(DAI).balanceOf(user1) >= amountIn + fee, "balance not enough");
        IERC20(DAI).approve(address(proxySwap), 5000 ether);
        proxySwap.swapTokensForExactETH(1 ether);
        require(1 ether == user1.balance, "Ether balance should be 1 ether");
        require(5000 ether - amountIn - fee == IERC20(DAI).balanceOf(user1), "amountOut not equal");
        require(fee == IERC20(DAI).balanceOf(feeReceiver), "fee not equal");
        vm.stopPrank();
    }

    function testSwapExactTokensForETH() public{
        //for testSwapTokensForExactETH() and testSwapExactTokensForETH()
        proxy = new ERC1967Proxy(payable(address(swap)), abi.encodeWithSignature("initialize(address,address,address,address,uint256)", owner, DAI, WETH, feeReceiver, 8000));
        proxySwap = SimpleSwap(payable(address(proxy)));
        deal(DAI,user1,1000 ether);
        vm.startPrank(user1);
        uint256 fee = 500 ether * 8000 / 1e12;
        IERC20(DAI).approve(address(proxySwap), 500 ether);
        uint256 amountOut = proxySwap.getAmountOut(500 ether - fee);
        proxySwap.swapExactTokensForETH(500 ether, amountOut*95/100);
        require(amountOut == user1.balance, "Ether balance error");
        require(500 ether == IERC20(DAI).balanceOf(user1), "DAI balance not equal");
        require(fee == IERC20(DAI).balanceOf(feeReceiver), "fee not equal");
        vm.stopPrank();
    }
}