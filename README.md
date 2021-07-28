# PBT-Staking
Smart contract that rewards PBT for staking LP tokens

## Deliverables:
- ERC20 contract
- PB LP Staking contract for ERC20 rewards
- Uni LP Staking contract for ERC20 rewards
- Web 3 integration scripts for the contracts
- Detailed documentation of the contracts.

## How the core logic works
At any point in time, the amount of PBTs entitled to a user but is pending to be distributed is:

	`pending reward = (user.amount * pool.accPbtPerShare) - user.rewardDebt`

Whenever a user deposits or withdraws LP tokens (both PB and Uni), Here's what happens:
  1. The pool's `accPbtPerShare` (and `lastRewardBlock`) gets updated.
  2. User receives the pending reward sent to his/her address.
  3. User's `amount` gets updated.
  4. User's `rewardDebt` gets updated.

## Function Descriptions (only callable by Owner)

### Constructor
Deploys the contract
- `IERC20 _pbt` : address of the PBT token
- `uint256 _pbtPerBlock` : number of PBT to be minted per block (scaled by 10^18)
- `uint256 _startBlock` : the block to start giving out rewards from (has to be a block in the future)

###  add
Add a new LP to the contract.
- `uint256 _allocPoint` : relative ratio of allocation points of rewards to award to this LP
- `IERC20 _lpToken` : address of the LP token to allow to be staked

### set
Update the given pool's PBT allocation point
- `uint256 _pid` : the pool ID of the pool
- `uint256 _allocPoint` : new relative ratio of allocation points of rewards to award to this LP

## Function Descriptions (callable by anyone)

### deposit
Deposit LP tokens to PBTStaking for PBT allocation
- `uint256 _pid` : the pool ID of the pool
- `uint256 _amount` : the number of LP tokens to deposit

### withdraw
Withdraw LP tokens (and rewards) from PBTStaking
- `uint256 _pid` : the pool ID of the pool
- `uint256 _amount` : the number of LP tokens to withdraw