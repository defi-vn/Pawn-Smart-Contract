const hre = require("hardhat");
const artifactDFYHard721 = "DFYHard721";
const artifactLoanToken = "LoanToken";
const artifactHub = "Hub";
const artifactHardEvaluation = "HardEvaluation";
const { expect, assert } = require("chai");


describe("Deploy DFY Factory", (done) => {

    let _DFYHard721Contract = null;
    let _loanTokenContract = null;
    let _hubContract = null;
    let _hardEvaluationContract = null;
    let _evaluationFee = BigInt(1 * 10 ** 18);
    let _mintingFee = BigInt(1 * 10 ** 18);
    let _assetCID = "Example";
    let _tokenName = "DFYHard721NFT";
    let _symbol = "DFY";
    let _collectionCID = "EXAMPLE";
    let _defaultRoyaltyRate = BigInt(10 * 10 ** 5);
    let appointmentTime = Math.floor(Date.now() / 1000) + 300;

    before(async () => {
        [
            _deployer,
            _customer,
            _evaluator,
            _feeWallet,
            _feeToken
        ] = await ethers.getSigners();

        // loan Token 
        const loanTokenFactory = await hre.ethers.getContractFactory(artifactLoanToken);
        const loanContract = await loanTokenFactory.deploy();
        _loanTokenContract = await loanContract.deployed();

        // contract Hub 
        const hubContractFactory = await hre.ethers.getContractFactory(artifactHub);
        const hubContract = await hre.upgrades.deployProxy(
            hubContractFactory,
            [_feeWallet.address, _loanTokenContract.address, _deployer.address],
            { kind: "uups" }
        );
        _hubContract = await hubContract.deployed();

        // hard_Evaluation
        const hardEvaluationFactory = await hre.ethers.getContractFactory(artifactHardEvaluation);
        const hardEvaluationContract = await hre.upgrades.deployProxy(
            hardEvaluationFactory,
            [_hubContract.address],
            { kind: "uups" }
        );
        _hardEvaluationContract = await hardEvaluationContract.deployed();
        console.log(_hardEvaluationContract.address, "hard : ");

        // DFYHard721 
        const DFYHard721Factory = await hre.ethers.getContractFactory(artifactDFYHard721);
        const DFYHard721Contract = await DFYHard721Factory.deploy(
            _tokenName,
            _symbol,
            _collectionCID,
            _defaultRoyaltyRate,
            _hardEvaluationContract.address,
            _deployer.address
        );
        _DFYHard721Contract = await DFYHard721Contract.deployed();
    });

    describe("unit PawnNFTContract V2  ", async () => {

        it("case 1 : evaluator create NFT for customer ", async () => {

            // -> customer create asset request
            await _hardEvaluationContract.connect(_deployer).addWhiteListFee(_loanTokenContract.address, _evaluationFee, _mintingFee); // addWhiteListFee -> add address token to pay for evaluation fee , mint nft fee 
            await _hardEvaluationContract.connect(_customer).createAssetRequest(_assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18), _loanTokenContract, 0); // create Asset request 
            let assetList = await _hardEvaluationContract.assetList(0);

            expect(assetList.assetCID).to.equal(_assetCID);
            expect(assetList.owner).to.equal(_customer.address);
            expect(assetList.collectionAddress).to.equal(_DFYHard721Contract.address);
            expect(assetList.collectionStandard).to.equal(0);
            expect(assetList.status).to.equal(0);

            // -> customer create Appointment 
            await _loanTokenContract.setOperator(_deployer.address, true); // loan token transfer for customer and approve
            await _loanTokenContract.mint(_deployer.address, BigInt(1000 * 10 ** 18));
            await _loanTokenContract.connect(_deployer).transfer(_customer.address, BigInt(100 * 10 ** 18));
            await _loanTokenContract.connect(_customer).approve(_hardEvaluationContract.address, BigInt(100 * 10 ** 18));

            let balanceOfCustomerBeforeTXT = await _loanTokenContract.balanceOf(_customer.address);
            let balanceOfContractHardEvaluationBeforeTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

            console.log("before TXT : ");
            console.log(balanceOfCustomerBeforeTXT.toString(), "balance of Borrower Before TXT ");
            console.log(balanceOfContractHardEvaluationBeforeTXT.toString(), "balance of Contract HardEvaluation Before TXT ");

            await _hardEvaluationContract.connect(_customer).createAppointment(0, _evaluator.address, _loanTokenContract.address, appointmentTime);

            let appointmentList = await _hardEvaluationContract.appointmentList(0); // check info after create 
            expect(appointmentList.assetId).to.equal(0);
            expect(appointmentList.assetOwner).to.equal(_customer.address);
            expect(appointmentList.evaluator).to.equal(_evaluator.address);
            expect(appointmentList.evaluationFee).to.equal(_evaluationFee);
            expect(appointmentList.evaluationFeeAddress).to.equal(_loanTokenContract.address);

            let getIdAppointmentListOfAsset = await _hardEvaluationContract.appointmentListOfAsset(0, 0); // get appointmentId from list asset 
            await _hardEvaluationContract.assetList(getIdAppointmentListOfAsset); // query AssetList with appointmentId
            assetList = await _hardEvaluationContract.assetList(0);

            expect(assetList.status).to.equal(1); // check status asset

            let balanceOfCustomerAfterTXT = await _loanTokenContract.balanceOf(_customer.address); // check transfer 
            let balanceOfContractHardEvaluationAfterTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

            console.log("After TXT : ");
            console.log(balanceOfCustomerAfterTXT.toString(), "balance of Borrower After TXT ");
            console.log(balanceOfContractHardEvaluationAfterTXT.toString(), "balance of Contract HardEvaluation After TXT ");

            expect(balanceOfCustomerBeforeTXT).to.equal(BigInt(balanceOfCustomerAfterTXT) + BigInt(_evaluationFee));
            expect(balanceOfContractHardEvaluationBeforeTXT).to.equal(BigInt(balanceOfContractHardEvaluationAfterTXT) - BigInt(_evaluationFee));

            // -> Evaluator accept Appoitment

            let getEVALUATOR_ROLE = await _hubContract.EvaluatorRole();  // grant evalutor roll 
            await _hubContract.connect(_deployer).grantRole(getEVALUATOR_ROLE, _evaluator.address);
            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(0, appointmentTime);
            let info = await _hardEvaluationContract.appointmentList(0); // check status turn accept 

            expect(info.status).to.equal(1); // 1 is ACCEPTED

            // -> Evaluator evaluated Asset

            balanceOfContractHardEvaluationBeforeTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);
            let balanceOfEvaluatorBeforeTXT = await _loanTokenContract.balanceOf(_evaluator.address);

            console.log("before TXT : ");
            console.log(balanceOfEvaluatorBeforeTXT.toString(), "balance of Evaluator Before TXT ");
            console.log(balanceOfContractHardEvaluationBeforeTXT.toString(), "balance of Contract HardEvaluation Before TXT ");

            await _hardEvaluationContract.connect(_evaluator).evaluatedAsset(_DFYHard721Contract.address,
                0, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 18), _loanTokenContract.address);

            let balanceOfEvalutorAfterTXT = await _loanTokenContract.balanceOf(_evaluator.address);
            balanceOfContractHardEvaluationAfterTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

            console.log("After TXT : ");
            console.log(balanceOfEvalutorAfterTXT.toString(), "balance of Evaluator After TXT ");
            console.log(balanceOfContractHardEvaluationAfterTXT.toString(), "balance of Contract HardEvaluation After TXT ");

            expect(balanceOfEvaluatorBeforeTXT).to.equal(BigInt(balanceOfEvalutorAfterTXT) - BigInt(_evaluationFee));
            expect(balanceOfContractHardEvaluationBeforeTXT).to.equal(BigInt(balanceOfContractHardEvaluationAfterTXT) + BigInt(_evaluationFee));

            // -> customer accept evaluation 

            balanceOfCustomerBeforeTXT = await _loanTokenContract.balanceOf(_customer.address);
            balanceOfContractHardEvaluationBeforeTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

            console.log("before TXT : ");
            console.log(balanceOfCustomerBeforeTXT.toString(), "balance of customer Before TXT ");
            console.log(balanceOfContractHardEvaluationBeforeTXT.toString(), "balance of Contract HardEvaluation Before TXT ");

            await _hardEvaluationContract.connect(_customer).acceptEvaluation(0);

            balanceOfCustomerAfterTXT = await _loanTokenContract.balanceOf(_customer.address);
            balanceOfContractHardEvaluationAfterTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

            console.log("After TXT : ");
            console.log(balanceOfCustomerAfterTXT.toString(), "balance of customer After TXT ");
            console.log(balanceOfContractHardEvaluationAfterTXT.toString(), "balance of Contract HardEvaluation After TXT ");

            expect(balanceOfCustomerBeforeTXT).to.equal(BigInt(balanceOfCustomerAfterTXT) + BigInt(_evaluationFee));
            expect(balanceOfContractHardEvaluationBeforeTXT).to.equal(BigInt(balanceOfContractHardEvaluationAfterTXT) - BigInt(_evaluationFee));

            // -> Evaluator mint NFT for Customer

            balanceOfContractHardEvaluationBeforeTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);
            let balanceOfHubFeeWalletBeforeTXt = await _loanTokenContract.balanceOf(_feeWallet.address);

            console.log("before TXT : ");

            console.log(balanceOfContractHardEvaluationBeforeTXT.toString(), "balance of Contract HardEvaluation Before TXT ");
            console.log(balanceOfHubFeeWalletBeforeTXt.toString(), "balance of hub fee wallet Before TXT ");

            await _hardEvaluationContract.connect(_evaluator).createNftToken(0, 1, "NFTCID");

            balanceOfContractHardEvaluationAfterTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);
            let balanceOfHubFeeWalletAfterTXt = await _loanTokenContract.balanceOf(_feeWallet.address);

            console.log("After TXT : ");
            console.log(balanceOfHubFeeWalletAfterTXt.toString(), "balance of hub fee wallet After TXT ");
            console.log(balanceOfContractHardEvaluationAfterTXT.toString(), "balance of Contract HardEvaluation After TXT ");

            let owner = await _DFYHard721Contract.ownerOf(0);

            expect(balanceOfHubFeeWalletBeforeTXt).to.equal(BigInt(balanceOfHubFeeWalletAfterTXt) - BigInt(_evaluationFee));
            expect(owner).to.equal(_customer.address);
        });


        it("case 2 : evalutor evaluated Asset", async () => {

            // -> customer create asset request
            await _hardEvaluationContract.connect(_customer).createAssetRequest(_assetCID, _DFYHard721Contract.address, 0); // create Asset request 
            let assetList = await _hardEvaluationContract.assetList(1);

            expect(assetList.assetCID).to.equal(_assetCID);
            expect(assetList.owner).to.equal(_customer.address);
            expect(assetList.collectionAddress).to.equal(_DFYHard721Contract.address);
            expect(assetList.collectionStandard).to.equal(0);
            expect(assetList.status).to.equal(0);

            // -> customer create Appointment 

            let balanceOfCustomerBeforeTXT = await _loanTokenContract.balanceOf(_customer.address);
            let balanceOfContractHardEvaluationBeforeTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

            console.log("before TXT : ");
            console.log(balanceOfCustomerBeforeTXT.toString(), "balance of Borrower Before TXT ");
            console.log(balanceOfContractHardEvaluationBeforeTXT.toString(), "balance of Contract HardEvaluation Before TXT ");

            await _hardEvaluationContract.connect(_customer).createAppointment(1, _evaluator.address, _loanTokenContract.address, appointmentTime);

            let appointmentList = await _hardEvaluationContract.appointmentList(1); // check info after create 
            expect(appointmentList.assetId).to.equal(1);
            expect(appointmentList.assetOwner).to.equal(_customer.address);
            expect(appointmentList.evaluator).to.equal(_evaluator.address);
            expect(appointmentList.evaluationFee).to.equal(_evaluationFee);
            expect(appointmentList.evaluationFeeAddress).to.equal(_loanTokenContract.address);

            let getIdAppointmentListOfAsset = await _hardEvaluationContract.appointmentListOfAsset(1, 0); // get appointmentId from list asset 
            await _hardEvaluationContract.assetList(getIdAppointmentListOfAsset); // query AssetList with appointmentId
            assetList = await _hardEvaluationContract.assetList(1);

            expect(assetList.status).to.equal(1); // check status asset

            let balanceOfCustomerAfterTXT = await _loanTokenContract.balanceOf(_customer.address); // check transfer 
            let balanceOfContractHardEvaluationAfterTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

            console.log("After TXT : ");
            console.log(balanceOfCustomerAfterTXT.toString(), "balance of Borrower After TXT ");
            console.log(balanceOfContractHardEvaluationAfterTXT.toString(), "balance of Contract HardEvaluation After TXT ");

            expect(balanceOfCustomerBeforeTXT).to.equal(BigInt(balanceOfCustomerAfterTXT) + BigInt(_evaluationFee));
            expect(balanceOfContractHardEvaluationBeforeTXT).to.equal(BigInt(balanceOfContractHardEvaluationAfterTXT) - BigInt(_evaluationFee));

            // -> Evaluator accept Appoitment

            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(1, appointmentTime);
            let info = await _hardEvaluationContract.appointmentList(1); // check status turn accept 

            expect(info.status).to.equal(1); // 1 is ACCEPTED

            // -> Evaluator evaluated Asset

            balanceOfContractHardEvaluationBeforeTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);
            let balanceOfEvaluatorBeforeTXT = await _loanTokenContract.balanceOf(_evaluator.address);

            console.log("before TXT : ");
            console.log(balanceOfEvaluatorBeforeTXT.toString(), "balance of Evaluator Before TXT ");
            console.log(balanceOfContractHardEvaluationBeforeTXT.toString(), "balance of Contract HardEvaluation Before TXT ");

            await _hardEvaluationContract.connect(_evaluator).evaluatedAsset(_DFYHard721Contract.address,
                1, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 18), _loanTokenContract.address);

            let balanceOfEvalutorAfterTXT = await _loanTokenContract.balanceOf(_evaluator.address);
            balanceOfContractHardEvaluationAfterTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

            console.log("After TXT : ");
            console.log(balanceOfEvalutorAfterTXT.toString(), "balance of Evaluator After TXT ");
            console.log(balanceOfContractHardEvaluationAfterTXT.toString(), "balance of Contract HardEvaluation After TXT ");

            expect(balanceOfEvaluatorBeforeTXT).to.equal(BigInt(balanceOfEvalutorAfterTXT) - BigInt(_evaluationFee));
            expect(balanceOfContractHardEvaluationBeforeTXT).to.equal(BigInt(balanceOfContractHardEvaluationAfterTXT) + BigInt(_evaluationFee));

        });

        it("case 3 : customer reject Evaluation  : ", async () => {

            // -> customer create asset request
            await _hardEvaluationContract.connect(_customer).createAssetRequest(_assetCID, _DFYHard721Contract.address, 0); // create Asset request 
            let assetList = await _hardEvaluationContract.assetList(2);

            expect(assetList.assetCID).to.equal(_assetCID);
            expect(assetList.owner).to.equal(_customer.address);
            expect(assetList.collectionAddress).to.equal(_DFYHard721Contract.address);
            expect(assetList.collectionStandard).to.equal(0);
            expect(assetList.status).to.equal(0);

            // -> customer create Appointment 

            let balanceOfCustomerBeforeTXT = await _loanTokenContract.balanceOf(_customer.address);
            let balanceOfContractHardEvaluationBeforeTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

            console.log("before TXT : ");
            console.log(balanceOfCustomerBeforeTXT.toString(), "balance of Borrower Before TXT ");
            console.log(balanceOfContractHardEvaluationBeforeTXT.toString(), "balance of Contract HardEvaluation Before TXT ");

            await _hardEvaluationContract.connect(_customer).createAppointment(2, _evaluator.address, _loanTokenContract.address, appointmentTime);

            let appointmentList = await _hardEvaluationContract.appointmentList(2); // check info after create 
            expect(appointmentList.assetId).to.equal(2);
            expect(appointmentList.assetOwner).to.equal(_customer.address);
            expect(appointmentList.evaluator).to.equal(_evaluator.address);
            expect(appointmentList.evaluationFee).to.equal(_evaluationFee);
            expect(appointmentList.evaluationFeeAddress).to.equal(_loanTokenContract.address);

            let getIdAppointmentListOfAsset = await _hardEvaluationContract.appointmentListOfAsset(2, 0); // get appointmentId from list asset 
            await _hardEvaluationContract.assetList(getIdAppointmentListOfAsset); // query AssetList with appointmentId
            assetList = await _hardEvaluationContract.assetList(2);

            expect(assetList.status).to.equal(1); // check status asset

            let balanceOfCustomerAfterTXT = await _loanTokenContract.balanceOf(_customer.address); // check transfer 
            let balanceOfContractHardEvaluationAfterTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

            console.log("After TXT : ");
            console.log(balanceOfCustomerAfterTXT.toString(), "balance of Borrower After TXT ");
            console.log(balanceOfContractHardEvaluationAfterTXT.toString(), "balance of Contract HardEvaluation After TXT ");

            expect(balanceOfCustomerBeforeTXT).to.equal(BigInt(balanceOfCustomerAfterTXT) + BigInt(_evaluationFee));
            expect(balanceOfContractHardEvaluationBeforeTXT).to.equal(BigInt(balanceOfContractHardEvaluationAfterTXT) - BigInt(_evaluationFee));

            // -> Evaluator accept Appoitment

            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(2, appointmentTime);
            let info = await _hardEvaluationContract.appointmentList(2); // check status turn accept 

            expect(info.status).to.equal(1); // 1 is ACCEPTED

            // -> Evaluator evaluated Asset

            balanceOfContractHardEvaluationBeforeTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);
            let balanceOfEvaluatorBeforeTXT = await _loanTokenContract.balanceOf(_evaluator.address);

            console.log("before TXT : ");
            console.log(balanceOfEvaluatorBeforeTXT.toString(), "balance of Evaluator Before TXT ");
            console.log(balanceOfContractHardEvaluationBeforeTXT.toString(), "balance of Contract HardEvaluation Before TXT ");

            await _hardEvaluationContract.connect(_evaluator).evaluatedAsset(_DFYHard721Contract.address,
                2, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 18), _loanTokenContract.address);

            let balanceOfEvalutorAfterTXT = await _loanTokenContract.balanceOf(_evaluator.address);
            balanceOfContractHardEvaluationAfterTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

            console.log("After TXT : ");
            console.log(balanceOfEvalutorAfterTXT.toString(), "balance of Evaluator After TXT ");
            console.log(balanceOfContractHardEvaluationAfterTXT.toString(), "balance of Contract HardEvaluation After TXT ");

            expect(balanceOfEvaluatorBeforeTXT).to.equal(BigInt(balanceOfEvalutorAfterTXT) - BigInt(_evaluationFee));
            expect(balanceOfContractHardEvaluationBeforeTXT).to.equal(BigInt(balanceOfContractHardEvaluationAfterTXT) + BigInt(_evaluationFee));

            // -> customer reject Evaluation 
            await _hardEvaluationContract.connect(_customer).rejectEvaluation(2, "rẻ quá không đồng ý");

            let infoEvaluation = await _hardEvaluationContract.evaluationList(2);
            let infoAsset = await _hardEvaluationContract.assetList(2);
            expect(infoEvaluation.status).to.equal(2);
            expect(infoAsset.status).to.equal(0);
        });


        it("Case 4 :  Evaluator reject Appoitment ", async () => {


            // -> customer create asset request
            await _hardEvaluationContract.connect(_customer).createAssetRequest(_assetCID, _DFYHard721Contract.address, 0); // create Asset request 
            let assetList = await _hardEvaluationContract.assetList(3);

            expect(assetList.assetCID).to.equal(_assetCID);
            expect(assetList.owner).to.equal(_customer.address);
            expect(assetList.collectionAddress).to.equal(_DFYHard721Contract.address);
            expect(assetList.collectionStandard).to.equal(0);
            expect(assetList.status).to.equal(0);

            // -> customer create Appointment 

            let balanceOfCustomerBeforeTXT = await _loanTokenContract.balanceOf(_customer.address);
            let balanceOfContractHardEvaluationBeforeTXT = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

            console.log("before TXT : ");
            console.log(balanceOfCustomerBeforeTXT.toString(), "balance of customer Before TXT ");
            console.log(balanceOfContractHardEvaluationBeforeTXT.toString(), "balance of Contract HardEvaluation Before TXT ");

            await _hardEvaluationContract.connect(_customer).createAppointment(3, _evaluator.address, _loanTokenContract.address, appointmentTime);

            let appointmentList = await _hardEvaluationContract.appointmentList(3); // check info after create 
            expect(appointmentList.assetId).to.equal(3);
            expect(appointmentList.assetOwner).to.equal(_customer.address);
            expect(appointmentList.evaluator).to.equal(_evaluator.address);
            expect(appointmentList.evaluationFee).to.equal(_evaluationFee);
            expect(appointmentList.evaluationFeeAddress).to.equal(_loanTokenContract.address);

            let getIdAppointmentListOfAsset = await _hardEvaluationContract.appointmentListOfAsset(3, 0); // get appointmentId from list asset 
            await _hardEvaluationContract.assetList(getIdAppointmentListOfAsset); // query AssetList with appointmentId
            assetList = await _hardEvaluationContract.assetList(3);

            expect(assetList.status).to.equal(1); // check status asset

            let balanceOfCustomerAfterCreateAppoitment = await _loanTokenContract.balanceOf(_customer.address); // check transfer 
            let balanceOfContractHardEvaluationAfterCreateAppoitment = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

            console.log("After TXT : ");
            console.log(balanceOfCustomerAfterCreateAppoitment.toString(), "balance of customer After create Appoitment ");
            console.log(balanceOfContractHardEvaluationAfterCreateAppoitment.toString(), "balance of Contract HardEvaluation After Appoitment ");

            expect(balanceOfCustomerBeforeTXT).to.equal(BigInt(balanceOfCustomerAfterCreateAppoitment) + BigInt(_evaluationFee));
            expect(balanceOfContractHardEvaluationBeforeTXT).to.equal(BigInt(balanceOfContractHardEvaluationAfterCreateAppoitment) - BigInt(_evaluationFee));

            // -> Evaluator reject Appoitment
            _hardEvaluationContract.connect(_evaluator).rejectAppointment(3, "không thích cho mi tạo Appointment đấy");

            let infoAppointment = await _hardEvaluationContract.appointmentList(3);
            expect(infoAppointment.status).to.equal(0); // 0 is open -> reject -> open 

            balanceOfCustomerAfterRejectAppoitment = await _loanTokenContract.balanceOf(_customer.address);
            balanceOfContractHardEvaluationAfterRejectAppoitment = await _loanTokenContract.balanceOf(_hardEvaluationContract.address);

            expect(balanceOfCustomerAfterCreateAppoitment).to.equal(BigInt(balanceOfCustomerAfterRejectAppoitment) - BigInt(_evaluationFee));
            expect(balanceOfContractHardEvaluationAfterCreateAppoitment).to.equal(BigInt(balanceOfContractHardEvaluationAfterRejectAppoitment) + BigInt(_evaluationFee));

        });
    });
});