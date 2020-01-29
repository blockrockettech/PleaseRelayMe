pragma solidity 0.6.2;

interface ILiquidityProvider {
    function swapDAIToETH(uint256 quantity) external returns(uint256);
}