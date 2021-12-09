require('@nomiclabs/hardhat-ethers');
require('@openzeppelin/hardhat-upgrades');

const hre = require('hardhat');

const { Proxies } = require('./.deployment_data.json');
const proxies = Proxies.Staging;

const RepuProxyAddr     = proxies.REPUTATION_CONTRACT_ADDRESS;
const RepuBuildNameV1   = "contracts/pawn/reputation/Reputation.sol:Reputation";
const RepuBuildNameV2   = "contracts/pawn/reputation/Reputation.sol:Reputation";

const decimals          = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("============================================================");
    console.log("Upgrading contracts with the account:", deployer.address);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================");

    const RepuFactoryV1     = await hre.ethers.getContractFactory(RepuBuildNameV1);
    const RepuArtifactV1    = await hre.artifacts.readArtifact(RepuBuildNameV1);
    const RepuContractV1    = RepuFactoryV1.attach(RepuProxyAddr);

    const RepuImplV1        = await hre.upgrades.erc1967.getImplementationAddress(RepuContractV1.address);

    console.log(`Upgrading ${RepuArtifactV1.contractName} at proxy: ${RepuContractV1.address}`);
    console.log(`Current implementation address: ${RepuImplV1}`);

    const RepuFactoryV2      = await hre.ethers.getContractFactory(RepuBuildNameV2);
    const RepuArtifactV2     = await hre.artifacts.readArtifact(RepuBuildNameV2);
    
    const RepuContractV2     = await hre.upgrades.upgradeProxy(RepuProxyAddr, RepuFactoryV2);
    
    await RepuContractV2.deployed();
    
    const RepuImplV2         = await hre.upgrades.erc1967.getImplementationAddress(RepuContractV2.address);

    console.log(`${RepuArtifactV2.contractName} deployed to: ${RepuContractV2.address}`);
    console.log(`New implementation Address: ${RepuImplV2}`);

    console.log("============================================================\n\r");

    console.log("Initialize Reward points by Reason...");
    await RepuContractV2.initializeRewardByReason();
    console.log("Completed.");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });