Feature: Command execution

  Scenario: Command without arguments
    Given I apply the "command.txt" worldlet
    And client 1 connects
    When client 1 sends "try"
    Then client 1 should receive "You tried."
