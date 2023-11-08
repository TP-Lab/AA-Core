// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "@account-abstraction/contracts/core/BasePaymaster.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/UserOperation.sol";

import "../core/interfaces/IOracle.sol";

contract TokenPocketPaymaster is BasePaymaster {

    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;

    uint256 private constant VALID_TIMESTAMP_OFFSET = 20;
    uint256 private constant SIGNATURE_OFFSET = 84;
    address public verifyingSigner;

    event PostOpReverted(address indexed user, uint256 preCharge);
    event UserOperationSponsored(address indexed  sender, uint256 requiredPreFund, uint256 actualGasCost);
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

    function getHash(UserOperation calldata userOp, uint48 validUntil, uint48 validAfter)
    public view returns (bytes32) {
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
                    validUntil, 
                    validAfter
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
        (uint48 validUntil, uint48 validAfter, bytes calldata signature) = parsePaymasterAndData(userOp.paymasterAndData);

        //ECDSA library supports both 64 and 65-byte long signatures.
        //  we only "require" it here so that the revert reason on invalid signature will be of "VerifyingPaymaster", and not "ECDSA"
        require(signature.length == 64 || signature.length == 65, "VerifyingPaymaster: invalid signature length in paymasterAndData");
        bytes32 hash = ECDSA.toEthSignedMessageHash(getHash(userOp, validUntil, validAfter));

        context = abi.encode(
            userOp.sender,
            requiredPreFund
        );

        //don't revert on signature failure: return SIG_VALIDATION_FAILED
        if (verifyingSigner != ECDSA.recover(hash, signature)) {
            return (context, _packValidationData(true,validUntil,validAfter));
        }
        return (context, _packValidationData(false,validUntil,validAfter));
    }

    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        // decode context
        (address sender, uint256 requiredPreFund) = abi.decode(context, (address,uint256));
        if (mode == PostOpMode.postOpReverted) {
            emit PostOpReverted(sender, requiredPreFund);
            // Do nothing here to not revert the whole bundle and harm reputation
            return;
        }
        emit UserOperationSponsored(sender, requiredPreFund, actualGasCost);
    }

    function parsePaymasterAndData(
        bytes calldata paymasterAndData
    ) public pure returns (uint48 validUntil, uint48 validAfter, bytes calldata signature) {
        (validUntil, validAfter) = abi.decode(paymasterAndData[VALID_TIMESTAMP_OFFSET:SIGNATURE_OFFSET],(uint48, uint48));
        signature = paymasterAndData[SIGNATURE_OFFSET:];
    }
}