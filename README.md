# TruthPost

TruthPost is a decentralized social media platform built on Clarity smart contracts where content authenticity is verified on-chain and creators earn tokens based on engagement and accuracy ratings.

## Overview

This smart contract enables a social media platform with the following features:

- **Content Posting**: Users can post content with cryptographic hashing for integrity
- **On-chain Verification**: Community members verify content authenticity
- **Engagement Tracking**: System tracks likes, shares, and comments
- **Accuracy Ratings**: Users rate content accuracy on a scale of 1-5
- **Token Rewards**: Content creators earn tokens based on engagement and accuracy
- **Reputation System**: Users build reputation through positive contributions

## Contract Functions

### User Management
- `register-user`: Register as a new user with a username
- `update-username`: Update your username
- `get-user-info`: Get information about a user

### Content Management
- `create-post`: Create a new post with content and content hash
- `get-post`: Get information about a post
- `get-total-posts`: Get the total number of posts on the platform

### Verification System
- `verify-post`: Verify the authenticity of a post
- `get-post-verification`: Check if a user has verified a post

### Engagement System
- `engage-with-post`: Engage with a post (like, share, comment)
- `get-post-engagement`: Check a user's engagement with a post

### Rating System
- `rate-post-accuracy`: Rate the accuracy of a post (1-5)
- `get-post-rating`: Get a user's rating for a post

## Reward Mechanisms

The contract includes several token reward mechanisms:

1. **Verification Rewards**:
   - Users who verify content receive 5 tokens and 1 reputation point
   - Content creators receive 50 tokens and 10 reputation points when their post is verified by 3+ users

2. **Engagement Rewards**:
   - Content creators receive 10 tokens for each engagement (like, share, comment)

3. **Accuracy Rewards**:
   - Users who rate content receive 2 tokens and 1 reputation point
   - Content creators receive 20 tokens and 5 reputation points for highly rated content (4-5 stars)

## Development

This contract is designed to be deployed on the Stacks blockchain and can be tested using Clarinet.