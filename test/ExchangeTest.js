// 修正导入：通常直接从 chai 导入 expect
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Exchange", function () {
    let myToken;
    let exchange;
    let owner;

    beforeEach(async function () {
        // 获取签名者
        [owner] = await ethers.getSigners();
        
        // 部署MyToken合约
        const MyToken = await ethers.getContractFactory("MyToken");
        myToken = await MyToken.deploy("MyToken", "MTK", ethers.parseEther("1000000"));
        await myToken.waitForDeployment();
        const myTokenAddress = await myToken.getAddress();
        console.log("MyToken deployed to:", myTokenAddress);

        // 部署Exchange合约
        const Exchange = await ethers.getContractFactory("Exchange");
        exchange = await Exchange.deploy(myTokenAddress); // 直接使用地址字符串
        await exchange.waitForDeployment();
        const exchangeAddress = await exchange.getAddress();
        console.log("Exchange deployed to:", exchangeAddress);

        // 可选：检查部署者的代币余额
        const ownerBalance = await myToken.balanceOf(owner.address);
        console.log("Owner token balance:", ethers.formatEther(ownerBalance));
    });

    //添加流动性测试用例
    it("should add liquidity correctly", async function () {
        const tokenAmount = ethers.parseEther("1000");
        const ethAmount = ethers.parseEther("10");

        // 1. 授权Exchange合约使用代币
        console.log("Approving tokens for exchange...");
        const approveTx = await myToken.approve(await exchange.getAddress(), tokenAmount);
        await approveTx.wait(); // 等待确认
        console.log("Approval confirmed.");

        // 检查授权额度
        const allowance = await myToken.allowance(owner.address, await exchange.getAddress());
        console.log("Allowance granted:", ethers.formatEther(allowance));
        if (allowance < tokenAmount) {
            throw new Error("Insufficient allowance granted.");
        }

        // 2. 添加流动性
        console.log("Adding liquidity...");
        // 注意：确保 addLiquidity 函数能正确处理 ETH (payable)
        const addLiquidityTx = await exchange.addLiquidity(tokenAmount, { value: ethAmount });
        const receipt = await addLiquidityTx.wait(); // 等待并获取收据
        console.log("Liquidity added. Transaction hash:", receipt.hash);

        // 3. 检查准备金
        const reserve = await exchange.getReserve();
        console.log("Reserve in exchange:", ethers.formatEther(reserve));
        expect(reserve).to.equal(tokenAmount);
    });

    // 测试兑换计算函数
    it("should get correct amount of tokens for given ETH", async function () {
        const tokenAmount = ethers.parseEther("1000");
        const ethAmount = ethers.parseEther("1000");

        // 添加流动性前的准备
        const approveTx = await myToken.approve(await exchange.getAddress(), tokenAmount);
        await approveTx.wait();
        const addLiquidityTx = await exchange.addLiquidity(tokenAmount, { value: ethAmount });
        await addLiquidityTx.wait();

        // 测试eth兑换tokens计算
        const inputEth = ethers.parseEther("1000");
        const tokensOut = await exchange.getTokenAomout(inputEth);
        console.log(`For ${ethers.formatEther(inputEth)} ETH, you get ${ethers.formatEther(tokensOut)} tokens.`);
        
        // 简单断言，确保返回值大于0
        expect(tokensOut).to.be.gt(0);


        // 测试tokens兑换eth计算
        const inputTokens = ethers.parseEther("1000");
        const ethOut = await exchange.getEthAmount(inputTokens);
        console.log(`For ${ethers.formatEther(inputTokens)} tokens, you get ${ethers.formatEther(ethOut)} ETH.`);

    });

    // 移除流动性测试用例
    it("should remove liquidity correctly", async function () {
        const tokenAmount = ethers.parseEther("1000");
        const ethAmount = ethers.parseEther("10");

        // 添加流动性准备
        const approveTx = await myToken.approve(await exchange.getAddress(), tokenAmount);
        await approveTx.wait();
        const addLiquidityTx = await exchange.addLiquidity(tokenAmount, { value: ethAmount });
        await addLiquidityTx.wait();

        // 获取流动性代币余额
        const liquidityBalance = await exchange.balanceOf(owner.address);
        console.log("Liquidity tokens owned:", ethers.formatEther(liquidityBalance));

        // 移除流动性
        console.log("Removing liquidity...");
        const removeLiquidityTx = await exchange.removeLiquidity(liquidityBalance);
        const receipt = await removeLiquidityTx.wait();
        console.log("Liquidity removed. Transaction hash:", receipt.hash);

        // 检查移除后准备金
        const reserve = await exchange.getReserve();
        console.log("Reserve after removing liquidity:", ethers.formatEther(reserve));
        expect(reserve).to.equal(0);
    });
});