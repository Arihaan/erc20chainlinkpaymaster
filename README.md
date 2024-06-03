# ERC20ChainlinkPaymaster 

Connecting zkSync Native Account Abstraction with Chainlink Price Feeds.

![ERC20ChainlinkPaymaster](https://github.com/Arihaan/erc20chainlinkpaymaster/assets/48653895/3b796a34-ac91-4788-bc72-07e2d0a3b0fa)

#### This project demonstrates a new zkSync Paymaster for **connecting the innovation of zkSync Native Account Abstraction with the ease and security of Chainlink Price Feeds**.

## What it does

This Paymaster allows users to pay their gas fees using ERC20 tokens of their choice. 

It leverages zkSync’s native implementation of account abstraction and Chainlink’s price feeds on the zkSync era Sepolia testnet to convert gas fees in ETH to different ERC20 tokens such as LINK and USDC.

## Problem Being Solved

Traditional blockchain models require users to pay gas fees in the network's native cryptocurrency, such as ETH on Ethereum. This creates several issues:

1. **User Inconvenience**: Users need to manage multiple cryptocurrencies. If they primarily use ERC20 tokens like USDC or LINK, they must also hold ETH for gas fees, complicating the user experience.
   
2. **Barrier to Entry**: New users may find it confusing and discouraging to understand why they need a different token (ETH) for transaction fees, which can hinder adoption.
   
3. **Liquidity Issues**: Users may not always have ETH available, requiring them to acquire it, often incurring additional fees and dealing with price volatility.

Allowing gas fee payments in ERC20 tokens addresses these problems by:

1. **Enhanced User Experience**: Users can pay fees with the same tokens they transact with, reducing the need to manage multiple cryptocurrencies.
   
2. **Lower Barrier to Entry**: Simplifying fee payments encourages new users to engage with blockchain applications.
   
3. **Improved Liquidity Management**: Users maintain liquidity in their preferred tokens without needing to convert to ETH.

Using Chainlink’s Price Feeds ensures accurate and reliable price data for converting gas fees, enhancing the reliability and fairness of the process. This solution makes blockchain technology more accessible and user-friendly, benefiting both users and developers.

## How I built it

The ERC20ChainlinkPaymaster.sol contract is written in Solidity and deployed using the Atlas IDE.

A simple Greeter contract and Vue.js front-end application are used to demonstrate this Paymaster.

The Chainlink Data Feeds are used both off-chain and on-chain to determine how many ERC20 tokens are required.

## Team

This was a solo project by me, Arihaan: A final year Computer Science student in London, UK with a keen interest in emerging technologies such as Blockchain and Artificial Intelligence, having won several hackathons in this space.

Connect with me on [LinkedIn](https://www.linkedin.com/in/arihaan/) !

## Installation Guide

Simply clone the repo with:

```
git clone https://github.com/Arihaan/erc20chainlinkpaymaster
```

and spin up the project with:

```
yarn
yarn dev
```
Then navigate to the displayed localhost on your browser to interact with the front-end.
