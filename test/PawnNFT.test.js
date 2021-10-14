require('@nomiclabs/hardhat-ethers');

const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');

const PawnNFT         = "contracts/pawn/pawn-p2p/PawnContract.sol:PawnContract";
const Evaluation      = "contracts/pawn/evaluation/EvaluationContract.sol:AssetEvaluation";
const DFY_NFT         = "contracts/pawn/nft/DFY_Physical_NFTs.sol:DFY_Physical_NFTs"
const Reputation      = "contracts/pawn/reputation/Reputation.sol:Reputation";
const DFY_Token       = "DFY";

before("PawnNFT For testing", async () => {
    this.PawnNFTFactory     = await ethers.getContractFactory(PawnNFT);
    this.PawnNFTInstance    = await this.PawnNFTFactory.deploy();
    await this.PawnNFTInstance.deployed();

    this.EvaluationFactory     = await ethers.getContractFactory(Evaluation);
    this.EvaluationInstance    = await this.EvaluationFactory.deploy();
    await this.EvaluationInstance.deployed();

    this.ReputationFactory  = await ethers.getContractFactory(Reputation);
    this.ReputationInstance = await upgrades.deployProxy(this.ReputationFactory, { kind: 'uups' });
    await this.ReputationInstance.deployed();

    this.DFY_NFTFactory     = await ethers.getContractFactory(DFY_NFT);
    this.DFY_NFTInstance    = await this.DFY_NFTFactory.deploy();
    await this.DFY_NFTInstance.deployed();

    this.DFY_TokenFactory     = await ethers.getContractFactory(DFY_Token);
    this.DFY_TokenInstance    = await this.DFY_TokenFactory.deploy();
    await this.DFY_TokenInstance.deployed();

    // Setting accounts
    [admin, ope, feeCollector, pawnShopAccount, borrowerAccount] = await ethers.getSigners();
    this.admin = admin;
    this.operator = ope;
    this.feeWallet = feeCollector;
    this.PawnShopAccount = pawnShopAccount;
    this.BorrowerAccount = borrowerAccount;


    // Initialize Pawn contract
    const zoom              = 100000;
    const lateThreshold     = 3;
    const penaltyRate       = 15000000;
    const prepaidFeeRate    = 300000;
    const systemFeeRate     = 2000000;
    const whitelistedToken  = this.DFYInstance.address;
    const operator          = this.operator.address;
    const feeWallet         = this.feeWallet.address;

    await this.PawnInstance.initialize(zoom);
    await this.PawnInstance.setFeeWallet(feeWallet);
    await this.PawnInstance.setOperator(operator);
    await this.PawnInstance.setLateThreshold(lateThreshold);
    await this.PawnInstance.setPenaltyRate(penaltyRate);
    await this.PawnInstance.setPrepaidFeeRate(prepaidFeeRate);
    await this.PawnInstance.setSystemFeeRate(systemFeeRate);
    await this.PawnInstance.setWhitelistCollateral(whitelistedToken, 1);

    // Setting connections
    await this.PawnInstance.setReputationContract(this.ReputationInstance.address);
    await this.ReputationInstance.addWhitelistedContractCaller(this.PawnInstance.address);

    // Transfer from Admin to Borrower
    const transferAmount = BigInt(10 ** 21); // 1000 * 10 ** 18 = 1000 DFY
    await this.DFYInstance.transfer(this.BorrowerAccount.address, transferAmount);
    
})