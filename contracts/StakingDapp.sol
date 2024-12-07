// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StalingDapp is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount; // Amount of tokens deposited by the user.
        uint256 rewardDebt; // Reward debt for the user.
        uint256 lockUntil; // Timestamp until funds are locked.
    }

    struct PoolInfo {
        IERC20 token; // Token to be staked in the pool.
        IERC20 rewardToken; // Token rewarded for staking.
        uint256 depositedAmount; // Total amount deposited in the pool.
        uint256 apy; // Annual Percentage Yield (in basis points).
        uint256 lockDays; // Lock period in days.
    }

    struct Notification {
        uint256 poolID; // Pool ID associated with the notification.
        uint256 amount; // Amount involved in the action.
        address user; // User associated with the action.
        string typeOf; // Type of action ("Deposit", "Withdraw", etc.).
        uint256 timestamp; // Timestamp of the notification.
    }

    uint256 public decimals = 10 ** 18;
    uint256 public poolCount;
    PoolInfo[] public poolInfo;

    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    Notification[] public notifications;

    /**
     * @dev Adds a new staking pool.
     * @param _token Token to be staked.
     * @param _rewardToken Token rewarded for staking.
     * @param _apy Annual Percentage Yield (in basis points, e.g., 1000 = 10%).
     * @param _lockDays Lock period in days.
     */
    function addPool(
        IERC20 _token,
        IERC20 _rewardToken,
        uint256 _apy,
        uint256 _lockDays
    ) public onlyOwner {
        poolInfo.push(
            PoolInfo({
                token: _token,
                rewardToken: _rewardToken,
                depositedAmount: 0,
                apy: _apy,
                lockDays: _lockDays
            })
        );
        poolCount++;
    }

    /**
     * @dev Allows users to deposit tokens into a specific pool.
     * @param poolID ID of the pool to deposit into.
     * @param amount Amount of tokens to deposit.
     */
    function deposit(uint256 poolID, uint256 amount) public nonReentrant {
        require(poolID < poolCount, "Invalid pool ID");
        PoolInfo storage pool = poolInfo[poolID];
        UserInfo storage user = userInfo[poolID][msg.sender];

        require(amount > 0, "Deposit amount must be greater than zero");
        pool.token.safeTransferFrom(msg.sender, address(this), amount);

        user.amount += amount;
        user.lockUntil = block.timestamp + (pool.lockDays * 1 days);
        pool.depositedAmount += amount;

        _createNotification(poolID, amount, msg.sender, "Deposit");
    }

    /**
     * @dev Allows users to withdraw their tokens after the lock period.
     * @param poolID ID of the pool to withdraw from.
     * @param amount Amount of tokens to withdraw.
     */
    function withdraw(uint256 poolID, uint256 amount) public nonReentrant {
        require(poolID < poolCount, "Invalid pool ID");
        PoolInfo storage pool = poolInfo[poolID];
        UserInfo storage user = userInfo[poolID][msg.sender];

        require(block.timestamp >= user.lockUntil, "Tokens are still locked");
        require(amount > 0 && amount <= user.amount, "Invalid withdraw amount");

        user.amount -= amount;
        pool.depositedAmount -= amount;
        pool.token.safeTransfer(msg.sender, amount);

        _createNotification(poolID, amount, msg.sender, "Withdraw");
    }

    /**
     * @dev Calculates pending rewards for a user in a specific pool.
     * @param poolID ID of the pool.
     * @param user Address of the user.
     */
    function _calcPendingReward(uint256 poolID, address user) internal view returns (uint256) {
        PoolInfo storage pool = poolInfo[poolID];
        UserInfo storage userInfoData = userInfo[poolID][user];

        uint256 reward = (userInfoData.amount * pool.apy * (block.timestamp - userInfoData.lockUntil)) / (365 days * 10000);
        return reward;
    }

    /**
     * @dev Public function to view pending rewards.
     * @param poolID ID of the pool.
     * @return Pending reward amount.
     */
    function pendingReward(uint256 poolID) public view returns (uint256) {
        return _calcPendingReward(poolID, msg.sender);
    }

    /**
     * @dev Internal function to create a notification.
     * @param poolID ID of the pool.
     * @param amount Amount involved.
     * @param user Address of the user.
     * @param typeOf Type of notification.
     */
    function _createNotification(uint256 poolID, uint256 amount, address user, string memory typeOf) internal {
        notifications.push(
            Notification({
                poolID: poolID,
                amount: amount,
                user: user,
                typeOf: typeOf,
                timestamp: block.timestamp
            })
        );
    }
}
