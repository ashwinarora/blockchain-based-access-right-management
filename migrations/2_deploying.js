var PermissionManagement = artifacts.require("./PermissionManagement.sol");
var NotarizationManagement = artifacts.require("./NotarizationManagement.sol");

module.exports = function(deployer) {
  deployer.deploy(PermissionManagement);
  deployer.deploy(NotarizationManagement);
};
