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
        console.log(`Minting fee: \x1b[36m${Number(_mintingFee) / decimal}\x1b[0m\n\r`);
    });

    describe("Unit test Hard NFT & Evaluation", async () => {

        it(`Case 1: Evaluator create NFT for customer\n\r`, async () => {

            // -> customer create asset request
            await _hubContract.connect(_deployer).setEvaluationConfig(_loanTokenContract.address, _evaluationFee, _mintingFee); // addWhiteListFee -> add address token to pay for evaluation fee , mint nft fee 
            let getEventCreateAssetRequest = await _hardEvaluationContract.connect(_customer).createAssetRequest(
                _assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
                _loanTokenContract.address, 0, _beAssetId); // create Asset request 
            let assetList = await _hardEvaluationContract.assetList(0);

            console.log(`\x1b[31m Event customer created AssetRequest \x1b[0m`);
            let recipt = await getEventCreateAssetRequest.wait();
            console.log(`assetId : \x1b[36m ${recipt.events[0].args[0].toString()} \x1b[0m`);
            console.log("asset", recipt.events[0].args[1])
            console.log(`beAssetId : \x1b[36m ${recipt.events[0].args[2].toString()} \x1b[0m`);

            expect(assetList.assetCID).to.equal(_assetCID);
            expect(assetList.owner).to.equal(_customer.address);
            expect(assetList.collectionAddress).to.equal(_DFYHard721Contract.address);
            expect(assetList.collectionStandard).to.equal(0);
            expect(assetList.status).to.equal(AssetStatus.OPEN);

            // -> customer create Appointment 
            await _loanTokenContract.setOperator(_deployer.address, true); // loan token transfer for customer and approve
            await _loanTokenContract.mint(_deployer.address, BigInt(1000 * 10 ** 18));
            await _loanTokenContract.connect(_deployer).transfer(_customer.address, BigInt(100 * 10 ** 18));
            await _loanTokenContract.connect(_customer).approve(_hardEvaluationContract.address, BigInt(100 * 10 ** 18));

            let balanceOfCustomerBeforeTnx = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            let balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - before transaction: ");
            console.log(`Customer balance: ${balanceOfCustomerBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

            let getEventCreateAppointment = await _hardEvaluationContract.connect(_customer).createAppointment(0, _evaluator.address, _loanTokenContract.address, appointmentTime);
            let reciptEventCreateAppointment = await getEventCreateAppointment.wait();
            console.log(`\x1b[31m Event customer create Appointment \x1b[0m`);
            console.log(`appointmentId : \x1b[36m ${reciptEventCreateAppointment.events[2].args[0].toString()} \x1b[0m`);
            console.log("asset", reciptEventCreateAppointment.events[2].args[1]);
            console.log("appointmentList", reciptEventCreateAppointment.events[2].args[2]);
            console.log(`"" \x1b[36m ${reciptEventCreateAppointment.events[2].args[3].toString()} \x1b[0m`);
            console.log(`appointmentTime : \x1b[36m ${reciptEventCreateAppointment.events[2].args[4].toString()} \x1b[0m`);

            console.log(`\x1b[31m Event transfer token of customer into this contract \x1b[0m`);
            console.log(reciptEventCreateAppointment.events[0]);
            // console.log(Number(reciptEventCreateAppointment.events[0].data));

            let appointmentList = await _hardEvaluationContract.appointmentList(0); // check info after create appointment  
            expect(appointmentList.assetId).to.equal(0);
            expect(appointmentList.assetOwner).to.equal(_customer.address);
            expect(appointmentList.evaluator).to.equal(_evaluator.address);
            expect(appointmentList.evaluationFee).to.equal(_evaluationFee);
            expect(appointmentList.evaluationFeeAddress).to.equal(_loanTokenContract.address);
            expect(reciptEventCreateAppointment.events[2].args[2].status).to.equal(AppointmentStatus.OPEN);


            let balanceOfCustomerAfterTnx = (await _loanTokenContract.balanceOf(_customer.address)) / decimal; // check transfer 
            let balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - after transaction:");
            console.log(`Customer balance: ${balanceOfCustomerAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            expect(balanceOfCustomerBeforeTnx).to.equal(balanceOfCustomerAfterTnx + evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx - evaluationFee);

            // -> Evaluator accept Appoitment

            let getEVALUATOR_ROLE = await _hubContract.EvaluatorRole();  // grant evaluator roll 
            await _hubContract.connect(_deployer).grantRole(getEVALUATOR_ROLE, _evaluator.address);
            let getEventAcceptAppointment = await _hardEvaluationContract.connect(_evaluator).acceptAppointment(0, appointmentTime);
            let reciptEventAcceptAppointment = await getEventAcceptAppointment.wait();

            console.log(`\x1b[31m Event Evaluator accept Appointment \x1b[0m`);
            console.log(`thisAppointmentId : \x1b[36m ${reciptEventAcceptAppointment.events[0].args[0].toString()} \x1b[0m`);
            console.log("assetList", reciptEventAcceptAppointment.events[0].args[1]);
            console.log("thisAppointment", reciptEventAcceptAppointment.events[0].args[2]);
            console.log(`unknow : \x1b[36m ${reciptEventAcceptAppointment.events[0].args[3].toString()} \x1b[0m`);
            console.log(`appointmentTime : \x1b[36m ${reciptEventAcceptAppointment.events[0].args[4].toString()} \x1b[0m`);



            expect(reciptEventAcceptAppointment.events[0].args[1].status).to.equal(AppointmentStatus.ACCEPTED);
            expect(reciptEventAcceptAppointment.events[0].args[2].status).to.equal(AssetStatus.APPOINTED);

            // -> Evaluator evaluated Asset

            balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;
            let balanceOfEvaluatorBeforeTnx = (await _loanTokenContract.balanceOf(_evaluator.address)) / decimal;

            console.log("Evaluation - before transaction:");
            console.log(`Evaluator balance: ${balanceOfEvaluatorBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

            let getEventEvaluateAsset = await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
                0, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);
            let reciptEvaluateAsset = await getEventEvaluateAsset.wait();

            console.log(`\x1b[31m Event contract transfer token for evaluator after evaluator evaluate Asset \x1b[0m`);
            console.log(reciptEvaluateAsset.events[0]);

            console.log(`\x1b[31m Event Evaluator evaluated Asset \x1b[0m`);
            console.log(`evaluationId : \x1b[36m ${reciptEvaluateAsset.events[1].args[0].toString()} \x1b[0m`);
            console.log("asset :", reciptEvaluateAsset.events[1].args[1]);
            console.log("evaluationList", reciptEvaluateAsset.events[1].args[2])
            console.log(`beEvaluationId : \x1b[36m ${reciptEvaluateAsset.events[1].args[3].toString()} \x1b[0m`);

            let balanceOfEvaluatorAfterTnx = (await _loanTokenContract.balanceOf(_evaluator.address)) / decimal;
            balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Evaluation - after transaction:");
            console.log(`Evaluator balance: ${balanceOfEvaluatorAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            let appoitmentInfo = await _hardEvaluationContract.appointmentList(0);

            expect(balanceOfEvaluatorBeforeTnx).to.equal(balanceOfEvaluatorAfterTnx - evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx + evaluationFee);
            expect(appoitmentInfo.status).to.equal(AppointmentStatus.EVALUATED);
            expect(reciptEvaluateAsset.events[1].args[2].status).to.equal(EvaluationStatus.EVALUATED);

            // -> customer accept evaluation 

            balanceOfCustomerBeforeTnx = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Accept evaluation - before transaction:");
            console.log(`Customer balance: ${balanceOfCustomerBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

            let getEventAcceptEvaluation = await _hardEvaluationContract.connect(_customer).acceptEvaluation(0);
            let reciptEventAcceptEvaluation = await getEventAcceptEvaluation.wait();
            console.log(`\x1b[31m Event Customer accept evaluation \x1b[0m`);
            console.log(`evaluationId : \x1b[36m ${reciptEventAcceptEvaluation.events[2].args[0].toString()} \x1b[0m`);
            console.log("asset :", reciptEventAcceptEvaluation.events[2].args[1]);
            console.log("evaluation :", reciptEventAcceptEvaluation.events[2].args[2]);
            console.log(`unknow : \x1b[36m ${reciptEventAcceptEvaluation.events[2].args[3].toString()} \x1b[0m`);

            console.log(`\x1b[31m Event customer transfer token into contract \x1b[0m`);
            console.log(reciptEventAcceptEvaluation.events[0]);

            balanceOfCustomerAfterTnx = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Accept evaluation - after transaction:");
            console.log(`Customer balance: ${balanceOfCustomerAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            let getEvaluationInfo = await _hardEvaluationContract.evaluationList(0);

            expect(balanceOfCustomerBeforeTnx).to.equal(balanceOfCustomerAfterTnx + mintingFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx - mintingFee);
            expect(getEvaluationInfo.status).to.equal(EvaluationStatus.EVALUATION_ACCEPTED);
            expect(reciptEventAcceptEvaluation.events[2].args[1].status).to.equal(AssetStatus.EVALUATED);

            // -> Evaluator mint NFT for Customer

            let balanceOfHubFeeWalletBeforeTnx = (await _loanTokenContract.balanceOf(_feeWallet.address)) / decimal;
            balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Mint NFT - before transaction:");
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}`);
            console.log(`Fee Wallet balance: ${balanceOfHubFeeWalletBeforeTnx.toString()}\n\r`);

            let getEventCreateNFT = await _hardEvaluationContract.connect(_evaluator).createNftToken(0, 1, "NFTCID");
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

            let balanceOfHubFeeWalletAfterTnx = (await _loanTokenContract.balanceOf(_feeWallet.address)) / decimal;
            balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Mint NFT - after transaction:");
            console.log(`Fee Wallet balance: ${balanceOfHubFeeWalletAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            let owner = await _DFYHard721Contract.ownerOf(0);
            let assetAfterCreateNFT = await _hardEvaluationContract.assetList(0);
            let evaluationAfterCreateNFT = await _hardEvaluationContract.evaluationList(0);

            expect(balanceOfHubFeeWalletBeforeTnx).to.equal(balanceOfHubFeeWalletAfterTnx - mintingFee);
            expect(owner).to.equal(_customer.address);
            expect(assetAfterCreateNFT.status).to.equal(AssetStatus.NFT_CREATED);
            expect(evaluationAfterCreateNFT.status).to.equal(EvaluationStatus.NFT_CREATED);

        });

        it("Case 2: Evaluator evaluated Asset\n\r", async () => {

            // -> customer create asset request
            await _hubContract.connect(_deployer).setEvaluationConfig(_loanTokenContract.address, _evaluationFee, _mintingFee); // addWhiteListFee -> add address token to pay for evaluation fee , mint nft fee 
            await _hardEvaluationContract.connect(_customer).createAssetRequest(
                _assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
                _loanTokenContract.address, 0, _beAssetId); // create Asset request 

            // -> customer create Appointment 
            await _loanTokenContract.setOperator(_deployer.address, true); // loan token transfer for customer and approve
            await _loanTokenContract.mint(_deployer.address, BigInt(1000 * 10 ** 18));
            await _loanTokenContract.connect(_deployer).transfer(_customer.address, BigInt(100 * 10 ** 18));
            await _loanTokenContract.connect(_customer).approve(_hardEvaluationContract.address, BigInt(100 * 10 ** 18));

            let balanceOfCustomerBeforeTnx = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            let balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - before transaction: ");
            console.log(`Customer balance: ${balanceOfCustomerBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

            await _hardEvaluationContract.connect(_customer).createAppointment(1, _evaluator.address, _loanTokenContract.address, appointmentTime);

            let balanceOfCustomerAfterTnx = (await _loanTokenContract.balanceOf(_customer.address)) / decimal; // check transfer 
            let balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - after transaction:");
            console.log(`Customer balance: ${balanceOfCustomerAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            expect(balanceOfCustomerBeforeTnx).to.equal(balanceOfCustomerAfterTnx + evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx - evaluationFee);

            // -> Evaluator accept Appoitment

            let getEVALUATOR_ROLE = await _hubContract.EvaluatorRole();  // grant evaluator roll 
            await _hubContract.connect(_deployer).grantRole(getEVALUATOR_ROLE, _evaluator.address);
            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(1, appointmentTime);

            // -> Evaluator evaluated Asset

            balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;
            let balanceOfEvaluatorBeforeTnx = (await _loanTokenContract.balanceOf(_evaluator.address)) / decimal;

            console.log("Evaluation - before transaction:");
            console.log(`Evaluator balance: ${balanceOfEvaluatorBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

            let getEventEvaluateAsset = await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
                1, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);
            let reciptEvaluateAsset = await getEventEvaluateAsset.wait();

            console.log(`\x1b[31m Event contract transfer token for evaluator after evaluator evaluate Asset \x1b[0m`);
            console.log(reciptEvaluateAsset.events[0]);

            console.log(`\x1b[31m Event Evaluator evaluated Asset \x1b[0m`);
            console.log(`evaluationId : \x1b[36m ${reciptEvaluateAsset.events[1].args[0].toString()} \x1b[0m`);
            console.log("asset :", reciptEvaluateAsset.events[1].args[1]);
            console.log("evaluationList", reciptEvaluateAsset.events[1].args[2])
            console.log(`beEvaluationId : \x1b[36m ${reciptEvaluateAsset.events[1].args[3].toString()} \x1b[0m`);

            let balanceOfEvaluatorAfterTnx = (await _loanTokenContract.balanceOf(_evaluator.address)) / decimal;
            balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Evaluation - after transaction:");
            console.log(`Evaluator balance: ${balanceOfEvaluatorAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            let appoitmentInfo = await _hardEvaluationContract.appointmentList(1);

            expect(balanceOfEvaluatorBeforeTnx).to.equal(balanceOfEvaluatorAfterTnx - evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx + evaluationFee);
            expect(appoitmentInfo.status).to.equal(AppointmentStatus.EVALUATED);
            expect(reciptEvaluateAsset.events[1].args[2].status).to.equal(EvaluationStatus.EVALUATED);
        });

        it("Case 3: Customer reject Evaluation\n\r", async () => {

            // -> customer create asset request
            await _hubContract.connect(_deployer).setEvaluationConfig(_loanTokenContract.address, _evaluationFee, _mintingFee); // addWhiteListFee -> add address token to pay for evaluation fee , mint nft fee 
            await _hardEvaluationContract.connect(_customer).createAssetRequest(
                _assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
                _loanTokenContract.address, 0, _beAssetId); // create Asset request 

            // -> customer create Appointment 
            await _loanTokenContract.setOperator(_deployer.address, true); // loan token transfer for customer and approve
            await _loanTokenContract.mint(_deployer.address, BigInt(1000 * 10 ** 18));
            await _loanTokenContract.connect(_deployer).transfer(_customer.address, BigInt(100 * 10 ** 18));
            await _loanTokenContract.connect(_customer).approve(_hardEvaluationContract.address, BigInt(100 * 10 ** 18));

            let balanceOfCustomerBeforeTnx = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            let balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - before transaction: ");
            console.log(`Customer balance: ${balanceOfCustomerBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

            await _hardEvaluationContract.connect(_customer).createAppointment(2, _evaluator.address, _loanTokenContract.address, appointmentTime);

            let balanceOfCustomerAfterTnx = (await _loanTokenContract.balanceOf(_customer.address)) / decimal; // check transfer 
            let balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - after transaction:");
            console.log(`Customer balance: ${balanceOfCustomerAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            expect(balanceOfCustomerBeforeTnx).to.equal(balanceOfCustomerAfterTnx + evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx - evaluationFee);

            // -> Evaluator accept Appoitment

            let getEVALUATOR_ROLE = await _hubContract.EvaluatorRole();  // grant evaluator roll 
            await _hubContract.connect(_deployer).grantRole(getEVALUATOR_ROLE, _evaluator.address);
            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(2, appointmentTime);

            // -> Evaluator evaluated Asset

            balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;
            let balanceOfEvaluatorBeforeTnx = (await _loanTokenContract.balanceOf(_evaluator.address)) / decimal;

            console.log("Evaluation - before transaction:");
            console.log(`Evaluator balance: ${balanceOfEvaluatorBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

            await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
                2, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);

            let balanceOfEvaluatorAfterTnx = (await _loanTokenContract.balanceOf(_evaluator.address)) / decimal;
            balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Evaluation - after transaction:");
            console.log(`Evaluator balance: ${balanceOfEvaluatorAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            expect(balanceOfEvaluatorBeforeTnx).to.equal(balanceOfEvaluatorAfterTnx - evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx + evaluationFee);

            // -> customer reject Evaluation 
            let getEventCustomerRejectEvaluation = await _hardEvaluationContract.connect(_customer).rejectEvaluation(2);
            let reciptEventCustomerRejectEvaluation = await getEventCustomerRejectEvaluation.wait();
            console.log(`\x1b[31m Event customer reject Evaluation \x1b[0m`);
            console.log(`evaluationId : \x1b[36m ${reciptEventCustomerRejectEvaluation.events[0].args[0].toString()} \x1b[0m`);
            console.log("asset", reciptEventCustomerRejectEvaluation.events[0].args[1]);
            console.log("evaluation", reciptEventCustomerRejectEvaluation.events[0].args[2]);
            console.log("unknow", reciptEventCustomerRejectEvaluation.events[0].args[3]);

            let infoEvaluation = await _hardEvaluationContract.evaluationList(2);
            let infoAsset = await _hardEvaluationContract.assetList(2);
            expect(infoEvaluation.status).to.equal(EvaluationStatus.EVALUATION_REJECTED);
            expect(infoAsset.status).to.equal(AssetStatus.OPEN);
        });

        it("Case 4: customer cancel Appoitment\n\r", async () => {

            // -> customer create asset request
            await _hubContract.connect(_deployer).setEvaluationConfig(_loanTokenContract.address, _evaluationFee, _mintingFee); // addWhiteListFee -> add address token to pay for evaluation fee , mint nft fee 
            let getEventCreateAssetRequest = await _hardEvaluationContract.connect(_customer).createAssetRequest(
                _assetCID, _DFYHard721Contract.address, BigInt(10 * 10 ** 18),
                _loanTokenContract.address, 0, _beAssetId); // create Asset request 
            let assetList = await _hardEvaluationContract.assetList(3);

            console.log(`\x1b[31m Event customer created AssetRequest \x1b[0m`);
            let recipt = await getEventCreateAssetRequest.wait();
            console.log(`assetId : \x1b[36m ${recipt.events[0].args[0].toString()} \x1b[0m`);
            console.log("asset", recipt.events[0].args[1])
            console.log(`beAssetId : \x1b[36m ${recipt.events[0].args[2].toString()} \x1b[0m`);

            expect(assetList.assetCID).to.equal(_assetCID);
            expect(assetList.owner).to.equal(_customer.address);
            expect(assetList.collectionAddress).to.equal(_DFYHard721Contract.address);
            expect(assetList.collectionStandard).to.equal(0);
            expect(assetList.status).to.equal(AssetStatus.OPEN);

            // -> customer create Appointment 
            await _loanTokenContract.setOperator(_deployer.address, true); // loan token transfer for customer and approve
            await _loanTokenContract.mint(_deployer.address, BigInt(1000 * 10 ** 18));
            await _loanTokenContract.connect(_deployer).transfer(_customer.address, BigInt(100 * 10 ** 18));
            await _loanTokenContract.connect(_customer).approve(_hardEvaluationContract.address, BigInt(100 * 10 ** 18));

            let balanceOfCustomerBeforeTnx = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            let balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - before transaction: ");
            console.log(`Customer balance: ${balanceOfCustomerBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

            let getEventCreateAppointment = await _hardEvaluationContract.connect(_customer).createAppointment(3, _evaluator.address, _loanTokenContract.address, appointmentTime);
            let reciptEventCreateAppointment = await getEventCreateAppointment.wait();
            console.log(`\x1b[31m Event customer create Appointment \x1b[0m`);
            console.log(`appointmentId : \x1b[36m ${reciptEventCreateAppointment.events[2].args[0].toString()} \x1b[0m`);
            console.log("asset", reciptEventCreateAppointment.events[2].args[1]);
            console.log("appointmentList", reciptEventCreateAppointment.events[2].args[2]);
            console.log(`"" \x1b[36m ${reciptEventCreateAppointment.events[2].args[3].toString()} \x1b[0m`);
            console.log(`appointmentTime : \x1b[36m ${reciptEventCreateAppointment.events[2].args[4].toString()} \x1b[0m`);

            console.log(`\x1b[31m Event transfer token of customer into this contract \x1b[0m`);
            console.log(reciptEventCreateAppointment.events[0]);

            let appointmentList = await _hardEvaluationContract.appointmentList(3); // check info after create appointment 
            expect(appointmentList.assetId).to.equal(3);
            expect(appointmentList.assetOwner).to.equal(_customer.address);
            expect(appointmentList.evaluator).to.equal(_evaluator.address);
            expect(appointmentList.evaluationFee).to.equal(_evaluationFee);
            expect(appointmentList.evaluationFeeAddress).to.equal(_loanTokenContract.address);
            expect(reciptEventCreateAppointment.events[2].args[2].status).to.equal(AppointmentStatus.OPEN);

            let balanceOfCustomerAfterTnx = (await _loanTokenContract.balanceOf(_customer.address)) / decimal; // check transfer 
            let balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - after transaction:");
            console.log(`Customer balance: ${balanceOfCustomerAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            expect(balanceOfCustomerBeforeTnx).to.equal(balanceOfCustomerAfterTnx + evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx - evaluationFee);

            // -> customer cancel Appointment
            let getEventCancelAppointment = await _hardEvaluationContract.cancelAppointment(3, "unknow");
            let reciptEventCancelAppointment = await getEventCancelAppointment.wait();

            console.log(`\x1b[31m Event Customer cancel Appointment \x1b[0m`);
            console.log(reciptEventCancelAppointment.events[1]);

            console.log(`\x1b[31m Event contract refund for customer \x1b[0m`);
            console.log(reciptEventCancelAppointment.events[0]);

        });

        it("Case 5: Evaluator reject Appoitment\n\r", async () => {

            // -> customer create asset request
            await _hubContract.connect(_deployer).setEvaluationConfig(_loanTokenContract.address, _evaluationFee, _mintingFee); // addWhiteListFee -> add address token to pay for evaluation fee , mint nft fee 
            await _hardEvaluationContract.connect(_customer).createAssetRequest(
                _assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
                _loanTokenContract.address, 0, _beAssetId); // create Asset request 

            // -> customer create Appointment 
            await _loanTokenContract.setOperator(_deployer.address, true); // loan token transfer for customer and approve
            await _loanTokenContract.mint(_deployer.address, BigInt(1000 * 10 ** 18));
            await _loanTokenContract.connect(_deployer).transfer(_customer.address, BigInt(100 * 10 ** 18));
            await _loanTokenContract.connect(_customer).approve(_hardEvaluationContract.address, BigInt(100 * 10 ** 18));

            let balanceOfCustomerBeforeTnx = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            let balanceOfContractHardEvaluationBeforeTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - before transaction: ");
            console.log(`Customer balance: ${balanceOfCustomerBeforeTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationBeforeTnx.toString()}\n\r`);

            await _hardEvaluationContract.connect(_customer).createAppointment(4, _evaluator.address, _loanTokenContract.address, appointmentTime);;


            let balanceOfCustomerAfterTnx = (await _loanTokenContract.balanceOf(_customer.address)) / decimal; // check transfer 
            let balanceOfContractHardEvaluationAfterTnx = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            console.log("Create appointment - after transaction:");
            console.log(`Customer balance: ${balanceOfCustomerAfterTnx.toString()}`);
            console.log(`HardEvaluation contract balance: ${balanceOfContractHardEvaluationAfterTnx.toString()}\n\r`);

            expect(balanceOfCustomerBeforeTnx).to.equal(balanceOfCustomerAfterTnx + evaluationFee);
            expect(balanceOfContractHardEvaluationBeforeTnx).to.equal(balanceOfContractHardEvaluationAfterTnx - evaluationFee);

            // -> Evaluator reject Appoitment
            let getEventRejectAppointment = await _hardEvaluationContract.connect(_evaluator).rejectAppointment(4, "11");

            let reciptEventRejectAppointment = await getEventRejectAppointment.wait();
            console.log(reciptEventRejectAppointment.events);

            let infoAppointment = await _hardEvaluationContract.appointmentList(4);
            expect(infoAppointment.status).to.equal(AppointmentStatus.REJECTED);

            let balanceOfCustomerAfterRejectAppoitment = (await _loanTokenContract.balanceOf(_customer.address)) / decimal;
            let balanceOfContractHardEvaluationAfterRejectAppoitment = (await _loanTokenContract.balanceOf(_hardEvaluationContract.address)) / decimal;

            expect(balanceOfCustomerAfterTnx).to.equal(balanceOfCustomerAfterRejectAppoitment - evaluationFee);
            expect(balanceOfContractHardEvaluationAfterTnx).to.equal(balanceOfContractHardEvaluationAfterRejectAppoitment + evaluationFee);

        });
    });
});