require('@nomiclabs/hardhat-ethers');
const hre = require('hardhat');

const { PawnConfig, Proxies, Tokens } = require('./.deployment_data_prelive.json');
const proxies = Proxies.Prelive;

const LoanProxyAddr     = proxies.PAWN_P2PLOAN_CONTRACT_ADDRESS;
const LoanBuildName     = "contracts/pawn/pawn-p2p-v2/PawnP2PLoanContract.sol:PawnP2PLoanContract";

const RepuProxyAddr     = proxies.REPUTATION_CONTRACT_ADDRESS;
const RepuBuildName     = "contracts/pawn/reputation/Reputation.sol:Reputation";

const ExchangeProxyAddr = proxies.EXCHANGE_CONTRACT_ADDRESS;
const PawnProxyAddr     = proxies.PAWN_CONTRACT_ADDRESS;

// const zoom              = 100000; // Initialized on proxy deployment
const lateThreshold     = PawnConfig.LateThreshold;
const penaltyRate       = PawnConfig.PenaltyRate;
const prepaidFeeRate    = PawnConfig.PrepaidFee;
const systemFeeRate     = PawnConfig.SystemFee;
const operator          = PawnConfig.Operator;
const feeWallet         = PawnConfig.FeeWallet;

const decimals          = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("============================================================");
    console.log(`Initialize contracts with the account: ${deployer.address}`);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================");

    const LoanFactory   = await hre.ethers.getContractFactory(LoanBuildName);
    const LoanArtifact  = await hre.artifacts.readArtifact(LoanBuildName);
    const LoanContract  = LoanFactory.attach(LoanProxyAddr);

    const RepuFactory   = await hre.ethers.getContractFactory(RepuBuildName);
    const RepuArtifact  = await hre.artifacts.readArtifact(RepuBuildName);
    const RepuContract  = RepuFactory.attach(RepuProxyAddr);

    console.log("Initializing...");
    console.log(`Setting Fee wallet...`);
    await LoanContract.setFeeWallet(feeWallet);
    console.log(`Fee wallet set at: ${feeWallet}\n\r`);

    console.log(`Setting contract operator...`);
    await LoanContract.setOperator(operator);
    console.log(`Contract operator: ${operator}\n\r`);

    console.log(`Setting Late threshold...`);
    await LoanContract.setLateThreshold(lateThreshold);
    console.log(`Late threshold: ${lateThreshold}\n\r`);

    console.log(`Setting Penalty rate...`);
    await LoanContract.setPenaltyRate(penaltyRate);
    console.log(`Penalty rate: ${penaltyRate}\n\r`);

    console.log(`Setting Prepaid fee rate...`);
    await LoanContract.setPrepaidFeeRate(prepaidFeeRate);
    console.log(`Prepaid fee rate: ${prepaidFeeRate}\n\r`);

    console.log(`Setting System fee rate...`);
    await LoanContract.setSystemFeeRate(systemFeeRate);
    console.log(`System fee rate: ${systemFeeRate}\n\r`);

    console.log(`Setting Reputation contract...`);
    await LoanContract.setReputationContract(RepuProxyAddr);
    console.log(`Reputation contract set at address: ${RepuProxyAddr}\n\r`);

    console.log(`Setting Exchange contract...`);
    await LoanContract.setExchangeContract(ExchangeProxyAddr);
    console.log(`Exchange contract set at address: ${ExchangeProxyAddr}\n\r`);

    console.log(`Setting Pawn contract address...`);
    await LoanContract.setPawnContract(PawnProxyAddr);
    console.log(`Pawn contract set at address: ${PawnProxyAddr}`);
    
    // console.log(`Setting Pawn contract as operator...`);
    // await LoanContract.setOperator(PawnProxyAddr);
    // console.log(`Pawn contract as operator: ${PawnProxyAddr}\n\r`);

    console.log(`Setting Whitelisted collateral...`);
    for await (let token of Tokens) {
        if(token.Address != "0x0000000000000000000000000000000000000000") {
            await LoanContract.setWhitelistCollateral(token.Address, 1);
            console.log(`\tWhitelisted token as collateral: ${token.Symbol}: ${token.Address}`);
        }
    }

    console.log("============================================================\n\r");
    console.log(`Initializing ${RepuArtifact.contractName}...`);
    console.log(`Setting contract caller...`);
    await RepuContract.addWhitelistedContractCaller(LoanProxyAddr);
    console.log(`Contract caller set at address: ${LoanArtifact.contractName} - ${LoanProxyAddr}\n\r`);

    console.log("============================================================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });