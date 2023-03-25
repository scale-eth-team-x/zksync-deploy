// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Wallet.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "hardhat/console.sol";

// This contract is implemented as ERC4337: account abstraction without Ethereum protocol change
// Also simple social recovery function is implemented

contract SpendLimit is ERC165, Wallet {
    constructor(
        IEntryPoint anEntryPoint,
        address anOwner
    ) Wallet(anEntryPoint, anOwner) {}

    struct Limit {
        uint limit;
        uint available;
        uint resetTime;
        bool isEnabled;
    }

    mapping(address => Limit) limits; // token => Limit

    /// this function enables a daily spending limit for ETH only.
    /// @param _amount non-zero limit.
    function setSpendingLimit(uint _amount) public onlyOwner {
        require(_amount != 0, "Invalid amount");
        require(limits[address(0)].isEnabled, "Spend Limit Func haven't enabled");

        uint resetTime;
        uint timestamp = block.timestamp; // L1 batch timestamp

        if (_isValidUpdate()) {
            resetTime = 300 + timestamp;
        } else {
            resetTime = timestamp;
        }

        _updateLimit(_amount, _amount, resetTime, true);
    }

    function enableSpendLimit() public onlyOwner {
        limits[address(0)].isEnabled = true;
    }

    // this function disables an active daily spending limit,
    // decreasing each uint number in the Limit struct to zero and setting isEnabled false.
    function removeSpendingLimit() public onlyOwner {
        require(_isValidUpdate(), "Invalid Update");
        _updateLimit(0, 0, 0, false);
    }

    // verify if the update to a Limit struct is valid
    // Ensure that users can't freely modify(increase or remove) the daily limit to spend more.
    function _isValidUpdate() internal view returns (bool) {
        // Reverts unless it is first spending after enabling
        // or called after 24 hours have passed since the last update.
        if (limits[address(0)].isEnabled) {
            require(
                limits[address(0)].limit == limits[address(0)].available ||
                    block.timestamp > limits[address(0)].resetTime,
                "Invalid Update"
            );

            return true;
        } else {
            return false;
        }
    }

    // storage-modifying private function called by either `setSpendingLimit` or `removeSpendingLimit`
    function _updateLimit(
        uint _limit,
        uint _available,
        uint _resetTime,
        bool _isEnabled
    ) private {
        Limit storage limit = limits[address(0)];
        limit.limit = _limit;
        limit.available = _available;
        limit.resetTime = _resetTime;
        limit.isEnabled = _isEnabled;
    }

    function _checkSpendingLimit(uint _amount) internal {
        uint timestamp = block.timestamp; // L1 batch timestamp
        Limit memory limit = limits[address(0)];

        if (!limit.isEnabled) return;

        if (timestamp > limit.resetTime) {
            limit.resetTime = 300 + timestamp;
            limit.available = limit.limit;
        }

        require(limit.available >= _amount, "Exceed daily limit");

        limit.available -= _amount;

        limits[address(0)] = limit;
    }

    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external virtual override {
        _requireFromEntryPointOrOwner();
        _checkSpendingLimit(value);
        _call(dest, value, func);
    }

    function getLimit() public view returns (uint) {
        return limits[address(0)].limit;
    }

    function getLimitInfo() public view returns (Limit memory) {
        return limits[address(0)];
    }
}