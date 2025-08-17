import fs from "node:fs";
import { uintCV, principalCV, ClarityVersion } from "@stacks/transactions";
import { SimulationBuilder } from "stxer";

// Define addresses (using your exact addresses)
const DEPLOYER = "SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM";
const BFAKTORY_PROVIDER = "SP3VES970E3ZGHQEZ69R8PY62VP3R0C8CTQ8DAMQW";
const STX_USER_1 = "SPHNEPXY2N25RTB6BMJGJXAH0XSHV55GZB2FC69D";
const STX_USER_2 = "SP3GS0VZBE15D528128G7FN3HXJQ20BXCG4CNPG64";

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

  // NOW TEST WITHDRAWALS (since LOCK_PERIOD = u0)

  // User 1 withdraws LP tokens (should work now)
  .withSender(STX_USER_1)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-alex-single-faktory`,
    function_name: "withdraw-lp-tokens",
    function_args: [],
  })

  // Check user 1 LP tokens after withdrawal (should be 0)
  .addEvalCode(
    `${DEPLOYER}.b-alex-single-faktory`,
    `(get-user-lp-tokens '${STX_USER_1})`
  )

  // User 2 withdraws LP tokens (should work)
  .withSender(STX_USER_2)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-alex-single-faktory`,
    function_name: "withdraw-lp-tokens",
    function_args: [],
  })

  // Check user 2 LP tokens after withdrawal (should be 0)
  .addEvalCode(
    `${DEPLOYER}.b-alex-single-faktory`,
    `(get-user-lp-tokens '${STX_USER_2})`
  )

  // Bfaktory provider withdraws remaining bfaktory tokens
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

  // Try withdrawing when user has no LP tokens (should fail)
  .withSender(STX_USER_1)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-alex-single-faktory`,
    function_name: "withdraw-lp-tokens",
    function_args: [], // Should fail with ERR_NO_DEPOSIT
  })

  // Check final pool info
  .addEvalCode(`${DEPLOYER}.b-alex-single-faktory`, "(get-pool-info)")

  .run()
  .catch(console.error);
// runs https://stxer.xyz/simulations/mainnet/56ba58e3a14b7fe0d56537da8dc6a406
// all green https://stxer.xyz/simulations/mainnet/ead26f39cfbb884b817155f44b343cd2
