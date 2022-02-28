// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "../../base/BaseInterface.sol";

interface IVoting is BaseInterface {
    /*==== Enum */
    enum VotingStatus {
        OPEN,
        CANCELLED,
        QUEUE,
        COMPLETE,
        FALSE
    }

    /** struct */

    struct VotingNewToken {
        uint256 votingId;
        address tokenAddress;
        uint256 votingStart;
        uint256 votingEnd;
        uint256 targetVoting;
        uint256 rewardPoll;
        uint256 totalVotes;
        bool success;
        VotingStatus votingStatus;
    }

    struct Voting {
        mapping(address => uint256) votes;
        uint256 votingId;
    }

    /**  event */
    event NewTokenEvent(VotingNewToken newToken, string tokenCID);
    event VoteEvent(
        VotingNewToken newToken,
        address voter,
        uint256 totalvotesOfvoter
    );

    event AddNewTokenEvent(
        int256 votingId,
        address token,
        address priceFeed,
        string tokenCID
    );

    /** function */
    function addNewToken(
        address tokenAddress,
        uint256 targetVoting,
        uint256 rewardPoll,
        uint256 votingStart,
        uint256 votingEnd,
        string memory tokenCID
    ) external;

    function cancelTokenVoting(uint256 tokenId) external;

    function editTokenVoting(
        uint256 tokenId,
        address tokenAddress,
        uint256 targetVoting,
        uint256 rewardPool,
        uint256 votingStart,
        uint256 votingEnd,
        string memory tokenCID
    ) external;

    function voting(uint256 votingId, uint256 votes) external;

    // function closeVote(uint256 votingId) external;

    // function claim(uint256 votingId) external;

    // function ListNewToken(
    //     uint256 votingId,
    //     address priceFeedAddress,
    //     uint256 statusWhitelistCollateral,
    //     string memory TokenCID
    // ) external;
}
