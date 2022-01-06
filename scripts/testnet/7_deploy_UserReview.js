require("@openzeppelin/hardhat-upgrades");

const hre = require('hardhat');
const { Proxies } = require('./.deployment_data.json');
const proxies = Proxies.Beta;

const ReviewBuildName = "contracts/pawn/reputation/UserReview.sol:UserReview";
const proxyType = { kind: "uups" };
const decimals  = 10**18;

const HubProxyAddr = proxies.HUB_CONTRACT_ADDRESS;
const HubBuildName = "Hub";

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
            HubProxyAddr
        ],
        proxyType
    );
    
    await ReviewContract.deployed();

    const signature = await ReviewContract.signature();
    console.log(`USERREVIEW_CONTRACT_ADDRESS: ${ReviewContract.address}`);
    console.log(`Signature: \x1b[36m${signature}\x1b[0m`);

    const implementationAddress = await hre.upgrades.erc1967.getImplementationAddress(ReviewContract.address);
    console.log(`${ReviewArtifact.contractName} implementation address: ${implementationAddress}`);

    const HubFactory = await hre.ethers.getContractFactory(HubBuildName);
    const HubArtifact = await hre.artifacts.readArtifact(HubBuildName);
    const HubContract = HubFactory.attach(HubProxyAddr);

    console.log(`HUB_ADDRESS: \x1b[31m${HubContract.address}\x1b[0m`);
    console.log(`Registering \x1b[36m${ReviewArtifact.contractName}\x1b[0m to \x1b[31m${HubArtifact.contractName}\x1b[0m...`);

    await HubContract.registerContract(signature,ReviewContract.address,ReviewArtifact.contractName);
    
    console.log("============================================================\n\r");
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });