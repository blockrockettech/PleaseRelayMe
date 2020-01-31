pragma solidity 0.6.2;

import "../liquidity/ILiquidityProvider.sol";

contract MockLiquidityProvider is ILiquidityProvider {
    function swapDAIToETH(uint256 quantity) external override returns(uint256) {
        uint256 ethToTransfer = 0.01 ether;
        msg.sender.transfer(ethToTransfer);
        return ethToTransfer;
    }
}