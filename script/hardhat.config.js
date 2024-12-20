require("@nomicfoundation/hardhat-toolbox");

module.exports = {
    solidity: "0.8.18",
    networks: {
        sepolia: {
            url: "https://sepolia.infura.io/v3/3593888cae9745d789d7fcf23d59c09d", // Замените YOUR_INFURA_PROJECT_ID на ваш ID проекта из Infura
            accounts: ["2a7ac0ddfa7148381924d49fa279acf7fbeedb073f0b561c3b1f8bf7a586fd1c"], // Замените на приватный ключ вашего кошелька (без 0x)
            gasPrice: 20000000000
        },
    },
};