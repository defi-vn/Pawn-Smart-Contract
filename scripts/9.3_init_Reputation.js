require('@nomiclabs/hardhat-ethers');
const hre = require('hardhat');

const { Proxies, PawnConfig } = require('./.deployment_data.json');
const proxies = Proxies.Beta;

const RepuProxyAddr     = proxies.REPUTATION_CONTRACT_ADDRESS;
const PawnP2PProxyAddr  = proxies.PAWN_CONTRACT_ADDRESS;
const LoanP2PProxyAddr  = proxies.PAWN_P2PLOAN_CONTRACT_ADDRESS;
const PawnNFTProxyAddr  = proxies.PAWN_NFT_CONTRACT_ADDRESS;
const LoanNFTProxyAddr  = proxies.PAWN_NFPLOAN_CONTRACT_ADDRESS;

const RepuBuildName     = "contracts/reputation/v102/Reputation.sol:Reputation"

const decimals           = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("============================================================");
    console.log(`Initialize contracts with the account: ${deployer.address}`);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================");

    const RepuFactory   = await hre.ethers.getContractFactory(RepuBuildName);
    const RepuArtifact  = await hre.artifacts.readArtifact(RepuBuildName);
    const RepuContract  = RepuFactory.attach(RepuProxyAddr);

    // Config Reputation contract
    console.log(`Initializing ${RepuArtifact.contractName}...`);

    // Set white listed contract caller
    console.log(`Adding Whitelisted contract caller:`);
    await RepuContract.addWhitelistedContractCaller(PawnP2PProxyAddr);
    console.log(`\tPawn P2P Contract: ${PawnP2PProxyAddr}\n\r`);

    await RepuContract.addWhitelistedContractCaller(LoanP2PProxyAddr);
    console.log(`\tLoan P2P Contract: ${LoanP2PProxyAddr}\n\r`);

    await RepuContract.addWhitelistedContractCaller(PawnNFTProxyAddr);
    console.log(`\tPawn NFT Contract: ${PawnNFTProxyAddr}\n\r`);

    // await RepuContract.addWhitelistedContractCaller(LoanNFTProxyAddr);
    // console.log(`\tLoan NFT Contract: ${LoanNFTProxyAddr}\n\r`);

    // Grant Roles to admin
    // console.log(`Setting Roles to ADMIN account: ${PawnConfig.Admin}`);
    // await RepuContract.grantRole(PawnConfig.DEFAULT_ADMIN_ROLE, PawnConfig.Admin);
    // await RepuContract.grantRole(PawnConfig.PAUSER_ROLE, PawnConfig.Admin);
    // console.log(`Roles granted: 
    //             \n\r\t${PawnConfig.DEFAULT_ADMIN_ROLE}, 
    //             \n\r\t${PawnConfig.OPERATOR_ROLE}, 
    //             \n\r\t${PawnConfig.PAUSER_ROLE}`);

    console.log("============================================================\n\r");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });