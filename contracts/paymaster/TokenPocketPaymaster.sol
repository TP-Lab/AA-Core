// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "@account-abstraction/contracts/core/BasePaymaster.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/UserOperation.sol";

import "../core/interfaces/IOracle.sol";

contract TokenPocketPaymaster is BasePaymaster {

    using SafeMath for uint256;
    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;

    uint256 private constant VALID_TIMESTAMP_OFFSET = 20;
    uint256 private constant SIGNATURE_OFFSET = 148;
    uint256 public constant POST_OP_GAS = 50000;
    address public verifyingSigner;

    event UserOperationSponsored(address indexed  sender, uint256 actualTokenNeeded, uint256 actualGasCost, uint256 exchangeRate);
    event Withdraw(address indexed token, address indexed to, uint256 value);
    event Received(address indexed sender, uint256 value);
    event ChangeVerifyingSigner(address indexed previous, address indexed latest);

    constructor(IEntryPoint _entryPoint, address _verifyingSigner) BasePaymaster(_entryPoint) {
        _transferOwnership(msg.sender);
        verifyingSigner = _verifyingSigner;
    }

    function changeVerifyingSigner(address _verifyingSigner) onlyOwner external {
        require(_verifyingSigner != address(0), "invalid verifying signer");
        address previous = verifyingSigner;
        verifyingSigner = _verifyingSigner;
        emit ChangeVerifyingSigner(previous, _verifyingSigner);
    }

    function getHash(UserOperation calldata userOp, bytes32 paymasterHash) public view returns (bytes32) {
        address sender = userOp.getSender();
        return
        keccak256(
            abi.encode(
                sender,
                userOp.nonce,
                keccak256(userOp.initCode),
                keccak256(userOp.callData),
                userOp.callGasLimit,
                userOp.verificationGasLimit,
                userOp.preVerificationGas,
                userOp.maxFeePerGas,
                userOp.maxPriorityFeePerGas,
                block.chainid,
                address(this),
                paymasterHash
            )
        );
    }

    function withdrawToken(IERC20 token, address payable to, uint256 amount) external onlyOwner {
        if (address(token) == address(0)) {
            to.transfer(amount);
        } else {
            SafeERC20.safeTransfer(token, to, amount);
        }
        emit Withdraw(address(token), to, amount);
    }

    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 requiredPreFund)
    internal override returns (bytes memory context, uint256 validationResult) {
        (requiredPreFund, userOpHash);
        //parsePaymasterAndData
        (uint48 validUntil, uint48 validAfter, address token, uint256 exchangeRate, bytes calldata signature) = parsePaymasterAndData(userOp.paymasterAndData);

        //ECDSA library supports both 64 and 65-byte long signatures.
        //  we only "require" it here so that the revert reason on invalid signature will be of "VerifyingPaymaster", and not "ECDSA"
        require(signature.length == 64 || signature.length == 65, "VerifyingPaymaster: invalid signature length in paymasterAndData");
        bytes32 paymasterHash = keccak256(abi.encode(validUntil, validAfter, exchangeRate, token));
        bytes32 hash = ECDSA.toEthSignedMessageHash(getHash(userOp, paymasterHash));

        context = abi.encode(
            userOp.sender,
            token,
            userOp.maxFeePerGas,
            userOp.maxPriorityFeePerGas,
            requiredPreFund,
            exchangeRate
        );

        //don't revert on signature failure: return SIG_VALIDATION_FAILED
        if (verifyingSigner != ECDSA.recover(hash, signature)) {
            return (context, _packValidationData(true,validUntil,validAfter));
        }
        return (context, _packValidationData(false,validUntil,validAfter));
    }

    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        // decode context
        (address sender, address token, uint256 maxFeePerGas, uint256 maxPriorityFeePerGas, uint256 requiredPreFund, uint256 exchangeRate) = abi.decode(
            context,
            (address,address,uint256,uint256,uint256,uint256)
        );
        if (mode == PostOpMode.postOpReverted) {
            // revert if not paid
            revert("paymaster: postOp reverted");
        }
        // post op gas
        uint256 opGasPrice = gasPrice(maxFeePerGas, maxPriorityFeePerGas);
        actualGasCost = actualGasCost + (POST_OP_GAS * opGasPrice);

        uint256 tokenAmount = actualGasCost.mul(exchangeRate).div(1e18);
        if (tokenAmount > 0) {
            SafeERC20.safeTransferFrom(IERC20(token), sender, address(this), tokenAmount);
        }
        emit UserOperationSponsored(sender, tokenAmount, actualGasCost, exchangeRate);
    }

    function parsePaymasterAndData(
        bytes calldata paymasterAndData
    ) public pure returns (uint48 validUntil, uint48 validAfter,address token, uint256 exchangeRate, bytes calldata signature) {
        (validUntil, validAfter, token, exchangeRate) = abi.decode(paymasterAndData[VALID_TIMESTAMP_OFFSET:SIGNATURE_OFFSET],(uint48, uint48, address, uint256));
        signature = paymasterAndData[SIGNATURE_OFFSET:];
    }

    function gasPrice(uint256 maxFeePerGas, uint256 maxPriorityFeePerGas) internal view returns (uint256) {
    unchecked {
        if (maxFeePerGas == maxPriorityFeePerGas) {
            //legacy mode (for networks that don't support basefee opcode)
            return maxFeePerGas;
        }
        return min(maxFeePerGas, maxPriorityFeePerGas + block.basefee);
    }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}