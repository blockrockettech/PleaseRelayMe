const rDAIRelayHub = artifacts.require('rDAIRelayHub');
const MockLiquidityProvider = artifacts.require('MockLiquidityProvider');

module.exports = async function (deployer, network, accounts) {
    console.log(`Deploying rDAI Relay Hub and mock liqidity provider on [${network}] using [${accounts[0]}]`);

    // Todo: needs swapping out for real liquidity provider
    const liquidityProvider = await deployer.deploy(MockLiquidityProvider, {from: accounts[0]});

    // Todo: replace kovan deployment addresses below
    const DAI = '0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa';
    const rDAI = '0x462303f77a3f17Dbd95eb7bab412FE4937F9B9CB';
    const hub = await deployer.deploy(rDAIRelayHub, DAI, rDAI, liquidityProvider.address, {from: accounts[0]});
    console.log(`Deployed at ${hub.address}`);
};