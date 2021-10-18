require('@nomiclabs/hardhat-ethers');
const hre = require('hardhat');

const { PawnConfig, Proxies, Exchanges } = require('./.deployment_data_prelive.json');
const proxies = Proxies.Prelive;

const ExchangeProxyAddr = proxies.EXCHANGE_CONTRACT_ADDRESS;
const ExchangeBuildName = "Exchange";

const decimals          = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("============================================================");
    console.log(`Initialize contracts with the account: ${deployer.address}`);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================");

    const ExchangeFactory   = await hre.ethers.getContractFactory(ExchangeBuildName);
    const ExchangeArtifact  = await hre.artifacts.readArtifact(ExchangeBuildName);
    const ExchangeContract  = ExchangeFactory.attach(ExchangeProxyAddr);

    console.log(`Initializing ${ExchangeArtifact.contractName}...`);

    console.log(`Setting Exchange addresses...`);
    for await (let exchange of Exchanges) {
        await ExchangeContract.setCryptoExchange(exchange.Address, exchange.Exchange);
        console.log(`\tExchange address for ${exchange.Name}: ${exchange.Exchange}`);
    }

    console.log("============================================================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });