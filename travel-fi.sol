// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract TravelFiToken is ERC20, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Address for address payable;

    uint8 private constant _DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 1_000_000 * 10**_DECIMALS;

    IERC20 public usdt;
    address payable public owner;

    receive() external payable {}

    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event TokensWithdrawn(address indexed operator, address indexed to, address token, uint256 amount, uint256 timestamp);

    constructor(address _usdt) ERC20("TravelFi Token", "TFT") {
        require(_usdt != address(0), "Invalid USDT");
        usdt = IERC20(_usdt);
        owner = payable(msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _mint(address(this), 100_000 * 10**_DECIMALS);
    }

    function mint(uint256 amountWei) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        require(amountWei > 0, "Amount must be > 0");
        require(totalSupply() + amountWei <= MAX_SUPPLY, "Exceeds max supply");
        _mint(address(this), amountWei);
        emit TokensMinted(address(this), amountWei);
    }

    function burn(uint256 amountWei) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        require(amountWei > 0, "Amount must be > 0");
        _burn(address(this), amountWei);
        emit TokensBurned(address(this), amountWei);
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
            payable(to).sendValue(amount);
        } else {
            IERC20 erc20 = IERC20(tokenAddr);
            require(erc20.balanceOf(address(this)) >= amount, "Insufficient token balance");
            erc20.safeTransfer(to, amount);
        }

        emit TokensWithdrawn(msg.sender, to, tokenAddr, amount, block.timestamp);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
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

contract TravelFiCrowdsale is ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;
    using Address for address payable;

    TravelFiToken public token;
    IERC20 public usdt;
    address payable public owner;

    uint256 public usdtRate;
    uint256 public ethRate;
    uint256 public usdtDecimals;

    event TokensPurchased(address indexed buyer, uint256 amountIn, uint256 amountOut, string currency, uint256 timestamp);
    event TokensSold(address indexed seller, uint256 amountIn, uint256 amountOut, string currency, uint256 timestamp);
    event RateUpdated(uint256 newUsdtRate, uint256 newEthRate, uint256 timestamp);
    event TokensWithdrawn(address indexed operator, address indexed to, address token, uint256 amount, uint256 timestamp);

    receive() external payable {}

    constructor(address _token, address _usdt) payable {
        require(_token != address(0), "Invalid token");
        require(_usdt != address(0), "Invalid USDT");

        token = TravelFiToken(payable(_token));
        usdt = IERC20(_usdt);
        owner = payable(msg.sender);

        usdtDecimals = IERC20Metadata(_usdt).decimals();
        require(usdtDecimals == 6, "USDT must have 6 decimals");

        usdtRate = 10 * 10**18;
        ethRate = 25_000 * 10**18;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function buyWithUSDT(uint256 usdtAmount, uint256 minTftOut) external nonReentrant whenNotPaused {
        require(usdtAmount > 0, "Amount must be > 0");
        uint256 tftAmount = (usdtAmount * usdtRate) / (10 ** usdtDecimals);
        require(tftAmount >= minTftOut, "Slippage too high");
        require(token.balanceOf(address(this)) >= tftAmount, "Insufficient TFT");

        usdt.safeTransferFrom(msg.sender, address(this), usdtAmount);
        token.transfer(msg.sender, tftAmount);

        emit TokensPurchased(msg.sender, usdtAmount, tftAmount, "USDT", block.timestamp);
    }

    function buyWithETH(uint256 minTftOut) external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Must send ETH");
        uint256 tftAmount = (msg.value * ethRate) / 1e18;
        require(tftAmount >= minTftOut, "Slippage too high");
        require(token.balanceOf(address(this)) >= tftAmount, "Insufficient TFT");

        token.transfer(msg.sender, tftAmount);

        emit TokensPurchased(msg.sender, msg.value, tftAmount, "ETH", block.timestamp);
    }

    function sellWithUSDT(uint256 tftAmount, uint256 minUsdtOut) external nonReentrant whenNotPaused {
        require(tftAmount > 0, "Amount must be > 0");
        uint256 usdtAmount = (tftAmount * (10 ** usdtDecimals)) / usdtRate;
        require(usdtAmount >= minUsdtOut, "Slippage too high");
        require(usdt.balanceOf(address(this)) >= usdtAmount, "Insufficient USDT");

        token.transferFrom(msg.sender, address(this), tftAmount);
        usdt.safeTransfer(msg.sender, usdtAmount);

        emit TokensSold(msg.sender, tftAmount, usdtAmount, "USDT", block.timestamp);
    }

    function sellWithETH(uint256 tftAmount, uint256 minEthOut) external nonReentrant whenNotPaused {
        require(tftAmount > 0, "Amount must be > 0");
        uint256 ethAmount = (tftAmount * 1e18) / ethRate;
        require(ethAmount >= minEthOut, "Slippage too high");
        require(address(this).balance >= ethAmount, "Insufficient ETH");

        token.transferFrom(msg.sender, address(this), tftAmount);
        payable(msg.sender).sendValue(ethAmount);

        emit TokensSold(msg.sender, tftAmount, ethAmount, "ETH", block.timestamp);
    }

    function setUSDTRate(uint256 newRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newRate > 0, "Rate must be > 0");
        usdtRate = newRate;
        emit RateUpdated(newRate, ethRate, block.timestamp);
    }

    function setETHRate(uint256 newRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newRate > 0, "Rate must be > 0");
        ethRate = newRate;
        emit RateUpdated(usdtRate, newRate, block.timestamp);
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
            payable(to).sendValue(amount);
        } else {
            IERC20 erc20 = IERC20(tokenAddr);
            require(erc20.balanceOf(address(this)) >= amount, "Insufficient token balance");
            erc20.safeTransfer(to, amount);
        }

        emit TokensWithdrawn(msg.sender, to, tokenAddr, amount, block.timestamp);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
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
            bool isPaused
        )
    {
        tftBalance = token.balanceOf(address(this));
        usdtBalance = usdt.balanceOf(address(this));
        ethBalance = address(this).balance;
        currentUsdtRate = usdtRate;
        currentEthRate = ethRate;
        isPaused = paused();
    }
}

contract TravelFiRewards is ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;
    using Address for address payable;

    TravelFiToken public token;
    IERC20 public usdt;
    address payable public owner;

    uint256 public lockDays = 7 days;

    mapping(address => uint256) public rewardAllocated;
    mapping(address => uint256) public rewardClaimed;
    mapping(address => uint256) public rewardExpiry;

    uint256 public totalAllocated;
    uint256 public totalClaimed;

    event RewardAllocated(address indexed user, uint256 tokens, uint256 expiry, uint256 timestamp);
    event RewardClaimed(address indexed user, uint256 tokens, uint256 timestamp);
    event RewardRevoked(address indexed user, uint256 tokens, uint256 timestamp);
    event TokensWithdrawn(address indexed operator, address indexed to, address token, uint256 amount, uint256 timestamp);

    receive() external payable {}

    constructor(address _token, address _usdt) {
        require(_token != address(0), "Invalid token");
        require(_usdt != address(0), "Invalid USDT");

        token = TravelFiToken(payable(_token));
        usdt = IERC20(_usdt);
        owner = payable(msg.sender);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setLockDays(uint256 newLockDays) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newLockDays > 0, "Lock days must be > 0");
        lockDays = newLockDays * 1 days;
    }

    function sendReward(address user, uint256 tokensWei) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(user != address(0), "Invalid user");
        require(tokensWei > 0, "Amount must be > 0");
        require(token.balanceOf(address(this)) >= tokensWei, "Insufficient TFT");

        uint256 expiry = block.timestamp + lockDays;
        rewardAllocated[user] += tokensWei;
        rewardExpiry[user] = expiry;
        totalAllocated += tokensWei;

        emit RewardAllocated(user, tokensWei, expiry, block.timestamp);
    }

    function sendRewardBatch(address[] calldata users, uint256[] calldata amountsWei) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(users.length == amountsWei.length, "Array length mismatch");

        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "Invalid user");
            require(amountsWei[i] > 0, "Amount must be > 0");

            uint256 expiry = block.timestamp + lockDays;
            rewardAllocated[users[i]] += amountsWei[i];
            rewardExpiry[users[i]] = expiry;
            totalAllocated += amountsWei[i];

            emit RewardAllocated(users[i], amountsWei[i], expiry, block.timestamp);
        }
    }

    function claimReward() external nonReentrant whenNotPaused {
        require(rewardAllocated[msg.sender] > 0, "No reward allocated");
        require(block.timestamp >= rewardExpiry[msg.sender], "Lock period not ended");

        uint256 amount = rewardAllocated[msg.sender] - rewardClaimed[msg.sender];
        require(amount > 0, "Nothing to claim");
        require(token.balanceOf(address(this)) >= amount, "Insufficient TFT");

        rewardClaimed[msg.sender] += amount;
        totalClaimed += amount;
        token.transfer(msg.sender, amount);

        emit RewardClaimed(msg.sender, amount, block.timestamp);
    }

    function revokeReward(address user, uint256 amountWei) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(user != address(0), "Invalid user");
        require(amountWei > 0, "Amount must be > 0");
        require(rewardAllocated[user] >= amountWei, "Cannot revoke more than allocated");
        require(block.timestamp < rewardExpiry[user], "Reward period ended");

        rewardAllocated[user] -= amountWei;
        totalAllocated -= amountWei;

        emit RewardRevoked(user, amountWei, block.timestamp);
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
            payable(to).sendValue(amount);
        } else {
            IERC20 erc20 = IERC20(tokenAddr);
            require(erc20.balanceOf(address(this)) >= amount, "Insufficient token balance");
            erc20.safeTransfer(to, amount);
        }

        emit TokensWithdrawn(msg.sender, to, tokenAddr, amount, block.timestamp);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function getUserRewardInfo(address user)
        external
        view
        returns (
            uint256 allocated,
            uint256 claimed,
            uint256 available,
            uint256 lockExpiry,
            bool isExpired
        )
    {
        allocated = rewardAllocated[user];
        claimed = rewardClaimed[user];
        available = allocated > claimed ? allocated - claimed : 0;
        lockExpiry = rewardExpiry[user];
        isExpired = block.timestamp > lockExpiry;
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