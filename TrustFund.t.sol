// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TrustFund.sol";

contract TrustFundTest is Test {
    TrustFund public trustFund;
    
    address public creator = address(1);
    address public contributor1 = address(2);
    address public contributor2 = address(3);

    function setUp() public {
        trustFund = new TrustFund();
        vm.deal(contributor1, 100 ether);
        vm.deal(contributor2, 100 ether);
    }

    function testCreateCampaign() public {
        vm.startPrank(creator);
        
        string[] memory descs = new string[](2);
        descs[0] = "Milestone 1";
        descs[1] = "Milestone 2";
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 5 ether;
        amounts[1] = 5 ether;

        trustFund.createCampaign(10 ether, 7, descs, amounts);
        vm.stopPrank();

        (address _creator, uint256 goal, , , TrustFund.CampaignStatus status, ) = trustFund.campaigns(0);
        assertEq(_creator, creator);
        assertEq(goal, 10 ether);
        assertEq(uint(status), uint(TrustFund.CampaignStatus.Active));
    }

    function testDonateAndApprove() public {
        testCreateCampaign();

        vm.prank(contributor1);
        trustFund.donate{value: 6 ether}(0);
        
        vm.prank(contributor2);
        trustFund.donate{value: 4 ether}(0);

        vm.prank(creator);
        trustFund.submitMilestone(0, 0);

        vm.prank(contributor1);
        trustFund.approveMilestone(0, 0);

        (, , , bool isApproved, , uint256 votes) = trustFund.campaignMilestones(0, 0);
        assertTrue(isApproved);
        assertEq(votes, 6 ether);

        uint256 creatorBalanceBefore = creator.balance;
        trustFund.releaseFunds(0, 0);
        assertEq(creator.balance, creatorBalanceBefore + 5 ether);
    }

    function testRefundOnFailure() public {
        testCreateCampaign();

        vm.prank(contributor1);
        trustFund.donate{value: 4 ether}(0);

        vm.warp(block.timestamp + 8 days);

        uint256 balanceBefore = contributor1.balance;
        
        vm.prank(contributor1);
        trustFund.claimRefund(0);

        assertEq(contributor1.balance, balanceBefore + 4 ether);
    }
}
