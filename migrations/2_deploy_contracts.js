const Util = artifacts.require('Util.sol');
const NetworkManager = artifacts.require('NetworkManager.sol');

module.exports = function (deployer) {
    deployer.deploy(Util).then(() => {
        deployer.deploy(NetworkManager);
    });
    deployer.link(Util, NetworkManager);
    deployer.deploy(NetworkManager, {gas: 10000000});
};
