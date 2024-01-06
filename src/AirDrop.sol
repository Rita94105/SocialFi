// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AirDrop {

    /// Transfer ETH to multiple addresses
    function multiTransferETH(
        address payable[] calldata _addresses,
        uint256[] calldata _amounts
    ) public payable{
        // Check: _addresses and _amounts arrays should have the same length
        require(_addresses.length == _amounts.length, "Lengths of Addresses and Amounts NOT EQUAL");
        // Calculate total amount of ETH to be airdropped
        uint _amountSum = _getSum(_amounts);
        // Check: transferred ETH should equal total amount
        require(msg.value == _amountSum, "Transfer amount error");
        // Use a for loop to transfer ETH using transfer function
        for (uint256 i = 0; i < _addresses.length; i++) {
            _addresses[i].transfer(_amounts[i]);
        }
    }

    function _multiTransferToken(
    address _token,
    address[] calldata _addresses,
    uint256[] calldata _amounts
    ) internal{
    // Check: The length of _addresses array should be equal to the length of _amounts array
    require(_addresses.length == _amounts.length, "Lengths of Addresses and Amounts NOT EQUAL");
    
    // for loop, use transferFrom function to send airdrops
    for (uint8 i; i < _addresses.length; i++) {
        IERC20(_token).transfer(_addresses[i], _amounts[i]);
    }
}

    // sum function for arrays
    function _getSum(uint256[] calldata _arr) internal pure returns(uint sum)
    {
        for(uint i = 0; i < _arr.length; i++)
            sum = sum + _arr[i];
    }

    // users can withdraw tokens approved by the contract
    function _withdrawToken(
        address _token, uint _amount
    ) internal{
        //IERC20(_token).transferFrom(address(this), msg.sender,_amount);
        IERC20(_token).transfer(msg.sender, _amount);
    }

}