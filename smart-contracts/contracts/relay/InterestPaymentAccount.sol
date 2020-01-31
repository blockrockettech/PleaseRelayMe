pragma solidity 0.6.2;

import "../IERC20.sol";
import "../rDAI/IRToken.sol";
import "../ReentrancyGuard.sol";

// I.e. the IPA of a dapp
contract InterestPaymentAccount is ReentrancyGuard {
    IRToken public rDAI;
    IERC20 public DAI;

    // ID for the interest distribution configuration in IRToken
    uint256 hatID;

    address relayHub;

    address dapp;

    mapping(address => uint256) public funderToPrinciple;

    modifier onlyRelayHub() {
        require(msg.sender == relayHub, "Only the relay hub can call this method");
        _;
    }

    constructor(address _relayHub, address _dapp, IRToken _rDAI, IERC20 _DAI) public {
        // Set up addresses and contracts
        dapp = _dapp;
        relayHub = _relayHub;
        rDAI = _rDAI;
        DAI = _DAI;

        // Create a hat for this IPA
        address ipaAddress = address(this);
        address[] memory participants = new address[](1);
        participants[0] = ipaAddress;

        uint32[] memory splits = new uint32[](1);
        splits[0] = 4294967295; // Needs to be equivalent of 100% of the interest generated

        hatID = rDAI.createHat(participants, splits, true);
    }

    function fund(address funder, uint256 principleAmount) external nonReentrant {
        funderToPrinciple[funder] = principleAmount;

        rDAI.mint(principleAmount);

        // At this point, the assumption is that the contract has an rDAI balance and no DAI

        // todo emit ipa funded event
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