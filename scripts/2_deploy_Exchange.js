require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { Proxies } = require('./.deployment_data.json');

const ExchangeBuildName = "contracts/pawn/exchange/Exchange.sol:Exchange";

const proxyType = { kind: "uups" };

const proxies = Proxies.Dev2;

const HubProxyAddr = proxies.HUB_CONTRACT_ADDRESS;
const HubBuildName     = "Hub";
const decimals      = 10**18;

async function main() {
    const [deployer, proxyAdmin] = await hre.ethers.getSigners();
    
    console.log("============================================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================\n\r");
  
    const ExchangeFactory   = await hre.ethers.getContractFactory(ExchangeBuildName);
    const ExchangeArtifact  = await hre.artifacts.readArtifact(ExchangeBuildName);
    const ExchangeContract  = await hre.upgrades.deployProxy(ExchangeFactory,[HubProxyAddr], proxyType);

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