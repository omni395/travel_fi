// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Изолированный интерфейс Chainlink Price Feed с поддержкой decimals()
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

// ============================================================================
// 1. СМАРТ-КОНТРАКТ ТОКЕНА (TravelFiToken)
// ============================================================================

contract TravelFiToken is ERC20, ERC20Permit, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint8 private constant _DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 1_000_000 * 10**_DECIMALS;

    IERC20 public usdt;
    bool public initialSupplyDistributed;

    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event InitialTokensDistributed(address crowdsale, uint256 crowdsaleAmount, address rewards, uint256 rewardsAmount);
    event TokensWithdrawn(address indexed operator, address indexed to, address token, uint256 amount, uint256 timestamp);

    receive() external payable {}

    constructor(address _usdt) 
        ERC20("TravelFi Token", "TFT") 
        ERC20Permit("TravelFi Token") 
    {
        require(_usdt != address(0), "Invalid USDT address");
        usdt = IERC20(_usdt);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function distributeInitialSupply(address crowdsale, address rewards) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(!initialSupplyDistributed, "Initial supply already distributed");
        require(crowdsale != address(0) && rewards != address(0), "Invalid target addresses");

        initialSupplyDistributed = true;

        uint256 amountPerContract = 50_000 * 10**_DECIMALS;
        require(totalSupply() + (amountPerContract * 2) <= MAX_SUPPLY, "Exceeds max supply");

        _mint(crowdsale, amountPerContract);
        _mint(rewards, amountPerContract);

        emit InitialTokensDistributed(crowdsale, amountPerContract, rewards, amountPerContract);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override whenNotPaused {
        super._update(from, to, value);
    }

    function mint(address to, uint256 amountWei) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        require(to != address(0), "Invalid recipient");
        require(amountWei > 0, "Amount must be > 0");
        require(totalSupply() + amountWei <= MAX_SUPPLY, "Exceeds max supply");

        _mint(to, amountWei);
        emit TokensMinted(to, amountWei);
    }

    function burn(address from, uint256 amountWei) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        require(from != address(0), "Invalid target address");
        require(amountWei > 0, "Amount must be > 0");
        require(balanceOf(from) >= amountWei, "Insufficient balance to burn");

        _burn(from, amountWei);
        emit TokensBurned(from, amountWei);
    }

    function transferToken(address tokenAddr, address to, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");

        if (tokenAddr == address(0)) {
            require(address(this).balance >= amount, "Insufficient ETH balance");
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
            uint256 maxSupply,
            uint256 currentSupply,
            bool isPaused
        )
    {
        tftBalance = balanceOf(address(this));
        usdtBalance = usdt.balanceOf(address(this));
        ethBalance = address(this).balance;
        maxSupply = MAX_SUPPLY;
        currentSupply = totalSupply();
        isPaused = paused();
    }
}


// ============================================================================
// 2. СМАРТ-КОНТРАКТ ОБМЕНА И КАССЫ (TravelFiCrowdsale) - С TON ORACLE
// ============================================================================

contract TravelFiCrowdsale is ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    TravelFiToken public token;
    IERC20 public usdt;
    
    // Оракулы
    AggregatorV3Interface public ethUsdPriceFeed;
    AggregatorV3Interface public tonUsdPriceFeed;

    uint256 public usdtRate; 
    uint256 public usdtDecimals;
    
    uint8 public oracleDecimals = 8;
    uint8 public tonOracleDecimals = 8;

    uint256 public constant MAX_RATE_CHANGE_BPS = 1500;
    uint256 public constant RATE_COOLDOWN = 1 hours;
    uint256 public constant STALE_PRICE_THRESHOLD = 2 hours;
    uint256 public lastRateUpdateTimestamp;

    uint256 public sellFeeBps = 100;
    uint256 public constant MAX_FEE_BPS = 2000;

    bool public useChainlinkOracle = true;
    uint256 public fallbackEthRate = 25_000 * 10**18; 
    uint256 public fallbackTonRate = 5 * 10**18; // Запасной курс TON, например $5.00

    event TokensPurchased(address indexed buyer, uint256 amountIn, uint256 amountOut, string currency, uint256 timestamp);
    event TokensSold(address indexed seller, uint256 amountIn, uint256 amountOut, uint256 feeAmount, string currency, uint256 timestamp);
    event USDTRateUpdated(uint256 oldRate, uint256 newRate, uint256 timestamp);
    event SellFeeUpdated(uint256 newFeeBps, uint256 timestamp);
    event OracleStatusUpdated(bool useOracle, address ethOracleAddress, address tonOracleAddress, uint256 timestamp);
    event TokensWithdrawn(address indexed operator, address indexed to, address token, uint256 amount, uint256 timestamp);

    receive() external payable {}

    constructor(address _token, address _usdt, address _ethPriceFeed, address _tonPriceFeed) payable {
        require(_token != address(0), "Invalid token address");
        require(_usdt != address(0), "Invalid USDT address");

        token = TravelFiToken(payable(_token));
        usdt = IERC20(_usdt);

        usdtDecimals = IERC20Metadata(_usdt).decimals();
        usdtRate = 10 * 10**18;

        if (_ethPriceFeed != address(0)) {
            _updateEthOracleFeed(_ethPriceFeed);
        } else {
            useChainlinkOracle = false;
        }

        if (_tonPriceFeed != address(0)) {
            _updateTonOracleFeed(_tonPriceFeed);
        }

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    function _updateEthOracleFeed(address _priceFeed) internal {
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeed);
        try ethUsdPriceFeed.decimals() returns (uint8 dec) {
            oracleDecimals = dec;
        } catch {
            oracleDecimals = 8;
        }
    }

    function _updateTonOracleFeed(address _priceFeed) internal {
        tonUsdPriceFeed = AggregatorV3Interface(_priceFeed);
        try tonUsdPriceFeed.decimals() returns (uint8 dec) {
            tonOracleDecimals = dec;
        } catch {
            tonOracleDecimals = 8;
        }
    }

    function getLatestETHPrice() public view returns (uint256) {
        if (!useChainlinkOracle || address(ethUsdPriceFeed) == address(0)) {
            return 0;
        }

        try ethUsdPriceFeed.latestRoundData() returns (
            uint80 roundId,
            int256 price,
            uint256,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            if (
                price <= 0 ||
                updatedAt == 0 ||
                updatedAt > block.timestamp ||
                block.timestamp - updatedAt > STALE_PRICE_THRESHOLD ||
                answeredInRound < roundId
            ) {
                return 0;
            }
            return uint256(price);
        } catch {
            return 0;
        }
    }

    function getLatestTONPrice() public view returns (uint256) {
        if (!useChainlinkOracle || address(tonUsdPriceFeed) == address(0)) {
            return 0;
        }

        try tonUsdPriceFeed.latestRoundData() returns (
            uint80 roundId,
            int256 price,
            uint256,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            if (
                price <= 0 ||
                updatedAt == 0 ||
                updatedAt > block.timestamp ||
                block.timestamp - updatedAt > STALE_PRICE_THRESHOLD ||
                answeredInRound < roundId
            ) {
                return 0;
            }
            return uint256(price);
        } catch {
            return 0;
        }
    }

    // Вспомогательная функция для бэкенда: расчет TFT за переданное количество TON (в wei)
    function calculateTftForTon(uint256 tonAmountWei) public view returns (uint256) {
        uint256 tonPrice;
        
        if (useChainlinkOracle) {
            tonPrice = getLatestTONPrice();
        }
        
        if (tonPrice == 0) {
            require(fallbackTonRate > 0, "Fallback TON rate not set");
            tonPrice = fallbackTonRate;
        }

        // Если цена получена из оракула (например 8 decimals), делим на (18 + tonOracleDecimals)
        // Если из fallback (где уже 18 decimals), то логика как с fallbackEthRate
        if (tonPrice == fallbackTonRate) {
             return (tonAmountWei * fallbackTonRate * usdtRate) / (10 ** (18 + 18));
        }

        return (tonAmountWei * tonPrice * usdtRate) / (10 ** (18 + tonOracleDecimals));
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
        
        uint256 tftAmount;

        if (useChainlinkOracle) {
            uint256 ethPrice = getLatestETHPrice();
            require(ethPrice > 0, "Oracle price unavailable or stale");
            
            tftAmount = (msg.value * ethPrice * usdtRate) / (10 ** (18 + oracleDecimals));
        } else {
            require(fallbackEthRate > 0, "Fallback rate not set");
            tftAmount = (msg.value * fallbackEthRate) / 1e18;
        }

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

        try token.permit(msg.sender, address(this), tftAmount, deadline, v, r, s) {} catch {}

        uint256 grossEthAmount;

        if (useChainlinkOracle) {
            uint256 ethPrice = getLatestETHPrice();
            require(ethPrice > 0, "Oracle price unavailable or stale");

            grossEthAmount = (tftAmount * (10 ** (18 + oracleDecimals))) / (ethPrice * usdtRate);
        } else {
            require(fallbackEthRate > 0, "Fallback rate not set");
            grossEthAmount = (tftAmount * 1e18) / fallbackEthRate;
        }

        uint256 feeEth = (grossEthAmount * sellFeeBps) / 10000;
        uint256 netEthAmount = grossEthAmount - feeEth;

        require(netEthAmount >= minEthOut, "Slippage too high");
        require(address(this).balance >= netEthAmount, "Insufficient ETH in contract");

        token.transferFrom(msg.sender, address(this), tftAmount);
        (bool success, ) = payable(msg.sender).call{value: netEthAmount}("");
        require(success, "ETH transfer failed");

        emit TokensSold(msg.sender, tftAmount, netEthAmount, feeEth, "ETH", block.timestamp);
    }

    function setUSDTRate(uint256 newRate) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender), "Not admin or operator");
        require(newRate > 0, "Rate must be > 0");

        if (usdtRate > 0 && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            require(block.timestamp >= lastRateUpdateTimestamp + RATE_COOLDOWN, "Rate update cooldown active");
            uint256 diff = newRate > usdtRate ? newRate - usdtRate : usdtRate - newRate;
            uint256 changeBps = (diff * 10000) / usdtRate;
            require(changeBps <= MAX_RATE_CHANGE_BPS, "Rate change exceeds 15% limit");
        }

        emit USDTRateUpdated(usdtRate, newRate, block.timestamp);
        usdtRate = newRate;
        lastRateUpdateTimestamp = block.timestamp;
    }

    function setSellFeeBps(uint256 _sellFeeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_sellFeeBps <= MAX_FEE_BPS, "Fee exceeds max limit");
        sellFeeBps = _sellFeeBps;
        emit SellFeeUpdated(_sellFeeBps, block.timestamp);
    }

    function setOracleConfigs(
        address _ethPriceFeed, 
        address _tonPriceFeed, 
        bool _useOracle, 
        uint256 _fallbackEthRate, 
        uint256 _fallbackTonRate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_ethPriceFeed != address(0)) {
            _updateEthOracleFeed(_ethPriceFeed);
        }
        if (_tonPriceFeed != address(0)) {
            _updateTonOracleFeed(_tonPriceFeed);
        }
        
        useChainlinkOracle = _useOracle;
        
        if (_fallbackEthRate > 0) fallbackEthRate = _fallbackEthRate;
        if (_fallbackTonRate > 0) fallbackTonRate = _fallbackTonRate;
        
        emit OracleStatusUpdated(_useOracle, _ethPriceFeed, _tonPriceFeed, block.timestamp);
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
            uint256 latestChainlinkEthPrice,
            uint256 latestChainlinkTonPrice,
            uint256 currentSellFeeBps,
            bool isPaused
        )
    {
        tftBalance = token.balanceOf(address(this));
        usdtBalance = usdt.balanceOf(address(this));
        ethBalance = address(this).balance;
        currentUsdtRate = usdtRate;
        latestChainlinkEthPrice = getLatestETHPrice();
        latestChainlinkTonPrice = getLatestTONPrice();
        currentSellFeeBps = sellFeeBps;
        isPaused = paused();
    }
}


// ============================================================================
// 3. СМАРТ-КОНТРАКТ НАГРАД И БУХГАЛТЕРИИ (TravelFiRewards)
// ============================================================================

contract TravelFiRewards is ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    TravelFiToken public token;
    IERC20 public usdt;

    uint256 public lockDays = 7 days;

    mapping(address => mapping(uint256 => uint256)) public userDailyAllocated;
    mapping(address => uint256) public lastProcessedDay;
    mapping(address => uint256) public userFirstDay;

    mapping(address => uint256) public claimableRewards;

    uint256 public totalAllocated;
    uint256 public totalClaimed;

    event RewardAllocated(address indexed user, uint256 tokens, uint256 unlockTime, uint256 timestamp);
    event RewardClaimed(address indexed user, uint256 tokens, uint256 timestamp);
    event RewardRevoked(address indexed user, uint256 tokens, uint256 timestamp);
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

    function setLockDays(uint256 newLockDays) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newLockDays > 0, "Lock days must be > 0");
        lockDays = newLockDays * 1 days;
    }

    function _unlockVested(address user) internal {
        uint256 currentDay = block.timestamp / 1 days;
        uint256 lockInDays = lockDays / 1 days;

        if (currentDay < lockInDays) return;

        uint256 unlockedUpToDay = currentDay - lockInDays;
        uint256 startDay = lastProcessedDay[user];

        if (startDay == 0) {
            if (userFirstDay[user] > 0) {
                startDay = userFirstDay[user];
            } else {
                return;
            }
        }

        if (startDay > unlockedUpToDay) return;

        uint256 maxDaysToProcess = 365;
        uint256 endDay = unlockedUpToDay;
        if (endDay - startDay > maxDaysToProcess) {
            endDay = startDay + maxDaysToProcess;
        }

        uint256 unlockedTotal = 0;
        for (uint256 day = startDay; day <= endDay; day++) {
            uint256 amount = userDailyAllocated[user][day];
            if (amount > 0) {
                unlockedTotal += amount;
                delete userDailyAllocated[user][day];
            }
        }

        if (unlockedTotal > 0) {
            claimableRewards[user] += unlockedTotal;
        }

        lastProcessedDay[user] = endDay + 1;
    }

    function _processRewardAllocation(address user, uint256 tokensWei) internal {
        _unlockVested(user);

        uint256 currentDay = block.timestamp / 1 days;
        
        if (userFirstDay[user] == 0) {
            userFirstDay[user] = currentDay;
            lastProcessedDay[user] = currentDay;
        }

        userDailyAllocated[user][currentDay] += tokensWei;
        totalAllocated += tokensWei;

        uint256 unlockTime = (currentDay + (lockDays / 1 days)) * 1 days;
        emit RewardAllocated(user, tokensWei, unlockTime, block.timestamp);
    }

    function _revokeUserReward(address user, uint256 amountWei) internal {
        require(user != address(0), "Invalid user");
        require(amountWei > 0, "Amount must be > 0");

        _unlockVested(user);

        uint256 remainingToRevoke = amountWei;

        if (claimableRewards[user] >= remainingToRevoke) {
            claimableRewards[user] -= remainingToRevoke;
            remainingToRevoke = 0;
        } else {
            remainingToRevoke -= claimableRewards[user];
            claimableRewards[user] = 0;

            uint256 currentDay = block.timestamp / 1 days;
            uint256 startDay = lastProcessedDay[user];

            for (uint256 day = currentDay; day >= startDay && remainingToRevoke > 0; ) {
                uint256 amount = userDailyAllocated[user][day];
                if (amount > 0) {
                    if (amount <= remainingToRevoke) {
                        remainingToRevoke -= amount;
                        delete userDailyAllocated[user][day];
                    } else {
                        userDailyAllocated[user][day] -= remainingToRevoke;
                        remainingToRevoke = 0;
                    }
                }
                if (day == 0) break;
                unchecked { day--; }
            }
        }

        require(remainingToRevoke == 0, "Cannot revoke more than total unclaimed user balance");

        totalAllocated -= amountWei;
        emit RewardRevoked(user, amountWei, block.timestamp);
    }

    function syncRewards(address user) external {
        _unlockVested(user);
    }

    function sendReward(address user, uint256 tokensWei) external nonReentrant whenNotPaused {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender), "Not admin or operator");
        require(user != address(0), "Invalid user");
        require(tokensWei > 0, "Amount must be > 0");
        require(token.balanceOf(address(this)) >= tokensWei, "Insufficient TFT balance in reward pool");

        _processRewardAllocation(user, tokensWei);
    }

    function sendRewardBatch(address[] calldata users, uint256[] calldata amountsWei) external whenNotPaused {
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

            _processRewardAllocation(users[i], amountsWei[i]);
        }
    }

    function claimReward(address user) external nonReentrant whenNotPaused {
        require(user != address(0), "Invalid user address");

        _unlockVested(user);

        uint256 amountToClaim = claimableRewards[user];
        require(amountToClaim > 0, "Nothing to claim");
        require(token.balanceOf(address(this)) >= amountToClaim, "Insufficient TFT in contract pool");

        claimableRewards[user] = 0;
        totalClaimed += amountToClaim;

        token.transfer(user, amountToClaim);

        emit RewardClaimed(user, amountToClaim, block.timestamp);
    }

    function revokeReward(address user, uint256 amountWei) external whenNotPaused {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender), "Not admin or operator");
        _revokeUserReward(user, amountWei);
    }

    function revokeRewardBatch(address[] calldata users, uint256[] calldata amountsWei) external whenNotPaused {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender), "Not admin or operator");
        require(users.length > 0 && users.length <= 50, "Batch size out of bounds (1-50)");
        require(users.length == amountsWei.length, "Array length mismatch");

        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] == address(0) || amountsWei[i] == 0) continue;
            _revokeUserReward(users[i], amountsWei[i]);
        }
    }

    function getUserRewardInfo(address user)
        external
        view
        returns (
            uint256 claimable,
            uint256 lockedSum,
            uint256 lastProcessed,
            uint256 nextUnlockTime
        )
    {
        claimable = claimableRewards[user];
        uint256 currentDay = block.timestamp / 1 days;
        uint256 lockInDays = lockDays / 1 days;
        uint256 startDay = lastProcessedDay[user];

        if (startDay == 0 && userFirstDay[user] > 0) {
            startDay = userFirstDay[user];
        }

        if (startDay > 0) {
            uint256 unlockedUpToDay = currentDay >= lockInDays ? currentDay - lockInDays : 0;

            for (uint256 day = startDay; day <= currentDay; day++) {
                uint256 amount = userDailyAllocated[user][day];
                if (amount > 0) {
                    if (day <= unlockedUpToDay) {
                        claimable += amount;
                    } else {
                        lockedSum += amount;
                        uint256 unlockTime = (day + lockInDays) * 1 days;
                        if (nextUnlockTime == 0 || unlockTime < nextUnlockTime) {
                            nextUnlockTime = unlockTime;
                        }
                    }
                }
            }
        }

        lastProcessed = lastProcessedDay[user];
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
            uint256 totalAllocatedRewards,
            uint256 totalClaimedRewards,
            uint256 ethBalance,
            uint256 usdtBalance,
            uint256 currentLockDays,
            bool isPaused
        )
    {
        tftBalance = token.balanceOf(address(this));
        totalAllocatedRewards = totalAllocated;
        totalClaimedRewards = totalClaimed;
        ethBalance = address(this).balance;
        usdtBalance = usdt.balanceOf(address(this));
        currentLockDays = lockDays / 1 days;
        isPaused = paused();
    }
}