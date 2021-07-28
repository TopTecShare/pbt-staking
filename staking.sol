// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PBTStaking is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. PBTs to distribute per block.
        uint256 lastRewardBlock; // Last block number that PBTs distribution occurs.
        uint256 accPbtPerShare; // Accumulated PBTs per share, times 1e12. See below.
    }
    // The PBT TOKEN
    IERC20 public pbt;
    // PBT tokens minted per block.
    uint256 public pbtPerBlock;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Info of existence of each pool which allows LP token staking
    mapping(IERC20 => bool) public doesPoolExist;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The source of all PBT rewards
    uint256 public pbtForRewards = 0;
    // The block number when PBT mining starts.
    uint256 public startBlock;
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(IERC20 _pbt, uint256 _pbtPerBlock, uint256 _startBlock) {
        require(_startBlock > block.number, "StartBlock must be in the future");
        pbt = _pbt;
        pbtPerBlock = _pbtPerBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _lpToken) public onlyOwner() {
        require(!doesPoolExist[_lpToken], "Pool already exists");
        massUpdatePools();
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        doesPoolExist[_lpToken] = true;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accPbtPerShare: 0
            })
        );
    }

    // Update the given pool's PBT allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint) public onlyOwner() {
        massUpdatePools();
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        if(_allocPoint == 0) {
            doesPoolExist[poolInfo[_pid].lpToken] = false;
        }
    }

    // View function to see pending PBTs on frontend.
    function pendingPbt(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accPbtPerShare = pool.accPbtPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = block.number.sub(pool.lastRewardBlock);
            uint256 pbtReward = multiplier.mul(pbtPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accPbtPerShare = accPbtPerShare.add(pbtReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accPbtPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (!doesPoolExist[pool.lpToken]) {
            return;
        }
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number.sub(pool.lastRewardBlock);
        uint256 pbtReward = multiplier.mul(pbtPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        require(pbt.balanceOf(address(this)).sub(pbtForRewards) >= pbtReward, "Insufficient PBT tokens for rewards");
        pbtForRewards = pbtForRewards.add(pbtReward);
        pool.accPbtPerShare = pool.accPbtPerShare.add(pbtReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to PBTStaking for PBT allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accPbtPerShare).div(1e12).sub(user.rewardDebt);
            safePbtTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accPbtPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from PBTStaking.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accPbtPerShare).div(1e12).sub(user.rewardDebt);
        safePbtTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accPbtPerShare).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
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

    // Safe pbt transfer function, just in case if rounding error causes pool to not have enough PBTs.
    function safePbtTransfer(address _to, uint256 _amount) internal {
        uint256 pbtBal = pbt.balanceOf(address(this));
        if (_amount > pbtBal) {
            pbt.transfer(_to, pbtBal);
        } else {
            pbt.transfer(_to, _amount);
        }
    }
}
