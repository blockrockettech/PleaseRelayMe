/**
 * Because the use of ABIEncoderV2 , the pragma should be locked above 0.5.10 ,
 * as there is a known bug in array storage:
 * https://blog.ethereum.org/2019/06/25/solidity-storage-array-bugs/
 */
pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;

import {RTokenStructs} from "./RTokenStructs.sol";
import {IERC20} from "../IERC20.sol";

/**
 * @notice RToken interface a ERC20 interface and one can mint new tokens by
 *      trasfering underlying token into the contract, configure _hats_ for
 *      addresses and pay earned interest in new _rTokens_.
 */
abstract contract IRToken is RTokenStructs, IERC20 {

    function mint(uint256 mintAmount) external virtual returns (bool);


    function mintWithSelectedHat(uint256 mintAmount, uint256 hatID)
        external virtual
        returns (bool);


    function mintWithNewHat(
        uint256 mintAmount,
        address[] calldata recipients,
        uint32[] calldata proportions
    ) external virtual returns (bool);


    function transferAll(address dst) external virtual returns (bool);


    function transferAllFrom(address src, address dst) external virtual returns (bool);


    function redeem(uint256 redeemTokens) external virtual returns (bool);


    function redeemAll() external virtual returns (bool);


    function redeemAndTransfer(address redeemTo, uint256 redeemTokens)
        external virtual
        returns (bool);


    function redeemAndTransferAll(address redeemTo) external virtual returns (bool);


    function createHat(
        address[] calldata recipients,
        uint32[] calldata proportions,
        bool doChangeHat
    ) external virtual returns (uint256 hatID);


    function changeHat(uint256 hatID) external virtual returns (bool);


    function payInterest(address owner) external virtual returns (bool);

    ////////////////////////////////////////////////////////////////////////////
    // Essential info views
    ////////////////////////////////////////////////////////////////////////////
    /**
     * @notice Get the maximum hatID in the system
     */
    function getMaximumHatID() external virtual view returns (uint256 hatID);


    function getHatByAddress(address owner)
        external
        view
        virtual
        returns (
            uint256 hatID,
            address[] memory recipients,
            uint32[] memory proportions
        );


    function getHatByID(uint256 hatID)
        external
        view
        virtual
        returns (address[] memory recipients, uint32[] memory proportions);

    /**
     * @notice Amount of saving assets given to the recipient along with the
     *         loans.
     * @param owner Account owner address
     */
    function receivedSavingsOf(address owner)
        external
        view
        virtual
        returns (uint256 amount);


    function receivedLoanOf(address owner)
        external
        view
        virtual
        returns (uint256 amount);


    function interestPayableOf(address owner)
        external
        view
        virtual
        returns (uint256 amount);

    ////////////////////////////////////////////////////////////////////////////
    // statistics views
    ////////////////////////////////////////////////////////////////////////////

    function getCurrentSavingStrategy() external view virtual returns (address);


    function getSavingAssetBalance()
        external
        view
        virtual
        returns (uint256 rAmount, uint256 sOriginalAmount);


    function getGlobalStats() external view virtual returns (GlobalStats memory);


    function getAccountStats(address owner)
        external
        view
        virtual
        returns (AccountStatsView memory);


    function getHatStats(uint256 hatID)
        external
        view
        virtual
        returns (HatStatsView memory);

    ////////////////////////////////////////////////////////////////////////////
    // Events
    ////////////////////////////////////////////////////////////////////////////
    /**
     * @notice Event emitted when loans get transferred
     */
    event LoansTransferred(
        address indexed owner,
        address indexed recipient,
        uint256 indexed hatId,
        bool isDistribution,
        uint256 redeemableAmount,
        uint256 internalSavingsAmount);

    /**
     * @notice Event emitted when interest paid
     */
    event InterestPaid(address indexed recipient, uint256 amount);

    /**
     * @notice A new hat is created
     */
    event HatCreated(uint256 indexed hatID);

    /**
     * @notice Hat is changed for the account
     */
    event HatChanged(address indexed account, uint256 indexed oldHatID, uint256 indexed newHatID);
}