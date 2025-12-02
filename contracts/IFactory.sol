// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IFactory {
    function createExchange(address tokenAddress) external returns (address);

    function getExchange(address tokenAddress) external view returns (address);
}