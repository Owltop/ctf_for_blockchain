// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleCTF {
    address public owner; // Переменная для хранения адреса владельца

    constructor() {
        // Устанавливаем владельца контракта как того, кто сделал деплой
        owner = msg.sender;
    }

    // Уязвимая функция для смены владельца
    function setOwner(address _newOwner) public {
        // Ошибка: Смена владельца возможна любым адресом!
        owner = _newOwner;
    }

    // Функция для внесения средств (добавим немного баланса)
    function deposit() public payable {}

    // Функция для вывода всех средств
    function withdraw() public {
        require(msg.sender == owner, "Not the owner"); // Только владелец может выводить
        payable(owner).transfer(address(this).balance);
    }

    // Вспомогательная функция для проверки баланса контракта
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
