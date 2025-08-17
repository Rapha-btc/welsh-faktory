import fs from "node:fs";
import { uintCV, principalCV, ClarityVersion } from "@stacks/transactions";
import { SimulationBuilder } from "stxer";

// Define addresses
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
    function_args: [uintCV(1000000000000000)], // 10M time 10^8 for micro bfaktory tokens
  })

  // Check pool info after initialization
  .addEvalCode(`${DEPLOYER}.b-alex-single-faktory`, "(get-pool-info)")

  // STX user 1 deposits for LP
  .withSender(STX_USER_1)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-alex-single-faktory`,
    function_name: "deposit-stx-for-lp",
    function_args: [uintCV(100000000)], // 100 STX
  })

  // STX user 2 deposits for LP
  .withSender(STX_USER_2)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-alex-single-faktory`,
    function_name: "deposit-stx-for-lp",
    function_args: [uintCV(200000000)], // 200 STX
  })

  // Check user LP tokens
  .addEvalCode(
    `${DEPLOYER}.b-alex-single-faktory`,
    `(get-user-lp-tokens '${STX_USER_1})`
  )

  .addEvalCode(
    `${DEPLOYER}.b-alex-single-faktory`,
    `(get-user-lp-tokens '${STX_USER_2})`
  )

  // Check final pool info
  .addEvalCode(`${DEPLOYER}.b-alex-single-faktory`, "(get-pool-info)")

  .run()
  .catch(console.error);

// runs https://stxer.xyz/simulations/mainnet/56ba58e3a14b7fe0d56537da8dc6a406
