// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../src/AirDrop.sol";
import { IUniswapV2Router02 } from "v2-periphery/interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "v2-core/interfaces/IUniswapV2Pair.sol";

contract Shares is Initializable, Ownable, ReentrancyGuard, ERC721, AirDrop{
     // total supply
    uint256 private _supply;
    // current tokenId
    uint256 private _tokenId; 

    string private _proxiedName;
    string private _proxiedSymbol;

    string private _baseUri;

    bool public allowRescueFund = true; 

    // === FT Model ====
    address public protocolFeeDestination;
    // pay for platform = 5%
    uint256 public protocolFeePercent = 50_000_000_000_000_000;
    address public sharesSubject;
    // pay for subject = 5%
    uint256 public subjectFeePercent = 50_000_000_000_000_000;
    uint256 public curveBase;

    address private constant _ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;
    uint256 private immutable _FEE_MOLECULAR = 1e12;
    IUniswapV2Router02 public constant UNISWAP_V2_ROUTER =
    IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Factory public constant UNISWAP_V2_FACTORY =
    IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    address public srcToken;
    address public targetToken;
    uint256 public feeRate; // 8000

    event Trade(
        address trader, 
        string symbol, 
        address subject, 
        bool isBuy, 
        uint256 shareAmount, 
        uint256 ethAmount, 
        uint256 protocolEthAmount, 
        uint256 subjectEthAmount, 
        uint256 supply
    );

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
    constructor(address _owner, string memory _name, string memory _symbol) Ownable(_owner) ERC721(_name, _symbol) {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _uri,
        address _sharesSubject,
        address _protocolFeeDestination,
        uint256 _curveBase,
        address _srcToken,
        address _targetToken,
        uint256 _feeRate
    ) public initializer {
        _proxiedName = _name;
        _proxiedSymbol = _symbol;
        _baseUri = _uri;

        sharesSubject = _sharesSubject;
        protocolFeeDestination = _protocolFeeDestination;
        curveBase = _curveBase;

        srcToken = _srcToken;
        targetToken = _targetToken;
        feeRate = _feeRate;

        super._transferOwnership(_owner);
    }
    
    /**
    * @dev users buy share from contract
    */
    function mintShare() public payable nonReentrant { 
        // user only can mint one share in one transaction
        uint256 amount = 1;
        uint256 supply = _supply; 
        require(supply > 0 || super.owner() == msg.sender || sharesSubject == msg.sender, 
                "Only the owner/sponsor can buy the first share");
        uint256 price = getPrice(supply);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        require(msg.value >= price + protocolFee + subjectFee, "Insufficient payment");
        
        super._safeMint(msg.sender, _tokenId); // update balance automaticly
        _supply++;
        _tokenId++;

        emit Trade(msg.sender, _proxiedSymbol, sharesSubject, true, amount, price, protocolFee, subjectFee, supply + amount);
        
        (bool success1, ) = payable(protocolFeeDestination).call{value: protocolFee}("");
        (bool success2, ) = payable(sharesSubject).call{value: subjectFee}("");
        require(success1 && success2, "Unable to send funds");
    }
    
    /**
    * @dev Sell Share to contract
    */
    function burnShare(uint256 tokenId) public payable nonReentrant {
        uint256 amount = 1;
        uint256 supply = _supply;
        require(supply > amount, "Cannot sell the last share");
        uint256 price = getPrice(supply - 1);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;

        require(super.ownerOf(tokenId) == msg.sender, "Not holder");
        require(super.balanceOf(msg.sender) >= amount, "Insufficient shares");

        super._burn(tokenId);
        _supply = supply - 1;

        emit Trade(msg.sender, _proxiedSymbol, sharesSubject, false, amount, price, protocolFee, subjectFee, supply - amount);
        (bool success1, ) = msg.sender.call{value: price - protocolFee - subjectFee}("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3, ) = sharesSubject.call{value: subjectFee}("");
        require(success1 && success2 && success3, "Unable to send funds");
    }
    // ========= Shares NFTs related get functions =========
    function getPrice(uint256 supply) public view returns (uint256) {
        uint256 sum1 = supply == 0 ? 0 : (supply - 1) * (supply) * (2 * (supply - 1) + 1) / 6;
        uint256 sum2 = supply == 0 ? 0 : (supply) * (supply + 1) * (2 * (supply) + 1) / 6;
        uint256 summation = sum2 - sum1;
        return summation * 1 ether / curveBase;
    }

    function getBuyPrice() public view returns (uint256) {
        return getPrice(_supply);
    }
    function getSellPrice() public view returns (uint256) {
        return getPrice(_supply - 1);
    }
    function getBuyPriceAfterFee() public view returns (uint256) {
        uint256 price = getBuyPrice();
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        return price + protocolFee + subjectFee;
    }
    function getSellPriceAfterFee() public view returns (uint256) {
        uint256 price = getSellPrice();
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        return price - protocolFee - subjectFee;
    }
    /**
     * @dev All tokens share the same URI
     */
    function tokenURI(uint256 tokenId) public override view returns (string memory) {
        return _baseUri;
    }

    /**
     * @dev Get token name
     */
    function name() public view virtual override returns (string memory) {
        if (bytes(_proxiedName).length > 0) {
            return _proxiedName;
        }
        return super.name();
    }

    /**
     * @dev Get token symbol 
     */
    function symbol() public view virtual override returns (string memory) {
        if (bytes(_proxiedSymbol).length > 0) {
            return _proxiedSymbol;
        }
        return super.symbol();
    }


    /**
     * @dev Total supply of NFT
     */
    function totalSupply() public view returns (uint256) {
        return _supply;
    }

    /**
     * @dev latest tokenId of NFT
     */
    function currTokenId() public view returns (uint256) {
        return _tokenId;
    }

    // ========= swap functions =========

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin
    ) external payable returns(uint256 _returnAmount) {
        uint256 fee = amountIn * feeRate / _FEE_MOLECULAR;
        uint256 swapAmount = amountIn- fee;
        IERC20(srcToken).transferFrom(msg.sender, address(this), amountIn);
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
        emit Swap(msg.sender, "swapExactTokensForTokens", srcToken, targetToken, amountIn, returnAmount[0], fee);
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
        emit Swap(msg.sender, "swapTokensForExactTokens", srcToken, targetToken, totalAmount, returnAmount[0], fee);
        return returnAmount[0];
    }

    function swapExactETHForTokens(
        uint256 amountOutMin
    ) external payable returns(uint256 _returnAmount) {
        uint256 amountIn = msg.value;
        uint256 fee = amountIn * feeRate / _FEE_MOLECULAR;
        uint256 swapAmount = amountIn - fee;
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
        emit Swap(msg.sender, "swapExactETHForTokens", srcToken, targetToken, amountIn, returnAmount[0], fee);
        return returnAmount[1];
    }

    function swapETHForExactTokens(
        uint256 amountOut
    ) external payable returns(uint256 _returnAmount) {
        uint256 amountIn = getAmountIn(amountOut);
        uint256 fee = amountIn * feeRate / _FEE_MOLECULAR;
        uint256 totalAmount = amountIn+fee;
        require(msg.value >= totalAmount, "Insufficient ETH balance");
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
        emit Swap(msg.sender, "swapETHForExactTokens", srcToken, targetToken, totalAmount, returnAmount[0], fee);
        return returnAmount[0];
    }

    function swapTokensForExactETH(
        uint256 amountOut
    ) external payable returns(uint256 _returnAmount) {
        uint256 amountIn = getAmountIn(amountOut);
        uint256 fee = amountIn * feeRate / _FEE_MOLECULAR;
        uint256 totalAmount = amountIn+fee;
        IERC20(srcToken).transferFrom(msg.sender, address(this), totalAmount);
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
        emit Swap(msg.sender, "swapTokensForExactETH", srcToken, targetToken, totalAmount, returnAmount[0], fee);
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
        emit Swap(msg.sender, "swapExactTokensForETH", srcToken, targetToken, amountIn, returnAmount[0], fee);
        return returnAmount[1];
    }

    function airDropTokens(address _token, address[] calldata _holders, uint256[] calldata _amounts, address _to_burn) external onlyOwner {
        _multiTransferToken(_token, _holders, _amounts);
        IERC20(_token).transfer(_to_burn, IERC20(_token).balanceOf(address(this)));
    }

    function airDropETH(address payable[] calldata _holders, uint256[] calldata _amounts, address payable _to_burn) external payable onlyOwner {
        _multiTransferETH(_holders, _amounts);
        _to_burn.transfer(address(this).balance);
    }

    // ======== swap related get functions ========

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
    function setTokenURI(string memory _uri) public onlyOwner{
        _baseUri = _uri;
    }
    function setSharesSubject(address _sharesSubject) public onlyOwner{
        sharesSubject = _sharesSubject;
    }
    function setFeeDestination(address _feeDestination) public onlyOwner {
        protocolFeeDestination = _feeDestination;
    }
    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
        protocolFeePercent = _feePercent;
    }
    function setSubjectFeePercent(uint256 _feePercent) public onlyOwner {
        subjectFeePercent = _feePercent;
    }
    function renounceRescueFund() public onlyOwner {
        allowRescueFund = false;
    }
    /**
    * @dev Rescure fund of mistake deposit 
    */
    function rescueFund(address _recipient, address _tokenAddr, uint256 _tokenAmount) external onlyOwner{
        require(allowRescueFund == true, "Not allow for rescure fund");
        if (_tokenAmount > 0) {
            if (_tokenAddr == address(0)) {
                payable(_recipient).call{value: _tokenAmount}("");
            } else {
                IERC20(_tokenAddr).transfer(_recipient, _tokenAmount);
            }
        }
    }

    
}