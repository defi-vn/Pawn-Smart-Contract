// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./ivoting.sol";
import "../../base/BaseContract.sol";
import "../../hub/HubLib.sol";
import "../../hub/HubInterface.sol";
import "../exchange/IExchange.sol";

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
        //    require(votingStart > block.timestamp, "votingStart > present time");
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

        CommonLib.safeTransfer(
            tokenAddress,
            msg.sender,
            address(this),
            rewardPooll
        );

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
        require(votingEnd > votingStart, "votingTime");
        //    require(block.timestamp < _token.votingEnd, "time vote < votingEnd");

        if (rewardPool < _token.rewardPoll) {
            CommonLib.safeTransfer(
                tokenAddress,
                address(this),
                msg.sender,
                (_token.rewardPoll - rewardPool)
            );
        }
        if (rewardPool > _token.rewardPoll) {
            CommonLib.safeTransfer(
                tokenAddress,
                msg.sender,
                address(this),
                (rewardPool - _token.rewardPoll)
            );
        }

        ListTokenVote[votingId] = VotingNewToken({
            votingId: votingId,
            tokenAddress: tokenAddress,
            votingStart: votingStart,
            votingEnd: votingEnd,
            targetVoting: targetVoting,
            rewardPoll: rewardPool,
            totalVotes: _token.totalVotes,
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
        //   require(block.timestamp < _token.votingEnd, "time vote < votingEnd");

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

        emit VoteEvent(_token, msg.sender, votes);
    }

    function cancelTokenVoting(uint256 votingId) external override onlyAdmin {
        VotingNewToken storage _token = ListTokenVote[votingId];

        require(
            _token.votingStatus == VotingStatus.OPEN,
            "voting status not is OPEN"
        );

        //        require(block.timestamp < _token.votingEnd, "time vote < votingEnd");

        CommonLib.safeTransfer(
            _token.tokenAddress,
            address(this),
            msg.sender,
            _token.rewardPoll
        );

        _token.votingStatus = VotingStatus.CANCELLED;

        emit NewTokenEvent(_token, "");
    }

    function closeVote(uint256 votingId) external onlyOperator {
        VotingNewToken storage _token = ListTokenVote[votingId];
        require(block.timestamp > _token.votingEnd, "chua het thoi gian");

        if (_token.totalVotes >= _token.targetVoting) {
            _token.votingStatus = VotingStatus.QUEUE;
        }

        if (_token.totalVotes < _token.targetVoting) {
            _token.votingStatus = VotingStatus.FALSE;
        }

        emit NewTokenEvent(_token, "");
    }

    function calculateTokenClaim(uint256 votingId, address claimer)
        external
        view
        returns (uint256 totalTokenVote, uint256 tokenreward)
    {
        // totalTokenVote = 0;
        // tokenreward = 0;
        VotingNewToken storage _token = ListTokenVote[votingId];

        require(
            _token.votingStatus == VotingStatus.QUEUE ||
                _token.votingStatus == VotingStatus.COMPLETE ||
                _token.votingStatus == VotingStatus.CANCELLED ||
                _token.votingStatus == VotingStatus.FALSE
        );

        if (
            _token.votingStatus == VotingStatus.FALSE ||
            _token.votingStatus == VotingStatus.CANCELLED ||
            _token.votingStatus == VotingStatus.QUEUE
        ) {
            // require(
            //     Votes[votingId].votes[msg.sender] > 0,
            //     "ban da claim roi claim lam the"
            // );
            totalTokenVote = Votes[votingId].votes[claimer];
        }

        if (_token.votingStatus == VotingStatus.QUEUE) {
            // require(
            //     Votes[votingId].votes[msg.sender] > 0,
            //     "ban da claim roi claim lam the"
            // );
            // tinh ti le tra thuong
            uint256 abc = (Votes[votingId].votes[claimer] * 10**5) /
                _token.totalVotes;

            uint256 tientra = DivRound((_token.rewardPoll * abc) / 10**5);

            tokenreward = tientra;
        }
    }

    function claim(uint256 votingId) external {
        VotingNewToken storage _token = ListTokenVote[votingId];

        require(block.timestamp > _token.votingEnd);
        require(
            _token.votingStatus == VotingStatus.QUEUE ||
                _token.votingStatus == VotingStatus.COMPLETE ||
                _token.votingStatus == VotingStatus.CANCELLED ||
                _token.votingStatus == VotingStatus.FALSE
        );

        (, address _addressTokenVotes) = HubInterface(contractHub)
            .getSystemConfig();

        if (
            _token.votingStatus == VotingStatus.FALSE ||
            _token.votingStatus == VotingStatus.CANCELLED
        ) {
            require(
                Votes[votingId].votes[msg.sender] > 0,
                "ban da claim roi claim lam the"
            );
            CommonLib.safeTransfer(
                _addressTokenVotes,
                address(this),
                msg.sender,
                Votes[votingId].votes[msg.sender]
            );
            emit ClainEvent(
                votingId,
                _addressTokenVotes,
                _token.tokenAddress,
                Votes[votingId].votes[msg.sender],
                0,
                address(this),
                msg.sender
            );

            Votes[votingId].votes[msg.sender] = 0;
        }

        if (_token.votingStatus == VotingStatus.QUEUE) {
            require(
                Votes[votingId].votes[msg.sender] > 0,
                "ban da claim roi claim lam the"
            );

            CommonLib.safeTransfer(
                _addressTokenVotes,
                address(this),
                msg.sender,
                Votes[votingId].votes[msg.sender]
            );

            // tinh ti le tra thuong
            uint256 abc = (Votes[votingId].votes[msg.sender] * 10**5) /
                _token.totalVotes;

            uint256 tientra = DivRound((_token.rewardPoll * abc) / 10**5);
            CommonLib.safeTransfer(
                _token.tokenAddress,
                address(this),
                msg.sender,
                tientra
            );

            emit ClainEvent(
                votingId,
                _addressTokenVotes,
                _token.tokenAddress,
                Votes[votingId].votes[msg.sender],
                tientra,
                address(this),
                msg.sender
            );

            Votes[votingId].votes[msg.sender] = 0;
        }
    }

    function ListNewToken(
        uint256 votingId,
        address priceFeedAddress,
        uint256 statusWhitelistCollateral,
        string memory tokenCID
    ) external onlyAdmin {
        VotingNewToken storage _token = ListTokenVote[votingId];
        require(_token.votingStatus == VotingStatus.QUEUE);

        configNewToken(
            _token.tokenAddress,
            priceFeedAddress,
            statusWhitelistCollateral
        );

        emit AddNewTokenEvent(
            int256(votingId),
            _token.tokenAddress,
            priceFeedAddress,
            tokenCID
        );
    }

    function ListAddNewToken(
        address addressToken,
        address priceFeedAddress,
        uint256 statusWhitelistCollateral,
        string memory tokenCID
    ) public onlyAdmin {
        configNewToken(
            addressToken,
            priceFeedAddress,
            statusWhitelistCollateral
        );
        emit AddNewTokenEvent(-1, addressToken, priceFeedAddress, tokenCID);
    }

    function configNewToken(
        address addressToken,
        address priceFeedAddress,
        uint256 statusWhitelistCollateral
    ) internal {
        require(
            HubInterface(contractHub).getWhitelistCollateral(addressToken) != 1,
            "token already exists in whitelist"
        );

        require(priceFeedAddress.isContract(), "is not contract");
        require(addressToken.isContract(), "is not contract");

        require(priceFeedAddress != address(0));

        HubInterface(contractHub).setWhitelistCollateral(
            addressToken,
            statusWhitelistCollateral
        );

        (address _exchangeAddress, ) = HubInterface(contractHub)
            .getContractAddress(type(IExchange).interfaceId);

        IExchange(_exchangeAddress).setCryptoExchange(
            addressToken,
            priceFeedAddress
        );
    }

    function DivRound(uint256 a) private pure returns (uint256) {
        uint256 tm = a / 10**13;
        uint256 rouding = tm * 10**13;
        return rouding;
    }
}
