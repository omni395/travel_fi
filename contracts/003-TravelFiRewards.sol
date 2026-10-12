// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./001-TravelFiToken.sol";

/**
 * @title TravelFiRewards
 * @notice Пул наград: раздает токены TFT исключительно из своего баланса (без минта).
 */
contract TravelFiRewards is ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 private constant _REWARD_CLAIM_TYPEHASH = keccak256("RewardClaim(address user,uint256 amount,uint256 nonce,uint256 deadline)");
    bytes32 private constant _EIP712_DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _REWARDS_NAME_HASH = keccak256("TravelFiRewards");
    bytes32 private constant _VERSION_HASH = keccak256("1");
    uint256 private constant _SECP256K1_HALF_ORDER = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    TravelFiToken public token;
    IERC20 public usdt;
    address public immutable trustedForwarder;
    mapping(address => uint256) public rewardClaimNonces;

    event RewardsSent(address indexed user, uint256 tokens, uint256 timestamp);
    event RewardClaimed(address indexed user, uint256 tokens, uint256 nonce);
    event TokensWithdrawn(address indexed operator, address indexed to, address token, uint256 amount, uint256 timestamp);

    receive() external payable {}

    constructor(address _token, address _usdt, address _forwarder) {
        require(_token != address(0), "Invalid token address");
        require(_usdt != address(0), "Invalid USDT address");
        require(_forwarder != address(0), "Invalid forwarder address");

        token = TravelFiToken(payable(_token));
        usdt = IERC20(_usdt);
        trustedForwarder = _forwarder;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    function _msgSender2771() internal view returns (address sender) {
        if (msg.sender == trustedForwarder && msg.data.length >= 20) {
            return address(bytes20(msg.data[msg.data.length - 20:]));
        }
        return msg.sender;
    }

    /**
     * @notice Прямой перевод награды пользователю из баланса пула по вызову оператора/админа.
     */
    function sendReward(address user, uint256 tokensWei) external nonReentrant whenNotPaused {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender), "Not admin or operator");
        require(user != address(0), "Invalid user");
        require(tokensWei > 0, "Amount must be > 0");
        require(token.balanceOf(address(this)) >= tokensWei, "Insufficient TFT balance in reward pool");

        token.transfer(user, tokensWei);
        emit RewardsSent(user, tokensWei, block.timestamp);
    }

    /**
     * @notice Пользователь сам забирает награду из баланса пула, предоставляя EIP-712 подпись бэкенда.
     */
    function claimReward(uint256 amountWei, uint256 nonce, uint256 deadline, bytes calldata operatorSignature) external nonReentrant whenNotPaused {
        address user = _msgSender2771();
        require(user != address(0), "Invalid user");
        require(amountWei > 0, "Amount must be > 0");
        require(block.timestamp <= deadline, "Claim expired");
        require(nonce == rewardClaimNonces[user], "Invalid claim nonce");
        require(token.balanceOf(address(this)) >= amountWei, "Insufficient TFT balance in reward pool");

        bytes32 structHash = keccak256(abi.encode(_REWARD_CLAIM_TYPEHASH, user, amountWei, nonce, deadline));
        bytes32 domainSeparator = keccak256(abi.encode(_EIP712_DOMAIN_TYPEHASH, _REWARDS_NAME_HASH, _VERSION_HASH, block.chainid, address(this)));
        address signer = _recoverSigner(keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash)), operatorSignature);
        require(hasRole(OPERATOR_ROLE, signer) || hasRole(DEFAULT_ADMIN_ROLE, signer), "Invalid claim authorizer");

        rewardClaimNonces[user] = nonce + 1;
        token.transfer(user, amountWei);
        
        emit RewardsSent(user, amountWei, block.timestamp);
        emit RewardClaimed(user, amountWei, nonce);
    }

    function _recoverSigner(bytes32 digest, bytes calldata signature) private pure returns (address) {
        require(signature.length == 65, "Invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        require(uint256(s) <= _SECP256K1_HALF_ORDER && (v == 27 || v == 28), "Invalid signature");
        return ecrecover(digest, v, r, s);
    }

    /**
     * @notice Пакетная отправка (перевод) токенов из баланса пула группе пользователей до 50 адресов.
     */
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

    /**
     * @notice Эвакуация токенов/ETH админом в случае необходимости.
     */
    function transferToken(address tokenAddr, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
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
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender), "Not admin or operator");
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function getContractStatus() external view returns (uint256 tftBalance, uint256 ethBalance, uint256 usdtBalance, bool isPaused) {
        tftBalance = token.balanceOf(address(this));
        ethBalance = address(this).balance;
        usdtBalance = usdt.balanceOf(address(this));
        isPaused = paused();
    }
}
