from web3 import Web3
from eth_account import Account
import time

# Подключение к Ethereum RPC (например, Infura, Alchemy, или локальный узел)
INFURA_URL = "https://sepolia.infura.io/v3/3593888cae9745d789d7fcf23d59c09d"
web3 = Web3(Web3.HTTPProvider(INFURA_URL))

# Проверяем подключение
if not web3.isConnected():
    print("Не удалось подключиться к Ethereum сети.")
    exit()

# Приватный ключ основного аккаунта
MAIN_PRIVATE_KEY = "0x2a7ac0ddfa7148381924d49fa279acf7fbeedb073f0b561c3b1f8bf7a586fd1c"  # Ваш главный аккаунт
main_account = web3.eth.account.from_key(MAIN_PRIVATE_KEY)

# Ваш реферальный адрес
REFERRAL_ADDRESS = main_account.address

# Адрес контракта и ABI
VAULT_CONTRACT_ADDRESS = "0x0cf69A44C158fC145A39A1a578074a4831493742"
VAULT_CONTRACT_ABI = [
    {
        "constant": False,
        "inputs": [{"name": "_partner", "type": "address"}],
        "name": "follow_the_link",
        "outputs": [],
        "payable": False,
        "stateMutability": "nonpayable",
        "type": "function",
    },
]

# Указываем контракт
vault_contract = web3.eth.contract(address=VAULT_CONTRACT_ADDRESS, abi=VAULT_CONTRACT_ABI)

# Количество аккаунтов для создания
NUM_ACCOUNTS = 100000

# Сумма ETH, которую нужно отправить каждому аккаунту (достаточно для одной транзакции)
FUNDING_AMOUNT = web3.toWei(0.001, 'ether')  # 0.001 ETH


def create_account():
    """Создаем новый случайный аккаунт"""
    acct = Account.create()
    return acct


def fund_account(account_address):
    """Отправляем немного ETH для покрытия газа"""
    tx = {
        'from': main_account.address,
        'to': account_address,
        'value': FUNDING_AMOUNT,
        'gas': 21000,
        'gasPrice': web3.toWei('20', 'gwei'),
        'nonce': web3.eth.get_transaction_count(main_account.address),
    }
    # Подписываем и отправляем транзакцию
    signed_tx = web3.eth.account.sign_transaction(tx, private_key=MAIN_PRIVATE_KEY)
    tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
    web3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"Финансирован аккаунт {account_address}, tx hash: {tx_hash.hex()}")


def call_follow_the_link(account, private_key):
    """Вызов метода follow_the_link от имени нового аккаунта"""
    nonce = web3.eth.get_transaction_count(account.address)
    tx = vault_contract.functions.follow_the_link(REFERRAL_ADDRESS).build_transaction({
        'from': account.address,
        'gas': 100000,
        'gasPrice': web3.toWei('20', 'gwei'),
        'nonce': nonce
    })
    signed_tx = web3.eth.account.sign_transaction(tx, private_key=private_key)
    tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
    web3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"follow_the_link вызван от аккаунта {account.address}, tx hash: {tx_hash.hex()}")


def main():
    """Основной процесс"""
    for i in range(NUM_ACCOUNTS):
        print(f"Создаем аккаунт {i + 1}/{NUM_ACCOUNTS}...")
        # Шаг 1: Создаем новый случайный аккаунт
        new_account = create_account()
        print(f"Создан новый аккаунт: {new_account.address}")

        # Шаг 2: Финансируем аккаунт
        try:
            fund_account(new_account.address)
        except Exception as e:
            print(f"Ошибка финансирования аккаунта {new_account.address}: {e}")
            continue

        # Шаг 3: Вызываем follow_the_link
        try:
            call_follow_the_link(new_account, new_account.key)
        except Exception as e:
            print(f"Ошибка вызова follow_the_link для аккаунта {new_account.address}: {e}")
            continue

        # Ждем немного, чтобы избежать перегрузки сети
        time.sleep(1)

    print("Все аккаунты обработаны!")


if __name__ == "__main__":
    main()