// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";

contract InvariantTest is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine dsce;
    function setUp() external {
        deployer = new DeployDSC();
        dsce = deployer.run();
    }
}