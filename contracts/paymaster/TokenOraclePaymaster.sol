// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "@account-abstraction/contracts/core/BasePaymaster.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/UserOperation.sol";

import "../core/interfaces/IOracle.sol";

contract TokenOraclePaymaster is BasePaymaster, Pausable {

    using SafeMath for uint256;
    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;

    uint256 public constant POST_OP_GAS = 50000;
    uint8 public immutable payTokenDecimals;
    uint8 public oracleAnswerDecimals;
    IOracle public oracle;
    IERC20Metadata public payToken;

    event UserOperationSponsored(address indexed  sender, uint256 actualTokenNeeded, uint256 actualGasCost, int256 oracleAnswer);
    event Withdraw(address indexed token, address indexed to, uint256 value);
    event Received(address indexed sender, uint256 value);
    event UpdatedOracle(address indexed oldOracle, address indexed newOracle);

    constructor(IEntryPoint _entryPoint, IOracle _oracle, address _token) BasePaymaster(_entryPoint) {
        _transferOwnership(msg.sender);
        oracle = _oracle;
        payToken = IERC20Metadata(_token);
        payTokenDecimals = payToken.decimals();
        oracleAnswerDecimals = oracle.decimals();
    }

    function updateOracle(IOracle _oracle) external onlyOwner {
        address oldOracle = address(oracle);
        oracle = _oracle;
        oracleAnswerDecimals = oracle.decimals();
        emit UpdatedOracle(oldOracle, address(_oracle));
    }

    function updatePause() external onlyOwner {
        if (paused()) {
            _unpause();
        } else {
            _pause();
        }
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

        context = abi.encode(
            userOp.sender, 
            userOp.maxFeePerGas,
            userOp.maxPriorityFeePerGas,
            requiredPreFund
        );

        return (context, _packValidationData(false,0,0));
    }

    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        _requireNotPaused();
        // decode context
        (address sender, uint256 maxFeePerGas, uint256 maxPriorityFeePerGas, ) = abi.decode(
            context,
            (address,uint256,uint256,uint256)
        );
        if (mode == PostOpMode.postOpReverted) {
            // must revert, because it's available to everyone.
            revert("paymaster: postOp reverted");
        }
        // post op gas
        uint256 opGasPrice = gasPrice(maxFeePerGas, maxPriorityFeePerGas);
        actualGasCost = actualGasCost + (POST_OP_GAS * opGasPrice);
        // get native's price from oracle
        int256 tokenPrice = oracle.latestAnswer();
        uint256 tokenAmount = actualGasCost.mul(uint256(tokenPrice))
            .mul(10**payTokenDecimals)
            .div(1e18)
            .div(10**oracleAnswerDecimals);
        SafeERC20.safeTransferFrom(payToken, sender, address(this), tokenAmount);
        emit UserOperationSponsored(sender, tokenAmount, actualGasCost, tokenPrice);
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