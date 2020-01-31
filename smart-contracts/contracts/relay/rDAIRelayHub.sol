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
        require(DAI.allowance(msg.sender, address(this)) >= principleAmount, "Not enough DAI allowance");

        // Bring in the principle
        DAI.transferFrom(msg.sender, address(this), principleAmount);

        // If IPA not created for the dapp, create it
        if(address(dappToIPA[dapp]) == address(0)) {
            bytes32 create2Salt = bytes32(keccak256(abi.encodePacked(dapp)));

            //---Use sugar over CREATE2 to instantiate the contract
            dappToIPA[dapp] = new InterestPaymentAccount{salt: create2Salt}();
        }

        address ipaAddress = address(dappToIPA[dapp]);
        address[] memory participants = new address[](1);
        participants[0] = ipaAddress;

        uint32[] memory splits = new uint32[](1);
        splits[0] = 100; // Need to do the real calculation which is equivalent of 100% of the interest generated

        rDAI.mintWithNewHat(principleAmount, participants, splits);

        dappToFunderAndTheirPrinciple[dapp][msg.sender] = principleAmount;

        emit DappFunded(dapp, ipaAddress, msg.sender, principleAmount);
    }

    function _refuelFor(address dapp) internal nonReentrant {
        InterestPaymentAccount ipa = dappToIPA[dapp];

        //---Check if there is any accrued interest above minimumInterestAmountForRefuel
        if(ipa.accruedInterest() > minimumInterestAmountForRefuel) {
            //---brings DAI into the relay hub from the IPA
            ipa.claimInterest();

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

    /**
    * internal method implemented that mostly follows original depositFor from the RelayHub contract
    */
    function _depositFromIPA(address target, uint256 amount, address from) internal {
        balances[target] = balances[target].add(amount);
        emit Deposited(target, from, amount);
    }
}