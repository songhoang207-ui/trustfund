// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TrustFund {
    // --- Events ---
    event CampaignCreated(uint256 indexed campaignId, address indexed creator, uint256 goal, uint256 deadline);
    event DonationReceived(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event MilestoneSubmitted(uint256 indexed campaignId, uint256 milestoneIndex);
    event MilestoneApproved(uint256 indexed campaignId, uint256 milestoneIndex);
    event FundsReleased(uint256 indexed campaignId, uint256 milestoneIndex, uint256 amount);
    event RefundClaimed(uint256 indexed campaignId, address indexed contributor, uint256 amount);

    enum CampaignStatus { Active, Successful, Failed }

    struct Milestone {
        string description;
        uint256 targetAmount;
        bool isSubmitted;
        bool isApproved;
        bool isReleased;
        uint256 approvalVotes; // Tính theo số tiền AVAX của người biểu quyết
    }

    struct Campaign {
        address payable creator;
        uint256 goal;
        uint256 deadline;
        uint256 totalRaised;
        CampaignStatus status;
        uint256 milestoneCount;
    }

    uint256 public campaignCounter;
    
    // Lưu trữ dữ liệu
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(uint256 => Milestone)) public campaignMilestones;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    // Kiểm tra contributor đã vote cho milestone chưa (campaignId => milestoneIndex => address => bool)
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public hasVoted;

    // --- Functions ---

    // 1. Tạo campaign
    function createCampaign(
        uint256 _goal, 
        uint256 _durationInDays, 
        string[] memory _milestoneDescs, 
        uint256[] memory _milestoneAmounts
    ) external {
        require(_milestoneDescs.length == _milestoneAmounts.length, "Milestone data mismatch");
        require(_goal > 0, "Goal must be > 0");

        uint256 totalMilestoneAmount = 0;
        for(uint i = 0; i < _milestoneAmounts.length; i++) {
            totalMilestoneAmount += _milestoneAmounts[i];
        }
        require(totalMilestoneAmount == _goal, "Milestone amounts must equal goal");

        uint256 campaignId = campaignCounter++;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        Campaign storage newCampaign = campaigns[campaignId];
        newCampaign.creator = payable(msg.sender);
        newCampaign.goal = _goal;
        newCampaign.deadline = deadline;
        newCampaign.status = CampaignStatus.Active;
        newCampaign.milestoneCount = _milestoneDescs.length;

        for(uint i = 0; i < _milestoneDescs.length; i++) {
            campaignMilestones[campaignId][i] = Milestone({
                description: _milestoneDescs[i],
                targetAmount: _milestoneAmounts[i],
                isSubmitted: false,
                isApproved: false,
                isReleased: false,
                approvalVotes: 0
            });
        }

        emit CampaignCreated(campaignId, msg.sender, _goal, deadline);
    }

    // 2. Nhận donation bằng native AVAX
    function donate(uint256 _campaignId) external payable {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline, "Campaign ended");
        require(campaign.status == CampaignStatus.Active, "Not active");
        require(msg.value > 0, "Donation must be > 0");

        campaign.totalRaised += msg.value;
        contributions[_campaignId][msg.sender] += msg.value;

        if (campaign.totalRaised >= campaign.goal) {
            campaign.status = CampaignStatus.Successful;
        }

        emit DonationReceived(_campaignId, msg.sender, msg.value);
    }

    // 3. Submit milestone (Chỉ Creator)
    function submitMilestone(uint256 _campaignId, uint256 _milestoneIndex) external {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator, "Only creator");
        require(campaign.status == CampaignStatus.Successful, "Campaign not successful yet");
        
        Milestone storage milestone = campaignMilestones[_campaignId][_milestoneIndex];
        require(!milestone.isSubmitted, "Already submitted");

        milestone.isSubmitted = true;
        emit MilestoneSubmitted(_campaignId, _milestoneIndex);
    }

    // Cơ chế Approve Milestone (Dành cho Contributor bình chọn)
    function approveMilestone(uint256 _campaignId, uint256 _milestoneIndex) external {
        uint256 contributorAmount = contributions[_campaignId][msg.sender];
        require(contributorAmount > 0, "Only contributors can approve");
        
        Milestone storage milestone = campaignMilestones[_campaignId][_milestoneIndex];
        require(milestone.isSubmitted, "Milestone not submitted");
        require(!milestone.isApproved, "Already approved");
        require(!hasVoted[_campaignId][_milestoneIndex][msg.sender], "Already voted");

        hasVoted[_campaignId][_milestoneIndex][msg.sender] = true;
        milestone.approvalVotes += contributorAmount;

        // Ngưỡng phê duyệt: Hơn 50% tổng số tiền đã gây quỹ đồng ý
        if (milestone.approvalVotes > (campaigns[_campaignId].totalRaised / 2)) {
            milestone.isApproved = true;
            emit MilestoneApproved(_campaignId, _milestoneIndex);
        }
    }

    // 4. Giải ngân (Release funds)
    function releaseFunds(uint256 _campaignId, uint256 _milestoneIndex) external {
        Campaign storage campaign = campaigns[_campaignId];
        Milestone storage milestone = campaignMilestones[_campaignId][_milestoneIndex];

        require(milestone.isApproved, "Milestone not approved");
        require(!milestone.isReleased, "Funds already released"); // Chống xử lý trùng

        milestone.isReleased = true;
        campaign.creator.transfer(milestone.targetAmount);

        emit FundsReleased(_campaignId, _milestoneIndex, milestone.targetAmount);
    }

    // 5. Hoàn tiền (Refund) nếu chiến dịch thất bại
    function claimRefund(uint256 _campaignId) external {
        Campaign storage campaign = campaigns[_campaignId];
        
        // Cập nhật trạng thái nếu hết hạn và chưa đạt mục tiêu
        if (block.timestamp >= campaign.deadline && campaign.totalRaised < campaign.goal) {
            campaign.status = CampaignStatus.Failed;
        }

        require(campaign.status == CampaignStatus.Failed, "Refunds not available");
        
        uint256 contributedAmount = contributions[_campaignId][msg.sender];
        require(contributedAmount > 0, "No funds to claim or already claimed"); // Chống xử lý trùng

        contributions[_campaignId][msg.sender] = 0; // Reset số dư trước khi chuyển tiền (Reentrancy guard)
        payable(msg.sender).transfer(contributedAmount);

        emit RefundClaimed(_campaignId, msg.sender, contributedAmount);
    }
}
