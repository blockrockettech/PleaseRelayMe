pragma solidity 0.6.2;

import "../SafeMath.sol";
import "../IERC20.sol";
import "../ReentrancyGuard.sol";
import "./RelayHub.sol";
import "../rDAI/IRToken.sol";
import "../liquidity/ILiquidityProvider.sol";
import "./InterestPaymentAccount.sol";

contract rDAIRelayHub is RelayHub, ReentrancyGuard {
    using SafeMath for uint256;

    event DappFunded(
        address indexed dapp,
        address indexed ipa,
        address indexed funder,
        uint256 principleAmount
    );

    event DappFundingRemoved(
        address indexed dapp,
        address indexed funder,
        uint256 originalPrincipleAmount
    );

    event DappFundingReduced(
        address indexed dapp,
        address indexed funder,
        uint256 originalPrincipleAmount,
        uint256 reducedTo
    );

    IERC20 public DAI;
    IRToken public rDAI;

    ILiquidityProvider public liquidityProvider;

    // Dapp contract address to interest payment account (IPA)
    mapping(address => InterestPaymentAccount) public dappToIPA;

    mapping(address => mapping(address => uint256)) public dappToFunderAndTheirPrinciple;

    //---- Start basic threshold configuration section ----

    // Currently set to 1 DAI
    uint256 public minimumDAIPrincipleAmount = 1*10**18;

    // Currently set to 5 DAI
    uint256 public minimumInterestAmountForRefuel = 5*10**18;

    //---- End basic threshold configuration section ----

    constructor(IERC20 _DAI, IRToken _rDAI, ILiquidityProvider _liquidityProvider) public {
        DAI = _DAI;
        rDAI = _rDAI;
        liquidityProvider = _liquidityProvider;
    }

    // Default payable
    receive() external payable {}

    function fundDapp(address dapp, uint256 principleAmount) external nonReentrant {
        require(dapp != address(0), "Invalid dapp address");
        require(principleAmount >= minimumDAIPrincipleAmount, "You need to offer at least the minimum principle amount");

        address self = address(this);
        require(DAI.allowance(msg.sender, self) >= principleAmount, "Not enough DAI allowance");

        // Bring in the principle
        DAI.transferFrom(msg.sender, self, principleAmount);

        // If IPA not created for the dapp, create it
        if(address(dappToIPA[dapp]) == address(0)) {
            bytes32 create2Salt = bytes32(keccak256(abi.encodePacked(dapp)));

            //---Use sugar over CREATE2 to instantiate the contract
            dappToIPA[dapp] = new InterestPaymentAccount{salt: create2Salt}(self);
        }

        address ipaAddress = address(dappToIPA[dapp]);
        address[] memory participants = new address[](1);
        participants[0] = ipaAddress;

        uint32[] memory splits = new uint32[](1);
        splits[0] = 4294967295; // Needs to be equivalent of 100% of the interest generated

        rDAI.mintWithNewHat(principleAmount, participants, splits);

        // At this point, the assumption is that the contract has an rDAI balance and no DAI

        dappToFunderAndTheirPrinciple[dapp][msg.sender] = principleAmount;

        emit DappFunded(dapp, ipaAddress, msg.sender, principleAmount);
    }

    function _refuelFor(address dapp) internal nonReentrant {
        InterestPaymentAccount ipa = dappToIPA[dapp];

        //---Check if there is any accrued interest above minimumInterestAmountForRefuel
        if(ipa.accruedInterest(rDAI) > minimumInterestAmountForRefuel) {
            //---brings DAI into the relay hub from the IPA
            ipa.claimInterest(rDAI, DAI);

            //---Relay hub now has DAI so convert to ether!
            uint256 daiBalance = DAI.balanceOf(address(this));
            DAI.approve(address(liquidityProvider), daiBalance);
            uint256 ethReceived = liquidityProvider.swapDAIToETH(daiBalance);

            //---Update ETH balance of dapp
            _depositFromIPA(dapp, ethReceived, address(ipa));
        }
    }

    function relayCall(
        address from,
        address recipient,
        bytes memory encodedFunction,
        uint256 transactionFee,
        uint256 gasPrice,
        uint256 gasLimit,
        uint256 nonce,
        bytes memory signature,
        bytes memory approvalData
    ) public override {
        if(maxPossibleCharge(gasLimit, gasPrice, transactionFee) <= balances[recipient]) {
            // Attempt to top up dapp's balance from any accrued interest if applicable
            _refuelFor(recipient);
        }

        super.relayCall(
            from,
            recipient,
            encodedFunction,
            transactionFee,
            gasPrice,
            gasLimit,
            nonce,
            signature,
            approvalData
        );
    }

    function removeAllDappFunding(address dapp) external nonReentrant {
        require(dapp != address(0), "Invalid dapp address");
        require(address(dappToIPA[dapp]) != address(0), "The dapp has not been funded yet");

        uint256 fundersPrinciple = dappToFunderAndTheirPrinciple[dapp][msg.sender];
        require(fundersPrinciple > 0, "You have not put down a principle for this dapp");

        // Should not get here but sensible to check that our rDAI balance is greater than or eq to principle being refunded

        dappToFunderAndTheirPrinciple[dapp][msg.sender] = 0;

        // Redeem the underlying DAI
        rDAI.redeem(fundersPrinciple);

        // Give the funder back their principle
        DAI.transfer(msg.sender, fundersPrinciple);

        emit DappFundingRemoved(dapp, msg.sender, fundersPrinciple);
    }

    function reduceDappFunding(address dapp, uint256 reduceTo) external nonReentrant {
        require(dapp != address(0), "Invalid dapp address");
        require(address(dappToIPA[dapp]) != address(0), "The dapp has not been funded yet");

        uint256 fundersPrinciple = dappToFunderAndTheirPrinciple[dapp][msg.sender];
        require(fundersPrinciple > reduceTo, "Either you have not put down a principle or your reduction is not less than original principle");

        // Should not get here but sensible to check that our rDAI balance is greater than or eq to principle being refunded

        dappToFunderAndTheirPrinciple[dapp][msg.sender] = reduceTo;

        uint256 amountToSendBack = fundersPrinciple.sub(reduceTo);

        // Redeem the underlying DAI
        rDAI.redeem(amountToSendBack);

        // Give the funder back the DAI
        DAI.transfer(msg.sender, amountToSendBack);

        emit DappFundingReduced(dapp, msg.sender, fundersPrinciple, reduceTo);
    }

    // ***
    // Pseudo-code for the flipFunding() function
    // ---
    // This function would allow a dapp funder to direct / flip the interest being accrued towards another dapp
    // i.e. they would stop funding one dapp and fund another with their interest.
    // ---
    // The basics of this involves updating the rDAI config for a dapp
    // ***
    // function flipFunding() external nonReentrant
    //      TODO

    /**
    * internal method implemented that mostly follows original depositFor from the RelayHub contract
    */
    function _depositFromIPA(address target, uint256 amount, address from) internal {
        balances[target] = balances[target].add(amount);
        emit Deposited(target, from, amount);
    }
}