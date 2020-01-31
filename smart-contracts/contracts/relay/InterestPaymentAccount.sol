pragma solidity 0.6.2;

import "../IERC20.sol";
import "../rDAI/IRToken.sol";

contract InterestPaymentAccount {
    address relayHub;

    modifier onlyRelayHub() {
        require(msg.sender == relayHub, "Only the relay hub can call this method");
        _;
    }

    constructor(address _relayHub) public {
        relayHub = _relayHub;
    }

    function accruedInterest(IRToken _rDAI) external view returns (uint256) {
        return _rDAI.interestPayableOf(address(this));
    }

    function claimInterest(IRToken _rDAI, IERC20 _DAI) onlyRelayHub external returns (bool) {
        _rDAI.payInterest(address(this));

        _rDAI.redeemAll();

        _DAI.transfer(relayHub, _DAI.balanceOf(address(this)));

        return true;
    }
}