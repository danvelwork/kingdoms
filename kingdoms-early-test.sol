// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TeamGame is ERC20, Ownable {
    uint256 public ethToChipRate = 100; // Example: 1 ETH = 100 Chips
    uint256 public constant tokensPerRound = 50 * 10**18; // 50 Tokens as reward per round
    uint256 public constant teamBitRequirement = 60; // Each team needs 60 chips per round
    uint256 public roundDuration = 10 seconds; // Set for fast testing rounds

    mapping(address => uint256) public chipBalance;
    mapping(address => uint256) public teamChoice;
    mapping(uint256 => address[]) public teamMembers;
    mapping(uint256 => mapping(address => uint256)) public teamBids;
    
    uint256 public lastRoundTime;
    uint256 public roundNumber = 1;
    uint256 public constant maxTeams = 3; // Only 3 teams for testing
    
    event BurnForChips(address indexed user, uint256 ethAmount, uint256 chipsReceived);
    event JoinedTeam(address indexed user, uint256 team);
    event RoundResult(uint256 winningTeam, uint256 roundNumber);

    constructor() ERC20("RewardToken", "RWT") Ownable(msg.sender) {
        _mint(address(this), 1_000_000 * 10**18); // Initial supply of 1 million tokens
        lastRoundTime = block.timestamp;
    }

    // 1) Burn Mechanism: Users burn ETH to receive chips
    function burnETHForChips() external payable {
        require(msg.value > 0, "Must send ETH to receive chips");
        uint256 chipsReceived = msg.value * ethToChipRate;
        chipBalance[msg.sender] += chipsReceived;
        emit BurnForChips(msg.sender, msg.value, chipsReceived);
    }

    // 2) Team Selection: Join one of three teams
    function joinTeam(uint256 team) external {
        require(team >= 1 && team <= maxTeams, "Invalid team choice");
        require(teamChoice[msg.sender] == 0, "Already in a team");
        
        teamChoice[msg.sender] = team;
        teamMembers[team].push(msg.sender);
        emit JoinedTeam(msg.sender, team);
    }

    // 3) Automated Chip Delegation per Round
    function delegateChips(uint256 bidAmount) external {
        uint256 team = teamChoice[msg.sender];
        require(team > 0, "Must join a team first");
        require(bidAmount == 10 || bidAmount == 20 || bidAmount == 30, "Invalid bid amount");
        require(chipBalance[msg.sender] >= bidAmount, "Insufficient chips");

        teamBids[team][msg.sender] += bidAmount;
        chipBalance[msg.sender] -= bidAmount;
    }

    // 4) Simulate Round (Random winner team)
    function simulateRound() external {
        require(block.timestamp >= lastRoundTime + roundDuration, "Round duration not met");
        
        uint256 winningTeam = randomTeamSelection();
        distributeRewards(winningTeam);
        
        emit RoundResult(winningTeam, roundNumber);
        lastRoundTime = block.timestamp;
        roundNumber++;
        
        // Reset team bids for the next round
        resetBids();
    }

    // 5) Random Team Selection
    function randomTeamSelection() internal view returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % maxTeams) + 1;
    }

    // 6) Reward Distribution: Winning team members equally split tokens
    function distributeRewards(uint256 winningTeam) internal {
        uint256 teamMemberCount = teamMembers[winningTeam].length;
        require(teamMemberCount > 0, "No members in winning team");
        
        uint256 rewardPerMember = tokensPerRound / teamMemberCount;
        
        for (uint256 i = 0; i < teamMemberCount; i++) {
            _transfer(address(this), teamMembers[winningTeam][i], rewardPerMember);
        }
    }

    // Reset bids after each round
    function resetBids() internal {
        for (uint256 team = 1; team <= maxTeams; team++) {
            for (uint256 i = 0; i < teamMembers[team].length; i++) {
                address member = teamMembers[team][i];
                teamBids[team][member] = 0;
            }
        }
    }

    // Helper to check chip balance
    function getChipBalance(address user) external view returns (uint256) {
        return chipBalance[user];
    }

    // Fallback function to accept ETH
    receive() external payable {}
}
