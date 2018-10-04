# blockchain-based-access-right-management
A Blockchain based application allowing users to enforce Access Rights for any Document/File/Folder. Implemented by writing and deploying Smart Contract (in Solidity) on the Ethereum Blockchain. Four types of Access Rights were implemented- master, owner, write and read.


There are 2 smart contracts- PermissionManagement.sol and NotarizationManagement.sol

NotarizationManagement.sol-
This contracts gives a important function and data structures which will be inherited by the PermissionManagement.sol. The most important data structure in enum PermissionType {master, owner, write, read, none}. This enum is widely used in PermissionManagement.sol. Functions, transferDocument() and documentExists() are are also widely used in PermissionManagement.sol. This contract is very small and mostly self-explanatory.

PermissionManagement.sol-
To under this contract, one must first understand the data structure used. These are defined in the starting of the contract.
Here’s a description of each function of the contract. In this description the purpose and working of functions is explained please refer to the code for exact specifications.
1.	newDocument()-  This is used to save the hash of a new document/file/folder. The caller of this function is automatically granted the master access. There can only be one master for a particular hash.
2.	changeMaster()- This function is used when the master of a hash wants to give up it’s own master access and delegate some other address with the master access.
3.	checkYourPermission()- Used by the caller to check his/her permission.
4.	checkDelegatePermission()- used by anyone to check the permission of any address for a particular hash.
5.	checkPermission()- One of the most widely used function throughout the contract. This will return the permission of a particular address. This function checks if there are any upgrades and returns the highest permission at the time of function call.
6.	checkPermanentPermission()- This is called by checkPermission(). It returns the permanent permission of delegate.
7.	checkTimedPermission()- This is called by checkPermission(). It returns the permanent permission of delegate.
8.	delegatePermanentOwner()- Used to delegate permanent owner permission.
9.	removePermanentOwner()- Used to remove Permanent Owner Permission.
10.	delegateTimeRestrictedOwner()- Used to delegate owner Permission which will be valid for only the given time bounds. This is a base permission.
11.	removeTimeRestrictedOwner()- Used to remove owner Permission with time bounds
12.	upgradeToOwner()- This is the longest and most complicated function in the entire contract. This function is used to grant temporary owner permission on top of read or write permission. It carefully analysis the base permissions and then delegates owner permission. This function has comments on every step. Read the comments to understand exact working.
13.	delegatePermanentWrite()- Used to delegate permanent write permission.
14.	removePermanentWrite()- Used to remove Permanent write Permission.
15.	delegateTimeRestrictedWrite()- Used to delegate write Permission which will be valid for only the given time bounds. This is a base permission.
16.	removeTimeRestrictedWrite()- Used to remove write Permission with time bounds
17.	UpgradeToWrite()- This function is used to grant temporary write permission on top of read permission. It carefully analysis the base permissions and then delegates write permission.
18.	delegatePermanentRead()- Used to delegate permanent read permission.
19.	removePermanentRead()- Used to remove Permanent read Permission.
20.	delegateTimeRestrictedRead()- Used to delegate read Permission which will be valid for only the given time bounds. This is a base permission.
21.	removeTimeRestrictedRead()- Used to remove Read Permission with time bounds
22.	isOwner()- checks if the delegate has permanent Owner access
23.	isWriter()- checks if the delegate has permanent Write access
24.	isReader()- checks if the delegate has permanent Read access.
Kindly refer the code for better understanding.
For any doubts/queries/bug reports/issues feel free to email at ashwinarora48@gmail.com

