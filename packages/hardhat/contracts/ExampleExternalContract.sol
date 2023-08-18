// SPDX-License-Identifier: MIT
pragma solidity 0.8.4; //Do not change the solidity version as it negativly impacts submission grading

contract ExampleExternalContract {
    address public eoa = 0x1dBB10f6377A2B277C0474eD1aD8aF60F3f5f3eB;
    bool public completed;

    function complete() public payable {
        completed = true;
    }

    function returnRepatriateFunds() public returns(bool) {
        uint256 contractBalance = address(this).balance;
        (bool success, ) = eoa.call{value: contractBalance}("");
        require(success);
        completed = false;
        return success;
    }
}
