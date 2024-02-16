// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ISwaplace {
  /**
   * @dev Displayed when the caller is not the owner of the swap.
   */
  error InvalidAddress(address caller);

  /**
   * @dev Displayed when the amount of {ISwap-Asset} has a length of zero.
   *
   * NOTE: The `biding` or `asking` array must not be empty to avoid mistakes
   * when creating a swap. Assuming one side of the swap is empty, the
   * correct approach should be the usage of {transferFrom} and we reinforce
   * this behavior by requiring the length of the array to be bigger than zero.
   */
  error InvalidAssetsLength();

  /**
   * @dev Displayed when the `expiry` date is in the past.
   */
  error InvalidExpiration(uint256 timestamp);

  /**
   * @dev Emitted when a new Swap is created.
   */
  event SwapCreated(
    uint256 indexed swapId,
    address indexed owner,
    uint256 expiration
  );

  /**
   * @dev Emitted when a Swap fails.
   */
  event SwapCanceled(uint256 indexed swapId, address indexed owner);
}
