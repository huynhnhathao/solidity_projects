# E-commerce recipient
This project implements a contract that acts as a recipient who receives order's payment from customers and verifies the order's payments. The mechanism is simple:

1. A random e-commerce company decided to accept cryptocurrencies payment for their products, and want to make a promise to their customer that: you can get a refund if you don't satisfy with the delivered products. This promise is strong and the customers's doubt is understandable. Then, the company can use hardcoded-promise in smart contract to make the promises unbreakable.
2. When a user go to the checkout page, we ask them to lock their tokens to the contract (an amount of tokens equal to the one in the bill, convert to multiple different tokens that are accepted by the company)
4. An order will be created on-chain with the amount of tokens that need to be paid. The user will need to pay for his order(Identified by the order's ID).
5. The merchant send the products to the users after they confirmed the payment of user on-chain (the information involving address, products, times, ... is off-chain. Only the ID of the order and the amount need to be paid will be on-chain)
6. The user received the package, he/she can do two things: request a refund or release the fund to the merchant. 
- If the user want a refund, he/she can request for a refund by send it back to the merchant, then the merchant verify that they received the product, then the merchant accept the refund on-chain, then the user can withdraw their tokens.
- If the user satisfies with the product, he/she will hit the release button on-chain and the fund is released to the merchant

What if the users received the products and decided not to release the fund or they've just forgotten to do that? To solve this issue, every order on-chain has a deadline for users to request a refund or release it. If users don't do anything and the deadline is reached, the fund is automatically released to the merchant.

As alluded above, the users can only get the refund if the merchant accept the refund. What if the merchant received the returned package from the users, but they don't accept the refund? Or what if the users didn't send back the package but lied about it and request a refund? we will need a third-party here to assess the situation and find out who is the lier. So the owners of the contract will have the right to release the fund to user if they find out the merchant is lying.