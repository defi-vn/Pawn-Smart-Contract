const hre = require('hardhat');

const { Proxies } = require('./.deployment_data.json');
const proxies = Proxies.Dev2;

const LoanProxyAddr     = proxies.PAWN_P2PLOAN_CONTRACT_ADDRESS;
const LoanBuildName     = "contracts/pawn/pawn-p2p-v2/PawnP2PLoanContract.sol:PawnP2PLoanContract";

const decimals  = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();
  
    console.log("============================================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================\n\r");
  
    const LoanFactoryV1      = await hre.ethers.getContractFactory(LoanBuildName);
    const LoanArtifactV1     = await hre.artifacts.readArtifact(LoanBuildName);
    const LoanContractV1     = LoanFactoryV1.attach(LoanProxyAddr);

    const LoanImplV1         = await hre.upgrades.erc1967.getImplementationAddress(LoanContractV1.address);

    console.log(`Upgrading ${LoanArtifactV1.contractName} at proxy: ${LoanContractV1.address}`);
    console.log(`Current implementation address: ${LoanImplV1}`);

    const LoanFactoryV2      = await hre.ethers.getContractFactory(LoanBuildName);
    const LoanArtifactV2     = await hre.artifacts.readArtifact(LoanBuildName);
    const LoanContractV2     = await hre.upgrades.upgradeProxy(LoanContractV1, LoanFactoryV2);
    
    await LoanContractV2.deployed();
    
    const LoanImplV2         = await hre.upgrades.erc1967.getImplementationAddress(LoanContractV2.address);

    console.log(`${LoanArtifactV2.contractName} deployed to: ${LoanContractV2.address}`);
    console.log(`New implementation Address: ${LoanImplV2}`);

    console.log("============================================================\n\r");
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });