require('@nomiclabs/hardhat-ethers');

const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');

const PawnBuild         = "contracts/pawn/pawn-p2p/PawnContract.sol:PawnContract";
const ReputationBuild   = "contracts/pawn/reputation/Reputation.sol:Reputation";
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

    // Setting accounts
    [admin, ope, feeCollector, pawnShopAccount, borrowerAccount] = await ethers.getSigners();
    this.admin = admin;
    this.operator = ope;
    this.feeWallet = feeCollector;
    this.PawnShopAccount = pawnShopAccount;
    this.BorrowerAccount = borrowerAccount;
    console.log(`Pawnshop accounts: ${this.PawnShopAccount.address}`);
    console.log(`Borrower accounts: ${this.BorrowerAccount.address}`);

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

describe("Pawn For testing", () => {
    it("Should return balance of Borrower account", async () => {
        const balance = await this.DFYInstance.balanceOf(this.BorrowerAccount.address);
        console.log(balance.toString());
    })
    it("Should return Reputation address", async () => {
        console.log(await this.PawnInstance.reputation());
        expect(await this.PawnInstance.reputation()).to.equal(this.ReputationInstance.address);
    })

    it("Should return 1 for whitelisted token", async () => {
        console.log(`Whitelisted token: ${this.DFYInstance.address}`);
        expect(await this.PawnInstance.whitelistCollateral(this.DFYInstance.address)).to.equal(1);
    })
    
    it(`Should return Reputation score = 3 for Pawnshop account - create package`, async () => {
        const pawnshop = this.PawnFactory.connect(this.PawnShopAccount);
        this.PawnInstance = pawnshop.attach(this.PawnInstance.address);
        const createPkgTx = await this.PawnInstance.createPawnShopPackage(
            0, 
            this.DFYInstance.address, 
            [1,1000000000000000],
            [this.DFYInstance.address],
            10,
            1,
            [1,20],
            this.DFYInstance.address,
            1,
            70,
            90
        );
        
        let receipt = await createPkgTx.wait();
        let packageId = receipt.events[0].args.packageId.toNumber();
        
        // console.log(receipt.events[0].args);
        // console.log(`Package owner: ${receipt.events[0].args.data.owner}`);
        // console.log(`Package ID: ${packageId}`);

        console.log(`\n\rPawnshop loan package created with Package ID: ${packageId}`);
    
        const pkgObj = await this.PawnInstance.pawnShopPackages(packageId);
        console.log(`Owner: ${pkgObj.owner}`);
        console.log(`Package type: ${pkgObj.packageType == 0 ? "Auto" : "Semi"}`);
        console.log(`Loan token: ${pkgObj.loanToken}`);
        console.log(`Loan amount range: from ${pkgObj.loanAmountRange.lowerBound.toNumber()} to ${pkgObj.loanAmountRange.upperBound.toNumber()}`);
        console.log(`Interest: ${pkgObj.interest.toNumber()}`);
        console.log(`Duration type: ${pkgObj.durationType.toNumber() == 0 ? "Week" : "Month"}`);
        console.log(`Duration range: from ${pkgObj.durationRange.lowerBound.toNumber()} to ${pkgObj.durationRange.upperBound.toNumber()}`);
        console.log(`Repayment asset: ${pkgObj.repaymentAsset}`);
        console.log(`Repayment cycle: ${pkgObj.repaymentCycleType == 0 ? "Weekly" : "Monthly"}`);
        console.log(`Loan to value: ${pkgObj.loanToValue.toNumber()}`);
        console.log(`Liquidation threshold: ${pkgObj.loanToValueLiquidationThreshold.toNumber()}`);

        expect(await this.ReputationInstance.getReputationScore(this.PawnShopAccount.address)).to.equal(3);
    })

    it("Should return Reputation score = 3 for Borrower account - Create Collateral", async () => {
        const collateralAmount = BigInt(10 ** 20); // 100 * 10 ** 18 = 100 DFY
        // Getting approval from DFY
        const DFY = this.DFYFactory.connect(this.BorrowerAccount);
        this.DFYInstance = DFY.attach(this.DFYInstance.address);
        await this.DFYInstance.approve(this.PawnInstance.address, collateralAmount);

        const pawnshop = this.PawnFactory.connect(this.BorrowerAccount);
        this.PawnInstance = pawnshop.attach(this.PawnInstance.address);
        const createColtTx = await this.PawnInstance.createCollateral(
            this.DFYInstance.address, 
            0,
            BigInt(10 ** 20),
            this.DFYInstance.address,
            1,
            1
        );

        let receipt = await createColtTx.wait();

        let topics = receipt.events[1];

        console.log(`Number of events: ${receipt.events.length}`);
        for(let i = 0; i < receipt.events.length; i++) {
            console.log(`Event number ${i}:`);
            console.log(receipt.events[i]);
        }

        console.log(topics);

        let collateralId = receipt.events[0].args.collateralId.toNumber();
        
        // console.log(receipt.events);
        // console.log(receipt.events[0]);
        // console.log(receipt.events[1]);

        console.log(`Collateral has been created with Collateral ID: ${collateralId}`);
    
        const coltObj = await this.PawnInstance.collaterals(collateralId);
        let cltStatus;
        switch(coltObj.status) {
            case(0): 
                cltStatus = "OPEN";
                break;
            case(c1): 
                cltStatus = "DOING";
                break;
            case(2):
                cltStatus = "COMPLETED";
                break;
            case(3):
                cltStatus = "CANCEL";
                break;
        }

        console.log(`Owner: ${coltObj.owner}`);
        console.log(`Collateral amount: ${coltObj.amount}`);
        console.log(`Collateral asset token: ${coltObj.collateralAddress}`);
        console.log(`Loan asset token: ${coltObj.loanAsset}`);
        console.log(`Expected duration: ${coltObj.expectedDurationQty.toNumber()}`);
        console.log(`Duration type: ${coltObj.expectedDurationType == 0 ? "Week" : "Month"}`);
        console.log(`Collateral status: ${cltStatus}`);

        expect(await this.ReputationInstance.getReputationScore(this.BorrowerAccount.address)).to.equal(3)
    })

    // it("Should accept collateral for package", async () => {
    //     const pawnshop = this.PawnFactory.connect(this.operator);
    //     this.PawnInstance = pawnshop.attach(this.PawnInstance.address);
    //     const checkConditionTx = await this.PawnInstance.acceptCollateralOfPackage(0, 0);

    //     let receipt = await checkConditionTx.wait();

    //     console.log(receipt.events);
    // })

})