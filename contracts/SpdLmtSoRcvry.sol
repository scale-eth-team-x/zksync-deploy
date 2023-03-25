// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Wallet.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "hardhat/console.sol";

// This contract is implemented as ERC4337: account abstraction without Ethereum protocol change
// Also simple social recovery function is implemented

contract SpdLmtSoRcvry is ERC165, IERC1271, Wallet {
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

    struct RecoveryRequest {
        address newOwner;
        uint256 requestedAt;
    }

    uint256 public recoveryConfirmationTime = 1;
    address public guardian;
    RecoveryRequest public recoveryRequest;

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

    // Social Recovery Part

    function setGuardian(address guardian_) public onlyOwner {
        guardian = guardian_;
    }

    function setRecoveryConfirmationTime(
        uint256 recoveryConfirmationTime_
    ) public onlyOwner {
        recoveryConfirmationTime = recoveryConfirmationTime_;
    }

    function initRecovery(address newOwner) public {
        require(msg.sender == guardian, "SocialRecovery: msg sender invalid");
        uint256 requestedAt = block.timestamp;
        recoveryRequest = RecoveryRequest({
            newOwner: newOwner,
            requestedAt: requestedAt
        });
    }

    function cancelRecovery() public {
        require(msg.sender == owner, "SocialRecovery: msg sender invalid");
        require(
            recoveryRequest.newOwner != address(0x0),
            "SocialRecovery: request invalid"
        );
        delete recoveryRequest;
    }

    function executeRecovery() public {
        require(
            msg.sender == owner || msg.sender == guardian,
            "SocialRecovery: msg sender invalid"
        );
        require(
            recoveryRequest.requestedAt + recoveryConfirmationTime <
                block.timestamp,
            "SocialRecovery: recovery confirmation time not passed"
        );
        owner = recoveryRequest.newOwner;
        delete recoveryRequest;
    }

    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view override returns (bytes4) {
        address recovered = ECDSA.recover(_hash, _signature);
        if (recovered == owner) {
            return type(IERC1271).interfaceId;
        } else {
            return 0xffffffff;
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC1271).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}