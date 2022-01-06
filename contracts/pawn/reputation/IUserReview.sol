// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../../base/BaseInterface.sol";
import "./IReputation.sol";

interface IUserReview is BaseInterface {
    /** Datatypes */
    struct Review {
        address reviewee;
        uint256 contractId;
        uint256 points;
        address contractOrigin;
    }

    /** Events */
    event UserReviewSubmitted(
        address reviewer,
        address reviewee,
        uint256 points,
        uint256 contractId,
        address contractOrigin,
        IReputation.ReasonType reason
    );
}
