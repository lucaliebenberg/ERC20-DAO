// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Box} from "../src/Box.sol";

contract MyGovernorTest is Test {
    MyGovernor governor;
    GovToken govToken;
    TimeLock timelock;
    Box box;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;
    uint256 public constant MIN_DELAY = 3600; // 1 hour (delay after a vote passes)
    uint256 public constant VOTING_DELAY = 1; // how many blocks till a vote is active
    uint256 public constant VOTING_PERIOD = 50400;

    address[] proposers;
    address[] executors;

    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        govToken.delegate(USER);
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 exectuorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(exectuorRole, address(0));
        timelock.revokeRole(adminRole, USER);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timelock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 888;
        string memory description = "store 1 in Box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature(
            "store(uint256)",
            valueToStore
        );
        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));    

        // 1. Propose to the DAO
        uint256 proposalId = governor.propose(targets, values, calldatas, description); 

        // View proposal state (-> Pending (0) )
        console.log("Proposal state: ", uint256(governor.state(proposalId))); 

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        // View proposal state (-> Active (1) )
        console.log("Proposal state: ", uint256(governor.state(proposalId)));

        // 2. Vote
        string memory reason = "because vegans suck";

        uint8 voteWay = 1; // yes
        vm.prank(USER); 
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue the TX
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. Execute
        governor.execute(targets, values, calldatas, descriptionHash);

        console.log("Box value: ", box.getNumber());
        assert(box.getNumber() == valueToStore);
    }
    //  function testGovernanceUpdatesBox() public {
    //     uint256 valueToStore = 777;
    //     string memory description = "Store 1 in Box";
    //     bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
    //     targets.push(address(box));
    //     values.push(0);
    //     calldatas.push(encodedFunctionCall);
    //     // 1. Propose to the DAO
    //     uint256 proposalId = governor.propose(targets, values, calldatas, description);

    //     console.log("Proposal State:", uint256(governor.state(proposalId)));
    //     // governor.proposalSnapshot(proposalId)
    //     // governor.proposalDeadline(proposalId)

    //     vm.warp(block.timestamp + VOTING_DELAY + 1);
    //     vm.roll(block.number + VOTING_DELAY + 1);

    //     console.log("Proposal State:", uint256(governor.state(proposalId)));

    //     // 2. Vote
    //     string memory reason = "I like a do da cha cha";
    //     // 0 = Against, 1 = For, 2 = Abstain for this example
    //     uint8 voteWay = 1;
    //     vm.prank(USER);
    //     governor.castVoteWithReason(proposalId, voteWay, reason);

    //     vm.warp(block.timestamp + VOTING_PERIOD + 1);
    //     vm.roll(block.number + VOTING_PERIOD + 1);

    //     console.log("Proposal State:", uint256(governor.state(proposalId)));

    //     // 3. Queue
    //     bytes32 descriptionHash = keccak256(abi.encodePacked(description));
    //     governor.queue(targets, values, calldatas, descriptionHash);
    //     vm.roll(block.number + MIN_DELAY + 1);
    //     vm.warp(block.timestamp + MIN_DELAY + 1);

    //     // 4. Execute
    //     governor.execute(targets, values, calldatas, descriptionHash);

    //     assert(box.getNumber() == valueToStore);
    // }
}