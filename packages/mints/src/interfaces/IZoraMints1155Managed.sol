// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IZoraMints1155Managed {
    function transferBatchToManagerAndCall(
        uint256[] calldata tokenIds,
        uint256[] calldata quantities,
        bytes calldata call
    ) external payable returns (bytes memory callReturn);

    struct PermitBatch {
        // owner of the MINTs to be transferred.  Signer of the permit must match this address.
        address owner;
        // account to be transferred to.
        address to;
        // The ids of the tokens to transfer
        uint256[] tokenIds;
        // Quantities of each token to transfer
        uint256[] quantities;
        // The data to pass to the safeTransferFrom function when transferring.
        bytes safeTransferData;
        // Expiration timestamp for the permit
        uint256 deadline;
        // Nonce for action scoped by user
        uint256 nonce;
    }

    struct PermitSingle {
        // owner of the MINTs to be transferred.  Signer of the permit must match this address.
        address owner;
        // account to be transferred to.
        address to;
        // The ids of the tokens to transfer
        uint256 tokenId;
        // Quantities of each token to transfer
        uint256 quantity;
        // The data to pass to the safeTransferFrom function when transferring.
        bytes safeTransferData;
        // Expiration timestamp for the permit
        uint256 deadline;
        // Nonce for action scoped by user
        uint256 nonce;
    }

    function permitSafeTransferBatch(PermitBatch calldata permit, bytes calldata signature) external;
    function permitSafeTransfer(PermitSingle calldata permit, bytes calldata signature) external;

    /**
     * @dev Returns if the nonce is used for the owner and nonce.
     */
    function nonceUsed(address owner, uint256 nonce) external view returns (bool);

    /**
     * @dev Permit deadline has expired.
     */
    error ERC2612ExpiredSignature(uint256 deadline);

    /**
     * @dev Mismatched signature.
     */
    error InvalidSignature();

    error CallFailed(bytes returnData);
}
