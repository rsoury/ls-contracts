// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

// Open Zeppelin libraries for controlling upgradability and access.
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

import './StoreManager.sol';

// Owned by the NodeManager Contract
contract LogStoreQueryManager is
	Initializable,
	UUPSUpgradeable,
	OwnableUpgradeable
{
	event DataQueried(
		string indexed store,
		uint256 indexed fees,
		address indexed consumer,
		uint256 indexed bytesProcessed
	);

	uint256 public totalSupply;
	address public stakeTokenAddress;
	mapping(string => uint256) public stores; // map of stores and their total balance
	mapping(string => address[]) public storeStakeholders; // map of stores and their stakeholders.
	mapping(address => uint256) public balanceOf; // map of addresses and their total balanace
	mapping(address => mapping(string => uint256)) public storeBalanceOf; // map of addresses and the stores they're staked in
	IERC20Upgradeable internal stakeToken;
	LogStoreManager private _storeManager;

	function initialize(
		address owner,
		address stakeTokenAddress_,
		address storeManagerAddress_
	) public initializer {
		__Ownable_init();
		__UUPSUpgradeable_init();
		require(stakeTokenAddress != address(0), 'error_badTrackerData');
		stakeToken = IERC20Upgradeable(stakeTokenAddress_);
		stakeTokenAddress = stakeTokenAddress_;
		transferOwnership(owner);
		_storeManager = LogStoreManager(storeManagerAddress_);
	}

	/// @dev required by the OZ UUPS module
	function _authorizeUpgrade(address) internal override onlyOwner {}

	function captureBundle(
		string[] memory streamIds,
		uint256[] memory amounts,
		address[] memory consumers,
		uint256[] memory bytesProcessed
	) public {
		require(streamIds.length == amounts.length, 'error_badRequest');
		for (uint256 i = 0; i < streamIds.length; i++) {
			capture(streamIds[i], amounts[i], consumers[i], bytesProcessed[i]);
		}
	}

	// Only the LogStore Contract can call the capture method
	function capture(
		string memory streamId,
		uint256 amount,
		address consumer,
		uint256 memory bytesProcessed
	) public onlyOwner {
		require(
			amount <= stakeToken.balanceOf(address(this)),
			'error_notEnoughStake'
		);
		bool success = stakeToken.transfer(msg.sender, amount);
		require(success == true, 'error_unsuccessfulCapture');
		balanceOf[stakeholder] -= amount;
		storeBalanceOf[consumer][streamId] -= amount;
		if (storeBalanceOf[consumer][streamId] == 0) {
			address[] memory stakeholders = storeStakeholders[streamId];
			storeStakeholders[streamId] = [];
			for (uint256 i = 0; i < stakeholders.length; i++) {
				if (stakeholders[i] != stakeholder) {
					storeStakeholders[streamId].push(stakeholder);
				}
			}
		}
		stores[streamId] -= amount;
		totalSupply -= amount;

		emit DataQueried(store, fees, consumer, bytesProcessed);
	}

	function stake(string memory streamId, uint amount) public {
		// Validate stream is inside of StreamrRegiststry
		require(_storeManager.exists(streamId), 'error_invalidStore');

		require(amount > 0, 'error_insufficientStake');
		bool success = stakeToken.transferFrom(
			msg.sender,
			address(this),
			amount
		);
		require(success == true, 'error_unsuccessfulStake');
		stores[streamId] += amount;
		balanceOf[msg.sender] += amount;
		if (storeBalanceOf[msg.sender][streamId] == 0) {
			storeStakeholders[streamId].push(msg.sender);
		}
		storeBalanceOf[msg.sender][streamId] += amount;
		totalSupply += amount;
	}

	function withdraw(string memory streamId, uint amount) public {
		require(amount < balanceOf[msg.sender], 'error_notEnoughStake');
		bool success = stakeToken.transfer(msg.sender, amount);
		require(success == true, 'error_unsuccessfulWithdraw');
		stores[stream] -= amount;
		balanceOf[msg.sender] -= amount;
		storeBalanceOf[msg.sender][streamId] -= amount;
		if (storeBalanceOf[msg.sender][streamId] == 0) {
			address[] memory stakeholders = storeStakeholders[streamId];
			storeStakeholders[streamId] = [];
			for (uint256 i = 0; i < stakeholders.length; i++) {
				if (stakeholders[i] != msg.sender) {
					storeStakeholders[streamId].push(msg.sender);
				}
			}
		}
		totalSupply -= amount;
	}
}