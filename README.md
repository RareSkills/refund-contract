# Payment and Refund

## Get started

- Clone repo
- Install npm packages `npm i`
- Copy `.example.env` to new file `.env`
- Replace value in .env w/ your own `HTTPS` API string from Alchemy. 

```shell
npx hardhat run scripts/deploy.js
`npx hardhat coverage`
```

Run `npx prettier --write 'contracts/**/*.sol` for auto formatting

## Mutation testing:

Install: `pip3 install --user-vertigo`
Run: `vertigo run --hardhat-parallel 8`

Test output is being saved to `./mutationOutput/<Date with underscores>_<Attempt number>`
