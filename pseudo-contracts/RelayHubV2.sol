pragma solidity ^0.6.2;

import "./InterestPaymentAccount.sol";

contract RelayHubV2 is RelayHub {
    IERC20 public DAI;
    IRToken public rDAI;
    ILiquidityProvider public liquidityProvider;

    // Dapp contract address to interest payment account (IPA)
    mapping(address => InterestPaymentAccount) public dappToIPA;

    // Front-end coordinates approval required for this
    function setupDapp(address dapp, uint256 principleAmount) {
        //DAI.transferFrom(msg.sender, address(this), principleAmount);

        //---Counterfactually determine the deployment address of the dapp's Interest Payment Account (IPA)

        //---Create a hat which directs all interest earned by the principle to the IPA of the dapp
        //rDAI.createHat([address(dappToIPA[dapp])], [100%], true)

        //rDAI.mint(principleAmount);

        //---Could alternatively wrap the two lines above up with: rDAI.mintWithNewHat(principleAmount, [address(dappToIPA[dapp])], [100%]); but this untested by us

        //---Use sugar over CREATE2 to counterfactually instantiate the contract:
        //new InterestPaymentAccount{salt: dapp}();

        //---Store the counterfactual IPA in `dappToIPA` mapping
    }

    function refuelDapp(address dapp) {
        // InterestPaymentAccount ipa = dappToIPA[dapp]

        //---Check if there is any accrued interest with: ipa.accruedInterest()
            //---If yes, then
            //ipa.claimInterest()
            //---the above brings DAI into the relay hub from the IPA

            //---Relay hub now has DAI so convert to ether!
            //uint256 daiBalance = DAI.balanceOf(address(this))
            //DAI.approve(address(liquidityProvider), daiBalance)
            //uint256 ethReceived = liquidityProvider.swapDAIToETH(daiBalance)

            //---Update ETH balance of dapp
            //balances[dapp] = balances[dapp].add(ethReceived);
    }
}