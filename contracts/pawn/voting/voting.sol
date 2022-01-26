// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./ivoting.sol";
import "../../base/BaseContract.sol";
import "../../hub/HubLib.sol";
import "../../hub/HubInterface.sol";

contract Vote is IVoting, BaseContract {
    using AddressUpgradeable for address;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _totalTokenToVote;
    CountersUpgradeable.Counter private _totalVoting;

    mapping(uint256 => VotingNewToken) public ListTokenVote;
    mapping(uint256 => Voting) public Votes;

    function initialize(address _hubContract) public initializer {
        __BaseContract_init(_hubContract);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function signature() public pure override returns (bytes4) {
        return type(IVoting).interfaceId;
    }

    function addNewToken(
        address tokenAddress,
        uint256 targetVoting,
        uint256 rewardPooll,
        uint256 votingStart,
        uint256 votingEnd,
        string memory tokenCID
    ) external override onlyAdmin {
        require(
            HubInterface(contractHub).getWhitelistCollateral(tokenAddress) != 1,
            "token already exists in whitelist"
        );

        require(votingStart > 0 && votingEnd > votingStart, "votingTime");

        require(tokenAddress.isContract(), "token address is not contract");

        uint256 _votingId = _totalTokenToVote.current();

        ListTokenVote[_votingId] = VotingNewToken({
            votingId: _votingId,
            tokenAddress: tokenAddress,
            votingStart: votingStart,
            votingEnd: votingEnd,
            targetVoting: targetVoting,
            rewardPoll: rewardPooll,
            totalVotes: 0,
            success: false,
            votingStatus: VotingStatus.OPEN
        });

        _totalTokenToVote.increment();

        emit NewTokenEvent(ListTokenVote[_votingId], tokenCID);
    }

    function editTokenVoting(
        uint256 votingId,
        address tokenAddress,
        uint256 targetVoting,
        uint256 rewardPool,
        uint256 votingStart,
        uint256 votingEnd,
        string memory tokenCID
    ) external override onlyAdmin {
        VotingNewToken storage _token = ListTokenVote[votingId];

        require(
            _token.votingStatus == VotingStatus.OPEN,
            "voting status not is OPEN"
        );
        require(block.timestamp < _token.votingEnd, "time vote < votingEnd");

        ListTokenVote[votingId] = VotingNewToken({
            votingId: votingId,
            tokenAddress: tokenAddress,
            votingStart: votingStart,
            votingEnd: votingEnd,
            targetVoting: targetVoting,
            rewardPoll: rewardPool,
            totalVotes: 0,
            success: false,
            votingStatus: VotingStatus.OPEN
        });

        emit NewTokenEvent(ListTokenVote[votingId], tokenCID);
    }

    function voting(uint256 votingId, uint256 votes) external {
        VotingNewToken storage _token = ListTokenVote[votingId];

        require(
            _token.votingStatus == VotingStatus.OPEN,
            "voting status not is OPEN"
        );
        require(block.timestamp < _token.votingEnd, "time vote < votingEnd");

        _token.totalVotes = _token.totalVotes + votes;

        Votes[votingId].votingId = votingId;
        Votes[votingId].votes[msg.sender] =
            Votes[votingId].votes[msg.sender] +
            votes;

        (, address _addressTokenVotes) = HubInterface(contractHub)
            .getSystemConfig();

        CommonLib.safeTransfer(
            _addressTokenVotes,
            msg.sender,
            address(this),
            votes
        );

        emit VoteEvent(_token, msg.sender, _token.totalVotes);
    }

    function cancelTokenVoting(uint256 votingId) external override onlyAdmin {
        VotingNewToken storage _token = ListTokenVote[votingId];

        require(
            _token.votingStatus == VotingStatus.OPEN,
            "voting status not is OPEN"
        );
        require(block.timestamp < _token.votingEnd, "time vote < votingEnd");

        _token.votingStatus = VotingStatus.CANCELLED;

        emit NewTokenEvent(_token, "");
    }
}
