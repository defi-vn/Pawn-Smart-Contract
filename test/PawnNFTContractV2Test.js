const hre = require("hardhat");
const artifactDFYHard721 = "DFY_Hard_721";
const artifactLoanToken = "LoanToken";
const artifactRepaymentToken = "RepaymentToken";
const artifactHub = "Hub";
const artifactPawnNFTContractV2 = "PawnNFTContractV2";
const artifactHardEvaluation = "Hard_Evaluation";
const { expect, assert } = require("chai");
const BNB_ADDRESS = "0x0000000000000000000000000000000000000000";
const decimals = 10 ** 18;
const { time } = require("@openzeppelin/test-helpers");


describe("Deploy DFY Factory", (done) => {

    let _DFYHard721Contract = null;
    let _loanTokenContract = null;
    let _repaymentTokenContract = null;
    let _hubContract = null;
    let _pawnNFTContractV2 = null;
    let _hardEvaluationContract = null;

    let _evaluationFeeRate = BigInt(10 * 10 ** 5);
    let _assetCID = "Example";
    let _zoom = 1e5;
    let _fistToken = 1;
    let _loanAmount = BigInt(1 * 10 ** 18);
    let _tokenName = "DFYHard721NFT";
    let _symbol = "DFY";
    let _collectionCID = "EXAMPLE";
    let _defaultRoyaltyRate = BigInt(10 * 10 ** 5);

    before(async () => {
        [
            _deployer,
            _borrower,
            _lender,
            _evaluator,
            _feeWallet,
            _feeToken

        ] = await ethers.getSigners();

        // loan Token 
        const loanTokenFactory = await hre.ethers.getContractFactory(artifactLoanToken);
        const loanContract = await loanTokenFactory.deploy();
        _loanTokenContract = await loanContract.deployed();

        // repayment Token 
        const repaymentTokenFactory = await hre.ethers.getContractFactory(artifactRepaymentToken);
        const repaymentContract = await repaymentTokenFactory.deploy();
        _repaymentTokenContract = await repaymentContract.deployed();

        // contract Hub 
        const hubContractFactory = await hre.ethers.getContractFactory(artifactHub);
        const hubContract = await hre.upgrades.deployProxy(
            hubContractFactory,
            [_feeWallet.address, _loanTokenContract.address, _deployer.address],
            { kind: "uups" }
        );
        _hubContract = await hubContract.deployed();
        await _hubContract.connect(_deployer).setSystemConfig(_feeWallet.address, _loanTokenContract.address);
        console.log(_hubContract.address, "hub address ");

        // hard_Evaluation
        const hardEvaluationFactory = await hre.ethers.getContractFactory(artifactHardEvaluation);
        const hardEvaluationContract = await hre.upgrades.deployProxy(
            hardEvaluationFactory,
            [_hubContract.address],
            { kind: "uups" }
        );
        _hardEvaluationContract = await hardEvaluationContract.deployed();

        // DFYHard721 
        // const DFYHard721Factory = await hre.ethers.getContractFactory(artifactDFYHard721);
        // const DFYHard721Contract = await hre.upgrades.deployProxy(
        //     DFYHard721Factory,
        //     [_tokenName, _symbol, _collectionCID, _defaultRoyaltyRate, _hardEvaluationContract.address, _borrower.address],
        //     { kind: "uups" }
        // );
        // _DFYHard721Contract = await DFYHard721Contract.deployed();


        // // pawnNFTContractV2 
        // const pawnNFTContractV2Factory = await hre.ethers.getContractFactory(artifactPawnNFTContractV2);
        // const pawnNFTContract = await pawnNFTContractV2Factory.deploy();
        // _pawnNFTContractV2 = await pawnNFTContract.deployed();
    });

    describe("unit PawnNFTContract V2  ", async () => {

        it("hard evaluation addWhiteListEvaluationFee and addWhiteListMintingFee after check it information ", async () => {

            // await _hardEvaluationContract.connect(_deployer).addWhiteListEvaluationFee(_loanTokenContract.address, _evaluationFeeRate);
            // await _hardEvaluationContract.addWhiteListMintingFee(_loanTokenContract.address, _evaluationFeeRate);

            // // output : trả về _evaluationFeeRate tương ứng với address token 
            // let getWhiteListEvaluationFee = await _hardEvaluationContract.whiteListEvaluationFee(_loanTokenContract.address);
            // let getwhiteListMintingFee = await _hardEvaluationContract.whiteListMintingFee(_loanTokenContract.address);

            // console.log(getWhiteListEvaluationFee.toString(), "getWhiteListEvaluationFee");
            // console.log(getwhiteListMintingFee.toString(), "getwhiteListMintingFee");
        });

        // it("borrower create asset request and check it information : ", async () => {

        //     // create Asset request 
        //     await _hardEvaluationContract.connect(_borrower).createAssetRequest(_assetCID, _DFYHard721Contract.address, 0);
        //     let assetList = await _hardEvaluationContract.assetList(0);

        //     expect(assetList.assetCID).to.equal(_assetCID);
        //     expect(assetList.owner).to.equal(_borrower.address);
        //     expect(assetList.collectionAddress).to.equal(_DFYHard721Contract.address);
        //     expect(assetList.collectionStandard).to.equal(0);
        //     expect(assetList.status).to.equal(0);
        // });

        // it("borrower create Appointment and check it information : ", async () => {

        //     // loan token drop and approve
        //     await _loanTokenContract.setOperator(_deployer.address, true);
        //     await _loanTokenContract.mint(_deployer.address, BigInt(1000 * 10 ** 18));
        //     await _loanTokenContract.connect(_deployer).transfer(_borrower.address, BigInt(100 * 10 ** 18));
        //     await _loanTokenContract.connect(_borrower).approve(_hardEvaluationContract.address, BigInt(100 * 10 ** 18));

        //     let balanceOfBorrowerBeforeTXT = await _loanTokenContract.balanceOf(_borrower.address);
        //     let balanceOfContractHardEvaluationBeforeTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

        //     console.log("before TXT : ");
        //     console.log(balanceOfBorrowerBeforeTXT.toString(), "balance of Borrower Before TXT ");
        //     console.log(balanceOfContractHardEvaluationBeforeTXT.toString(), "balance of Contract HardEvaluation Before TXT ");

        //     await _hardEvaluationContract.connect(_borrower).createAppointment(0, _evaluator.address, _loanTokenContract.address);

        //     // check info after create  
        //     let appointmentList = await _hardEvaluationContract.appointmentList(0);
        //     expect(appointmentList.assetId).to.equal(0);
        //     expect(appointmentList.assetOwner).to.equal(_borrower.address);
        //     expect(appointmentList.evaluator).to.equal(_evaluator.address);
        //     expect(appointmentList.evaluationFee).to.equal(_evaluationFeeRate);
        //     expect(appointmentList.evaluationFeeAddress).to.equal(_loanTokenContract.address);

        //     // get appointmentId from list asset 
        //     let getIdAppointmentListOfAsset = await _hardEvaluationContract.appointmentListOfAsset(0, 0);
        //     // query AssetList with appointmentId
        //     let assetList = await _hardEvaluationContract.assetList(getIdAppointmentListOfAsset);
        //     // check status asset
        //     expect(assetList.status).to.equal(1);

        //     // check transfer 
        //     let balanceOfBorrowerAfterTXT = await _loanTokenContract.balanceOf(_borrower.address);
        //     let balanceOfContractHardEvaluationAfterTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

        //     console.log("After TXT : ");
        //     console.log(balanceOfBorrowerAfterTXT.toString(), "balance of Borrower After TXT ");
        //     console.log(balanceOfContractHardEvaluationAfterTXT.toString(), "balance of Contract HardEvaluation After TXT ");

        //     expect(balanceOfBorrowerBeforeTXT).to.equal(BigInt(balanceOfBorrowerAfterTXT) + BigInt(_evaluationFeeRate));
        //     expect(balanceOfContractHardEvaluationBeforeTXT).to.equal(BigInt(balanceOfContractHardEvaluationAfterTXT) - BigInt(_evaluationFeeRate));

        // });

        // it("Evaluator accept Appoitment and check it information ", async () => {

        //     // grant evalutor roll 
        //     await _hubContract.connect(_deployer).setEvaluationRole(_evaluator.address);
        //     await _hardEvaluationContract.connect(_evaluator).acceptAppointment(0);

        //     // check status turn accept 
        //     let info = await _hardEvaluationContract.appointmentList(0);
        //     // 1 is ACCEPTED
        //     expect(info.status).to.equal(1);
        // });

        // it("Evaluator evaluated Asset and check it information ", async () => {

        //     let balanceOfContractHardEvaluationBeforeTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);
        //     let balanceOfEvaluatorBeforeTXT = await _loanTokenContract.balanceOf(_evaluator.address);

        //     console.log("before TXT : ");
        //     console.log(balanceOfEvaluatorBeforeTXT.toString(), "balance of Evaluator Before TXT ");
        //     console.log(balanceOfContractHardEvaluationBeforeTXT.toString(), "balance of Contract HardEvaluation Before TXT ");

        //     await _hardEvaluationContract.connect(_evaluator).evaluatedAsset(_DFYHard721Contract.address,
        //         0, 10, "_evaluationCID", BigInt(1 * 10 ** 18), _loanTokenContract.address);

        //     let balanceOfEvalutorAfterTXT = await _loanTokenContract.balanceOf(_evaluator.address);
        //     let balanceOfContractHardEvaluationAfterTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

        //     console.log("After TXT : ");
        //     console.log(balanceOfEvalutorAfterTXT.toString(), "balance of Evaluator After TXT ");
        //     console.log(balanceOfContractHardEvaluationAfterTXT.toString(), "balance of Contract HardEvaluation After TXT ");

        //     expect(balanceOfEvaluatorBeforeTXT).to.equal(BigInt(balanceOfEvalutorAfterTXT) - BigInt(_evaluationFeeRate));
        //     expect(balanceOfContractHardEvaluationBeforeTXT).to.equal(BigInt(balanceOfContractHardEvaluationAfterTXT) + BigInt(_evaluationFeeRate));
        // });

        // it("borrower accept evaluation check it information ", async () => {

        //     let balanceOfBorrowerBeforeTXT = await _loanTokenContract.balanceOf(_borrower.address);
        //     let balanceOfContractHardEvaluationBeforeTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

        //     console.log("before TXT : ");
        //     console.log(balanceOfBorrowerBeforeTXT.toString(), "balance of Borrower Before TXT ");
        //     console.log(balanceOfContractHardEvaluationBeforeTXT.toString(), "balance of Contract HardEvaluation Before TXT ");

        //     await _hardEvaluationContract.connect(_borrower).acceptEvaluation(0);

        //     let balanceOfBorrowerAfterTXT = await _loanTokenContract.balanceOf(_borrower.address);
        //     let balanceOfContractHardEvaluationAfterTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

        //     console.log("After TXT : ");
        //     console.log(balanceOfBorrowerAfterTXT.toString(), "balance of Evaluator After TXT ");
        //     console.log(balanceOfContractHardEvaluationAfterTXT.toString(), "balance of Contract HardEvaluation After TXT ");

        //     expect(balanceOfBorrowerBeforeTXT).to.equal(BigInt(balanceOfBorrowerAfterTXT) + BigInt(_evaluationFeeRate));
        //     expect(balanceOfContractHardEvaluationBeforeTXT).to.equal(BigInt(balanceOfContractHardEvaluationAfterTXT) - BigInt(_evaluationFeeRate));
        // });

        // it("Evaluator create NFT", async () => {

        //     let balanceOfContractHardEvaluationBeforeTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);
        //     let balanceOfHubFeeWalletBeforeTXt = await _loanTokenContract.balanceOf(_feeWallet.address);

        //     console.log("before TXT : ");

        //     console.log(balanceOfContractHardEvaluationBeforeTXT.toString(), "balance of Contract HardEvaluation Before TXT ");
        //     console.log(balanceOfHubFeeWalletBeforeTXt.toString(), "balance of hub fee wallet Before TXT ");

        //     await _hardEvaluationContract.connect(_evaluator).createNftToken(0, 1, "NFTCID");

        //     let balanceOfContractHardEvaluationAfterTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);
        //     let balanceOfHubFeeWalletAfterTXt = await _loanTokenContract.balanceOf(_feeWallet.address);

        //     console.log("After TXT : ");
        //     console.log(balanceOfHubFeeWalletAfterTXt.toString(), "balance of hub fee wallet After TXT ");
        //     console.log(balanceOfContractHardEvaluationAfterTXT.toString(), "balance of Contract HardEvaluation After TXT ");

        //     // expect()

        // });

        // it("Evaluator reject Appoitment and check it information ", async () => {

        //     let balanceOfBorrowerBeforeTXT = await _loanTokenContract.balanceOf(_borrower.address);
        //     let balanceOfContractHardEvaluationBeforeTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

        //     console.log("before TXT : ");
        //     console.log(balanceOfBorrowerBeforeTXT.toString(), "balance of Borrower Before TXT ");
        //     console.log(balanceOfContractHardEvaluationBeforeTXT.toString(), "balance of Contract HardEvaluation Before TXT ");

        //     await _hardEvaluationContract.connect(_borrower).createAssetRequest(_assetCID, _DFYHard721Contract.address, 0);
        //     await _hardEvaluationContract.connect(_borrower).createAppointment(1, _evaluator.address, _loanTokenContract.address);
        //     await _hardEvaluationContract.connect(_evaluator).rejectAppointment(1, "không thích đấy");

        //     let balanceOfBorrowerAfterTXT = await _loanTokenContract.balanceOf(_borrower.address);
        //     let balanceOfContractHardEvaluationAfterTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

        //     console.log("After TXT : ");
        //     console.log(balanceOfBorrowerAfterTXT.toString(), "balance of Borrower After TXT ");
        //     console.log(balanceOfContractHardEvaluationAfterTXT.toString(), "balance of Contract HardEvaluation After TXT ");

        //     let info = await _hardEvaluationContract.appointmentList(1);
        //     expect(info.status).to.equal(2);
        //     expect(balanceOfBorrowerBeforeTXT).to.equal(BigInt(balanceOfBorrowerAfterTXT));
        //     expect(balanceOfContractHardEvaluationBeforeTXT).to.equal(BigInt(balanceOfContractHardEvaluationAfterTXT));

        // });

        // it("Evaluator reject Appoitment and check it information ", async () => {

        //     let balanceOfBorrowerBeforeTXT = await _loanTokenContract.balanceOf(_borrower.address);
        //     let balanceOfContractHardEvaluationBeforeTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

        //     console.log("before TXT : ");
        //     console.log(balanceOfBorrowerBeforeTXT.toString(), "balance of Borrower Before TXT ");
        //     console.log(balanceOfContractHardEvaluationBeforeTXT.toString(), "balance of Contract HardEvaluation Before TXT ");

        //     await _hardEvaluationContract.connect(_borrower).createAssetRequest(_assetCID, _DFYHard721Contract.address, 0);
        //     await _hardEvaluationContract.connect(_borrower).createAppointment(2, _evaluator.address, _loanTokenContract.address);
        //     await _hardEvaluationContract.cancelAppointment(2, "unknow");

        //     let balanceOfBorrowerAfterTXT = await _loanTokenContract.balanceOf(_borrower.address);
        //     let balanceOfContractHardEvaluationAfterTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

        //     console.log("After TXT : ");
        //     console.log(balanceOfBorrowerAfterTXT.toString(), "balance of Borrower After TXT ");
        //     console.log(balanceOfContractHardEvaluationAfterTXT.toString(), "balance of Contract HardEvaluation After TXT ");

        //     let info = await _hardEvaluationContract.appointmentList(2);
        //     expect(info.status).to.equal(3);
        //     expect(balanceOfBorrowerBeforeTXT).to.equal(BigInt(balanceOfBorrowerAfterTXT));
        //     expect(balanceOfContractHardEvaluationBeforeTXT).to.equal(BigInt(balanceOfContractHardEvaluationAfterTXT));
        // });

    });
});