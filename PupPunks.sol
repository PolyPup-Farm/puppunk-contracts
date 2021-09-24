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
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

contract PolyPupPunks is
	ERC721Pausable,
	ERC721Burnable,
	Ownable,
	ERC721Enumerable,
	ReentrancyGuard
{
	using Counters for Counters.Counter;

	bool private sale;

	uint256 public constant TOKEN_LIMIT = 100;
	uint256 public constant PRICE = 75 ether; // 0.06 ETH
	uint256 public constant MAX_MINT_AT_ONCE = 10;
	address payable internal immutable developer;
	string public baseTokenURI;

	Counters.Counter private _numberOfTokens;

	// Random index assignment
	uint256 internal nonce = 0;
	uint256[TOKEN_LIMIT] internal indices;
	address public immutable pairAddress =
		0x853Ee4b2A13f8a742d64C8F088bE7bA2131f670d; // USDC/WETH QuickSwap Pair Address

	/**
	 * Event emitted when poly pup punk minted
	 */

	event PolyPupPunkMinted(uint256 indexed id);

	/**
	 * Event emitted when the public sale begins.
	 */
	event SaleBegins();

	/**
	 * Event emitted when base uri is updated
	 */
	event BaseURIUpdated();

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
		emit SaleBegins();
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

	function mint(uint256 _count) external payable nonReentrant {
		uint256 total = _totalSupply();
		require(sale == true, 'Sale has not yet started');
		require(total + _count <= TOKEN_LIMIT, 'Max limit');
		require(_count <= MAX_MINT_AT_ONCE, 'Exceeds number');
		require(msg.value == price(_count), 'Value below price');
		require(tx.origin == msg.sender, 'Caller cannot be a contract'); // Only EOA can mint and not a contract

		Address.sendValue(developer, msg.value);

		for (uint256 i = 0; i < _count; i++) {
			_mintAnElement(msg.sender);
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
		//Fetching current balances of USDC/WETH QS Pair for increasing Randomness Entropy
		(uint256 balance1, uint256 balance2) = getCurrentBalanceQSPair();
		uint256 index = uint256(
			keccak256(
				abi.encodePacked(
					nonce,
					msg.sender,
					balance1,
					balance2,
					block.difficulty,
					block.timestamp
				)
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
		return value + 1;
	}

	/**
	 * @dev Getting current reserves of USDC and WETH pairs on QuickSwap
	 */
	function getCurrentBalanceQSPair() public view returns (uint256, uint256) {
		IUniswapV2Pair pair = IUniswapV2Pair(
			0x853Ee4b2A13f8a742d64C8F088bE7bA2131f670d // Address of USDC/WETH Pair on QuickSwap
		);
		(uint256 res0, uint256 res1, ) = pair.getReserves();
		return (res0, res1);
	}

	/** Returns total minted at that point of time */
	function totalMint() public view returns (uint256) {
		return _totalSupply();
	}

	/** Returns total price for total numbrer of minting */
	function price(uint256 _count) public pure returns (uint256) {
		return PRICE * _count;
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
		emit BaseURIUpdated();
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
		// returning only baseTokenURI followed by the ID.
		return string(abi.encodePacked(baseTokenURI, Strings.toString(_tokenId)));
	}

	/**
	 * Pause and unpause sale
	 */
	function pause(bool val) public onlyOwner {
		// Allowing pause only if the sale hasn't started
		if (val == true && sale == false) {
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
