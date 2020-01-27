pragma solidity 0.5.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./RelayHub.sol";
import "../rDAI/IRToken.sol";
import "../liquidity/UniswapExchangeInterface.sol";

contract rDAIRelayHub is RelayHub {
    using SafeMath for uint256;

    address ETH_PROXY = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address KYBER_NETWORK_PROXY_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function refuelFor(address target, IRToken rDai, IERC20 dai, UniswapExchangeInterface uniswap) external {
        // 1. Claim earned rDAI interest
        address self = address(this);
        bool interestClaimSuccess = rDai.payInterest(self);
        require(interestClaimSuccess, "Failed to claim interest earned for target");

        // 2. Redeem underlying DAI from rDAI contract
        bool redeemSuccess = rDai.redeemAll();
        require(redeemSuccess, "Failed to redeem underlying DAI from interest paid");

        // 3. TODO: Swap DAI for ETH
        dai.approve(KYBER_NETWORK_PROXY_ADDRESS, dai.balanceOf(self));
        uint256 ethReceivedFromDaiSale = 0;

        // 4. Update target contract's relay balance
        balances[target] = balances[target].add(ethReceivedFromDaiSale);

        emit Deposited(target, msg.sender, ethReceivedFromDaiSale);
    }
}