require('@nomiclabs/hardhat-ethers');
const hre = require('hardhat');

const { PawnConfig, Proxies } = require('./.deployment_data.json');
const proxies = Proxies.Dev2;

const NFTProxyAddr      = proxies.NFT_CONTRACT_ADDRESS;
const PawnNFTProxyAddr  = proxies.PAWN_NFT_CONTRACT_ADDRESS;
const RepuProxyAddr     = proxies.REPUTATION_CONTRACT_ADDRESS;
const PawnNFTBuildName  = "PawnNFTContract";

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
    
    // Config Pawn NFT contract
    console.log(`Initializing ${PawnNFTArtifact.contractName}...`);

    // Set Fee wallet
    console.log(`Setting Fee wallet...`);
    await PawnNFTContract.setFeeWallet(feeWallet);
    console.log(`Fee wallet set at: ${feeWallet}\n\r`);

    // Set contract operator (backend)
    console.log(`Setting contract operator...`);
    await PawnNFTContract.setOperator(operator);
    console.log(`Contract operator: ${operator}\n\r`);

    // Set late threshold
    console.log(`Setting Late threshold...`);
    await PawnNFTContract.setLateThreshold(lateThreshold);
    console.log(`Late threshold: ${lateThreshold}\n\r`);

    // Set penalty rate
    console.log(`Setting Penalty rate...`);
    await PawnNFTContract.setPenaltyRate(penaltyRate);
    console.log(`Penalty rate: ${penaltyRate}\n\r`);

    // Set prepaid fee
    console.log(`Setting Prepaid fee rate...`);
    await PawnNFTContract.setPrepaidFeeRate(prepaidFeeRate);
    console.log(`Prepaid fee rate: ${prepaidFeeRate}\n\r`);

    // Set system fee
    console.log(`Setting System fee rate...`);
    await PawnNFTContract.setSystemFeeRate(systemFeeRate);
    console.log(`System fee rate: ${systemFeeRate}\n\r`);
    
    // Set Reputation contract
    console.log(`Setting Reputation contract...`);
    await PawnNFTContract.setReputationContract(RepuProxyAddr);
    console.log(`Reputation contract set at: ${RepuProxyAddr}\n\r`);

    // Set NFT contract as whitelisted collateral
    console.log(`Setting Whitelisted NFT collateral...`);
    await PawnNFTContract.setWhitelistCollateral(NFTProxyAddr, 1);
    console.log(`Whitelisted token as collateral: ${NFTProxyAddr}\n\r`);

    // Grant Roles to admin
    // console.log(`Setting Roles to ADMIN account: ${PawnConfig.Admin}`);
    // await PawnNFTContract.grantRole(PawnConfig.DEFAULT_ADMIN_ROLE, PawnConfig.Admin);
    // await PawnNFTContract.grantRole(PawnConfig.PAUSER_ROLE, PawnConfig.Admin);
    // console.log(`Roles granted: 
    //             \t${PawnConfig.DEFAULT_ADMIN_ROLE}, 
    //             \t${PawnConfig.PAUSER_ROLE}\n\r`);

    console.log("============================================================\n\r");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });