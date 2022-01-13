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
    let _beAssetId = "EXAMPLE";
    let _beEvaluationId = "EXAMPLE";
    // let _defaultRoyaltyRate = BigInt(10 * 10 ** 5);
    let _defaultRoyaltyRate = 0;
    let appointmentTime = Math.floor(Date.now() / 1000) + 300;

    let evaluationFee = Number(_evaluationFee) / decimal;
    let mintingFee = Number(_mintingFee) / decimal;

    const AssetStatus = {
        OPEN: 0,
        APPOINTED: 1,
        EVALUATED: 2,
        NFT_CREATED: 3
    }
    const EvaluationStatus = {
        EVALUATED: 0,
        EVALUATION_ACCEPTED: 1,
        EVALUATION_REJECTED: 2,
        NFT_CREATED: 3
    }
    const CollectionStandard = {
        NFT_HARD_721: 0,
        NFT_HARD_1155: 1
    }
    const AppointmentStatus = {
        OPEN: 0,
        ACCEPTED: 1,
        REJECTED: 2,
        CANCELLED: 3,
        EVALUATED: 4
    }
    const EvaluatorStatus = {
        ACCEPTED: 0,
        CANCELLED: 1
    }

    const NFTOfBorrower = {
        FIRSTNFT: 0,
        SECONDNFT: 1,
        THIRDNFT: 2,
        FOURNFT: 3,
        FIVENFT: 4
    };
    const ListAssetRequest = {
        FIRSTID: 0,
        SECONDID: 1,
        THIRDID: 2,
        FOURDID: 3,
        FIVEID: 4,
        SIXID: 5
    };
    const ListAppointment = {
        FIRSTID: 0,
        SECONDID: 1,
        THIRDID: 2,
        FOURDID: 3,
        FIVEID: 4,
        SIXID: 5,
        SEVENTID: 6,
        EIGHTID: 7
    };
    const EvaluatorList = {
        EVALUATORA: 0,
        EVALUATORB: 1,
        EVALUATORC: 2,
        EVALUATORD: 3
    };
    const EvaluationList = {
        FIRSTID: 0,
        SECONDID: 1,
        THIRDID: 2,
        FOURDID: 3,
        FIVEID: 4,
        SIXID: 5
    };


    before(async () => {
        [
            _deployer,
            _customer,
            _evaluator,
            _evaluatorB,
            _evaluatorC,
            _evaluatorD,
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
        let hardEvaluationSignature = await _hardEvaluationContract.signature();
        await _hubContract.registerContract(hardEvaluationSignature, _hardEvaluationContract.address, artifactHardEvaluation);
        let getOperatorRole = await _hubContract.OperatorRole();
        await _hubContract.connect(_deployer).grantRole(getOperatorRole, _hardEvaluationContract.address);
        let checkRole = await _hubContract.hasRole(getOperatorRole, _hardEvaluationContract.address);
        expect(checkRole).to.equal(true);


        // DFYHard721 
        const DFYHard721Factory = await hre.ethers.getContractFactory(artifactDFYHard721);
        const DFYHard721Contract = await DFYHard721Factory.deploy(
            _tokenName,
            _symbol,
            _deployer.address,
            _collectionCID,
            _hubContract.address,
            _hardEvaluationContract.address,
        );
        _DFYHard721Contract = await DFYHard721Contract.deployed();

        console.log(`Hub address: \x1b[31m${_hubContract.address}\x1b[0m`);
        console.log(`DFY Hard NFT-721: \x1b[36m${_DFYHard721Contract.address}\x1b[0m`);
        console.log(`Loan asset: \x1b[36m${_loanTokenContract.address}\x1b[0m`);

        console.log(`Hub address: \x1b[31m${_hubContract.address}\x1b[0m`);
        console.log(`Evaluation contract: \x1b[36m${_hardEvaluationContract.address}\x1b[0m`);
        console.log(`DFY Hard NFT-721: \x1b[36m${_DFYHard721Contract.address}\x1b[0m`);
        console.log(`Loan asset: \x1b[36m${_loanTokenContract.address}\x1b[0m`);
        console.log(`Evaluation fee: \x1b[36m${evaluationFee}\x1b[0m`);
        console.log(`Minting fee: \x1b[36m${Number(_mintingFee) / decimal}\x1b[0m\n\r`);
    });

    describe("Unit test Hard NFT & Evaluation", async () => {

        it("Case 1: Accept Evaluator and Remove Evaluator \n\r", async () => {

            // có thể cấp quyền evaluatorRole cho evaluator ở hub hoặc thực hiện acceptEvaluator ở hard evaluation
            // set evaluator role in hub 
            // let getEVALUATOR_ROLE = await _hubContract.EvaluatorRole();  // grant evaluator roll 
            // await _hubContract.connect(_deployer).grantRole(getEVALUATOR_ROLE, _evaluator.address);
            // let checkEvaluatorRole = await _hubContract.hasRole(getEVALUATOR_ROLE, _evaluator.address);
            // expect(checkEvaluatorRole).to.equals(true);

            // accept evaluator 
            let getEventAcceptEvaluator = await _hardEvaluationContract.connect(_deployer).acceptEvaluator(EvaluatorList.EVALUATORA, _evaluator.address);
            let reciptEvenAcceptEvaluator = await getEventAcceptEvaluator.wait();
            await _hardEvaluationContract.acceptEvaluator(EvaluatorList.EVALUATORB, _evaluatorB.address);
            await _hardEvaluationContract.acceptEvaluator(EvaluatorList.EVALUATORC, _evaluatorC.address);
            await _hardEvaluationContract.acceptEvaluator(EvaluatorList.EVALUATORD, _evaluatorD.address);

            let getEvaluatorRole = await _hubContract.EvaluatorRole();
            let checkEvaluatorRoleOfEvaluator = await _hubContract.hasRole(getEvaluatorRole, _evaluator.address);
            let checkEvaluatorRoleOfEvaluatorB = await _hubContract.hasRole(getEvaluatorRole, _evaluatorB.address);
            let checkEvaluatorRoleOfEvaluatorC = await _hubContract.hasRole(getEvaluatorRole, _evaluatorC.address);
            let checkEvaluatorRoleOfEvaluatorD = await _hubContract.hasRole(getEvaluatorRole, _evaluatorD.address);

            console.log(`\x1b[31m event AcceptEvaluator :\x1b[0m`);
            console.log(reciptEvenAcceptEvaluator.events[1]);

            expect(checkEvaluatorRoleOfEvaluator).to.equal(true);
            expect(checkEvaluatorRoleOfEvaluatorB).to.equal(true);
            expect(checkEvaluatorRoleOfEvaluatorC).to.equal(true);
            expect(checkEvaluatorRoleOfEvaluatorD).to.equal(true);
            expect(reciptEvenAcceptEvaluator.events[1].args[2]).to.equal(EvaluatorStatus.ACCEPTED);

            // remove Evaluator 
            let getEventRemoveEvaluator = await _hardEvaluationContract.removeEvaluator(EvaluatorList.EVALUATORD, _evaluatorD.address);
            let reciptEventRemoveEvaluator = await getEventRemoveEvaluator.wait();

            checkEvaluatorRoleOfEvaluatorD = await _hubContract.hasRole(getEvaluatorRole, _evaluatorD.address);
            expect(checkEvaluatorRoleOfEvaluatorD).to.equal(false);

            console.log(`\x1b[31m event remove Evaluator :\x1b[0m`);
            console.log(reciptEventRemoveEvaluator.events[1]);

            expect(reciptEventRemoveEvaluator.events[1].args[2]).to.equal(EvaluatorStatus.CANCELLED);
        });

        it(`Case 2: Evaluator create NFT for customer\n\r`, async () => {

            // -> customer create asset request
            await _hubContract.connect(_deployer).setEvaluationConfig(_feeWallet.address, _loanTokenContract.address, _evaluationFee, _mintingFee); // addWhiteListFee -> add address token to pay for evaluation fee , mint nft fee 
            let getEventCreateAssetRequest = await _hardEvaluationContract.connect(_customer).createAssetRequest(
                _assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
                _loanTokenContract.address, 0, _beAssetId); // create Asset request 
            let assetList = await _hardEvaluationContract.assetList(0);

            console.log(`\x1b[31m Event customer created AssetRequest \x1b[0m`);
            let recipt = await getEventCreateAssetRequest.wait();
            console.log(`assetId : \x1b[36m ${recipt.events[0].args[0].toString()} \x1b[0m`);
            console.log("assetList :", recipt.events[0].args[1])
            console.log(`beAssetId : \x1b[36m ${recipt.events[0].args[2].toString()} \x1b[0m`);

            expect(assetList.assetCID).to.equal(_assetCID);
            expect(assetList.owner).to.equal(_customer.address);
            expect(assetList.collectionAddress).to.equal(_DFYHard721Contract.address);
            expect(assetList.collectionStandard).to.equal(CollectionStandard.NFT_HARD_721);
            expect(assetList.status).to.equal(AssetStatus.OPEN);

            // -> customer create Appointment 
            await _loanTokenContract.setOperator(_deployer.address, true); // loan token transfer for customer and approve
            await _loanTokenContract.mint(_deployer.address, BigInt(100 * 10 ** 18));
            await _loanTokenContract.connect(_deployer).transfer(_customer.address, BigInt(100 * 10 ** 18));
            await _loanTokenContract.connect(_customer).approve(_hardEvaluationContract.address, BigInt(100000 * 10 ** 18));

            let balanceOfCustomerBeforeCreateAppointment = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            let balanceOfContractHardEvaluationBeforeCreateAppoitment = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - before transaction: ");
            console.log(`\x1b[36m customer balance : ${balanceOfCustomerBeforeCreateAppointment.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeCreateAppoitment.toString()} \x1b[0m`);

            let getEventCreateAppointment = await _hardEvaluationContract.connect(_customer).createAppointment(ListAppointment.FIRSTID, _evaluator.address, _loanTokenContract.address, appointmentTime);
            let reciptEventCreateAppointment = await getEventCreateAppointment.wait();

            console.log(`\x1b[31m Event customer create Appointment \x1b[0m`);
            console.log(`appointmentId : \x1b[36m ${reciptEventCreateAppointment.events[2].args[0].toString()} \x1b[0m`);
            console.log("asset", reciptEventCreateAppointment.events[2].args[1]);
            console.log("appointmentList", reciptEventCreateAppointment.events[2].args[2]);
            console.log(`"" \x1b[36m ${reciptEventCreateAppointment.events[2].args[3].toString()} \x1b[0m`);
            console.log(`appointmentTime : \x1b[36m ${reciptEventCreateAppointment.events[2].args[4].toString()} \x1b[0m`);

            console.log(`\x1b[31m Event transfer token of customer into this contract \x1b[0m`);
            console.log(reciptEventCreateAppointment.events[0]);

            let appointmentList = await _hardEvaluationContract.appointmentList(ListAppointment.FIRSTID); // check info after create appointment  
            expect(appointmentList.assetId).to.equal(ListAppointment.FIRSTID);
            expect(appointmentList.assetOwner).to.equal(_customer.address);
            expect(appointmentList.evaluator).to.equal(_evaluator.address);
            expect(appointmentList.evaluationFee).to.equal(_evaluationFee);
            expect(appointmentList.evaluationFeeAddress).to.equal(_loanTokenContract.address);
            expect(reciptEventCreateAppointment.events[2].args[2].status).to.equal(AppointmentStatus.OPEN);

            let balanceOfCustomerAfterCreateAppoitnment = (await _loanTokenContract.balanceOf(_customer.address)) / decimal; // check transfer 
            let balanceOfContractHardEvaluationAfterCreateAppointment = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - after transaction:");
            console.log(`\x1b[36m customer balance : ${balanceOfCustomerAfterCreateAppoitnment.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterCreateAppointment.toString()} \x1b[0m`);

            expect(balanceOfCustomerBeforeCreateAppointment).to.equal(balanceOfCustomerAfterCreateAppoitnment + evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeCreateAppoitment).to.equal(balanceOfContractHardEvaluationAfterCreateAppointment - evaluationFee);

            // -> Evaluator accept Appointment
            let getEventAcceptAppointment = await _hardEvaluationContract.connect(_evaluator).acceptAppointment(ListAppointment.FIRSTID, appointmentTime);
            let reciptEventAcceptAppointment = await getEventAcceptAppointment.wait();

            console.log(`\x1b[31m Event Evaluator accept Appointment \x1b[0m`);
            console.log(`thisAppointmentId : \x1b[36m ${reciptEventAcceptAppointment.events[0].args[0].toString()} \x1b[0m`);
            console.log("assetList", reciptEventAcceptAppointment.events[0].args[1]);
            console.log("thisAppointment", reciptEventAcceptAppointment.events[0].args[2]);
            console.log(`unknow : \x1b[36m ${reciptEventAcceptAppointment.events[0].args[3].toString()} \x1b[0m`);
            console.log(`appointmentTime : \x1b[36m ${reciptEventAcceptAppointment.events[0].args[4].toString()} \x1b[0m`);

            console.log(`\x1b[31m check appointment List Of Asset after evaluator accept an appointment \x1b[0m`);
            let assetId = await reciptEventAcceptAppointment.events[0].args[2].assetId.toString();
            let appointmentId = await reciptEventAcceptAppointment.events[0].args[0].toString();
            let appointmentListOfAsset = await _hardEvaluationContract.appointmentListOfAsset(assetId, appointmentId);
            console.log(appointmentListOfAsset.toString());

            expect(reciptEventAcceptAppointment.events[0].args[2].status).to.equal(AppointmentStatus.ACCEPTED);

            // -> Evaluator evaluated Asset
            let balanceOfContractHardEvaluationBeforeEvaluatedAsset = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;
            let balanceOfEvaluatorBeforeEvaluatedAsset = (await _loanTokenContract.balanceOf(_evaluator.address)) / decimal;

            console.log("Evaluation - before transaction:");
            console.log(`\x1b[36m Evaluator  balance : ${balanceOfEvaluatorBeforeEvaluatedAsset.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeEvaluatedAsset.toString()} \x1b[0m`);

            let getEventEvaluateAsset = await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
                ListAppointment.FIRSTID, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);
            let reciptEvaluateAsset = await getEventEvaluateAsset.wait();

            console.log(`\x1b[31m Event contract transfer token for evaluator after evaluator evaluate Asset \x1b[0m`);
            console.log(reciptEvaluateAsset.events[0]);

            console.log(`\x1b[31m Event Evaluator evaluated Asset \x1b[0m`);
            console.log(`evaluationId : \x1b[36m ${reciptEvaluateAsset.events[1].args[0].toString()} \x1b[0m`);
            console.log("asset :", reciptEvaluateAsset.events[1].args[1]);
            console.log("evaluationList", reciptEvaluateAsset.events[1].args[2])
            console.log(`beEvaluationId : \x1b[36m ${reciptEvaluateAsset.events[1].args[3].toString()} \x1b[0m`);

            let balanceOfEvaluatorAfterEvaluatedAsset = (await _loanTokenContract.balanceOf(_evaluator.address)) / decimal;
            let balanceOfContractHardEvaluationAfterEvaluatedAsset = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Evaluation - after transaction:");
            console.log(`\x1b[36m Evaluator  balance : ${balanceOfEvaluatorAfterEvaluatedAsset.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterEvaluatedAsset.toString()} \x1b[0m`);

            let appoitmentInfo = await _hardEvaluationContract.appointmentList(ListAppointment.FIRSTID);


            expect(balanceOfEvaluatorBeforeEvaluatedAsset).to.equal(balanceOfEvaluatorAfterEvaluatedAsset - evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeEvaluatedAsset).to.equal(balanceOfContractHardEvaluationAfterEvaluatedAsset + evaluationFee);
            expect(appoitmentInfo.status).to.equal(AppointmentStatus.EVALUATED);
            expect(reciptEvaluateAsset.events[1].args[2].status).to.equal(EvaluationStatus.EVALUATED);

            // -> customer accept evaluation 

            let balanceOfCustomerBeforeAcceptEvaluation = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            let balanceOfContractHardEvaluationBeforeAcceptEvaluation = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Accept evaluation - before transaction:");
            console.log(`\x1b[36m Customer  balance : ${balanceOfCustomerBeforeAcceptEvaluation.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeAcceptEvaluation.toString()} \x1b[0m`);

            let listEvaluation = await _hardEvaluationContract.evaluationList(EvaluationList.FIRSTID);
            console.log(listEvaluation.toString());

            let getEventAcceptEvaluation = await _hardEvaluationContract.connect(_customer).acceptEvaluation(EvaluationList.FIRSTID);
            let reciptEventAcceptEvaluation = await getEventAcceptEvaluation.wait();
            console.log(`\x1b[31m Event Customer accept evaluation \x1b[0m`);
            console.log(`evaluationId : \x1b[36m ${reciptEventAcceptEvaluation.events[2].args[0].toString()} \x1b[0m`);
            console.log("asset :", reciptEventAcceptEvaluation.events[2].args[1]);
            console.log("evaluation :", reciptEventAcceptEvaluation.events[2].args[2]);
            console.log(`unknow : \x1b[36m ${reciptEventAcceptEvaluation.events[2].args[3].toString()} \x1b[0m`);

            console.log(`\x1b[31m Event customer transfer token into contract \x1b[0m`);
            console.log(reciptEventAcceptEvaluation.events[0]);

            let balanceOfCustomerAfterAcceptEvaluation = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            let balanceOfContractHardEvaluationAfterAcceptEvaluation = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Accept evaluation - after transaction:");
            console.log(`\x1b[36m Customer  balance : ${balanceOfCustomerAfterAcceptEvaluation.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterAcceptEvaluation.toString()} \x1b[0m`);

            let getEvaluationInfo = await _hardEvaluationContract.evaluationList(EvaluationList.FIRSTID);

            expect(balanceOfCustomerBeforeAcceptEvaluation).to.equal(balanceOfCustomerAfterAcceptEvaluation + mintingFee);
            expect(balanceOfContractHardEvaluationBeforeAcceptEvaluation).to.equal(balanceOfContractHardEvaluationAfterAcceptEvaluation - mintingFee);
            expect(getEvaluationInfo.status).to.equal(EvaluationStatus.EVALUATION_ACCEPTED);
            expect(reciptEventAcceptEvaluation.events[2].args[1].status).to.equal(AssetStatus.EVALUATED);

            // -> Evaluator mint NFT for Customer

            let balanceOfHubFeeWalletBeforeMintNFT = (await _loanTokenContract.balanceOf(_feeWallet.address)) / decimal;
            let balanceOfContractHardEvaluationBeforeMintNFT = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Mint NFT - before transaction:");
            console.log(`\x1b[36m Fee Wallet balance : ${balanceOfHubFeeWalletBeforeMintNFT.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeMintNFT.toString()} \x1b[0m`);

            let getEventCreateNFT = await _hardEvaluationContract.connect(_evaluator).createNftToken(EvaluationList.FIRSTID, 1, "NFTCID");
            let reciptEventCreateNFT = await getEventCreateNFT.wait();
            console.log(`\x1b[31m Event evaluator mintNFT \x1b[0m`);
            console.log(`tokenId : \x1b[36m ${reciptEventCreateNFT.events[2].args[0].toString()} \x1b[0m`);
            console.log(`nftCID : \x1b[36m ${reciptEventCreateNFT.events[2].args[1].toString()} \x1b[0m`);
            console.log(`amount : \x1b[36m ${reciptEventCreateNFT.events[2].args[2].toString()} \x1b[0m`);
            console.log("aseet :", reciptEventCreateNFT.events[2].args[3]);
            console.log("evaluation :", reciptEventCreateNFT.events[2].args[4]);
            console.log(`evaluationId : \x1b[36m ${reciptEventCreateNFT.events[2].args[5].toString()} \x1b[0m`);


            console.log(`\x1b[31m Event transfer token to mintNFT \x1b[0m`);
            console.log(reciptEventCreateNFT.events[1]);

            let balanceOfHubFeeWalletAfterMintNFT = (await _loanTokenContract.balanceOf(_feeWallet.address)) / decimal;
            let balanceOfContractHardEvaluationAfterMintNFT = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Mint NFT - after transaction:");
            console.log(`\x1b[36m Fee Wallet balance : ${balanceOfHubFeeWalletAfterMintNFT.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterMintNFT.toString()} \x1b[0m`);

            let owner = await _DFYHard721Contract.ownerOf(NFTOfBorrower.FIRSTNFT);
            let assetAfterCreateNFT = await _hardEvaluationContract.assetList(ListAssetRequest.FIRSTID);
            let evaluationAfterCreateNFT = await _hardEvaluationContract.evaluationList(EvaluationList.FIRSTID);

            expect(balanceOfHubFeeWalletBeforeMintNFT).to.equal(balanceOfHubFeeWalletAfterMintNFT - mintingFee);
            expect(balanceOfContractHardEvaluationBeforeMintNFT).to.equal(balanceOfContractHardEvaluationAfterMintNFT + mintingFee);
            expect(owner).to.equal(_customer.address);
            expect(assetAfterCreateNFT.status).to.equal(AssetStatus.NFT_CREATED);
            expect(evaluationAfterCreateNFT.status).to.equal(EvaluationStatus.NFT_CREATED);

        });

        it("Case 3: Evaluator evaluated Asset\n\r", async () => {

            // -> customer create asset request
            await _hardEvaluationContract.connect(_customer).createAssetRequest(
                _assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
                _loanTokenContract.address, 0, _beAssetId); // create Asset request 

            // -> customer create Appointment 
            let balanceOfCustomerBeforeCreateAppointment = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            let balanceOfContractHardEvaluationBeforeCreateAppoitment = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - before transaction: ");
            console.log(`\x1b[36m customer balance : ${balanceOfCustomerBeforeCreateAppointment.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeCreateAppoitment.toString()} \x1b[0m`);

            await _hardEvaluationContract.connect(_customer).createAppointment(ListAssetRequest.SECONDID, _evaluator.address, _loanTokenContract.address, appointmentTime);

            let balanceOfCustomerAfterCreateAppoitnment = (await _loanTokenContract.balanceOf(_customer.address)) / decimal; // check transfer 
            let balanceOfContractHardEvaluationAfterCreateAppointment = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - after transaction:");
            console.log(`\x1b[36m customer balance : ${balanceOfCustomerAfterCreateAppoitnment.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterCreateAppointment.toString()} \x1b[0m`);

            expect(balanceOfCustomerBeforeCreateAppointment).to.equal(balanceOfCustomerAfterCreateAppoitnment + evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeCreateAppoitment).to.equal(balanceOfContractHardEvaluationAfterCreateAppointment - evaluationFee);

            // -> Evaluator accept Appoitment

            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(ListAppointment.SECONDID, appointmentTime);

            // -> Evaluator evaluated Asset

            let balanceOfContractHardEvaluationBeforeEvaluatedAsset = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;
            let balanceOfEvaluatorBeforeEvaluatedAsset = (await _loanTokenContract.balanceOf(_evaluator.address)) / decimal;

            console.log("Evaluation - before transaction:");
            console.log(`\x1b[36m Evaluator  balance : ${balanceOfEvaluatorBeforeEvaluatedAsset.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeEvaluatedAsset.toString()} \x1b[0m`);

            let getEventEvaluateAsset = await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
                ListAppointment.SECONDID, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);
            let reciptEvaluateAsset = await getEventEvaluateAsset.wait();

            console.log(`\x1b[31m Event contract transfer token for evaluator after evaluator evaluate Asset \x1b[0m`);
            console.log(reciptEvaluateAsset.events[0]);

            console.log(`\x1b[31m Event Evaluator evaluated Asset \x1b[0m`);
            console.log(`evaluationId : \x1b[36m ${reciptEvaluateAsset.events[1].args[0].toString()} \x1b[0m`);
            console.log("asset :", reciptEvaluateAsset.events[1].args[1]);
            console.log("evaluationList", reciptEvaluateAsset.events[1].args[2]);
            console.log(`beEvaluationId : \x1b[36m ${reciptEvaluateAsset.events[1].args[3].toString()} \x1b[0m`);

            let balanceOfEvaluatorAfterEvaluatedAsset = (await _loanTokenContract.balanceOf(_evaluator.address)) / decimal;
            let balanceOfContractHardEvaluationAfterEvaluatedAsset = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Evaluation - after transaction:");
            console.log(`\x1b[36m Evaluator  balance : ${balanceOfEvaluatorAfterEvaluatedAsset.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterEvaluatedAsset.toString()} \x1b[0m`);

            let appoitmentInfo = await _hardEvaluationContract.appointmentList(ListAppointment.SECONDID);

            expect(balanceOfEvaluatorBeforeEvaluatedAsset).to.equal(balanceOfEvaluatorAfterEvaluatedAsset - evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeEvaluatedAsset).to.equal(balanceOfContractHardEvaluationAfterEvaluatedAsset + evaluationFee);
            expect(appoitmentInfo.status).to.equal(AppointmentStatus.EVALUATED);
            expect(reciptEvaluateAsset.events[1].args[2].status).to.equal(EvaluationStatus.EVALUATED);
        });

        it("Case 4: Customer reject Evaluation\n\r", async () => {

            // -> customer create asset request
            await _hardEvaluationContract.connect(_customer).createAssetRequest(
                _assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
                _loanTokenContract.address, 0, _beAssetId); // create Asset request 

            // -> customer create Appointment 
            let balanceOfCustomerBeforeCreateAppointment = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            let balanceOfContractHardEvaluationBeforeCreateAppoitment = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - before transaction: ");
            console.log(`\x1b[36m customer balance : ${balanceOfCustomerBeforeCreateAppointment.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeCreateAppoitment.toString()} \x1b[0m`);

            await _hardEvaluationContract.connect(_customer).createAppointment(ListAssetRequest.THIRDID, _evaluator.address, _loanTokenContract.address, appointmentTime);

            let balanceOfCustomerAfterCreateAppoitnment = (await _loanTokenContract.balanceOf(_customer.address)) / decimal; // check transfer 
            let balanceOfContractHardEvaluationAfterCreateAppointment = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - after transaction:");
            console.log(`\x1b[36m customer balance : ${balanceOfCustomerAfterCreateAppoitnment.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterCreateAppointment.toString()} \x1b[0m`);

            expect(balanceOfCustomerBeforeCreateAppointment).to.equal(balanceOfCustomerAfterCreateAppoitnment + evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeCreateAppoitment).to.equal(balanceOfContractHardEvaluationAfterCreateAppointment - evaluationFee);

            // -> Evaluator accept Appoitment
            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(ListAppointment.THIRDID, appointmentTime);

            // -> Evaluator evaluated Asset

            let balanceOfContractHardEvaluationBeforeEvaluatedAsset = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;
            let balanceOfEvaluatorBeforeEvaluatedAsset = (await _loanTokenContract.balanceOf(_evaluator.address)) / decimal;

            console.log("Evaluation - before transaction:");
            console.log(`\x1b[36m Evaluator  balance : ${balanceOfEvaluatorBeforeEvaluatedAsset.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeEvaluatedAsset.toString()} \x1b[0m`);

            let getEventEvaluateAsset = await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
                ListAppointment.THIRDID, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);
            let reciptEvaluateAsset = await getEventEvaluateAsset.wait();

            console.log(`\x1b[31m Event contract transfer token for evaluator after evaluator evaluate Asset \x1b[0m`);
            console.log(reciptEvaluateAsset.events[0]);

            console.log(`\x1b[31m Event Evaluator evaluated Asset \x1b[0m`);
            console.log(`evaluationId : \x1b[36m ${reciptEvaluateAsset.events[1].args[0].toString()} \x1b[0m`);
            console.log("asset :", reciptEvaluateAsset.events[1].args[1]);
            console.log("evaluationList", reciptEvaluateAsset.events[1].args[2])
            console.log(`beEvaluationId : \x1b[36m ${reciptEvaluateAsset.events[1].args[3].toString()} \x1b[0m`);

            let balanceOfEvaluatorAfterEvaluatedAsset = (await _loanTokenContract.balanceOf(_evaluator.address)) / decimal;
            let balanceOfContractHardEvaluationAfterEvaluatedAsset = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Evaluation - after transaction:");
            console.log(`\x1b[36m Evaluator  balance : ${balanceOfEvaluatorAfterEvaluatedAsset.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterEvaluatedAsset.toString()} \x1b[0m`);

            let appoitmentInfo = await _hardEvaluationContract.appointmentList(ListAppointment.THIRDID);

            expect(balanceOfEvaluatorBeforeEvaluatedAsset).to.equal(balanceOfEvaluatorAfterEvaluatedAsset - evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeEvaluatedAsset).to.equal(balanceOfContractHardEvaluationAfterEvaluatedAsset + evaluationFee);
            // expect(appoitmentInfo.status).to.equal(AppointmentStatus.EVALUATED);
            expect(reciptEvaluateAsset.events[1].args[2].status).to.equal(EvaluationStatus.EVALUATED);

            // -> customer reject Evaluation 
            let getEventCustomerRejectEvaluation = await _hardEvaluationContract.connect(_customer).rejectEvaluation(EvaluationList.THIRDID);
            let reciptEventCustomerRejectEvaluation = await getEventCustomerRejectEvaluation.wait();
            console.log(`\x1b[31m Event customer reject Evaluation \x1b[0m`);
            console.log(`evaluationId : \x1b[36m ${reciptEventCustomerRejectEvaluation.events[0].args[0].toString()} \x1b[0m`);
            console.log("asset", reciptEventCustomerRejectEvaluation.events[0].args[1]);
            console.log("evaluation", reciptEventCustomerRejectEvaluation.events[0].args[2]);
            console.log("unknow", reciptEventCustomerRejectEvaluation.events[0].args[3]);

            let infoEvaluation = await _hardEvaluationContract.evaluationList(EvaluationList.THIRDID);
            let infoAsset = await _hardEvaluationContract.assetList(ListAssetRequest.THIRDID);
            expect(infoEvaluation.status).to.equal(EvaluationStatus.EVALUATION_REJECTED);
            expect(infoAsset.status).to.equal(AssetStatus.OPEN);
        });

        it("Case 5: customer cancel Appoitment\n\r", async () => {

            // -> customer create asset request
            await _hardEvaluationContract.connect(_customer).createAssetRequest(
                _assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
                _loanTokenContract.address, 0, _beAssetId); // create Asset request 

            // -> customer create Appointment 
            let balanceOfCustomerBeforeCreateAppointment = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            let balanceOfContractHardEvaluationBeforeCreateAppoitment = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - before transaction: ");
            console.log(`\x1b[36m customer balance : ${balanceOfCustomerBeforeCreateAppointment.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeCreateAppoitment.toString()} \x1b[0m`);

            await _hardEvaluationContract.connect(_customer).createAppointment(ListAssetRequest.FOURDID, _evaluator.address, _loanTokenContract.address, appointmentTime);

            let balanceOfCustomerAfterCreateAppoitnment = (await _loanTokenContract.balanceOf(_customer.address)) / decimal; // check transfer 
            let balanceOfContractHardEvaluationAfterCreateAppointment = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - after transaction:");
            console.log(`\x1b[36m customer balance : ${balanceOfCustomerAfterCreateAppoitnment.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterCreateAppointment.toString()} \x1b[0m`);

            expect(balanceOfCustomerBeforeCreateAppointment).to.equal(balanceOfCustomerAfterCreateAppoitnment + evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeCreateAppoitment).to.equal(balanceOfContractHardEvaluationAfterCreateAppointment - evaluationFee);

            // -> customer cancel Appointment
            let getEventCancelAppointment = await _hardEvaluationContract.cancelAppointment(ListAppointment.FOURDID, "unknow");
            let reciptEventCancelAppointment = await getEventCancelAppointment.wait();

            console.log(`\x1b[31m Event Customer cancel Appointment \x1b[0m`);
            console.log(reciptEventCancelAppointment.events[1]);

            console.log(`\x1b[31m Event contract refund for customer \x1b[0m`);
            console.log(reciptEventCancelAppointment.events[0]);

            let balanceOfCustomerAfterCancelAppointment = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            let balanceOfContractHardEvaluationAfterCancelAppoitment = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Cancel appointment - after transaction: ");
            console.log(`\x1b[36m customer balance : ${balanceOfCustomerAfterCancelAppointment.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterCancelAppoitment.toString()} \x1b[0m`);

            expect(balanceOfCustomerAfterCreateAppoitnment).to.equal(balanceOfCustomerAfterCancelAppointment - evaluationFee);
            expect(balanceOfContractHardEvaluationAfterCreateAppointment).to.equal(balanceOfContractHardEvaluationAfterCancelAppoitment + evaluationFee);

        });

        it("Case 6: Evaluator reject Appoitment\n\r", async () => {

            // -> customer create asset request 
            await _hardEvaluationContract.connect(_customer).createAssetRequest(
                _assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
                _loanTokenContract.address, 0, _beAssetId); // create Asset request 

            // -> customer create Appointment 
            let balanceOfCustomerBeforeCreateAppointment = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            let balanceOfContractHardEvaluationBeforeCreateAppoitment = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - before transaction: ");
            console.log(`\x1b[36m customer balance : ${balanceOfCustomerBeforeCreateAppointment.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeCreateAppoitment.toString()} \x1b[0m`);

            await _hardEvaluationContract.connect(_customer).createAppointment(ListAssetRequest.FIVEID, _evaluator.address, _loanTokenContract.address, appointmentTime);

            let balanceOfCustomerAfterCreateAppoitnment = (await _loanTokenContract.balanceOf(_customer.address)) / decimal; // check transfer 
            let balanceOfContractHardEvaluationAfterCreateAppointment = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - after transaction:");
            console.log(`\x1b[36m customer balance : ${balanceOfCustomerAfterCreateAppoitnment.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterCreateAppointment.toString()} \x1b[0m`);

            expect(balanceOfCustomerBeforeCreateAppointment).to.equal(balanceOfCustomerAfterCreateAppoitnment + evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeCreateAppoitment).to.equal(balanceOfContractHardEvaluationAfterCreateAppointment - evaluationFee);

            // -> Evaluator reject Appoitment
            let getEventRejectAppointment = await _hardEvaluationContract.connect(_evaluator).rejectAppointment(ListAppointment.FIVEID, "11");

            let reciptEventRejectAppointment = await getEventRejectAppointment.wait();

            console.log(`\x1b[31m Event Contract refund evalation fee for customer \x1b[0m`);
            console.log(reciptEventRejectAppointment.events[0]);

            console.log(`\x1b[31m Event Evaluator reject Appoitment \x1b[0m`);
            console.log(reciptEventRejectAppointment.events[1]);

            let infoAppointment = await _hardEvaluationContract.appointmentList(ListAppointment.FIVEID);
            expect(infoAppointment.status).to.equal(AppointmentStatus.REJECTED);

            let balanceOfCustomerAfterRejectAppoitment = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            let balanceOfContractHardEvaluationAfterRejectAppoitment = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Reject appointment - after transaction:");
            console.log(`\x1b[36m customer balance : ${balanceOfCustomerAfterRejectAppoitment.toString()} \x1b[0m`);
            console.log(`\x1b[36m HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterRejectAppoitment.toString()} \x1b[0m`);

            expect(balanceOfCustomerAfterCreateAppoitnment).to.equal(balanceOfCustomerAfterRejectAppoitment - evaluationFee);
            expect(balanceOfContractHardEvaluationAfterCreateAppointment).to.equal(balanceOfContractHardEvaluationAfterRejectAppoitment + evaluationFee);
        });

        it(` case 7 : customer create an list appointment for evaluators, evaluators evaluate asset and customer accept 1 evaluation of 1 evaluator \n\r`, async () => {

            // -> customer create asset request
            await _hardEvaluationContract.connect(_customer).createAssetRequest(
                _assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
                _loanTokenContract.address, 0, _beAssetId);

            // -> customer create Appointment For A and For B and C 
            await _hardEvaluationContract.connect(_customer).createAppointment(ListAssetRequest.SIXID, _evaluator.address, _loanTokenContract.address, appointmentTime);
            await _hardEvaluationContract.connect(_customer).createAppointment(ListAssetRequest.SIXID, _evaluatorB.address, _loanTokenContract.address, appointmentTime);
            await _hardEvaluationContract.connect(_customer).createAppointment(ListAssetRequest.SIXID, _evaluatorC.address, _loanTokenContract.address, appointmentTime);

            let appointmentListA = await _hardEvaluationContract.appointmentList(ListAppointment.SIXID);
            let appointmentListB = await _hardEvaluationContract.appointmentList(ListAppointment.SEVENTID);
            let appointmentListC = await _hardEvaluationContract.appointmentList(ListAppointment.EIGHTID);

            expect(appointmentListA.evaluator).to.equal(_evaluator.address);
            expect(appointmentListA.status).to.equal(AppointmentStatus.OPEN);
            expect(appointmentListB.evaluator).to.equal(_evaluatorB.address);
            expect(appointmentListB.status).to.equal(AppointmentStatus.OPEN);
            expect(appointmentListC.evaluator).to.equal(_evaluatorC.address);
            expect(appointmentListC.status).to.equal(AppointmentStatus.OPEN);

            // -> Evaluator accept Appointment 5 
            let getEventAcceptAppointment5 = await _hardEvaluationContract.connect(_evaluator).acceptAppointment(ListAppointment.SIXID, appointmentTime);
            let reciptEventAcceptAppointment5 = await getEventAcceptAppointment5.wait();
            console.log(reciptEventAcceptAppointment5.events[0].args[2]);
            expect(reciptEventAcceptAppointment5.events[0].args[2].status).to.equal(AppointmentStatus.ACCEPTED);

            // -> EvaluatorB accept Appointment 6
            let getEventAcceptAppointment6 = await _hardEvaluationContract.connect(_evaluatorB).acceptAppointment(ListAppointment.SEVENTID, appointmentTime);
            let reciptEventAcceptAppointment6 = await getEventAcceptAppointment6.wait();
            expect(reciptEventAcceptAppointment6.events[0].args[2].status).to.equal(AppointmentStatus.ACCEPTED);

            // -> Evaluator evaluated Asset5 with AppointmentId 5
            await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
                ListAppointment.SIXID, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);

            // -> EvaluatorB evaluated Asset5 with AppointmentId 6
            await _hardEvaluationContract.connect(_evaluatorB).evaluateAsset(_DFYHard721Contract.address,
                ListAppointment.SEVENTID, BigInt(100 * 10 ** 18), "_evaluationCID", BigInt(10 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);

            let evaluation3 = await _hardEvaluationContract.evaluationList(EvaluationList.FOURDID);
            let evaluation4 = await _hardEvaluationContract.evaluationList(EvaluationList.FIVEID);
            console.log(evaluation3.toString());
            console.log(evaluation4.toString());

            let getEventAcceptEvaluation = await _hardEvaluationContract.connect(_customer).acceptEvaluation(EvaluationList.FOURDID);
            // // let getEventAcceptEvaluation = await _hardEvaluationContract.connect(_customer).acceptEvaluation(4);
            let reciptEventAcceptEvaluation = await getEventAcceptEvaluation.wait();

            console.log(`\x1b[31m Event customer accept evaluation A and reject evaluation B : \x1b[0m`);
            console.log(reciptEventAcceptEvaluation.events[0]);
            console.log("evaluation Id reject :", reciptEventAcceptEvaluation.events[0].args[0].toString());
            console.log("Asset :", reciptEventAcceptEvaluation.events[0].args[1].toString());
            console.log("list evaluation :", reciptEventAcceptEvaluation.events[0].args[2]);

            // sau khi accept thằng 3 thì đổi evaluation status của thằng 4 thành reject 
            evaluation4 = await _hardEvaluationContract.evaluationList(EvaluationList.FIVEID);
            expect(evaluation4.status).to.equal(EvaluationStatus.EVALUATION_REJECTED);

            console.log(`\x1b[31m Event reject Appointment C after customer accept evaluation A : \x1b[0m`);
            console.log(reciptEventAcceptEvaluation.events[1]);

            let getAppointmentC = await _hardEvaluationContract.appointmentList(ListAppointment.EIGHTID);
            expect(getAppointmentC.status).to.equal(AppointmentStatus.REJECTED);
        });

    });
});