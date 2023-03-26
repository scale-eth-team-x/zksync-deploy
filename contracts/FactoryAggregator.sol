// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

contract FactoryAggregator {
    
    struct FactoryDetails {
        address factoryAddress;
        string factoryName;
        string factoryDescription;
        bool audited;
    }

    mapping(address => FactoryDetails) public factories;
    address[] public factoryAddresses;

    function addFactory(address _factoryAddress, string memory _factoryName, string memory _factoryDescription, bool _audited) public {
        factories[_factoryAddress] = FactoryDetails(_factoryAddress, _factoryName, _factoryDescription, _audited);
        factoryAddresses.push(_factoryAddress);
    }

    function getSingleFactory(address _factoryAddress) public view returns (FactoryDetails memory) {
        return factories[_factoryAddress];
    }

    function getAllFactories() public view returns (FactoryDetails[] memory) {
        FactoryDetails[] memory allFactories = new FactoryDetails[](factoryAddresses.length);
        for (uint i = 0; i < factoryAddresses.length; i++) {
            allFactories[i] = factories[factoryAddresses[i]];
        }
        return allFactories;
    }
}