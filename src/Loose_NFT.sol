// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {INonfungiblePositionManager} from "lib/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {TickMath} from "lib/v3-core/contracts/libraries/TickMath.sol";
import {IPriceFeed} from "./PriceFeed.sol";
import {SafeMath} from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {LiquidityAmounts} from "lib/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

//1 . get an nft i.e erc721 token
interface IERC20Detailed is IERC20 {
    function decimals() external view returns (uint8);
}

contract LooseNFT is ERC20 {
    using SafeMath for uint256;

    INonfungiblePositionManager public positionManager;
    IPriceFeed public priceFeed;

    constructor(address _positionManager, address _priceFeed)
        ERC20("BitchCoin", "BCH")
    {
        positionManager = INonfungiblePositionManager(_positionManager);
        priceFeed = IPriceFeed(_priceFeed);
    }

    function getNFTAmount(uint256 tokenid) public returns (uint256) {
        (
            ,
            ,
            address token0,
            address token1,
            ,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,

        ) = positionManager.positions(tokenid);

        (uint256 price0, uint256 price1) = getPrice(token0, token1);

        uint160 sqrtPriceX96 = uint160(getSqrtPriceX96(price0, price1));

        int24 tick = getTick(sqrtPriceX96);

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                TickMath.getSqrtRatioAtTick(tick),
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );

        uint256 total_value = calculatePrice(amount0, amount1, token0, token1);
        _mint(msg.sender, 100);

        return total_value;
    }

    function getPrice(address _tokenA, address _tokenB)
        public
        view
        returns (uint256 priceA, uint256 priceB)
    {
        uint256 _priceA = priceFeed.price(_tokenA);
        uint256 _priceB = priceFeed.price(_tokenB);

        priceA = 10**IERC20Detailed(_tokenA).decimals();

        uint256 x = SafeMath.mul(_priceB, IERC20Detailed(_tokenB).decimals());

        priceB = SafeMath.div(x, _priceA);
    }

    function getTick(uint160 sqrtPriceX96) public pure returns (int24 tick) {
        tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }

    function getSqrtPriceX96(uint256 priceA, uint256 priceB)
        public
        pure
        returns (uint256)
    {
        uint256 ratioX192 = (priceA << 192).div(priceB);
        return Math.sqrt(ratioX192);
    }

    function calculatePrice(
        uint256 amountA,
        uint256 amountB,
        address tokenA,
        address tokenB
    ) public view returns (uint256 price) {
        price = (amountA.mul(priceFeed.price(tokenA))).add(
            amountB.mul(priceFeed.price(tokenB))
        );
    }
}
