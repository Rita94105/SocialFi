pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {QQToken} from "../src/QQToken.sol";
import {Campaigns} from "../src/Campaigns.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract CampaignsTest is Test{
    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    QQToken public token;
    Campaigns public campaigns;
    Campaigns public proxyCampaigns;
    ERC1967Proxy public proxy;
    function setUp() public{
        vm.startPrank(owner);

        token = new QQToken();
        token.mint(user1, 100 ether);

        campaigns = new Campaigns(owner);
        proxy = new ERC1967Proxy(payable(address(campaigns)), abi.encodeWithSignature("initialize(address)", owner));
        proxyCampaigns = Campaigns(payable(address(proxy)));
        vm.stopPrank();
    }

    function testCreateCampaign() public{
        vm.startPrank(user1);
        token.approve(address(proxyCampaigns), type(uint256).max);
        proxyCampaigns.createCampaign(user1,"First Quest", "Give everyone red envelop to celebrate 2024", 10, 100 ether, address(token));
        bytes32 hash = proxyCampaigns.getAllCamps(user1)[0];
        (, string memory title, string memory description, uint256 startTime, uint256 endTime, uint256 totalFunds, uint256 balance, address prizes,address[] memory winners, address payable creator, uint8 status) = proxyCampaigns.getCampaign(hash);
        assertEq(title,"First Quest", "title error");
        assertEq(description,"Give everyone red envelop to celebrate 2024", "description error");
        assertEq(creator,user1, "creator error");
        assertEq(startTime,block.timestamp, "start time error");
        assertEq(endTime,block.timestamp + 10, "end time error");
        assertEq(totalFunds,100 ether, "total funds error");
        assertEq(balance,100 ether, "balance error");
        assertEq(prizes,address(token), "prizes error");
        assertEq(status,0, "status error");
        assertEq(winners.length,0, "winners length should be 0");
        vm.stopPrank();
    }

    function testAddWinners() public{
        vm.startPrank(user1);
        token.approve(address(proxyCampaigns), type(uint256).max);
        proxyCampaigns.createCampaign(user1,"First Quest", "Give everyone red envelop to celebrate 2024", 10, 100 ether, address(token));
        bytes32 hash = proxyCampaigns.getAllCamps(user1)[0];
        vm.warp(11);
        address[] memory winners = new address[](2);
        winners[0] = user2;
        winners[1] = user3;
        proxyCampaigns.addWinners(hash, winners);
        (, , , , , , , ,address[] memory final_winners, , ) = proxyCampaigns.getCampaign(hash);
        assertEq(final_winners.length,2, "winners length should be 2");
        vm.stopPrank();
    }

    function testAirdrop() public{
        vm.startPrank(user1);
        token.approve(address(proxyCampaigns), type(uint256).max);
        proxyCampaigns.createCampaign(user1,"First Quest", "Give everyone red envelop to celebrate 2024", 10, 100 ether, address(token));
        bytes32 hash = proxyCampaigns.getAllCamps(user1)[0];
        assertEq(token.balanceOf(address(proxyCampaigns)),100 ether, "contract should have 0 tokens");
        vm.warp(11);
        address[] memory winners = new address[](2);
        winners[0] = user2;
        winners[1] = user3;
        proxyCampaigns.addWinners(hash, winners);
        proxyCampaigns.airDrop(hash);
        assertEq(token.balanceOf(user2), 50 ether, "user2 should get 50 tokens");
        assertEq(token.balanceOf(user3), 50 ether, "user3 should get 50 tokens");
        (, , , , , , uint256 balance, , , , uint8 status) = proxyCampaigns.getCampaign(hash);
        assertEq(balance,0 ether, "balance should be 0");
        assertEq(status,1, "status should be 1");
        vm.stopPrank();
    }

    function testPauseCampaign() public{
        vm.startPrank(user1);
        token.approve(address(proxyCampaigns), type(uint256).max);
        proxyCampaigns.createCampaign(user1,"First Quest", "Give everyone red envelop to celebrate 2024", 10, 100 ether, address(token));
        bytes32 hash = proxyCampaigns.getAllCamps(user1)[0];
        proxyCampaigns.pauseCampign(hash);
        (, , , , , , , , , , uint8 status) = proxyCampaigns.getCampaign(hash);
        assertEq(status,1, "status should be 1");
        assertEq(token.balanceOf(user1), 100 ether, "user1 should get 100 tokens");
        vm.stopPrank();
    }
}