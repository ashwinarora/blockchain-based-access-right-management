pragma solidity ^0.4.23;

import "./NotarizationManagement.sol";

/// @title PermissionManagement
/// @author Ashwin Arora
contract PermissionManagement is NotarizationManagement{

  //struct to hold permissions of respective hashes
  struct Permissions{
    address master;
    mapping(address => bool) owner;
    mapping(address => bool) write;
    mapping(address => bool) read;
    uint ownerLength;
    uint writeLength;
    uint readLength;
    mapping(address => bool) isBaseRestricted;
    mapping(address => bool) isTemporarilyUpgraded;
    mapping(address => bool) isUpgradedAgain;
    mapping(address => TimeBounds) ownerTime;
    mapping(address => TimeBounds) writeTime;
    mapping(address => TimeBounds) readTime;
    mapping(address => bool) isOwnerRestricted;
    mapping(address => bool) isWriteRestricted;
    mapping(address => bool) isReadRestricted;
  }
  //how to access above varibles-
  //permissionOf[_hash].owner[_delegate]
  //permissionOf[_hash].ownerTime[_delegate].fromTime
  //permissiosOf[_hash].isBaseRestricted[_delegate]

  /*
  struct AddressDetails{
    bool isBaseRestricted;
    bool isTemporarilyUpgraded;
    bool isUpgradedAgain;
  }
  */

  struct TimeBounds{
    uint256 fromTime;
    uint256 toTime;
  }

  //maps to all the permissions of a particular hash
  //bytes32 to store the hash
  mapping(bytes32 => Permissions) permissionOf;

  event NewDocument(bytes32 hash, address master, uint blockNumber);

  event TimeRestrictedPermission(
    uint blockNumber,
    uint blockTimeStamp,
    bytes32 hash,
    address from,
    address to,
    PermissionType permissionOfFrom,
    PermissionType permissionOfTo,
    uint256 fromTime,
    uint256 toTime
  );

  event TemporaryPermission(
    uint blockNumber,
    uint blockTimeStamp,
    bytes32 hash,
    address from,
    address to,
    PermissionType permissionOfFrom,
    PermissionType permissionOfTo,
    uint256 fromTime,
    uint256 toTime
  );

  constructor() public{
    owner = msg.sender;
  }

  /**
  * @dev use to create a new document with new hash
  * @param _hash hash of the document
  */
  function newDocument(bytes32 _hash) public {
    require(!documentExists(_hash), "Document Already exist");

    ++documentCount;
    permissionOf[_hash].master = msg.sender;
    usedHashes[_hash] = true;
    history.push(DocumentTransfer(block.number, block.timestamp, _hash, msg.sender, msg.sender, PermissionType.master, PermissionType.master));
    emit NewDocument(_hash, msg.sender, block.number);
  }

  /**
  * @dev used to chang the master, caller will loose master access and _delegate will gain master access
  * @param _delegate Ethereum address to whom permission is to be delegated
  * @param _hash hash of the document
  */
  function changeMaster(address _delegate, bytes32 _hash) public{
    require(documentExists(_hash), "Document does not exist");
    require(checkPermission(msg.sender, _hash) == PermissionType.master, "Access Denied");

    permissionOf[_hash].master = _delegate;
    emit NewDocument(_hash, msg.sender, block.number);
    transferDocument( _hash, msg.sender, _delegate, PermissionType.master, PermissionType.master);
  }

  /**
  * @dev use to check what permissions the caller hash
  * @param _hash hash of the document
  */
  function checkYourPermission(bytes32 _hash) public view returns(PermissionType){
    require(documentExists(_hash), "Document does not exist");
    return checkPermission(msg.sender, _hash);
  }

  /**
  * @dev use to check what permissions the delegate hash
  * @param _delegate Ethereum address of whos permission is to be checked
  * @param _hash hash of the document
  */
  function checkDelegatePermission(address _delegate, bytes32 _hash) public view returns (PermissionType) {
    require(documentExists(_hash), "Document does not exist");
    if(checkPermission(msg.sender, _hash) != PermissionType.none ){
      return checkPermission(_delegate, _hash);
    }else{
      revert ("Access Denied");
    }
  }

  /**
  * @dev use to check what permissions the delegate hash
  * @param _delegate Ethereum address of whos permission is to be checked
  * @param _hash hash of the document
  */
  function checkPermission(address _delegate, bytes32 _hash) private view returns (PermissionType){
    if(permissionOf[_hash].master == _delegate){
      return PermissionType.master;
    }
    //checking if the delegte's permission are time restricted or not
    if(permissionOf[_hash].isBaseRestricted[_delegate] == false){
      //checking if there is any upgrade
      if(permissionOf[_hash].isTemporarilyUpgraded[_delegate] == true){
        PermissionType timeRestrictedPermission = checkTimedPermission(_delegate, _hash);
        if(timeRestrictedPermission != PermissionType.none){
          return timeRestrictedPermission;
        }else{
          return checkPermanentPermission(_delegate,_hash);
        }
      }else{
        return checkPermanentPermission(_delegate, _hash);
      }
    }else if(permissionOf[_hash].isBaseRestricted[_delegate] == true){
      return checkTimedPermission(_delegate,_hash);
    }else{
      return PermissionType.none;
    }
  }

  /**
  * @dev use to check just the base permission of delegate
  * @param _delegate Ethereum address of whos permission is to be checked
  * @param _hash hash of the document
  */
  function checkPermanentPermission(address _delegate, bytes32 _hash) private view returns(PermissionType){
    if(isOwner(_delegate, _hash)){
      return PermissionType.owner;
    }else if(isWriter(_delegate, _hash)){
      return PermissionType.write;
    }else if(isReader(_delegate, _hash)){
      return PermissionType.read;
    }else{
      return PermissionType.none;
    }
  }

  /**
  * @dev use to check just the base permission of delegate
  * @param _delegate Ethereum address of whos permission is to be checked
  * @param _hash hash of the document
  */
  function checkTimedPermission(address _delegate, bytes32 _hash) private view returns(PermissionType){
    if(permissionOf[_hash].ownerTime[_delegate].fromTime <= now && permissionOf[_hash].ownerTime[_delegate].toTime > now){
      return PermissionType.owner;
    }else if(permissionOf[_hash].writeTime[_delegate].fromTime <= now && permissionOf[_hash].writeTime[_delegate].toTime > now){
      return PermissionType.write;
    }else if(permissionOf[_hash].readTime[_delegate].fromTime <= now && permissionOf[_hash].readTime[_delegate].toTime > now){
      return PermissionType.read;
    }else{
      return PermissionType.none;
    }
  }

  /**
  * @dev use to delegate owner access to any ethereum address
  * @param _delegate Ethereum address to whom permission is to be delegated
  * @param _hash hash of the document
  */
  function delegatePermanentOwner(address _delegate, bytes32 _hash) public{
    require(documentExists(_hash), "Document does not exist");
    require(permissionOf[_hash].master == msg.sender, "Caller does not has master access");
    require(checkPermission(_delegate, _hash) == PermissionType.none, "Delegate already exists");

    permissionOf[_hash].isBaseRestricted[_delegate] = false;
    permissionOf[_hash].owner[_delegate] = true;
    permissionOf[_hash].ownerLength++;
    transferDocument( _hash, msg.sender, _delegate, PermissionType.master, PermissionType.owner);
  }

  /**
  * @dev use to remove owner access of existing owner
  * @param _delegate Ethereum address to whom permission is to be delegated
  * @param _hash hash of the document
  */
  function removePermanentOwner(address _delegate, bytes32 _hash) public{
    require(documentExists(_hash), "Document does not exist");
    require(checkPermission(msg.sender, _hash) == PermissionType.master, "Sender does not has master access");
    //require(permissionOf[_hash].master == msg.sender, "Caller does not has master access");
    require(checkPermission(_delegate, _hash) == PermissionType.owner, "Not an owner");

    permissionOf[_hash].owner[_delegate] = false;
    permissionOf[_hash].ownerLength--;
    transferDocument( _hash, msg.sender, _delegate, PermissionType.master, PermissionType.none);
  }


  /**
    * @dev use to delegate owner permission with time bounds
    * @param _delegate Ethereum address to whom permission is to be delegated
    * @param _hash hash of the document
    * @param _fromTime Time from which the delegate has access
    * @param _toTime Time till which the delegate has access
    */
  function delegateTimeRestrictedOwner(address _delegate, bytes32 _hash, uint256 _fromTime, uint256 _toTime) public{
    require(documentExists(_hash), "Document does not exist");
    require(block.timestamp <= _fromTime && _fromTime < _toTime, "Invalid time bounds." );
    require(checkPermission(_delegate, _hash) == PermissionType.none, "Delegate already exists");
    PermissionType permissionOfCaller = checkPermission(msg.sender, _hash);
    require(permissionOfCaller == PermissionType.master, "Access Denied");

    if(permissionOf[_hash].writeTime[_delegate].toTime < block.timestamp &&  permissionOf[_hash].readTime[_delegate].toTime < block.timestamp){
      permissionOf[_hash].isBaseRestricted[_delegate] = true;
      permissionOf[_hash].isWriteRestricted[_delegate] = true;
      permissionOf[_hash].writeTime[_delegate].fromTime = _fromTime;
      permissionOf[_hash].writeTime[_delegate].toTime = _toTime;
      emit TimeRestrictedPermission(block.number, block.timestamp, _hash, msg.sender, _delegate, permissionOfCaller, PermissionType.owner, _fromTime, _toTime);
    }else{
      revert("Delegate already exists");
    }
  }

  /**
  * @dev use to remove Owner permission with time bounds
  * @param _delegate Ethereum address to whom permission is to be delegated
  * @param _hash hash of the document
  */
  function removeTimeRestrictedOwner(address _delegate, bytes32 _hash) public{
    require(documentExists(_hash), "Document does not exist");
    require(permissionOf[_hash].isOwnerRestricted[_delegate] == true, "Delegate does not exist.");
    //require(permissionOf[_hash].ownerTime[_delegate].toTime >= block.timestamp, "");
    PermissionType permissionOfCaller = checkPermission(msg.sender, _hash);
    require(permissionOfCaller == PermissionType.master, "Access Denied");

    permissionOf[_hash].isOwnerRestricted[_delegate] = false;
    permissionOf[_hash].ownerTime[_delegate].fromTime = 0;
    permissionOf[_hash].ownerTime[_delegate].toTime = 0;
    emit TimeRestrictedPermission(block.number, block.timestamp, _hash, msg.sender, _delegate, permissionOfCaller, PermissionType.none, 0,0);
  }

  /**
  * @dev use to temporarily upgrade read or write access of an address to owner access
  * @param _delegate Ethereum address whos permission is to be temporarily upgarded
  * @param _hash hash of the document
  * @param _fromTime Time from which the delegate has upgraded write access
  * @param _toTime Time till which the delegate has upgraded write access
  */
  function upgradeToOwner(address _delegate, bytes32 _hash, uint256 _fromTime, uint256 _toTime) public returns (bool success){
    require(documentExists(_hash), "Document does not exists");
    require(block.timestamp <= _fromTime && _fromTime < _toTime, "Invalid Time Bounds.");
    require(permissionOf[_hash].ownerTime[_delegate].toTime < block.timestamp);
    PermissionType permissionOfCaller = checkPermission(msg.sender, _hash);
    require(permissionOfCaller == PermissionType.master , "Access Denied");

    PermissionType permissionOfDelegate = checkPermission(_delegate, _hash);

    //checking if the base permission is restricted of not
    //in case base permission is not restricted
    if(permissionOf[_hash].isBaseRestricted[_delegate] == false){
      //Delegate's Permission can be write in 2 cases
      //1. Base Permission is write
      //2. Base Permission is Read and delegate was previously granted temporary write upgrade
      if(permissionOfDelegate == PermissionType.write){
        //Case 2. Base Permission is Read and delegate is previously granted temporary write upgrade
        if(permissionOf[_hash].writeTime[_delegate].toTime > block.timestamp){
          //checking if given time bounds are inside temporarily upgraded write time bounds
          if(permissionOf[_hash].writeTime[_delegate].toTime > _toTime){
            permissionOf[_hash].isUpgradedAgain[_delegate] = true;
            permissionOf[_hash].isOwnerRestricted[_delegate] = true;
            permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
            permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
            success = true;
            return success;
          }// in case given time bounds begin after the end of write time bounds
          else if(permissionOf[_hash].writeTime[_delegate].toTime < _fromTime){
            permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
            permissionOf[_hash].isOwnerRestricted[_delegate] = true;
            permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
            permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
            success = true;
            return success;
          }else{
            revert("Given Time Bounds are conflicting");
          }
        }
        //Case 1. Base Permission is Write
        else{
          permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
          permissionOf[_hash].isOwnerRestricted[_delegate] = true;
          permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
          permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
          success = true;
          return success;
        }
      }
      //Delegate's permission can be read in 2 cases
      //1. Base permission is Read with no write upgrades later in time
      //2. Base Permission is Read with write upgrade later in times
      else if(permissionOfDelegate == PermissionType.read){
        //Case 2. Base Permission is Read with write upgrades later in times
        if(permissionOf[_hash].writeTime[_delegate].fromTime > block.timestamp){
          //in case given time bounds start and end before the start of write time bounds
          if(permissionOf[_hash].writeTime[_delegate].fromTime > _toTime){
            permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
            permissionOf[_hash].isOwnerRestricted[_delegate] = true;
            permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
            permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
            success = true;
            return success;
          }
          //in case given time bounds are inside write time bounds
          else if(permissionOf[_hash].writeTime[_delegate].fromTime < _fromTime && permissionOf[_hash].writeTime[_delegate].toTime > _toTime){
            permissionOf[_hash].isUpgradedAgain[_delegate] = true;
            permissionOf[_hash].isOwnerRestricted[_delegate] = true;
            permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
            permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
            success = true;
            return success;
          }
          // in case given time bounds begin after the end of write time bounds
          else if(permissionOf[_hash].writeTime[_delegate].toTime < _fromTime){
            permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
            permissionOf[_hash].isOwnerRestricted[_delegate] = true;
            permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
            permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
            success = true;
            return success;
          }else{
            revert("Given Time Bounds are conflicting");
          }
        }
        // Case 1. Base permission is Read with no write upgrades later in time
        else{
          permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
          permissionOf[_hash].isOwnerRestricted[_delegate] = true;
          permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
          permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
          success = true;
          return success;
        }
      }else{
        revert("Base Permission Invalid");
      }
    }
    // in case base is restricted
    else if(permissionOf[_hash].isBaseRestricted[_delegate] == true){
      //Delegates Permission can be read in 2 cases
      //1. Base Permission is read with no write upgrade later in time
      //2. Base Permission is Read with write upgrade later in times
      if(permissionOfDelegate == PermissionType.read){
        //Case 2.  Base Permission is Read with write upgrade later in times
        if(permissionOf[_hash].writeTime[_delegate].toTime > block.timestamp){
          //in case time bounds start and end before the start of write time bounds
          if(permissionOf[_hash].writeTime[_delegate].fromTime > _toTime){
            permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
            permissionOf[_hash].isOwnerRestricted[_delegate] = true;
            permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
            permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
            success = true;
            return success;
          }
          //in case given time bounds are inside write time bounds
          else if(permissionOf[_hash].writeTime[_delegate].fromTime < _fromTime && permissionOf[_hash].writeTime[_delegate].toTime > _toTime){
            permissionOf[_hash].isUpgradedAgain[_delegate] = true;
            permissionOf[_hash].isOwnerRestricted[_delegate] = true;
            permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
            permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
            success = true;
            return success;
          }
          // in case given time bounds begin after the end of write time  bounds and are inside read time bounds
          else if(permissionOf[_hash].writeTime[_delegate].toTime < _fromTime && permissionOf[_hash].readTime[_delegate].toTime > _toTime){
            permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
            permissionOf[_hash].isOwnerRestricted[_delegate] = true;
            permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
            permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
            success = true;
            return success;
          }else{
            revert("Given Time Bounds are conflicting");
          }
        }
        //Case 2. Base Permission is read with no write upgrade later in time
        else{
          //checking if given time bounds are inside read time bounds
          if(permissionOf[_hash].readTime[_delegate].toTime > _toTime){
            permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
            permissionOf[_hash].isOwnerRestricted[_delegate] = true;
            permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
            permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
            success = true;
            return success;
          }else{
            revert("Given Time Bounds are Confliting");
          }
        }
      }
      //Delegate's permission can be write in 2 cases
      //1. Base Permission is write
      //2. Base Permission is Read and delegate was previously granted temporary write upgrade
      else if(permissionOfDelegate == PermissionType.write){
        //Case 2. Base Permission is Read and delegate was previously granted temporary write upgrade
        if(permissionOf[_hash].readTime[_delegate].toTime > block.timestamp){
          //checking if given time bounds are inside temporarily upgraded write time bounds
          if(permissionOf[_hash].writeTime[_delegate].toTime > _toTime){
            permissionOf[_hash].isUpgradedAgain[_delegate] = true;
            permissionOf[_hash].isOwnerRestricted[_delegate] = true;
            permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
            permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
            success = true;
            return success;
          }
          // in case given time bounds begin after the end of write time bounds
          // and checking if given time bounds end before the end of read time bounds
          else if(permissionOf[_hash].writeTime[_delegate].toTime < _fromTime && permissionOf[_hash].readTime[_delegate].toTime > _toTime){
            permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
            permissionOf[_hash].isOwnerRestricted[_delegate] = true;
            permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
            permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
            success = true;
            return success;
          }else{
            revert("Given Time Bounds are conflicting");
          }
        }
        //Case 1. Base Permission is write
        else{
          if(permissionOf[_hash].writeTime[_delegate].toTime > _toTime){
            permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
            permissionOf[_hash].isOwnerRestricted[_delegate] = true;
            permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
            permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
            success = true;
            return success;
          }else{
            revert("Given Time Bounds are conflicting");
          }
        }
      }
      //Permission of delegate can be none when-
      //Delegate has time restricted write access begining later in time
      //Delegate has time restricted read access begining later in time
      else if(permissionOfDelegate == PermissionType.none){
        //Delegate's base permission can be read in 2 cases
        //1. read access is begining later in time with no temporary write upgrade
        //2. read access is begining later in time with temporary write upgrade
        if(permissionOf[_hash].readTime[_delegate].fromTime > block.timestamp){
          //Case 2. read access is begining later in time with temporary write upgrade
          if(permissionOf[_hash].writeTime[_delegate].fromTime > block.timestamp){
            //checking if given bounds
            //begin after the start of read time bounds
            //and end before the start of write time bounds
            if(permissionOf[_hash].readTime[_delegate].fromTime < _fromTime && permissionOf[_hash].writeTime[_delegate].fromTime >_toTime){
              permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
              permissionOf[_hash].isOwnerRestricted[_delegate] = true;
              permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
              permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
              success = true;
              return success;
            }
            //checking if given time bounds
            //begin after the start of write time bounds
            //and end before the end of write time bounds
            else if(permissionOf[_hash].writeTime[_delegate].fromTime < _fromTime && permissionOf[_hash].writeTime[_delegate].toTime >_toTime){
              permissionOf[_hash].isUpgradedAgain[_delegate] = true;
              permissionOf[_hash].isOwnerRestricted[_delegate] = true;
              permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
              permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
              success = true;
              return success;
            }
            //checking if the given time bounds
            //begin after the end of write time bounds
            //and before the end of read bounds
            else if(permissionOf[_hash].writeTime[_delegate].toTime < _fromTime && permissionOf[_hash].readTime[_delegate].toTime > _toTime){
              permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
              permissionOf[_hash].isOwnerRestricted[_delegate] = true;
              permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
              permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
              success = true;
              return success;
            }else{
              revert("Given Time Bounds are conflicting");
            }
          }
          //Case 1. read access is begining later in time with no temporary write upgrade
          else{
            if(permissionOf[_hash].readTime[_delegate].fromTime < _fromTime && permissionOf[_hash].readTime[_delegate].toTime > _toTime){
              permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
              permissionOf[_hash].isOwnerRestricted[_delegate] = true;
              permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
              permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
              success = true;
              return success;
            }else{
              revert("Given Time Bounds are conflicting");
            }
          }
        }
        //in case delegate's base permissions is write begining later in time
        else if(permissionOf[_hash].writeTime[_delegate].fromTime > block.timestamp){
          //checking if given time bounds are inside write time bounds
          if(permissionOf[_hash].writeTime[_delegate].fromTime < _fromTime && permissionOf[_hash].writeTime[_delegate].toTime > _toTime){
            permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
            permissionOf[_hash].isOwnerRestricted[_delegate] = true;
            permissionOf[_hash].ownerTime[_delegate].fromTime = _fromTime;
            permissionOf[_hash].ownerTime[_delegate].toTime = _toTime;
            success = true;
            return success;
          }else{
            revert("Given Time Bounds are conflicting");
          }

        }else{
          revert("Base Permission Invalid");
        }

      }else{
        revert("Base Permission Invalid");
      }

    }else{
      revert("Unexpected Failure");
    }


  }


  /**
  * @dev use to delegate write access to any ethereum address
  * @param _delegate Ethereum address to whom permission is to be delegated
  * @param _hash hash of the document
  */
  function delegatePermanentWrite(address _delegate, bytes32 _hash) public{
    require(documentExists(_hash), "Document does not exist");
    require(checkPermission(_delegate, _hash) == PermissionType.none, "Delegate already exists");
    PermissionType permissionOfCaller = checkPermission(msg.sender,_hash);
    require(permissionOfCaller == PermissionType.master || permissionOfCaller == PermissionType.owner, "Access Denied");

    permissionOf[_hash].isBaseRestricted[_delegate] = false;
    permissionOf[_hash].write[_delegate] = true;
    permissionOf[_hash].writeLength++;
    transferDocument( _hash, msg.sender, _delegate, permissionOfCaller ,PermissionType.write);
  }

  /**
  * @dev use to remove write access of any ethereum address
  * @param _delegate Ethereum address of whos permission is to be removed
  * @param _hash hash of the document
  */
  function removePermanentWrite(address _delegate, bytes32 _hash) public{
    require(documentExists(_hash), "Document does not exist");
    require(checkPermission(_delegate, _hash) == PermissionType.write, "Delegate does not exist.");
    PermissionType permissionOfCaller = checkPermission(msg.sender, _hash);
    require(permissionOfCaller == PermissionType.master || permissionOfCaller == PermissionType.owner, "Access Denied");

    permissionOf[_hash].write[_delegate] = false;
    permissionOf[_hash].writeLength--;
    transferDocument( _hash, msg.sender, _delegate, permissionOfCaller, PermissionType.none);
  }

  /**
  * @dev use to delegate write permission with time bounds
  * @param _delegate Ethereum address to whom permission is to be delegated
  * @param _hash hash of the document
  * @param _fromTime Time from which the delegate has access
  * @param _toTime Time till which the delegate has access
  */
  function delegateTimeRestrictedWrite(address _delegate, bytes32 _hash, uint256 _fromTime, uint256 _toTime) public{
    require(documentExists(_hash), "Document does not exists");
    require(block.timestamp <= _fromTime && _fromTime < _toTime, "Invalid time bounds." );
    require(checkPermission(_delegate, _hash) == PermissionType.none, "Delegate already exists");
    PermissionType permissionOfCaller = checkPermission(msg.sender, _hash);
    require(permissionOfCaller == PermissionType.master || permissionOfCaller == PermissionType.owner, "Access Denied");

    if(permissionOf[_hash].ownerTime[_delegate].toTime < block.timestamp &&  permissionOf[_hash].readTime[_delegate].toTime < block.timestamp){
      permissionOf[_hash].isBaseRestricted[_delegate] = true;
      permissionOf[_hash].isWriteRestricted[_delegate] = true;
      permissionOf[_hash].writeTime[_delegate].fromTime = _fromTime;
      permissionOf[_hash].writeTime[_delegate].toTime = _toTime;
      emit TimeRestrictedPermission(block.number, block.timestamp, _hash, msg.sender, _delegate, permissionOfCaller, PermissionType.write, _fromTime, _toTime);
    }else{
      revert("Delegate already exists");
    }
  }

  /**
  * @dev use to remove write permission with time bounds
  * @param _delegate Ethereum address to whom permission is to be delegated
  * @param _hash hash of the document
  */
  function removeTimeRestrictedWrite(address _delegate, bytes32 _hash) public{
    require(documentExists(_hash), "Document does not exists");
    require(permissionOf[_hash].isWriteRestricted[_delegate] == true, "Delegate does not exist.");
    PermissionType permissionOfCaller = checkPermission(msg.sender, _hash);
    require(permissionOfCaller == PermissionType.master || permissionOfCaller == PermissionType.owner, "Access Denied");

    permissionOf[_hash].isWriteRestricted[_delegate] = false;
    permissionOf[_hash].writeTime[_delegate].fromTime = 0;
    permissionOf[_hash].writeTime[_delegate].toTime = 0;
    emit TimeRestrictedPermission(block.number, block.timestamp, _hash, msg.sender, _delegate, permissionOfCaller, PermissionType.none, 0, 0);
  }

  /**
  * @dev use to temporarily upgrade read access of an address to write access
  * @param _delegate Ethereum address whos permission is to be temporarily upgarded
  * @param _hash hash of the document
  * @param _fromTime Time from which the delegate has upgraded write access
  * @param _toTime Time till which the delegate has upgraded write access
  */
  function upgradeToWrite(address _delegate, bytes32 _hash, uint256 _fromTime, uint256 _toTime) public returns(bool success){
    require(documentExists(_hash), "Document does not exists");
    require(block.timestamp <= _fromTime && _fromTime < _toTime, "Invalid Time Bounds.");
    require(permissionOf[_hash].writeTime[_delegate].toTime < block.timestamp);
    PermissionType permissionOfCaller = checkPermission(msg.sender, _hash);
    require(permissionOfCaller == PermissionType.master || permissionOfCaller == PermissionType.owner, "Access Denied");

    PermissionType permissionOfDelegate = checkPermission(_delegate, _hash);

    if(permissionOf[_hash].isBaseRestricted[_delegate] == false){
      if(permissionOfDelegate == PermissionType.read){
        permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
        permissionOf[_hash].isWriteRestricted[_delegate] = true;
        permissionOf[_hash].writeTime[_delegate].fromTime = _fromTime;
        permissionOf[_hash].writeTime[_delegate].toTime = _toTime;
        success = true;
        return success;
      }else{
        revert("Base Permission Invalid");
      }
    }else if(permissionOf[_hash].isBaseRestricted[_delegate] == true){
      if(permissionOf[_hash].readTime[_delegate].toTime > block.timestamp){
        if(permissionOf[_hash].readTime[_delegate].fromTime <= _fromTime && permissionOf[_hash].readTime[_delegate].toTime >= _toTime){
          permissionOf[_hash].isTemporarilyUpgraded[_delegate] = true;
          permissionOf[_hash].isWriteRestricted[_delegate] = true;
          permissionOf[_hash].writeTime[_delegate].fromTime = _fromTime;
          permissionOf[_hash].writeTime[_delegate].toTime = _toTime;
          success = true;
          return success;
        }else{
          revert("Given Time Bounds are outside Base Time Bounds");
        }
      }else{
        revert("Base Permission Invalid or Expired");
      }
    }else{
      revert("Unexpected Failure");
    }
  }

  /**
  * @dev use to delegate read access to any ethereum address
  * @param _delegate Ethereum address to whom permission is to be delegated
  * @param _hash hash of the document
  */
  function delegatePermanentRead(address _delegate, bytes32 _hash) public{
    require(documentExists(_hash), "Document does not exist");
    require(checkPermission(_delegate, _hash) == PermissionType.none, "Delegate already exists");
    PermissionType permissionOfCaller = checkPermission(msg.sender, _hash);
    require(permissionOfCaller != PermissionType.none, "Access Denied");

    permissionOf[_hash].isBaseRestricted[_delegate] = false;
    permissionOf[_hash].read[_delegate] = true;
    permissionOf[_hash].readLength++;
    transferDocument( _hash, msg.sender, _delegate, permissionOfCaller, PermissionType.read);
  }

  /**
  * @dev use to remove read access of any ethereum address
  * @param _delegate Ethereum address of whos permission is to be removed
  * @param _hash hash of the document
  */
  function removePermanentRead(address _delegate, bytes32 _hash) public{
    require(documentExists(_hash), "Document does not exist");
    require(checkPermission(_delegate, _hash) == PermissionType.read, "Delegate does not exist.");
    PermissionType permissionOfCaller = checkPermission(msg.sender, _hash);
    require(permissionOfCaller != PermissionType.read && permissionOfCaller != PermissionType.none, "Access Denied");

    permissionOf[_hash].read[_delegate] = false;
    permissionOf[_hash].readLength--;
    transferDocument( _hash, msg.sender, _delegate, permissionOfCaller, PermissionType.none);
  }

  /**
  * @dev use to delegate Read permission with time bounds
  * @param _delegate Ethereum address to whom permission is to be delegated
  * @param _hash hash of the document
  * @param _fromTime Time from which the delegate has access
  * @param _toTime Time till which the delegate has access
  */
  function delegateTimeRestrictedRead(address _delegate, bytes32 _hash, uint256 _fromTime, uint256 _toTime) public{
    require(documentExists(_hash), "Document does not exist");
    require(block.timestamp <= _fromTime && _fromTime < _toTime, "Invalid time bounds." );
    require(checkPermission(_delegate,_hash) == PermissionType.none, "Delegate already exists.");
    PermissionType permissionOfCaller = checkPermission(msg.sender, _hash);
    require(permissionOfCaller != PermissionType.none, "Access Denied");

    if(permissionOf[_hash].ownerTime[_delegate].toTime < block.timestamp &&  permissionOf[_hash].writeTime[_delegate].toTime < block.timestamp){
      permissionOf[_hash].isBaseRestricted[_delegate] = true;
      permissionOf[_hash].isReadRestricted[_delegate] = true;
      permissionOf[_hash].readTime[_delegate].fromTime = _fromTime;
      permissionOf[_hash].readTime[_delegate].toTime = _toTime;
      emit TimeRestrictedPermission(block.number, block.timestamp, _hash, msg.sender, _delegate, permissionOfCaller, PermissionType.read, _fromTime, _toTime);
    }else{
      revert("Delegate already exists");
    }
  }

  /**
  * @dev use to remove Read permission with time bounds
  * @param _delegate Ethereum address to whom permission is to be delegated
  * @param _hash hash of the document
  */
  function removeTimeRestrictedRead(address _delegate, bytes32 _hash) public{
    require(documentExists(_hash), "Document does not exist");
    require(permissionOf[_hash].isReadRestricted[_delegate] == true, "Delegate does not exist.");
    PermissionType permissionOfCaller = checkPermission(msg.sender, _hash);
    require(permissionOfCaller != PermissionType.read && permissionOfCaller != PermissionType.none, "Access Denied");

    permissionOf[_hash].isReadRestricted[_delegate] = false;
    permissionOf[_hash].readTime[_delegate].fromTime = 0;
    permissionOf[_hash].readTime[_delegate].toTime = 0;
    emit TimeRestrictedPermission(block.number, block.timestamp, _hash, msg.sender, _delegate, permissionOfCaller, PermissionType.none, 0, 0);
  }

  /**
  * @dev use to check if the delegate has owner exists
  * @param _delegate Ethereum address of whos owner access is being checked
  * @param _hash hash of the document
  */
  function isOwner(address _delegate, bytes32 _hash) private view returns (bool){
    if(permissionOf[_hash].owner[_delegate] == true){
      return true;
    }else{
      return false;
    }
  }

  /**
  * @dev use to check if has delegate has owner exists
  * @param _delegate Ethereum address of whos write access is being checked
  * @param _hash hash of the document
  */
  function isWriter(address _delegate, bytes32 _hash) private view returns (bool){
    if(permissionOf[_hash].write[_delegate] == true){
      return true;
    }else{
      return false;
    }
  }

  /**
  * @dev use to check if has delegate has read exists
  * @param _delegate Ethereum address of whos read access is being checked
  * @param _hash hash of the document
  */
  function isReader(address _delegate, bytes32 _hash) private view returns (bool){
    if(permissionOf[_hash].read[_delegate] == true){
      return true;
    }else{
      return false;
    }
  }

}
