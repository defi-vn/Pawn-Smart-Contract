require("@openzeppelin/hardhat-upgrades");

const hre = require('hardhat');
const { Proxies } = require('./.deployment_data.json');
const proxies = Proxies.Beta;

const ReviewBuildName = "contracts/pawn/reputation/UserReview.sol:UserReview";
const proxyType = { kind: "uups" };
const decimals  = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();
  
    console.log("============================================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================\n\r");
  
    const ReviewFactory   = await hre.ethers.getContractFactory(ReviewBuildName);
    const ReviewArtifact  = await hre.artifacts.readArtifact(ReviewBuildName);

    const ReviewContract  = await hre.upgrades.deployProxy(
        ReviewFactory, 
        [
            proxies.PAWN_CONTRACT_ADDRESS, 
            proxies.PAWN_P2PLOAN_CONTRACT_ADDRESS,
            proxies.REPUTATION_CONTRACT_ADDRESS
        ],
        proxyType
    );
    
    await ReviewContract.deployed();

    console.log(`USERREVIEW_CONTRACT_ADDRESS: ${ReviewContract.address}`);

    const implementationAddress = await hre.upgrades.erc1967.getImplementationAddress(ReviewContract.address);
    console.log(`${ReviewArtifact.contractName} implementation address: ${implementationAddress}`);
    
    console.log("============================================================\n\r");
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });