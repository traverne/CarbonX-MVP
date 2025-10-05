// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {CarbonX} from "./CarbonX.sol";

import {Owned} from "solmate/auth/Owned.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

enum Standard {
    Verra,
    GoldStandard,
    CDM,
    ACR,
    CAR,
    Other
}

struct Certification {
    string project_name;
    string issuer_name;
    string location;
    string methodology;
    uint256 amount;
    uint256 vintage_year;
    uint256 expiry;
    Standard standard;
}

struct CreditMetadata {
    Certification certification;
    bytes32 salt;
    uint256 createdAt;
    uint256 retiredAt;
    address mintedBy;
    address retiredBy;
    address validatedBy;
    bytes validationProof;
}

/// @title Registrar: Registrar for CarbonX Carbon Credits
/// @author Athen Traverne [athen@aetherionresearch.com]
/// @notice Version:MVP(1)
contract Registrar is Owned, ReentrancyGuard {
    /* ============================================ */
    /* ERC-191 Signature Structure
    /* ============================================ */
    string public constant CREDIT_ISSUING_PREFIX = "CarbonCreditRegistrar/IssueCredit";

    bytes1 constant PREFIX = bytes1(0x19);
    bytes1 constant VERSION = bytes1(0x00);
    address immutable _this;
    uint256 immutable _chainid;

    CarbonX public token;

    /// @dev Used for replay attack and signature malleability protection.
    mapping(bytes32 => bool) private consumed;

    mapping(uint256 => CreditMetadata) public credits;
    mapping(address => bool) public validators;

    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);

    event Issued(uint256 indexed id);
    event Retired(uint256 indexed id);

    constructor(string memory _prefix, address _owner) Owned(_owner) {
        _this = address(this);
        _chainid = block.chainid;

        token = new CarbonX(_prefix, _this);
    }

    /* ============================================ */
    /* Validator Authentication Logic
    /* ============================================ */
    function addValidator(address validator) external onlyOwner {
        require(validator != address(0x00), "CarbonCreditRegistrar: Invalid address");

        if (validators[validator]) return;
        validators[validator] = true;

        emit ValidatorAdded(validator);
    }

    function removeValidator(address validator) external onlyOwner {
        if (!validators[validator]) return;
        validators[validator] = false;

        emit ValidatorRemoved(validator);
    }

    /* ============================================ */
    /* Non-static User Functions
    /* ============================================ */
    /// @dev param:salt To support if there exists another credit with the exactly same certification
    function issue(
        Certification calldata certification,
        address recipient,
        bytes32 salt,
        bytes calldata validationProof,
        bytes calldata signature
    ) external nonReentrant returns (uint256 id) {
        id = getCreditId(certification, salt);
        require(!isCreditIssued(id), "CarbonCreditRegistrar: Already issued");

        CreditMetadata memory metadata;
        metadata.certification = certification;
        metadata.salt = salt;

        bytes32 digest = _generateDigest(id, validationProof);

        metadata.validatedBy = _validateDigest(digest, signature);
        metadata.validationProof = validationProof;

        metadata.mintedBy = msg.sender;
        metadata.createdAt = block.timestamp;

        // initial default values
        // metadata.retiredAt = 0
        // metadata.retiredBy = address(0x00)

        credits[id] = metadata;

        if (recipient == address(0x00)) {
            recipient = msg.sender;
        }

        token.mint(recipient, id);
        emit Issued(id);
    }

    function retire(uint256 id) external nonReentrant returns (Certification memory certification) {
        require(isUsableCredit(id), "CarbonCreditRegistrar: Unusable credit");

        address creditOwner = token.ownerOf(id);
        address approved = token.getApproved(id);
        require(
            creditOwner == msg.sender || approved == msg.sender || token.isApprovedForAll(creditOwner, msg.sender),
            "CarbonCreditRegistrar: Unauthorized retire"
        );

        CreditMetadata storage metadata = credits[id];
        metadata.retiredAt = block.timestamp;
        metadata.retiredBy = msg.sender;

        token.burn(id);

        emit Retired(id);
        return metadata.certification;
    }

    /* ============================================ */
    /* Static User Functions
    /* ============================================ */
    function getMetadata(uint256 id) public view returns (CreditMetadata memory) {
        return credits[id];
    }

    function getCertification(uint256 id) public view returns (Certification memory) {
        return credits[id].certification;
    }

    function isUsableCredit(uint256 id) public view returns (bool) {
        return isCreditIssued(id) && (!isCreditExpired(id)) && (!isCreditRetired(id));
    }

    function isCreditIssued(uint256 id) public view returns (bool) {
        return credits[id].createdAt > 0;
    }

    function isCreditExpired(uint256 id) public view returns (bool) {
        return credits[id].certification.expiry != 0 && credits[id].certification.expiry <= block.timestamp;
    }

    function isCreditRetired(uint256 id) public view returns (bool) {
        return credits[id].retiredAt > 0;
    }

    function getCreditId(Certification calldata certification, bytes32 salt) public pure returns (uint256) {
        bytes32 certhash = keccak256(abi.encode(certification));
        return uint256(keccak256(abi.encodePacked(certhash, salt)));
    }

    /* ============================================ */
    /* Internal Functions
    /* ============================================ */
    function _generateDigest(uint256 creditId, bytes calldata validationProof) internal view returns (bytes32 digest) {
        bytes32 message = keccak256(abi.encodePacked(CREDIT_ISSUING_PREFIX, creditId, validationProof));
        return keccak256(abi.encodePacked(PREFIX, VERSION, _this, _chainid, message));
    }

    function _validateDigest(bytes32 digest, bytes memory signature) internal returns (address validator) {
        require(signature.length == 65, "CarbonCreditRegistrar: Invalid signature");
        require(!consumed[digest], "CarbonCreditRegistrar: Signature already used");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // proof is a bytes memory, layout in memory:
            // [0-31]:   length (32 bytes)
            // [32-63]:  r (32 bytes)
            // [64-95]:  s (32 bytes)
            // [96]:     v (1 byte)

            r := mload(add(signature, 32))
            s := mload(add(signature, 64))

            // mload reads 32 bytes, so we read from position 96 and mask to get only first byte
            v := byte(0, mload(add(signature, 96)))
        }

        // No need to check for null address as it's prevented to be registered.
        validator = ecrecover(digest, v, r, s);

        require(validators[validator], "CarbonCreditRegistrar: Invalid signature");
        consumed[digest] = true;
    }
}
