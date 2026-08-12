// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./01-TravelFiToken.sol";

contract TravelFiCrowdsale is ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    TravelFiToken public token;
    IERC20 public usdt;
    
    // Курсы, управляемые бэкендом (оператором)
    uint256 public usdtRate; // Количество TFT за 1 USDT
    uint256 public ethRate;  // Цена ETH в USD (18 знаков)
    uint256 public tonRate;  // Цена TON в USD (18 знаков)
    uint256 public usdtDecimals;

    uint256 public constant MAX_RATE_CHANGE_BPS = 1500;
    uint256 public constant RATE_COOLDOWN = 1 hours;
    uint256 public lastRateUpdateTimestamp;

    uint256 public sellFeeBps = 100;
    uint256 public constant MAX_FEE_BPS = 2000;

    event TokensPurchased(address indexed buyer, uint256 amountIn, uint256 amountOut, string currency, uint256 timestamp);
    event TokensSold(address indexed seller, uint256 amountIn, uint256 amountOut, uint256 feeAmount, string currency, uint256 timestamp);
    event RatesUpdated(uint256 usdtRate, uint256 ethRate, uint256 tonRate, uint256 timestamp);
    event SellFeeUpdated(uint256 newFeeBps, uint256 timestamp);
    event TokensWithdrawn(address indexed operator, address indexed to, address token, uint256 amount, uint256 timestamp);

    receive() external payable {}

    constructor(address _token, address _usdt) payable {
        require(_token != address(0), "Invalid token address");
        require(_usdt != address(0), "Invalid USDT address");

        token = TravelFiToken(payable(_token));
        usdt = IERC20(_usdt);

        usdtDecimals = IERC20Metadata(_usdt).decimals();
        usdtRate = 10 * 10**18;
        ethRate = 25_000 * 10**18;
        tonRate = 5 * 10**18;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    // Вспомогательная функция для бэкенда: расчет TFT за переданное количество TON (в wei)
    function calculateTftForTon(uint256 tonAmountWei) public view returns (uint256) {
        require(tonRate > 0, "TON rate not set");
        return (tonAmountWei * tonRate * usdtRate) / (10 ** (18 + 18));
    }

    function buyWithUSDT(uint256 usdtAmount, uint256 minTftOut) external nonReentrant whenNotPaused {
        require(usdtAmount > 0, "Amount must be > 0");
        
        uint256 tftAmount = (usdtAmount * usdtRate) / (10 ** usdtDecimals);
        
        require(tftAmount >= minTftOut, "Slippage too high");
        require(token.balanceOf(address(this)) >= tftAmount, "Insufficient TFT in contract");

        usdt.safeTransferFrom(msg.sender, address(this), usdtAmount);
        token.transfer(msg.sender, tftAmount);

        emit TokensPurchased(msg.sender, usdtAmount, tftAmount, "USDT", block.timestamp);
    }

    function buyWithETH(uint256 minTftOut) external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Must send ETH");
        require(ethRate > 0, "ETH rate not set");
        
        uint256 tftAmount = (msg.value * ethRate * usdtRate) / (10 ** (18 + 18));

        require(tftAmount >= minTftOut, "Slippage too high");
        require(token.balanceOf(address(this)) >= tftAmount, "Insufficient TFT in contract");

        token.transfer(msg.sender, tftAmount);

        emit TokensPurchased(msg.sender, msg.value, tftAmount, "ETH", block.timestamp);
    }

    function sellWithUSDT(
        uint256 tftAmount,
        uint256 minUsdtOut,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant whenNotPaused {
        require(tftAmount > 0, "Amount must be > 0");

        try token.permit(msg.sender, address(this), tftAmount, deadline, v, r, s) {} catch {}

        uint256 grossUsdtAmount = (tftAmount * (10 ** usdtDecimals)) / usdtRate;
        uint256 feeUsdt = (grossUsdtAmount * sellFeeBps) / 10000;
        uint256 netUsdtAmount = grossUsdtAmount - feeUsdt;

        require(netUsdtAmount >= minUsdtOut, "Slippage too high");
        require(usdt.balanceOf(address(this)) >= netUsdtAmount, "Insufficient USDT in contract");

        token.transferFrom(msg.sender, address(this), tftAmount);
        usdt.safeTransfer(msg.sender, netUsdtAmount);

        emit TokensSold(msg.sender, tftAmount, netUsdtAmount, feeUsdt, "USDT", block.timestamp);
    }

    function sellWithETH(
        uint256 tftAmount,
        uint256 minEthOut,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant whenNotPaused {
        require(tftAmount > 0, "Amount must be > 0");
        require(ethRate > 0, "ETH rate not set");

        try token.permit(msg.sender, address(this), tftAmount, deadline, v, r, s) {} catch {}

        uint256 grossEthAmount = (tftAmount * (10 ** 18) * (10 ** 18)) / (ethRate * usdtRate);

        uint256 feeEth = (grossEthAmount * sellFeeBps) / 10000;
        uint256 netEthAmount = grossEthAmount - feeEth;

        require(netEthAmount >= minEthOut, "Slippage too high");
        require(address(this).balance >= netEthAmount, "Insufficient ETH in contract");

        token.transferFrom(msg.sender, address(this), tftAmount);
        (bool success, ) = payable(msg.sender).call{value: netEthAmount}("");
        require(success, "ETH transfer failed");

        emit TokensSold(msg.sender, tftAmount, netEthAmount, feeEth, "ETH", block.timestamp);
    }

    function setRates(uint256 newUsdtRate, uint256 newEthRate, uint256 newTonRate) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender), "Not admin or operator");
        require(newUsdtRate > 0 && newEthRate > 0 && newTonRate > 0, "Rates must be > 0");

        if (usdtRate > 0 && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            require(block.timestamp >= lastRateUpdateTimestamp + RATE_COOLDOWN, "Rate update cooldown active");
            uint256 diff = newUsdtRate > usdtRate ? newUsdtRate - usdtRate : usdtRate - newUsdtRate;
            uint256 changeBps = (diff * 10000) / usdtRate;
            require(changeBps <= MAX_RATE_CHANGE_BPS, "Rate change exceeds 15% limit");
        }

        usdtRate = newUsdtRate;
        ethRate = newEthRate;
        tonRate = newTonRate;
        lastRateUpdateTimestamp = block.timestamp;

        emit RatesUpdated(newUsdtRate, newEthRate, newTonRate, block.timestamp);
    }

    function setSellFeeBps(uint256 _sellFeeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_sellFeeBps <= MAX_FEE_BPS, "Fee exceeds max limit");
        sellFeeBps = _sellFeeBps;
        emit SellFeeUpdated(_sellFeeBps, block.timestamp);
    }

    function transferToken(address tokenAddr, address to, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");

        if (tokenAddr == address(0)) {
            require(address(this).balance >= amount, "Insufficient ETH");
            (bool success, ) = payable(to).call{value: amount}("");
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
            uint256 usdtBalance,
            uint256 ethBalance,
            uint256 currentUsdtRate,
            uint256 currentEthRate,
            uint256 currentTonRate,
            uint256 currentSellFeeBps,
            bool isPaused
        )
    {
        tftBalance = token.balanceOf(address(this));
        usdtBalance = usdt.balanceOf(address(this));
        ethBalance = address(this).balance;
        currentUsdtRate = usdtRate;
        currentEthRate = ethRate;
        currentTonRate = tonRate;
        currentSellFeeBps = sellFeeBps;
        isPaused = paused();
    }
}