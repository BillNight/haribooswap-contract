pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./uniswapv2/interfaces/IUniswapV2ERC20.sol";
import "./uniswapv2/interfaces/IUniswapV2Pair.sol";
import "./uniswapv2/interfaces/IUniswapV2Factory.sol";


contract ColaMaker {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IUniswapV2Factory public factory;
    address public soda;
    address public cola;
    address public wbnb;

    constructor(IUniswapV2Factory _factory, address _soda, address _cola, address _wbnb) public {
        factory = _factory;
        cola = _cola;
        soda = _soda;
        wbnb = _wbnb;
    }

    function convert(address token0, address token1) public {
        
        require(msg.sender == tx.origin, "do not convert from contract");
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(token0, token1));
        pair.transfer(address(pair), pair.balanceOf(address(this)));
        pair.burn(address(this));
        uint256 wbnbAmount = _toWBNB(token0) + _toWBNB(token1);
        _toCOLA(wbnbAmount);
    }

    function _toWBNB(address token) internal returns (uint256) {
        if (token == cola) {
            uint amount = IERC20(token).balanceOf(address(this));
            _safeTransfer(token, soda, amount);
            return 0;
        }
        if (token == wbnb) {
            uint amount = IERC20(token).balanceOf(address(this));
            _safeTransfer(token, factory.getPair(wbnb, cola), amount);
            return amount;
        }
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(token, wbnb));
        if (address(pair) == address(0)) {
            return 0;
        }
        (uint reserve0, uint reserve1,) = pair.getReserves();
        address token0 = pair.token0();
        (uint reserveIn, uint reserveOut) = token0 == token ? (reserve0, reserve1) : (reserve1, reserve0);
        uint amountIn = IERC20(token).balanceOf(address(this));
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        uint amountOut = numerator / denominator;
        (uint amount0Out, uint amount1Out) = token0 == token ? (uint(0), amountOut) : (amountOut, uint(0));
        _safeTransfer(token, address(pair), amountIn);
        pair.swap(amount0Out, amount1Out, factory.getPair(wbnb, cola), new bytes(0));
        return amountOut;
    }

    function _toCOLA(uint256 amountIn) internal {
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(wbnb, cola));
        (uint reserve0, uint reserve1,) = pair.getReserves();
        address token0 = pair.token0();
        (uint reserveIn, uint reserveOut) = token0 == wbnb ? (reserve0, reserve1) : (reserve1, reserve0);
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        uint amountOut = numerator / denominator;
        (uint amount0Out, uint amount1Out) = token0 == wbnb ? (uint(0), amountOut) : (amountOut, uint(0));
        pair.swap(amount0Out, amount1Out, soda, new bytes(0));
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        IERC20(token).safeTransfer(to, amount);
    }
}
