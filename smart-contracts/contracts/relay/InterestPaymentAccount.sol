pragma solidity 0.6.2;

import "../SafeMath.sol";
import "../IERC20.sol";
import "../rDAI/IRToken.sol";
import "../ReentrancyGuard.sol";

// I.e. the IPA of a dapp
contract InterestPaymentAccount is ReentrancyGuard {
    using SafeMath for uint256;

    event IPAFunded(
        address indexed funder,
        address indexed dapp,
        address indexed relayHub,
        uint256 principleAmount
    );

    event IPAFundingRemoved(
        address indexed funder,
        address indexed dapp,
        address indexed relayHub,
        uint256 originalPrincipleAmount
    );

    event IPAFundingReduced(
        address indexed funder,
        address indexed dapp,
        address indexed relayHub,
        uint256 originalPrincipleAmount,
        uint256 reducedTo
    );

    IRToken public rDAI;
    IERC20 public DAI;

    // ID for the interest distribution configuration in IRToken
    uint256 public hatID;

    address public relayHub;

    address public dapp;

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

        rDAI.mintWithSelectedHat(principleAmount, hatID);

        // At this point, the assumption is that the contract has an rDAI balance and no DAI

        emit IPAFunded(funder, dapp, relayHub, principleAmount);
    }

    function removeAllDappFunding(address funder) external nonReentrant {
        uint256 fundersPrinciple = funderToPrinciple[funder];
        require(fundersPrinciple > 0, "You have not put down a principle for this dapp");

        // Should not get here but sensible to check that our rDAI balance is greater than or eq to principle being refunded

        funderToPrinciple[funder] = 0;

        // Redeem the underlying DAI
        rDAI.redeem(fundersPrinciple);

        // Give the funder back their principle
        DAI.transfer(funder, fundersPrinciple);

        emit IPAFundingRemoved(funder, dapp, relayHub, fundersPrinciple);
    }

    function reduceDappFunding(address funder, uint256 reduceTo) external nonReentrant {
        uint256 fundersPrinciple = funderToPrinciple[funder];
        require(fundersPrinciple > reduceTo, "Either you have not put down a principle or your reduction is not less than original principle");

        // Should not get here but sensible to check that our rDAI balance is greater than or eq to principle being refunded

        funderToPrinciple[funder] = reduceTo;

        uint256 amountToSendBack = fundersPrinciple.sub(reduceTo);

        // Redeem the underlying DAI
        rDAI.redeem(amountToSendBack);

        // Give the funder back the DAI
        DAI.transfer(funder, amountToSendBack);

        emit IPAFundingReduced(funder, dapp, relayHub, fundersPrinciple, reduceTo);
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