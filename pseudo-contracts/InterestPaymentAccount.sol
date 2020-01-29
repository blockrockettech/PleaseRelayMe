contract InterestPaymentAccount {
    IERC20 public DAI;
    IRToken public rDAI;

    address relayer;

    function accruedInterest() returns (uint256) {
        return rDAI.interestPayableOf(address(this));
    }

    function claimInterest() onlyRelayer returns (bool) {
        rDAI.payInterest(address(this));

        rDAI.redeemAll();

        DAI.transfer(relayer, DAI.balanceOf(address(this)));

        return true;
    }
}