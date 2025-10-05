// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

/// @dev structure is optimized for efficient packing
struct Listing {
    address asker;
    address bidder;
    uint256 id;
    uint256 price;
    uint256 expiry;
    uint256 createdAt;
    uint256 fulfilledAt;
}

/// @title Marketplace: Permissionless CarbonX Carbon Credit Exchange
/// @author Athen Traverne [athen@aetherionresearch.com]
/// @notice Version:MVP(1)
contract Marketplace is ReentrancyGuard, ERC721TokenReceiver {
    IERC721 public CarbonX;
    mapping(uint256 listingId => Listing listing) public listings;

    event Listed(uint256 listingId, uint256 indexed id);
    event Fulfilled(uint256 listingId, uint256 indexed id, address indexed to);

    event Expired(uint256 listingId, uint256 indexed id);
    event ListingUpdated(uint256 listingId, uint256 indexed id);
    event ListingCancelled(uint256 listingId, uint256 indexed id);

    constructor(IERC721 _token) {
        CarbonX = _token;
    }

    /* ============================================ */
    /* Core User Functions
    /* ============================================ */
    function list(uint256 id, uint256 price, uint256 expiry, bytes32 salt)
        public
        nonReentrant
        returns (uint256 listingId)
    {
        // Lets the contract transfer the token (which is approved to this marketplace)
        // if the user is also approved to use the token

        address creditOwner = CarbonX.ownerOf(id);
        address approved = CarbonX.getApproved(id);

        require(
            creditOwner == msg.sender || approved == msg.sender || CarbonX.isApprovedForAll(creditOwner, msg.sender),
            "Marketplace: Unauthorized"
        );

        listingId = getListingId(id, price, expiry, salt, block.number);
        Listing storage listing = listings[listingId];

        listing.asker = msg.sender;
        listing.id = id;
        listing.price = price;
        listing.expiry = expiry;
        listing.createdAt = block.timestamp;

        // initial default values
        // listing.bidder = null addr
        // listing.fulfilledAt = 0

        CarbonX.safeTransferFrom(creditOwner, address(this), id);
        emit Listed(listingId, id);
    }

    function update(uint256 listingId, uint256 newPrice, uint256 newExpiry) external {
        Listing storage listing = listings[listingId];

        require(listing.asker == msg.sender, "Marketplace: Unauthorized");
        require(isListingActive(listingId), "Marketplace: Listing not active");

        if (newPrice != 0) listing.price = newPrice;
        if (newExpiry != 0) listing.expiry = newExpiry;

        emit ListingUpdated(listingId, listing.id);
    }

    function cancel(uint256 listingId) external nonReentrant returns (uint256 id) {
        Listing storage listing = listings[listingId];
        id = listing.id;

        require(listing.asker == msg.sender, "Marketplace: Unauthorized");
        require(!isListingFulfilled(listingId), "Marketplace: Listing already fulfilled");

        listing.fulfilledAt = type(uint256).max;
        CarbonX.safeTransferFrom(address(this), listing.asker, id);

        if (isListingExpired(id)) emit Expired(listingId, id);
        else emit ListingCancelled(listingId, id);
    }

    function fulfill(uint256 listingId) external payable nonReentrant returns (uint256 id) {
        Listing storage listing = listings[listingId];
        id = listing.id;

        _processPayable(listing.price);
        listing.bidder = msg.sender;
        listing.fulfilledAt = block.timestamp;

        CarbonX.safeTransferFrom(address(this), listing.bidder, id);

        emit Fulfilled(listingId, id, msg.sender);
    }

    /* ============================================ */
    /* Static User Functions
    /* ============================================ */
    function getListing(uint256 listingId) public view returns (Listing memory) {
        return listings[listingId];
    }

    function isListingActive(uint256 listingId) public view returns (bool) {
        return isListingValid(listingId) && (!isListingFulfilled(listingId)) && (!isListingExpired(listingId));
    }

    function isListingExpired(uint256 listingId) public view returns (bool) {
        return listings[listingId].expiry != 0 && listings[listingId].expiry < block.timestamp;
    }

    function isListingValid(uint256 listingId) public view returns (bool) {
        return listings[listingId].createdAt > 0;
    }

    function isListingFulfilled(uint256 listingId) public view returns (bool) {
        return listings[listingId].fulfilledAt > 0;
    }

    /// @dev uses block.number for pseudorandomness for additional uniqueness in extreme edge cases
    function getListingId(uint256 id, uint256 price, uint256 expiry, bytes32 salt, uint256 blockNumber)
        public
        pure
        returns (uint256 listingId)
    {
        listingId = uint256(keccak256(abi.encodePacked(id, price, expiry, salt, blockNumber)));
    }

    /* ============================================ */
    /* Internal Functions
    /* ============================================ */
    function _processPayable(uint256 p) internal {
        require(p <= msg.value, "Marketplace: Insufficient price paid");
        uint256 s = msg.value - p;
        if (s > 0) {
            (bool success,) = payable(msg.sender).call{value: s}("");
            require(success, "Marketplace: Excess payment refund failed");
        }
    }
}
