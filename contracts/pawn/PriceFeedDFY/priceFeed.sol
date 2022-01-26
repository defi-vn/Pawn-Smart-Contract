// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IPancakePair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

/**
 * @title The Owned contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract Owned {
    address public owner;
    address private pendingOwner;

    event OwnershipTransferRequested(address indexed from, address indexed to);
    event OwnershipTransferred(address indexed from, address indexed to);

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Allows an owner to begin transferring ownership to a new address,
     * pending.
     */
    function transferOwnership(address _to) external onlyOwner {
        pendingOwner = _to;

        emit OwnershipTransferRequested(owner, _to);
    }

    /**
     * @dev Allows an ownership transfer to be completed by the recipient.
     */
    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "Must be proposed owner");

        address oldOwner = owner;
        owner = msg.sender;
        pendingOwner = address(0);

        emit OwnershipTransferred(oldOwner, msg.sender);
    }

    /**
     * @dev Reverts if called by anyone other than the contract owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only callable by owner");
        _;
    }
}

interface AggregatorInterface {
    function latestAnswer() external view returns (int256);

    function latestTimestamp() external view returns (uint256);

    function latestRound() external view returns (uint256);

    function getAnswer(uint256 roundId) external view returns (int256);

    function getTimestamp(uint256 roundId) external view returns (uint256);

    event AnswerUpdated(
        int256 indexed current,
        uint256 indexed roundId,
        uint256 updatedAt
    );
    event NewRound(
        uint256 indexed roundId,
        address indexed startedBy,
        uint256 startedAt
    );
}

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

interface AggregatorV2V3Interface is
    AggregatorInterface,
    AggregatorV3Interface
{}

/**
 * @title A trusted proxy for updating where current answers are read from
 * @notice This contract provides a consistent address for the
 * CurrentAnwerInterface but delegates where it reads from to the owner, who is
 * trusted to update it.
 */
contract AggregatorProxy is AggregatorV2V3Interface, Owned {
    struct Phase {
        uint16 id;
        AggregatorV2V3Interface aggregator_;
    }
    Phase private currentPhase;
    AggregatorV2V3Interface public proposedAggregator;
    mapping(uint16 => AggregatorV2V3Interface) public phaseAggregators;

    uint256 private constant PHASE_OFFSET = 64;
    uint256 private constant PHASE_SIZE = 16;
    uint256 private constant MAX_ID = 2**(PHASE_OFFSET + PHASE_SIZE) - 1;

    constructor(address _aggregator) Owned() {
        setAggregator(_aggregator);
    }

    /**
     * @notice Reads the current answer from aggregator_ delegated to.
     *
     * @dev #[deprecated] Use latestRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended latestRoundData
     * instead which includes better verification information.
     */
    function latestAnswer()
        public
        view
        virtual
        override
        returns (int256 answer)
    {
        return currentPhase.aggregator_.latestAnswer();
    }

    /**
     * @notice Reads the last updated height from aggregator_ delegated to.
     *
     * @dev #[deprecated] Use latestRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended latestRoundData
     * instead which includes better verification information.
     */
    function latestTimestamp()
        public
        view
        virtual
        override
        returns (uint256 updatedAt)
    {
        return currentPhase.aggregator_.latestTimestamp();
    }

    /**
     * @notice get past rounds answers
     * @param _roundId the answer number to retrieve the answer for
     *
     * @dev #[deprecated] Use getRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended getRoundData
     * instead which includes better verification information.
     */
    function getAnswer(uint256 _roundId)
        public
        view
        virtual
        override
        returns (int256 answer)
    {
        if (_roundId > MAX_ID) return 0;

        (uint16 phaseId_, uint64 aggregatorRoundId) = parseIds(_roundId);
        AggregatorV2V3Interface aggregator_ = phaseAggregators[phaseId_];
        if (address(aggregator_) == address(0)) return 0;

        return aggregator_.getAnswer(aggregatorRoundId);
    }

    /**
     * @notice get block timestamp when an answer was last updated
     * @param _roundId the answer number to retrieve the updated timestamp for
     *
     * @dev #[deprecated] Use getRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended getRoundData
     * instead which includes better verification information.
     */
    function getTimestamp(uint256 _roundId)
        public
        view
        virtual
        override
        returns (uint256 updatedAt)
    {
        if (_roundId > MAX_ID) return 0;

        (uint16 phaseId_, uint64 aggregatorRoundId) = parseIds(_roundId);
        AggregatorV2V3Interface aggregator_ = phaseAggregators[phaseId_];
        if (address(aggregator_) == address(0)) return 0;

        return aggregator_.getTimestamp(aggregatorRoundId);
    }

    /**
     * @notice get the latest completed round where the answer was updated. This
     * ID includes the proxy's phase, to make sure round IDs increase even when
     * switching to a newly deployed aggregator_.
     *
     * @dev #[deprecated] Use latestRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended latestRoundData
     * instead which includes better verification information.
     */
    function latestRound()
        public
        view
        virtual
        override
        returns (uint256 roundId)
    {
        Phase memory phase = currentPhase; // cache storage reads
        return addPhase(phase.id, uint64(phase.aggregator_.latestRound()));
    }

    /**
     * @notice get data about a round. Consumers are encouraged to check
     * that they're receiving fresh data by inspecting the updatedAt and
     * answeredInRound return values.
     * Note that different underlying implementations of AggregatorV3Interface
     * have slightly different semantics for some of the return values. Consumers
     * should determine what implementations they expect to receive
     * data from and validate that they can properly handle return data from all
     * of them.
     * @param _roundId the requested round ID as presented through the proxy, this
     * is made up of the aggregator_'s round ID with the phase ID encoded in the
     * two highest order bytes
     * @return roundId is the round ID from the aggregator_ for which the data was
     * retrieved combined with an phase to ensure that round IDs get larger as
     * time moves forward.
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @dev Note that answer and updatedAt may change between queries.
     */
    function getRoundData(uint80 _roundId)
        public
        view
        virtual
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (uint16 phaseId_, uint64 aggregatorRoundId) = parseIds(_roundId);

        (
            roundId,
            answer,
            startedAt,
            updatedAt,
            answeredInRound
        ) = phaseAggregators[phaseId_].getRoundData(aggregatorRoundId);

        return
            addPhaseIds(
                roundId,
                answer,
                startedAt,
                updatedAt,
                answeredInRound,
                phaseId_
            );
    }

    /**
     * @notice get data about the latest round. Consumers are encouraged to check
     * that they're receiving fresh data by inspecting the updatedAt and
     * answeredInRound return values.
     * Note that different underlying implementations of AggregatorV3Interface
     * have slightly different semantics for some of the return values. Consumers
     * should determine what implementations they expect to receive
     * data from and validate that they can properly handle return data from all
     * of them.
     * @return roundId is the round ID from the aggregator_ for which the data was
     * retrieved combined with an phase to ensure that round IDs get larger as
     * time moves forward.
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @dev Note that answer and updatedAt may change between queries.
     */
    function latestRoundData()
        public
        view
        virtual
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        Phase memory current = currentPhase; // cache storage reads

        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 ansIn
        ) = current.aggregator_.latestRoundData();

        return
            addPhaseIds(
                roundId,
                answer,
                startedAt,
                updatedAt,
                ansIn,
                current.id
            );
    }

    /**
     * @notice Used if an aggregator_ contract has been proposed.
     * @param _roundId the round ID to retrieve the round data for
     * @return roundId is the round ID for which data was retrieved
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     */
    function proposedGetRoundData(uint80 _roundId)
        public
        view
        virtual
        hasProposal
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return proposedAggregator.getRoundData(_roundId);
    }

    /**
     * @notice Used if an aggregator_ contract has been proposed.
     * @return roundId is the round ID for which data was retrieved
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     */
    function proposedLatestRoundData()
        public
        view
        virtual
        hasProposal
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return proposedAggregator.latestRoundData();
    }

    /**
     * @notice returns the current phase's aggregator_ address.
     */
    function aggregator() external view returns (address) {
        return address(currentPhase.aggregator_);
    }

    /**
     * @notice returns the current phase's ID.
     */
    function phaseId() external view returns (uint16) {
        return currentPhase.id;
    }

    /**
     * @notice represents the number of decimals the aggregator_ responses represent.
     */
    function decimals() external view override returns (uint8) {
        // return currentPhase.aggregator_.decimals();
        return 8;
    }

    /**
     * @notice the version number representing the type of aggregator_ the proxy
     * points to.
     */
    function version() external view override returns (uint256) {
        //    return currentPhase.aggregator_.version();
        return 1;
    }

    /**
     * @notice returns the description of the aggregator_ the proxy points to.
     */
    function description() external view override returns (string memory) {
        // return currentPhase.aggregator_.description();
        return "UNO/USD";
    }

    /**
     * @notice Allows the owner to propose a new address for the aggregator_
     * @param _aggregator The new address for the aggregator_ contract
     */
    function proposeAggregator(address _aggregator) external onlyOwner {
        proposedAggregator = AggregatorV2V3Interface(_aggregator);
    }

    /**
     * @notice Allows the owner to confirm and change the address
     * to the proposed aggregator_
     * @dev Reverts if the given address doesn't match what was previously
     * proposed
     * @param _aggregator The new address for the aggregator_ contract
     */
    function confirmAggregator(address _aggregator) external onlyOwner {
        require(
            _aggregator == address(proposedAggregator),
            "Invalid proposed aggregator_"
        );
        delete proposedAggregator;
        setAggregator(_aggregator);
    }

    /*
     * Internal
     */

    function setAggregator(address _aggregator) internal {
        uint16 id = currentPhase.id + 1;
        currentPhase = Phase(id, AggregatorV2V3Interface(_aggregator));
        phaseAggregators[id] = AggregatorV2V3Interface(_aggregator);
    }

    function addPhase(uint16 _phase, uint64 _originalId)
        internal
        view
        returns (uint80)
    {
        return uint80((uint256(_phase) << PHASE_OFFSET) | _originalId);
    }

    function parseIds(uint256 _roundId) internal view returns (uint16, uint64) {
        uint16 phaseId_ = uint16(_roundId >> PHASE_OFFSET);
        uint64 aggregatorRoundId = uint64(_roundId);

        return (phaseId_, aggregatorRoundId);
    }

    function addPhaseIds(
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound,
        uint16 phaseId_
    )
        internal
        view
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        return (
            addPhase(phaseId_, uint64(roundId)),
            answer,
            startedAt,
            updatedAt,
            addPhase(phaseId_, uint64(answeredInRound))
        );
    }

    /*
     * Modifiers
     */

    modifier hasProposal() {
        require(
            address(proposedAggregator) != address(0),
            "No proposed aggregator_ present"
        );
        _;
    }
}

interface AccessControllerInterface {
    function hasAccess(address user, bytes calldata data)
        external
        view
        returns (bool);
}

/**
 * @title External Access Controlled Aggregator Proxy
 * @notice A trusted proxy for updating where current answers are read from
 * @notice This contract provides a consistent address for the
 * Aggregator and AggregatorV3Interface but delegates where it reads from to the owner, who is
 * trusted to update it.
 * @notice Only access enabled addresses are allowed to access getters for
 * aggregated answers and round information.
 */

contract EACAggregatorProxy is AggregatorProxy {
    AccessControllerInterface public accessController;
    AggregatorV3Interface internal priceFeed;
    address aggregator_;

    constructor(address _aggregator)
        public
        //address _aggregator
        // address _accessController
        AggregatorProxy(_aggregator)
    {
        aggregator_ = _aggregator;
        setController(address(0));
        // BNB / usd
        priceFeed = AggregatorV3Interface(
            0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
        );
    }

    function configAggregator(address _aggregator) public onlyOwner {
        aggregator_ = _aggregator;
    }

    // ====================================================================================================================

    function getData()
        public
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (
            uint80 roundID_,
            int256 priceUSDTofUSD_,
            uint256 startedAt_,
            uint256 timeStamp_,
            uint80 answeredInRound_
        ) = priceFeed.latestRoundData();

        (uint112 reserve0, uint112 reserve1, ) = IPancakePair(aggregator_)
            .getReserves();
        (, uint256 priceTokenOfUSDT) = tryDiv(
            reserve1 * uint256(priceUSDTofUSD_),
            reserve0
        );
        int256 price_ = int256(priceTokenOfUSDT);

        roundId = roundID_;
        answer = price_;
        startedAt = startedAt_;
        updatedAt = timeStamp_;
        answeredInRound = answeredInRound_;
    }

    //======================================================================================================================

    /**
     * @notice Allows the owner to update the accessController contract address.
     * @param _accessController The new address for the accessController contract
     */
    function setController(address _accessController) public onlyOwner {
        accessController = AccessControllerInterface(_accessController);
    }

    /**
     * @notice Reads the current answer from aggregator_ delegated to.
     * @dev overridden function to add the checkAccess() modifier
     *
     * @dev #[deprecated] Use latestRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended latestRoundData
     * instead which includes better verification information.
     */
    function latestAnswer()
        public
        view
        override
        checkAccess
        returns (int256 _answer)
    {
        (, _answer, , , ) = getData();
    }

    /**
     * @notice get the latest completed round where the answer was updated. This
     * ID includes the proxy's phase, to make sure round IDs increase even when
     * switching to a newly deployed aggregator_.
     *
     * @dev #[deprecated] Use latestRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended latestRoundData
     * instead which includes better verification information.
     */
    function latestTimestamp()
        public
        view
        override
        checkAccess
        returns (uint256 _timestamp)
    {
        (, , , _timestamp, ) = getData();
    }

    /**
     * @notice get past rounds answers
     * @param _roundId the answer number to retrieve the answer for
     * @dev overridden function to add the checkAccess() modifier
     *
     * @dev #[deprecated] Use getRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended getRoundData
     * instead which includes better verification information.
     */
    function getAnswer(uint256 _roundId)
        public
        view
        override
        checkAccess
        returns (int256)
    {
        return super.getAnswer(_roundId);
    }

    /**
     * @notice get block timestamp when an answer was last updated
     * @param _roundId the answer number to retrieve the updated timestamp for
     * @dev overridden function to add the checkAccess() modifier
     *
     * @dev #[deprecated] Use getRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended getRoundData
     * instead which includes better verification information.
     */
    function getTimestamp(uint256 _roundId)
        public
        view
        override
        checkAccess
        returns (uint256)
    {
        return super.getTimestamp(_roundId);
    }

    /**
     * @notice get the latest completed round where the answer was updated
     * @dev overridden function to add the checkAccess() modifier
     *
     * @dev #[deprecated] Use latestRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended latestRoundData
     * instead which includes better verification information.
     */
    function latestRound()
        public
        view
        override
        checkAccess
        returns (uint256 _latestRound)
    {
        (_latestRound, , , , ) = getData();
    }

    /**
     * @notice get data about a round. Consumers are encouraged to check
     * that they're receiving fresh data by inspecting the updatedAt and
     * answeredInRound return values.
     * Note that different underlying implementations of AggregatorV3Interface
     * have slightly different semantics for some of the return values. Consumers
     * should determine what implementations they expect to receive
     * data from and validate that they can properly handle return data from all
     * of them.
     * @param _roundId the round ID to retrieve the round data for
     * @return roundId is the round ID from the aggregator_ for which the data was
     * retrieved combined with a phase to ensure that round IDs get larger as
     * time moves forward.
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @dev Note that answer and updatedAt may change between queries.
     */
    function getRoundData(uint80 _roundId)
        public
        view
        override
        checkAccess
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return super.getRoundData(_roundId);
    }

    /**
     * @notice get data about the latest round. Consumers are encouraged to check
     * that they're receiving fresh data by inspecting the updatedAt and
     * answeredInRound return values.
     * Note that different underlying implementations of AggregatorV3Interface
     * have slightly different semantics for some of the return values. Consumers
     * should determine what implementations they expect to receive
     * data from and validate that they can properly handle return data from all
     * of them.
     * @return roundId is the round ID from the aggregator_ for which the data was
     * retrieved combined with a phase to ensure that round IDs get larger as
     * time moves forward.
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @dev Note that answer and updatedAt may change between queries.
     */
    function latestRoundData()
        public
        view
        override
        checkAccess
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        //   return super.latestRoundData();
        return getData();
    }

    /**
     * @notice Used if an aggregator_ contract has been proposed.
     * @param _roundId the round ID to retrieve the round data for
     * @return roundId is the round ID for which data was retrieved
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     */
    function proposedGetRoundData(uint80 _roundId)
        public
        view
        override
        checkAccess
        hasProposal
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return super.proposedGetRoundData(_roundId);
    }

    /**
     * @notice Used if an aggregator_ contract has been proposed.
     * @return roundId is the round ID for which data was retrieved
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     */
    function proposedLatestRoundData()
        public
        view
        override
        checkAccess
        hasProposal
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return super.proposedLatestRoundData();
    }

    /**
     * @dev reverts if the caller does not have access by the accessController
     * contract or is the contract itself.
     */
    modifier checkAccess() {
        AccessControllerInterface ac = accessController;
        require(
            address(ac) == address(0) || ac.hasAccess(msg.sender, msg.data),
            "No access"
        );
        _;
    }

    function DivRound(uint256 a) private pure returns (uint256) {
        // kiem tra so du khi chia 10**13. Neu lon hon 5 *10**12 khi chia xong thi lam tron len(+1) roi nhan lai voi 10**13
        //con nho hon thi giu nguyen va nhan lai voi 10**13

        uint256 tmp = a % 10**10;
        uint256 tm;
        if (tmp < 5 * 10**9) {
            tm = a / 10**10;
        } else {
            tm = a / 10**10 + 1;
        }
        uint256 rouding = tm;
        return rouding;
    }

    function tryDiv(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }
}
