// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./AirDrop.sol";

contract Campaigns is Initializable, Ownable, ReentrancyGuard, AirDrop{
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
        mapping(address => bool) winners;
        uint256 winnersCount;
        mapping(address => bool) claimers;
        uint256 claimersCount;
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

        Campaign storage newCampaign = campaigns[campHash];
        newCampaign.id = campHash;
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.startTime = _startTime;
        newCampaign.endTime = _endTime;
        newCampaign.totalFunds = _totalFunds;
        newCampaign.balance = _totalFunds;
        newCampaign.prizes = _prizes;
        newCampaign.creator = payable(_creator);
        newCampaign.winnersCount = 0;
        newCampaign.claimersCount = 0;
        newCampaign.status = 0;
    
        userCampaigns[_creator].push(campHash);
        campaignCount++;
    }

    /**
    * @dev airdrop the prizes to the winners
    * creator should call this function only when the campaign has ended
    * winners should be added before calling this function
    */
    function airDropTokens(bytes32 _campaignId,address[] calldata _winners, uint256[] calldata _amounts) public{
        Campaign storage _campaign = campaigns[_campaignId];
        require(_campaign.creator == msg.sender, "Only creator can call this function");
        require(block.timestamp >= _campaign.endTime, "Campaign has not ended yet");
        require(_campaign.status == 1, "Campaign has not ended yet");
        require(_campaign.winnersCount > 0, "No winners added");
        require(_campaign.totalFunds > 0, "Campaign has no funds");
        require(IERC20(_campaign.prizes).balanceOf(address(this)) >= _campaign.totalFunds, "Not enough funds");
        _campaign.status = 1;
        uint256 _amount = getAmount(_campaignId);
        _multiTransferToken(_campaign.prizes, _winners, _amounts);
        _campaign.balance -= _amount*_winners.length;
        if(_campaign.balance > 0){
            IERC20(_campaign.prizes).transfer(owner(), _campaign.balance);
            _campaign.balance = 0;
        }
    }

    /**
    * @dev pause the campaign and return the funds to the creator
    */
    function pauseCampign(bytes32 _campaignId) public{
        Campaign storage _campaign = campaigns[_campaignId];
        require(_campaign.creator == msg.sender, "Only creator can call this function");
        require(_campaign.status == 0, "Campaign has already ended");
        require(IERC20(_campaign.prizes).balanceOf(address(this)) >= _campaign.totalFunds, "Not enough funds");
        _campaign.status = 1;
        _campaign.endTime = block.timestamp;
        IERC20(_campaign.prizes).transfer(_campaign.creator, _campaign.totalFunds);
    }
    /**
    * @dev add winners to the campaign
    * winners should be added only after the campaign has ended but before airdropping the prizes
    */
    function addWinners(bytes32 _campaignId, address[] memory _winners) public{
        Campaign storage _campaign = campaigns[_campaignId];
        require(_campaign.creator == msg.sender, "Only creator can call this function");
        require(_campaign.status == 0, "Campaign has already ended");
        require(block.timestamp >= _campaign.endTime, "Campaign has not ended yet");
        require(_winners.length > 0, "No winners added");
        require(_campaign.winnersCount == 0, "Winners already added");
        for(uint256 i = 0; i < _winners.length; i++){
            _campaign.winners[_winners[i]] = true;
        }
        _campaign.winnersCount = _winners.length;
        uint256 _amount = _campaign.totalFunds/_winners.length;
        uint256 _left = _campaign.totalFunds - _amount*_winners.length;
        _campaign.status=1;
        if(_left > 0){
            IERC20(_campaign.prizes).transfer(owner(), _left);
            _campaign.balance -= _left;
        }
    }

    function claim(bytes32 _campaignId,address _prizes,uint256 _amount) public{
        require(block.timestamp >= campaigns[_campaignId].endTime, "Campaign has not ended yet");
        require(campaigns[_campaignId].winnersCount > 0, "No winners added");
        require(isWinner(_campaignId, msg.sender), "You are not a winner");
        require(!isClaimer(_campaignId, msg.sender), "You have already claimed");
        Campaign storage _campaign = campaigns[_campaignId];
        require(_campaign.balance >= _amount, "Not enough funds");
        _campaign.balance -= _amount;
        _campaign.claimers[msg.sender] = true;
        _campaign.claimersCount++;
        _withdrawToken(_prizes, _amount);
    }

    function rescueFund(bytes32 _campaignId,address _recipient, address _prizes, uint256 _amount) external onlyOwner{
        Campaign storage _campaign = campaigns[_campaignId];
        require(_campaign.status == 1, "Campaign has not ended yet");
        if (_amount > 0 && _campaign.balance >= _amount) {
            IERC20(_prizes).transfer(_recipient, _amount);
        }
        _campaign.balance -= _amount;
    }

    function getAllCamps(address _creator) public view returns(bytes32[] memory){
        return userCampaigns[_creator];
    }

    function getCampaign(bytes32 hash) public view 
    returns (bytes32, string memory, string memory, uint256, uint256, uint256, 
    uint256, address,uint256, uint256, address payable, uint8) {
        Campaign storage campaign = campaigns[hash];
        return (campaign.id, campaign.title, campaign.description, campaign.startTime, 
        campaign.endTime, campaign.totalFunds, campaign.balance, campaign.prizes,
        campaign.winnersCount, campaign.claimersCount, campaign.creator, campaign.status);
    }

    function getAmount(bytes32 _campaignId) public view returns(uint256){
        require(block.timestamp >= campaigns[_campaignId].endTime, "Campaign has not ended yet");
        Campaign storage _campaign = campaigns[_campaignId];
        require(_campaign.winnersCount > 0, "No winners added");
        return _campaign.totalFunds/_campaign.winnersCount;
    }

    function isWinner(bytes32 _campaignId, address user) public view returns (bool) {
        return campaigns[_campaignId].winners[user];
    }

    function isClaimer(bytes32 _campaignId, address user) public view returns (bool) {
        return campaigns[_campaignId].claimers[user];
    }

    function _generateCampHash(address _from,uint256 _totalFunds,address _prizes,uint256 _startTime) internal pure returns(bytes32){
        return keccak256(abi.encodePacked(_from,_totalFunds,_prizes,_startTime));
    }

    receive() external payable {}
}