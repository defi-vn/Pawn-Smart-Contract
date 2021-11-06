const yargs = require('yargs');
const Web3 = require('web3');
const web3 = new Web3("https://bsc-dataseed.binance.org/");

const { Proxies } = require('../live-2.4/.deployment_data_live.json');
const proxies = Proxies.Live;

var loanContract = require('../../artifacts/contracts/pawn/pawn-p2p-v2/PawnP2PLoanContract.sol/PawnP2PLoanContract.json');
var loan = new web3.eth.Contract(loanContract.abi, proxies.PAWN_P2PLOAN_CONTRACT_ADDRESS);


// Process input parameters
const argv = yargs
    .command('block', 'Block to scan', {
        fromBlock: {
            description: 'The block to scan for events',
            alias: 'f',
            type: 'number',
        }
    })
    .option('toBlock', {
        alias: 't',
        description: 'The last block to scan',
        type: 'number'
    })
    .option('allEvents', {
        alias: 'a',
        description: 'Show all events',
        type: 'boolean'
    })
    .option('eventDetails', {
        alias: 'd',
        description: 'Show event details',
        type: 'boolean'
    })
    .help()
    .alias('help', 'h')
    .argv;


if(argv._.includes('block')) {
    let startBlock = argv.fromBlock;
    let endBlock = (argv.toBlock > argv.fromBlock) ? argv.toBlock : argv.fromBlock;
    let events = argv.allEvents ? "allEvents" : "LoanContractCreatedEvent";
    console.log(`From block: ${startBlock} - to block: ${endBlock}`);

    // Get past events from contract
    loan.getPastEvents(events, {
        fromBlock: startBlock,
        toBlock: endBlock, 
        function(error, events) {
            showOutput(events, argv.eventDetails);
        }
    }).then(function(events) {
        showOutput(events, argv.eventDetails);
    });
}
else {
    console.log("Block parameter is required");
}

const showOutput = (events, showDetails) => {
    if(showDetails) {
        for(var i = 0; i < events.length; i++) {
            console.log(`Block number: ${events[i].blockNumber}`);
            console.log(`Event: ${events[i].event}`);
            console.log(events[i].returnValues);
        }
    }
    else {
        for(var i = 0; i < events.length; i++) {
            if(events[i].returnValues.exchangeRate !== undefined) {
                console.log(`Block number: ${events[i].blockNumber}`);
                console.log(`Exchange Rate: ${events[i].returnValues.exchangeRate}`);
            }
        }
    }
}

// console.log(argv);