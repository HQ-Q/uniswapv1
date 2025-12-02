// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
import "./Exchange.sol";
import "./IFactory.sol";

contract Factory is IFactory {
    mapping(address tokenAddress => address exchangeAddress)
        public tokenToExchange;

    /**
     * 创建交易所
     * @param tokenAddress 代币地址
     */
    function createExchange(address tokenAddress) override public returns (address) {
        require(
            tokenToExchange[tokenAddress] == address(0),
            "Exchange already exists"
        );
        Exchange exchange = new Exchange(tokenAddress,address(this));
        tokenToExchange[tokenAddress] = address(exchange);
        return address(exchange);
    }

    /**
     * 获取交易所地址
     * @param tokenAddress 代币地址
     */
    function getExchange(address tokenAddress) override public view returns (address) {
        return tokenToExchange[tokenAddress];
    }
}
