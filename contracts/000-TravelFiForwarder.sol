// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

import "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";

/**
 * @title TravelFiForwarder
 * @notice Официальный контракт-релейер мета-транзакций (Gasless) стандарта OpenZeppelin v5.
 */
contract TravelFiForwarder is ERC2771Forwarder {
    constructor() ERC2771Forwarder("TravelFiTokenForwarder") {}
}
