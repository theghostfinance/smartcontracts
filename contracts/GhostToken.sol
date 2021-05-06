/*
 * theghost.finance
 * Multi-dex Yield Farming on Fantom Opera
 *
 * Token contract
 *
 * https://t.me/theghostfinance
 */
pragma solidity >=0.6.0<0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import "./LockedERC20.sol";

contract GhostToken is LockedERC20("theghost.finance", "GHOST"), Ownable {

    using SafeMath for uint256;

    /// Contract address of the airdrop
    address public airdropAddr;

    struct Dex {
        address router; // Router address
        address pair;   // GHOST/FTM pair address
    }

    // List of registered dex
    Dex[] public dexList;

    constructor() public {
        // 25 = 4% locked for every transfer
        liquidityLockDivisor = 25;
    }

    /// @notice Allow everybody to burn GHOST tokens
    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the MasterChef contract.
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    /// @notice update the liquidity lock divisor
    function updateLiquidityLockDivisor(uint256 _liquidityLockDivisor) external onlyOwner {
        liquidityLockDivisor = _liquidityLockDivisor;
    }

    /// @notice Add a dex with the router address.
    /// If the GHOST/FTM pair doesn't exist, it creates the pair and add
    /// the initial liquidity
    /// @param _routerAddress the router address of the new dex.
    /// @param _ghostAmount the ghost amount for initial liquidity
    /// @dev must be called from the MasterChef (owner) when adding a farming pool.
    function addDex(address _routerAddress, uint256 _ghostAmount) external payable onlyOwner returns (address pair) {
        require(_routerAddress != address(0), "GhostToken::addDex: router can't be zero address");

        address factory = IUniswapV2Router02(_routerAddress).factory();
        // get Factory address
        require(factory != address(0), "Factory can't be zero address. Given router may not exist");

        address ftm = IUniswapV2Router02(_routerAddress).WETH();
        pair = IUniswapV2Factory(factory).getPair(address(this), ftm);

        // If pair doesn't exist
        if (pair == address(0)) {
            pair = IUniswapV2Factory(factory).createPair(address(this), ftm);

            // mint GHOSTs
            _mint(address(this), _ghostAmount);
            deposit();

            addLiquidity(_ghostAmount, msg.value, _routerAddress);
        }

        // Add new dex !
        dexList.push(Dex(_routerAddress, pair));
    }

    /// @notice For every dex, use the locked liquidity
    /// Split equally between dexes
    function lockLiquidityForAllDex() external {
        uint256 tmp = liquidityLockDivisor;
        liquidityLockDivisor = 0;
        uint256 amount = lockedSupply();
        uint length = dexList.length;

        require(amount != 0, "GhostToken::lockLiquidityForAllDex: Can't lock with zero locked supply");
        require(length > 0, "GhostToken::lockLiquidityForAllDex: Need more than zero dex");

        uint256 amountSplit = amount.div(length);

        for (uint i = 0; i < length; i++) {
            lockLiquidity(amountSplit, dexList[i].router);
        }
        liquidityLockDivisor = tmp;
    }

    /// @notice Burn received LP Token (after lockLiquidity)
    /// for every dex
    function burnLiquidityForAllDex() external {
        uint length = dexList.length;
        require(length > 0, "GhostToken::burnLiquidityForAllDex: Need more than zero dex");

        for (uint i = 0; i < length; i++) {
            if (ERC20(dexList[i].pair).balanceOf(address(this)) != 0) {
                burnLiquidity(dexList[i].pair);
            }
        }
    }

    /// @notice returns the GHOST supply total of all dex from
    /// burned LP token and burnable LP token.
    function totalSupplyFromAllLockedLP() external view returns (uint256 total) {
        total = 0;
        for (uint i = 0; i < dexList.length; i++) {
            total += supplyFromLockedLP(dexList[i].pair);
        }
    }

    /// @notice returns the GHOST supply total of all dex from
    /// burned LP
    function totalSupplyFromAllBurnedLP() external view returns (uint256 total) {
        total = 0;
        for (uint i = 0; i < dexList.length; i++) {
            total += supplyFromBurnedLP(dexList[i].pair);
        }
    }

    /// @notice returns the GHOST supply total of all dex from
    /// burnable LP
    function totalSupplyFromAllBurnableLP() external view returns (uint256 total) {
        total = 0;
        for (uint i = 0; i < dexList.length; i++) {
            total += supplyFromBurnableLP(dexList[i].pair);
        }
    }

    /// @notice send the given amount to the airdrop address (managing the airdrop)
    /// Can be called once.
    function prepareAirdrop(address _airdropAddr, uint256 _amount) external onlyOwner {
        require(airdropAddr == address(0), "GhostToken::prepareAirdrop: Airdrop address already setted");
        airdropAddr = _airdropAddr;
        _mint(_airdropAddr, _amount);
    }
}