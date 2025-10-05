// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {CarbonX} from "../src/CarbonX.sol";
import {Registrar, Certification, Standard} from "../src/Registrar.sol";

/// @title CarbonX: Unit Testing for CarbonX Contract
/// @author Athen Traverne [athen@aetherionresearch.com], et al
/// @notice Auto-generated using AI Agents
contract CarbonXTest is Test {
    CarbonX public token;
    Registrar public registrar;

    address public owner;
    address public validator;
    address public user;
    address public recipient;

    uint256 public validatorPrivateKey;

    Certification public testCert;
    bytes32 public testSalt;

    event Minted(uint256 id);
    event Burned(uint256 id);
    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        recipient = makeAddr("recipient");

        validatorPrivateKey = 0xA11CE;
        validator = vm.addr(validatorPrivateKey);

        vm.prank(owner);
        registrar = new Registrar("CARBON", owner);
        token = registrar.token();

        vm.prank(owner);
        registrar.addValidator(validator);

        testCert = Certification({
            project_name: "Wind Farm Project",
            issuer_name: "Renewable Energy Inc",
            location: "Texas, USA",
            methodology: "ACM0003",
            amount: 500,
            vintage_year: 2024,
            expiry: block.timestamp + 365 days,
            standard: Standard.GoldStandard
        });

        testSalt = keccak256("test_salt");
    }

    /* ============================================ */
    /* Constructor Tests
    /* ============================================ */

    function test_Constructor() public view {
        assertEq(token.name(), "[CarbonX] Carbon Credit");
        assertEq(token.symbol(), "CO2e");
        assertEq(token.prefix(), "CARBON");
        assertEq(token.registrar(), address(registrar));
    }

    function test_Constructor_RevertWhen_ZeroAddress() public {
        vm.expectRevert("Carbon Credit: Invalid address");
        new CarbonX("TEST", address(0));
    }

    /* ============================================ */
    /* Mint Tests
    /* ============================================ */

    function test_Mint() public {
        uint256 tokenId = 1;

        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), recipient, tokenId);

        vm.expectEmit(true, false, false, false);
        emit Minted(tokenId);

        vm.prank(address(registrar));
        token.mint(recipient, tokenId);

        assertEq(token.ownerOf(tokenId), recipient);
        assertEq(token.balanceOf(recipient), 1);
    }

    function test_Mint_MultipleTokens() public {
        vm.startPrank(address(registrar));

        token.mint(user, 1);
        token.mint(user, 2);
        token.mint(recipient, 3);

        vm.stopPrank();

        assertEq(token.balanceOf(user), 2);
        assertEq(token.balanceOf(recipient), 1);
        assertEq(token.ownerOf(1), user);
        assertEq(token.ownerOf(2), user);
        assertEq(token.ownerOf(3), recipient);
    }

    function test_Mint_RevertWhen_NotRegistrar() public {
        vm.expectRevert("Carbon Credit: Unauthorized");
        vm.prank(user);
        token.mint(recipient, 1);
    }

    function test_Mint_RevertWhen_ToZeroAddress() public {
        vm.expectRevert();
        vm.prank(address(registrar));
        token.mint(address(0), 1);
    }

    function test_Mint_RevertWhen_TokenAlreadyMinted() public {
        vm.startPrank(address(registrar));
        token.mint(user, 1);

        vm.expectRevert();
        token.mint(recipient, 1);
        vm.stopPrank();
    }

    /* ============================================ */
    /* Burn Tests
    /* ============================================ */

    function test_Burn() public {
        uint256 tokenId = 1;

        vm.prank(address(registrar));
        token.mint(user, tokenId);

        assertEq(token.ownerOf(tokenId), user);

        vm.expectEmit(true, true, true, false);
        emit Transfer(user, address(0), tokenId);

        vm.expectEmit(true, false, false, false);
        emit Burned(tokenId);

        vm.prank(address(registrar));
        token.burn(tokenId);

        assertEq(token.balanceOf(user), 0);

        vm.expectRevert();
        token.ownerOf(tokenId);
    }

    function test_Burn_RevertWhen_NotRegistrar() public {
        vm.prank(address(registrar));
        token.mint(user, 1);

        vm.expectRevert("Carbon Credit: Unauthorized");
        vm.prank(user);
        token.burn(1);
    }

    function test_Burn_RevertWhen_TokenNotMinted() public {
        vm.expectRevert();
        vm.prank(address(registrar));
        token.burn(999);
    }

    /* ============================================ */
    /* ERC721 Standard Tests
    /* ============================================ */

    function test_Transfer() public {
        uint256 tokenId = 1;

        vm.prank(address(registrar));
        token.mint(user, tokenId);

        vm.expectEmit(true, true, true, false);
        emit Transfer(user, recipient, tokenId);

        vm.prank(user);
        token.transferFrom(user, recipient, tokenId);

        assertEq(token.ownerOf(tokenId), recipient);
        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(recipient), 1);
    }

    function test_Transfer_RevertWhen_NotOwner() public {
        vm.prank(address(registrar));
        token.mint(user, 1);

        vm.expectRevert();
        vm.prank(recipient);
        token.transferFrom(user, recipient, 1);
    }

    function test_Approve() public {
        uint256 tokenId = 1;

        vm.prank(address(registrar));
        token.mint(user, tokenId);

        vm.expectEmit(true, true, true, false);
        emit Approval(user, recipient, tokenId);

        vm.prank(user);
        token.approve(recipient, tokenId);

        assertEq(token.getApproved(tokenId), recipient);
    }

    function test_Approve_Transfer() public {
        uint256 tokenId = 1;

        vm.prank(address(registrar));
        token.mint(user, tokenId);

        vm.prank(user);
        token.approve(recipient, tokenId);

        vm.prank(recipient);
        token.transferFrom(user, recipient, tokenId);

        assertEq(token.ownerOf(tokenId), recipient);
    }

    function test_ApprovalForAll() public {
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(user, recipient, true);

        vm.prank(user);
        token.setApprovalForAll(recipient, true);

        assertTrue(token.isApprovedForAll(user, recipient));
    }

    function test_ApprovalForAll_Transfer() public {
        vm.prank(address(registrar));
        token.mint(user, 1);

        vm.prank(address(registrar));
        token.mint(user, 2);

        vm.prank(user);
        token.setApprovalForAll(recipient, true);

        vm.startPrank(recipient);
        token.transferFrom(user, recipient, 1);
        token.transferFrom(user, recipient, 2);
        vm.stopPrank();

        assertEq(token.ownerOf(1), recipient);
        assertEq(token.ownerOf(2), recipient);
        assertEq(token.balanceOf(recipient), 2);
    }

    function test_SafeTransferFrom() public {
        uint256 tokenId = 1;

        vm.prank(address(registrar));
        token.mint(user, tokenId);

        vm.prank(user);
        token.safeTransferFrom(user, recipient, tokenId);

        assertEq(token.ownerOf(tokenId), recipient);
    }

    function test_SafeTransferFrom_WithData() public {
        uint256 tokenId = 1;

        vm.prank(address(registrar));
        token.mint(user, tokenId);

        bytes memory data = "test data";

        vm.prank(user);
        token.safeTransferFrom(user, recipient, tokenId, data);

        assertEq(token.ownerOf(tokenId), recipient);
    }

    function test_SafeTransferFrom_ToContract() public {
        uint256 tokenId = 1;

        ERC721Receiver receiver = new ERC721Receiver();

        vm.prank(address(registrar));
        token.mint(user, tokenId);

        vm.prank(user);
        token.safeTransferFrom(user, address(receiver), tokenId);

        assertEq(token.ownerOf(tokenId), address(receiver));
    }

    function test_SafeTransferFrom_RevertWhen_InvalidReceiver() public {
        uint256 tokenId = 1;

        InvalidReceiver receiver = new InvalidReceiver();

        vm.prank(address(registrar));
        token.mint(user, tokenId);

        vm.expectRevert();
        vm.prank(user);
        token.safeTransferFrom(user, address(receiver), tokenId);
    }

    /* ============================================ */
    /* TokenURI Tests
    /* ============================================ */

    function test_TokenURI() public {
        uint256 id = _issueCredit(user);

        string memory uri = token.tokenURI(id);

        assertTrue(bytes(uri).length > 0);
        assertTrue(_startsWith(uri, "data:application/json;base64,"));
    }

    function test_TokenURI_RevertWhen_TokenNotMinted() public {
        vm.expectRevert();
        token.tokenURI(999);
    }

    function test_TokenURI_AfterRetire() public {
        uint256 id = _issueCredit(user);

        vm.prank(user);
        registrar.retire(id);

        // TokenURI should still work even after retirement
        // as metadata is still stored in registrar
        string memory uri = token.tokenURI(id);
        assertTrue(bytes(uri).length > 0);
    }

    /* ============================================ */
    /* Integration Tests with Registrar
    /* ============================================ */

    function test_Integration_IssueAndTransfer() public {
        uint256 id = _issueCredit(user);

        assertEq(token.ownerOf(id), user);

        vm.prank(user);
        token.transferFrom(user, recipient, id);

        assertEq(token.ownerOf(id), recipient);
    }

    function test_Integration_IssueAndRetire() public {
        uint256 id = _issueCredit(user);

        assertEq(token.balanceOf(user), 1);

        vm.prank(user);
        registrar.retire(id);

        assertEq(token.balanceOf(user), 0);

        vm.expectRevert();
        token.ownerOf(id);
    }

    function test_Integration_TransferAndRetire() public {
        uint256 id = _issueCredit(user);

        vm.prank(user);
        token.transferFrom(user, recipient, id);

        vm.prank(recipient);
        registrar.retire(id);

        assertTrue(registrar.isCreditRetired(id));

        vm.expectRevert();
        token.ownerOf(id);
    }

    function test_Integration_ApproveAndRetire() public {
        uint256 id = _issueCredit(user);

        vm.prank(user);
        token.approve(recipient, id);

        vm.prank(recipient);
        registrar.retire(id);

        assertTrue(registrar.isCreditRetired(id));
    }

    function test_Integration_MultipleCredits() public {
        Certification memory cert1 = testCert;
        Certification memory cert2 = testCert;
        cert2.project_name = "Solar Project";

        bytes32 salt1 = keccak256("salt1");
        bytes32 salt2 = keccak256("salt2");

        uint256 id1 = _issueCreditWithParams(user, cert1, salt1);
        uint256 id2 = _issueCreditWithParams(recipient, cert2, salt2);

        assertEq(token.balanceOf(user), 1);
        assertEq(token.balanceOf(recipient), 1);
        assertEq(token.ownerOf(id1), user);
        assertEq(token.ownerOf(id2), recipient);

        assertTrue(id1 != id2);
    }

    /* ============================================ */
    /* SupportsInterface Tests
    /* ============================================ */

    function test_SupportsInterface_ERC721() public view {
        // ERC721 interface ID
        assertTrue(token.supportsInterface(0x80ac58cd));
    }

    function test_SupportsInterface_ERC165() public view {
        // ERC165 interface ID
        assertTrue(token.supportsInterface(0x01ffc9a7));
    }

    function test_SupportsInterface_Invalid() public view {
        assertFalse(token.supportsInterface(0xffffffff));
    }

    /* ============================================ */
    /* Edge Cases Tests
    /* ============================================ */

    function test_BalanceOf_ZeroBalance() public view {
        assertEq(token.balanceOf(user), 0);
    }

    function test_GetApproved_NoApproval() public {
        vm.prank(address(registrar));
        token.mint(user, 1);

        assertEq(token.getApproved(1), address(0));
    }

    function test_Approve_ClearApproval() public {
        vm.prank(address(registrar));
        token.mint(user, 1);

        vm.prank(user);
        token.approve(recipient, 1);

        assertEq(token.getApproved(1), recipient);

        vm.prank(user);
        token.approve(address(0), 1);

        assertEq(token.getApproved(1), address(0));
    }

    function test_Transfer_ClearsApproval() public {
        vm.prank(address(registrar));
        token.mint(user, 1);

        vm.prank(user);
        token.approve(makeAddr("someone"), 1);

        vm.prank(user);
        token.transferFrom(user, recipient, 1);

        assertEq(token.getApproved(1), address(0));
    }

    /* ============================================ */
    /* Fuzz Tests
    /* ============================================ */

    function testFuzz_Mint(address to, uint256 tokenId) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);

        vm.prank(address(registrar));
        token.mint(to, tokenId);

        assertEq(token.ownerOf(tokenId), to);
        assertEq(token.balanceOf(to), 1);
    }

    function testFuzz_Transfer(address from, address to, uint256 tokenId) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        vm.assume(from.code.length == 0 && to.code.length == 0);

        vm.prank(address(registrar));
        token.mint(from, tokenId);

        vm.prank(from);
        token.transferFrom(from, to, tokenId);

        assertEq(token.ownerOf(tokenId), to);
    }

    function testFuzz_Approve(address owner, address spender, uint256 tokenId) public {
        vm.assume(owner != address(0) && spender != address(0));
        vm.assume(owner.code.length == 0);

        vm.prank(address(registrar));
        token.mint(owner, tokenId);

        vm.prank(owner);
        token.approve(spender, tokenId);

        assertEq(token.getApproved(tokenId), spender);
    }

    function testFuzz_SetApprovalForAll(address owner, address operator, bool approved) public {
        vm.assume(owner != address(0) && operator != address(0));

        vm.prank(owner);
        token.setApprovalForAll(operator, approved);

        assertEq(token.isApprovedForAll(owner, operator), approved);
    }

    /* ============================================ */
    /* Gas Tests
    /* ============================================ */

    function test_Gas_Mint() public {
        uint256 gasBefore = gasleft();

        vm.prank(address(registrar));
        token.mint(user, 1);

        uint256 gasUsed = gasBefore - gasleft();
        console2.log("Gas used for mint:", gasUsed);

        assertTrue(gasUsed < 100000);
    }

    function test_Gas_Transfer() public {
        vm.prank(address(registrar));
        token.mint(user, 1);

        uint256 gasBefore = gasleft();

        vm.prank(user);
        token.transferFrom(user, recipient, 1);

        uint256 gasUsed = gasBefore - gasleft();
        console2.log("Gas used for transfer:", gasUsed);

        assertTrue(gasUsed < 100000);
    }

    function test_Gas_Burn() public {
        vm.prank(address(registrar));
        token.mint(user, 1);

        uint256 gasBefore = gasleft();

        vm.prank(address(registrar));
        token.burn(1);

        uint256 gasUsed = gasBefore - gasleft();
        console2.log("Gas used for burn:", gasUsed);

        assertTrue(gasUsed < 100000);
    }

    /* ============================================ */
    /* Helper Functions
    /* ============================================ */

    function _issueCredit(address to) internal returns (uint256 id) {
        return _issueCreditWithParams(to, testCert, testSalt);
    }

    function _issueCreditWithParams(
        address to,
        Certification memory cert,
        bytes32 salt
    ) internal returns (uint256 id) {
        id = registrar.getCreditId(cert, salt);
        bytes memory validationProof = "ipfs://proof";
        bytes32 digest = _generateDigest(id, validationProof);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user);
        registrar.issue(cert, to, salt, validationProof, signature);
    }

    function _generateDigest(uint256 creditId, bytes memory validationProof) internal view returns (bytes32) {
        bytes32 message = keccak256(
            abi.encodePacked(registrar.CREDIT_ISSUING_PREFIX(), creditId, validationProof)
        );
        return keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x00),
                address(registrar),
                block.chainid,
                message
            )
        );
    }

    function _startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);

        if (strBytes.length < prefixBytes.length) {
            return false;
        }

        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) {
                return false;
            }
        }

        return true;
    }
}

/* ============================================ */
/* Mock Contracts for Testing
/* ============================================ */

contract ERC721Receiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract InvalidReceiver {
    // Does not implement onERC721Received
}

contract ReentrantReceiver {
    CarbonX public token;
    bool public attacked;

    constructor(CarbonX _token) {
        token = _token;
    }

    function onERC721Received(
        address,
        address,
        uint256 tokenId,
        bytes calldata
    ) external returns (bytes4) {
        if (!attacked) {
            attacked = true;
            // Try to transfer the token again (should fail due to state changes)
            token.transferFrom(address(this), msg.sender, tokenId);
        }
        return this.onERC721Received.selector;
    }
}
