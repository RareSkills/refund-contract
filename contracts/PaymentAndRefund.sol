//SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity 0.8.17;

///@author M. Burke
///@notice This is a payment contract that enforces a refund schedule.

contract PaymentAndRefund {
    IERC20 USDC;
    uint8[15] public refundSchedule = [
        100,
        100,
        75,
        75,
        75,
        75,
        50,
        50,
        50,
        50,
        25,
        25,
        25,
        25,
        0
    ];

    uint64 public priceInDollars;
    uint256 public depositedUSDC = 0;
    mapping(address => Deposit) public deposits;
    address public admin;
    uint256 public constant MAX_TIME_FROM_START = 30 days;
    uint256 public constant USDC_DECIMALS = 10**6;

    ///@notice This struct is used to handle book keeping for each user.

    struct Deposit {
        uint64 originalDepositInDollars;
        uint64 balanceInDollars;
        uint64 depositTime;
        uint64 startTime;
        uint8[15] refundSchedule;
    }

    constructor(address _usdc) {
        admin = msg.sender;
        USDC = IERC20(_usdc);
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "onlyAdmin");
        _;
    }

    ///@notice Users are required to make allowance with USDC contract before calling.
    ///@param _price The price in dollars to be paid.
    ///@param _startTime The start time in seconds. See EPOCH time converter.

    function payUpfront(uint64 _price, uint64 _startTime) external {
        uint64 currentPriceInDollars = priceInDollars;
        uint64 currentTime = uint64(block.timestamp);

        uint256 maxPastTime = currentTime - MAX_TIME_FROM_START;
        uint256 maxFutureTime = currentTime + MAX_TIME_FROM_START;

        require(
            _startTime >= maxPastTime && _startTime <= maxFutureTime,
            "User must select start time within bounds."
        );
        require(
            deposits[msg.sender].depositTime == 0,
            "User cannot deposit twice."
        );
        require(
            _price == currentPriceInDollars,
            "User must pay correct price."
        );
        require(
            USDC.allowance(msg.sender, address(this)) >=
                currentPriceInDollars * USDC_DECIMALS,
            "User must have made allowance via USDC contract."
        );

        USDC.transferFrom(
            msg.sender,
            address(this),
            currentPriceInDollars * USDC_DECIMALS
        );

        unchecked {
            depositedUSDC += currentPriceInDollars;
        }

        Deposit memory deposit;
        deposit = Deposit({
            originalDepositInDollars: currentPriceInDollars,
            balanceInDollars: currentPriceInDollars,
            depositTime: currentTime,
            startTime: _startTime,
            refundSchedule: refundSchedule
        });

        deposits[msg.sender] = deposit;
    }

    ///@notice Users can claim refund and remove 'account' from contract.

    function buyerClaimRefund() external {
        uint256 refundInDollars = calculateRefundDollars(msg.sender);

        depositedUSDC -= refundInDollars;
        delete deposits[msg.sender];

        USDC.transfer(msg.sender, refundInDollars * USDC_DECIMALS);
    }

    ///@dev See that `priceInDollars` is mutable BUT current price is stored
    ///     in user struct at time of purchase.
    ///@param _price The price in dollars to be set.

    function setPrice(uint64 _price) external onlyAdmin {
        priceInDollars = _price;
    }

    ///@dev See that `refundSchedule` is mutable BUT current schedule is
    ///     stored in user struct at time of purchase.
    ///@param _schedule The new 15 week schedule(as an array) to be set.

    function setRefundSchedule(uint8[15] calldata _schedule)
        external
        onlyAdmin
    {
        require(
            _schedule[0] > 0,
            "must have at least 1 non-zero refund period"
        );
        require(
            _schedule[_schedule.length - 1] == 0,
            "must end with zero refund"
        );

        uint256 len = _schedule.length;
        for (uint256 i = 0; i < len - 1; ) {
            uint256 idxValue = _schedule[i];
            require(
                idxValue >= _schedule[i + 1],
                "refund must be non-increasing"
            );
            require(idxValue < 101, "refund cannot exceed 100%");
            unchecked {
                ++i;
            }
        }
        refundSchedule = _schedule;
    }

    ///@dev Push payment to user and removal of 'account'
    ///@param _buyer The user's wallet address who is to be removed.

    function sellerTerminateAgreement(address _buyer) external onlyAdmin {
        uint256 refundInDollars = calculateRefundDollars(_buyer);

        depositedUSDC -= refundInDollars;
        delete deposits[_buyer];

        USDC.transfer(_buyer, refundInDollars * USDC_DECIMALS);
    }

    ///@dev See calculation to ensure user refund policy is respected.
    ///@param _buyers An array of active user accounts (wallet addresses)
    ///       to withdraw funds from.

    function sellerWithdraw(address[] calldata _buyers) external onlyAdmin {
        uint256 dollarsToWithdraw = 0;
        uint256 len = _buyers.length;

        for (uint256 i = 0; i < len; ) {
            uint256 safeValue = calculateSafeWithdrawDollars(_buyers[i]);

            deposits[_buyers[i]].balanceInDollars -= uint64(safeValue);
            unchecked {
                dollarsToWithdraw += safeValue;
                ++i;
            }
        }
        depositedUSDC -= dollarsToWithdraw;
        USDC.transfer(admin, dollarsToWithdraw * USDC_DECIMALS);
    }

    ///@notice This is used internally for book keeping but made available
    ///        publicaly.
    ///@param _buyer User wallet address.

    function calculateRefundDollars(address _buyer)
        public
        view
        returns (uint256)
    {
        uint256 paidDollars = deposits[_buyer].originalDepositInDollars;
        uint256 scheduleLength = deposits[_buyer].refundSchedule.length;

        uint256 weeksComplete = _getWeeksComplete(_buyer);
        uint256 multiplier;

        if (weeksComplete < scheduleLength) {
            multiplier = deposits[_buyer].refundSchedule[weeksComplete];
        }

        if (weeksComplete > scheduleLength) {
            multiplier = 0;
        }

        return (paidDollars * multiplier) / 100;
    }

    ///@notice This is used internally for book keeping but made available
    ///        publicaly.
    ///@param _buyer User wallet address.

    function calculateSafeWithdrawDollars(address _buyer)
        public
        view
        returns (uint256)
    {
        uint256 accountRequirments = calculateRefundDollars(_buyer);
        uint256 accountBalance = deposits[_buyer].balanceInDollars;

        if (accountRequirments >= accountBalance) {
            return 0;
        }

        return accountBalance - accountRequirments;
    }

    ///@notice Used interanlly for calculating where a user is within their
    ///        refund schedule.
    ///@param _buyer User wallet address.

    function _getWeeksComplete(address _buyer) internal view returns (uint256) {
        uint256 startTime = deposits[_buyer].startTime;
        uint256 currentTime = block.timestamp;

        if (currentTime < startTime) {
            return 0;
        }

        uint256 weeksComplete = (currentTime - startTime) / 1 weeks;

        return weeksComplete;
    }

    ///@notice Used to recover ERC20 tokens transfered to contract
    ///        outside of standard interactions.
    ///@param _tokenContract The contract address of a standard ERC20
    ///@param _amount The value (with correct decimals) to be recovered.

    function rescueERC20Token(IERC20 _tokenContract, uint256 _amount)
        external
        onlyAdmin
    {
        if (_tokenContract != USDC) {
            _tokenContract.transfer(admin, _amount);
            return;
        }

        // For transfer of USDC make check (passed in `_amount` is ignored and
        // amountToWithdraw is calculated.

        uint256 contractBalance = USDC.balanceOf(address(this));

        if (contractBalance > depositedUSDC * USDC_DECIMALS) {
            uint256 amountToWithdraw = contractBalance -
                (depositedUSDC * USDC_DECIMALS);
            _tokenContract.transfer(admin, amountToWithdraw);
        }
    }
}
