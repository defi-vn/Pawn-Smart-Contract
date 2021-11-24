// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "../../base/BaseInterface.sol";

interface IExchange is BaseInterface {
    // lay gia cua dong BNB

    function setCryptoExchange(
        address _cryptoAddress,
        address _latestPriceAddress
    ) external;

    // function RateBNBwithUSD() external view returns (uint256 price);

    // // lay ti gia dong BNB + timestamp
    // function RateBNBwithUSDAttimestamp()
    //     external
    //     view
    //     returns (uint256 price, uint256 timeStamp);

    // // lay gia cua cac crypto va token khac da duoc them vao ListcryptoExchange
    // function getLatesPriceToUSD(address _adcrypto)
    //     external
    //     view
    //     returns (uint256 price);

    // // lay ti gia va timestamp cua cac crypto va token da duoc them vao ListcryptoExchange
    // function getRateAndTimestamp(address _adcrypto)
    //     external
    //     view
    //     returns (uint256 price, uint256 timeStamp);
}
