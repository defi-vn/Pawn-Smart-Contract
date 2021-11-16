// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IExchange {
    // lay gia cua dong BNB
    function RateBNBwithUSD() external view returns (uint256 price);

    // lay ti gia dong BNB + timestamp
    function RateBNBwithUSDAttimestamp()
        external
        view
        returns (uint256 price, uint256 timeStamp);

    // lay gia cua cac crypto va token khac da duoc them vao ListcryptoExchange
    function getLatesPriceToUSD(address _adcrypto)
        external
        view
        returns (uint256 price);

    // lay ti gia va timestamp cua cac crypto va token da duoc them vao ListcryptoExchange
    function getRateAndTimestamp(address _adcrypto)
        external
        view
        returns (uint256 price, uint256 timeStamp);
}
