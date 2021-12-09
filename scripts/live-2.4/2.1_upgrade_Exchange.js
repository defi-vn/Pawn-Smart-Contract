require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { Proxies } = require('./.deployment_data_live.json');
const proxies = Proxies.Live;

const ExchangeProxyAddr = proxies.EXCHANGE_CONTRACT_ADDRESS;
const ExchangeBuildName = "Exchange";

const decimals      = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    
    console.log("============================================================\n\r");
    console.log("Upgrading contracts with the account:", deployer.address);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================\n\r");

    const ExchangeFactoryV1     = await hre.ethers.getContractFactory(ExchangeBuildName);
    const ExchangeArtifactV1    = await hre.artifacts.readArtifact(ExchangeBuildName);
    const ExchangeContractV1    = ExchangeFactoryV1.attach(ExchangeProxyAddr);

    const ExchangeImplV1        = await hre.upgrades.erc1967.getImplementationAddress(ExchangeContractV1.address);

    console.log(`Upgrading ${ExchangeArtifactV1.contractName} at proxy: ${ExchangeContractV1.address}`);
    console.log(`Current implementation address: ${ExchangeImplV1}`);

    const ExchangeFactoryV2     = await hre.ethers.getContractFactory(ExchangeBuildName);
    const ExchangeArtifactV2    = await hre.artifacts.readArtifact(ExchangeBuildName);
    const ExchangeContractV2    = await hre.upgrades.upgradeProxy(ExchangeContractV1, ExchangeFactoryV2);
    
    await ExchangeContractV2.deployed();
    
    const ExchangeImplV2    = await hre.upgrades.erc1967.getImplementationAddress(ExchangeContractV2.address);

    console.log(`${ExchangeArtifactV2.contractName} deployed to: ${ExchangeContractV2.address}`);
    console.log(`New implementation Address: ${ExchangeImplV2}`);

    console.log("============================================================\n\r");
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });