require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { Proxies } = require('./.deployment_data_prelive.json');

const LoanNFTBuildName = "LoanNFTContract";

const proxyType = { kind: "uups" };
const proxies = Proxies.Prelive;

const HubProxyAddr = proxies.HUB_CONTRACT_ADDRESS;
const HubBuildName = "Hub";
const decimals = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();

    console.log("=================================\n\r");
    console.log("Deploying contraqct with the account:", deployer.address);
    console.log("Account balance:", ((await deployer.getBalance()) / decimals).toString());
    console.log("================================\n\r");

    const LoanNFTFactory = await hre.ethers.getContractFactory(LoanNFTBuildName);
    const LoanNFTArtifact = await hre.artifacts.readArtifact(LoanNFTBuildName);
    const LoanNFTContract = await hre.upgrades.deployProxy(LoanNFTFactory,[HubProxyAddr], proxyType);

    await LoanNFTContract.deployed();
    const signature = await LoanNFTContract.signature();

    console.log(`Loan_NFT_CONTRACT_ADDRESS: ${LoanNFTContract.address}`);
     console.log(`Signature: \x1b[36m${signature}\x1b[0m`);

    implementationAddress = await hre.upgrades.erc1967.getImplementationAddress(LoanNFTContract.address);
    console.log(`${LoanNFTArtifact.contractName} implementation address: ${implementationAddress}`);

    const HubFactory = await hre.ethers.getContractFactory(HubBuildName);
    const HubArtifact = await hre.artifacts.readArtifact(HubBuildName);
    const HubContract = HubFactory.attach(HubProxyAddr);

    console.log(`HUB_ADDRESS: \x1b[31m${HubContract.address}\x1b[0m`);
    console.log(`Registering \x1b[36m${LoanNFTArtifact.contractName}\x1b[0m to \x1b[31m${HubArtifact.contractName}\x1b[0m...`);

    await HubContract.registerContract(signature,LoanNFTContract.address,LoanNFTArtifact.contractName);
    console.log("===========================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })