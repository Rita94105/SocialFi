// SPDX-License-Identifier: MIT
pragma solidity>=0.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract QQToken is ERC20 {
    address _owner;
    mapping(address account => uint256) private _balances;
    mapping(address account => mapping(address spender => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    modifier onlyOwner(){
        require(_owner==msg.sender,"only owner can access this function");
        _;
    }

    constructor() ERC20("QQToken", "QQ") {
        _owner=msg.sender;
    }

    function getOwner() public view returns(address){
        return _owner;
    }

    function mint(address account,uint256 amount) onlyOwner public{
        _mint(account,amount);
        emit Transfer(address(0),account,amount);
    }

    function burn(address account,uint256 amount) onlyOwner public{
        _burn(account,amount);
        emit Transfer(account,address(0),amount);
    }
}
