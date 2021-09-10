// SPDX-License-Identifier: MIT OR Apache-2.0

// @title: PolyPup Punks NFT
// @author: Neothon

//	.______     ______    __      ____    ____ .______    __    __  .______      .______    __    __  .__   __.  __  ___      _______.
//	|   _  \   /  __  \  |  |     \   \  /   / |   _  \  |  |  |  | |   _  \     |   _  \  |  |  |  | |  \ |  | |  |/  /     /       |
//	|  |_)  | |  |  |  | |  |      \   \/   /  |  |_)  | |  |  |  | |  |_)  |    |  |_)  | |  |  |  | |   \|  | |  '  /     |   (----`
//	|   ___/  |  |  |  | |  |       \_    _/   |   ___/  |  |  |  | |   ___/     |   ___/  |  |  |  | |  . `  | |    <       \   \
//	|  |      |  `--'  | |  `----.    |  |     |  |      |  `--'  | |  |         |  |      |  `--'  | |  |\   | |  .  \  .----)   |
//	| _|       \______/  |_______|    |__|     | _|       \______/  | _|         | _|       \______/  |__| \__| |__|\__\ |_______/

pragma solidity ^0.8.4;

import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

import '@openzeppelin/contracts/access/Ownable.sol';
import 'hardhat/console.sol';

contract PolyPupPunks is
	ERC721Pausable,
	ERC721Burnable,
	Ownable,
	ERC721Enumerable,
	ReentrancyGuard
{
	using Counters for Counters.Counter;
	using SafeMath for uint256;

	bool private sale;

	uint256 public constant TOKEN_LIMIT = 100;
	uint256 public constant PRICE = 75 ether; // 0.06 ETH
	uint256 public constant MAX_MINT_AT_ONCE = 10;
	address payable internal developer;
	string public baseTokenURI;

	Counters.Counter private _numberOfTokens;

	// Random index assignment
	uint256 internal nonce = 0;
	uint256[TOKEN_LIMIT] internal indices;

	mapping(address => uint256[]) internal ownerToIds;
	mapping(uint256 => uint256) internal idToOwnerIndex;
	/**
	 * Event emitted when poly pup punk minted
	 */

	event PolyPupPunkMinted(uint256 indexed id);

	/**
	 * Event emitted when the public sale begins.
	 */
	event SaleBegins();

	constructor(string memory baseURI, address payable _developer)
		ERC721('PolyPup Punks', 'POLYPUP')
	{
		setBaseURI(baseURI);
		developer = _developer;
		pause(true);
		sale = false;
	}

	/**
	 * Start sale only owner allowed
	 */
	function startSale() public onlyOwner {
		sale = true;
		pause(false);
	}

	/**
	 * Function modifier to pause sale if owner is not calling the function.
	 */
	modifier saleIsOpen() {
		require(_totalSupply() <= TOKEN_LIMIT, 'Sale ended');
		if (_msgSender() != owner()) {
			require(!paused(), 'Pausable: paused');
		}
		_;
	}

	modifier validNFToken(uint256 _tokenId) {
		require(_exists(_tokenId), 'Invalid token.');
		_;
	}

	/**
	 * Public method to start minting PolyPup Punks
	 */

	function mint(address _to, uint256 _count) external payable nonReentrant {
		uint256 total = _totalSupply();
		require(sale == true, 'Sale has not yet started');
		require(total <= TOKEN_LIMIT, 'Sale ended');
		require(total + _count <= TOKEN_LIMIT, 'Max limit');
		require(_count <= MAX_MINT_AT_ONCE, 'Exceeds number');
		require(msg.value >= price(_count), 'Value below price');
		// TODO: If this is the safest method to transfer
		payable(developer).transfer(msg.value);

		for (uint256 i = 0; i < _count; i++) {
			_mintAnElement(_to);
		}
	}

	function _mintAnElement(address _to) private {
		// uint256 id = _totalSupply();
		uint256 id = _randomIndex();
		_numberOfTokens.increment();
		_safeMint(_to, id);
		emit PolyPupPunkMinted(id);
	}

	/**
	 * Returns a random index within the unminited token id range
	 */
	function _randomIndex() internal returns (uint256) {
		uint256 totalSize = TOKEN_LIMIT - _numberOfTokens.current();
		uint256 index = uint256(
			keccak256(
				abi.encodePacked(nonce, msg.sender, block.difficulty, block.timestamp)
			)
		) % totalSize;
		uint256 value = 0;
		if (indices[index] != 0) {
			value = indices[index];
		} else {
			value = index;
		}

		// Move last value to selected position
		if (indices[totalSize - 1] == 0) {
			// Array position not initialized, so use position
			indices[index] = totalSize - 1;
		} else {
			// Array position holds a value so use that
			indices[index] = indices[totalSize - 1];
		}
		nonce++;
		// Don't allow a zero index, start counting at 1
		return value.add(1);
	}

	/** Returns total minted at that point of time */
	function totalMint() public view returns (uint256) {
		return _totalSupply();
	}

	/** Returns total price for total numbrer of minting */
	function price(uint256 _count) public pure returns (uint256) {
		return PRICE.mul(_count);
	}

	/** Defining Internal Methods */

	/**
	 * Returns the total current supply
	 */
	function _totalSupply() internal view returns (uint256) {
		return _numberOfTokens.current();
	}

	/*
	 * Function set base URI. Only Contract Owner can do this
	 */
	function setBaseURI(string memory baseURI) public onlyOwner {
		baseTokenURI = baseURI;
	}

	/**
	 * @dev A distinct URI (RFC 3986) for a given NFT.
	 * @param _tokenId Id for which we want uri.
	 * @return _tokenId URI of _tokenId.
	 */
	function tokenURI(uint256 _tokenId)
		public
		view
		virtual
		override
		validNFToken(_tokenId)
		returns (string memory)
	{
		return
			string(
				abi.encodePacked(
					baseTokenURI,
					'api/polypup-punks/',
					Strings.toString(_tokenId)
				)
			);
	}

	/**
	 * Pause and unpause sale
	 */
	function pause(bool val) public onlyOwner {
		if (val == true) {
			_pause();
			return;
		}
		_unpause();
	}

	// return NFTs in owner wallet
	function walletOfOwner(address _owner)
		external
		view
		returns (uint256[] memory)
	{
		uint256 tokenCount = balanceOf(_owner);

		uint256[] memory tokenIds = new uint256[](tokenCount);
		for (uint256 i = 0; i < tokenCount; i++) {
			tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
		}

		return tokenIds;
	}

	// function withdrawAll() public payable onlyOwner {
	// 	uint256 balance = address(this).balance;
	// 	require(balance > 0);
	// 	_widthdraw(developer, balance.mul(60).div(100));
	// 	_widthdraw(official, address(this).balance);
	// }

	// function _widthdraw(address _address, uint256 _amount) private {
	// 	(bool success, ) = _address.call{value: _amount}('');
	// 	require(success, 'Transfer failed.');
	// }

	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 tokenId
	) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
		super._beforeTokenTransfer(from, to, tokenId);
	}

	function supportsInterface(bytes4 interfaceId)
		public
		view
		virtual
		override(ERC721, ERC721Enumerable)
		returns (bool)
	{
		return super.supportsInterface(interfaceId);
	}
}
