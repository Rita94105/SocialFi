# [HiSocialFi](https://hisocialfi-on5j14e.gamma.site/)

HiSocialFi is breaking through the challenges of Web3, leading users into a world filled with promise and potential. It seamlessly integrates web2 and web3, enhancing convenience, and unlocking innovative economic models.

## Problems

- real application in web3 and web2

  Although Friend.tech connect Twitter's Accounts, providing only private chatting service.

- user group

  It's difficult to attract new users to use.

- sustainable development

  Like Friend.tech, people think it's a Ponzi scheme, and only can sell and buy shares.

## Solutions

- create Campaign

  Every user can launch campaigns to set assigned tasks for others to achieve in web2 and web3, in order to get the chance of airdrops.

- get profit

  1. People can get airdrops from attending free campaigns, and project parties also can advertise their activities through these platfroms.

  2. People can buy Shares which are combined with Defi-swap pool, getting share profits from the income of transaction fees.

- Easy access to Web3

  Users can easily engage in transactions such as issuing NFTs, managing portfolios, airdrops, coin exchanges, profit-sharing, and more.Users can easily engage in transactions such as issuing NFTs, managing portfolios, airdrops, coin exchanges, profit-sharing, and more.

## Implementation

1. Shares

- Adapted based on [FriendtechSharesV1](https://basescan.org/address/0xcf205808ed36593aa40a44f10c7f7c2f67d4a4d4#code) into NFT format allows for trading on third-party markets, enhancing liquidity.

- Publishers can independently configure curve-based parameters, adjusting the pricing curve according to project-specific requirements.

- Users are limited to minting one NFT at a time, and there is no upper limit on the total issuance.

- Each Shares contract incorporates Uniswap trading pair coin exchange functionality.

- During each quarterly snapshot, 60% of the airdrop profit-sharing fees go to the holders, 20% to the NFT issuers, and the remaining 20% is converted into QQ Tokens and burned.

2. Campaigns

- Everyone can launch a campaign which should set tasks for users to challenge like following twitter accounts, and use defi-pool to swap, and people will get the chance of airdrop.

3. QQToken

- A platform token designed to reward both event organizers and participants.

- The platform will periodically distribute platform tokens as incentives for user engagement. In future plans, creations of Campaigns and Shares NFTs will be required to use QQToken for payment, and additional platform applications will be developed progressively.

4. Airdrop

- Campaigns and Shares contracts both inherit from the Airdrop contract.

- Providing two withdrawal methods: a list-based approach with specified amounts and addresses, or users can independently claim their rewards.

## WorkFlow

![SocialFi workFLow](/pic/WorkFlow.png)
