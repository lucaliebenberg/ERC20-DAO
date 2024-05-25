// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";


contract TimeLock is TimelockController {
    constructor(uint256 mintdelay, address[] memory proposers, address[] memory executors) 
    TimelockController(mintdelay, proposers, executors, msg.sender)
    {
        
    }
}