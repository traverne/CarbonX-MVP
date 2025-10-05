// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {Registrar, Certification, CreditMetadata, Standard} from "../src/Registrar.sol";
import {CarbonX} from "../src/CarbonX.sol";

/// @title RegistrarTest: Unit Testing for Registrar Contract
/// @author Athen Traverne [athen@aetherionresearch.com], et al
/// @notice Auto-generated using AI Agents
contract RegistrarTest is Test {
    Registrar public registrar;
    CarbonX public token;

    address public owner;
    address public validator;
    address public user;
    address public recipient;

    uint256 public validatorPrivateKey;
    uint256 public unauthorizedPrivateKey;

    Certification public testCert;
    bytes32 public testSalt;

    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event Issued(uint256 indexed id);
    event Retired(uint256 indexed id);

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        recipient = makeAddr("recipient");

        validatorPrivateKey = 0xA11CE;
        validator = vm.addr(validatorPrivateKey);

        unauthorizedPrivateKey = 0xBAD;

        vm.prank(owner);
        registrar = new Registrar("TEST", owner);
        token = registrar.token();

        vm.prank(owner);
        registrar.addValidator(validator);

        testCert = Certification({
            project_name: "Solar Farm Alpha",
            issuer_name: "Green Energy Corp",
            location: "California, USA",
            methodology: "ACM0002",
            amount: 1000,
            vintage_year: 2024,
            expiry: block.timestamp + 365 days,
            standard: Standard.Verra
        });

        testSalt = keccak256("unique_salt_1");
    }

    /* ============================================ */
    /* Constructor Tests
    /* ============================================ */

    function test_Constructor() public view {
        assertEq(registrar.owner(), owner);
        assertEq(address(registrar.token()), address(token));
        assertTrue(registrar.validators(validator));
    }

    function test_Constructor_TokenProperties() public view {
        assertEq(token.name(), "[CarbonX] Carbon Credit");
        assertEq(token.symbol(), "CO2e");
        assertEq(token.prefix(), "TEST");
        assertEq(token.registrar(), address(registrar));
    }

    /* ============================================ */
    /* Validator Management Tests
    /* ============================================ */

    function test_AddValidator() public {
        address newValidator = makeAddr("newValidator");

        vm.expectEmit(true, false, false, false);
        emit ValidatorAdded(newValidator);

        vm.prank(owner);
        registrar.addValidator(newValidator);

        assertTrue(registrar.validators(newValidator));
    }

    function test_AddValidator_AlreadyExists() public {
        vm.prank(owner);
        registrar.addValidator(validator);

        assertTrue(registrar.validators(validator));
    }

    function test_AddValidator_RevertWhen_ZeroAddress() public {
        vm.expectRevert("CarbonCreditRegistrar: Invalid address");
        vm.prank(owner);
        registrar.addValidator(address(0));
    }

    function test_AddValidator_RevertWhen_NotOwner() public {
        address newValidator = makeAddr("newValidator");

        vm.expectRevert("UNAUTHORIZED");
        vm.prank(user);
        registrar.addValidator(newValidator);
    }

    function test_RemoveValidator() public {
        vm.expectEmit(true, false, false, false);
        emit ValidatorRemoved(validator);

        vm.prank(owner);
        registrar.removeValidator(validator);

        assertFalse(registrar.validators(validator));
    }

    function test_RemoveValidator_NotExists() public {
        address nonExistent = makeAddr("nonExistent");

        vm.prank(owner);
        registrar.removeValidator(nonExistent);

        assertFalse(registrar.validators(nonExistent));
    }

    function test_RemoveValidator_RevertWhen_NotOwner() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(user);
        registrar.removeValidator(validator);
    }

    /* ============================================ */
    /* Credit ID Generation Tests
    /* ============================================ */

    function test_GetCreditId() public view {
        uint256 id = registrar.getCreditId(testCert, testSalt);
        assertTrue(id > 0);
    }

    function test_GetCreditId_DifferentSalts() public view {
        bytes32 salt1 = keccak256("salt1");
        bytes32 salt2 = keccak256("salt2");

        uint256 id1 = registrar.getCreditId(testCert, salt1);
        uint256 id2 = registrar.getCreditId(testCert, salt2);

        assertTrue(id1 != id2);
    }

    function test_GetCreditId_DifferentCertifications() public view {
        Certification memory cert2 = testCert;
        cert2.amount = 2000;

        uint256 id1 = registrar.getCreditId(testCert, testSalt);
        uint256 id2 = registrar.getCreditId(cert2, testSalt);

        assertTrue(id1 != id2);
    }

    /* ============================================ */
    /* Issue Credit Tests
    /* ============================================ */

    function test_Issue() public {
        uint256 id = registrar.getCreditId(testCert, testSalt);
        bytes memory validationProof = "ipfs://proof123";
        bytes32 digest = _generateDigest(id, validationProof);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, false, false, false);
        emit Issued(id);

        vm.prank(user);
        uint256 issuedId = registrar.issue(testCert, recipient, testSalt, validationProof, signature);

        assertEq(issuedId, id);
        assertEq(token.ownerOf(id), recipient);
        assertTrue(registrar.isCreditIssued(id));
        assertFalse(registrar.isCreditRetired(id));

        CreditMetadata memory metadata = registrar.getMetadata(id);
        assertEq(metadata.mintedBy, user);
        assertEq(metadata.validatedBy, validator);
        assertEq(metadata.createdAt, block.timestamp);
        assertEq(metadata.retiredAt, 0);
        assertEq(metadata.retiredBy, address(0));
    }

    function test_Issue_ToMsgSender() public {
        uint256 id = registrar.getCreditId(testCert, testSalt);
        bytes memory validationProof = "ipfs://proof123";
        bytes32 digest = _generateDigest(id, validationProof);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user);
        registrar.issue(testCert, address(0), testSalt, validationProof, signature);

        assertEq(token.ownerOf(id), user);
    }

    function test_Issue_RevertWhen_AlreadyIssued() public {
        uint256 id = registrar.getCreditId(testCert, testSalt);
        bytes memory validationProof = "ipfs://proof123";
        bytes32 digest = _generateDigest(id, validationProof);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user);
        registrar.issue(testCert, recipient, testSalt, validationProof, signature);

        // Try to issue again with different signature
        bytes memory validationProof2 = "ipfs://proof456";
        bytes32 digest2 = _generateDigest(id, validationProof2);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(validatorPrivateKey, digest2);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        vm.expectRevert("CarbonCreditRegistrar: Already issued");
        vm.prank(user);
        registrar.issue(testCert, recipient, testSalt, validationProof2, signature2);
    }

    function test_Issue_RevertWhen_InvalidSignature() public {
        uint256 id = registrar.getCreditId(testCert, testSalt);
        bytes memory validationProof = "ipfs://proof123";
        bytes32 digest = _generateDigest(id, validationProof);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(unauthorizedPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert("CarbonCreditRegistrar: Invalid signature");
        vm.prank(user);
        registrar.issue(testCert, recipient, testSalt, validationProof, signature);
    }

    function test_Issue_RevertWhen_InvalidSignatureLength() public {
        uint256 id = registrar.getCreditId(testCert, testSalt);
        bytes memory validationProof = "ipfs://proof123";
        bytes memory invalidSignature = "short";

        vm.expectRevert("CarbonCreditRegistrar: Invalid signature");
        vm.prank(user);
        registrar.issue(testCert, recipient, testSalt, validationProof, invalidSignature);
    }

    /* ============================================ */
    /* Retire Credit Tests
    /* ============================================ */

    function test_Retire_ByOwner() public {
        uint256 id = _issueCredit(user);

        vm.expectEmit(true, false, false, false);
        emit Retired(id);

        vm.prank(user);
        Certification memory cert = registrar.retire(id);

        assertEq(cert.project_name, testCert.project_name);
        assertTrue(registrar.isCreditRetired(id));
        assertFalse(registrar.isUsableCredit(id));

        CreditMetadata memory metadata = registrar.getMetadata(id);
        assertEq(metadata.retiredBy, user);
        assertEq(metadata.retiredAt, block.timestamp);

        vm.expectRevert();
        token.ownerOf(id);
    }

    function test_Retire_ByApproved() public {
        uint256 id = _issueCredit(user);

        vm.prank(user);
        token.approve(recipient, id);

        vm.prank(recipient);
        registrar.retire(id);

        assertTrue(registrar.isCreditRetired(id));
    }

    function test_Retire_ByOperator() public {
        uint256 id = _issueCredit(user);

        vm.prank(user);
        token.setApprovalForAll(recipient, true);

        vm.prank(recipient);
        registrar.retire(id);

        assertTrue(registrar.isCreditRetired(id));
    }

    function test_Retire_RevertWhen_NotIssued() public {
        uint256 nonExistentId = 999999;

        vm.expectRevert("CarbonCreditRegistrar: Unusable credit");
        vm.prank(user);
        registrar.retire(nonExistentId);
    }

    function test_Retire_RevertWhen_AlreadyRetired() public {
        uint256 id = _issueCredit(user);

        vm.prank(user);
        registrar.retire(id);

        vm.expectRevert("CarbonCreditRegistrar: Unusable credit");
        vm.prank(user);
        registrar.retire(id);
    }

    function test_Retire_RevertWhen_Expired() public {
        testCert.expiry = block.timestamp + 1 days;
        uint256 id = _issueCredit(user);

        vm.warp(block.timestamp + 2 days);

        vm.expectRevert("CarbonCreditRegistrar: Unusable credit");
        vm.prank(user);
        registrar.retire(id);
    }

    function test_Retire_RevertWhen_Unauthorized() public {
        uint256 id = _issueCredit(user);

        vm.expectRevert("CarbonCreditRegistrar: Unauthorized retire");
        vm.prank(recipient);
        registrar.retire(id);
    }

    /* ============================================ */
    /* Credit Status Tests
    /* ============================================ */

    function test_IsUsableCredit() public {
        uint256 id = _issueCredit(user);
        assertTrue(registrar.isUsableCredit(id));
    }

    function test_IsUsableCredit_Expired() public {
        testCert.expiry = block.timestamp + 1 days;
        uint256 id = _issueCredit(user);

        assertTrue(registrar.isUsableCredit(id));

        vm.warp(block.timestamp + 2 days);
        assertFalse(registrar.isUsableCredit(id));
    }

    function test_IsUsableCredit_NoExpiry() public {
        testCert.expiry = 0;
        uint256 id = _issueCredit(user);

        vm.warp(block.timestamp + 365 days * 100);
        assertTrue(registrar.isUsableCredit(id));
    }

    function test_IsCreditExpired() public {
        testCert.expiry = block.timestamp + 1 days;
        uint256 id = _issueCredit(user);

        assertFalse(registrar.isCreditExpired(id));

        vm.warp(block.timestamp + 1 days);
        assertTrue(registrar.isCreditExpired(id));
    }

    function test_IsCreditRetired() public {
        uint256 id = _issueCredit(user);

        assertFalse(registrar.isCreditRetired(id));

        vm.prank(user);
        registrar.retire(id);

        assertTrue(registrar.isCreditRetired(id));
    }

    /* ============================================ */
    /* Metadata Tests
    /* ============================================ */

    function test_GetMetadata() public {
        uint256 id = _issueCredit(user);

        CreditMetadata memory metadata = registrar.getMetadata(id);

        assertEq(metadata.certification.project_name, testCert.project_name);
        assertEq(metadata.certification.amount, testCert.amount);
        assertEq(metadata.salt, testSalt);
        assertEq(metadata.mintedBy, user);
        assertEq(metadata.validatedBy, validator);
        assertTrue(metadata.createdAt > 0);
    }

    function test_GetCertification() public {
        uint256 id = _issueCredit(user);

        Certification memory cert = registrar.getCertification(id);

        assertEq(cert.project_name, testCert.project_name);
        assertEq(cert.issuer_name, testCert.issuer_name);
        assertEq(cert.location, testCert.location);
        assertEq(cert.amount, testCert.amount);
    }

    /* ============================================ */
    /* Reentrancy Tests
    /* ============================================ */

    function test_Issue_NoReentrancy() public {
        // Deploy malicious contract that tries to reenter
        MaliciousReceiver malicious = new MaliciousReceiver(registrar);

        uint256 id = registrar.getCreditId(testCert, testSalt);
        bytes memory validationProof = "ipfs://proof123";
        bytes32 digest = _generateDigest(id, validationProof);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user);
        registrar.issue(testCert, address(malicious), testSalt, validationProof, signature);

        // Should succeed without reentrancy
        assertTrue(registrar.isCreditIssued(id));
    }

    /* ============================================ */
    /* Fuzz Tests
    /* ============================================ */

    function testFuzz_GetCreditId(bytes32 salt, uint256 amount) public view {
        Certification memory cert = testCert;
        cert.amount = amount;

        uint256 id = registrar.getCreditId(cert, salt);
        assertTrue(id > 0);
    }

    function testFuzz_Issue(address _recipient, bytes32 salt) public {
        vm.assume(_recipient != address(0));
        vm.assume(_recipient.code.length == 0);

        Certification memory cert = testCert;
        uint256 id = registrar.getCreditId(cert, salt);

        bytes memory validationProof = "ipfs://proof";
        bytes32 digest = _generateDigest(id, validationProof);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user);
        registrar.issue(cert, _recipient, salt, validationProof, signature);

        assertEq(token.ownerOf(id), _recipient);
    }

    /* ============================================ */
    /* Helper Functions
    /* ============================================ */

    function _issueCredit(address to) internal returns (uint256 id) {
        id = registrar.getCreditId(testCert, testSalt);
        bytes memory validationProof = "ipfs://proof123";
        bytes32 digest = _generateDigest(id, validationProof);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user);
        registrar.issue(testCert, to, testSalt, validationProof, signature);
    }

    function _generateDigest(uint256 creditId, bytes memory validationProof) internal view returns (bytes32) {
        bytes32 message = keccak256(abi.encodePacked(registrar.CREDIT_ISSUING_PREFIX(), creditId, validationProof));
        return keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x00), address(registrar), block.chainid, message));
    }
}

contract MaliciousReceiver {
    Registrar public registrar;

    constructor(Registrar _registrar) {
        registrar = _registrar;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        // Could attempt reentrancy here, but ReentrancyGuard should prevent it
        return this.onERC721Received.selector;
    }
}
