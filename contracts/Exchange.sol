// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IFactory.sol";

interface IExchange {
    // 以太坊兑换代币并转账给指定地址
    function ethToTokenTransfer(
        uint256 _minTokens,
        address recipient
    ) external payable;

    // 获取以太坊能兑换多少代币
    function getTokenAomout(uint256 _ethSold) external view returns (uint256);
}

contract Exchange is ERC20, IExchange {
    address public tokenAddress;
    address public factoryAddress;

    constructor(
        address _tokenAddress,
        address _factoryAddress
    ) ERC20("HUniswapV1", "HUNI-V1") {
        require(_tokenAddress != address(0), "Invalid token address");
        tokenAddress = _tokenAddress;
        factoryAddress = _factoryAddress;
    }

    //添加流动性
    function addLiquidity(uint256 amount) public payable returns (uint256) {
        if (getReserve() == 0) {
            //首次添加流动性
            IERC20 token = IERC20(tokenAddress);
            // Transfer tokens from the user to the exchange contract
            require(
                token.transferFrom(msg.sender, address(this), amount),
                "Token transfer failed"
            );
            //铸造流动性代币给流动性提供者
            uint256 liquidity = address(this).balance;
            _mint(msg.sender, liquidity);
            return liquidity;
        } else {
            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = getReserve();
            uint256 requiredTokenAmount = (msg.value * tokenReserve) /
                ethReserve;
            require(amount >= requiredTokenAmount, "Insufficient token amount");
            IERC20 token = IERC20(tokenAddress);
            // Transfer tokens from the user to the exchange contract
            require(
                token.transferFrom(
                    msg.sender,
                    address(this),
                    requiredTokenAmount
                ),
                "Token transfer failed"
            );
            //计算流动性代币数量
            uint256 liquidity = (totalSupply() * msg.value) / ethReserve;
            _mint(msg.sender, liquidity);
            return liquidity;
        }
    }

    //移除流动性
    function removeLiquidity(
        uint256 _amount
    ) public returns (uint256, uint256) {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = getReserve();
        uint256 ethAmount = (ethReserve * _amount) / totalSupply();
        uint256 tokenAmount = (tokenReserve * _amount) / totalSupply();
        // 销毁流动性代币
        _burn(msg.sender, _amount);
        //将以太坊发送给用户
        payable(msg.sender).transfer(ethAmount);
        //将代币发送给用户
        IERC20 token = IERC20(tokenAddress);
        require(
            token.transfer(msg.sender, tokenAmount),
            "Token transfer failed"
        );
        return (ethAmount, tokenAmount);
    }

    //获取储备量
    function getReserve() public view returns (uint256) {
        IERC20 token = IERC20(tokenAddress);
        return token.balanceOf(address(this));
    }

    // 获取以太坊能兑换多少代币
    function getTokenAomout(
        uint256 _ethSold
    ) public view override returns (uint256) {
        return getOutputAmount(_ethSold, address(this).balance, getReserve());
    }

    // 获取代币能兑换多少以太坊
    function getEthAmount(uint256 _tokenSold) public view returns (uint256) {
        return getOutputAmount(_tokenSold, getReserve(), address(this).balance);
    }

    /**
     * AMM  x * y = k
     * @dev 根据恒定乘积公式计算输入资产能兑换到的输出资产数量
     * @param inputAmount 投入的代币数量 (Δx)
     * @param inputReserve 输入代币在资金池中的储备量 (x)
     * @param outputReserve 输出代币在资金池中的储备量 (y)
     * @return 计算得到的输出代币数量 (Δy)
     */
    function getOutputAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) internal pure returns (uint256) {
        require(inputAmount > 0, "inputAmount must > 0");

        // 参数校验：储备量必须大于0，确保价格有效
        require(
            inputReserve > 0 && outputReserve > 0,
            "INSUFFICIENT_LIQUIDITY"
        );
        // 根据公式 Δy = (Δx * y) / (x + Δx) 进行计算
        //扣除手续费后进行计算，这里假设手续费为0.3%
        uint256 inputAmountWithFee = inputAmount * 997;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 1000) + inputAmountWithFee;
        return numerator / denominator;

        // uint256 numerator = inputAmount * outputReserve;
        // uint256 denominator = inputReserve + inputAmount;
        // uint256 outputAmount = numerator / denominator;
    }

    /**
     *
     * @dev 以太坊兑换代币
     * @param _minTokens 最少接受的代币数量，防止滑点过大
     * @param recipient 接收代币的地址
     */
    function ethToTokenSwap(
        uint256 _minTokens,
        address recipient
    ) public payable {
        ethToToken(_minTokens, recipient);
    }

    function ethToToken(uint256 _minTokens, address recipient) internal {
        uint256 tokensBought = getTokenAomout(msg.value);
        require(tokensBought >= _minTokens, "INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20 token = IERC20(tokenAddress);
        token.transfer(recipient, tokensBought);
    }

    function ethToTokenTransfer(
        uint256 _minTokens,
        address recipient
    ) public payable override {
        ethToToken(_minTokens, recipient);
    }

    /**
     * @dev 代币兑换以太坊
     * @param _tokensSold 代币数量
     * @param _minEth 最少接受的eth数量，防止滑点过大
     */
    function tokenToEthSwap(uint256 _tokensSold, uint256 _minEth) public {
        uint256 ethBought = getEthAmount(_tokensSold);
        require(ethBought >= _minEth, "INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20 token = IERC20(tokenAddress);
        // 将代币从用户转移到合约
        require(
            token.transferFrom(msg.sender, address(this), _tokensSold),
            "Token transfer failed"
        );
        // 将以太坊发送给用户
        payable(msg.sender).transfer(ethBought);
    }

    /**
     *  @dev 代币兑换代币
     * 1. 通过工厂合约获取目标代币的交易所地址
     * 2. 计算出卖出代币能兑换到的以太坊数量
     * 3. 在当前交易所进行代币兑换以太坊
     * 4. 在目标交易所进行以太坊兑换代币
     * @param _tokensSold  卖出代币数量
     * @param _minTokensBought  最少接受的目标代币数量，防止滑点过大
     * @param _tokenAddress  目标代币地址
     */
    function tokenToTokenSwap(
        uint256 _tokensSold,
        uint256 _minTokensBought,
        address _tokenAddress
    ) public {
        require(_tokenAddress != tokenAddress, "Cannot swap the same token");
        address exchangeAddress = IFactory(factoryAddress).getExchange(
            _tokenAddress
        );
        require(
            exchangeAddress != address(this),
            "Target exchange address cannot be the same as the current exchange"
        );
        require(
            exchangeAddress != address(0),
            "Exchange for this token does not exist"
        );

        uint256 ethBought = getEthAmount(_tokensSold);
        IERC20 token = IERC20(tokenAddress);
        // 将代币从用户转移到合约
        require(
            token.transferFrom(msg.sender, address(this), _tokensSold),
            "Token transfer failed"
        );
        // 在目标交易所进行以太坊兑换代币
        IExchange exchange = IExchange(exchangeAddress);
        uint256 tokensBought = exchange.getTokenAomout(ethBought);
        require(tokensBought >= _minTokensBought, "INSUFFICIENT_OUTPUT_AMOUNT");
        exchange.ethToTokenTransfer{value: ethBought}(
            _minTokensBought,
            msg.sender
        );
        // 将兑换到的代币发送给用户
        IERC20 targetToken = IERC20(_tokenAddress);
        require(
            targetToken.transfer(msg.sender, tokensBought),
            "Target token transfer failed"
        );
    }
}
