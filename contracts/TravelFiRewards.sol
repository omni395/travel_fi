// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./01-TravelFiToken.sol";

/// @title TravelFiRewards
/// @notice Reward pool-контракт: выдаёт токены TFT из своего баланса по вызову оператора.
/// On-chain vesting убран: лок-период ведётся на бэке (TokenTransaction#claimed).
contract TravelFiRewards is ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    TravelFiToken public token;
    IERC20 public usdt;

    event RewardsSent(address indexed user, uint256 tokens, uint256 timestamp);
    event TokensWithdrawn(address indexed operator, address indexed to, address token, uint256 amount, uint256 timestamp);

    receive() external payable {}

    constructor(address _token, address _usdt) {
        require(_token != address(0), "Invalid token address");
        require(_usdt != address(0), "Invalid USDT address");

        token = TravelFiToken(payable(_token));
        usdt = IERC20(_usdt);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    /// @notice Начисляет TFT пользователю (прямой перевод из пула). Без lock:
    /// блокировка ведётся на бэке. Токены берутся из баланса пула (НЕ mint).
    function sendReward(address user, uint256 tokensWei) external nonReentrant whenNotPaused {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender), "Not admin or operator");
        require(user != address(0), "Invalid user");
        require(tokensWei > 0, "Amount must be > 0");
        require(token.balanceOf(address(this)) >= tokensWei, "Insufficient TFT balance in reward pool");

        token.transfer(user, tokensWei);
        emit RewardsSent(user, tokensWei, block.timestamp);
    }

    /// @notice Пакетное начисление TFT группе пользователей (акции). Один вызов = одна tx.
    function sendRewardBatch(address[] calldata users, uint256[] calldata amountsWei) external nonReentrant whenNotPaused {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender), "Not admin or operator");
        require(users.length > 0 && users.length <= 50, "Batch size out of bounds (1-50)");
        require(users.length == amountsWei.length, "Array length mismatch");

        uint256 totalBatchAmount = 0;
        for (uint256 i = 0; i < amountsWei.length; i++) {
            totalBatchAmount += amountsWei[i];
        }
        require(token.balanceOf(address(this)) >= totalBatchAmount, "Insufficient TFT in pool for batch");

        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "Invalid user");
            require(amountsWei[i] > 0, "Amount must be > 0");

            token.transfer(users[i], amountsWei[i]);
            emit RewardsSent(users[i], amountsWei[i], block.timestamp);
        }
    }

    /// @notice Вывод ETH/token с пула (только админ).
    function transferToken(address tokenAddr, address to, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");

        if (tokenAddr == address(0)) {
            require(address(this).balance >= amount, "Insufficient ETH");
            (bool success, ) = payable(to).call{ value: amount }("");
            require(success, "ETH transfer failed");
        } else {
            IERC20 erc20 = IERC20(tokenAddr);
            require(erc20.balanceOf(address(this)) >= amount, "Insufficient token balance");
            erc20.safeTransfer(to, amount);
        }

        emit TokensWithdrawn(msg.sender, to, tokenAddr, amount, block.timestamp);
    }

    function pause() external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender),
            "Not admin or operator"
        );
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function getContractStatus()
        external
        view
        returns (
            uint256 tftBalance,
            uint256 ethBalance,
            uint256 usdtBalance,
            bool isPaused
        )
    {
        tftBalance = token.balanceOf(address(this));
        ethBalance = address(this).balance;
        usdtBalance = usdt.balanceOf(address(this));
        isPaused = paused();
    }
}
