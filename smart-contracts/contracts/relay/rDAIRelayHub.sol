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
        address indexed funder
    );

    event DappFundingReduced(
        address indexed dapp,
        address indexed funder,
        uint256 reducedTo
    );

    event DappRefuelled(
        address indexed dapp,
        uint256 daiProvidedFromInterest,
        uint256 ethAdded
    );

    IERC20 public DAI;
    IRToken public rDAI;

    ILiquidityProvider public liquidityProvider;

    // Dapp contract address to interest payment account (IPA)
    mapping(address => InterestPaymentAccount) public dappToIPA;

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

        // If IPA not created for the dapp, create it
        if(address(dappToIPA[dapp]) == address(0)) {
            bytes32 create2Salt = bytes32(keccak256(abi.encodePacked(dapp)));

            //---Use sugar over CREATE2 to instantiate the contract
            dappToIPA[dapp] = new InterestPaymentAccount{salt: create2Salt}(self, dapp, rDAI, DAI);
        }

        InterestPaymentAccount ipa = dappToIPA[dapp];
        address ipaAddress = address(ipa);

        // Send the principle to the IPA
        DAI.transferFrom(msg.sender, ipaAddress, principleAmount);

        // Trigger the funding process in the IPA
        ipa.fund(msg.sender, principleAmount);

        emit DappFunded(dapp, ipaAddress, msg.sender, principleAmount);
    }

    function _refuelFor(address dapp) internal nonReentrant {
        InterestPaymentAccount ipa = dappToIPA[dapp];

        //---Check if there is any accrued interest above minimumInterestAmountForRefuel
        if(ipa.accruedInterest() > minimumInterestAmountForRefuel) {
            //---brings DAI into the relay hub from the IPA
            uint256 interestReceivedInDAI = ipa.claimInterest();

            //---Relay hub now has DAI so convert to ether!
            DAI.approve(address(liquidityProvider), interestReceivedInDAI);
            uint256 ethReceived = liquidityProvider.swapDAIToETH(interestReceivedInDAI);

            //---Update ETH balance of dapp
            _depositFromIPA(dapp, ethReceived, address(ipa));

            emit DappRefuelled(dapp, interestReceivedInDAI, ethReceived);
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

        dappToIPA[dapp].removeAllDappFunding(msg.sender);

        emit DappFundingRemoved(dapp, msg.sender);
    }

    function reduceDappFunding(address dapp, uint256 reduceTo) external nonReentrant {
        require(dapp != address(0), "Invalid dapp address");
        require(address(dappToIPA[dapp]) != address(0), "The dapp has not been funded yet");

        dappToIPA[dapp].reduceDappFunding(msg.sender, reduceTo);

        emit DappFundingReduced(dapp, msg.sender, reduceTo);
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
    function _depositFromIPA(address dapp, uint256 amount, address from) internal {
        balances[dapp] = balances[dapp].add(amount);
        emit Deposited(dapp, from, amount);
    }
}