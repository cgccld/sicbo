// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {console2 as console, StdStyle, BaseDeploy} from "@kit/BaseDeploy.s.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

interface IProxy {
  function upgradeToAndCall(address implementation, bytes memory data) external;
}

abstract contract BaseMigrate is BaseDeploy {
  using StdStyle for *;

  mapping(string => address) internal deployed;

  function deployContract(string memory fileDest, bytes memory args)
    public
    log(string.concat("Deploy for ", fileDest))
    returns (address contractAddress)
  {
    contractAddress = deploy(fileDest, args);
    console.log("Contract address: ".green(), contractAddress);
  }

  function deployUUPSProxy(string memory fileDest, bytes memory args)
    public
    log(string.concat("Deploy uups proxy for ", fileDest))
    returns (address proxy)
  {
    address logic = deploy(fileDest, EMPTY_ARGS);
    proxy = deploy("ERC1967Proxy.sol:ERC1967Proxy", abi.encode(logic, args));
    console.log("Logic address: ".green(), logic);
    console.log("Proxy address: ".green(), proxy);
  }

  function deployTransparentProxy(string memory fileDest, bytes memory args)
    public
    log(string.concat("Deploy transparent proxy for ", fileDest))
    returns (address proxy)
  {
    address logic = deploy(fileDest, EMPTY_ARGS);
    proxy = deploy("TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy", abi.encode(logic, msg.sender, args));
    console.log("Logic address: ".green(), logic);
    console.log("Proxy address: ".green(), proxy);
  }

  function upgradeProxy(string memory fileDest, address proxy, bytes memory args)
    public
    log(string.concat("Upgrade for ", fileDest))
  {
    address logic = deploy(fileDest, EMPTY_ARGS);
    IProxy(proxy).upgradeToAndCall(logic, args);
    console.log("Logic address: ".green(), logic);
    console.log("Proxy address: ".green(), proxy);
  }
}
