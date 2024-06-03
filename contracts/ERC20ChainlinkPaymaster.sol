// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IPaymaster, ExecutionResult, PAYMASTER_VALIDATION_SUCCESS_MAGIC} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymaster.sol";
import {IPaymasterFlow} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymasterFlow.sol";
import {TransactionHelper, Transaction} from "@matterlabs/zksync-contracts/l2/system-contracts/libraries/TransactionHelper.sol";

import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";

// Referencing Chainlink Data Feed 
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @author Arihaan N.
/// @notice This smart contract pays the gas fees for accounts with ERC20 Tokens where ETH exchange rate is calculated using Chainlink Price Feeds. It makes use of the approval-based flow paymaster.

contract ERC20ChainlinkPaymaster is IPaymaster {

    modifier onlyBootloader() {
        require(msg.sender == BOOTLOADER_FORMAL_ADDRESS, "Only bootloader can call this method");
        // Continue execution if called from the bootloader.
        _;
    }

    // Addresses for tokens accepted by Paymaster
    address public constant ETH_ADDRESS = 0x0000000000000000000000000000000000000000;
    address public constant USDC_ADDRESS = 0xcB2B2d0dc5C629cd73154c097073012338eB8a4B;
    address public constant LINK_ADDRESS = 0x23A1aFD896c8c8876AF46aDc38521f4432658d1e;

    // Setting up Chainlink Price feed addresses
    address public constant ETH_PRICE_FEED_ADDRESS = 0xfEefF7c3fB57d18C5C6Cdd71e45D2D0b4F9377bF;
    address public constant LINK_PRICE_FEED_ADDRESS = 0x894423C43cD7230Cd22a47B329E96097e6355292;
    address public constant USDC_PRICE_FEED_ADDRESS = 0x1844478CA634f3a762a2E71E3386837Bd50C947F;

    // Returns the latest price of ETH in USD
    function getLatestEthPrice() public view returns (int256) {
        (, int256 price, , , ) = AggregatorV3Interface(ETH_PRICE_FEED_ADDRESS).latestRoundData();
        return price;
    }

    // Returns the latest price of LINK in USD
    function getLatestLinkPrice() public view returns (int256) {
        (, int256 price, , , ) = AggregatorV3Interface(LINK_PRICE_FEED_ADDRESS).latestRoundData();
        return price;
    }

    // Returns the latest price of USDC in USD
    function getLatestUsdcPrice() public view returns (int256) {
        (, int256 price, , , ) = AggregatorV3Interface(USDC_PRICE_FEED_ADDRESS).latestRoundData();
        return price;
    }

    // Compares if the provided amount of USDC is less than the required amount of ETH in USD equivalent.
    function isUsdcLessThanRequiredEth(uint256 usdcAmount, uint256 requiredEth) public view returns (bool) {
        int256 ethPrice = getLatestEthPrice();
        int256 usdcPrice = getLatestUsdcPrice();

        // Convert prices from 8 decimals to 18 decimals
        uint256 ethPrice18 = uint256(ethPrice) * 10**10;
        uint256 usdcPrice18 = uint256(usdcPrice) * 10**10;

        // Calculate the required ETH value in USD
        uint256 requiredEthInUsd = requiredEth * ethPrice18 / 10**18;

        // Calculate the provided USDC value in USD
        uint256 providedUsdcInUsd = usdcAmount * usdcPrice18 / 10**18;

        return providedUsdcInUsd < requiredEthInUsd;
    }

    // Compares if the provided amount of LINK is less than the required amount of ETH in USD equivalent.
    function isLinkLessThanRequiredEth(uint256 linkAmount, uint256 requiredEth) public view returns (bool) {
        int256 ethPrice = getLatestEthPrice();
        int256 linkPrice = getLatestLinkPrice();

        // Convert prices from 8 decimals to 18 decimals
        uint256 ethPrice18 = uint256(ethPrice) * 10**10;
        uint256 linkPrice18 = uint256(linkPrice) * 10**10;

        // Calculate the required ETH value in USD
        uint256 requiredEthInUsd = requiredEth * ethPrice18 / 10**18;

        // Calculate the provided LINK value in USD
        uint256 providedLinkInUsd = linkAmount * linkPrice18 / 10**18;

        return providedLinkInUsd < requiredEthInUsd;
    }

    function validateAndPayForPaymasterTransaction(
        bytes32,
        bytes32,
        Transaction calldata _transaction
    )
        external payable onlyBootloader returns (bytes4 magic, bytes memory context) {
        // By default we consider the transaction as accepted.
        magic = PAYMASTER_VALIDATION_SUCCESS_MAGIC;

        require(
            _transaction.paymasterInput.length >= 4,
            "The standard paymaster input must be at least 4 bytes long"
        );

        bytes4 paymasterInputSelector = bytes4(
            _transaction.paymasterInput[0:4]
        );

        if (paymasterInputSelector == IPaymasterFlow.approvalBased.selector) {
            // While the transaction data consists of address, uint256 and bytes data,
            // the data is not needed for this paymaster
            (address token, uint256 amount, ) = abi.decode(
                _transaction.paymasterInput[4:],
                (address, uint256, bytes)
            );

            // We verify that the user has provided enough allowance
            address userAddress = address(uint160(_transaction.from));

            address thisAddress = address(this);

            uint256 providedAllowance = IERC20(token).allowance(
                userAddress,
                thisAddress
            );

            require(providedAllowance >= amount, "The user did not provide enough allowance");

            // Minimum amount of ETH required for this transaction
            uint256 requiredETH = _transaction.gasLimit *
                _transaction.maxFeePerGas;

            // Checks if enough tokens are provided to cover gas fees.
            if (token == ETH_ADDRESS) {
                if (amount < requiredETH) {
                    // Important note: while this clause definitely means that the user
                    // has underpaid the paymaster and the transaction should not accepted,
                    // we do not want the transaction to revert, because for fee estimation
                    // we allow users to provide smaller amount of funds then necessary to preserve
                    // the property that if using X gas the transaction success, then it will succeed with X+1 gas.
                    magic = bytes4(0);
                }
            } else if (token == LINK_ADDRESS) {
                if (isLinkLessThanRequiredEth(amount, requiredETH)) {
                    magic = bytes4(0);
                }
            } else if (token == USDC_ADDRESS) {
                if (isUsdcLessThanRequiredEth(amount, requiredETH)) {
                    magic = bytes4(0);
                }
            }

            try
                IERC20(token).transferFrom(userAddress, thisAddress, amount)
            {} catch (bytes memory revertReason) {
                // If the revert reason is empty or represented by just a function selector,
                // we replace the error with a more user-friendly message
                if (revertReason.length <= 4) {
                    revert("Failed to transferFrom from users' account");
                } else {
                    assembly {
                        revert(add(0x20, revertReason), mload(revertReason))
                    }
                }
            }

            // The bootloader never returns any data, so it can safely be ignored here.
            (bool success, ) = payable(BOOTLOADER_FORMAL_ADDRESS).call{
                value: requiredETH
            }("");
            require(
                success,
                "Failed to transfer tx fee to the bootloader. Paymaster balance might not be enough."
            );
        } else {
            revert("Unsupported paymaster flow");
        }
    }

    function postTransaction(
        bytes calldata _context,
        Transaction calldata _transaction,
        bytes32,
        bytes32,
        ExecutionResult _txResult,
        uint256 _maxRefundedGas
    ) external payable override onlyBootloader {
    }

    receive() external payable {}
}
