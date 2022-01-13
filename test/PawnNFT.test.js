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
        FIVEID: 4
    };
    const ListAppointment = {
        FIRSTID: 0,
        SECONDID: 1,
        THIRDID: 2,
        FOURDID: 3,
        FIVEID: 4
    }
    const NFTCollateral = {
        FIRSTID: 0,
        SECONDID: 1,
        THIRDID: 2,
        FOURDID: 3,
        FIVEID: 4
    };
    const ListOffer = {
        FIRSTID: 0,
        SECONDID: 1,
        THIRDID: 2,
        FOURDID: 3,
        FIVEID: 4,
        SIXID: 5
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
            _evaluator,
            _borrower,
            _lender,
            _lenderB,
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

        console.log(`Hub address: \x1b[31m${_hubContract.address}\x1b[0m`);
        console.log(`DFY Hard NFT-721: \x1b[36m${_DFYHard721Contract.address}\x1b[0m`);
        console.log(`Loan asset: \x1b[36m${_loanTokenContract.address}\x1b[0m`);
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
            await _hardEvaluationContract.connect(_borrower).createAppointment(ListAssetRequest.FIRSTID, _evaluator.address, _loanTokenContract.address, _appointmentTime);

            // -> Evaluator accept Appoitment
            let getEVALUATOR_ROLE = await _hubContract.EvaluatorRole();  // grant evaluator roll 
            await _hubContract.connect(_deployer).grantRole(getEVALUATOR_ROLE, _evaluator.address);
            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(ListAppointment.FIRSTID, _appointmentTime);

            // -> Evaluator evaluated Asset
            await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
                ListAppointment.FIRSTID, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);

            // -> customer accept evaluation 
            await _hardEvaluationContract.connect(_borrower).acceptEvaluation(EvaluationList.FIRSTID);

            // -> Evaluator mint NFT for Customer
            await _hardEvaluationContract.connect(_evaluator).createNftToken(EvaluationList.FIRSTID, 1, "NFTCID");

            // approve
            await _DFYHard721Contract.connect(_borrower).approve(_pawnNFTContract.address, NFTOfBorrower.FIRSTNFT);

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

            let onwerTokenOfCustomerBeforePutOnPawn = await _DFYHard721Contract.ownerOf(NFTOfBorrower.FIRSTNFT);
            console.log("before put on pawn");
            console.log(`owner : \x1b[36m ${onwerTokenOfCustomerBeforePutOnPawn.toString()} \x1b[0m`);
            console.log(`customer : \x1b[36m ${_borrower.address} \x1b[0m`);

            // -> Borrower put on pawn, if currency = address(0) is solftNFT else is hardNFT để tính ngỡ thanh lý 
            let getEventPutOnPawn = await _pawnNFTContract.connect(_borrower).putOnPawn(
                _DFYHard721Contract.address, NFTOfBorrower.FIRSTNFT, BigInt(1 * 10 ** 18),
                _loanTokenContract.address, 1, 3, LoanDurationType.WEEK, 0);
            let reciptEventPutOnPawn = await getEventPutOnPawn.wait();

            console.log("action transfer nft of customer into pawnNFTContract");
            let onwerTokenOfCustomerAfterPutOnPawn = await _DFYHard721Contract.ownerOf(NFTOfBorrower.FIRSTNFT);
            console.log("after put on pawn");
            console.log(`owner : \x1b[36m ${onwerTokenOfCustomerAfterPutOnPawn.toString()} \x1b[0m`);
            console.log(`pawnNFT contract : \x1b[36m ${_pawnNFTContract.address} \x1b[0m`);
            expect(_pawnNFTContract.address).to.equal(onwerTokenOfCustomerAfterPutOnPawn);

            console.log(`\x1b[31m Event customer transfer token into pawnNFT contract \x1b[0m`);
            console.log(reciptEventPutOnPawn.events[1]);

            let getCollateral = await _pawnNFTContract.collaterals(NFTCollateral.FIRSTID);
            expect(getCollateral.nftContract).to.equal(reciptEventPutOnPawn.events[2].args[1].nftContract);
            expect(getCollateral.nftTokenId).to.equal(reciptEventPutOnPawn.events[2].args[1].nftTokenId);
            expect(getCollateral.expectedlLoanAmount).to.equal(reciptEventPutOnPawn.events[2].args[1].expectedlLoanAmount);
            expect(getCollateral.loanAsset).to.equal(reciptEventPutOnPawn.events[2].args[1].loanAsset);
            expect(getCollateral.nftTokenQuantity).to.equal(reciptEventPutOnPawn.events[2].args[1].nftTokenQuantity);
            expect(getCollateral.expectedDurationQty).to.equal(reciptEventPutOnPawn.events[2].args[1].expectedDurationQty);
            expect(getCollateral.durationType).to.equal(reciptEventPutOnPawn.events[2].args[1].durationType);

            console.log(`\x1b[31m Event Put on pawn \x1b[0m`);
            console.log(reciptEventPutOnPawn.events[2]);

            // Lender create offer 
            await _loanTokenContract.setOperator(_deployer.address, true);
            await _loanTokenContract.mint(_deployer.address, BigInt(1000 * 10 ** 18));
            await _loanTokenContract.connect(_deployer).transfer(_lender.address, BigInt(500 * 10 ** 18));
            await _loanTokenContract.connect(_deployer).transfer(_lenderB.address, BigInt(500 * 10 ** 18))
            await _loanTokenContract.connect(_lender).approve(_pawnNFTContract.address, BigInt(500 * 10 ** 18));
            await _loanTokenContract.connect(_lenderB).approve(_pawnNFTContract.address, BigInt(500 * 10 ** 18));

            let getEventCreateOffer = await _pawnNFTContract.connect(_lender).createOffer(NFTCollateral.FIRSTID,
                _DFYHard721Contract.address, BigInt(1 * 10 ** 18), _interest, _duration,
                LoanDurationType.WEEK, LoanDurationType.WEEK);
            let reciptEventCreateOffer = await getEventCreateOffer.wait();

            let getOffer = await _pawnNFTContract.getOffer(NFTCollateral.FIRSTID, ListOffer.FIRSTID);

            expect(getOffer.owner).to.equal(_lender.address);
            expect(getOffer.repaymentAsset).to.equal(_DFYHard721Contract.address);
            expect(getOffer.loanAmount).to.equal(BigInt(1 * 10 ** 18));
            expect(getOffer.interest).to.equal(_interest);
            expect(getOffer.loanDurationType).to.equal(LoanDurationType.WEEK);
            expect(getOffer.repaymentCycleType).to.equal(LoanDurationType.WEEK);
            console.log(getOffer.status);

            console.log(`\x1b[31m Event lender create offer :\x1b[0m`);
            console.log(reciptEventCreateOffer.events[0]);


            console.log(`\x1b[31m balance borrower of before acceptOffer \x1b[0m`);
            let balanceOfBorrowerBeforeAcceptOffer = await _loanTokenContract.balanceOf(_borrower.address);
            console.log(`\x1b[36m ${balanceOfBorrowerBeforeAcceptOffer.toString()} \x1b[0m`);

            // Borrower accept offer from lender
            let getEventAcceptOffer = await _pawnNFTContract.connect(_borrower).acceptOffer(NFTCollateral.FIRSTID, ListOffer.FIRSTID);
            let reciptEventAcceptOffer = await getEventAcceptOffer.wait();

            // transfer loan asset to collateral owner 
            console.log(`\x1b[31m balance borrower of after acceptOffer \x1b[0m`);
            let balanceOfBorrowerAfterAcceptOffer = await _loanTokenContract.balanceOf(_borrower.address);
            console.log(balanceOfBorrowerAfterAcceptOffer);

            expect(balanceOfBorrowerBeforeAcceptOffer).to.equal(BigInt(balanceOfBorrowerAfterAcceptOffer)
                - BigInt(reciptEventCreateOffer.events[0].args[2].loanAmount));

            let getLoanNFTContract = await _loanNFTContract.contracts(0);
            getCollateral = await _pawnNFTContract.collaterals(NFTCollateral.FIRSTID);

            console.log(`\x1b[31m contract loanNFT :\x1b[0m`);
            console.log(getLoanNFTContract);

            console.log(`\x1b[31m first collateral :\x1b[0m`);
            console.log(getCollateral);


            expect(getLoanNFTContract.nftCollateralId).to.equal(NFTCollateral.FIRSTID);
            // colateral
            expect(getLoanNFTContract.offerId).to.equal(ListOffer.FIRSTID);
            expect(getLoanNFTContract.terms.loanAmount).to.equal(BigInt(1 * 10 ** 18));
            expect(getLoanNFTContract.terms.lender).to.equal(_lender.address);
            expect(getLoanNFTContract.terms.repaymentAsset).to.equal(_DFYHard721Contract.address);
            expect(getLoanNFTContract.terms.interest).to.equal(_interest);
            // exchangeRate
            expect(getLoanNFTContract.terms.repaymentCycleType).to.equal(getOffer.repaymentCycleType);
            getOffer = await _pawnNFTContract.getOffer(NFTCollateral.FIRSTID, ListOffer.FIRSTID);
            expect(getOffer.status).to.equal(OfferStatus.ACCEPTED);
            expect(getCollateral.status).to.equal(CollateralStatus.DOING);
        });

        it(`Case 2: borrower cancel offer from lender \n\r`, async () => {

            // customer create asset request 
            await _hardEvaluationContract.connect(_borrower).createAssetRequest(_assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
                _loanTokenContract.address, CollectionStandard.ERC721, _beAssetId);

            // -> customer create Appointment 
            await _hardEvaluationContract.connect(_borrower).createAppointment(ListAssetRequest.SECONDID, _evaluator.address, _loanTokenContract.address, _appointmentTime);

            // -> Evaluator accept Appoitment
            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(ListAppointment.SECONDID, _appointmentTime);

            // -> Evaluator evaluated Asset
            await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
                ListAppointment.SECONDID, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);

            // -> customer accept evaluation 
            await _hardEvaluationContract.connect(_borrower).acceptEvaluation(EvaluationList.SECONDID);

            // -> Evaluator mint NFT for Customer
            await _hardEvaluationContract.connect(_evaluator).createNftToken(EvaluationList.SECONDID, 1, "NFTCID");

            // approve
            await _DFYHard721Contract.connect(_borrower).approve(_pawnNFTContract.address, NFTOfBorrower.SECONDNFT);

            // Borrower put on pawn 
            await _pawnNFTContract.connect(_borrower).putOnPawn(_DFYHard721Contract.address, NFTOfBorrower.SECONDNFT, BigInt(1 * 10 ** 18),
                _loanTokenContract.address, 1, 3, LoanDurationType.WEEK, 0);

            // Lender create offer 
            await _pawnNFTContract.connect(_lender).createOffer(NFTCollateral.SECONDID, _DFYHard721Contract.address, _loanAmount, _interest, _duration,
                LoanDurationType.WEEK, LoanDurationType.WEEK);

            // Borrower cancel offer from lender
            let getEventAcceptOffer = await _pawnNFTContract.connect(_borrower).cancelOffer(ListOffer.SECONDID, NFTCollateral.SECONDID);
            let reciptEventAcceptOffer = await getEventAcceptOffer.wait();
            console.log(`\x1b[31m event reject offer :\x1b[0m`);
            console.log(reciptEventAcceptOffer.events[0]);
        });

        it(`Case 3: lender itself cancel offer\n\r`, async () => {

            // customer create asset request 
            await _hardEvaluationContract.connect(_borrower).createAssetRequest(_assetCID, _DFYHard721Contract.address, BigInt(10000 * 10 ** 18),
                _loanTokenContract.address, CollectionStandard.ERC721, _beAssetId);

            // -> customer create Appointment 
            await _hardEvaluationContract.connect(_borrower).createAppointment(ListAssetRequest.THIRDID, _evaluator.address, _loanTokenContract.address, _appointmentTime);

            // -> Evaluator accept Appoitment
            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(ListAppointment.THIRDID, _appointmentTime);

            // -> Evaluator evaluated Asset
            await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
                ListAppointment.THIRDID, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);

            // -> customer accept evaluation 
            await _hardEvaluationContract.connect(_borrower).acceptEvaluation(EvaluationList.THIRDID);

            // -> Evaluator mint NFT for Customer
            await _hardEvaluationContract.connect(_evaluator).createNftToken(EvaluationList.THIRDID, 1, "NFTCID");

            // approve
            await _DFYHard721Contract.connect(_borrower).approve(_pawnNFTContract.address, NFTOfBorrower.THIRDNFT);

            // Borrower put on pawn 
            await _pawnNFTContract.connect(_borrower).putOnPawn(_DFYHard721Contract.address, NFTOfBorrower.THIRDNFT, BigInt(1 * 10 ** 18),
                _loanTokenContract.address, 1, 3, LoanDurationType.WEEK, 0);

            // Lender create offer 
            await _pawnNFTContract.connect(_lender).createOffer(NFTOfBorrower.THIRDNFT, _DFYHard721Contract.address,
                _loanAmount, _interest, _duration,
                LoanDurationType.WEEK, LoanDurationType.WEEK);


            // lender cancel offer 
            let getEventAcceptOffer = await _pawnNFTContract.connect(_lender).cancelOffer(NFTOfBorrower.THIRDNFT, NFTCollateral.THIRDID);
            let reciptEventAcceptOffer = await getEventAcceptOffer.wait();
            console.log(`\x1b event cancel offer :  \x1b[0m`);
            console.log(reciptEventAcceptOffer.events);

        });

        it(`Case 4: borrower withdrawCollateral after put on pawn \n\r`, async () => {

            // customer create asset request 
            await _hardEvaluationContract.connect(_borrower).createAssetRequest(_assetCID, _DFYHard721Contract.address, BigInt(100 * 10 ** 18),
                _loanTokenContract.address, CollectionStandard.ERC721, _beAssetId);

            // -> customer create Appointment 
            await _hardEvaluationContract.connect(_borrower).createAppointment(ListAssetRequest.FOURDID, _evaluator.address, _loanTokenContract.address, _appointmentTime);

            // -> Evaluator accept Appoitment
            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(ListAssetRequest.FOURDID, _appointmentTime);

            // -> Evaluator evaluated Asset
            await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
                ListAssetRequest.FOURDID, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);

            // -> customer accept evaluation 
            await _hardEvaluationContract.connect(_borrower).acceptEvaluation(EvaluationList.FOURDID);

            // -> Evaluator mint NFT for Customer
            await _hardEvaluationContract.connect(_evaluator).createNftToken(EvaluationList.FOURDID, 1, "NFTCID");

            // approve
            await _DFYHard721Contract.connect(_borrower).approve(_pawnNFTContract.address, NFTOfBorrower.FOURNFT);

            // Borrower put on pawn 
            await _pawnNFTContract.connect(_borrower).putOnPawn(_DFYHard721Contract.address, NFTOfBorrower.FOURNFT, BigInt(1 * 10 ** 18),
                _loanTokenContract.address, 1, 3, LoanDurationType.WEEK, 0);

            // Lender create offer 
            await _pawnNFTContract.connect(_lender).createOffer(NFTCollateral.FOURDID, _DFYHard721Contract.address, _loanAmount, _interest, _duration,
                LoanDurationType.WEEK, LoanDurationType.WEEK);

            // Borrower withdrawCollateral NFT 
            let getEventWithdraw = await _pawnNFTContract.connect(_borrower).withdrawCollateral(NFTCollateral.FOURDID);
            let reciptEventWithdraw = await getEventWithdraw.wait();
            console.log(`\x1b after put on pawn  :  \x1b[0m`);
            let ownerToken = await _DFYHard721Contract.ownerOf(NFTOfBorrower.FOURNFT);
            expect(ownerToken).to.equal(_borrower.address);

            let collateralOffersMapping = await _pawnNFTContract.collateralOffersMapping(NFTCollateral.FOURDID);
            console.log(collateralOffersMapping);
            expect(collateralOffersMapping).to.equal(false);
            console.log(`\x1b[36m event cancel offer :  \x1b[0m`);
            console.log(reciptEventWithdraw.events[2]);

            console.log(`\x1b[36m event withdraw :  \x1b[0m`);
            console.log(reciptEventWithdraw.events[3]);

            console.log(`\x1b[36m list collateral :  \x1b[0m`);
            console.log(reciptEventWithdraw.events[3].args[1]);
            expect(reciptEventWithdraw.events[3].args[1].status).to.equal(CollateralStatus.CANCEL);
        });

        it(`Case 5: list offer , borrower accept an offer  \n\r`, async () => {

            // customer create asset request 
            await _hardEvaluationContract.connect(_borrower).createAssetRequest(_assetCID, _DFYHard721Contract.address, BigInt(1000 * 10 ** 18),
                _loanTokenContract.address, CollectionStandard.ERC721, _beAssetId);

            // -> customer create Appointment 
            await _hardEvaluationContract.connect(_borrower).createAppointment(ListAssetRequest.FIVEID, _evaluator.address, _loanTokenContract.address, _appointmentTime);

            // -> Evaluator accept Appoitment
            await _hardEvaluationContract.connect(_evaluator).acceptAppointment(ListAssetRequest.FIVEID, _appointmentTime);

            // -> Evaluator evaluated Asset
            await _hardEvaluationContract.connect(_evaluator).evaluateAsset(_DFYHard721Contract.address,
                ListAppointment.FIVEID, BigInt(10 * 10 ** 18), "_evaluationCID", BigInt(1 * 10 ** 5), _loanTokenContract.address, _beEvaluationId);

            // -> customer accept evaluation 
            await _hardEvaluationContract.connect(_borrower).acceptEvaluation(EvaluationList.FIVEID);

            // -> Evaluator mint NFT for Customer
            await _hardEvaluationContract.connect(_evaluator).createNftToken(EvaluationList.FIVEID, 1, "NFTCID");

            // approve
            await _DFYHard721Contract.connect(_borrower).approve(_pawnNFTContract.address, NFTOfBorrower.FIVENFT);

            // Borrower put on pawn 
            await _pawnNFTContract.connect(_borrower).putOnPawn(_DFYHard721Contract.address, NFTOfBorrower.FIVENFT, BigInt(1 * 10 ** 18),
                _loanTokenContract.address, 1, 4, LoanDurationType.WEEK, 0);

            // Lender create offer 
            let getEventCreateOffer = await _pawnNFTContract.connect(_lender).createOffer(NFTCollateral.FIVEID, _DFYHard721Contract.address, BigInt(1 * 10 ** 18), _interest, _duration,
                LoanDurationType.WEEK, LoanDurationType.WEEK);
            let reciptEventCreateOffer = await getEventCreateOffer.wait();
            console.log(reciptEventCreateOffer.events[0]);

            // LenderB create offer 
            let getEventCreateOfferB = await _pawnNFTContract.connect(_lenderB).createOffer(NFTCollateral.FIVEID, _DFYHard721Contract.address, BigInt(2 * 10 ** 18), _interest, _duration,
                LoanDurationType.WEEK, LoanDurationType.WEEK);
            let reciptEventCreateOfferB = await getEventCreateOfferB.wait();
            console.log(reciptEventCreateOfferB.events[0]);

            let balanceOfLenderBeforeAcceptOffer = await _loanTokenContract.balanceOf(_lender.address);
            let balanceOfLenderBBeforeAcceptOffer = await _loanTokenContract.balanceOf(_lenderB.address);
            let balanceOfBorrowerBeforeAcceptOffer = await _loanTokenContract.balanceOf(_borrower.address);
            console.log("balance of borrower before accept offer :", balanceOfBorrowerBeforeAcceptOffer.toString());
            console.log("balance of lender before accept offer : ", balanceOfLenderBeforeAcceptOffer.toString());
            console.log("balance of lenderB before accept offer : ", balanceOfLenderBBeforeAcceptOffer.toString());

            // Borrower accept offer B 
            let getEventAcceptOffer = await _pawnNFTContract.connect(_borrower).acceptOffer(NFTCollateral.FIVEID, ListOffer.SIXID);
            let reciptEventAcceptOffer = await getEventAcceptOffer.wait();
            console.log(`\x1b[36m event borrower accept offer :  \x1b[0m`);
            console.log(reciptEventAcceptOffer.events);
            console.log(`\x1b[36m event rejectOfferEvent :  \x1b[0m`);
            console.log(reciptEventAcceptOffer.events[2]);

            let balanceOfBorrowerAfterAcceptOffer = await _loanTokenContract.balanceOf(_borrower.address);
            let balanceOfLenderAfterAcceptOffer = await _loanTokenContract.balanceOf(_lender.address);
            let balanceOfLenderBAfterAcceptOffer = await _loanTokenContract.balanceOf(_lenderB.address);
            let allowance = await _loanTokenContract.allowance(_lender.address, _pawnNFTContract.address);

            console.log("allowance : ", allowance.toString()); // return amount owner approve for spender 
            console.log("balance of borrower After accept offer :", balanceOfBorrowerAfterAcceptOffer.toString());
            console.log("balance of lender After accept offer : ", balanceOfLenderAfterAcceptOffer.toString());
            console.log("balance of lenderB After accept offer : ", balanceOfLenderBAfterAcceptOffer.toString())
            expect(balanceOfBorrowerBeforeAcceptOffer).to.equal(BigInt(balanceOfBorrowerAfterAcceptOffer) - BigInt(2 * 10 ** 18));
            expect(balanceOfLenderBBeforeAcceptOffer).to.equal(BigInt(balanceOfLenderBAfterAcceptOffer) + BigInt(2 * 10 ** 18));
            expect(balanceOfLenderBeforeAcceptOffer).to.equal(BigInt(balanceOfLenderAfterAcceptOffer));

            let getOfferB = await _pawnNFTContract.getOffer(NFTCollateral.FIVEID, ListOffer.SIXID);
            console.log("offer B", getOfferB);

            console.log(`\x1b[36m sau khi borrower accept offer B thì xóa offer A đi :\x1b[0m`);
            let getOfferA = await _pawnNFTContract.getOffer(NFTCollateral.FIVEID, ListOffer.FIVEID);
            console.log("offer A", getOfferA);
        });

    });
});