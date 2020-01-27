pragma solidity 0.5.12;

import "./RelayHub.sol";
import "../rDAI/IRToken.sol";
import "../liquidity/UniswapExchangeInterface.sol";

contract rDAIRelayHub is RelayHub {
    function refuelFor(address target, IRToken rDai, UniswapExchangeInterface uniswap) external {
        // 1. Claim earned rDAI interest
        bool interestClaimSuccess = rDai.payInterest(address(this));
        require(interestClaimSuccess, "Failed to claim interest earned for target");

        // 2. Redeem underlying DAI from rDAI contract
        bool redeemSuccess = rDai.redeemAll();
        require(redeemSuccess, "Failed to redeem underlying DAI from interest paid");

        // 3. Swap DAI for ETH
        // 4. Update target contract's relay balance
    }
}