const hre = require('hardhat');

const { Proxies } = require('./.deployment_data.json');
const proxies = Proxies.Beta;

const PawnProxyAddr     = proxies.PAWN_CONTRACT_ADDRESS;
const PawnBuildName     = "contracts/pawn/pawn-p2p/PawnContract.sol:PawnContract";
const ProxyBuildName    = "AdminUpgradeabilityProxy";

const decimals  = 10**18;

async function main() {
    const [deployer, proxyAdmin] = await hre.ethers.getSigners();
  
    console.log("============================================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================\n\r");
  
    const PawnFactory   = await hre.ethers.getContractFactory(PawnBuildName);
    const PawnArtifact  = await hre.artifacts.readArtifact(PawnBuildName);

    const PawnContract  = await PawnFactory.deploy();
    
    await PawnContract.deployed();
  
    console.log(`${PawnArtifact.contractName} implementation address: ${PawnContract.address}`);

    console.log("============================================================\n\r");

    const ProxyFactory  = await hre.ethers.getContractFactory(ProxyBuildName, proxyAdmin);
    // const ProxyArtifact = await hre.artifacts.readArtifact(ProxyBuildName);
    const ProxyContract = ProxyFactory.attach(PawnProxyAddr);

    console.log(`Upgrading contracts with the account: ${proxyAdmin.address}`);  
    console.log("Account balance:", ((await proxyAdmin.getBalance())/decimals).toString());
    console.log(`Upgrading ${PawnProxyAddr} with new implementation from ${PawnContract.address}`)
    await ProxyContract.upgradeTo(PawnContract.address);
    console.log("Upgrade successful");
  
    // console.log(`PAWN_CONTRACT_ADDRESS: ${proxyDeploy.address}`);
    console.log("============================================================\n\r");
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });