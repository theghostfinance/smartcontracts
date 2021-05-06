pragma solidity >=0.6.0<0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";


/// @title ERC-20 token with lock mechanism
contract LockedERC20 is ERC20 {

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) public {}

    using SafeMath for uint256;

    // Events
    event LockLiquidity(uint256 tokenAmount, uint256 ftmAmount, address dexV2Router);
    event BurnLiquidity(uint256 lpTokenAmount);
    event lockedSupplyUsed(uint256 amount);

    // Divisor who determines the locked percentage of every transfer
    uint256 public liquidityLockDivisor;

    /// @notice override erc-20 transfer to lock a part of
    /// tha amount in the contract.
    function _transfer(address from, address to, uint256 amount) internal override {
        // calculate liquidity lock amount
        // dont transfer burn from this contract
        // or can never lock full lockable amount
        if (liquidityLockDivisor != 0 && from != address(this)) {
            uint256 liquidityLockAmount = amount.div(liquidityLockDivisor);
            super._transfer(from, address(this), liquidityLockAmount);
            super._transfer(from, to, amount.sub(liquidityLockAmount));
        }
        else {
            super._transfer(from, to, amount);
        }
    }

    // receive FTM from dex
    receive() external payable {}

    function deposit() public payable {}

    /// @return the GHOST balance of the contract
    /// These GHOSTs are locked, and ready to be added to
    /// the liquidity.
    function lockedSupply() public view returns (uint256) {
        return balanceOf(address(this));
    }

    /// @notice after adding liquidity with the locked tokens
    /// we can burn the LP Tokens received from a specific dex by calling
    /// this function.
    function burnLiquidity(address dexV2Pair) public {
        uint256 balance = ERC20(dexV2Pair).balanceOf(address(this));
        require(balance != 0, "GouvernanceAndLockedERC20::burnLiquidity: burn amount cannot be 0");
        ERC20(dexV2Pair).transfer(address(0), balance);
        emit BurnLiquidity(balance);
    }

    /// @notice returns the GHOST supply in a specific dex Pool from
    /// burned LP token and burnable LP token.
    function supplyFromLockedLP(address dexV2Pair) public view returns (uint256) {
        uint256 lpTotalSupply = ERC20(dexV2Pair).totalSupply();
        uint256 lpLocked = lockedLiquidity(dexV2Pair);

        // (lpLocked x 100) / lpTotalSupply = percentOfLpTotalSupply
        uint256 percentOfLpTotalSupply = lpLocked.mul(1e12).div(lpTotalSupply);

        return supplyOfDexPair(percentOfLpTotalSupply, dexV2Pair);
    }

    /// @notice returns the GHOST supply in a specific dex Pool from burned LP.
    /// It means that the LP Token providing the following supply is "burned", it
    /// is locked forever.
    function supplyFromBurnedLP(address dexV2Pair) public view returns (uint256) {
        uint256 lpTotalSupply = ERC20(dexV2Pair).totalSupply();
        uint256 lpBurned = burnedLiquidity(dexV2Pair);

        // (lpBurned x 100) / lpTotalSupply = percentOfLpTotalSupply
        uint256 percentOfLpTotalSupply = lpBurned.mul(1e12).div(lpTotalSupply);

        return supplyOfDexPair(percentOfLpTotalSupply, dexV2Pair);
    }

    /// @notice returns the GHOST supply in a specific dex Pool from burnable LP.
    /// It means that the LP Token providing the following supply is "burnable", it
    /// can be locked forever (if burnLiquidity is called).
    function supplyFromBurnableLP(address dexV2Pair) virtual public view returns (uint256) {
        uint256 lpTotalSupply = ERC20(dexV2Pair).totalSupply();
        uint256 lpBurnable = burnableLiquidity(dexV2Pair);

        // (lpBurned x 100) / lpTotalSupply = percentOfLpTotalSupply
        uint256 percentOfLpTotalSupply = lpBurnable.mul(1e12).div(lpTotalSupply);

        return supplyOfDexPair(percentOfLpTotalSupply, dexV2Pair);
    }

    /// @notice returns total LP amount (not token amount) :
    /// LP burned + LP burnable (from specific dex)
    function lockedLiquidity(address dexV2Pair) public view returns (uint256) {
        return burnableLiquidity(dexV2Pair).add(burnedLiquidity(dexV2Pair));
    }

    /// @notice returns LP amount (not token amount) ready
    /// to burn (after locking liquidity) from a specific dex.
    function burnableLiquidity(address dexV2Pair) public view returns (uint256) {
        return ERC20(dexV2Pair).balanceOf(address(this));
    }

    /// @notice returns burned LP amount (not token amount) of a specific pair.
    /// We check the balanceOf of "0x" address (where the tokens are
    /// sent to be burnt).
    function burnedLiquidity(address dexV2Pair) public view returns (uint256) {
        return ERC20(dexV2Pair).balanceOf(address(0));
    }

    /// @notice Swap half of the locked GHOST for FTM, and add liquidity
    /// on a specific dex
    function lockLiquidity(uint256 amount, address dexV2Router) internal {
        // lockable supply is the token balance of this contract
        require(amount <= balanceOf(address(this)), "GouvernanceAndLockedERC20::lockLiquidity: lock amount higher than lockable balance");
        require(amount != 0, "GouvernanceAndLockedERC20::lockLiquidity: lock amount cannot be 0");

        uint256 amountToSwapForFtm = amount.div(2);
        uint256 amountToAddLiquidity = amount.sub(amountToSwapForFtm);

        // needed in case contract already owns ftm
        uint256 ftmBalanceBeforeSwap = address(this).balance;
        swapTokensForFtm(amountToSwapForFtm, dexV2Router);
        uint256 ftmReceived = address(this).balance.sub(ftmBalanceBeforeSwap);

        addLiquidity(amountToAddLiquidity, ftmReceived, dexV2Router);
        emit LockLiquidity(amountToAddLiquidity, ftmReceived, dexV2Router);
    }

    /// @notice swap GHOST for FTM on a specific dex
    /// @param dexV2Router dex router to swap
    /// @param tokenAmount the amount of GHOST to swap for FTM
    function swapTokensForFtm(uint256 tokenAmount, address dexV2Router) private {
        address[] memory dexPairPath = new address[](2);
        dexPairPath[0] = address(this);
        dexPairPath[1] = IUniswapV2Router02(dexV2Router).WETH();

        _approve(address(this), dexV2Router, tokenAmount);

        IUniswapV2Router02(dexV2Router)
        .swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            dexPairPath,
            address(this),
            block.timestamp
        );
    }

    /// @notice Add liquidity for the GHOST/FTM pool on a specific dex
    /// @param tokenAmount GHOST amount
    /// @param ftmAmount FTM amount
    /// @param dexV2Router address of the dex where we add liquidity
    function addLiquidity(uint256 tokenAmount, uint256 ftmAmount, address dexV2Router) internal {
        _approve(address(this), dexV2Router, tokenAmount);

        IUniswapV2Router02(dexV2Router)
        .addLiquidityETH
        {value:ftmAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    /// @return the GHOST supply in dex Pair, with the given percentage applied.
    /// @param percent the percentage, where x means wei%
    function supplyOfDexPair(uint256 percent, address dexV2Pair) private view returns (uint256) {
        uint256 ghostDexBalance = balanceOf(dexV2Pair);

        // (balance of GHOST in dex Pair x percent) / 100
        uint256 supply = ghostDexBalance.mul(percent).div(1e12);
        return supply;
    }
}