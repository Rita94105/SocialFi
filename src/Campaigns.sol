// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Campaigns is Initializable, Ownable, ReentrancyGuard{
    bool private _initialized;
    uint256 public campaignCount = 0;
    mapping(bytes32 => Campaign) public campaigns;
    mapping(address => bytes32[]) public userCampaigns;

    struct Campaign{
        bytes32 id;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 totalFunds;
        uint256 balance;
        address prizes;
        address[] winners;
        address payable creator;
        uint8 status; // 0 = ongoing, 1 = ended
    }

    constructor(address _owner) Ownable(_owner){
        _disableInitializers();
    }

    function initialize(address _owner) public initializer {
        require(!_initialized, "Contract instance has already been initialized");
        _initialized = true;
        _transferOwnership(_owner);
    }

    /**
    * @dev Create a new campaign
    * creator should transfer the total funds to the contract when calling this function
    */
    function createCampaign(address _creator,string memory _title, string memory _description,uint256 blocks, uint256 _totalFunds,address _prizes) public{
        uint256 _startTime = block.timestamp;
        uint256 _endTime = block.timestamp + blocks;
        require(_startTime < _endTime, "Start time must be less than end time");
        require(_totalFunds > 0, "Total funds must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_prizes != address(0), "Prizes address cannot be 0");
        IERC20(_prizes).transferFrom(_creator, address(this), _totalFunds);
        bytes32 campHash = _generateCampHash(_creator,_totalFunds,_prizes,_startTime);
        campaigns[campHash] = Campaign(campHash, _title, _description, _startTime, _endTime, _totalFunds, _totalFunds, _prizes, new address[](0), payable(_creator),0);
        userCampaigns[_creator].push(campHash);
        campaignCount++;
    }

    /**
    * @dev airdrop the prizes to the winners
    * creator should call this function only when the campaign has ended
    * winners should be added before calling this function
    */
    function airDrop(bytes32 _campaignId) public{
        Campaign memory _campaign = campaigns[_campaignId];
        require(_campaign.creator == msg.sender, "Only creator can call this function");
        require(block.timestamp >= _campaign.endTime, "Campaign has not ended yet");
        require(_campaign.status == 0, "Campaign has already ended");
        require(_campaign.totalFunds > 0, "Campaign has no funds");
        require(IERC20(_campaign.prizes).balanceOf(address(this)) >= _campaign.totalFunds, "Not enough funds");
        require(_campaign.winners.length > 0, "No winners added");
        _campaign.status = 1;
        uint256 _totalWinners = _campaign.winners.length;
        uint256 _totalFunds = _campaign.totalFunds;
        uint256 _balance = _campaign.balance;
        uint256 _prize = _totalFunds / _totalWinners;
        for(uint256 i = 0; i < _totalWinners; i++){
            _balance -= _prize;
            IERC20(_campaign.prizes).transfer(_campaign.winners[i], _prize);
        }
        if(_balance > 0){
            IERC20(_campaign.prizes).transfer(owner(), _balance);
            _balance = 0;
        }
        _campaign.balance = _balance;
        campaigns[_campaignId] = _campaign;
    }

    /**
    * @dev pause the campaign and return the funds to the creator
    */
    function pauseCampign(bytes32 _campaignId) public{
        Campaign memory _campaign = campaigns[_campaignId];
        require(_campaign.creator == msg.sender, "Only creator can call this function");
        require(_campaign.status == 0, "Campaign has already ended");
        require(IERC20(_campaign.prizes).balanceOf(address(this)) >= _campaign.totalFunds, "Not enough funds");
        _campaign.status = 1;
        _campaign.winners = new address[](0);
        _campaign.endTime = block.timestamp;
        IERC20(_campaign.prizes).transfer(_campaign.creator, _campaign.totalFunds);
        campaigns[_campaignId] = _campaign;
    }
    /**
    * @dev add winners to the campaign
    * winners should be added only after the campaign has ended but before airdropping the prizes
    */
    function addWinners(bytes32 _campaignId, address[] memory _winners) public{
        Campaign memory _campaign = campaigns[_campaignId];
        require(_campaign.creator == msg.sender, "Only creator can call this function");
        require(_campaign.status == 0, "Campaign has already ended");
        require(block.timestamp >= _campaign.endTime, "Campaign has not ended yet");
        require(_winners.length > 0, "No winners added");
        _campaign.winners = _winners;
        campaigns[_campaignId] = _campaign;
    }

    function getAllCamps(address _creator) public view returns(bytes32[] memory){
        return userCampaigns[_creator];
    }

    function getCampaign(bytes32 hash) public view returns (bytes32, string memory, string memory, uint256, uint256, uint256, uint256, address,address[] memory, address payable, uint8) {
        Campaign storage campaign = campaigns[hash];
        return (campaign.id, campaign.title, campaign.description, campaign.startTime, campaign.endTime, campaign.totalFunds, campaign.balance, campaign.prizes,campaign.winners, campaign.creator, campaign.status);
    }

    function _generateCampHash(address _from,uint256 _totalFunds,address _prizes,uint256 _startTime) internal pure returns(bytes32){
        return keccak256(abi.encodePacked(_from,_totalFunds,_prizes,_startTime));
    }

    receive() external payable {}
}