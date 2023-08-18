// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {
    ExampleExternalContract public exampleExternalContract;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTimestamps;

    uint256 public constant rewardRatePerSecond = 0.1 ether;
    uint256 public withdrawalDeadline = block.number + 3;
    uint256 public claimDeadline = block.number + 5;
    uint256 public currentBlock;
    address public owner;
    // Events
    event Stake(address indexed sender, uint256 amount);
    event Received(address, uint);
    event Execute(address indexed sender, uint256 amount);

    // Modifiers
    /*
  Checks if the withdrawal period has been reached or not
  */
    modifier withdrawalDeadlineReached(bool requireReached) {
        uint256 timeRemaining = withdrawalTimeLeft();
        console.log("timeRemaining: %d", timeRemaining);
        if (requireReached) {
            require(timeRemaining == 0, "Withdrawal period is not reached yet");
        } else {
            require(timeRemaining > 0, "Withdrawal period has been reached");
        }
        _;
    }

    /*
  Checks if the claim period has ended or not
  */
    modifier claimDeadlineReached(bool requireReached) {
        uint256 timeRemaining = claimPeriodLeft();
        console.log("claimTimeRemaining: %d", timeRemaining);
        if (requireReached) {
            require(timeRemaining == 0, "Claim deadline is not reached yet");
        } else {
            require(timeRemaining > 0, "Claim deadline has been reached");
        }
        _;
    }

    /*
  Requires that the contract only be completed once!
  */
    modifier notCompleted() {
        bool completed = exampleExternalContract.completed();
        require(!completed, "Stake already completed!");
        _;
    }
    modifier isCompleted() {
        bool completed = exampleExternalContract.completed();
        require(completed, "Stake must be completed!");
        _;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "Requires the Owner");
        _;
    }

    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(
            exampleExternalContractAddress
        );
        currentBlock = block.number;
        owner = msg.sender;
    }

    // Stake function for a user to stake ETH in our contract
    function stake()
        public
        payable
        withdrawalDeadlineReached(false)
        claimDeadlineReached(false)
    {
        balances[msg.sender] = balances[msg.sender] + msg.value;
        depositTimestamps[msg.sender] = block.number;
        emit Stake(msg.sender, msg.value);
    }

    /*
  Withdraw function for a user to remove their staked ETH inclusive
  of both principal and any accrued interest
  */
    function withdraw()
        public
        withdrawalDeadlineReached(true)
        claimDeadlineReached(false)
        notCompleted
    {
        require(balances[msg.sender] > 0, "You have no balance to withdraw!");
        uint256 individualBalance = balances[msg.sender];
        uint256 blocksPassed = (block.number - depositTimestamps[msg.sender]);
        console.log(blocksPassed);
        uint256 indBalanceRewards = (individualBalance +
            (2 ** (blocksPassed / 4)) *
            (10 ** 18)) / 10 ** 18;
        console.log(indBalanceRewards);
        balances[msg.sender] = 0;

        // Transfer all ETH via call! (not transfer) cc: https://solidity-by-example.org/sending-ether
        (bool sent, ) = msg.sender.call{value: indBalanceRewards}("");
        require(sent, "RIP; withdrawal failed :( ");
    }

    /*
  Allows any user to repatriate "unproductive" funds that are left in the staking contract
  past the defined withdrawal period
  */
    function execute() public claimDeadlineReached(true) notCompleted {
        uint256 contractBalance = address(this).balance;
        exampleExternalContract.complete{value: address(this).balance}();
    }

    function returnFunds() public claimDeadlineReached(true) isCompleted {
        bool success = exampleExternalContract.returnRepatriateFunds();
        if (success) {
            withdrawalDeadline = block.number + 3;
            claimDeadline = block.number + 5;
        }
    }

    /*
  READ-ONLY function to calculate the time remaining before the minimum staking period has passed
  */
    function withdrawalTimeLeft()
        public
        view
        returns (uint256 withdrawalTimeLeft)
    {
        if (block.number >= withdrawalDeadline) {
            return (0);
        } else {
            return (withdrawalDeadline - block.number);
        }
    }

    /*
  READ-ONLY function to calculate the time remaining before the minimum staking period has passed
  */
    function claimPeriodLeft() public view returns (uint256 claimPeriodLeft) {
        if (block.number >= claimDeadline) {
            return (0);
        } else {
            return (claimDeadline - block.number);
        }
    }

    /*
  Time to "kill-time" on our local testnet
  */
    function killTime() public {
        currentBlock = block.number;
    }

    /*
  \Function for our smart contract to receive ETH
  cc: https://docs.soliditylang.org/en/latest/contracts.html#receive-ether-function
  */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
