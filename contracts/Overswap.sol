// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {CCIP} from "./CCIP.sol";
import {IOverswap} from "./interfaces/IOverswap.sol";
import {ITransfer} from "./interfaces/ITransfer.sol";

contract Overswap is CCIP, IOverswap {
  uint256 private _totalSwaps;

  mapping(uint256 => Swap) private _swaps;

  constructor(address _router, address _link) CCIP(_router, _link) {}

  function createSwap(Swap calldata swap) external payable returns (uint256) {
    (, uint64 destinationChainSelector, uint32 expiration) = parseData(
      swap.config
    );

    if (swap.owner != msg.sender) {
      revert InvalidAddress(msg.sender);
    }

    if (expiration < block.timestamp) {
      revert InvalidExpiration(expiration);
    }

    if (swap.biding.length == 0 || swap.asking.length == 0) {
      revert InvalidAssetsLength();
    }

    bytes32 proof = keccak256(abi.encode(swap));

    if (msg.value > 0) {
      _sendMessagePayNative(
        destinationChainSelector,
        allowlistSenders(destinationChainSelector),
        msg.value,
        proof
      );
    } else {
      _sendMessagePayLINK(
        destinationChainSelector,
        allowlistSenders(destinationChainSelector),
        proof
      );
    }

    unchecked {
      assembly {
        sstore(_totalSwaps.slot, add(sload(_totalSwaps.slot), 1))
      }
    }

    _transferFrom(msg.sender, address(this), swap.biding);
    _increaseUnlockSteps(proof);

    uint256 swapId = _totalSwaps;
    _swaps[swapId] = swap;

    emit SwapCreated(swapId, msg.sender, expiration);

    return swapId;
  }

  function acceptSwap(Swap calldata swap) public payable {
    (
      address allowed,
      uint64 destinationChainSelector,
      uint32 expiration
    ) = parseData(swap.config);

    if (allowed != address(0) && allowed != msg.sender) {
      revert InvalidAddress(msg.sender);
    }

    if (expiration < block.timestamp) {
      revert InvalidExpiration(expiration);
    }

    bytes32 proof = keccak256(abi.encode(swap));

    if (msg.value > 0) {
      _sendMessagePayNative(
        destinationChainSelector,
        allowlistSenders(destinationChainSelector),
        msg.value,
        proof
      );
    } else {
      _sendMessagePayLINK(
        destinationChainSelector,
        allowlistSenders(destinationChainSelector),
        proof
      );
    }

    _increaseUnlockSteps(proof);
    _transferFrom(msg.sender, address(this), swap.asking);

    emit SwapAccepted(proof, msg.sender);
  }

  function withdraw(uint256 swapId) public {
    Swap memory swap = getSwap(swapId);
    bytes32 proof = keccak256(abi.encode(swap));

    if (getUnlockSteps(proof) < 2) {
      revert NothingToWithdraw();
    }

    if (swap.owner != msg.sender) {
      revert InvalidAddress(msg.sender);
    }

    _transferFrom(address(this), swap.owner, swap.asking);

    emit Withdraw(proof, msg.sender);
  }

  function _transferFrom(
    address from,
    address to,
    Asset[] memory assets
  ) internal {
    for (uint256 i = 0; i < assets.length; ) {
      ITransfer(assets[i].addr).transferFrom(from, to, assets[i].amountOrId);
      unchecked {
        i++;
      }
    }
  }

  function packData(
    address allowed,
    uint64 destinationChainSelector,
    uint32 expiration
  ) public pure returns (uint256) {
    return
      uint160(allowed) |
      (uint256(destinationChainSelector) << 160) |
      (uint256(expiration) << (160 + 64));
  }

  function parseData(
    uint256 validationData
  ) public pure returns (address, uint64, uint32) {
    return (
      address(uint160(validationData)),
      uint64(validationData >> 160),
      uint32(validationData >> 224)
    );
  }

  function simulateFees(
    Swap calldata swap
  ) public view returns (uint256 fees, bytes32 proof) {
    (, uint64 destinationChainSelector, ) = parseData(swap.config);
    proof = keccak256(abi.encode(swap));
    fees = _simulateFees(
      destinationChainSelector,
      allowlistSenders(destinationChainSelector),
      proof
    );
  }

  function totalSwaps() public view returns (uint256) {
    return _totalSwaps;
  }

  function getSwap(uint256 swapId) public view returns (Swap memory) {
    return _swaps[swapId];
  }

  function redeem() public payable onlyOwner {
    payable(address(msg.sender)).transfer(address(this).balance);
  }
}