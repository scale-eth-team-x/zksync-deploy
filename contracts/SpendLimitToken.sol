// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Wallet.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

// This contract is implemented as ERC4337: account abstraction without Ethereum protocol change
// Also simple social recovery function is implemented
 
contract SpendLimitToken is ERC165, Wallet {
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

    // uint public ONE_DAY = 24 hours;
    uint public ONE_DAY = 1 minutes; // set to 1 min for tutorial
    mapping(address => Limit) limits; // token => Limit

    /// this function enables a daily spending limit for specific tokens.
    /// @param _token ETH or ERC20 token address that a given spending limit is applied.
    /// @param _amount non-zero limit.
    function setSpendingLimit(address _token, uint _amount) public onlyOwner {
        require(_amount != 0, "Invalid amount");

        uint resetTime;
        uint timestamp = block.timestamp; // L1 batch timestamp

        if (_isValidUpdate(_token)) {
            resetTime = timestamp + ONE_DAY;
        } else {
            resetTime = timestamp;
        }

        _updateLimit(_token, _amount, _amount, resetTime, true);
    }

    // this function disables an active daily spending limit,
    // decreasing each uint number in the Limit struct to zero and setting isEnabled false.
    function removeSpendingLimit(address _token) public onlyOwner {
        require(_isValidUpdate(_token), "Invalid Update");
        _updateLimit(_token, 0, 0, 0, false);
    }

    // verify if the update to a Limit struct is valid
    // Ensure that users can't freely modify(increase or remove) the daily limit to spend more.
    function _isValidUpdate(address _token) internal view returns (bool) {
        // Reverts unless it is first spending after enabling
        // or called after 24 hours have passed since the last update.
        if (limits[_token].isEnabled) {
            require(
                limits[_token].limit == limits[_token].available ||
                    block.timestamp > limits[_token].resetTime,
                "Invalid Update"
            );

            return true;
        } else {
            return false;
        }
    }

    // storage-modifying private function called by either `dingLimit or removeSpendingLimit
    function _updateLimit(
        address _token,
        uint _limit,
        uint _available,
        uint _resetTime,
        bool _isEnabled
    ) private {
        Limit storage limit = limits[_token];
        limit.limit = _limit;
        limit.available = _available;
        limit.resetTime = _resetTime;
        limit.isEnabled = _isEnabled;
    }

    // this function is called by the account before execution.
    // Verify the account is able to spend a given amount of tokens. And it records a new available amount.
    function _checkSpendingLimit(address _token, uint _amount) internal {
        Limit memory limit = limits[_token];

        // return if spending limit hasn't been enabled yet
        if (!limit.isEnabled) return;

        uint timestamp = block.timestamp; // L1 batch timestamp

        // Renew resetTime and available amount, which is only performed
        // if a day has already passed since the last update: timestamp > resetTime
        if (limit.limit != limit.available && timestamp > limit.resetTime) {
            limit.resetTime = timestamp + ONE_DAY;
            limit.available = limit.limit;

            // Or only resetTime is updated if it's the first spending after enabling limit
        } else if (limit.limit == limit.available) {
            limit.resetTime = timestamp + ONE_DAY;
        }

        // reverts if the amount exceeds the remaining available amount.
        require(limit.available >= _amount, "Exceed daily limit");

        // decrement `available`
        limit.available -= _amount;
        limits[_token] = limit;
    }

    function getLimit(address _token) public view returns (uint) {
        return limits[_token].limit;
    }

    function getLimitInfo(address _token) public view returns (Limit memory) {
        return limits[_token];
    }
}
