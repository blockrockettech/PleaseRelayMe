pragma solidity 0.5.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./RelayHub.sol";
import "../rDAI/IRToken.sol";
import "../liquidity/KyberNetworkInterface.sol";

contract rDAIRelayHub is RelayHub {
    using SafeMath for uint256;

    address ETH_PROXY = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address KYBER_NETWORK_PROXY_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function refuelFor(address target, IRToken rDai, IERC20 dai, KyberNetworkInterface kyber) external {
        // 1. Claim earned rDAI interest
        address self = address(this);
        bool interestClaimSuccess = rDai.payInterest(self);
        require(interestClaimSuccess, "Failed to claim interest earned for target");

        // 2. Redeem underlying DAI from rDAI contract
        bool redeemSuccess = rDai.redeemAll();
        require(redeemSuccess, "Failed to redeem underlying DAI from interest paid");

        // 3. TODO: Swap DAI for ETH
        uint256 daiBalance = dai.balanceOf(self);
        dai.approve(KYBER_NETWORK_PROXY_ADDRESS, daiBalance);

        (uint expectedDaiEthExhangeRate, ) = kyber.getExpectedRate(dai, IERC20(ETH_PROXY), daiBalance);
        uint256 ethReceivedFromDaiSale = kyber.tradeWithHint(
            self,
            dai,
            daiBalance,
            IERC20(ETH_PROXY),
            self,
            2**256 - 1,
            expectedDaiEthExhangeRate,
            address(0),
            abi.encodePacked(uint256(0))
        );

        // 4. Update target contract's relay balance
        balances[target] = balances[target].add(ethReceivedFromDaiSale);

        emit Deposited(target, msg.sender, ethReceivedFromDaiSale);
    }
}