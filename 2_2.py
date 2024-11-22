from web3 import Web3
from eth_account import Account
import hashlib

def send_transaction_to_clean_balance(private_key, target_address):
    account = Account.from_key(private_key)
    
    # Подключение к Sepolia сети через Infura
    infura_url = 'https://sepolia.infura.io/v3/3593888cae9745d789d7fcf23d59c09d'
    w3 = Web3(Web3.HTTPProvider(infura_url))
    
    # Получение nonce для аккаунта хакера
    nonce = w3.eth.get_transaction_count(account.address)
    balance = w3.eth.get_balance(account.address)
    print(balance)
    
    # Создание транзакции
    tx = {
        'nonce': nonce,
        'to': "0x8029505591A4e95cE2945B62d46e64dC4dDC9DeC",
        'value': Web3.to_wei(0.0003, 'ether'),  # Мы хотим отправить меньше 0.001 ETH
        'gas': 21000,
        'gasPrice': w3.to_wei('5', 'gwei')
    }

    0.000685000000000000
    0.000580000000000000
    0.000070000000000000

    # Подписание транзакции
    signed_tx = w3.eth.account.sign_transaction(tx, private_key)

    # Отправка транзакции
    tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    print(f"Транзакция отправлена: {tx_hash.hex()}")

    # Ожидание записи транзакции в блокчейн
    tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"Транзакция подтверждена в блоке: {tx_receipt.blockNumber}")


if __name__ == "__main__":
    private_key = "07a894ea1d6d3ae1dfc790d49042bdd34a36e7599f417ed6f38eb8922651dce0"
    hackers_address = "0x8Eb1BFF2F3c8Ad583782FfB1ac1Ef963caE9c8eC"
    
    send_transaction_to_clean_balance(private_key, hackers_address)