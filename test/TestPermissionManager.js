var PermissionManagement = artifacts.require("PermissionManagement.sol");

contract('PermissionManagement', (accounts)=> {
  var master = accounts[0];
  var owner = accounts[1];
  var writer = accounts[2];
  var reader = accounts[3];
  var hash = "0x38626630313632393933366636616133303132646561616662663865323164";

  it('should call newDocument with hash and delegate caller as master', () => {
    return PermissionManagement.deployed().then(instance => {
      return instance.newDocument(hash);
    });
  });

it('should delegate new owner', () => {
  return PermissionManagement.deployed().then(instance => {
    return instance.delegatePermanentOwner(owner,hash);
  });
});


it('should remove owner', () => {
  return PermissionManagement.deployed().then(instance => {
    return instance.removePermanentOwner(owner,hash);
  });
});

it('should delegate new writer', () => {
  return PermissionManagement.deployed().then(instance => {
    return instance.delegatePermanentWrite(writer,hash);
  });
});


it('should remove writer', () => {
  return PermissionManagement.deployed().then(instance => {
    return instance.removePermanentWrite(writer,hash);
  });
});

it('should delegate new reader', () => {
  return PermissionManagement.deployed().then(instance => {
    return instance.delegatePermanentRead(reader,hash);
  });
});


it('should remove reader', () => {
  return PermissionManagement.deployed().then(instance => {
    return instance.removePermanentRead(reader,hash);
  });
});




});
