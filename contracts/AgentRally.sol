// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal interface of the Agent ID registry (SPACE ID Agent ID, ERC-721).
/// Registry on BNB Chain: 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
interface IAgentIdRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title AgentRally — Daily check-in club for Agent ID holders
/// @notice Holders of an Agent ID (.ai) check in once per day to build streaks.
///         Reaching total check-in milestones automatically mints soulbound
///         ERC-721 badges. The contract has NO owner and NO admin functions:
///         nobody can pause it, change the rules, or touch user badges.
contract AgentRally {
    // ------------------------------------------------------------------
    // Constants
    // ------------------------------------------------------------------

    /// @notice The Agent ID registry checked for eligibility. Set once at
    /// deployment to the official registry on BNB Chain:
    /// 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F. Immutable — it can never change.
    IAgentIdRegistry public immutable AGENT_ID_REGISTRY;

    /// @notice Total check-ins required per badge tier (tier 1..4).
    uint32 public constant TIER1_AT = 1;
    uint32 public constant TIER2_AT = 3;
    uint32 public constant TIER3_AT = 7;
    uint32 public constant TIER4_AT = 14;
    uint8 public constant MAX_TIER = 4;

    // ------------------------------------------------------------------
    // Badge NFT (minimal soulbound ERC-721)
    // ------------------------------------------------------------------

    string public name = "Agent Rally Badge";
    string public symbol = "RALLY";
    string public baseURI;

    uint256 private _nextTokenId = 1;
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _badgeBalances;
    mapping(uint256 => uint8) public badgeTierOf;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    // ------------------------------------------------------------------
    // Check-in state
    // ------------------------------------------------------------------

    struct Stats {
        uint32 totalCheckIns;
        uint32 currentStreak;
        uint32 bestStreak;
        uint32 lastDay; // day index (unix / 86400) of the last check-in
        uint8 badgesMinted; // highest tier minted so far
    }

    mapping(address => Stats) public stats;
    /// @notice user => tier => tokenId (0 means not minted yet)
    mapping(address => mapping(uint8 => uint256)) public badgeTokenOf;

    uint256 public totalAgents; // unique addresses that ever checked in
    uint256 public totalCheckInsAll;
    uint256 public checkInsToday;
    uint256 private _todayDay;

    event CheckedIn(address indexed user, uint256 day, uint32 currentStreak, uint32 totalCheckIns);
    event BadgeMinted(address indexed user, uint8 tier, uint256 tokenId);

    constructor(address agentIdRegistry_, string memory baseURI_) {
        AGENT_ID_REGISTRY = IAgentIdRegistry(agentIdRegistry_);
        baseURI = baseURI_;
    }

    // ------------------------------------------------------------------
    // Core: daily check-in
    // ------------------------------------------------------------------

    function hasAgentId(address user) public view returns (bool) {
        return AGENT_ID_REGISTRY.balanceOf(user) > 0;
    }

    function currentDay() public view returns (uint256) {
        return block.timestamp / 1 days;
    }

    function checkIn() external {
        require(hasAgentId(msg.sender), "Agent ID required");

        uint256 day = currentDay();
        Stats storage s = stats[msg.sender];
        require(!(s.totalCheckIns > 0 && s.lastDay == day), "Already checked in today");

        if (s.totalCheckIns == 0) {
            totalAgents += 1;
        }
        if (s.totalCheckIns > 0 && s.lastDay == day - 1) {
            s.currentStreak += 1;
        } else {
            s.currentStreak = 1;
        }
        if (s.currentStreak > s.bestStreak) {
            s.bestStreak = s.currentStreak;
        }
        s.lastDay = uint32(day);
        s.totalCheckIns += 1;
        totalCheckInsAll += 1;

        if (_todayDay != day) {
            _todayDay = day;
            checkInsToday = 1;
        } else {
            checkInsToday += 1;
        }

        emit CheckedIn(msg.sender, day, s.currentStreak, s.totalCheckIns);

        _mintDueBadges(msg.sender, s);
    }

    function _threshold(uint8 tier) internal pure returns (uint32) {
        if (tier == 1) return TIER1_AT;
        if (tier == 2) return TIER2_AT;
        if (tier == 3) return TIER3_AT;
        return TIER4_AT;
    }

    function _mintDueBadges(address user, Stats storage s) internal {
        while (s.badgesMinted < MAX_TIER && s.totalCheckIns >= _threshold(s.badgesMinted + 1)) {
            uint8 tier = s.badgesMinted + 1;
            uint256 tokenId = _nextTokenId++;
            _owners[tokenId] = user;
            _badgeBalances[user] += 1;
            badgeTierOf[tokenId] = tier;
            badgeTokenOf[user][tier] = tokenId;
            s.badgesMinted = tier;
            emit Transfer(address(0), user, tokenId);
            emit BadgeMinted(user, tier, tokenId);
        }
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    function getStats(address user)
        external
        view
        returns (
            uint32 totalCheckIns,
            uint32 currentStreak,
            uint32 bestStreak,
            uint32 lastDay,
            uint8 badgesMinted,
            bool checkedInToday
        )
    {
        Stats storage s = stats[user];
        return (
            s.totalCheckIns,
            s.currentStreak,
            s.bestStreak,
            s.lastDay,
            s.badgesMinted,
            s.totalCheckIns > 0 && s.lastDay == currentDay()
        );
    }

    // ------------------------------------------------------------------
    // ERC-721 (soulbound: transfers and approvals always revert)
    // ------------------------------------------------------------------

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "Zero address");
        return _badgeBalances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "Nonexistent token");
        return owner;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_owners[tokenId] != address(0), "Nonexistent token");
        return string(abi.encodePacked(baseURI, _toString(badgeTierOf[tokenId]), ".json"));
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165
            interfaceId == 0x80ac58cd || // ERC721
            interfaceId == 0x5b5e139f; // ERC721Metadata
    }

    function approve(address, uint256) external pure {
        revert("Soulbound: approvals disabled");
    }

    function getApproved(uint256) external pure returns (address) {
        return address(0);
    }

    function setApprovalForAll(address, bool) external pure {
        revert("Soulbound: approvals disabled");
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) external pure {
        revert("Soulbound: non-transferable");
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert("Soulbound: non-transferable");
    }

    function safeTransferFrom(address, address, uint256, bytes memory) external pure {
        revert("Soulbound: non-transferable");
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
