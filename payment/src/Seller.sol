// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzepplin/contracts/token/ERC20/IERC20.sol";
import "@openzepplin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzepplin/contracts/access/Ownable.sol";

contract Seller is Ownable {
    using SafeERC20 for IERC20;

    // if this variable is true, then the software is free
    bool public free;

    // token address to amount
    mapping(address => uint256) public paymentAmounts;

    address[] public acceptedTokens;

    // if you bought the software, your mac's address hash will be true
    // in this mapping
    mapping(bytes32 => bool) public hasLicense;

    event ReceivedTokenPayment(
        address indexed token,
        uint256 amount,
        bytes32 macHash
    );
    event ReceivedNativePayment(uint256 amount, bytes32 macHash);
    event PaymentMethodAdded(address token, uint256 amount);
    event TokenWithdrawn(address indexed token, uint256 amount);
    event EtherWithdrawn(uint256 amount);
    event DonationReceived(uint256 amount);
    event TokenPaymentRemoved(address token);
    event FreeSoftware(uint256 timestamp);
    event NotFreeAnymore(uint256 timestamp);

    // donations in ether will go here
    receive() external payable {
        if (msg.value > 0) {
            emit DonationReceived(msg.value);
        }
    }

    /// @notice address zero denotes the native token
    /// @param _acceptedTokens List of token addresses that are accepted as payment
    /// @param _amounts List of amount corresponding to the token address
    constructor(address[] memory _acceptedTokens, uint256[] memory _amounts) {
        require(
            _acceptedTokens.length == _amounts.length,
            "INVALID_ARRAY_LENGTH"
        );
        for (uint256 i; i < _acceptedTokens.length; i++) {
            require(_amounts[i] > 0, "PAYMENT_ZERO");
            require(
                paymentAmounts[_acceptedTokens[i]] == 0,
                "TOKEN_NOT_UNIQUE"
            );
            paymentAmounts[_acceptedTokens[i]] = _amounts[i];
            acceptedTokens.push(_acceptedTokens[i]);
            emit PaymentMethodAdded(_acceptedTokens[i], _amounts[i]);
        }
    }

    /// @notice Buy the software with your choice of tokens
    /// @param tokenAddress The address of the token you want to pay in
    /// @param macHash Keccak256 hash of your mac address, use to identify your license
    function buy(address tokenAddress, bytes32 macHash) external payable {
        // we assume that if the token address is zero, then it is the native token

        require(macHash != bytes32(0), "INVALID_MAC_HASH");
        uint256 amount;

        if (tokenAddress == address(0)) {
            amount = paymentAmounts[address(0)];
            require(amount > 0, "NATIVE_TOKEN_NOT_SUPPORTED");
            require(msg.value >= amount, "NOT_ENOUGH_AMOUNT");

            // give license to the given mac hash
            hasLicense[macHash] = true;

            emit ReceivedNativePayment(msg.value, macHash);
        } else {
            amount = paymentAmounts[tokenAddress];

            require(amount > 0, "TOKEN_NOT_ACCEPTED");

            hasLicense[macHash] = true;

            IERC20(tokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                amount
            );
            emit ReceivedTokenPayment(tokenAddress, amount, macHash);
        }
    }

    /// @notice You can get free license if the owner set it free
    function getFreeLicense(bytes32 macHash) external {
        require(free, "LICENSE_IS_NOT_FREE");
        require(macHash != bytes32(0), "INVALID_MAC_HASH");
        hasLicense[macHash] = true;
        emit ReceivedNativePayment(0, macHash);
    }

    /// @notice Owner can withdraw tokens of this contract
    function withdrawToken(address tokenAddress, uint256 amount)
        external
        onlyOwner
    {
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "NOT_ENOUGH_TOKENS");
        token.safeTransfer(msg.sender, amount);
        emit TokenWithdrawn(tokenAddress, amount);
    }

    /// @notice Owner can withdraw ether of this contract
    function withdrawNative(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "NOT_ENOUGH_ETHER");
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "TRANSFER_FAILED");
        emit EtherWithdrawn(amount);
    }

    /// @notice Owner can withdraw all tokens and ether in one go
    function withdrawAll() external onlyOwner {
        uint256 length = acceptedTokens.length;
        uint256 amount;
        if (length > 0) {
            for (uint256 i; i < length; i++) {
                IERC20 token = IERC20(acceptedTokens[i]);
                amount = token.balanceOf(address(this));
                if (amount > 0) {
                    token.safeTransfer(msg.sender, amount);
                    emit TokenWithdrawn(address(token), amount);
                }
            }
        }
        amount = address(this).balance;
        if (amount > 0) {
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "TRANSFER_FAILED");
            emit EtherWithdrawn(amount);
        }
    }

    /// @notice Change the payment amount of one token address
    function changePaymentAmount(address token, uint256 amount)
        external
        onlyOwner
    {
        // use a check to make sure the token address already in the
        // acceptedTokens array
        bool check;
        uint256 length = acceptedTokens.length;
        for (uint256 i; i < length; i++) {
            if (acceptedTokens[i] == token) {
                check = true;
                break;
            }
        }
        require(check, "TOKEN_DOES_NOT_EXIST");
        require(amount > 0, "INVALID_AMOUNT");
        paymentAmounts[token] = amount;
    }

    /// @notice Add a payment token address and the amount required
    /// @param token Address of the token to be paid in
    /// @param amount Amount of token required
    function addPaymentMethod(address token, uint256 amount)
        external
        onlyOwner
    {
        // if the token already added, you should use the changePaymentAmount
        // function to change its amount
        require(paymentAmounts[token] == 0, "TOKEN_ALREADY_ADDED");
        paymentAmounts[token] = amount;
        acceptedTokens.push(token);
        emit PaymentMethodAdded(token, amount);
    }

    /// @notice Stop accepting payment from a token address
    function removePaymentMethod(address token) external onlyOwner {
        require(paymentAmounts[token] > 0, "TOKEN_DOES_NOT_EXIST");
        paymentAmounts[token] = 0;
        uint256 length = acceptedTokens.length;
        for (uint256 i; i < length; i++) {
            if (acceptedTokens[i] == token) {
                acceptedTokens[i] = acceptedTokens[length - 1];
                acceptedTokens.pop();
                break;
            }
        }

        emit TokenPaymentRemoved(token);
    }

    /// @notice Release the software for free
    function setFree() external onlyOwner {
        require(!free, "ALREADY_FREE");
        free = true;

        emit FreeSoftware(block.timestamp);
    }

    function stopFree() external onlyOwner {
        require(free, "NOT_FREE");
        free = false;

        emit NotFreeAnymore(block.timestamp);
    }

    function numAcceptedTokens() external view returns (uint256) {
        return acceptedTokens.length;
    }
}
