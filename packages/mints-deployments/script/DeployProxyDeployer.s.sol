// spdx-license-identifier: mit
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ProxyDeployerScript} from "../src/ProxyDeployerScript.sol";

/// @dev This should be run once on chains to deploye the Mints proxy to;
/// It creates the determinstic proxy deployer on the desired chain,
/// based on the saved byte code and salt a config generated previously in the
/// script SaveProxyDeployerConfig.s.sol
contract DeployProxyDeployer is ProxyDeployerScript {
    function run() public {
        vm.startBroadcast();

        createOrGetDeterministicProxyDeployer();

        vm.stopBroadcast();
    }
}
