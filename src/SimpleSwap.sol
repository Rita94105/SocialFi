// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import { IUniswapV2Router02 } from "v2-periphery/interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "v2-core/interfaces/IUniswapV2Pair.sol";

contract SimpleSwap is Context, Initializable, ReentrancyGuard{
    address private constant _ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;
    uint256 private constant _FEE_MOLECULAR = 1e12;

    IUniswapV2Router02 public constant UNISWAP_V2_ROUTER =
    IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Factory public constant UNISWAP_V2_FACTORY =
    IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    address public owner;
    address public srcToken;
    address public targetToken;
    address public feeReceiver;
    uint256 public feeRate; // 8000

    event Swap(
        address indexed _sender,
        string _swapType,
        address _tokenAddr,
        address _targetAddr,
        uint256 _tokenAmount,
        uint256 _returnAmount,
        uint256 _fee
    );

    receive () external payable {}

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner is allowed");
        _;
    }

    function initialize(address _owner,address _srcToken,address _targetToken,address _feeReceiver, uint256 _feeRate) external initializer {
        owner = _owner;
        srcToken = _srcToken;
        targetToken = _targetToken;
        feeRate = _feeRate;
        feeReceiver = _feeReceiver;
    } 

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin
    ) external payable returns(uint256 _returnAmount) {
        uint256 fee = amountIn * feeRate / _FEE_MOLECULAR;
        uint256 swapAmount = amountIn- fee;

        IERC20(srcToken).transferFrom(msg.sender, address(this), amountIn);
        IERC20(srcToken).transfer(feeReceiver, fee);

        IERC20(srcToken).approve(address(UNISWAP_V2_ROUTER), swapAmount);
        address[] memory path = new address[](2);
        path[0]=srcToken;
        path[1]=targetToken;
        require(IERC20(srcToken).balanceOf(address(this)) >= swapAmount, "Insufficient contract balance");
        uint256[] memory returnAmount = UNISWAP_V2_ROUTER.swapExactTokensForTokens(
            swapAmount,
            amountOutMin,
            path,
            msg.sender,
            block.timestamp + 10
        );

        emit Swap(msg.sender, "swapExactTokensForTokens", srcToken, targetToken, amountIn, amountOutMin, fee);

        return returnAmount[1];
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax
    ) external payable returns(uint256 _returnAmount) {
        uint256 amountIn = getAmountIn(amountOut);
        require(amountIn <= amountInMax, "amountIn is larger than amountInMax");
        uint256 fee = amountIn * feeRate / _FEE_MOLECULAR;
        uint256 totalAmount = amountIn+fee;

        IERC20(srcToken).transferFrom(msg.sender, address(this), totalAmount);
        IERC20(srcToken).transfer(feeReceiver, fee);

        IERC20(srcToken).approve(address(UNISWAP_V2_ROUTER), amountIn);
        address[] memory path = new address[](2);
        path[0]=srcToken;
        path[1]=targetToken;
        require(IERC20(srcToken).balanceOf(address(this)) >= amountIn, "Insufficient contract balance");
        uint256[] memory returnAmount = UNISWAP_V2_ROUTER.swapTokensForExactTokens(
            amountOut,
            amountIn,
            path,
            msg.sender,
            block.timestamp + 10
        );

        emit Swap(msg.sender, "swapTokensForExactTokens", srcToken, targetToken, totalAmount, amountOut, fee);

        return returnAmount[0];
    }

    function swapExactETHForTokens(
        uint256 amountOutMin
    ) external payable returns(uint256 _returnAmount) {
        uint256 amountIn = msg.value;
        uint256 fee = amountIn * feeRate / _FEE_MOLECULAR;
        uint256 swapAmount = amountIn - fee;

        payable(feeReceiver).transfer(fee);

        IERC20(srcToken).approve(address(UNISWAP_V2_ROUTER), swapAmount);
        address[] memory path = new address[](2);
        path[0]=srcToken;
        path[1]=targetToken;
        require(address(this).balance >= swapAmount, "Insufficient contract balance");
        uint256[] memory returnAmount = UNISWAP_V2_ROUTER.swapExactETHForTokens{value: swapAmount}(
            amountOutMin,
            path,
            msg.sender,
            block.timestamp + 10
        );

        emit Swap(msg.sender, "swapExactETHForTokens", srcToken, targetToken, amountIn, amountOutMin, fee);

        return returnAmount[1];
    }

    function swapETHForExactTokens(
        uint256 amountOut
    ) external payable returns(uint256 _returnAmount) {
        uint256 amountIn = getAmountIn(amountOut);
        uint256 fee = amountIn * feeRate / _FEE_MOLECULAR;
        uint256 totalAmount = amountIn+fee;
        require(msg.value >= totalAmount, "Insufficient ETH balance");
        payable(feeReceiver).transfer(fee);
        IERC20(srcToken).approve(address(UNISWAP_V2_ROUTER), amountIn);
        address[] memory path = new address[](2);
        path[0]=srcToken;
        path[1]=targetToken;
        require(address(this).balance >= amountIn, "Insufficient contract balance");
        uint256[] memory returnAmount = UNISWAP_V2_ROUTER.swapETHForExactTokens{value: amountIn}(
            amountOut,
            path,
            msg.sender,
            block.timestamp + 10
        );
        emit Swap(msg.sender, "swapETHForExactTokens", srcToken, targetToken, totalAmount, amountOut, fee);
        return returnAmount[0];
    }

    function swapTokensForExactETH(
        uint256 amountOut
    ) external payable returns(uint256 _returnAmount) {
        uint256 amountIn = getAmountIn(amountOut);
        uint256 fee = amountIn * feeRate / _FEE_MOLECULAR;
        uint256 totalAmount = amountIn+fee;

        IERC20(srcToken).transferFrom(msg.sender, address(this), totalAmount);
        IERC20(srcToken).transfer(feeReceiver, fee);

        IERC20(srcToken).approve(address(UNISWAP_V2_ROUTER), amountIn);
        address[] memory path = new address[](2);
        path[0]=srcToken;
        path[1]=targetToken;
        require(IERC20(srcToken).balanceOf(address(this)) >= amountIn, "Insufficient contract balance");
        uint256[] memory returnAmount = UNISWAP_V2_ROUTER.swapTokensForExactETH(
            amountOut,
            amountIn,
            path,
            msg.sender,
            block.timestamp + 10
        );

        emit Swap(msg.sender, "swapTokensForExactETH", srcToken, targetToken, totalAmount, amountOut, fee);

        return returnAmount[0];
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin
    ) external payable returns(uint256 _returnAmount) {
        uint256 fee = amountIn * feeRate / _FEE_MOLECULAR;
        uint256 swapAmount = amountIn- fee;
        require(swapAmount >= amountOutMin, "amountOutMin is larger than swapAmount");

        IERC20(srcToken).transferFrom(msg.sender, address(this), amountIn);
        IERC20(srcToken).transfer(feeReceiver, fee);

        IERC20(srcToken).approve(address(UNISWAP_V2_ROUTER), swapAmount);
        address[] memory path = new address[](2);
        path[0]=srcToken;
        path[1]=targetToken;
        require(IERC20(srcToken).balanceOf(address(this)) >= swapAmount, "Insufficient contract balance");
        uint256[] memory returnAmount = UNISWAP_V2_ROUTER.swapExactTokensForETH(
            swapAmount,
            amountOutMin,
            path,
            msg.sender,
            block.timestamp + 10
        );

        emit Swap(msg.sender, "swapExactTokensForETH", srcToken, targetToken, amountIn, amountOutMin, fee);

        return returnAmount[1];
    }

    function getAmountOut(uint256 amountIn) public view returns (uint256) {
        address pair = IUniswapV2Factory(UNISWAP_V2_FACTORY).getPair(srcToken, targetToken);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        uint256 amountOut;
        if(srcToken < targetToken){
            amountOut = UNISWAP_V2_ROUTER.getAmountOut(amountIn, reserve0, reserve1);
        } else{
            amountOut = UNISWAP_V2_ROUTER.getAmountOut(amountIn, reserve1, reserve0);
        }
        return amountOut;
    }

    function getAmountIn(uint256 amountOut) public view returns (uint256) {
        address pair = IUniswapV2Factory(UNISWAP_V2_FACTORY).getPair(srcToken, targetToken);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        uint256 amountIn;
        if(srcToken < targetToken){
            amountIn = UNISWAP_V2_ROUTER.getAmountIn(amountOut, reserve0, reserve1);
        } else{
            amountIn = UNISWAP_V2_ROUTER.getAmountIn(amountOut, reserve1, reserve0);
        }
        return amountIn;
    }

    function getTotalAmount(uint256 amountIn) public view returns (uint256) {
        uint256 fee = amountIn * feeRate / _FEE_MOLECULAR;
        uint256 totalAmount = amountIn+fee;
        return totalAmount;
    }

    // ========= Admin functions =========
    function rescueFunds(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(payable(msg.sender), amount);
    }

    function setOwner(address _owner) external onlyOwner {
        require(_owner != address(0), "Owner can't be zero address");
        owner = _owner;
    }

    function setFeeReceiver(address _receiver) external onlyOwner {
        require(_receiver != address(0), "fee receiver can't be zero address");
        feeReceiver = _receiver;
    }

    function setFee(uint256 _feeRate) external onlyOwner {
        feeRate = _feeRate;
    }

    function GetInitializeData(address _owner,address _srcToken,address _targetToken,address _feeReceiver, uint256 _feeRate) public pure returns(bytes memory){
        return abi.encodeWithSignature("initialize(address,address,address,address,uint256)", _owner,_srcToken,_targetToken,_feeReceiver,_feeRate);
    }
}