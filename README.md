# PBT-Staking
Smart contract that rewards PBT for staking LP tokens

## Deliverables:
- ERC20 contract
- PB LP Staking contract for ERC20 rewards
- Uni LP Staking contract for ERC20 rewards
- Web 3 integration scripts for the contracts
- Detailed documentation of the contracts.

## How the core logic works (the mathematics)
At any point in time, the amount of PBTs entitled to a user, and are pending to be distributed is:

  `pending reward = (user.amount * pool.accPbtPerShare) - user.rewardDebt`
  Which translates to: 
    pending reward = (amount staked by user) * (proportional share of the user in pool) - (rewards already paid to user)

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


## Entire Workflow

1. Owner(you) deploys the contract with the constructor arguments mentioned above
2. Owner(you) sends PBT tokens that you want to be distributed over the next 1 year (or any time frame) to the contract address. The contract will continue to function till the time it has sufficient PBT tokens to distribute.
Approximate time calculation is as follows:
  Time contract will function (in seconds) = (tokens sent / tokens per block) * 13
3. Owner(you) can add 1 or more pools using the `add` function above.
  2.1. Suppose you want to add 2 LP with addresses `0xabcd` and `0x1234` and equal weight, you will call the add function twice as follows:
    `add(100, 0xabcd)`
    `add(100, 0x1234)`
  Each distinct pool generates a sequential pid.
3. User approves the contract to spend their LP tokens
4. User calls `deposit` function with the pid of pool and amount of tokens to deposit.
5. At any time in the future, the user can call the `withdraw` function with same arguments as above to withdraw their tokens.
6. They can also call the `deposit` function with amount=0, to only claim their rewards, and not deposit/withdraw any principal tokens.
3. Owner(you) can retire a pool by calling the `set` function with the pool's pid, and `_allocPoint` = 0.