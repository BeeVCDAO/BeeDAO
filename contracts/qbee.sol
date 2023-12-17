// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./IUniswapV2Router02.sol";
import "./Rewards.sol";
import "./RewardsWithDividend.sol";
import "./RewardsWithDividendWithBurnLP.sol";

interface ISwapFactory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

contract BEEt is ERC20, ERC20Burnable, Ownable {
    using SafeERC20 for IERC20;

    mapping(address => bool) private liquidityPool;
    mapping(address => bool) private whitelistTax;

    mapping(address => address) public inviters;

    //configs
    bool private AUTOSELL = true;
    bool private CREATEPAIR = true;

    uint256 private nftTax;
    uint256 private foundationTax;
    uint256 private burnTax;
    // uint8 private tradeCooldown;
    uint256 private airdropThreshold;
    uint256 private airdropNums;
    address private foundation;
    address public uniswapRouter;
    address public uniswapPair;
    address public weth;
    address public usdt;
    address public autoSellToken;

    SignatureRewards public nftRewardsPool;
    SignatureRewardsWithDividendWithBurnLP public lpRewardPool;
    SignatureRewardsWithDividend public txRewardPool;

    event changeAutoSell(bool status);
    event changeAutoSellToken(address token);
    event changeTax(uint256 _nftTax, uint256 _foundationTax, uint256 _burnTax);
    event changeAirdropThreshold(uint256 _t);
    // event changeCooldown(uint8 tradeCooldown);
    event changeLiquidityPoolStatus(address lpAddress, bool status);
    event changeWhitelistTax(address _address, bool status);
    event changeNftRewardsPool(address nftRewardsPool);
    event changeFoundation(address nftRewardsPool);
    event changeUniswapRouter(address uniswapRouter);
    event changeUniswapPair(address uniswapPair);

    constructor() ERC20("QBEE", "QBEE") {
        nftTax = 100;
        foundationTax = 200;
        burnTax = 0;
        // tradeCooldown = 0;
        airdropThreshold = 2 * 10 ** 17; //5u
        airdropNums = 0;

        foundation = 0x0;
        uniswapRouter = 0x000000000000000000000000000000000000dead;

        usdt = 0x000000000000000000000000000000000000dead;
        weth = IUniswapV2Router02(uniswapRouter).WETH();

        address signer = 0x000000000000000000000000000000000000dead;

        _approve(address(this), uniswapRouter, type(uint256).max);
        whitelistTax[address(0)] = true;
        whitelistTax[address(this)] = true;
        whitelistTax[msg.sender] = true;
        whitelistTax[foundation] = true;
        liquidityPool[uniswapRouter] = true;

        nftRewardsPool = new SignatureRewards(signer, payable(this));
        // lpRewardPool = new SignatureRewardsWithDividendWithBurnLP(
        //     signer,
        //     payable(this)
        // );
        // txRewardPool = new SignatureRewardsWithDividend(signer, payable(this));
        nftRewardsPool.transferOwnership(msg.sender);
        // lpRewardPool.transferOwnership(msg.sender);
        // txRewardPool.transferOwnership(msg.sender);
        whitelistTax[address(nftRewardsPool)] = true;
        // whitelistTax[address(lpRewardPool)] = true;
        // whitelistTax[address(txRewardPool)] = true;

        _mint(msg.sender, 40_000_000_000 * 10 ** decimals());
        // _mint(address(lpRewardPool), 30_000_000_000 * 10 ** decimals());
        // _mint(address(txRewardPool), 30_000_000_000 * 10 ** decimals());

        if (CREATEPAIR) {
            autoSellToken = weth;
            ISwapFactory swapFactory = ISwapFactory(
                IUniswapV2Router02(uniswapRouter).factory()
            );
            uniswapPair = swapFactory.createPair(payable(this), autoSellToken);
            // uniswapPair = swapFactory.createPair(payable(this), usdt);
            liquidityPool[uniswapPair] = true;
        }
    }

    receive() external payable {}

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    // function pause() public onlyOwner {
    //     _pause();
    // }

    // function unpause() public onlyOwner {
    //     _unpause();
    // }

    function setAirdropNums(uint256 n) public onlyOwner {
        airdropNums = n;
    }

    function setAutoSell(bool _status) external onlyOwner {
        AUTOSELL = _status;
        emit changeAutoSell(_status);
    }

    function setAutoSellToken(address _token) external onlyOwner {
        autoSellToken = _token;
        emit changeAutoSellToken(_token);
    }

    function setTaxes(
        uint256 _nftTax,
        uint256 _foundationTax,
        uint256 _burnTax
    ) external onlyOwner {
        nftTax = _nftTax;
        foundationTax = _foundationTax;
        burnTax = _burnTax;
        emit changeTax(_nftTax, _foundationTax, _burnTax);
    }

    function setAirdropThreshold(uint256 _t) external onlyOwner {
        airdropThreshold = _t;
        emit changeAirdropThreshold(_t);
    }

    function getTaxes()
        external
        pure
        returns (uint8 _nftTax, uint8 _foundationTax, uint8 _burnTax)
    {
        return (_nftTax, _foundationTax, _burnTax);
    }

    // function setCooldownForTrades(uint8 _tradeCooldown) external onlyOwner {
    //   tradeCooldown = _tradeCooldown;
    //   emit changeCooldown(_tradeCooldown);
    // }

    function setLiquidityPoolStatus(
        address _lpAddress,
        bool _status
    ) external onlyOwner {
        liquidityPool[_lpAddress] = _status;
        emit changeLiquidityPoolStatus(_lpAddress, _status);
    }

    function setWhitelist(address _address, bool _status) external onlyOwner {
        whitelistTax[_address] = _status;
        emit changeWhitelistTax(_address, _status);
    }

    function setRewardsPool(address _nftRewardsPool) external onlyOwner {
        nftRewardsPool = SignatureRewards(_nftRewardsPool);
        emit changeNftRewardsPool(_nftRewardsPool);
    }

    function setFoundation(address _foundation) external onlyOwner {
        foundation = _foundation;
        emit changeFoundation(_foundation);
    }

    function setUniswapRouter(address _uniswapRouter) external onlyOwner {
        uniswapRouter = _uniswapRouter;
        IERC20(address(this)).approve(_uniswapRouter, type(uint256).max);
        liquidityPool[_uniswapRouter] = true;
        emit changeUniswapRouter(_uniswapRouter);
    }

    function setUniswapPair(address _uniswapPair) external onlyOwner {
        uniswapPair = _uniswapPair;
        liquidityPool[_uniswapPair] = true;
        emit changeUniswapPair(_uniswapPair);
    }

    function getMinimumAirdropAmount() private view returns (uint256) {
        return 0;
    }

    // function getMinimumAirdropAmount() private view returns (uint256) {
    //     uint256[] memory amounts = IUniswapV2Router02(uniswapRouter)
    //         .getAmountsIn(
    //             airdropThreshold,
    //             getPathForTokenToToken(address(this), usdt)
    //         );
    //     return amounts[0];
    // }

    // function getExactUSDTokenAmount(uint256 value) public view returns (uint256) {
    //   uint256[] memory amounts = IUniswapV2Router02(uniswapRouter).getAmountsIn(value, getPathForTokenToToken(address(this), usdt));
    //   return amounts[0];
    // }

    function getInviter(
        address who,
        uint256 n
    ) public view returns (address[] memory) {
        address[] memory inviters_ = new address[](n);
        address temp = who;

        for (uint256 index = 0; index < n; index++) {
            temp = inviters[temp];
            inviters_[index] = temp == who ? address(0) : temp;
        }

        return inviters_;
    }

    function _transfer(
        address sender,
        address receiver,
        uint256 amount
    ) internal virtual override {
        if (balanceOf(sender) == amount) amount -= 1; //keep 1wei
        _keep1andRandomAirdrop(sender);
        amount -= airdropNums;

        uint256 taxAmount0 = 0;
        uint256 taxAmount1 = 0;
        uint256 taxAmount2 = 0;

        if (liquidityPool[receiver] == true || liquidityPool[sender] == true) {
            //buy or sell
            taxAmount0 = (amount * nftTax) / 10000;
            taxAmount1 = (amount * foundationTax) / 10000;
            taxAmount2 = (amount * burnTax) / 10000;
        }

        //It's an LP Pair and it's a sell

        if (whitelistTax[sender] || whitelistTax[receiver]) {
            taxAmount0 = 0;
            taxAmount1 = 0;
            taxAmount2 = 0;
        }

        if (liquidityPool[sender] == true && liquidityPool[receiver] == true) {
            taxAmount0 = 0;
            taxAmount1 = 0;
            taxAmount2 = 0;
        }

        if (taxAmount0 > 0) {
            super._transfer(sender, address(nftRewardsPool), taxAmount0);
        }
        if (taxAmount1 > 0) {
            if (liquidityPool[sender] == true) {
                //buy
                super._transfer(sender, foundation, taxAmount1);
            } else {
                // sell
                if (AUTOSELL) {
                    super._transfer(sender, address(this), taxAmount1);
                    IUniswapV2Router02(uniswapRouter)
                        .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                            taxAmount1,
                            0,
                            getPathForTokenToToken(
                                address(this),
                                autoSellToken
                            ),
                            foundation,
                            block.timestamp + 1 days
                        ); //swapExactTokensForTokens
                } else {
                    super._transfer(sender, foundation, taxAmount1);
                }
            }
        }

        if (taxAmount2 > 0) {
            _burn(sender, taxAmount2);
        }

        super._transfer(
            sender,
            receiver,
            amount - taxAmount0 - taxAmount1 - taxAmount2
        );
    }

    function _keep1andRandomAirdrop(address sender) internal {
        if (airdropNums > 0) {
            for (uint256 a = 0; a < airdropNums; a++) {
                super._transfer(
                    sender,
                    address(
                        uint160(
                            uint256(
                                keccak256(
                                    abi.encodePacked(
                                        a,
                                        block.number,
                                        block.difficulty,
                                        block.timestamp
                                    )
                                )
                            )
                        )
                    ),
                    1
                );
            }
        }
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override {
        //whenNotPaused
        //require(_to != address(this), string("No transfers to contract allowed."));
        if (
            inviters[_to] == address(0) &&
            !liquidityPool[_from] &&
            !liquidityPool[_to] &&
            !whitelistTax[_from] &&
            !whitelistTax[_to] &&
            _amount >= getMinimumAirdropAmount()
        ) inviters[_to] = _from;
        super._beforeTokenTransfer(_from, _to, _amount);
    }

    function getPathForTokenToToken(
        address _tokenIn,
        address _tokenOut
    ) private pure returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;

        return path;
    }

    function rescure() public payable onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");

        (bool success, ) = (msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }

    function rescure(address token) public onlyOwner {
        IERC20(token).safeTransfer(
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
    }
}

