// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BallotContract} from "../src/BallotContract.sol";
import {BallotNFT} from "../src/BallotNFT.sol";

contract BallotContractTest is Test {
    BallotContract public ballotContract;
    BallotNFT public ballotNFT;
    
    address public owner = address(1);
    address public voter1 = address(2);
    address public voter2 = address(3);
    address public voter3 = address(4);
    
    event BallotCreated(BallotContract.Ballot ballot);
    event VoteCast(uint256 ballotId, uint256 tokenId, uint256 choice);
    
    function setUp() public {
        // Deploy BallotNFT first
        ballotNFT = new BallotNFT();
        
        // Deploy BallotContract with BallotNFT address
        ballotContract = new BallotContract(address(ballotNFT));
        
        // Set up users
        vm.deal(owner, 100 ether);
        vm.deal(voter1, 100 ether);
        vm.deal(voter2, 100 ether);
        vm.deal(voter3, 100 ether);
    }
    
    function test_CreateBallot() public {
        string memory title = "Test Ballot";
        string memory description = "This is a test ballot";
        string[] memory choices = new string[](3);
        choices[0] = "Option A";
        choices[1] = "Option B";
        choices[2] = "Option C";
        
        vm.expectEmit(true, true, true, true);
        emit BallotCreated(
            BallotContract.Ballot({
                id: 0,
                owner: address(this),
                title: title,
                description: description,
                choices: choices
            })
        );
        
        ballotContract.create(title, description, choices);
        
        BallotContract.Ballot memory ballot = ballotContract.getBallot(0);
        assertEq(ballot.id, 0);
        assertEq(ballot.title, title);
        assertEq(ballot.description, description);
        assertEq(ballot.choices.length, 3);
        assertEq(ballot.choices[0], "Option A");
        assertEq(ballot.choices[1], "Option B");
        assertEq(ballot.choices[2], "Option C");
        assertEq(ballotContract.ballotCount(), 1);
        assertEq(ballotContract.isClosed(0), false);
    }
    
    function test_CreateMultipleBallots() public {
        string[] memory choices1 = new string[](2);
        choices1[0] = "Yes";
        choices1[1] = "No";
        
        string[] memory choices2 = new string[](3);
        choices2[0] = "Red";
        choices2[1] = "Green";
        choices2[2] = "Blue";
        
        ballotContract.create("Ballot 1", "First ballot", choices1);
        ballotContract.create("Ballot 2", "Second ballot", choices2);
        
        assertEq(ballotContract.ballotCount(), 2);
        
        BallotContract.Ballot[] memory ballots = ballotContract.getBallots();
        assertEq(ballots.length, 2);
        assertEq(ballots[0].id, 0);
        assertEq(ballots[1].id, 1);
    }
    
    function test_MintBallotNFT() public {
        vm.prank(voter1);
        ballotContract.mintBallotNFT();
        
        assertEq(ballotNFT.ownerOf(0), voter1);
        assertEq(ballotNFT.balanceOf(voter1), 1);
    }
    
    function test_CastVote() public {
        // Create ballot
        string[] memory choices = new string[](3);
        choices[0] = "Option A";
        choices[1] = "Option B";
        choices[2] = "Option C";
        ballotContract.create("Test", "Description", choices);
        
        // Mint NFT for voter1
        vm.prank(voter1);
        ballotContract.mintBallotNFT();
        
        uint256 tokenId = 0;
        
        // Cast vote
        vm.prank(voter1);
        vm.expectEmit(true, true, true, true);
        emit VoteCast(0, tokenId, 1);
        
        ballotContract.castBallot(0, tokenId, 1);
        
        // Check results
        uint[] memory results = ballotContract.getResults(0);
        assertEq(results[0], 0);
        assertEq(results[1], 1);
        assertEq(results[2], 0);
        
        // Check that user has voted
        assertTrue(ballotContract.hasVoted(voter1, 0));
        assertTrue(ballotContract.isTokenUsed(tokenId));
    }
    
    function test_MultipleVotes() public {
        // Create ballot
        string[] memory choices = new string[](2);
        choices[0] = "Yes";
        choices[1] = "No";
        ballotContract.create("Vote", "Description", choices);
        
        // Mint NFTs for multiple voters
        vm.prank(voter1);
        ballotContract.mintBallotNFT();
        
        vm.prank(voter2);
        ballotContract.mintBallotNFT();
        
        vm.prank(voter3);
        ballotContract.mintBallotNFT();
        
        // Cast votes
        vm.prank(voter1);
        ballotContract.castBallot(0, 0, 0); // voter1 votes for "Yes"
        
        vm.prank(voter2);
        ballotContract.castBallot(0, 1, 0); // voter2 votes for "Yes"
        
        vm.prank(voter3);
        ballotContract.castBallot(0, 2, 1); // voter3 votes for "No"
        
        // Check results
        uint[] memory results = ballotContract.getResults(0);
        assertEq(results[0], 2); // 2 votes for "Yes"
        assertEq(results[1], 1); // 1 vote for "No"
    }
    
    function test_CannotVoteWithoutNFT() public {
        string[] memory choices = new string[](2);
        choices[0] = "Yes";
        choices[1] = "No";
        ballotContract.create("Test", "Description", choices);
        
        // Try to vote without owning NFT (token doesn't exist)
        vm.prank(voter1);
        vm.expectRevert();
        ballotContract.castBallot(0, 0, 0);
    }
    
    function test_CannotVoteWithUsedToken() public {
        string[] memory choices = new string[](2);
        choices[0] = "Yes";
        choices[1] = "No";
        ballotContract.create("Test", "Description", choices);
        
        // Mint and use token
        vm.prank(voter1);
        ballotContract.mintBallotNFT();
        
        vm.prank(voter1);
        ballotContract.castBallot(0, 0, 0);
        
        // Try to vote again with same token
        vm.prank(voter1);
        vm.expectRevert("Token has already been used");
        ballotContract.castBallot(0, 0, 1);
    }
    
    function test_CannotVoteTwice() public {
        string[] memory choices = new string[](2);
        choices[0] = "Yes";
        choices[1] = "No";
        ballotContract.create("Test", "Description", choices);
        
        // Mint two NFTs for voter1
        vm.prank(voter1);
        ballotContract.mintBallotNFT();
        
        vm.prank(voter1);
        ballotContract.mintBallotNFT();
        
        // Vote with first token
        vm.prank(voter1);
        ballotContract.castBallot(0, 0, 0);
        
        // Try to vote again with second token (should fail)
        vm.prank(voter1);
        vm.expectRevert("User has already voted");
        ballotContract.castBallot(0, 1, 1);
    }
    
    function test_CannotVoteWithInvalidChoice() public {
        string[] memory choices = new string[](2);
        choices[0] = "Yes";
        choices[1] = "No";
        ballotContract.create("Test", "Description", choices);
        
        vm.prank(voter1);
        ballotContract.mintBallotNFT();
        
        // Try to vote with invalid choice index
        vm.prank(voter1);
        vm.expectRevert("Invalid choice");
        ballotContract.castBallot(0, 0, 2); // Only 0 and 1 are valid
    }
    
    function test_GetTokensByOwner() public {
        // Mint NFTs for voter1
        vm.prank(voter1);
        ballotContract.mintBallotNFT();
        
        vm.prank(voter1);
        ballotContract.mintBallotNFT();
        
        // Mint NFT for voter2
        vm.prank(voter2);
        ballotContract.mintBallotNFT();
        
        // Get tokens for voter1
        BallotContract.UserToken[] memory tokens = ballotContract.getTokensByOwner(voter1);
        assertEq(tokens.length, 2);
        assertEq(tokens[0].tokenId, 0);
        assertEq(tokens[1].tokenId, 1);
        assertFalse(tokens[0].isUsed);
        assertFalse(tokens[1].isUsed);
        
        // Get tokens for voter2
        tokens = ballotContract.getTokensByOwner(voter2);
        assertEq(tokens.length, 1);
        assertEq(tokens[0].tokenId, 2);
    }
    
    function test_GetTokensByOwnerAfterVoting() public {
        string[] memory choices = new string[](2);
        choices[0] = "Yes";
        choices[1] = "No";
        ballotContract.create("Test", "Description", choices);
        
        // Mint and vote
        vm.prank(voter1);
        ballotContract.mintBallotNFT();
        
        vm.prank(voter1);
        ballotContract.castBallot(0, 0, 0);
        
        // Check token is marked as used
        BallotContract.UserToken[] memory tokens = ballotContract.getTokensByOwner(voter1);
        assertEq(tokens.length, 1);
        assertEq(tokens[0].tokenId, 0);
        assertTrue(tokens[0].isUsed);
    }
    
    function test_GetResultsForNonExistentBallot() public view {
        // Should return empty array or revert - depends on implementation
        // This test checks current behavior
        uint[] memory results = ballotContract.getResults(999);
        assertEq(results.length, 0);
    }
    
    function test_CannotVoteWithOtherUsersToken() public {
        string[] memory choices = new string[](2);
        choices[0] = "Yes";
        choices[1] = "No";
        ballotContract.create("Test", "Description", choices);
        
        // voter1 mints NFT
        vm.prank(voter1);
        ballotContract.mintBallotNFT();
        
        // voter2 tries to vote with voter1's token
        vm.prank(voter2);
        vm.expectRevert("Caller does not own the token");
        ballotContract.castBallot(0, 0, 0);
    }
    
    function test_GetBallotById() public {
        string[] memory choices = new string[](2);
        choices[0] = "Yes";
        choices[1] = "No";
        
        ballotContract.create("First", "First description", choices);
        ballotContract.create("Second", "Second description", choices);
        
        BallotContract.Ballot memory ballot0 = ballotContract.getBallot(0);
        BallotContract.Ballot memory ballot1 = ballotContract.getBallot(1);
        
        assertEq(ballot0.id, 0);
        assertEq(ballot0.title, "First");
        assertEq(ballot1.id, 1);
        assertEq(ballot1.title, "Second");
    }
    
    function test_ResultsStartAtZero() public {
        string[] memory choices = new string[](3);
        choices[0] = "A";
        choices[1] = "B";
        choices[2] = "C";
        ballotContract.create("Test", "Description", choices);
        
        uint[] memory results = ballotContract.getResults(0);
        assertEq(results.length, 3);
        assertEq(results[0], 0);
        assertEq(results[1], 0);
        assertEq(results[2], 0);
    }
    
    function test_EmptyChoicesArray() public {
        string[] memory choices = new string[](0);
        ballotContract.create("Test", "Description", choices);
        
        BallotContract.Ballot memory ballot = ballotContract.getBallot(0);
        assertEq(ballot.choices.length, 0);
        
        uint[] memory results = ballotContract.getResults(0);
        assertEq(results.length, 0);
    }
    
    function test_MultipleBallotsWithDifferentChoices() public {
        string[] memory choices1 = new string[](2);
        choices1[0] = "Yes";
        choices1[1] = "No";
        
        string[] memory choices2 = new string[](4);
        choices2[0] = "Red";
        choices2[1] = "Blue";
        choices2[2] = "Green";
        choices2[3] = "Yellow";
        
        ballotContract.create("Binary", "Binary choice", choices1);
        ballotContract.create("Colors", "Color choice", choices2);
        
        assertEq(ballotContract.ballotCount(), 2);
        
        uint[] memory results1 = ballotContract.getResults(0);
        uint[] memory results2 = ballotContract.getResults(1);
        
        assertEq(results1.length, 2);
        assertEq(results2.length, 4);
    }
}

