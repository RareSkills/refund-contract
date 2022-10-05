# Payment and Refund


```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```

The standard test `npx hardhat test` is now producing an error 'could not determin exicutable to run'. 
Instead run the coverage test command :
`npx hardhat coverage` via solidity-coverage package

Run `npx prettier --write 'contracts/**/*.sol` for auto formatting

## Mutation testing:

Install: `pip3 install --user-vertigo`
Run: `vertigo run --hardhat-parallel 8`

Test output is being saved to `./mutationOutput/<Date with underscores>_<Attempt number>`

Final output:

Mutations:
```
[+] Survivors
Mutation:
    File: /home/mb/Documents/code/refund-contract/contracts/PaymentAndRefund.sol
    Line nr: 129
    Result: Lived
    Original line:
                 if (weeksComplete > scheduleLength) {

    Mutated line:
                 if (weeksComplete >= scheduleLength) {
    
    ACTION TAKEN: None. The business logic of this conditional statment sets a variable to 0. In 
                  circumstance of variable equality, the `multiplier` is set to zero (The 
                  refundSchedule's last index, this is inforced by the refundSchedule setter
                  function's requirments).

Mutation:
    File: /home/mb/Documents/code/refund-contract/contracts/PaymentAndRefund.sol
    Line nr: 152
    Result: Lived
    Original line:
                 if (currentTime < startTime) { 

    Mutated line:
                 if (currentTime <= startTime) { 

    ACTION TAKEN: None. The business logic of this conditional statment sets a variable to 0. In 
                  circumstance of variable equality, it is later set to zero as well (the two values
                  are subtracted. The if statment is to protect against creating a nagitive number).

Mutation:
    File: /home/mb/Documents/code/refund-contract/contracts/PaymentAndRefund.sol
    Line nr: 272
    Result: Lived
    Original line:
                 if (contractBalance > depositedUSDC * USDC_DECIMALS) {

    Mutated line:
                 if (contractBalance >= depositedUSDC * USDC_DECIMALS) {

    ACTION TAKEN: None. This if statement is used to ensure the subtraction that follows does not
                  procude a nagitive value.

Mutation:
    File: /home/mb/Documents/code/refund-contract/contracts/PaymentAndRefund.sol
    Line nr: 272
    Result: Lived
    Original line:
                 if (contractBalance > depositedUSDC * USDC_DECIMALS) {

    Mutated line:
                 if (contractBalance > depositedUSDC / USDC_DECIMALS) {

    ACTION TAKEN: None. This mutation is likely to cause a decimal value and revert.
                  Ex:
                  if (5_000_000_000 > 5_000 / 10 **6) -> 5_000_000_000 / 0.005_000

                  If there were 201 purchasers this would result in a division by 1.005
                  and the GT check would fail. 
[*] Done! 
```
