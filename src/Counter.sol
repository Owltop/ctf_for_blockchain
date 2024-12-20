// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

interface IUniswapV2Pair {
    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
    external
    view
    returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint);

    function price1CumulativeLast() external view returns (uint);

    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);

    function burn(address to) external returns (uint amount0, uint amount1);

    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;


    function skim(address to) external;

    function sync() external;
}

contract EIP712 {
    bytes32 public constant _TYPE_HASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant _HASHED_NAME = keccak256("PermitCTF");
    bytes32 public constant _VERSION = keccak256("1.0.0");

    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;

    constructor() {
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(_TYPE_HASH, _HASHED_NAME);
    }

    /// @notice Returns the domain separator for the current chain.
    /// @dev Uses cached version if chainid and address are unchanged from construction.
    function DOMAIN_SEPARATOR() public returns (bytes32) {
        return block.chainid == _CACHED_CHAIN_ID
            ? _CACHED_DOMAIN_SEPARATOR
            : _buildDomainSeparator(_TYPE_HASH, _HASHED_NAME);
    }

    /// @notice Builds a domain separator using the current chainId and contract address.
    function _buildDomainSeparator(
        bytes32 typeHash,
        bytes32 nameHash
    ) private returns (bytes32) {
        return keccak256(
            abi.encode(_TYPE_HASH, _HASHED_NAME, _VERSION, block.chainid, address(this))
        );
    }

    /// @notice Creates an EIP-712 typed data hash(V4 compatible)
    function _hashTypedData(bytes32 dataHash) internal returns (bytes32) {
        return keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), dataHash)
        );
    }
}

abstract contract PermitOffchain is EIP712 {
    using ECDSA for bytes;
    using PermitToHash for TransferByPermit;

    error DeadlineExpired();
    error SignatureAndMessageInvalidated();

    mapping(bytes32 => bool) public invalidatedSignatures;

    /// @notice The signed permit message for a single token transfer
    struct TransferByPermit {
        // recipient address
        address to;
        // ERC20 token address
        address token;
        // the transfer amount
        uint256 amount;
        // deadline on the permit signature
        uint256 deadline;
    }

    modifier deadline(uint256 deadlineTimestamp) {
        if (block.timestamp > deadlineTimestamp) revert DeadlineExpired();
        _;
    }

    function _verifyPermit(
        TransferByPermit memory permit,
        address owner,
        bytes calldata signature
    ) internal returns (bool) {
        bytes32 messageHash = _hashTypedData(permit.hash(owner));
        // Verify the signer address from the signature.
        signature.verify(messageHash, owner);

        _invalidateSignature(signature, messageHash);

        return true;
    }

    function _invalidateSignature(bytes memory signature, bytes32 messageHash) internal {
        bytes32 id = keccak256(abi.encode(messageHash, signature));
        if (invalidatedSignatures[id]) revert SignatureAndMessageInvalidated();

        invalidatedSignatures[id] = true;
    }
}

contract Wallet is Ownable, PermitOffchain {

    // Task Setup and Information

    address public pool;
    address public admin;

    event Deposit(address token, uint amount, address recipient);
    event Withdraw(address token, uint amount, address recipient);
    event WithdrawByPermit(TransferByPermit permit, address owner, bytes signature);

    /// @notice the function used for inital setup the task when created.
    function initialize(
        TransferByPermit memory permit,
        address _owner,
        bytes calldata signature,
        address _pool,
        uint256 amount0Out,
        uint256 amount1Out
    ) external onlyOwner() {
        pool = _pool;
        admin = _owner;

        // TransferFrom owner -> pair
        withdrawByPermit(permit, _owner, signature);

        // swap all transferred tokens
        IUniswapV2Pair(_pool).swap(amount0Out, amount1Out, _owner, new bytes(0));
    }

    // @notice The task is solved if the player was can to steal any amount of token from the admin account.
    function isSolved(address player, address token) external returns (bool) {
        return ERC20(token).balanceOf(player) > 0 && depositedAmounts[admin][token] == 0;
    }

    // Main logic

    error InvalidToken();
    error InvalidAmount();
    error InsufficientBalance();
    error InsufficientDeposit();
    error InsufficientApproval();
    error SignatureVerification();
    error InvalidRecipient();

    // user => token => amount
    mapping(address => mapping(address => uint256)) public depositedAmounts;

    function deposit(address _token, uint256 _amount, address _recipient) public {
        _deposit(_token, _amount, _recipient);
    }

    function withdraw(address _token, uint256 _amount) public {
        _withdraw(_token, _amount, msg.sender, msg.sender);
        emit Withdraw(_token, _amount, msg.sender);
    }

    function withdrawByPermit(
        TransferByPermit memory permit,
        address owner,
        bytes calldata signature
    ) public deadline(permit.deadline) {
        if (!_verifyPermit(permit, owner, signature)) revert SignatureVerification();

        _withdraw(
            permit.token,
            permit.amount,
            owner,
            permit.to
        );

        emit WithdrawByPermit(permit, owner, signature);
    }

    function _deposit(address _token, uint256 _amount, address _recipient) internal {
        if (_token == address(0)) revert InvalidToken();
        ERC20 token = ERC20(_token);

        if (_amount == 0) revert InvalidAmount();
        if (_amount > token.balanceOf(msg.sender)) revert InsufficientBalance();
        if (_amount > token.allowance(msg.sender, address(this))) revert InsufficientApproval();
        if (_recipient == address(this)) revert InvalidRecipient();

        uint256 newAmount = depositedAmounts[_recipient][_token] + _amount;
        depositedAmounts[_recipient][_token] = newAmount;

        token.transferFrom(msg.sender, address(this), _amount);

        emit Deposit(_token, _amount, _recipient);
    }

    function _withdraw(
        address _token,
        uint256 _amount,
        address _from,
        address _to
    ) internal {
        if (_token == address(0)) revert InvalidToken();
        ERC20 token = ERC20(_token);

        if (_amount == 0) revert InvalidAmount();
        uint256 currentAmount = depositedAmounts[_from][_token];
        if (_amount > currentAmount) revert InsufficientDeposit();
        if (_to == address(this)) revert InvalidRecipient();

        uint256 newAmount = currentAmount - _amount;
        depositedAmounts[_from][_token] = newAmount;

        token.transfer(_to, _amount);
    }
}

library PermitToHash {

    bytes32 public constant _PERMIT_TRANSFER_TYPEHASH = keccak256("TransferByPermit(address from,address to,address token,uint256 amount,uint256 deadline)");

    function hash(
        PermitOffchain.TransferByPermit memory permit,
        address owner
    ) internal view returns (bytes32) {
        return
        keccak256(
            abi.encode(
                _PERMIT_TRANSFER_TYPEHASH,
                owner,
                permit.to,
                permit.token,
                permit.amount,
                permit.deadline
            )
        );
    }
}

library ECDSA {

    error InvalidSignatureLength();
    error InvalidSignatureV();
    error InvalidSignature();
    error InvalidSigner(address expectedSigner, address claimedSigner, bytes32 hash);

    function verify(
        bytes calldata signature,
        bytes32 hash,
        address claimedSigner
    ) internal view {
        bytes32 r;
        bytes32 s;
        uint8 v;

        if (signature.length == 65) {
            (r, s) = abi.decode(signature, (bytes32, bytes32));
            v = uint8(signature[64]);
        } else {
            revert InvalidSignatureLength();
        }

        if (v != 27 && v != 28) {
            revert InvalidSignatureV();
        }

        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) revert InvalidSignature();
        if (signer != claimedSigner) revert InvalidSigner(signer, claimedSigner, hash);
    }
}