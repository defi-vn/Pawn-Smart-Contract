require('@nomiclabs/hardhat-ethers');
const hre = require('hardhat');

const { PawnConfig, Proxies } = require('./.deployment_data.json');
const proxies = Proxies.Test1;

const NFTProxyAddr      = proxies.NFT_CONTRACT_ADDRESS;
const EvaProxyAddr      = proxies.EVALUATION_CONTRACT_ADDRESS;
const PawnNFTProxyAddr  = proxies.PAWN_NFT_CONTRACT_ADDRESS;
const RepuProxyAddr     = proxies.REPUTATION_CONTRACT_ADDRESS;
const NFTBuildName      = "DFY_Physical_NFTs";
const EvaBuildName      = "AssetEvaluation";
const PawnNFTBuildName  = "PawnNFTContract";
const RepuBuildName     = "Reputation";

const lateThreshold     = 3;
const penaltyRate       = 15000000;
const prepaidFeeRate    = 300000;
const systemFeeRate     = 2000000;
const operator          = PawnConfig.Operator; // Backend operator
const feeWallet         = PawnConfig.FeeWallet;

const decimals           = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("============================================================");
    console.log(`Initialize contracts with the account: ${deployer.address}`);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================");

    const PawnNFTFactory   = await hre.ethers.getContractFactory(PawnNFTBuildName);
    const PawnNFTArtifact  = await hre.artifacts.readArtifact(PawnNFTBuildName);
    const PawnNFTContract  = PawnNFTFactory.attach(PawnNFTProxyAddr);

    const NFTFactory    = await hre.ethers.getContractFactory(NFTBuildName);
    const NFTArtifact   = await hre.artifacts.readArtifact(NFTBuildName);
    const NFTContract   = NFTFactory.attach(NFTProxyAddr);
    
    const EvaFactory    = await hre.ethers.getContractFactory(EvaBuildName);
    const EvaArtifact   = await hre.artifacts.readArtifact(EvaBuildName);
    const EvaContract   = EvaFactory.attach(EvaProxyAddr);

    const RepuFactory   = await hre.ethers.getContractFactory(RepuBuildName);
    const RepuArtifact  = await hre.artifacts.readArtifact(RepuBuildName);
    const RepuContract  = RepuFactory.attach(RepuProxyAddr);
    
    console.log(`Initializing ${PawnNFTArtifact.contractName}...`);
    console.log(`Setting Fee wallet...`);
    await PawnNFTContract.setFeeWallet(feeWallet);
    console.log(`Fee wallet set at: ${feeWallet}\n\r`);

    console.log(`Setting contract operator...`);
    await PawnNFTContract.setOperator(operator);
    console.log(`Contract operator: ${operator}\n\r`);

    console.log(`Setting Late threshold...`);
    await PawnNFTContract.setLateThreshold(lateThreshold);
    console.log(`Late threshold: ${lateThreshold}\n\r`);

    console.log(`Setting Penalty rate...`);
    await PawnNFTContract.setPenaltyRate(penaltyRate);
    console.log(`Penalty rate: ${penaltyRate}\n\r`);

    console.log(`Setting Prepaid fee rate...`);
    await PawnNFTContract.setPrepaidFeeRate(prepaidFeeRate);
    console.log(`Prepaid fee rate: ${prepaidFeeRate}\n\r`);

    console.log(`Setting System fee rate...`);
    await PawnNFTContract.setSystemFeeRate(systemFeeRate);
    console.log(`System fee rate: ${systemFeeRate}\n\r`);

    console.log(`Setting Whitelisted NFT collateral...`);
    await PawnNFTContract.setWhitelistCollateral(proxies.NFT_CONTRACT_ADDRESS, 1);
    console.log(`\tWhitelisted token as collateral: ${proxies.NFT_CONTRACT_ADDRESS}`);

    console.log("============================================================\n\r");

    console.log(`Initializing ${NFTArtifact.contractName}...`);
    console.log(`Setting Evaluation contract...`);
    await NFTContract.setEvaluationContract(EvaProxyAddr);
    console.log(`Evaluation contract address: ${EvaProxyAddr}`);

    console.log("============================================================\n\r");

    console.log(`Initializing ${EvaArtifact.contractName}...`);
    console.log(`Setting Fee wallet...`);
    await EvaContract.setFeeWallet(PawnConfig.FeeWallet);
    console.log(`Fee wallet address: ${PawnConfig.FeeWallet}`);

    console.log(`Setting Operator address...`);
    await EvaContract.grantRole(PawnConfig.OPERATOR_ROLE, PawnConfig.EvaluationOperator);
    console.log(`Operator address: ${PawnConfig.EvaluationOperator}`);

    console.log("============================================================\n\r");
    
    console.log(`Initializing ${RepuArtifact.contractName}...`);
    console.log(`Setting contract caller...`);
    await RepuContract.addWhitelistedContractCaller(PawnNFTProxyAddr);
    console.log(`Contract caller set at address: ${PawnNFTArtifact.contractName} - ${PawnNFTProxyAddr}\n\r`);
    
    console.log("============================================================\n\r");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });