// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/proxy/Proxy.sol";

contract SharesProxy is Proxy { 
    address private admin;
    address private impl;

    constructor(address _logic, bytes memory _data) {
        admin = msg.sender;
        if(_data.length > 0){
            (bool success, ) = _logic.delegatecall(_data);
            require(success, "SimpleSwap failed to initialize");
            impl = _logic;
        }   
    }
    modifier onlyAdmin {
        require(msg.sender == admin, "only admin");
        _; 
    }
    
    function upgradeToAndCall(address _logic, bytes calldata _data) external payable onlyAdmin {
        impl = _logic;
        (bool success, ) = impl.delegatecall(_data);
        require(success, "init failed");

    }

    function _implementation() internal view override returns (address) {
        return impl;
    }

    function implementation() external view returns (address) {
        return impl;
    }
}
