// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {ProtocolRewards} from "@zoralabs/protocol-rewards/src/ProtocolRewards.sol";
import {ZoraCreator1155Impl} from "../../../src/nft/ZoraCreator1155Impl.sol";
import {Zora1155} from "../../../src/proxies/Zora1155.sol";
import {IZoraCreator1155Errors} from "../../../src/interfaces/IZoraCreator1155Errors.sol";
import {IMinter1155} from "../../../src/interfaces/IMinter1155.sol";
import {ICreatorRoyaltiesControl} from "../../../src/interfaces/ICreatorRoyaltiesControl.sol";
import {IZoraCreator1155Factory} from "../../../src/interfaces/IZoraCreator1155Factory.sol";
import {ILimitedMintPerAddressErrors} from "../../../src/interfaces/ILimitedMintPerAddress.sol";
import {ZoraCreatorFixedPriceSaleStrategy} from "../../../src/minters/fixed-price/ZoraCreatorFixedPriceSaleStrategy.sol";
import {ZoraMintsFixtures} from "../../fixtures/ZoraMintsFixtures.sol";
import {IZoraMintsManager} from "@zoralabs/mints-contracts/src/interfaces/IZoraMintsManager.sol";
import {TokenConfig} from "@zoralabs/mints-contracts/src/ZoraMintsTypes.sol";

contract ZoraCreatorFixedPriceSaleStrategyTest is Test {
    ZoraCreator1155Impl internal target;
    ZoraCreatorFixedPriceSaleStrategy internal fixedPrice;
    IZoraMintsManager internal mints;
    address payable internal admin = payable(address(0x999));
    address internal zora;
    address internal tokenRecipient;
    address internal fundsRecipient;
    uint256 initialTokenId = 777;
    uint256 initialTokenPrice = 0.000777 ether;
    uint256 defaultMintFee = 0.000777 ether;

    event SaleSet(address indexed mediaContract, uint256 indexed tokenId, ZoraCreatorFixedPriceSaleStrategy.SalesConfig salesConfig);
    event MintComment(address indexed sender, address indexed tokenContract, uint256 indexed tokenId, uint256 quantity, string comment);

    function setUp() external {
        zora = makeAddr("zora");
        tokenRecipient = makeAddr("tokenRecipient");
        fundsRecipient = makeAddr("fundsRecipient");

        bytes[] memory emptyData = new bytes[](0);
        ProtocolRewards protocolRewards = new ProtocolRewards();
        mints = ZoraMintsFixtures.createMockMints(initialTokenId, initialTokenPrice);
        ZoraCreator1155Impl targetImpl = new ZoraCreator1155Impl(zora, address(0), address(protocolRewards), address(mints));
        Zora1155 proxy = new Zora1155(address(targetImpl));
        target = ZoraCreator1155Impl(payable(address(proxy)));
        target.initialize("test", "test", ICreatorRoyaltiesControl.RoyaltyConfiguration(0, 0, address(0)), admin, emptyData);
        fixedPrice = new ZoraCreatorFixedPriceSaleStrategy();
    }

    function createEthToken(uint256 tokenId, uint256 pricePerToken, bool defaultMintable) internal {
        mints.createToken(tokenId, TokenConfig({price: pricePerToken, tokenAddress: address(0), redeemHandler: address(0)}), defaultMintable);
    }

    function test_ContractName() external {
        assertEq(fixedPrice.contractName(), "Fixed Price Sale Strategy");
    }

    function test_Version() external {
        assertEq(fixedPrice.contractVersion(), "1.1.0");
    }

    function test_MintFlow() external {
        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        vm.expectEmit(true, true, true, true);
        emit SaleSet(
            address(target),
            newTokenId,
            ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                pricePerToken: 1 ether,
                saleStart: 0,
                saleEnd: type(uint64).max,
                maxTokensPerAddress: 0,
                fundsRecipient: address(0)
            })
        );
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(0)
                })
            )
        );
        vm.stopPrank();

        uint256 numTokens = 10;
        uint256 totalReward = target.computeTotalReward(defaultMintFee, numTokens);
        uint256 totalValue = (1 ether * numTokens) + totalReward;

        vm.deal(tokenRecipient, totalValue);

        vm.startPrank(tokenRecipient);
        target.mintWithRewards{value: totalValue}(fixedPrice, newTokenId, 10, abi.encode(tokenRecipient, ""), address(0));

        assertEq(target.balanceOf(tokenRecipient, newTokenId), 10);
        assertEq(address(target).balance, 10 ether);

        vm.stopPrank();
    }

    function test_MintWithCommentBackwardsCompatible() external {
        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        vm.expectEmit(true, true, true, true);
        emit SaleSet(
            address(target),
            newTokenId,
            ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                pricePerToken: 1 ether,
                saleStart: 0,
                saleEnd: type(uint64).max,
                maxTokensPerAddress: 0,
                fundsRecipient: address(0)
            })
        );
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(0)
                })
            )
        );
        vm.stopPrank();

        uint256 numTokens = 10;
        uint256 totalReward = target.computeTotalReward(defaultMintFee, numTokens);
        uint256 totalValue = (1 ether * numTokens) + totalReward;

        vm.deal(tokenRecipient, totalValue);

        vm.startPrank(tokenRecipient);
        target.mintWithRewards{value: totalValue}(fixedPrice, newTokenId, 10, abi.encode(tokenRecipient), address(0));

        assertEq(target.balanceOf(tokenRecipient, newTokenId), 10);
        assertEq(address(target).balance, 10 ether);

        vm.stopPrank();
    }

    function test_MintWithComment() external {
        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        vm.expectEmit(true, true, true, true);
        emit SaleSet(
            address(target),
            newTokenId,
            ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                pricePerToken: 1 ether,
                saleStart: 0,
                saleEnd: type(uint64).max,
                maxTokensPerAddress: 0,
                fundsRecipient: address(0)
            })
        );
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(0)
                })
            )
        );
        vm.stopPrank();

        uint256 numTokens = 10;
        uint256 totalReward = target.computeTotalReward(defaultMintFee, numTokens);
        uint256 totalValue = (1 ether * numTokens) + totalReward;

        vm.deal(tokenRecipient, totalValue);

        vm.startPrank(tokenRecipient);
        vm.expectEmit(true, true, true, true);
        emit MintComment(tokenRecipient, address(target), newTokenId, 10, "test comment");
        target.mintWithRewards{value: totalValue}(fixedPrice, newTokenId, 10, abi.encode(tokenRecipient, "test comment"), address(0));

        assertEq(target.balanceOf(tokenRecipient, newTokenId), 10);
        assertEq(address(target).balance, 10 ether);

        vm.stopPrank();
    }

    function test_SaleStart() external {
        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: uint64(block.timestamp + 1 days),
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 10,
                    fundsRecipient: address(0)
                })
            )
        );
        vm.stopPrank();

        vm.deal(tokenRecipient, 20 ether);

        createEthToken(newTokenId, uint96(defaultMintFee), true);

        uint256 totalReward = target.computeTotalReward(defaultMintFee, 10);

        vm.expectRevert(abi.encodeWithSignature("SaleHasNotStarted()"));

        vm.prank(tokenRecipient);
        target.mintWithRewards{value: 10 ether + totalReward}(fixedPrice, newTokenId, 10, abi.encode(tokenRecipient, ""), address(0));
    }

    function test_SaleEnd() external {
        vm.warp(2 days);

        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: uint64(1 days),
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(0)
                })
            )
        );
        vm.stopPrank();

        vm.deal(tokenRecipient, 20 ether);

        createEthToken(newTokenId, uint96(defaultMintFee), true);

        uint256 totalReward = target.computeTotalReward(defaultMintFee, 10);

        vm.expectRevert(abi.encodeWithSignature("SaleEnded()"));
        vm.prank(tokenRecipient);
        target.mintWithRewards{value: 10 ether + totalReward}(fixedPrice, newTokenId, 10, abi.encode(tokenRecipient, ""), address(0));
    }

    function test_MaxTokensPerAddress() external {
        vm.warp(2 days);

        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 5,
                    fundsRecipient: address(0)
                })
            )
        );
        vm.stopPrank();

        uint256 numTokens = 6;
        uint256 totalReward = target.computeTotalReward(defaultMintFee, numTokens);
        uint256 totalValue = (1 ether * numTokens) + totalReward;

        vm.deal(tokenRecipient, totalValue);

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(ILimitedMintPerAddressErrors.UserExceedsMintLimit.selector, tokenRecipient, 5, 6));
        target.mintWithRewards{value: totalValue}(fixedPrice, newTokenId, numTokens, abi.encode(tokenRecipient, ""), address(0));
    }

    function testFail_setupMint() external {
        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 9,
                    fundsRecipient: address(0)
                })
            )
        );
        vm.stopPrank();

        vm.deal(tokenRecipient, 20 ether);

        vm.startPrank(tokenRecipient);
        target.mintWithRewards{value: 10 ether}(fixedPrice, newTokenId, 10, abi.encode(tokenRecipient), address(0));

        assertEq(target.balanceOf(tokenRecipient, newTokenId), 10);
        assertEq(address(target).balance, 10 ether);

        vm.stopPrank();
    }

    function test_PricePerToken() external {
        vm.warp(2 days);

        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(0)
                })
            )
        );
        vm.stopPrank();

        uint256 totalReward = target.computeTotalReward(mints.getEthPrice(), 1);

        vm.deal(tokenRecipient, 1 ether * mints.getEthPrice());

        vm.startPrank(tokenRecipient);

        target.mintWithRewards{value: 1 ether + totalReward}(fixedPrice, newTokenId, 1, abi.encode(tokenRecipient, ""), address(0));

        vm.stopPrank();
    }

    function test_FundsRecipient() external {
        uint96 pricePerToken = 1 ether;
        uint256 numTokens = 10;

        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: pricePerToken,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 0,
                    fundsRecipient: fundsRecipient
                })
            )
        );
        vm.stopPrank();

        uint256 totalReward = target.computeTotalReward(defaultMintFee, numTokens);
        uint256 totalValue = (pricePerToken * numTokens) + totalReward;

        vm.deal(tokenRecipient, totalValue);

        vm.prank(tokenRecipient);
        target.mintWithRewards{value: totalValue}(fixedPrice, newTokenId, numTokens, abi.encode(tokenRecipient, ""), address(0));

        assertEq(fundsRecipient.balance, 10 ether);
    }

    function test_MintedPerRecipientGetter() external {
        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 0 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 20,
                    fundsRecipient: address(0)
                })
            )
        );
        vm.stopPrank();

        uint256 numTokens = 10;
        uint256 totalReward = target.computeTotalReward(defaultMintFee, numTokens);

        vm.deal(tokenRecipient, totalReward);

        vm.prank(tokenRecipient);
        target.mintWithRewards{value: totalReward}(fixedPrice, newTokenId, 10, abi.encode(tokenRecipient, ""), address(0));

        assertEq(fixedPrice.getMintedPerWallet(address(target), newTokenId, tokenRecipient), 10);
    }

    function test_ResetSale() external {
        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        vm.expectEmit(false, false, false, false);
        emit SaleSet(
            address(target),
            newTokenId,
            ZoraCreatorFixedPriceSaleStrategy.SalesConfig({pricePerToken: 0, saleStart: 0, saleEnd: 0, maxTokensPerAddress: 0, fundsRecipient: address(0)})
        );
        target.callSale(newTokenId, fixedPrice, abi.encodeWithSelector(ZoraCreatorFixedPriceSaleStrategy.resetSale.selector, newTokenId));
        vm.stopPrank();

        ZoraCreatorFixedPriceSaleStrategy.SalesConfig memory sale = fixedPrice.sale(address(target), newTokenId);
        assertEq(sale.pricePerToken, 0);
        assertEq(sale.saleStart, 0);
        assertEq(sale.saleEnd, 0);
        assertEq(sale.maxTokensPerAddress, 0);
        assertEq(sale.fundsRecipient, address(0));
    }

    function test_fixedPriceSaleSupportsInterface() public {
        assertTrue(fixedPrice.supportsInterface(0x6890e5b3));
        assertTrue(fixedPrice.supportsInterface(0x01ffc9a7));
        assertFalse(fixedPrice.supportsInterface(0x0));
    }

    function testRevert_CannotSetSaleOfDifferentTokenId() public {
        vm.startPrank(admin);
        uint256 tokenId1 = target.setupNewToken("https://zora.co/testing/token.json", 10);
        uint256 tokenId2 = target.setupNewToken("https://zora.co/testing/token.json", 5);

        target.addPermission(tokenId1, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.addPermission(tokenId2, address(fixedPrice), target.PERMISSION_BIT_MINTER());

        vm.expectRevert(abi.encodeWithSignature("Call_TokenIdMismatch()"));
        target.callSale(
            tokenId1,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                tokenId2,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(0)
                })
            )
        );
        vm.stopPrank();
    }

    function testRevert_CannotResetSaleOfDifferentTokenId() public {
        vm.startPrank(admin);
        uint256 tokenId1 = target.setupNewToken("https://zora.co/testing/token.json", 10);
        uint256 tokenId2 = target.setupNewToken("https://zora.co/testing/token.json", 5);

        target.addPermission(tokenId1, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.addPermission(tokenId2, address(fixedPrice), target.PERMISSION_BIT_MINTER());

        vm.expectRevert(abi.encodeWithSignature("Call_TokenIdMismatch()"));
        target.callSale(tokenId1, fixedPrice, abi.encodeWithSelector(ZoraCreatorFixedPriceSaleStrategy.resetSale.selector, tokenId2));
        vm.stopPrank();
    }
}
