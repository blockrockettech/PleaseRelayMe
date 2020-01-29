pragma solidity 0.6.2;

import "../SafeMath.sol";
import "../IERC20.sol";
import "./RelayHub.sol";
import "../rDAI/IRToken.sol";
import "../liquidity/ILiquidityProvider.sol";
import "./InterestPaymentAccount.sol";

contract rDAIRelayHub is RelayHub {
    using SafeMath for uint256;

    event DappSetup(
        address indexed dapp,
        address indexed ipa,
        address indexed caller,
        uint256 principleAmount
    );

    IERC20 public DAI;
    IRToken public rDAI;

    ILiquidityProvider public liquidityProvider;

    // Dapp contract address to interest payment account (IPA)
    mapping(address => InterestPaymentAccount) public dappToIPA;

    // Default payable
    receive() external payable {}

    function setupDapp(address dapp, uint256 principleAmount) external {
        require(address(dappToIPA[dapp]) == address(0), "An Interest Payment Account already exists for this dapp");
        require(DAI.allowance(msg.sender, address(this)) >= principleAmount, "Not enough DAI allowance");
        DAI.transferFrom(msg.sender, address(this), principleAmount);

        //---Counterfactually determine the deployment address of the dapp's Interest Payment Account (IPA)
        bytes32 salt = bytes32(keccak256(abi.encodePacked(dapp)));
        address ipaAddress = address(bytes20(keccak256(abi.encodePacked(
            byte(0xff),
            address(this),
            salt,
            keccak256(abi.encodePacked(
                type(InterestPaymentAccount).creationCode
            ))
        ))));

        address[] memory participants = new address[](1);
        participants[0] = ipaAddress;

        uint32[] memory splits = new uint32[](1);
        splits[0] = 100; // Need to do the real calculation which is equivalent of 100% of the interest generated

        rDAI.mintWithNewHat(principleAmount, participants, splits);

        //---Use sugar over CREATE2 to counterfactually instantiate the contract:
        InterestPaymentAccount ipa = new InterestPaymentAccount{salt: salt}();
        require(ipaAddress == address(ipa), "Counterfactual address mismatch on instantiation of Interest Payment Account");

        //---Store the counterfactual IPA in `dappToIPA` mapping
        dappToIPA[dapp] = ipa;

        emit DappSetup(dapp, ipaAddress, msg.sender, principleAmount);
    }

    function refuelFor(address dapp) external {
        InterestPaymentAccount ipa = dappToIPA[dapp];

        //---Check if there is any accrued interest with: ipa.accruedInterest()
        if(ipa.accruedInterest() > 0) {
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

    /**
    * internal method implemented that mostly follows original depositFor from the RelayHub contract
    */
    function _depositFromIPA(address target, uint256 amount, address from) internal {
        balances[target] = SafeMath.add(balances[target], amount);

        emit Deposited(target, from, amount);
    }
}