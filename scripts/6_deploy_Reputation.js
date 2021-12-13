const hre = require('hardhat');
const { Proxies } = require('./.deployment_data.json');
const RepuBuildName = "contracts/pawn/reputation/Reputation.sol:Reputation";
const proxyType = { kind: "uups" };
const decimals  = 10**18;

const proxies = Proxies.Dev2;

const HubProxyAddr = proxies.HUB_CONTRACT_ADDRESS;
const HubBuildName = "Hub";

async function main() {
    const [deployer] = await hre.ethers.getSigners();
  
    console.log("============================================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================\n\r");
  
    const RepuFactory   = await hre.ethers.getContractFactory(RepuBuildName);
    const RepuArtifact  = await hre.artifacts.readArtifact(RepuBuildName);

    const RepuContract  = await hre.upgrades.deployProxy(RepuFactory,[HubProxyAddr], proxyType);
    
    await RepuContract.deployed();

    const signature = await RepuContract.signature();
    console.log(`REPUTATION_CONTRACT_ADDRESS: ${RepuContract.address}`);
     console.log(`Signature: \x1b[36m${signature}\x1b[0m`);

    const implementationAddress = await hre.upgrades.erc1967.getImplementationAddress(RepuContract.address);
    console.log(`${RepuArtifact.contractName} implementation address: ${implementationAddress}`);
    
    const HubFactory = await hre.ethers.getContractFactory(HubBuildName);
    const HubArtifact = await hre.artifacts.readArtifact(HubBuildName);
    const HubContract = HubFactory.attach(HubProxyAddr);

    console.log(`HUB_ADDRESS: \x1b[31m${HubContract.address}\x1b[0m`);
    console.log(`Registering \x1b[36m${RepuArtifact.contractName}\x1b[0m to \x1b[31m${HubArtifact.contractName}\x1b[0m...`);

    await HubContract.registerContract(signature,RepuContract.address,RepuArtifact.contractName);
    console.log("============================================================\n\r");
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });