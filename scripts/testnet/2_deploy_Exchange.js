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
    const signature = await ExchangeContract.signature();

    console.log(`EXCHANGE_CONTRACT_ADDRESS: ${ExchangeContract.address}`);
    console.log(`Signature: \x1b[36m${signature}\x1b[0m`);

    implementationAddress = await hre.upgrades.erc1967.getImplementationAddress(ExchangeContract.address);
    console.log(`${ExchangeArtifact.contractName} implementation address: ${implementationAddress}`);

    const HubFactory = await hre.ethers.getContractFactory(HubBuildName);
    const HubArtifact = await hre.artifacts.readArtifact(HubBuildName);
    const HubContract = HubFactory.attach(HubProxyAddr);


    console.log(`HUB_ADDRESS: \x1b[31m${HubContract.address}\x1b[0m`);
    console.log(`Registering \x1b[36m${ExchangeArtifact.contractName}\x1b[0m to \x1b[31m${HubArtifact.contractName}\x1b[0m...`);

    await HubContract.registerContract(signature,ExchangeContract.address,ExchangeArtifact.contractName);
    console.log("============================================================\n\r");
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });