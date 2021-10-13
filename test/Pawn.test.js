require('@nomiclabs/hardhat-ethers');

const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');

const PawnBuild         = "contracts/pawn/pawn-p2p/PawnContract.sol:PawnContract";
const ReputationBuild   = "contracts/pawn/reputation/Reputation.sol:Reputation";
const Exchange          = "Exchange";
const PawnP2PLoanContract   = "PawnP2PLoanContract";
const DFYBuild          = "DFY";

before("Pawn For testing", async () => {
    this.DFYFactory     = await ethers.getContractFactory(DFYBuild);
    this.DFYInstance    = await this.DFYFactory.deploy();
    await this.DFYInstance.deployed();
    console.log(`DFY address: ${this.DFYInstance.address}`);

    this.PawnFactory    = await ethers.getContractFactory(PawnBuild);
    this.PawnInstance   = await this.PawnFactory.deploy();
    await this.PawnInstance.deployed();
    console.log(`Pawn address: ${this.PawnInstance.address}`);

    this.ReputationFactory  = await ethers.getContractFactory(ReputationBuild);
    this.ReputationInstance = await upgrades.deployProxy(this.ReputationFactory, { kind: 'uups' });
    await this.ReputationInstance.deployed();
    console.log(`Reputation address: ${this.ReputationInstance.address}`);

    this.ExchangeFactory  = await ethers.getContractFactory(Exchange);
    this.ExchangeInstance = await upgrades.deployProxy(this.ExchangeFactory, { kind: 'uups' });
    await this.ExchangeInstance.deployed();
    console.log(`Exchange address: ${this.ExchangeInstance.address}`);

    this.PawnP2PLoanContractFactory  = await ethers.getContractFactory(PawnP2PLoanContract);
    this.PawnP2PLoanContractInstance = await upgrades.deployProxy(this.PawnP2PLoanContractFactory, { kind: 'uups' });
    await this.PawnP2PLoanContractInstance.deployed();
    console.log(`PawnP2PLoanContract address: ${this.PawnP2PLoanContractInstance.address}`);

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
    await this.PawnInstance.setExchangeContract(this.ExchangeInstance.address);

    // Setting connections
    await this.PawnInstance.setReputationContract(this.ReputationInstance.address);
    await this.ReputationInstance.addWhitelistedContractCaller(this.PawnInstance.address);

    // Transfer from Admin to Borrower
    const transferAmount = BigInt(10 ** 21); // 1000 * 10 ** 18 = 1000 DFY
    await this.DFYInstance.transfer(this.BorrowerAccount.address, transferAmount);
    
})

describe("Pawn For testing", () => {
    it("Should return balance of Borrower account", async () => {
        const balance = await this.DFYInstance.balanceOf(this.BorrowerAccount.address);
    })
    it("Should return Reputation address", async () => {
        expect(await this.PawnInstance.reputation()).to.equal(this.ReputationInstance.address);
    })

    it("Should return 1 for whitelisted token", async () => {
        expect(await this.PawnInstance.whitelistCollateral(this.DFYInstance.address)).to.equal(1);
    })
    
    it(`Should return Reputation score = 3 for Pawnshop account - create package`, async () => {
        const pawnshop = this.PawnFactory.connect(this.PawnShopAccount);
        this.PawnInstance = pawnshop.attach(this.PawnInstance.address);
        let scoreOfPawnShopBeforeCreat = await this.ReputationInstance.getReputationScore(this.PawnShopAccount.address)
        
        const createPkgTx = await this.PawnInstance.createPawnShopPackage(
            0, 
            this.DFYInstance.address, 
            [1,BigInt(10000*10**18)],
            [this.DFYInstance.address],
            150000,
            0,
            [1,10],
            this.DFYInstance.address,
            0,
            600000,
            700000,
        );
        
        let receipt = await createPkgTx.wait();
        let packageId = receipt.events[0].args.packageId.toNumber();
        let scoreOfPawnShopAfterCreat = await this.ReputationInstance.getReputationScore(this.PawnShopAccount.address)
    
        const pkgObj = await this.PawnInstance.pawnShopPackages(packageId);

        expect(packageId == 0)
        expect(pkgObj.owner == this.PawnShopAccount.address)
        expect(pkgObj.packageType == 0)
        expect(pkgObj.loanToken == this.DFYInstance.address)
        expect(pkgObj.loanAmountRange.lowerBound == 1)
        expect(pkgObj.loanAmountRange.upperBound == BigInt(10000*10**18))
        expect(pkgObj.interest == 150000)
        expect(pkgObj.durationType == 0)
        expect(pkgObj.durationRange.lowerBound == 1)
        expect(pkgObj.durationRange.upperBound == 10)
        expect(pkgObj.repaymentAsset == this.DFYInstance.address)
        expect(pkgObj.repaymentCycleType == 0)
        expect(pkgObj.loanToValue == 600000)
        expect(pkgObj.loanToValueLiquidationThreshold == 700000)
        expect(scoreOfPawnShopAfterCreat == scoreOfPawnShopBeforeCreat + 3);
    })

    it("Should return Reputation score = 3 for Borrower account - Create Collateral", async () => {
        const collateralAmount = BigInt(10 ** 20); // 100 * 10 ** 18 = 100 DFY
        // Getting approval from DFY
        const DFY = this.DFYFactory.connect(this.BorrowerAccount);
        this.DFYInstance = DFY.attach(this.DFYInstance.address);
        await this.DFYInstance.approve(this.PawnInstance.address, collateralAmount);

        const pawnshop = this.PawnFactory.connect(this.BorrowerAccount);
        this.PawnInstance = pawnshop.attach(this.PawnInstance.address);

        let scoreOfBorrowerBeforeCreat = await this.ReputationInstance.getReputationScore(this.BorrowerAccount.address)
        
        const createColtTx = await this.PawnInstance.createCollateral(
            this.DFYInstance.address, 
            0,
            BigInt(100*10**18),
            this.DFYInstance.address,
            3,
            0
        );

        let receipt = await createColtTx.wait();
        let collateralId = receipt.events[0].args.collateralId.toNumber();
        const coltObj = await this.PawnInstance.collaterals(collateralId);
        let scoreOfBorrowerAfterCreat = await this.ReputationInstance.getReputationScore(this.BorrowerAccount.address)
        
        expect(coltObj.owner == this.BorrowerAccount.address)
        expect(coltObj.amount == BigInt(100*10**18).toString())
        expect(coltObj.collateralAddress == this.DFYInstance.address)
        expect(coltObj.loanAsset == this.DFYInstance.address)
        expect(coltObj.expectedDurationQty == 3)
        expect(coltObj.expectedDurationType == 0)
        expect(coltObj.status == 0)
        expect(scoreOfBorrowerAfterCreat == scoreOfBorrowerBeforeCreat + 3);
    })

    it("Should accept collateral for package", async () => {
        const pawnshop = this.PawnFactory.connect(this.operator);
        this.PawnInstance = pawnshop.attach(this.PawnInstance.address);
        console.log(this.PawnInstance.address)
        const checkConditionTx = await this.PawnInstance.acceptCollateralOfPackage(0,0);

        // let receipt = await checkConditionTx.wait();
        // console.log(receipt.events);
    })

})