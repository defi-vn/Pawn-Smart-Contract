const hre = require('hardhat');
const RepuBuildName = "contracts/pawn/reputation/Reputation.sol:Reputation";
const proxyType = { kind: "uups" };
const decimals  = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();
  
    console.log("============================================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================\n\r");
  
    const RepuFactory   = await hre.ethers.getContractFactory(RepuBuildName);
    const RepuArtifact  = await hre.artifacts.readArtifact(RepuBuildName);

    const RepuContract  = await hre.upgrades.deployProxy(RepuFactory, proxyType);
    
    await RepuContract.deployed();

    console.log(`REPUTATION_CONTRACT_ADDRESS: ${RepuContract.address}`);

    const implementationAddress = await hre.upgrades.erc1967.getImplementationAddress(RepuContract.address);
    console.log(`${RepuArtifact.contractName} implementation address: ${implementationAddress}`);
    
    console.log("============================================================\n\r");
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });