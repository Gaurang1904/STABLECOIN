// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    /////////////////////
    // Constructor Tests
    /////////////////////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDosentMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressAndPriceFeedAddressMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    ////////////////
    // Price Tests
    ////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testgetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    //////////////////////////
    // depositCollateral Test
    //////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovalCollateral() public {
        ERC20Mock ranToken = new ERC20Mock();
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    //////////////////////////////////////
    // depositCollateralAndMintDsc Tests
    /////////////////////////////////////

    function testDepositCollateralAndMintDscMintsAndDeposits() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        // user deposits 10 WETH and mints 5 DSC
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 5 ether);
        vm.stopPrank();

        // check state
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        assertEq(totalDscMinted, 5 ether, "DSC minted mismatch");
        assertGt(collateralValueInUsd, 0, "Collateral value should be > 0");
        assertEq(dsc.balanceOf(USER), 5 ether, "User should own 5 DSC");
    }

    function testDepositCollateralAndMintDscRevertsIfZeroCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedMoreThanZero.selector);
        dsce.depositCollateralAndMintDsc(weth, 0, 5 ether);
        vm.stopPrank();
    }

    function testDepositCollateralAndMintDscRevertsIfZeroMint() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedMoreThanZero.selector);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 0);
        vm.stopPrank();
    }

    function testDepositCollateralAndMintDscRevertsIfHealthFactorBroken() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        // try to mint way more DSC than collateral supports
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__BreaksHealthFactor.selector,
                uint256(1e16) // whatever the trace showed
            )
        );
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 1_000_000 ether);

        vm.stopPrank();
    }

    //////////////////////
    // mintDsc Tests
    //////////////////////

    function testMintDscRevertsIfZero() public depositCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedMoreThanZero.selector);
        dsce.mintDsc(0);
        vm.stopPrank();
    }

    function testMintDscRevertsIfHealthFactorBroken() public depositCollateral {
        vm.startPrank(USER);
        // try to mint way too much DSC against 10 ETH collateral
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__BreaksHealthFactor.selector,
                uint256(1e16) // whatever health factor you saw in traces
            )
        );
        dsce.mintDsc(1_000_000 ether);
        vm.stopPrank();
    }

    function testMintDscMintsSuccessfully() public depositCollateral {
        vm.startPrank(USER);
        uint256 mintAmount = 1 ether;
        dsce.mintDsc(mintAmount);
        vm.stopPrank();

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);

        assertEq(totalDscMinted, mintAmount, "Minted DSC mismatch");
        assertGt(collateralValueInUsd, 0, "Collateral value should remain > 0");
        assertEq(dsc.balanceOf(USER), mintAmount, "User DSC balance mismatch");
    }

    //////////////////////////
    // redeemCollateral tests
    //////////////////////////

    function testRedeemCollateralHappyPath() public {
        // 1. Deposit collateral first
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

        // 2. Redeem part of it
        uint256 redeemAmount = 5 ether;
        dsce.redeemCollateral(weth, redeemAmount);
        vm.stopPrank();

        // 3. Check storage & balance updates
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);

        assertEq(totalDscMinted, 0, "No DSC should be minted");
        // Remaining collateral = 10 - 5
        uint256 expectedRemaining = AMOUNT_COLLATERAL - redeemAmount;
        assertEq(
            ERC20Mock(weth).balanceOf(USER),
            STARTING_ERC20_BALANCE - AMOUNT_COLLATERAL + redeemAmount,
            "User WETH balance mismatch after redeem"
        );

        // Collateral value should be based on remaining amount
        uint256 expectedUsd = dsce.getUsdValue(weth, expectedRemaining);
        assertEq(collateralValueInUsd, expectedUsd, "Collateral value mismatch after redeem");
    }

    // function testRedeemCollateralRevertsIfHealthFactorBroken() public {
    //     vm.startPrank(USER);
    //     ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
    //     dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

    //     // Mint close to the limit but still safe (say 9_000 DSC)
    //     dsce.mintDsc(9_000 ether);

    //     // Redeeming now should break HF
    //     vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
    //     dsce.redeemCollateral(weth, 5 ether);

    //     vm.stopPrank();
    // }

    // function testMintRevertsIfHealthFactorBroken() public {
    //     vm.startPrank(USER);
    //     ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
    //     dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

    //     vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
    //     dsce.mintDsc(15_000 ether);

    //     vm.stopPrank();
    // }

    
}
