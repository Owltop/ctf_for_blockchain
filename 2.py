from web3 import Web3
from eth_account import Account
import hashlib


def brute_force_hackers_address(target_address):
    # Подключение к тестовой сети савоилы (Sepolia)
    infura_url = 'https://sepolia.infura.io/v3/3593888cae9745d789d7fcf23d59c09d'
    w3 = Web3(Web3.HTTPProvider(infura_url))

    # Поиск по простым целым числам (ограничение — 100000)
    for i in range(100000):
        # 1. Генерация приватного ключа с добавлением случайного числа
        private_key = Web3.keccak(int(i).to_bytes(32, byteorder='big')).hex()

        # 2. Создание аккаунта на основе сгенерированного приватного ключа
        account = Account.from_key(private_key)
        print(i, account.address.lower())
        
        # 3. Сравнение текущего сгенерированного адреса с целью
        if account.address.lower() == target_address.lower():
            print(f"Приватный ключ найден! Это {private_key}")
            return private_key
    
    print("Приватный ключ не найден!")
    return None


if __name__ == "__main__":
    hackers_address = "0x8Eb1BFF2F3c8Ad583782FfB1ac1Ef963caE9c8eC"
    
    private_key = brute_force_hackers_address(hackers_address)
    if private_key:
        print(f"Адрес хакера сгенерирован: {private_key}")
    else:
        print("Не удалось найти приватный ключ.")