pragma solidity >=0.8.2 <0.9.0;

import "hardhat/console.sol";
import "./leader_election.sol";

contract Test {
    using CreateTournament for Tournament;
    using RunTournament for Tournament;
    using RndSubmission for Tournament;

    Tournament public tournament;

    // create tree with n players with equal shares
    function createTournament(uint playerCount) private {
        for (uint i = 1; i <= playerCount; i++) {
            tournament.addPlayer(player(i));
            tournament.addWeight(player(i), 1);
        }
        tournament.setTotalRounds();
        console.log("Running checkWinningProposal");
    }

    function player(uint number) private pure returns(address) {
        return address(uint160(number));
    }

    // Test with 2 players
    function test1() public {
        createTournament(2);
        tournament.compete(player(1), 0);
        tournament.compete(player(2), 0);
        tournament.currentRound++;
        address winner = tournament.getTournamentWinner();
        emit PlayerLog("winner and total weight: ", winner, tournament.weights[winner]);
    }
    
}
