require('@nomiclabs/hardhat-ethers');
require('@openzeppelin/hardhat-upgrades');

const hre = require('hardhat');

const { Proxies } = require('./.deployment_data_prelive.json');
const proxies = Proxies.Prelive;

const ReviewProxyAddr     = proxies.USERREVIEW_CONTRACT_ADDRESS;
const ReviewBuildNameV1   = "contracts/pawn/reputation/UserReview.sol:UserReview";
const ReviewBuildNameV2   = "contracts/pawn/reputation/UserReview.sol:UserReview";

const decimals          = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("============================================================");
    console.log("Upgrading contracts with the account:", deployer.address);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================");

    const ReviewFactoryV1     = await hre.ethers.getContractFactory(ReviewBuildNameV1);
    const ReviewArtifactV1    = await hre.artifacts.readArtifact(ReviewBuildNameV1);
    const ReviewContractV1    = ReviewFactoryV1.attach(ReviewProxyAddr);

    const ReviewImplV1        = await hre.upgrades.erc1967.getImplementationAddress(ReviewContractV1.address);

    console.log(`Upgrading ${ReviewArtifactV1.contractName} at proxy: ${ReviewContractV1.address}`);
    console.log(`Current implementation address: ${ReviewImplV1}`);

    const ReviewFactoryV2      = await hre.ethers.getContractFactory(ReviewBuildNameV2);
    const ReviewArtifactV2     = await hre.artifacts.readArtifact(ReviewBuildNameV2);
    
    const ReviewContractV2     = await hre.upgrades.upgradeProxy(ReviewProxyAddr, ReviewFactoryV2);
    
    await ReviewContractV2.deployed();
    
    const ReviewImplV2         = await hre.upgrades.erc1967.getImplementationAddress(ReviewContractV2.address);

    console.log(`${ReviewArtifactV2.contractName} deployed to: ${ReviewContractV2.address}`);
    console.log(`New implementation Address: ${ReviewImplV2}`);

    console.log("============================================================\n\r");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });