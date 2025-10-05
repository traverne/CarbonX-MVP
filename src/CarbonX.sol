// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {Base64} from "base64/base64.sol";

import {Registrar} from "./Registrar.sol";

/// @title CarbonX: On-chain ERC721 Representation of Certified Carbon Credits
/// @author Athen Traverne [athen@aetherionresearch.com]
/// @notice Version:MVP(1)
contract CarbonX is ERC721 {
    using LibString for uint256;
    using Base64 for bytes;

    string public prefix;
    address public immutable registrar;

    constructor(string memory _prefix, address _registrar) ERC721("[CarbonX] Carbon Credit", "CO2e") {
        require(_registrar != address(0x00), "Carbon Credit: Invalid address");

        registrar = _registrar;
        prefix = _prefix;
    }

    modifier authenticate() {
        require(msg.sender == registrar, "Carbon Credit: Unauthorized");
        _;
    }

    function mint(address to, uint256 id) external authenticate {
        _safeMint(to, id);

        emit Minted(id);
    }

    function burn(uint256 id) external authenticate {
        _burn(id);

        emit Burned(id);
    }

    /// @dev use staticcall for gas efficiency (direct bytes returndata)
    function tokenURI(uint256 id) public view override returns (string memory) {
        require(Registrar(registrar).isCreditIssued(id), "Carbon Credit: Invalid id");

        (bool success, bytes memory metadata) =
            registrar.staticcall(abi.encodeWithSignature("getMetadata(uint256)", id));

        require(success, "Carbon Credit: Unable to fetch from registrar");

        return string(abi.encodePacked("data:application/json;base64,", metadata.encode()));
    }

    event Minted(uint256 id);
    event Burned(uint256 id);
}
