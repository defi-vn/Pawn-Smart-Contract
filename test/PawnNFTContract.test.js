const hre = require("hardhat");
const artifactDFYHard721 = "DFYHard721";
const artifactPawnNFT = "PawnNFTContract";
const artifactReputation = "Reputation";
const artifactHub = "Hub";
const artifactExchange = "ExchangeCopy";
const artifactHardEvaluation = "HardEvaluation";
const artifactLoanNFT = "LoanNFTContract";
const artifactLoanToken = "LoanToken";
const { expect, assert } = require("chai");
const decimal = 10 ** 18;

describe("Setting up test parameters:\n\r", (done) => {

    let _DFYHard721Contract = null;
    let _loanTokenContract = null;
    let _loanNFTContract = null;
    let _pawnNFTContract = null;
    let _hardEvaluationContract = null;
    let _hubContract = null;
    let _reputationContract = null;
    let _exchangeContract = null;
    let _evaluationFee = BigInt(10 * 10 ** 18);
    let _mintingFee = BigInt(15 * 10 ** 18);
    let _assetCID = "Example";
    let _tokenName = "DFYHard721NFT";
    let _symbol = "DFY";
    let _collectionCID = "EXAMPLE";
    let _appointmentTime = Math.floor(Date.now() / 1000) + 300;
    let _firstToken = 0;
    let _secondToken = 1;
    let _thirdToken = 2;
    let _4thToken = 3;
    let _beAssetId = "example";
    let _beEvaluationId = "EXAMPLE";
    let _loanToValue = BigInt(2 * 10 ** 18);
    let _loanAmount = BigInt(1 * 10 ** 18);
    let _interest = BigInt(250000);
    let _duration = Math.floor(Date.now() / 1000) + 500;
    let _liquidityThreshold = BigInt(3 * 10 ** 18);

    let evaluationFee = Number(_evaluationFee) / decimal;
    let mintingFee = Number(_mintingFee) / decimal;

    const LoanDurationType = {
        WEEK: 0,
        MONTH: 1
    };
    const CollateralStatus = {
        OPEN: 0,
        DOING: 1,
        COMPLETED: 2,
        CANCEL: 3
    };
    const OfferStatus = {
        PENDING: 0,
        ACCEPTED: 1,
        COMPLETED: 2,
        CANCEL: 3
    };
    const CollectionStandard = {
        ERC721: 0,
        ERC1155: 1,
    };

    before(async () => {
        [
            _deployer,
            _evaluator,
            _borrower,
            _lender,
            _hubFeeWallet,
            _feeToken
        ] = await ethers.getSigners();

        // loanToken 
        const loanTokenFactory = await hre.ethers.getContractFactory(artifactLoanToken);
        const loanTokenContract = await loanTokenFactory.deploy();
        _loanTokenContract = await loanTokenContract.deployed();

        // contract Hub 
        const hubContractFactory = await hre.ethers.getContractFactory(artifactHub);
        const hubContract = await hre.upgrades.deployProxy(
            hubContractFactory,
            [_hubFeeWallet.address, _loanTokenContract.address, _deployer.address],
            { kind: "uups" }
        );
        _hubContract = await hubContract.deployed();

        // loanNFT  
        const loanNFTFactory = await hre.ethers.getContractFactory(artifactLoanNFT);
        const loanContract = await hre.upgrades.deployProxy(
            loanNFTFactory,
            [_hubContract.address],
            { kind: "uups" }
        );
        _loanNFTContract = await loanContract.deployed();
        let getSignatureOfLoanNFTContract = await _loanNFTContract.signature();
        await _hubContract.registerContract(getSignatureOfLoanNFTContract, _loanNFTContract.address, artifactLoanNFT);

        // exchange 
        const exchangeFactory = await hre.ethers.getContractFactory(artifactExchange);
        const exchangeContract = await hre.upgrades.deployProxy(
            exchangeFactory,
            [_hubContract.address],
            { kind: "uups" }
        );
        _exchangeContract = await exchangeContract.deployed();

        let getSignatureExchangeContract = await _exchangeContract.signature();
        await _hubContract.connect(_deployer).registerContract(getSignatureExchangeContract, _exchangeContract.address, artifactExchange);
        await _hubContract.getContractAddress(getSignatureExchangeContract);

        let getOperatorRole = await _hubContract.OperatorRole();
        await _hubContract.connect(_deployer).grantRole(getOperatorRole, _loanNFTContract.address);

        // pawn nft contract 
        const pawnContractFactory = await hre.ethers.getContractFactory(artifactPawnNFT);
        const pawnNFTContract = await hre.upgrades.deployProxy(
            pawnContractFactory,
            [_hubContract.address],
            { kind: "uups" }
        );
        _pawnNFTContract = await pawnNFTContract.deployed();
        await _hubContract.grantRole(getOperatorRole, _pawnNFTContract.address);

        // reputation contract 
        const reputationFactory = await hre.ethers.getContractFactory(artifactReputation);
        const reputationContract = await hre.upgrades.deployProxy(
            reputationFactory,
            [_hubContract.address],
            { kind: "uups" }
        );
        _reputationContract = await reputationContract.deployed();

        // hard_Evaluation
        const hardEvaluationFactory = await hre.ethers.getContractFactory(artifactHardEvaluation);
        const hardEvaluationContract = await hre.upgrades.deployProxy(
            hardEvaluationFactory,
            [_hubContract.address],
            { kind: "uups" }
        );
        _hardEvaluationContract = await hardEvaluationContract.deployed();

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

        // console.log(`Hub address: \x1b[31m${_hubContract.address}\x1b[0m`);
        // console.log(`DFY Hard NFT-721: \x1b[36m${_DFYHard721Contract.address}\x1b[0m`);
        // console.log(`Loan asset: \x1b[36m${_loanTokenContract.address}\x1b[0m`);
    });

    describe("Unit test Pawn NFT Contract", async () => {

        it(`Case 1: borrower accept offer form lender \n\r`, async () => {

            // customer create asset request 
            await _hubContract.connect(_deployer).setEvaluationConfig(_hubFeeWallet.address, _loanTokenContract.address, _evaluationFee, _mintingFee);
            await _hardEvaluationContract.connect(_borrower).createAssetRequest(
                _assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
                _loanTokenContract.address, CollectionStandard.ERC721, _beAssetId);

            // -> customer create Appointment 
            await _loanTokenContract.setOperator(_deployer.address, true); // loan token transfer for customer and approve
            await _loanTokenContract.mint(_deployer.address, BigInt(1000 * 10 ** 18));
            await _loanTokenContract.connect(_deployer).transfer(_borrower.address, BigInt(1000 * 10 ** 18));
            await _loanTokenContract.connect(_borrower).approve(_hardEvaluationContract.address, BigInt(1000 * 10 ** 18));
            await _hardEvaluationContract.connect(_borrower).createAppointment(0, _evaluator.address, _loanTokenContract.address, _appointmentTime);

            // -> Evaluator accept Appoitment
            let getEVALUATOR_ROLE = await _hubContract.EvaluatorRole();  // grant evaluator roll 
            await _hubContract.connect(_deployer).grantRole(getEVALUATOR_ROLE, _evaluator.address);
            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(0, _appointmentTime);

            // -> Evaluator evaluated Asset
            await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
                0, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);

            // -> customer accept evaluation 
            await _hardEvaluationContract.connect(_borrower).acceptEvaluation(0);

            // -> Evaluator mint NFT for Customer
            await _hardEvaluationContract.connect(_evaluator).createNftToken(0, 1, "NFTCID");

            // approve
            await _DFYHard721Contract.connect(_borrower).approve(_pawnNFTContract.address, 0);

            // hub setWhitelistCollateral_NFT 
            await _hubContract.connect(_deployer).setWhitelistCollateral_NFT(_DFYHard721Contract.address, 1);

            // Reputation addWhitelistedContractCaller 
            await _reputationContract.connect(_deployer).addWhitelistedContractCaller(_pawnNFTContract.address);

            // signature Reputation & signature HardEvaluation 
            let getSignatureOfReputation = await _reputationContract.signature();
            let getSignatureHardEvaluation = await _hardEvaluationContract.signature();

            // registry reputation and hardEvaluation on hub 
            await _hubContract.connect(_deployer).registerContract(getSignatureOfReputation, _reputationContract.address, artifactReputation);
            await _hubContract.connect(_deployer).registerContract(getSignatureHardEvaluation, _hardEvaluationContract.address, artifactHardEvaluation);

            let onwerTokenOfCustomerBeforePutOnPawn = await _DFYHard721Contract.ownerOf(0);
            console.log("before put on pawn");
            console.log(`owner : \x1b[36m ${onwerTokenOfCustomerBeforePutOnPawn.toString()} \x1b[0m`);
            console.log(`customer : \x1b[36m ${_borrower.address} \x1b[0m`);

            // Borrower put on pawn 
            let getEventPutOnPawn = await _pawnNFTContract.connect(_borrower).putOnPawn(
                _DFYHard721Contract.address, _firstToken, BigInt(1 * 10 ** 18), _loanTokenContract.address, 1, 3, 0, 0);
            let reciptEventPutOnPawn = await getEventPutOnPawn.wait();

            console.log("action transfer nft of customer into pawnNFTContract");
            let onwerTokenOfCustomerAfterPutOnPawn = await _DFYHard721Contract.ownerOf(0);
            console.log("after put on pawn");
            console.log(`owner : \x1b[36m ${onwerTokenOfCustomerAfterPutOnPawn.toString()} \x1b[0m`);
            console.log(`pawnNFT contract : \x1b[36m ${_pawnNFTContract.address} \x1b[0m`);
            expect(_pawnNFTContract.address).to.equal(onwerTokenOfCustomerAfterPutOnPawn);
            console.log(`\x1b[31m Event customer transfer token into pawnNFT contract \x1b[0m`);
            console.log(reciptEventPutOnPawn.events[1]);

            console.log(`\x1b[31m Event Put on pawn \x1b[0m`);
            console.log(reciptEventPutOnPawn.events[2]);

            // Lender create offer 
            await _loanTokenContract.setOperator(_deployer.address, true);
            await _loanTokenContract.mint(_deployer.address, BigInt(1000 * 10 ** 18));
            await _loanTokenContract.connect(_deployer).transfer(_lender.address, BigInt(100 * 10 ** 18));
            await _loanTokenContract.connect(_lender).approve(_pawnNFTContract.address, BigInt(100 * 10 ** 18));

            let getEventCreateOffer = await _pawnNFTContract.connect(_lender).createOffer(0,
                _DFYHard721Contract.address, BigInt(1 * 10 ** 18), _interest, _duration,
                LoanDurationType.WEEK, LoanDurationType.WEEK);

            let reciptEventCreateOffer = await getEventCreateOffer.wait();

            // create offer 2 
            await _pawnNFTContract.connect(_lender).createOffer(0,
                _DFYHard721Contract.address, BigInt(3 * 10 ** 18), _interest, _duration,
                LoanDurationType.WEEK, LoanDurationType.WEEK);

            console.log(`\x1b[31m Event lender create offer :\x1b[0m`);
            console.log(reciptEventCreateOffer.events[0]);
            console.log(reciptEventCreateOffer.events[0].args[1]);

            let collateral = await _pawnNFTContract.collaterals(0);
            let collateralOfferList = await _pawnNFTContract.collateralOffersMapping(0);

            console.log(collateral.toString());
            console.log(collateralOfferList.toString());

            // Borrower accept offer from lender
            let getEventAcceptOffer = await _pawnNFTContract.connect(_borrower).acceptOffer(0, 1);
            let reciptEventAcceptOffer = await getEventAcceptOffer.wait();
            console.log(reciptEventAcceptOffer.events);

            // check change status of offer and collateral
            collateral = await _pawnNFTContract.collaterals(0);
            collateralOfferList = await _pawnNFTContract.collateralOffersMapping(0);
            console.log(collateral.toString());

            console.log(collateralOfferList);

            // expect(collateral.status).to.equal(CollateralStatus.DOING);
            // expect(collateralOfferList.status).to.equal(OfferStatus.ACCEPTED);
        });

        // it(`Case 2: borrower cancel offer from lender \n\r`, async () => {

        //     // customer create asset request 
        //     await _hardEvaluationContract.connect(_borrower).createAssetRequest(_assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
        //         _loanTokenContract.address, CollectionStandard.ERC721, _beAssetId);

        //     // -> customer create Appointment 
        //     await _hardEvaluationContract.connect(_borrower).createAppointment(1, _evaluator.address, _loanTokenContract.address, _appointmentTime);

        //     // -> Evaluator accept Appoitment
        //     await _hardEvaluationContract.connect(_evaluator).acceptAppointment(1, _appointmentTime);

        //     // -> Evaluator evaluated Asset
        //     await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
        //         1, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);

        //     // -> customer accept evaluation 
        //     await _hardEvaluationContract.connect(_borrower).acceptEvaluation(1);

        //     // -> Evaluator mint NFT for Customer
        //     await _hardEvaluationContract.connect(_evaluator).createNftToken(1, 1, "NFTCID");

        //     // approve
        //     await _DFYHard721Contract.connect(_borrower).approve(_pawnNFTContract.address, 1);

        //     // Borrower put on pawn 
        //     await _pawnNFTContract.connect(_borrower).putOnPawn(_DFYHard721Contract.address, _secondToken, BigInt(1 * 10 ** 18),
        //         _loanTokenContract.address, 1, 3, 0, 0);

        //     // Lender create offer 
        //     await _pawnNFTContract.connect(_lender).createOffer(1, _DFYHard721Contract.address, _loanAmount, _interest, _duration,
        //         LoanDurationType.WEEK, LoanDurationType.WEEK);

        //     // Borrower cancel offer from lender
        //     let getEventAcceptOffer = await _pawnNFTContract.connect(_borrower).cancelOffer(1, 1);
        //     let reciptEventAcceptOffer = await getEventAcceptOffer.wait();
        //     console.log(`\x1b[31m event reject offer :\x1b[0m`);
        //     console.log(reciptEventAcceptOffer.events[0]);
        // });

        // it(`Case 3: lender itself cancel offer\n\r`, async () => {

        //     // customer create asset request 
        //     await _hardEvaluationContract.connect(_borrower).createAssetRequest(_assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
        //         _loanTokenContract.address, CollectionStandard.ERC721, _beAssetId);

        //     // -> customer create Appointment 
        //     await _hardEvaluationContract.connect(_borrower).createAppointment(2, _evaluator.address, _loanTokenContract.address, _appointmentTime);

        //     // -> Evaluator accept Appoitment
        //     await _hardEvaluationContract.connect(_evaluator).acceptAppointment(2, _appointmentTime);

        //     // -> Evaluator evaluated Asset
        //     await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
        //         2, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);

        //     // -> customer accept evaluation 
        //     await _hardEvaluationContract.connect(_borrower).acceptEvaluation(2);

        //     // -> Evaluator mint NFT for Customer
        //     await _hardEvaluationContract.connect(_evaluator).createNftToken(2, 1, "NFTCID");

        //     // approve
        //     await _DFYHard721Contract.connect(_borrower).approve(_pawnNFTContract.address, _thirdToken);

        //     // Borrower put on pawn 
        //     await _pawnNFTContract.connect(_borrower).putOnPawn(_DFYHard721Contract.address, _thirdToken, BigInt(1 * 10 ** 18),
        //         _loanTokenContract.address, 1, 3, 0, 0);

        //     // Lender create offer 
        //     await _pawnNFTContract.connect(_lender).createOffer(2, _DFYHard721Contract.address, _loanAmount, _interest, _duration,
        //         LoanDurationType.WEEK, LoanDurationType.WEEK);

        //     // lender cancel offer 
        //     let getEventAcceptOffer = await _pawnNFTContract.connect(_lender).cancelOffer(2, 2);
        //     let reciptEventAcceptOffer = await getEventAcceptOffer.wait();
        //     console.log(`\x1b event cancel offer :  \x1b[0m`);
        //     console.log(reciptEventAcceptOffer.events);

        // });

        // it(`Case 4: borrower withdrawCollateral after put on pawn \n\r`, async () => {

        //     // customer create asset request 
        //     await _hardEvaluationContract.connect(_borrower).createAssetRequest(_assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
        //         _loanTokenContract.address, CollectionStandard.ERC721, _beAssetId);

        //     // -> customer create Appointment 
        //     await _hardEvaluationContract.connect(_borrower).createAppointment(3, _evaluator.address, _loanTokenContract.address, _appointmentTime);

        //     // -> Evaluator accept Appoitment
        //     await _hardEvaluationContract.connect(_evaluator).acceptAppointment(3, _appointmentTime);

        //     // -> Evaluator evaluated Asset
        //     await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
        //         3, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);

        //     // -> customer accept evaluation 
        //     await _hardEvaluationContract.connect(_borrower).acceptEvaluation(3);

        //     // -> Evaluator mint NFT for Customer
        //     await _hardEvaluationContract.connect(_evaluator).createNftToken(3, 1, "NFTCID");

        //     // approve
        //     await _DFYHard721Contract.connect(_borrower).approve(_pawnNFTContract.address, _4thToken);

        //     // Borrower put on pawn 
        //     await _pawnNFTContract.connect(_borrower).putOnPawn(_DFYHard721Contract.address, _4thToken, BigInt(1 * 10 ** 18),
        //         _loanTokenContract.address, 1, 3, 0, 0);

        //     // Lender create offer 
        //     await _pawnNFTContract.connect(_lender).createOffer(3, _DFYHard721Contract.address, _loanAmount, _interest, _duration,
        //         LoanDurationType.WEEK, LoanDurationType.WEEK);

        //     // Borrower withdrawCollateral NFT 
        //     let getEventWithdraw = await _pawnNFTContract.connect(_borrower).withdrawCollateral(3);
        //     let reciptEventWithdraw = await getEventWithdraw.wait();
        //     console.log(`\x1b after put on pawn  :  \x1b[0m`);
        //     let ownerToken = await _DFYHard721Contract.ownerOf(_4thToken);
        //     expect(ownerToken).to.equal(_borrower.address);

        //     console.log(`\x1b[36m event withdraw :  \x1b[0m`);
        //     console.log(reciptEventWithdraw.events[3]);

        //     console.log(`\x1b[36m list collateral :  \x1b[0m`);
        //     console.log(reciptEventWithdraw.events[3].args[1]);
        //     expect(reciptEventWithdraw.events[3].args[1].status).to.equal(CollateralStatus.CANCEL);

        // });

    });
});