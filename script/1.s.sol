// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// PRIVATE_KEY=0x2a7ac0ddfa7148381924d49fa279acf7fbeedb073f0b561c3b1f8bf7a586fd1c

import {Script} from "lib/forge-std/src/Script.sol";
import {console2} from "lib/forge-std/src/console2.sol";

contract Setter {

    address public reader;
    uint private MAGIC_NUMBER;
    uint public YOUR_NUMBER;

    constructor(address _reader, uint num) {
        reader = _reader;
        MAGIC_NUMBER = num;
    }

    modifier onlyReader {
        require(msg.sender == reader);
        _;
    }

    function getNum() external view onlyReader returns (uint) {
        return MAGIC_NUMBER;
    }

    function setYourNum(uint num) external {
        YOUR_NUMBER = num;
    }

    function solved() external view returns (bool) {
        return YOUR_NUMBER == MAGIC_NUMBER;
    }
}

contract SetterScript is Script {

    Setter s = Setter(0x350B75F055FdFD652Da05Ab3b7839aF46fB637C1);

    function setUp() public{}

    function run() public {
        uint pk = vm.envUint("PRIVATE_KEY");
        // address me = vm.addr(pk);

        // console2.log(me);

        vm.startBroadcast(pk);

        // vm.startPrank(0x7956C4729862d28937ec5252d26779D1DAB94B2f);

        s.setYourNum(29676);

        // vm.stopPrank();

        vm.stopBroadcast();

        // console2.log(s.solved());

    }
}
