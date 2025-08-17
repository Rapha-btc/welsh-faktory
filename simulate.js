import fs from "node:fs";
import { uintCV, principalCV, ClarityVersion } from "@stacks/transactions";
import { SimulationBuilder } from "stxer";

// Define addresses (using your exact addresses)
const DEPLOYER = "SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM";
const BFAKTORY_PROVIDER = "SP3VES970E3ZGHQEZ69R8PY62VP3R0C8CTQ8DAMQW";
const STX_USER_1 = "SPHNEPXY2N25RTB6BMJGJXAH0XSHV55GZB2FC69D";
const STX_USER_2 = "SP3GS0VZBE15D528128G7FN3HXJQ20BXCG4CNPG64";
const RANDOM_USER = "SP1K1A1PMGW2ZJCNF46NWZWHG8TS1D23EGH1KNK60"; // Someone not in the contract

SimulationBuilder.new()
  .withSender(DEPLOYER)

  // Deploy the STX-bfaktory SSO contract
  .addContractDeploy({
    contract_name: "b-alex-single-faktory",
    source_code: fs.readFileSync(
      "./contracts/b-alex-single-faktory.clar",
      "utf8"
    ),
    clarity_version: ClarityVersion.Clarity3,
  })

  // Initialize the bfaktory pool
  .withSender(BFAKTORY_PROVIDER)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-alex-single-faktory`,
    function_name: "initialize-bfaktory-pool",
    function_args: [uintCV(1000000000000000)], // Your exact amount
  })

  // Check pool info after initialization
  .addEvalCode(`${DEPLOYER}.b-alex-single-faktory`, "(get-pool-info)")

  // STX user 1 deposits for LP (your exact amount)
  .withSender(STX_USER_1)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-alex-single-faktory`,
    function_name: "deposit-stx-for-lp",
    function_args: [uintCV(100000000)], // 100 STX
  })

  // STX user 2 deposits for LP (your exact amount)
  .withSender(STX_USER_2)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-alex-single-faktory`,
    function_name: "deposit-stx-for-lp",
    function_args: [uintCV(200000000)], // 200 STX
  })

  // Check user LP tokens before withdrawal
  .addEvalCode(
    `${DEPLOYER}.b-alex-single-faktory`,
    `(get-user-lp-tokens '${STX_USER_1})`
  )

  .addEvalCode(
    `${DEPLOYER}.b-alex-single-faktory`,
    `(get-user-lp-tokens '${STX_USER_2})`
  )

  // TEST BUG 1: Random user tries to withdraw (should fail with ERR_NO_DEPOSIT)
  .withSender(RANDOM_USER)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-alex-single-faktory`,
    function_name: "withdraw-lp-tokens",
    function_args: [],
  })

  // TEST BUG 2: User 1 withdraws (this will show the 100% withdrawal bug)
  .withSender(STX_USER_1)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-alex-single-faktory`,
    function_name: "withdraw-lp-tokens",
    function_args: [],
  })

  // Check user LP tokens after User 1 withdrawal
  .addEvalCode(
    `${DEPLOYER}.b-alex-single-faktory`,
    `(get-user-lp-tokens '${STX_USER_1})`
  )

  .addEvalCode(
    `${DEPLOYER}.b-alex-single-faktory`,
    `(get-user-lp-tokens '${STX_USER_2})`
  )

  // Check pool info after User 1 withdrawal
  .addEvalCode(`${DEPLOYER}.b-alex-single-faktory`, "(get-pool-info)")

  // TEST BUG 2 CONTINUED: User 2 tries to withdraw (should fail because User 1 already withdrew everything)
  .withSender(STX_USER_2)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-alex-single-faktory`,
    function_name: "withdraw-lp-tokens",
    function_args: [],
  })

  // Random user tries to withdraw remaining bfaktory (should fail - not authorized)
  .withSender(RANDOM_USER)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-alex-single-faktory`,
    function_name: "withdraw-remaining-bfaktory",
    function_args: [],
  })

  // Bfaktory provider withdraws remaining bfaktory tokens (should work)
  .withSender(BFAKTORY_PROVIDER)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-alex-single-faktory`,
    function_name: "withdraw-remaining-bfaktory",
    function_args: [],
  })

  // Test error cases that should still fail:

  // Try bfaktory provider depositing STX (should fail - unauthorized)
  .withSender(BFAKTORY_PROVIDER)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-alex-single-faktory`,
    function_name: "deposit-stx-for-lp",
    function_args: [uintCV(25000000)], // Should fail with ERR_UNAUTHORIZED
  })

  // Try double initialization (should fail)
  .withSender(BFAKTORY_PROVIDER)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-alex-single-faktory`,
    function_name: "initialize-bfaktory-pool",
    function_args: [uintCV(500000000000000)], // Should fail with ERR_ALREADY_INITIALIZED
  })

  // Check final pool info
  .addEvalCode(`${DEPLOYER}.b-alex-single-faktory`, "(get-pool-info)")

  .run()
  .catch(console.error);
// runs https://stxer.xyz/simulations/mainnet/56ba58e3a14b7fe0d56537da8dc6a406
// all green https://stxer.xyz/simulations/mainnet/ead26f39cfbb884b817155f44b343cd2
// https://stxer.xyz/simulations/mainnet/4c6ef8802df5d885633ea9078213b41a
