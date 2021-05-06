/*
 * theghost.finance
 * Multi-dex Yield Farming on Fantom Opera
 *
 * Airdrop smart contract
 *
 * https://t.me/theghostfinance
 */
pragma solidity >=0.6.0<0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/// @title Ghost airdrop contract
contract GhostAirdrop is Ownable {

    using SafeMath for uint256;

    /// Mapping of whitelisted addresses
    mapping(address => bool) public whitelisted;

    /// List of participants addresses (whitelisted and unwhitelisted)
    address[] public participants;

    /// Address who claimed (or not)
    mapping(address => bool) public claimed;

    /// Weight of a whitelisted address
    mapping(address => uint256) public weights;

    /// Close the whitelisting
    bool public closed;

    /// If the airdrop is started
    bool public started;

    /// The airdropped token
    IERC20 public token;

    /// Initial claimable value without the weight
    uint256 public claimable;

    uint constant WEIGHT_1 = 2;
    uint constant WEIGHT_2 = 3;
    uint constant WEIGHT_3 = 4;

    constructor() public {
        closed = false;
        started = false;
    }

    /// @dev means that the function can be called
    /// only during the whitelist (open).
    modifier onlyWhitelist() {
        require(!closed, "GhostAirdrop: whitelist is closed");
        _;
    }

    /// @notice whitelist a list of addresses for a specific weight
    function whitelistAddrs(address[] memory addresses, uint256 weight) public onlyOwner onlyWhitelist {
        require(2 <= weight && weight <= 4 , "GhostAirdrop::whitelistAddrs: wrong weight (2-4)");
        for (uint i = 0; i < addresses.length; i++) {
            whitelisted[addresses[i]] = true;
            participants.push(addresses[i]);
            weights[addresses[i]] = weight;
        }
    }

    /// @notice whitelist one address with the weight
    function whitelistAddr(address addr, uint256 weight) public onlyOwner onlyWhitelist {
        require(2 <= weight && weight <= 4 , "GhostAirdrop::whitelistAddr: wrong weight (2-4)");
        whitelisted[addr] = true;
        participants.push(addr);
        weights[addr] = weight;
    }

    /// @notice update the weight of an whitelisted address
    function updateWeight(address addr, uint256 weight) public onlyOwner onlyWhitelist {
        require(whitelisted[addr], "GhostAirdrop::updateWeight: Addr is not whitelisted");
        require(2 <= weight && weight <= 4 , "GhostAirdrop::updateWeight: wrong weight (2-4)");
        weights[addr] = weight;
    }

    /// @notice unwhitelist a list of addresses
    function unwhitelistAddrs(address[] memory addresses) public onlyOwner onlyWhitelist {
        for (uint i = 0; i < addresses.length; i++) {
            whitelisted[addresses[i]] = false;
            weights[addresses[i]] = 0;
        }
    }

    /// @notice unwhitelist a list of addresses
    function unwhitelistAddr(address addr) public onlyOwner onlyWhitelist {
        whitelisted[addr] = false;
        weights[addr] = 0;
    }

    /// @notice close the whitelist
    /// Can't open the whitelist anymore
    function closeWhitelist() external onlyOwner onlyWhitelist {
        closed = true;
    }

    /// @notice Will start the airdrop, and calculate the claimable value
    /// (this claimable value will be multiplied with the weight in the claim function).
    function startAirdrop() external onlyOwner {
        require(closed, "GhostAirdrop::startAirdrop: Whitelist is not closed");
        require(airdropValue() > 0, "GhostAirdrop::startAirdrop: nothing to airdrop");
        require(address(token) != address(0), "GhostAirdrop::startAirdrop: the token must be setted");

        // Number of whitelisted users for every weights
        uint256 nWeight1 = 0;
        uint256 nWeight2 = 0;
        uint256 nWeight3 = 0;

        // Total whitelisted users
        uint256 nWhitelisted = 0;

        // Counting
        for (uint i = 0; i < participants.length; i++) {
            if (whitelisted[participants[i]]) {
                nWhitelisted++;
                if (weights[participants[i]] == WEIGHT_2) {
                    nWeight2++;
                } else if (weights[participants[i]] == WEIGHT_3) {
                    nWeight3++;
                } else {
                    nWeight1++;
                }
            }
        }

        // Calculate claimable
        claimable = airdropValue().div(nWeight1.mul(WEIGHT_1) + nWeight2.mul(WEIGHT_2) + nWeight3.mul(WEIGHT_3));

        // Start the airdrop, now users can claim
        started = true;
    }

    /// @notice return the token amount that will be
    /// airdroppped.
    function airdropValue() public view onlyOwner returns (uint256) {
        if (address(token) == address(0)) {
            return 0;
        } else {
            return token.balanceOf(address(this));
        }
    }

    /// @notice set the airdropped token
    function setToken(address _token) external onlyOwner {
        token = IERC20(_token);
    }

    /// @notice claim GHOST tokens
    function claim() external {
        require(started, "GhostAirdrop::claim: airdrop must be started");
        require(claimable != 0, "GhostAirdrop::claim: reward not set");
        require(whitelisted[msg.sender], "GhostAirdrop::claim: you are not whitelisted");
        require(!claimed[msg.sender], "GhostAirdrop::claim: you already claimed your tokens");

        claimed[msg.sender] = true;
        uint256 claimValue = claimable.mul(weights[msg.sender]);
        token.transfer(msg.sender, claimValue);
    }
}