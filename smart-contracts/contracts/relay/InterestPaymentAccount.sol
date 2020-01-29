pragma solidity 0.6.2;

import "../IERC20.sol";
import "../rDAI/IRToken.sol";

contract InterestPaymentAccount {
    IERC20 public DAI;
    IRToken public rDAI;

    address relayHub;

    modifier onlyRelayHub() {
        require(msg.sender == relayHub, "Only the relay hub can call this method");
        _;
    }

    function accruedInterest() external view returns (uint256) {
        return rDAI.interestPayableOf(address(this));
    }

    function claimInterest() onlyRelayHub external returns (bool) {
        rDAI.payInterest(address(this));

        rDAI.redeemAll();

        DAI.transfer(relayHub, DAI.balanceOf(address(this)));

        return true;
    }
}