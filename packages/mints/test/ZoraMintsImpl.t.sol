// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {IZoraMints1155, IZoraMints1155Errors} from "../src/interfaces/IZoraMints1155.sol";
import {ZoraMints1155} from "../src/ZoraMints1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ReceiveRejector} from "@zoralabs/shared-contracts/mocks/ReceiveRejector.sol";
import {MockPreminter} from "./mocks/MockPreminter.sol";
import {ZoraMintsFixtures} from "./fixtures/ZoraMintsFixtures.sol";
import {TokenConfig, Redemption} from "../src/ZoraMintsTypes.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {ZoraMintsManagerImpl} from "../src/ZoraMintsManagerImpl.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ZoraMints1155Test is Test {
    address admin = makeAddr("admin");
    address proxyAdmin = makeAddr("proxyAdmin");

    IZoraMints1155 mints;
    ZoraMintsManagerImpl mintsManager;

    uint256 initialTokenId = 995;
    uint256 initialTokenPrice = 4.32 ether;

    MockERC20 erc20a;
    MockERC20 erc20b;

    address minter = makeAddr("minter");
    address mintRecipient = makeAddr("mintRecipient");
    address redeemRecipient = makeAddr("redeemRecipient");

    function setUp() external {
        (, mints, mintsManager) = ZoraMintsFixtures.setupMintsProxyWithMockPreminter(proxyAdmin, admin, initialTokenId, initialTokenPrice);
        erc20a = setupMockERC20();
        erc20b = setupMockERC20();
    }

    event TokenCreated(uint256 indexed tokenId, uint256 indexed price, address indexed tokenAddress);

    function test_defaultTokenSettings() external {
        assertEq(ZoraMints1155(address(mints)).name(), "Zora MINTs");
        assertEq(ZoraMints1155(address(mints)).symbol(), "MINT");
        assertEq(mintsManager.mintableEthToken(), initialTokenId);
        assertEq(mintsManager.getEthPrice(), initialTokenPrice);
    }

    function test_ERC165() external {
        assertEq(mints.supportsInterface(0xd9b67a26), true);
        assertEq(mints.supportsInterface(0x01ffc9a7), true);
        assertEq(mints.supportsInterface(0), false);
    }

    function test_mintWithEth_mintsWithInitialSettings() external {
        address collector = makeAddr("collector");
        address recipient = makeAddr("recipient");

        uint256 quantity = 3;
        uint256 quantityToSend = quantity * initialTokenPrice;
        vm.deal(collector, quantityToSend);

        vm.prank(collector);
        uint256 tokenId = mintsManager.mintWithEth{value: quantityToSend}(quantity, recipient);

        assertEq(tokenId, initialTokenId);
        assertEq(payable(address(mints)).balance, quantityToSend);
    }

    function makeEthTokenConfig(uint256 pricePerToken) internal pure returns (TokenConfig memory) {
        return TokenConfig({price: pricePerToken, tokenAddress: address(0), redeemHandler: address(0)});
    }

    function createEthToken(uint256 tokenId, uint256 pricePerToken, bool defaultMintable) internal {
        TokenConfig memory tokenConfig = TokenConfig({price: pricePerToken, tokenAddress: address(0), redeemHandler: address(0)});
        vm.prank(admin);
        mintsManager.createToken(tokenId, tokenConfig, defaultMintable);
    }

    function createErc20Token(uint256 tokenId, address tokenAddress, uint256 pricePerToken, bool defaultMintable) internal {
        TokenConfig memory tokenConfig = TokenConfig({price: pricePerToken, tokenAddress: tokenAddress, redeemHandler: address(0)});
        vm.prank(admin);
        mintsManager.createToken(tokenId, tokenConfig, defaultMintable);
    }

    function setMintableEthToken(uint256 tokenId) internal {
        mintsManager.setDefaultMintable(address(0), tokenId);
    }

    function test_createEthToken_whenDefaultMintable_makesTokenMintable() external {
        uint256 tokenId = 6;
        uint256 pricePerToken = 0.3 ether;
        createEthToken(tokenId, uint96(pricePerToken), true);

        assertEq(mintsManager.mintableEthToken(), tokenId);
        assertEq(mintsManager.getEthPrice(), pricePerToken);
    }

    function test_createEthToken_emitsTokenCreated() external {
        uint256 tokenId = 7;
        uint256 pricePerToken = 0.2 ether;

        TokenConfig memory tokenConfig = makeEthTokenConfig(pricePerToken);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit TokenCreated(tokenId, tokenConfig.price, tokenConfig.tokenAddress);
        mintsManager.createToken(tokenId, tokenConfig, false);
    }

    event DefaultMintableTokenSet(address tokenAddress, uint tokenId);

    function test_createToken_whenDefaultMintable_emitsDefaultMintableTokenSet() external {
        uint256 tokenId = 5;
        uint256 pricePerToken = 10_000_000;

        TokenConfig memory tokenConfig = TokenConfig({price: pricePerToken, tokenAddress: makeAddr("erc20"), redeemHandler: address(0)});

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit DefaultMintableTokenSet(tokenConfig.tokenAddress, tokenId);
        mintsManager.createToken(tokenId, tokenConfig, true);
    }

    function test_getters_getProperValues() external {
        uint256 tokenId = 5;
        uint256 pricePerToken = 0.5 ether;

        createEthToken(tokenId, uint96(pricePerToken), true);

        assertEq(mints.tokenExists(initialTokenId), true);
        assertEq(mints.tokenExists(tokenId), true);

        assertEq(mints.tokenPrice(initialTokenId), initialTokenPrice);
        assertEq(mints.tokenPrice(tokenId), pricePerToken);
    }

    function test_createToken_whenNotDefaultMintable_doesntMakeTokenMintable() external {
        // create a default mintable token
        uint256 tokenId = 5;
        uint256 pricePerToken = 0.5 ether;
        createEthToken(tokenId, uint96(pricePerToken), true);

        // create another non default one
        uint256 tokenId2 = 6;
        uint256 pricePerToken2 = 0.1 ether;
        createEthToken(tokenId2, uint96(pricePerToken2), false);

        // assert that the default one is still mintable
        assertEq(mintsManager.mintableEthToken(), tokenId);
        assertEq(mintsManager.getEthPrice(), pricePerToken);

        // create another one that is default mintable
        uint256 tokenId3 = 7;
        uint256 pricePerToken3 = 0.2 ether;
        createEthToken(tokenId3, uint96(pricePerToken3), true);

        // assert that the new one is the mintable one
        assertEq(mintsManager.mintableEthToken(), tokenId3);
        assertEq(mintsManager.getEthPrice(), pricePerToken3);

        // now set the non default one to be mintable
        vm.prank(admin);
        setMintableEthToken(tokenId2);

        // assert that the new one is the mintable one
        assertEq(mintsManager.mintableEthToken(), tokenId2);
        assertEq(mintsManager.getEthPrice(), pricePerToken2);
    }

    function test_createToken_revertsWhen_tokenAlreadyExists() external {
        uint256 tokenId = 5;
        uint256 pricePerToken = 0.5 ether;
        createEthToken(tokenId, uint96(pricePerToken), true);

        vm.expectRevert(IZoraMints1155Errors.TokenAlreadyCreated.selector);
        createEthToken(tokenId, uint96(pricePerToken), true);

        vm.expectRevert(IZoraMints1155Errors.TokenAlreadyCreated.selector);
        createEthToken(tokenId, uint96(pricePerToken + 1), false);
    }

    function test_createToken_revertsWhen_priceIsLessThanMinimum(uint8 priceChange, bool isEth, bool increases) external {
        vm.assume(priceChange < 2);

        uint256 minimumPrice = isEth ? mints.MINIMUM_ETH_PRICE() : mints.MINIMUM_ERC20_PRICE();

        uint256 tokenId = 5;
        uint256 pricePerToken = minimumPrice;
        if (increases) {
            pricePerToken += priceChange;
        } else {
            pricePerToken -= priceChange;
        }

        TokenConfig memory tokenConfig = TokenConfig({price: pricePerToken, tokenAddress: isEth ? address(0) : makeAddr("erc20"), redeemHandler: address(0)});
        if (pricePerToken < minimumPrice) {
            vm.expectRevert(IZoraMints1155Errors.InvalidTokenPrice.selector);
        }
        vm.prank(admin);
        mintsManager.createToken(tokenId, tokenConfig, false);
    }

    function test_createToken_revertsWhen_notAdmin() external {
        address notAdmin = makeAddr("notAdmin");

        TokenConfig memory tokenConfig = makeEthTokenConfig(0.5 ether);

        vm.startPrank(notAdmin);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notAdmin));
        mintsManager.createToken(1, tokenConfig, false);
    }

    function test_setMintableEthToken_revertsWhen_notAValidToken() external {
        vm.expectRevert(IZoraMints1155Errors.TokenDoesNotExist.selector);
        vm.prank(admin);
        setMintableEthToken(1);
    }

    function test_setMintableethToken_revertsWhen_notAnAdmin() external {
        address notAdmin = makeAddr("notAdmin");

        vm.startPrank(notAdmin);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notAdmin));
        setMintableEthToken(1);
    }

    function test_mintWithEth_whenCorrectEth_resultsInQuantityMintedToRecipient() external {
        uint256 firstTokenId = 3;
        uint256 firstTokenPrice = 0.5 ether;

        createEthToken(firstTokenId, uint96(firstTokenPrice), true);

        address collector = makeAddr("collector");
        address recipient = makeAddr("recipient");

        uint256 quantity = 5;
        uint256 quantityToSend = quantity * mintsManager.getEthPrice();
        vm.deal(collector, quantityToSend);

        vm.prank(collector);
        uint256 tokenId = mintsManager.mintWithEth{value: quantityToSend}(quantity, recipient);

        assertEq(tokenId, firstTokenId, "first token id");
        assertEq(mints.balanceOf(recipient, tokenId), quantity, "quantity minted to recipient");
        assertEq(payable(address(mints)).balance, quantityToSend, "mints balance");
    }

    function test_mintWithEth_revertsWhen_invalidAmountSent(uint8 offset, bool increase) external {
        vm.assume(offset > 0);
        uint256 firstTokenId = 3;
        uint256 firstTokenPrice = 0.5 ether;

        createEthToken(firstTokenId, uint96(firstTokenPrice), true);

        address collector = makeAddr("collector");

        uint256 quantity = 5;
        uint256 quantityToSend = quantity * mintsManager.getEthPrice();
        if (increase) {
            quantityToSend += offset;
        } else {
            quantityToSend -= offset;
        }
        vm.deal(collector, quantityToSend);

        vm.prank(collector);
        vm.expectRevert(IZoraMints1155Errors.IncorrectAmountSent.selector);
        mintsManager.mintWithEth{value: quantityToSend}(quantity, collector);
    }

    function test_mintWithEth_revertsWhen_addressZero() external {
        address collector = makeAddr("collector");
        uint256 quantityToSend = mintsManager.getEthPrice() * 2;
        vm.deal(collector, quantityToSend);
        vm.prank(collector);

        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        mintsManager.mintWithEth{value: quantityToSend}(2, address(0));
    }

    function test_mintTokenWithEth_revertsWhen_notAnEthToken() external {
        // address collector = makeAddr("collector");

        vm.prank(admin);
        mintsManager.createToken(2, TokenConfig({price: 1 ether, tokenAddress: makeAddr("nonEthToken"), redeemHandler: address(0)}), true);

        vm.prank(address(mintsManager));
        vm.expectRevert(abi.encodeWithSelector(IZoraMints1155Errors.TokenMismatch.selector, makeAddr("nonEthToken"), address(0)));
        mints.mintTokenWithEth(2, 5, address(0), "");
    }

    function test_mintTokenWithEth_revertsWhen_notAToken() external {
        vm.prank(address(mintsManager));
        vm.expectRevert(IZoraMints1155Errors.TokenDoesNotExist.selector);
        mints.mintTokenWithEth(2, 5, address(0), "");
    }

    function setupMockERC20() internal returns (MockERC20) {
        MockERC20 mockERC20 = new MockERC20("MockERC20", "MERC20");
        return mockERC20;
    }

    function mintWithERC20(address tokenAddress, uint256 quantityToMint, address recipient) internal {
        mintsManager.mintWithERC20(tokenAddress, quantityToMint, recipient);
    }

    function test_mintWithERC20_transfersBalanceToContract() external {
        MockERC20 erc20 = setupMockERC20();

        uint256 erc20TokenId = 100;
        uint256 tokenPrice = mints.MINIMUM_ERC20_PRICE() * 2;

        uint256 initialErc20Balance = 1000000;

        uint256 quantityToMint = 5;

        uint256 expectedErc20ToTransfer = quantityToMint * tokenPrice;

        // create an erc20 based mint token id using the mock erc20 address as the token address, and set it as default mintable
        vm.prank(admin);
        mintsManager.createToken(erc20TokenId, TokenConfig({price: tokenPrice, tokenAddress: address(erc20), redeemHandler: address(0)}), true);

        // mint some erc20s to the minter
        vm.startPrank(minter);
        erc20.mint(initialErc20Balance);
        // approve what is needed to transfer to the mints contract
        erc20.approve(address(mintsManager), expectedErc20ToTransfer);

        // mint the mint token id using the erc20 token
        mintsManager.mintWithERC20(address(erc20), quantityToMint, mintRecipient);

        assertEq(erc20.balanceOf(minter), initialErc20Balance - expectedErc20ToTransfer);
        assertEq(erc20.balanceOf(address(mints)), expectedErc20ToTransfer);
        assertEq(mints.balanceOf(mintRecipient, erc20TokenId), quantityToMint);
    }

    function test_mintWithERC20_revertsWhen_erc20Slippage() external {
        MockERC20 erc20 = setupMockERC20();

        uint256 erc20TokenId = 100;
        uint256 tokenPrice = mints.MINIMUM_ERC20_PRICE() * 2;

        uint256 initialErc20Balance = 1000000;

        uint256 quantityToMint = 5;

        uint256 expectedErc20ToTransfer = quantityToMint * tokenPrice;

        // create an erc20 based mint token id using the mock erc20 address as the token address, and set it as default mintable
        vm.prank(admin);
        mintsManager.createToken(erc20TokenId, TokenConfig({price: tokenPrice, tokenAddress: address(erc20), redeemHandler: address(0)}), true);

        // set a tax on the erc20
        erc20.setTax(10);

        // mint some erc20s to the minter
        vm.startPrank(minter);
        erc20.mint(initialErc20Balance);
        // approve what is needed to transfer to the mints contract
        erc20.approve(address(mintsManager), expectedErc20ToTransfer);

        vm.expectRevert(IZoraMints1155Errors.ERC20TransferSlippage.selector);
        // mint the mint token id using the erc20 token
        mintsManager.mintWithERC20(address(erc20), quantityToMint, mintRecipient);
    }

    function test_redeem_sendsValueOfTokens_toRecipient(bool isErc20Token) external {
        // create a token
        uint256 tokenId = 5;
        uint256 pricePerToken = isErc20Token ? 100_000 : 1 ether;

        MockERC20 erc20 = setupMockERC20();

        address tokenAddress = isErc20Token ? address(erc20) : address(0);

        vm.prank(admin);
        mintsManager.createToken(tokenId, TokenConfig({price: pricePerToken, tokenAddress: tokenAddress, redeemHandler: address(0)}), true);

        uint256 quantityToMint = 7;

        // mint some tokens to a recipient
        if (isErc20Token) {
            vm.startPrank(minter);
            erc20.mint(quantityToMint * pricePerToken + 100);
            erc20.approve(address(mintsManager), quantityToMint * pricePerToken + 100);
            mintsManager.mintWithERC20(tokenAddress, quantityToMint, mintRecipient);
            vm.stopPrank();
        } else {
            vm.deal(minter, quantityToMint * pricePerToken);
            vm.prank(minter);
            mintsManager.mintWithEth{value: quantityToMint * pricePerToken}(quantityToMint, mintRecipient);
        }

        uint256 quantityToRedeem = 4;
        // redeem some tokens to a redeem recipient
        vm.prank(mintRecipient);
        uint256 valueRedeemed = mints.redeem(tokenId, quantityToRedeem, redeemRecipient).valueRedeemed;

        assertEq(valueRedeemed, quantityToRedeem * pricePerToken);

        if (isErc20Token) {
            assertEq(erc20.balanceOf(redeemRecipient), quantityToRedeem * pricePerToken);
            assertEq(erc20.balanceOf(minter), 100);
        } else {
            // balance of contract should be reduced by the value of the tokens
            assertEq(payable(address(mints)).balance, (quantityToMint - quantityToRedeem) * pricePerToken);
            // balance of redeem recipient should be increased by the value of the tokens
            assertEq(redeemRecipient.balance, quantityToRedeem * pricePerToken);
        }

        // balance of tokens should be reduced
        assertEq(mints.balanceOf(mintRecipient, tokenId), quantityToMint - quantityToRedeem);
    }

    function test_redeem_revertsWhen_insufficientBalance() external {
        // create a token
        uint256 tokenId = 5;
        uint256 pricePerToken = 0.52 ether;

        createEthToken(tokenId, uint96(pricePerToken), true);

        uint256 quantityToMint = 7;

        // mint some tokens to a recipient
        vm.deal(minter, quantityToMint * pricePerToken);
        vm.prank(minter);
        mintsManager.mintWithEth{value: quantityToMint * pricePerToken}(quantityToMint, mintRecipient);

        uint256 quantityToRedeem = quantityToMint + 1;

        // redeem in excess of balance
        vm.prank(mintRecipient);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, mintRecipient, quantityToMint, quantityToRedeem, tokenId));
        mints.redeem(tokenId, quantityToRedeem, redeemRecipient);

        // redeem from account that doesnt have tokens
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, minter, 0, quantityToMint, tokenId));
        mints.redeem(tokenId, quantityToMint, redeemRecipient);

        // redeem full balance, then redeem again, it should revert
        vm.prank(mintRecipient);
        mints.redeem(tokenId, quantityToMint, redeemRecipient);

        vm.prank(mintRecipient);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, mintRecipient, 0, 1, tokenId));
        mints.redeem(tokenId, 1, redeemRecipient);
    }

    function test_redeem_revertsWhen_addressZero() external {
        uint256 pricePerToken = mintsManager.getEthPrice();
        uint256 quantityToMint = 7;

        // mint some tokens to a recipient
        vm.deal(minter, quantityToMint * pricePerToken);
        vm.prank(minter);
        uint256 tokenId = mintsManager.mintWithEth{value: quantityToMint * pricePerToken}(quantityToMint, minter);

        uint256 quantityToRedeem = 4;

        // redeem some tokens to a redeem recipient
        vm.prank(minter);
        vm.expectRevert(IZoraMints1155Errors.InvalidRecipient.selector);
        mints.redeem(tokenId, quantityToRedeem, address(0));
    }

    function test_redeem_failsWhen_cannotSendValueToRecipient() external {
        // create a token
        uint256 tokenId = 5;
        uint256 pricePerToken = 0.52 ether;

        createEthToken(tokenId, uint96(pricePerToken), true);

        uint256 quantityToMint = 7;

        // mint some tokens to a recipient
        vm.deal(minter, quantityToMint * pricePerToken);
        vm.prank(minter);
        mintsManager.mintWithEth{value: quantityToMint * pricePerToken}(quantityToMint, mintRecipient);

        uint256 quantityToRedeem = 4;

        address transferRejector = address(new ReceiveRejector());

        // redeem some tokens to a redeem recipient
        vm.startPrank(mintRecipient);
        vm.expectRevert(IZoraMints1155Errors.ETHTransferFailed.selector);
        mints.redeem(tokenId, quantityToRedeem, transferRejector);
    }

    function testFuzz_redeeemWithdrawsCorrectAmount(
        uint8 firstTokenQuantityToMint,
        uint8 firstTokenQuantityToRedeem,
        uint8 secondTokenQuantityToMint,
        uint8 secondTokenQuantityToRedeem
    ) external {
        vm.assume(firstTokenQuantityToMint < 50);
        vm.assume(secondTokenQuantityToMint < 50);
        // done prevent overflows
        // ensure redeeming valid amount
        vm.assume(firstTokenQuantityToRedeem < firstTokenQuantityToMint);
        vm.assume(secondTokenQuantityToRedeem < secondTokenQuantityToMint);
        uint256 firstTokenId = 5;
        uint256 secondTokenId = 10;

        uint256 firstTokenPrice = 1.2 ether;
        uint256 secondTokenPrice = 2.3 ether;

        // create 2 tokens, but second one is not default mintable
        createEthToken(firstTokenId, uint96(firstTokenPrice), true);
        createEthToken(secondTokenId, uint96(secondTokenPrice), false);

        // mint some tokens to a recipient
        if (firstTokenQuantityToMint > 0) {
            vm.deal(minter, firstTokenPrice * firstTokenQuantityToMint);
            vm.prank(minter);
            mintsManager.mintWithEth{value: firstTokenPrice * firstTokenQuantityToMint}(firstTokenQuantityToMint, mintRecipient);
        }

        vm.prank(admin);
        setMintableEthToken(secondTokenId);

        if (secondTokenQuantityToMint > 0) {
            vm.deal(minter, secondTokenPrice * secondTokenQuantityToMint);
            vm.prank(minter);
            mintsManager.mintWithEth{value: secondTokenPrice * secondTokenQuantityToMint}(secondTokenQuantityToMint, mintRecipient);
        }

        // check balances
        assertEq(mints.balanceOf(mintRecipient, firstTokenId), firstTokenQuantityToMint);
        assertEq(mints.balanceOf(mintRecipient, secondTokenId), secondTokenQuantityToMint);
        // check eth balance of contract
        uint256 valueDeposited = (firstTokenPrice * firstTokenQuantityToMint) + (secondTokenPrice * secondTokenQuantityToMint);
        assertEq(payable(address(mints)).balance, valueDeposited);

        // now redeem some tokens
        if (firstTokenQuantityToRedeem > 0) {
            vm.prank(mintRecipient);
            mints.redeem(firstTokenId, firstTokenQuantityToRedeem, redeemRecipient);
        }

        if (secondTokenQuantityToRedeem > 0) {
            vm.prank(mintRecipient);
            mints.redeem(secondTokenId, secondTokenQuantityToRedeem, redeemRecipient);
        }

        // check balances
        assertEq(mints.balanceOf(mintRecipient, firstTokenId), firstTokenQuantityToMint - firstTokenQuantityToRedeem);
        assertEq(mints.balanceOf(mintRecipient, secondTokenId), secondTokenQuantityToMint - secondTokenQuantityToRedeem);
        // check eth balances
        uint256 valueRedeemed = (firstTokenPrice * firstTokenQuantityToRedeem) + (secondTokenPrice * secondTokenQuantityToRedeem);
        assertEq(payable(address(mints)).balance, valueDeposited - valueRedeemed);
        assertEq(redeemRecipient.balance, valueRedeemed);
    }

    function mintErc20AndBuyMint(address _minter, MockERC20 erc20, uint256 tokenId, uint256 mintTokenQuantity, address _mintRecipient) internal {
        uint256 quantity = mints.tokenPrice(tokenId) * mintTokenQuantity;
        vm.startPrank(_minter);
        erc20.mint(quantity);
        erc20.approve(address(mintsManager), quantity);
        mintsManager.mintWithERC20(address(erc20), mintTokenQuantity, _mintRecipient);
        vm.stopPrank();
    }

    function testFuzz_redeeemBatch_withdrawsCorrectAmount(
        bool firstTokenIsErc20,
        uint8 firstTokenQuantityToMint,
        uint8 firstTokenQuantityToRedeem,
        bool secondTokenIsErc20,
        uint8 secondTokenQuantityToMint,
        uint8 secondTokenQuantityToRedeem
    ) external {
        vm.assume(firstTokenQuantityToMint < 50);
        vm.assume(secondTokenQuantityToMint < 50);
        // done prevent overflows
        // ensure redeeming valid amount
        vm.assume(firstTokenQuantityToRedeem < firstTokenQuantityToMint);
        vm.assume(secondTokenQuantityToRedeem < secondTokenQuantityToMint);
        uint256 firstTokenId = 5;
        uint256 secondTokenId = 10;

        uint256 firstTokenPrice = firstTokenIsErc20 ? 20_000 : 1.2 ether;
        uint256 secondTokenPrice = secondTokenIsErc20 ? 30_000 : 2.3 ether;

        uint256 expectedEthValueRedeemed;
        uint256 valueDeposited;

        // create 2 tokens, but second one is not default mintable
        if (firstTokenIsErc20) {
            createErc20Token(firstTokenId, address(erc20a), uint96(firstTokenPrice), true);
        } else {
            createEthToken(firstTokenId, uint96(firstTokenPrice), true);
            valueDeposited += firstTokenPrice * firstTokenQuantityToMint;
            expectedEthValueRedeemed += firstTokenPrice * firstTokenQuantityToRedeem;
        }
        if (secondTokenIsErc20) {
            createErc20Token(secondTokenId, address(erc20b), uint96(secondTokenPrice), true);
        } else {
            createEthToken(secondTokenId, uint96(secondTokenPrice), false);
            valueDeposited += secondTokenPrice * secondTokenQuantityToMint;
            expectedEthValueRedeemed += secondTokenPrice * secondTokenQuantityToRedeem;
        }

        // mint some tokens to a recipient
        if (firstTokenQuantityToMint > 0) {
            if (firstTokenIsErc20) {
                mintErc20AndBuyMint(minter, erc20a, firstTokenId, firstTokenQuantityToMint, mintRecipient);
            } else {
                vm.deal(minter, firstTokenPrice * firstTokenQuantityToMint);
                vm.prank(minter);
                mintsManager.mintWithEth{value: firstTokenPrice * firstTokenQuantityToMint}(firstTokenQuantityToMint, mintRecipient);
            }
        }

        vm.prank(admin);
        mintsManager.setDefaultMintable(secondTokenIsErc20 ? address(erc20b) : address(0), secondTokenId);

        if (secondTokenQuantityToMint > 0) {
            if (secondTokenIsErc20) {
                mintErc20AndBuyMint(minter, erc20b, secondTokenId, secondTokenQuantityToMint, mintRecipient);
            } else {
                vm.deal(minter, secondTokenPrice * secondTokenQuantityToMint);
                vm.prank(minter);
                mintsManager.mintWithEth{value: secondTokenPrice * secondTokenQuantityToMint}(secondTokenQuantityToMint, mintRecipient);
            }
        }

        // check eth balance of contract

        assertEq(payable(address(mints)).balance, valueDeposited);

        uint256 valueRedeemed;
        {
            uint256[] memory tokenIds = new uint256[](2);
            tokenIds[0] = firstTokenId;
            tokenIds[1] = secondTokenId;

            uint256[] memory quantities = new uint256[](2);
            quantities[0] = firstTokenQuantityToRedeem;
            quantities[1] = secondTokenQuantityToRedeem;

            vm.prank(mintRecipient);
            Redemption[] memory redemptions = mints.redeemBatch(tokenIds, quantities, redeemRecipient);
            for (uint256 i = 0; i < redemptions.length; i++) {
                if (redemptions[i].tokenAddress == address(0)) {
                    valueRedeemed += redemptions[i].valueRedeemed;
                }
            }
        }

        // check balances
        assertEq(mints.balanceOf(mintRecipient, firstTokenId), firstTokenQuantityToMint - firstTokenQuantityToRedeem, "token 1 change");
        assertEq(mints.balanceOf(mintRecipient, secondTokenId), secondTokenQuantityToMint - secondTokenQuantityToRedeem, "token 2 change");

        assertEq(valueRedeemed, expectedEthValueRedeemed, "value redeemed");
        assertEq(payable(address(mints)).balance, valueDeposited - expectedEthValueRedeemed, "mints balance");
        assertEq(redeemRecipient.balance, expectedEthValueRedeemed, "redeem recipient balance");

        if (firstTokenIsErc20) {
            assertEq(erc20a.balanceOf(redeemRecipient), firstTokenPrice * firstTokenQuantityToRedeem);
        }
        if (secondTokenIsErc20) {
            assertEq(erc20b.balanceOf(redeemRecipient), secondTokenPrice * secondTokenQuantityToRedeem);
        }
    }

    function test_redeemBatch_revertsWhen_cannotSend() external {
        // create a token
        uint256 tokenId = 5;
        uint256 pricePerToken = 0.52 ether;

        createEthToken(tokenId, uint96(pricePerToken), true);

        uint256 quantityToMint = 7;

        // mint some tokens to a recipient
        vm.deal(minter, quantityToMint * pricePerToken);
        vm.prank(minter);
        mintsManager.mintWithEth{value: quantityToMint * pricePerToken}(quantityToMint, mintRecipient);

        uint256 quantityToRedeem = 4;

        address transferRejector = address(new ReceiveRejector());

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        uint256[] memory quantities = new uint256[](1);
        quantities[0] = quantityToRedeem;

        // redeem some tokens to a redeem recipient
        vm.startPrank(mintRecipient);
        vm.expectRevert(IZoraMints1155Errors.ETHTransferFailed.selector);
        mints.redeemBatch(tokenIds, quantities, transferRejector);
    }

    function test_redeemBatch_revertsWhen_recipientAddressZero() external {
        // create a token
        uint256 quantityToMint = 7;
        uint256 pricePerToken = mintsManager.getEthPrice();

        // mint some tokens to a recipient
        vm.deal(minter, quantityToMint * pricePerToken);
        vm.prank(minter);
        uint256 tokenId = mintsManager.mintWithEth{value: quantityToMint * pricePerToken}(quantityToMint, mintRecipient);

        uint256 quantityToRedeem = 4;

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        uint256[] memory quantities = new uint256[](1);
        quantities[0] = quantityToRedeem;

        // redeem some tokens to a redeem recipient
        vm.startPrank(mintRecipient);
        vm.expectRevert(IZoraMints1155Errors.InvalidRecipient.selector);
        mints.redeemBatch(tokenIds, quantities, address(0));
    }
}
