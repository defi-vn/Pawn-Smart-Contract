const hre = require("hardhat");
const artifactDFYHard721 = "DFYHard721";
const artifactLoanToken = "LoanToken";
const artifactHub = "Hub";
const artifactHardEvaluation = "HardEvaluation";
const { expect, assert } = require("chai");
const decimal = 10 ** 18;


describe("Setting up test parameters:\n\r", (done) => {

    let _DFYHard721Contract = null;
    let _loanTokenContract = null;
    let _hubContract = null;
    let _hardEvaluationContract = null;
    let _evaluationFee = BigInt(10 * 10 ** 18);
    let _mintingFee = BigInt(15 * 10 ** 18);
    let _assetCID = "Example";
    let _tokenName = "DFYHard721NFT";
    let _symbol = "DFY";
    let _collectionCID = "EXAMPLE";
    // let _defaultRoyaltyRate = BigInt(10 * 10 ** 5);
    let _defaultRoyaltyRate = 0;
    let appointmentTime = Math.floor(Date.now() / 1000) + 300;

    let evaluationFee = Number(_evaluationFee)/decimal;
    let mintingFee = Number(_mintingFee)/decimal;

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

        console.log(`Hub address: \x1b[31m${_hubContract.address}\x1b[0m`);
        console.log(`Evaluation contract: \x1b[36m${_hardEvaluationContract.address}\x1b[0m`);
        console.log(`DFY Hard NFT-721: \x1b[36m${_DFYHard721Contract.address}\x1b[0m`);
        console.log(`Loan asset: \x1b[36m${_loanTokenContract.address}\x1b[0m`);
        console.log(`Evaluation fee: \x1b[36m${evaluationFee}\x1b[0m`);
        console.log(`Minting fee: \x1b[36m${Number(_mintingFee)/decimal}\x1b[0m\n\r`);
    });

    describe("Unit test Hard NFT & Evaluation", async () => {

        it(`Case 1: Evaluator create NFT for customer\n\r`, async () => {

            // -> customer create asset request
            await _hubContract.connect(_deployer).setEvaluationConfig(_loanTokenContract.address, _evaluationFee, _mintingFee); // addWhiteListFee -> add address token to pay for evaluation fee , mint nft fee 
            await _hardEvaluationContract.connect(_customer).createAssetRequest(_assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18), _loanTokenContract.address, 0); // create Asset request 
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

            let balanceOfCustomerBeforeTnx = (await _loanTokenContract.balanceOf(_customer.address))/decimal;
            let balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Create appointment - before transaction: ");
            console.log(`Customer balance: ${balanceOfCustomerBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

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

            let balanceOfCustomerAfterTnx = (await _loanTokenContract.balanceOf(_customer.address))/decimal; // check transfer 
            let balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Create appointment - after transaction:");
            console.log(`Customer balance: ${balanceOfCustomerAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            expect(balanceOfCustomerBeforeTnx).to.equal(balanceOfCustomerAfterTnx + evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx - evaluationFee);

            // -> Evaluator accept Appoitment

            let getEVALUATOR_ROLE = await _hubContract.EvaluatorRole();  // grant evaluator roll 
            await _hubContract.connect(_deployer).grantRole(getEVALUATOR_ROLE, _evaluator.address);
            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(0, appointmentTime);
            let info = await _hardEvaluationContract.appointmentList(0); // check status turn accept 

            expect(info.status).to.equal(1); // 1 is ACCEPTED

            // -> Evaluator evaluated Asset

            balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;
            let balanceOfEvaluatorBeforeTnx = (await _loanTokenContract.balanceOf(_evaluator.address))/decimal;

            console.log("Evaluation - before transaction:");
            console.log(`Evaluator balance: ${balanceOfEvaluatorBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

            await _hardEvaluationContract.connect(_evaluator).evaluatedAsset(_DFYHard721Contract.address,
                0, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address);

            let balanceOfEvaluatorAfterTnx = (await _loanTokenContract.balanceOf(_evaluator.address))/decimal;
            balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Evaluation - after transaction:");
            console.log(`Evaluator balance: ${balanceOfEvaluatorAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            expect(balanceOfEvaluatorBeforeTnx).to.equal(balanceOfEvaluatorAfterTnx - evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx + evaluationFee);

            // -> customer accept evaluation 

            balanceOfCustomerBeforeTnx = (await _loanTokenContract.balanceOf(_customer.address))/decimal;
            balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Accept evaluation - before transaction:");
            console.log(`Customer balance: ${balanceOfCustomerBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

            await _hardEvaluationContract.connect(_customer).acceptEvaluation(0);

            balanceOfCustomerAfterTnx = (await _loanTokenContract.balanceOf(_customer.address))/decimal;
            balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Accept evaluation - after transaction:");
            console.log(`Customer balance: ${balanceOfCustomerAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            expect(balanceOfCustomerBeforeTnx).to.equal(balanceOfCustomerAfterTnx + mintingFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx - mintingFee);

            // -> Evaluator mint NFT for Customer

            let balanceOfHubFeeWalletBeforeTnx = (await _loanTokenContract.balanceOf(_feeWallet.address))/decimal;
            balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Mint NFT - before transaction:");
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}`);
            console.log(`Fee Wallet balance: ${balanceOfHubFeeWalletBeforeTnx.toString()}\n\r`);

            await _hardEvaluationContract.connect(_evaluator).createNftToken(0, 1, "NFTCID");

            let balanceOfHubFeeWalletAfterTnx = (await _loanTokenContract.balanceOf(_feeWallet.address))/decimal;
            balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Mint NFT - after transaction:");
            console.log(`Fee Wallet balance: ${balanceOfHubFeeWalletAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            let owner = await _DFYHard721Contract.ownerOf(0);

            expect(balanceOfHubFeeWalletBeforeTnx).to.equal(balanceOfHubFeeWalletAfterTnx - mintingFee);
            expect(owner).to.equal(_customer.address);
        });

        it("Case 2: Evaluator evaluated Asset\n\r", async () => {

            // -> customer create asset request
            await _hardEvaluationContract.connect(_customer).createAssetRequest(_assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18), _loanTokenContract.address, 0); // create Asset request 
            let assetList = await _hardEvaluationContract.assetList(1);

            expect(assetList.assetCID).to.equal(_assetCID);
            expect(assetList.owner).to.equal(_customer.address);
            expect(assetList.collectionAddress).to.equal(_DFYHard721Contract.address);
            expect(assetList.collectionStandard).to.equal(0);
            expect(assetList.status).to.equal(0);

            // -> customer create Appointment 

            let balanceOfCustomerBeforeTnx = (await _loanTokenContract.balanceOf(_customer.address))/decimal;
            let balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Create appointment - Before transaction:");
            console.log(`Customer balance: ${balanceOfCustomerBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

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

            let balanceOfCustomerAfterTnx = (await _loanTokenContract.balanceOf(_customer.address))/decimal; // check transfer 
            let balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Create appointment - after transaction:");
            console.log(`Customer balance after transaction: ${balanceOfCustomerAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            expect(balanceOfCustomerBeforeTnx).to.equal(balanceOfCustomerAfterTnx + evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx - evaluationFee);

            // -> Evaluator accept Appoitment

            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(1, appointmentTime);
            let info = await _hardEvaluationContract.appointmentList(1); // check status turn accept 

            expect(info.status).to.equal(1); // 1 is ACCEPTED

            // -> Evaluator evaluated Asset

            let balanceOfEvaluatorBeforeTnx = (await _loanTokenContract.balanceOf(_evaluator.address))/decimal;
            balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Evaluation - before transaction:");
            console.log(`Evaluator balance: ${balanceOfEvaluatorBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

            await _hardEvaluationContract.connect(_evaluator).evaluatedAsset(_DFYHard721Contract.address,
                1, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address);

            let balanceOfEvalutorAfterTnx = (await _loanTokenContract.balanceOf(_evaluator.address))/decimal;
            balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Evaluation - after transaction:");
            console.log(`Evaluator balance: ${balanceOfEvalutorAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            expect(balanceOfEvaluatorBeforeTnx).to.equal(balanceOfEvalutorAfterTnx - evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx + evaluationFee);

        });

        it("Case 3: Customer reject Evaluation\n\r", async () => {

            // -> customer create asset request
            await _hardEvaluationContract.connect(_customer).createAssetRequest(_assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18), _loanTokenContract.address, 0); // create Asset request 
            let assetList = await _hardEvaluationContract.assetList(2);

            expect(assetList.assetCID).to.equal(_assetCID);
            expect(assetList.owner).to.equal(_customer.address);
            expect(assetList.collectionAddress).to.equal(_DFYHard721Contract.address);
            expect(assetList.collectionStandard).to.equal(0);
            expect(assetList.status).to.equal(0);

            // -> customer create Appointment 

            let balanceOfCustomerBeforeTnx = (await _loanTokenContract.balanceOf(_customer.address))/decimal;
            let balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Create appointment - before transaction:");
            console.log(`Customer balance: ${balanceOfCustomerBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

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

            let balanceOfCustomerAfterTnx = (await _loanTokenContract.balanceOf(_customer.address))/decimal; // check transfer 
            let balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Create appointment - after transaction:");
            console.log(`Customer balance: ${balanceOfCustomerAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            expect(balanceOfCustomerBeforeTnx).to.equal(balanceOfCustomerAfterTnx + evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx - evaluationFee);

            // -> Evaluator accept Appoitment

            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(2, appointmentTime);
            let info = await _hardEvaluationContract.appointmentList(2); // check status turn accept 

            expect(info.status).to.equal(1); // 1 is ACCEPTED

            // -> Evaluator evaluated Asset

            let balanceOfEvaluatorBeforeTnx = (await _loanTokenContract.balanceOf(_evaluator.address))/decimal;
            balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Evaluation - before transaction:");
            console.log(`Evaluator balance: ${balanceOfEvaluatorBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

            await _hardEvaluationContract.connect(_evaluator).evaluatedAsset(_DFYHard721Contract.address,
                2, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address);

            let balanceOfEvaluatorAfterTnx = (await _loanTokenContract.balanceOf(_evaluator.address))/decimal;
            balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Evaluation - after transaction:");
            console.log(`Evaluator balance: ${balanceOfEvaluatorAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            expect(balanceOfEvaluatorBeforeTnx).to.equal(balanceOfEvaluatorAfterTnx - evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx + evaluationFee);

            // -> customer reject Evaluation 
            await _hardEvaluationContract.connect(_customer).rejectEvaluation(2, "rẻ quá không đồng ý");

            let infoEvaluation = await _hardEvaluationContract.evaluationList(2);
            let infoAsset = await _hardEvaluationContract.assetList(2);
            expect(infoEvaluation.status).to.equal(2);
            expect(infoAsset.status).to.equal(0);
        });

        it("Case 4: Evaluator reject Appoitment\n\r", async () => {

            // -> customer create asset request
            await _hardEvaluationContract.connect(_customer).createAssetRequest(_assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18), _loanTokenContract.address, 0); // create Asset request 
            let assetList = await _hardEvaluationContract.assetList(3);

            expect(assetList.assetCID).to.equal(_assetCID);
            expect(assetList.owner).to.equal(_customer.address);
            expect(assetList.collectionAddress).to.equal(_DFYHard721Contract.address);
            expect(assetList.collectionStandard).to.equal(0);
            expect(assetList.status).to.equal(0);

            // -> customer create Appointment 

            let balanceOfCustomerBeforeTnx = (await _loanTokenContract.balanceOf(_customer.address))/decimal;
            let balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Create appointment - before transaction:");
            console.log(`Customer balance: ${balanceOfCustomerBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

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

            let balanceOfCustomerAfterTnx = (await _loanTokenContract.balanceOf(_customer.address))/decimal; // check transfer 
            let balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            console.log("Create appointment - after transaction:");
            console.log(`Customer balance: ${balanceOfCustomerAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            expect(balanceOfCustomerBeforeTnx).to.equal(balanceOfCustomerAfterTnx + evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx - evaluationFee);

            // -> Evaluator reject Appoitment
            _hardEvaluationContract.connect(_evaluator).rejectAppointment(3, "không thích cho mi tạo Appointment đấy");

            let infoAppointment = await _hardEvaluationContract.appointmentList(3);
            expect(infoAppointment.status).to.equal(0); // 0 is open -> reject -> open 

            let balanceOfCustomerAfterRejectAppoitment = (await _loanTokenContract.balanceOf(_customer.address))/decimal;
            let balanceOfContractHardEvaluationAfterRejectAppoitment = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address))/decimal;

            expect(balanceOfCustomerAfterTnx).to.equal(balanceOfCustomerAfterRejectAppoitment - evaluationFee);
            expect(balanceOfContractHardEvaluationAfterTnx).to.equal(balanceOfContractHardEvaluationAfterRejectAppoitment + evaluationFee);

        });
    });
});