const rDAIRelayHub = artifacts.require('rDAIRelayHub');

module.exports = async function (deployer, network, accounts) {
    console.log(`Deploying rDAI Relay Hub on [${network}] using [${accounts[0]}]`);
    const hub = deployer.deploy(rDAIRelayHub, {from: accounts[0]});
    console.log(`Deployed at ${hub.address}`);
};