/*
 * theghost.finance
 * Multi-dex Yield Farming on Fantom Opera
 *
 * Yield Farming Smart Contract
 *
 * https://t.me/theghostfinance
 */
pragma solidity >=0.6.0<0.8.0;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GhostToken.sol";


contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of GHOSTs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accGhostPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accGhostPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. GHOSTs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that GHOSTs distribution occurs.
        uint256 accGhostPerShare; // Accumulated GHOSTs per share, times 1e12. See below.
    }

    GhostToken public ghost;

    // Dev address.
    address public devAddr;

    // Block number when bonus GHOST period ends.
    uint256 public bonusEndBlock;
    // GHOST tokens created per block.
    uint256 public ghostPerBlock;
    // Bonus muliplier for early ghost makers.
    uint256 public constant BONUS_MULTIPLIER = 10;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when GHOST mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        GhostToken _ghost,
        address _devAddr,
        uint256 _ghostPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public {
        ghost = _ghost;
        devAddr = _devAddr;
        ghostPerBlock = _ghostPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
    }

    receive() external payable {}

    function deposit() public payable {}

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // The LP is added via the router address.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, address _router, bool _withUpdate, uint256 _ghostAmount) public payable onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }

        deposit();
        IERC20 _lpToken = IERC20(ghost.addDex{value: msg.value}(_router, _ghostAmount));

        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accGhostPerShare: 0
        }));
    }

    // Update the given pool's GHOST allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function setBonusEndBlock(uint256 _bonusEndBlock) public onlyOwner {
        bonusEndBlock = _bonusEndBlock;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                _to.sub(bonusEndBlock)
            );
        }
    }

    // View function to see pending GHOSTs on frontend.
    function pendingGhost(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accGhostPerShare = pool.accGhostPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 ghostReward = multiplier.mul(ghostPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accGhostPerShare = accGhostPerShare.add(ghostReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accGhostPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 ghostReward = multiplier.mul(ghostPerBlock).mul(pool.allocPoint).div(totalAllocPoint);

        ghost.mint(devAddr, ghostReward.div(10));

        ghost.mint(address(this), ghostReward);
        pool.accGhostPerShare = pool.accGhostPerShare.add(ghostReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to GhostFarm for GHOST allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accGhostPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                safeGhostTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accGhostPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from GhostFarm.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accGhostPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safeGhostTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accGhostPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    /// @notice update the ghost per block
    function updateGhostPerBlock(uint256 _ghostPerBlock) external onlyOwner {
        massUpdatePools();
        ghostPerBlock = _ghostPerBlock;
    }

    /// @notice update the liquidity lock divisor
    function updateLiquidityLockDivisor(uint256 _liquidityLockDivisor) external onlyOwner {
        ghost.updateLiquidityLockDivisor(_liquidityLockDivisor);
    }

    // Safe ghost transfer function, just in case if rounding error causes pool to not have enough GHOSTs.
    function safeGhostTransfer(address _to, uint256 _amount) internal {
        uint256 ghostBal = ghost.balanceOf(address(this));
        if (_amount > ghostBal) {
            ghost.transfer(_to, ghostBal);
        } else {
            ghost.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devAddr) public {
        require(msg.sender == devAddr, 'you no dev: wut?');
        devAddr = _devAddr;
    }
}