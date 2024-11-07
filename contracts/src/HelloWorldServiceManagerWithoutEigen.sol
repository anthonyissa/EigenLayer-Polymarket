// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {ECDSAServiceManagerBase} from
    "@eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";
import {ECDSAUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {IERC1271Upgradeable} from "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

struct Bet {
        string name;
        uint endTimestamp;
        bool ended;
        bool yes;
        uint256 yesAmount;
        uint256 noAmount;
        address[] yesUsers;
        address[] noUsers;

    }

contract HelloWorldServiceManagerWithoutEigen is OwnableUpgradeable {
    using ECDSAUpgradeable for bytes32;

    uint public latestBetNum;
    mapping(uint => Bet) public allBets;
    mapping (address => mapping (uint => uint)) public potentialRewards;

    event NewBetCreated(uint betNum, Bet bet);
    event BetEnded(uint betNum);

    function createNewBet(string memory name, uint endTimestamp) public onlyOwner() {
        latestBetNum++;
        allBets[latestBetNum] = Bet({
            name: name,
            endTimestamp: endTimestamp,
            ended: false,
            yes: false,
            yesAmount: 1,
            noAmount: 1,
            yesUsers: new address[](0),
            noUsers: new address[](0)
        });
        emit NewBetCreated(latestBetNum, allBets[latestBetNum]);
    }

    function getCurrentBetOdds(uint betNum) public view returns (uint, uint) {
        uint yesAmount = allBets[betNum].yesAmount;
        uint noAmount = allBets[betNum].noAmount;
        uint totalAmount = yesAmount + noAmount;
        uint yesOdds = (yesAmount * 100) / totalAmount;
        uint noOdds = 100 - yesOdds;
        return (yesOdds, noOdds);
    }

    function bet(uint betNum, bool yes) public payable {
        require(allBets[betNum].ended == false, "Bet has already ended");
        require(allBets[betNum].endTimestamp > block.timestamp, "Bet has already ended");
        if (yes) {  
            allBets[betNum].yesAmount += msg.value;
            allBets[betNum].yesUsers.push(msg.sender);
        } else {
            allBets[betNum].noAmount += msg.value;
            allBets[betNum].noUsers.push(msg.sender);
        }
        savePotentialRewards(betNum, msg.value, yes);
    }

    function savePotentialRewards(uint betNum, uint value, bool yes) private {
        (uint yesOdds, uint noOdds) = getCurrentBetOdds(betNum);
        if (yes) {
            potentialRewards[msg.sender][betNum] = value * yesOdds / 100;
        } else {
            potentialRewards[msg.sender][betNum] = value * noOdds / 100;
        }
    }

    function respondToBet(uint betNum, bool yes) public {
        require(allBets[betNum].ended == false, "Bet has already ended");
        require(allBets[betNum].endTimestamp < block.timestamp, "Bet has not ended yet");
        allBets[betNum].ended = true;
        allBets[betNum].yes = yes;
        distributeRewards(betNum);
        emit BetEnded(betNum);
    }

    function distributeRewards(uint betNum) private {
        bool yes = allBets[betNum].yes;
        address[] memory users = yes ? allBets[betNum].yesUsers : allBets[betNum].noUsers;
        for (uint i = 0; i < users.length; i++) {
            address user = users[i];
            uint reward = potentialRewards[user][betNum];
            (bool success, ) = user.call{value: reward}("");
            require(success, "Failed to send Ether");
        }
    }


}
