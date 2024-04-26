// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23;

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Arrays } from "@openzeppelin/contracts/utils/Arrays.sol";

contract InverterTeamNFT is ERC1155Upgradeable, OwnableUpgradeable {
    using Arrays for uint256[];
    using Arrays for address[];

    address public authorizedMinter;
    mapping(bytes32 teamMemberName => uint256 tokenId) public teamMemberNameToTokenId;
    mapping(address teamMemberAddress => uint256 tokenId) private teamMemberAddressToTokenId;
    uint256 private tokenCounter;

    error InverterTeamNFT__NftAlreadyOwned();
    error InverterTeamNFT__InvalidAddress();
    error InverterTeamNFT__UnAuthorizedMinter();
    error InverterTeamNFT__TeamMemberAlreadyExists();
    error InverterTeamNFT__ArrayLengthMismatch();
    error InverterTeamNFT__NftIsNontransferable();

    // Todo: Getter functions?
    // TODO: What about removing team members?
    // Todo: update address for team member to attest, to make future proof

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC1155")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC1155StorageLocationInternal =
        0x88be536d5240c274a3b1d3a1be54482fd9caa294f08c62a7cde569f49a3c4500;

    function _getERC1155StorageInternal() private pure returns (ERC1155Storage storage $) {
        assembly {
            $.slot := ERC1155StorageLocationInternal
        }
    }

    modifier notOwnedYet(address _receiver, uint256 _teamNftId) {
        if (balanceOf(_receiver, _teamNftId) > 0) revert InverterTeamNFT__NftAlreadyOwned();
        _;
    }

    modifier onlyAuthorizedMinter() {
        if (_msgSender() != authorizedMinter) revert InverterTeamNFT__UnAuthorizedMinter();
        _;
    }

    function init(
        string memory uri_,
        address _authorizedMinter,
        bytes32[] memory _names,
        address[] memory _addresses
    )
        public
        initializer
    {
        __Ownable_init(_msgSender());
        __ERC1155_init(uri_);
        // Set backend service address which will mint tokens
        authorizedMinter = _authorizedMinter;
        // Set counter to initial value
        tokenCounter = 1;
        // Add initial names to array
        uint256 arrayLength = _names.length;
        if (arrayLength != _addresses.length) revert InverterTeamNFT__ArrayLengthMismatch();
        for (uint256 i; i < arrayLength; i++) {
            _addNameToMapping(_names[i], _addresses[i]);
        }
    }

    function mintTeamMemberNFT(address _receiver, uint256 _teamNftId) external onlyAuthorizedMinter {
        _mintTeamNFT(_receiver, _teamNftId);
    }

    function batchMintTeamMemberNFTs(
        address[] memory _receivers,
        uint256[] memory _teamNftIds
    )
        external
        onlyAuthorizedMinter
    {
        uint256 arrayLength = _receivers.length;
        if (arrayLength != _teamNftIds.length) revert InverterTeamNFT__ArrayLengthMismatch();

        for (uint256 i; i < arrayLength; i++) {
            _mintTeamNFT(_receivers[i], _teamNftIds[i]);
        }
    }

    function setAuthorizedMinter(address _authorizedMinter) external onlyOwner {
        if (_authorizedMinter == address(0)) revert InverterTeamNFT__InvalidAddress();
        authorizedMinter = _authorizedMinter;
    }

    function addTeamMemberNFT(bytes32 _teamMemberName, address _teamMemberAddress) external onlyOwner {
        _addNameToMapping(_teamMemberName, _teamMemberAddress);
    }

    function _mintTeamNFT(address _receiver, uint256 _teamNftId) internal notOwnedYet(_receiver, _teamNftId) {
        _mint(_receiver, _teamNftId, 1, "");
    }

    function _addNameToMapping(bytes32 _teamMemberName, address _teamMemberAddress) internal {
        if (teamMemberNameToTokenId[_teamMemberName] > 0) revert InverterTeamNFT__TeamMemberAlreadyExists();
        if (_teamMemberAddress == address(0)) revert InverterTeamNFT__InvalidAddress();
        if (teamMemberAddressToTokenId[_teamMemberAddress] > 0) revert InverterTeamNFT__TeamMemberAlreadyExists();
        // Map name to token ID
        teamMemberNameToTokenId[_teamMemberName] = tokenCounter;
        // Map address to token ID for attestation
        teamMemberAddressToTokenId[_teamMemberAddress] = tokenCounter;
        tokenCounter++;
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal override {
        ERC1155Storage storage $ = _getERC1155StorageInternal();
        if (ids.length != values.length) {
            revert ERC1155InvalidArrayLength(ids.length, values.length);
        }

        address operator = _msgSender();

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids.unsafeMemoryAccess(i);
            uint256 value = values.unsafeMemoryAccess(i);

            if (from != address(0)) {
                revert InverterTeamNFT__NftIsNontransferable();
            }

            if (to != address(0)) {
                $._balances[id][to] += value;
            }
        }

        if (ids.length == 1) {
            uint256 id = ids.unsafeMemoryAccess(0);
            uint256 value = values.unsafeMemoryAccess(0);
            emit TransferSingle(operator, from, to, id, value);
        } else {
            emit TransferBatch(operator, from, to, ids, values);
        }
    }
}
