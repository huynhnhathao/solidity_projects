// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "../src/Seller.sol";
import "../src/Token.sol";

// This contract act as an EOA customer
contract Customer {
    Seller seller;

    receive() external payable {}

    function callBuyUsingToken(
        address _seller,
        address _token,
        bytes32 _macHash
    ) public {
        seller = Seller(payable(_seller));
        seller.buy(_token, _macHash);
    }

    function callBuyUsingEther(
        address _seller,
        uint256 _amount,
        bytes32 _macHash
    ) public {
        seller = Seller(payable(_seller));
        seller.buy{value: _amount}(address(0), _macHash);
    }

    function callWithdrawToken(
        address _seller,
        address _token,
        uint256 _amount
    ) public {
        seller = Seller(payable(_seller));
        seller.withdrawToken(_token, _amount);
    }

    function callWithdrawNative(address _seller, uint256 _amount) public {
        seller = Seller(payable(_seller));
        seller.withdrawNative(_amount);
    }

    function callChangeAmount(
        address _seller,
        address _token,
        uint256 _amount
    ) public {}

    function callAddPaymentMethod(
        address _seller,
        address _token,
        uint256 _amount
    ) public {}

    function callGetFreeLicense(address _seller, bytes32 _macHash) public {
        seller = Seller(payable(_seller));
        seller.getFreeLicense(_macHash);
    }

    function callApprove(
        address _token,
        address _spender,
        uint256 _amount
    ) public {
        IERC20(_token).approve(_spender, _amount);
    }
}

contract SellerTest is Test {
    Seller seller;
    Token token1;
    Token token2;
    Customer cus1;
    Customer cus2;

    receive() external payable {}

    function setUp() public {
        token1 = new Token("Token1", "TK1");
        token2 = new Token("Token2", "TK2");

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1 ether;
        amounts[1] = 10 ether;
        amounts[2] = 5 ether;

        address[] memory tokens = new address[](3);
        tokens[0] = address(0);
        tokens[1] = address(token1);
        tokens[2] = address(token2);

        seller = new Seller(tokens, amounts);

        cus1 = new Customer();
        cus2 = new Customer();

        // mint some tokens for cus1 and cus2

        token1.mintTo(address(cus1), 100 ether);
        token2.mintTo(address(cus2), 100 ether);

        // give cus1 and cus2 some ethers

        payable(address(cus1)).transfer(10 ether);
        payable(address(cus2)).transfer(10 ether);

        assertEq(token1.balanceOf(address(cus1)), 100 ether);
        assertEq(token1.balanceOf(address(cus2)), 0);

        assertEq(token2.balanceOf(address(cus2)), 100 ether);
        assertEq(token2.balanceOf(address(cus1)), 0);

        assertEq(address(cus1).balance, 10 ether);
        assertEq(address(cus2).balance, 10 ether);
    }

    // test buy successfully using ERC20 token
    function testBuyUsingToken() public {
        // here we hash the string "customer1", but in our application
        // it can be hash of the mac address of the computer

        cus1.callApprove(address(token1), address(seller), 10 ether);
        cus1.callBuyUsingToken(
            address(seller),
            address(token1),
            keccak256("customer1")
        );
        assertTrue(seller.hasLicense(keccak256("customer1")));

        assertEq(token1.balanceOf(address(seller)), 10 ether);
    }

    // test buy successfully using native token
    function testBuyUsingNativeToken() public {
        cus2.callBuyUsingEther(
            address(seller),
            1 ether,
            keccak256("customer2")
        );

        assertTrue(seller.hasLicense(keccak256("customer2")));
        assertEq(address(cus2).balance, 9 ether);
        assertEq(address(seller).balance, 1 ether);
    }

    // test buy fail using native token not enough amount
    function testBuyFailNativeToken() public {
        vm.expectRevert("NOT_ENOUGH_AMOUNT");
        cus2.callBuyUsingEther(
            address(seller),
            1 ether - 1 wei,
            keccak256("customer2")
        );
    }

    // test buy fail using token not enough amount
    function testBuyFailToken() public {
        assertEq(IERC20(token2).balanceOf(address(cus1)), 0);
        cus1.callApprove(address(token2), address(seller), 4 ether);

        vm.expectRevert("ERC20: insufficient allowance");
        cus1.callBuyUsingToken(
            address(seller),
            address(token2),
            keccak256("fail")
        );
    }

    // test buy fail not accepted token
    function testBuyFailToken1() public {
        Token newToken = new Token("NewToken", "NTK");
        vm.expectRevert("TOKEN_NOT_ACCEPTED");
        cus1.callBuyUsingToken(
            address(seller),
            address(newToken),
            keccak256("fail")
        );
    }

    // test withdrawToken
    function testWithdrawToken() public {
        // one user buy
        cus1.callApprove(address(token1), address(seller), 10 ether);
        cus1.callBuyUsingToken(
            address(seller),
            address(token1),
            keccak256("customer1")
        );

        uint256 prebalance = token1.balanceOf(address(this));
        seller.withdrawToken(address(token1), 10 ether);
        uint256 postbalance = token1.balanceOf(address(this));
        assertEq(postbalance - prebalance, 10 ether);
    }

    // test withdrawToken fail not enough amount
    function testWithdrawToken1() public {
        vm.expectRevert("NOT_ENOUGH_TOKENS");
        seller.withdrawToken(address(token1), 10 ether);
    }

    // test withdrawNative
    function testWithdrawNative() public {
        cus2.callBuyUsingEther(
            address(seller),
            1 ether,
            keccak256("customer2")
        );
        uint256 prebalance = address(this).balance;
        seller.withdrawNative(1 ether);
        uint256 postbalance = address(this).balance;
        assertEq(postbalance - prebalance, 1 ether);
    }

    // test withdrawNative failed not enough amount
    function testWithdrawNativeFail() public {
        cus2.callBuyUsingEther(
            address(seller),
            1 ether,
            keccak256("customer2")
        );
        vm.expectRevert("NOT_ENOUGH_ETHER");
        seller.withdrawNative(2 ether);
    }

    // test withdrawNative failed not owner
    function testWithdrawNativeFal2() public {
        vm.expectRevert("Ownable: caller is not the owner");
        cus1.callWithdrawNative(address(seller), 1 ether);
    }

    // test withdraw token failed not owner
    function testWithdrawTokenFail2() public {
        vm.expectRevert("Ownable: caller is not the owner");
        cus1.callWithdrawToken(address(seller), address(token1), 1 ether);
    }

    // test change amount
    function testChangeAmount() public {
        seller.changePaymentAmount(address(token1), 1 ether);
        assertEq(seller.paymentAmounts(address(token1)), 1 ether);
    }

    // test add token payment
    function testAddToken() public {
        Token newToken = new Token("newToken", "NTk");
        seller.addPaymentMethod(address(newToken), 100 ether);

        assertEq(seller.paymentAmounts(address(newToken)), 100 ether);

        bool check;
        uint256 length = seller.numAcceptedTokens();
        for (uint256 i; i < length; i++) {
            if (seller.acceptedTokens(i) == address(newToken)) {
                check = true;
                break;
            }
        }

        assertTrue(check);
    }

    // test remove payment method successfully

    function testRemoveToken() public {
        seller.removePaymentMethod(address(token1));
        assertEq(seller.paymentAmounts(address(token1)), 0);

        bool check;
        uint256 length = seller.numAcceptedTokens();
        for (uint256 i; i < length; i++) {
            if (seller.acceptedTokens(i) == address(token1)) {
                check = true;
                break;
            }
        }
        assertTrue(!check);
    }

    // test remove fail non exist token
    function testRemoveTokenFail(address tokenAddress) public {
        if (
            tokenAddress == address(token1) ||
            tokenAddress == address(token2) ||
            tokenAddress == address(0)
        ) return;
        vm.expectRevert("TOKEN_DOES_NOT_EXIST");
        seller.removePaymentMethod(tokenAddress);
    }

    // test change fail if token does not exist
    function proveChangePaymentAmountFail(uint256 amount) public {
        vm.expectRevert("TOKEN_DOES_NOT_EXIST");
        seller.changePaymentAmount(address(1), amount);
    }

    // test add fail if token already exist
    function testAddTokenFail() public {
        vm.expectRevert("TOKEN_ALREADY_ADDED");
        seller.addPaymentMethod(address(token1), 2 ether);
    }

    // test set free can buy free
    function testSetFree() public {
        seller.setFree();
        assertTrue(seller.free());
    }

    // test get free fail if not set free
    function testGetFreeF() public {
        bytes32 mac = bytes32(keccak256("fail"));
        vm.expectRevert("LICENSE_IS_NOT_FREE");

        cus1.callGetFreeLicense(address(seller), mac);
    }
}
