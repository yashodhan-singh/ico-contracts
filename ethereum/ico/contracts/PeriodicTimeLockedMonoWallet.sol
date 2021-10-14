// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./CollectCoin.sol";
import "./ICollectCoinIco.sol";

contract PeriodicTimeLockedMonoWallet
{
    address public creator;
    uint256 public unlockDate;
    uint256 public createdAt;

    uint256 public unlockPeriod;
    uint public unlockPercentage;
    address tokenOwner;

    ICollectCoinIco public icoContract;

    mapping (address => uint256) private claimedAmountOf;

    event WithdrewTokens(address tokenContract, address to, uint256 amount);

    constructor(address _creator, ICollectCoinIco _icoContract, uint256 _unlockDate, uint256 _unlockPeriod, uint _unlockPercentage, address _tokenOwner)
    {
        creator = _creator;
        icoContract = _icoContract;

        unlockDate = _unlockDate;
        createdAt = block.timestamp;
        tokenOwner = _tokenOwner;

        // unlockedAmount = 0;
        unlockPeriod = _unlockPeriod;
        unlockPercentage = _unlockPercentage;
    }

    receive() external payable
    {
        // we do not accept any native coin on this wallet
        revert();
    }

    // callable by owner only, after specified time, only for Tokens implementing ERC20
    function withdrawTokens(address _tokenContract) public 
    {
       //require(block.timestamp >= unlockDate);

       CollectCoin token = CollectCoin(_tokenContract);

       //now send all the token balance
       uint256 unlockedTokenAmount = getUnlockedTokenAmount();
       
       claimedAmountOf[msg.sender] += unlockedTokenAmount;

       token.transferFrom(tokenOwner, msg.sender, unlockedTokenAmount);
       emit WithdrewTokens(_tokenContract, msg.sender, unlockedTokenAmount);
    }

    function balance() public view returns (uint256) {
        return icoContract.tokenAmountOf(msg.sender) - claimedAmountOf[msg.sender];
    }

    function claimed() public view returns (uint256) {
        return claimedAmountOf[msg.sender];
    }

    function getUnlockedTokenAmount() public view returns (uint256)
    {
        uint256 totaltokenAmount = icoContract.tokenAmountOf(msg.sender);

        // the amount of tokens already unlocked and transferred
        uint256 claimedAmount = claimedAmountOf[msg.sender];

        int256 timeDiff = int256(block.timestamp) - int256(unlockDate);

        if(timeDiff < 0) 
        {
            // still locked
            return 0;
        }

        uint unlockedUnits = (uint256(timeDiff) / unlockPeriod) + 1;

        uint multiplier = unlockedUnits * unlockPercentage >= 100 ? 100 : unlockedUnits * unlockPercentage;

        return (multiplier * totaltokenAmount) / 100 - claimedAmount;
    }
}