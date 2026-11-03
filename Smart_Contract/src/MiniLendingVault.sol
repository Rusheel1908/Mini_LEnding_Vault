// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IERC20Vault {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title MiniLendingVault
/// @notice A simplified lending vault for educational use.
/// @dev Assumptions: tokens are standard ERC20s with 18 decimals and have no
/// fee-on-transfer, rebasing, or hook behavior. Lend and collateral tokens are
/// distinct and are accounted for separately. There is no interest or
/// liquidation; third-party collateral top-ups are the only rescue path.
/// The owner-set collateral price is an oracle stand-in, not a real oracle.
/// Internal accounting is authoritative, so unsolicited token donations do
/// not affect lender share pricing or available liquidity.
contract MiniLendingVault {
    IERC20Vault public immutable lendToken;
    IERC20Vault public immutable collateralToken;
    address public immutable owner;
    uint256 public collateralPrice;

    uint256 public constant COLLATERAL_FACTOR = 1.5e18;
    uint256 public constant PRICE_SCALE = 1e18;

    uint256 public totalSupplied;
    uint256 public totalBorrowed;
    uint256 public totalShares;

    mapping(address => uint256) public shares;
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public debt;

    uint256 private _locked = 1;

    error ZeroAmount();
    error ZeroPrice();
    error NotOwner();
    error TransferFailed();
    error InsufficientShares();
    error InsufficientLiquidity();
    error InsufficientCollateral();
    error UnhealthyPosition();
    error NothingToTopUp();
    error Reentrancy();

    event Deposit(address indexed lender, uint256 assets, uint256 shares);
    event Withdraw(address indexed lender, uint256 assets, uint256 shares);
    event CollateralDeposited(address indexed borrower, uint256 amount);
    event CollateralWithdrawn(address indexed borrower, uint256 amount);
    event Borrow(address indexed borrower, uint256 amount);
    event Repay(address indexed borrower, uint256 amount);
    event CollateralToppedUp(address indexed payer, address indexed borrower, uint256 amount);
    event CollateralPriceUpdated(uint256 oldPrice, uint256 newPrice);

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(IERC20Vault lendToken_, IERC20Vault collateralToken_, uint256 initialPrice) {
        if (initialPrice == 0) revert ZeroPrice();
        lendToken = lendToken_;
        collateralToken = collateralToken_;
        collateralPrice = initialPrice;
        owner = msg.sender;
        emit CollateralPriceUpdated(0, initialPrice);
    }

    function setCollateralPrice(uint256 newPrice) external nonReentrant {
        if (msg.sender != owner) revert NotOwner();
        if (newPrice == 0) revert ZeroPrice();

        uint256 oldPrice = collateralPrice;
        collateralPrice = newPrice;
        emit CollateralPriceUpdated(oldPrice, newPrice);
    }

    function availableLiquidity() public view returns (uint256) {
        return totalSupplied - totalBorrowed;
    }

    function deposit(uint256 amount) external nonReentrant returns (uint256 mintedShares) {
        if (amount == 0) revert ZeroAmount();

        mintedShares = totalShares == 0 ? amount : (amount * totalShares) / totalSupplied;
        if (mintedShares == 0) revert ZeroAmount();

        totalSupplied += amount;
        totalShares += mintedShares;
        shares[msg.sender] += mintedShares;

        _pull(lendToken, msg.sender, amount);
        emit Deposit(msg.sender, amount, mintedShares);
    }

    function withdraw(uint256 shareAmount) external nonReentrant returns (uint256 assets) {
        if (shareAmount == 0) revert ZeroAmount();
        uint256 userShares = shares[msg.sender];
        if (userShares < shareAmount) revert InsufficientShares();

        assets = (shareAmount * totalSupplied) / totalShares;
        if (assets > availableLiquidity()) revert InsufficientLiquidity();

        shares[msg.sender] = userShares - shareAmount;
        totalShares -= shareAmount;
        totalSupplied -= assets;

        _push(lendToken, msg.sender, assets);
        emit Withdraw(msg.sender, assets, shareAmount);
    }

    function depositCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        collateral[msg.sender] += amount;
        _pull(collateralToken, msg.sender, amount);
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 userCollateral = collateral[msg.sender];
        if (userCollateral < amount) revert InsufficientCollateral();

        collateral[msg.sender] = userCollateral - amount;
        if (!_isHealthy(msg.sender)) revert UnhealthyPosition();

        _push(collateralToken, msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, amount);
    }

    function borrow(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > availableLiquidity()) revert InsufficientLiquidity();

        debt[msg.sender] += amount;
        totalBorrowed += amount;
        if (!_isHealthy(msg.sender)) revert UnhealthyPosition();

        _push(lendToken, msg.sender, amount);
        emit Borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external nonReentrant returns (uint256 repaid) {
        if (amount == 0) revert ZeroAmount();
        uint256 outstandingDebt = debt[msg.sender];
        repaid = amount > outstandingDebt ? outstandingDebt : amount;
        if (repaid == 0) revert ZeroAmount();

        debt[msg.sender] = outstandingDebt - repaid;
        totalBorrowed -= repaid;

        _pull(lendToken, msg.sender, repaid);
        emit Repay(msg.sender, repaid);
    }

    function healthFactor(address user) public view returns (uint256) {
        uint256 userDebt = debt[user];
        if (userDebt == 0) return type(uint256).max;
        return (collateral[user] * collateralPrice * 2) / (userDebt * 3);
    }

    function collateralShortfall(address borrower) public view returns (uint256) {
        uint256 borrowerDebt = debt[borrower];
        if (borrowerDebt == 0) return 0;

        uint256 requiredCollateral = _ceilDiv(borrowerDebt * COLLATERAL_FACTOR, collateralPrice);
        uint256 currentCollateral = collateral[borrower];
        return requiredCollateral > currentCollateral ? requiredCollateral - currentCollateral : 0;
    }

    function topUpToHealthy(address borrower) external nonReentrant {
        uint256 shortfall = collateralShortfall(borrower);
        if (shortfall == 0) revert NothingToTopUp();

        collateral[borrower] += shortfall;
        _pull(collateralToken, msg.sender, shortfall);
        emit CollateralToppedUp(msg.sender, borrower, shortfall);
    }

    function topUpCollateral(address borrower, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        collateral[borrower] += amount;
        _pull(collateralToken, msg.sender, amount);
        emit CollateralToppedUp(msg.sender, borrower, amount);
    }

    function _isHealthy(address user) private view returns (bool) {
        if (debt[user] == 0) return true;
        return collateral[user] * collateralPrice >= debt[user] * COLLATERAL_FACTOR;
    }

    function _ceilDiv(uint256 numerator, uint256 denominator) private pure returns (uint256) {
        return numerator == 0 ? 0 : (numerator - 1) / denominator + 1;
    }

    function _pull(IERC20Vault token, address from, uint256 amount) private {
        if (!token.transferFrom(from, address(this), amount)) revert TransferFailed();
    }

    function _push(IERC20Vault token, address to, uint256 amount) private {
        if (!token.transfer(to, amount)) revert TransferFailed();
    }
}
