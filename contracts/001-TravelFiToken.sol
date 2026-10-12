// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

/**
 * @title TravelFiToken
 * @notice Токен TFT с поддержкой ERC20Permit, ролевой моделью и стандартным ERC-2771 контекстом.
 */
contract TravelFiToken is ERC20, ERC20Permit, AccessControl, ReentrancyGuard, Pausable, ERC2771Context {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint8 private constant _DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**_DECIMALS;

    bool public initialSupplyDistributed;

    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event InitialTokensDistributed(address crowdsale, uint256 crowdsaleAmount, address rewards, uint256 rewardsAmount);
    event TokensWithdrawn(address indexed operator, address indexed to, address token, uint256 amount, uint256 timestamp);

    constructor(address _forwarder) 
        ERC20("TravelFi Token", "TFT") 
        ERC20Permit("TravelFi Token") 
        ERC2771Context(_forwarder)
    {
        require(_forwarder != address(0), "Invalid Forwarder address");
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Переопределение _msgSender и _msgData для корректной работы с ERC2771Context и OpenZeppelin
    function _msgSender() internal view override(Context, ERC2771Context) returns (address sender) {
        return super._msgSender();
    }

    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return super._msgData();
    }

    function _contextSuffixLength() internal view override(Context, ERC2771Context) returns (uint256) {
        return super._contextSuffixLength();
    }

    function distributeInitialSupply(address crowdsale, address rewards) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(!initialSupplyDistributed, "Initial supply already distributed");
        require(crowdsale != address(0) && rewards != address(0), "Invalid target addresses");

        initialSupplyDistributed = true;
        uint256 amountPerContract = 50_000_000 * 10**_DECIMALS;
        require(totalSupply() + (amountPerContract * 2) <= MAX_SUPPLY, "Exceeds max supply");

        _mint(crowdsale, amountPerContract);
        _mint(rewards, amountPerContract);

        emit InitialTokensDistributed(crowdsale, amountPerContract, rewards, amountPerContract);
    }

    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }

    function mint(address to, uint256 amountWei) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        require(to != address(0), "Invalid recipient");
        require(amountWei > 0, "Amount must be > 0");
        require(totalSupply() + amountWei <= MAX_SUPPLY, "Exceeds max supply");

        _mint(to, amountWei);
        emit TokensMinted(to, amountWei);
    }

    function burn(address from, uint256 amountWei) external whenNotPaused {
        require(from != address(0), "Invalid target address");
        require(amountWei > 0, "Amount must be > 0");
        require(balanceOf(from) >= amountWei, "Insufficient balance to burn");

        address spender = _msgSender();
        if (spender != from) {
            _spendAllowance(from, spender, amountWei);
        }

        _burn(from, amountWei);
        emit TokensBurned(from, amountWei);
    }

    function transferToken(address tokenAddr, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
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

        emit TokensWithdrawn(_msgSender(), to, tokenAddr, amount, block.timestamp);
    }

    function pause() external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()) || hasRole(OPERATOR_ROLE, _msgSender()), "Not admin or operator");
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function getContractStatus() external view returns (uint256 tftBalance, uint256 ethBalance, uint256 maxSupply, uint256 currentSupply, bool isPaused) {
        tftBalance = balanceOf(address(this));
        ethBalance = address(this).balance;
        maxSupply = MAX_SUPPLY;
        currentSupply = totalSupply();
        isPaused = paused();
    }
}