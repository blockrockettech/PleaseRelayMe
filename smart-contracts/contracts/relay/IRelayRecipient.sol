pragma solidity 0.6.2;

abstract contract IRelayRecipient {

    /**
     * return the relayHub of this contract.
     */
    function getHubAddr() public view virtual returns (address);

    /**
     * return the contract's balance on the RelayHub.
     * can be used to determine if the contract can pay for incoming calls,
     * before making any.
     */
    function getRecipientBalance() public view virtual returns (uint256);


     function acceptRelayedCall(
        address relay,
        address from,
        bytes calldata encodedFunction,
        uint256 transactionFee,
        uint256 gasPrice,
        uint256 gasLimit,
        uint256 nonce,
        bytes calldata approvalData,
        uint256 maxPossibleCharge
    )
    external
    view
     virtual
    returns (uint256, bytes memory);

    /*
     * modifier to be used by recipients as access control protection for preRelayedCall & postRelayedCall
     */
    modifier relayHubOnly() {
        require(msg.sender == getHubAddr(),"Function can only be called by RelayHub");
        _;
    }

    /** this method is called before the actual relayed function call.
     * It may be used to charge the caller before (in conjuction with refunding him later in postRelayedCall for example).
     * the method is given all parameters of acceptRelayedCall and actual used gas.
     *
     *
     *** NOTICE: if this method modifies the contract's state, it must be protected with access control i.e. require msg.sender == getHubAddr()
     *
     *
     * Revert in this functions causes a revert of the client's relayed call but not in the entire transaction
     * (that is, the relay will still get compensated)
     */
    function preRelayedCall(bytes calldata context) external virtual returns (bytes32);

    /** this method is called after the actual relayed function call.
     * It may be used to record the transaction (e.g. charge the caller by some contract logic) for this call.
     * the method is given all parameters of acceptRelayedCall, and also the success/failure status and actual used gas.
     *
     *
     *** NOTICE: if this method modifies the contract's state, it must be protected with access control i.e. require msg.sender == getHubAddr()
     *
     *
     * @param success - true if the relayed call succeeded, false if it reverted
     * @param actualCharge - estimation of how much the recipient will be charged. This information may be used to perform local booking and
     *   charge the sender for this call (e.g. in tokens).
     * @param preRetVal - preRelayedCall() return value passed back to the recipient
     *
     * Revert in this functions causes a revert of the client's relayed call but not in the entire transaction
     * (that is, the relay will still get compensated)
     */
    function postRelayedCall(bytes calldata context, bool success, uint actualCharge, bytes32 preRetVal) external virtual;

}