// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {GovToken} from "../src/GovToken.sol";

contract DAOGovernanceTest is Test {
    MyGovernor governor;
    Box box;
    TimeLock timelock;
    GovToken govToken;

    address public USER = makeAddr("user");
    address public PROPOSER = makeAddr("proposer");
    address public EXECUTOR = makeAddr("executor");
    address public VOTER1 = makeAddr("voter1");
    address public VOTER2 = makeAddr("voter2");
    address public VOTER3 = makeAddr("voter3");

    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant VOTING_DELAY = 1; // 1 block
    uint256 public constant VOTING_PERIOD = 50400; // 1 week in blocks
    uint256 public constant QUORUM_PERCENTAGE = 4; // 4%

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, 100e18);
        
        timelock = new TimeLock(MIN_DELAY, new address[](0), new address[](0));
        governor = new MyGovernor(govToken, timelock);
        box = new Box();
        
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.TIMELOCK_ADMIN_ROLE();
        
        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, address(this));
        
        box.transferOwnership(address(timelock));
        
        govToken.mint(VOTER1, 100e18);
        govToken.mint(VOTER2, 200e18);
        govToken.mint(VOTER3, 300e18);
    }

    function test_GovernanceWorkflow() public {
        // Delegate voting power
        vm.prank(VOTER1);
        govToken.delegate(VOTER1);
        vm.prank(VOTER2);
        govToken.delegate(VOTER2);
        vm.prank(VOTER3);
        govToken.delegate(VOTER3);

        // 1. Create proposal
        uint256 valueToStore = 777;
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        uint256 proposalId = _createProposal(encodedFunctionCall);
        
        // Check initial state (Pending)
        assertEq(uint256(governor.state(proposalId)), 0);
        
        // 2. Move to active state
        vm.roll(block.number + VOTING_DELAY + 1);
        assertEq(uint256(governor.state(proposalId)), 1);
        
        // 3. Cast votes - Modified to ensure proposal succeeds
        vm.prank(VOTER1);
        governor.castVoteWithReason(proposalId, 1, "I support this proposal");
        
        // Changed VOTER2 to vote FOR instead of AGAINST
        vm.prank(VOTER2);
        governor.castVoteWithReason(proposalId, 1, "I now support this proposal");
        
        vm.prank(VOTER3);
        governor.castVoteWithReason(proposalId, 2, "I abstain from voting");
        
        // 4. Move past voting period
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        // Check vote results
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        

        
        // Display voting results
        console.log("Voting Results:");
        console.log("---------------");
        console.log("For votes:    ", forVotes / 1e18, "tokens");
        console.log("Against votes: ", againstVotes / 1e18, "tokens");
        console.log("Abstain votes: ", abstainVotes / 1e18, "tokens");
        
        // Determine and display the winner
        if (forVotes > againstVotes) {
            console.log("Result: Proposal PASSED (For votes won)");
        } else if (againstVotes > forVotes) {
            console.log("Result: Proposal FAILED (Against votes won)");
        } else {
            console.log("Result: Proposal TIED");
        }
    


        assertEq(forVotes, 300e18); // 100 + 200
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 300e18);
        
        // Check quorum
        uint256 quorum = governor.quorum(block.number - 1);
        console.log("Quorum required: ", quorum / 1e18, "tokens");
        console.log("Total votes cast: ", (forVotes + againstVotes + abstainVotes) / 1e18, "tokens");
        
        assertGt(quorum, 0);
        assertTrue(forVotes + againstVotes + abstainVotes >= quorum, "Quorum not met");
        
        // Check proposal state - should now be Succeeded (4)
        uint256 snapshotBlock = governor.proposalSnapshot(proposalId);
        vm.roll(snapshotBlock + VOTING_PERIOD + 1);
        assertEq(uint256(governor.state(proposalId)), 4); // Now expects Succeeded
        
        // Restore block number for queue/execute
        vm.roll(block.number);
        
        // 5. Queue the proposal
        address[] memory targets = new address[](1);
        targets[0] = address(box);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = encodedFunctionCall;
        bytes32 descriptionHash = keccak256(bytes("Proposal #1: Store 777 in Box"));
        
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint256(governor.state(proposalId)), 5);
        
        // 6. Fast forward time
        vm.warp(block.timestamp + MIN_DELAY + 1);
        
        // 7. Execute the proposal
        governor.execute(targets, values, calldatas, descriptionHash);
        assertEq(box.retrieve(), valueToStore);
        assertEq(uint256(governor.state(proposalId)), 7);
    }

    function _createProposal(bytes memory encodedFunctionCall) internal returns (uint256) {
        address[] memory targets = new address[](1);
        targets[0] = address(box);
        
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = encodedFunctionCall;
        
        vm.prank(PROPOSER);
        govToken.delegate(PROPOSER);
        vm.prank(PROPOSER);
        return governor.propose(targets, values, calldatas, "Proposal #1: Store 777 in Box");
    }
}


/*
DAO Governance Test Summary:

1. Setup:
- Deploys GovToken (ERC20 voting token), TimeLock, Governor, and Box contracts
- Mints tokens to test accounts (USER, VOTER1-3)
- Configures governance roles (proposer, executor)
- Transfers Box ownership to TimeLock

2. Test Workflow:
- Delegates voting power to test accounts
- Creates proposal to store value 777 in Box contract
- Verifies proposal moves from Pending → Active state
- Voting results:
  * VOTER1 (100 tokens): FOR
  * VOTER2 (200 tokens): FOR
  * VOTER3 (300 tokens): ABSTAIN
- Total votes: 300 FOR, 0 AGAINST, 300 ABSTAIN
- Quorum: 28 tokens (4% of 700 total supply) - MET
- Proposal PASSES (more FOR than AGAINST)
- Successfully queues and executes proposal after timelock delay
- Verifies Box value updated to 777

3. Key Observations:
- Abstain votes don't count as for/against, only affect quorum
- Proposal passes with any FOR > AGAINST votes
- Quorum is based on total voting power used (FOR+AGAINST+ABSTAIN)
- Full governance lifecycle tested (propose → vote → queue → execute)
*/