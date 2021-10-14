require('@nomiclabs/hardhat-ethers');
require("@openzeppelin/hardhat-upgrades");

const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');
const { PawnConfig, Tokens } = require('../scripts/.deployment_data.json');

const PawnBuild        = "contracts/pawn/pawn-p2p/PawnContract.sol:PawnContract";
const ReputationBuild  = "contracts/pawn/reputation/Reputation.sol:Reputation";
const Exchange         = "Exchange";
const LoanBuild        = "PawnP2PLoanContract";
const DFYBuild         = "DFY";

before("Pawn For testing", async () => {
    this.DFYFactory     = await ethers.getContractFactory(DFYBuild);
    this.DFYContract    = await upgrades.deployProxy(this.DFYFactory, { kind: 'uups' });
    await this.DFYContract.deployed();
    console.log(`DFY address: ${this.DFYContract.address}`);

    this.PawnFactory    = await ethers.getContractFactory(PawnBuild);
    this.PawnContract   = await this.PawnFactory.deploy();
    await this.PawnContract.deployed();
    console.log(`Pawn address: ${this.PawnContract.address}`);

    this.ReputationFactory  = await ethers.getContractFactory(ReputationBuild);
    this.ReputationContract = await upgrades.deployProxy(this.ReputationFactory, { kind: 'uups' });
    await this.ReputationContract.deployed();
    console.log(`Reputation address: ${this.ReputationContract.address}`);

    this.ExchangeFactory  = await ethers.getContractFactory(Exchange);
    this.ExchangeContract = await upgrades.deployProxy(this.ExchangeFactory, { kind: 'uups' });
    await this.ExchangeContract.deployed();
    console.log(`Exchange address: ${this.ExchangeContract.address}`);

    this.LoanFactory  = await ethers.getContractFactory(LoanBuild);
    this.LoanContract = await upgrades.deployProxy(this.LoanFactory, [100000], { kind: 'uups' });
    await this.LoanContract.deployed();
    console.log(`PawnP2PLoanContract address: ${this.LoanContract.address}`);

    // Setting accounts
    [admin, ope, feeCollector, pawnShopAccount, borrowerAccount] = await ethers.getSigners();
    this.admin = admin;
    this.operator = ope;
    this.feeWallet = feeCollector;
    this.PawnShopAccount = pawnShopAccount;
    this.BorrowerAccount = borrowerAccount;

    // Initialize Pawn contract
    const zoom              = PawnConfig.ZOOM;
    const lateThreshold     = PawnConfig.LateThreshold;
    const penaltyRate       = PawnConfig.PenaltyRate;
    const prepaidFeeRate    = PawnConfig.PrepaidFee;
    const systemFeeRate     = PawnConfig.SystemFee;
    const whitelistedToken  = this.DFYContract.address;
    const operator          = this.operator.address;
    const feeWallet         = this.feeWallet.address;

    await this.PawnContract.initialize(PawnConfig.ZOOM);
    await this.PawnContract.setFeeWallet(feeWallet);
    await this.PawnContract.setOperator(operator);
    await this.PawnContract.setLateThreshold(lateThreshold);
    await this.PawnContract.setPenaltyRate(penaltyRate);
    await this.PawnContract.setPrepaidFeeRate(prepaidFeeRate);
    await this.PawnContract.setSystemFeeRate(systemFeeRate);
    await this.PawnContract.setWhitelistCollateral(whitelistedToken, 1);
    await this.PawnContract.setExchangeContract(this.ExchangeContract.address);

    await this.LoanContract.setFeeWallet(feeWallet);
    await this.LoanContract.setOperator(operator);
    await this.LoanContract.setLateThreshold(lateThreshold);
    await this.LoanContract.setPenaltyRate(penaltyRate);
    await this.LoanContract.setPrepaidFeeRate(prepaidFeeRate);
    await this.LoanContract.setSystemFeeRate(systemFeeRate);
    await this.LoanContract.setWhitelistCollateral(whitelistedToken, 1);
    await this.LoanContract.setOperator(this.PawnContract.address);

    // Setting connections
    await this.PawnContract.setReputationContract(this.ReputationContract.address);
    await this.PawnContract.setExchangeContract(this.ExchangeContract.address);
    await this.PawnContract.setPawnLoanContract(this.LoanContract.address);

    await this.LoanContract.setReputationContract(this.ReputationContract.address);
    await this.LoanContract.setExchangeContract(this.ExchangeContract.address);
    await this.LoanContract.setPawnContract(this.PawnContract.address);
    
    await this.ReputationContract.addWhitelistedContractCaller(this.PawnContract.address);
    await this.ReputationContract.addWhitelistedContractCaller(this.LoanContract.address);

    // Transfer from Admin to Borrower
    // const transferAmount = BigInt(10 ** 21); // 1000 * 10 ** 18 = 1000 DFY
    await this.DFYContract.transfer(this.PawnShopAccount.address, BigInt(10 ** 23)); // 100000 * 10 ** 18 = 1000 DFY
    await this.DFYContract.transfer(this.BorrowerAccount.address, BigInt(10 ** 21)); // 1000 * 10 ** 18 = 1000 DFY
})

describe("Pawn For testing", () => {
    it("Should return balance of Borrower account", async () => {
        const balance = await this.DFYContract.balanceOf(this.BorrowerAccount.address);
    })
    it("Should return Reputation address", async () => {
        expect(await this.PawnContract.reputation()).to.equal(this.ReputationContract.address);
    })

    it("Should return 1 for whitelisted token", async () => {
        expect(await this.PawnContract.whitelistCollateral(this.DFYContract.address)).to.equal(1);
    })
    
    it(`Should return Reputation score = 3 for Pawnshop account - create package`, async () => {
        const pawnshop = this.PawnFactory.connect(this.PawnShopAccount);
        this.PawnContract = pawnshop.attach(this.PawnContract.address);
        let scoreOfPawnShopBeforeCreat = await this.ReputationContract.getReputationScore(this.PawnShopAccount.address)
        
        const createPkgTx = await this.PawnContract.createPawnShopPackage(
            0, 
            this.DFYContract.address, 
            [1,BigInt(10000*10**18)],
            [this.DFYContract.address],
            150000,
            0,
            [1,10],
            this.DFYContract.address,
            0,
            600000,
            700000,
        );
        
        let receipt = await createPkgTx.wait();
        let packageId = receipt.events[0].args.packageId.toNumber();
        let scoreOfPawnShopAfterCreat = await this.ReputationContract.getReputationScore(this.PawnShopAccount.address)
    
        const pkgObj = await this.PawnContract.pawnShopPackages(packageId);

        expect(packageId == 0)
        expect(pkgObj.owner == this.PawnShopAccount.address)
        expect(pkgObj.packageType == 0)
        expect(pkgObj.loanToken == this.DFYContract.address)
        expect(pkgObj.loanAmountRange.lowerBound == 1)
        expect(pkgObj.loanAmountRange.upperBound == BigInt(10000*10**18))
        expect(pkgObj.interest == 150000)
        expect(pkgObj.durationType == 0)
        expect(pkgObj.durationRange.lowerBound == 1)
        expect(pkgObj.durationRange.upperBound == 10)
        expect(pkgObj.repaymentAsset == this.DFYContract.address)
        expect(pkgObj.repaymentCycleType == 0)
        expect(pkgObj.loanToValue == 600000)
        expect(pkgObj.loanToValueLiquidationThreshold == 700000)
        expect(scoreOfPawnShopAfterCreat == scoreOfPawnShopBeforeCreat + 3);
    })

    it("Should return Reputation score = 3 for Borrower account - Create Collateral", async () => {
        const collateralAmount = BigInt(10 ** 20); // 100 * 10 ** 18 = 100 DFY
        // Getting approval from DFY
        const DFY = this.DFYFactory.connect(this.BorrowerAccount);
        this.DFYContract = DFY.attach(this.DFYContract.address);
        await this.DFYContract.approve(this.PawnContract.address, collateralAmount);

        const pawnshop = this.PawnFactory.connect(this.BorrowerAccount);
        this.PawnContract = pawnshop.attach(this.PawnContract.address);

        let scoreOfBorrowerBeforeCreat = await this.ReputationContract.getReputationScore(this.BorrowerAccount.address)
        
        const createColtTx = await this.PawnContract.createCollateral(
            this.DFYContract.address, 
            0,
            BigInt(100*10**18),
            this.DFYContract.address,
            3,
            0
        );

        let receipt = await createColtTx.wait();
        let collateralId = receipt.events[0].args.collateralId.toNumber();
        const coltObj = await this.PawnContract.collaterals(collateralId);
        let scoreOfBorrowerAfterCreat = await this.ReputationContract.getReputationScore(this.BorrowerAccount.address)
        
        expect(coltObj.owner == this.BorrowerAccount.address)
        expect(coltObj.amount == BigInt(100*10**18).toString())
        expect(coltObj.collateralAddress == this.DFYContract.address)
        expect(coltObj.loanAsset == this.DFYContract.address)
        expect(coltObj.expectedDurationQty == 3)
        expect(coltObj.expectedDurationType == 0)
        expect(coltObj.status == 0)
        expect(scoreOfBorrowerAfterCreat == scoreOfBorrowerBeforeCreat + 3);
    })

    it("Should accept collateral for package", async () => {
        const pawnshop = this.PawnFactory.connect(this.operator);
        this.PawnContract = pawnshop.attach(this.PawnContract.address);
        console.log(this.PawnContract.address);
        console.log(await this.LoanContract.exchange());
        const checkConditionTx = await this.PawnContract.acceptCollateralOfPackage(0,0);

        let receipt = await checkConditionTx.wait();
        console.log(receipt.events);
    })

})