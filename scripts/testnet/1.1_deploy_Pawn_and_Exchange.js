require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { PawnConfig } = require('./.deployment_data.json');

const PawnBuildName     = "contracts/pawn/pawn-p2p/PawnContract.sol:PawnContract";
const ProxyBuildName    = "AdminUpgradeabilityProxy";
const ProxyData         = "0x";
const ExchangeBuildName = "Exchange";

const proxyType = { kind: "uups" };

const decimals      = 10**18;

async function main() {
    const [deployer, proxyAdmin] = await hre.ethers.getSigners();
    
    console.log("============================================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================\n\r");
  
    const PawnFactory   = await hre.ethers.getContractFactory(PawnBuildName);
    const PawnArtifact  = await hre.artifacts.readArtifact(PawnBuildName);

    const pawnDeploy   = await PawnFactory.deploy();
    
    await pawnDeploy.deployed();
  
    console.log(`${PawnArtifact.contractName} implementation address: ${pawnDeploy.address}`);

    console.log("============================================================\n\r");

    const ProxyFactory  = await (await hre.ethers.getContractFactory(ProxyBuildName, proxyAdmin));
    // const ProxyArtifact = await hre.artifacts.readArtifact(ProxyBuildName);

    const proxyDeploy   = await ProxyFactory.deploy(pawnDeploy.address, proxyAdmin.address, ProxyData);
    
    await proxyDeploy.deployed();
  
    console.log(`PAWN_CONTRACT_ADDRESS: ${proxyDeploy.address}`);
    console.log("============================================================\n\r");

    const ExchangeFactory   = await hre.ethers.getContractFactory(ExchangeBuildName);
    const ExchangeArtifact  = await hre.artifacts.readArtifact(ExchangeBuildName);
    const ExchangeContract  = await hre.upgrades.deployProxy(ExchangeFactory, proxyType);

    await ExchangeContract.deployed();

    console.log(`EXCHANGE_CONTRACT_ADDRESS: ${ExchangeContract.address}`);

    implementationAddress = await hre.upgrades.erc1967.getImplementationAddress(ExchangeContract.address);
    console.log(`${ExchangeArtifact.contractName} implementation address: ${implementationAddress}`);

    console.log("============================================================\n\r");
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });