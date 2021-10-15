require('@nomiclabs/hardhat-ethers');
// require("@openzeppelin/hardhat-upgrades");

const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');
const decimals = 10**18;
const { PawnConfig, Tokens, Exchanges } = require('../scripts/.deployment_data.json');

const PawnBuild        = "contracts/pawn/pawn-p2p/PawnContract.sol:PawnContract";
const ReputationBuild  = "contracts/pawn/reputation/Reputation.sol:Reputation";
const Exchange         = "Exchange";
const LoanBuild        = "PawnP2PLoanContract";
const DFYBuild         = "contracts/erc20/Mock-DFY.sol:DFY";

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
    // await this.PawnContract.setWhitelistCollateral(whitelistedToken, 1);
    await this.PawnContract.setWhitelistCollateral(this.DFYContract.address, 1);
    for await (let token of Tokens) {
        if(token.Address != "0x0000000000000000000000000000000000000000") {
            await this.PawnContract.setWhitelistCollateral(token.Address, 1);
            console.log(`\tWhitelisted token as collateral: ${token.Symbol}: ${token.Address}`);
        }
    }

    await this.LoanContract.setFeeWallet(feeWallet);
    await this.LoanContract.setOperator(operator);
    await this.LoanContract.setOperator(this.PawnContract.address);
    await this.LoanContract.setLateThreshold(lateThreshold);
    await this.LoanContract.setPenaltyRate(penaltyRate);
    await this.LoanContract.setPrepaidFeeRate(prepaidFeeRate);
    await this.LoanContract.setSystemFeeRate(systemFeeRate);
    // await this.LoanContract.setWhitelistCollateral(whitelistedToken, 1);
    await this.LoanContract.setWhitelistCollateral(this.DFYContract.address, 1);
    for await (let token of Tokens) {
        if(token.Address != "0x0000000000000000000000000000000000000000") {
            await this.LoanContract.setWhitelistCollateral(token.Address, 1);
            console.log(`\tWhitelisted token as collateral: ${token.Symbol}: ${token.Address}`);
        }
    }
    
    // Init Exchange contract 
    for await (let exchange of Exchanges) {
        await this.ExchangeContract.setCryptoExchange(exchange.Address, exchange.Exchange);
        console.log(`\tExchange address for ${exchange.Name}: ${exchange.Exchange}`);
    }

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
        await this.DFYContract.transfer(this.BorrowerAccount.address, BigInt(10 ** 21)); // 1000 * 10 ** 18 = 1000 DFY
        const balance = await this.DFYContract.balanceOf(this.BorrowerAccount.address);
        console.log("Ballance: ", balance.toString());
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

    // it("Should return Reputation score = 3 for Borrower account - Create Collateral", async () => {
    //     const collateralAmount = BigInt(10 ** 21); // 1000 * 10 ** 18 = 100 DFY
    //     // Getting approval from DFY
    //     const DFY = this.DFYFactory.connect(this.BorrowerAccount);
    //     this.DFYContract = DFY.attach(this.DFYContract.address);
    //     await this.DFYContract.approve(this.PawnContract.address, collateralAmount);

    //     const pawnshop = this.PawnFactory.connect(this.BorrowerAccount);
    //     this.PawnContract = pawnshop.attach(this.PawnContract.address);

    //     let scoreOfBorrowerBeforeCreate = await this.ReputationContract.getReputationScore(this.BorrowerAccount.address)
        
    //     const createColtTx = await this.PawnContract.createCollateral(
    //         this.DFYContract.address, 
    //         0,
    //         collateralAmount,
    //         this.DFYContract.address,
    //         3,
    //         0
    //     );

    //     let receipt = await createColtTx.wait();
    //     let collateralId = receipt.events[0].args.collateralId.toNumber();
    //     const coltObj = await this.PawnContract.collaterals(collateralId);
    //     let scoreOfBorrowerAfterCreat = await this.ReputationContract.getReputationScore(this.BorrowerAccount.address)
        
    //     expect(coltObj.owner == this.BorrowerAccount.address)
    //     expect(coltObj.amount == BigInt(100*10**18).toString())
    //     expect(coltObj.collateralAddress == this.DFYContract.address)
    //     expect(coltObj.loanAsset == this.DFYContract.address)
    //     expect(coltObj.expectedDurationQty == 3)
    //     expect(coltObj.expectedDurationType == 0)
    //     expect(coltObj.status == 0)
    //     expect(scoreOfBorrowerAfterCreat == scoreOfBorrowerBeforeCreate + 3);
    // })

    it("Should return Reputation score = 3 for Borrower account - Create Collateral", async () => {
        const collateralAmount = BigInt(10 ** 20); // 100 * 10 ** 18 = 100 DFY
        // Getting approval from DFY
        const DFY = this.DFYFactory.connect(this.BorrowerAccount);
        this.DFYContract = DFY.attach(this.DFYContract.address);
        await this.DFYContract.approve(this.PawnContract.address, collateralAmount);

        const pawnshop = this.PawnFactory.connect(this.BorrowerAccount);
        this.PawnContract = pawnshop.attach(this.PawnContract.address);
        const createColtTx = await this.PawnContract.createCollateral(
            this.DFYContract.address, 
            0,
            BigInt(10 ** 20),
            this.DFYContract.address,
            1,
            1
        );

        let receipt = await createColtTx.wait();

        // let topics = receipt.events[1];

        // console.log(`Number of events: ${receipt.events.length}`);
        // for(let i = 0; i < receipt.events.length; i++) {
        //     console.log(`Event number ${i}:`);
        //     console.log(receipt.events[i]);
        // }

        // console.log(topics);

        let collateralId = receipt.events[0].args.collateralId.toNumber();
        
        // console.log(receipt.events);
        // console.log(receipt.events[0]);
        // console.log(receipt.events[1]);

        console.log(`Collateral has been created with Collateral ID: ${collateralId}`);
    
        const coltObj = await this.PawnContract.collaterals(collateralId);
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

        expect(await this.ReputationContract.getReputationScore(this.BorrowerAccount.address)).to.equal(3)
    })

    it("Should accept collateral for package", async () => {
        let DFY = this.DFYFactory.connect(this.admin);
        this.DFYContract = DFY.attach(this.DFYContract.address);
        await this.DFYContract.transfer(this.PawnShopAccount.address, BigInt(10 ** 23)); // 100000 * 10 ** 18 = 1000 DFY
        await this.DFYContract.transfer(this.BorrowerAccount.address, BigInt(10 ** 21)); // 1000 * 10 ** 18 = 1000 DFY

        const collateralAmount = BigInt(200000 * decimals); // 1000 * 10 ** 18 = 100 DFY
        const pawnshop = this.PawnFactory.connect(this.operator);
        this.PawnContract = pawnshop.attach(this.PawnContract.address);
        console.log("Pawn contract: ", this.PawnContract.address);

        DFY = this.DFYFactory.connect(this.BorrowerAccount);
        this.DFYContract = DFY.attach(this.DFYContract.address);
        await this.DFYContract.approve(this.PawnContract.address, collateralAmount);
        
        DFY = this.DFYFactory.connect(this.PawnShopAccount);
        this.DFYContract = DFY.attach(this.DFYContract.address);
        await this.DFYContract.approve(this.PawnContract.address, collateralAmount);
        
        console.log(`Current lender balance: `, ((await this.DFYContract.balanceOf(this.PawnShopAccount.address))/decimals).toString());
        console.log(`Current borrower balance: `, ((await this.DFYContract.balanceOf(this.BorrowerAccount.address))/decimals).toString());

        console.log("Allowance: ", ((await this.DFYContract.allowance(this.PawnShopAccount.address, this.PawnContract.address))/decimals).toString());
        console.log("Allowance: ", ((await this.DFYContract.allowance(this.BorrowerAccount.address, this.PawnContract.address))/decimals).toString());
        
        console.log("Loan's exchange contract: ", await this.LoanContract.exchange());
        const checkConditionTx = await this.PawnContract.acceptCollateralOfPackage(0,0);

        // let receipt = await checkConditionTx.wait();
        // console.log(receipt.events);
    })

})