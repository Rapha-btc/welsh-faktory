import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const bfaktoryProvider = accounts.get("wallet_1")!;
const stxUser1 = accounts.get("wallet_2")!;
const stxUser2 = accounts.get("wallet_3")!;

describe("STX-bfaktory Single-Sided Opportunity Contract", () => {
  it("should deploy successfully", () => {
    const deployResult = simnet.deployContract(
      "stx-bfaktory-sso",
      Deno.readTextFileSync("./contracts/stx-bfaktory-sso.clar"),
      null,
      deployer
    );
    expect(deployResult.result).toBeOk();
  });

  it("should initialize bfaktory pool correctly", () => {
    // Deploy contract first
    simnet.deployContract(
      "stx-bfaktory-sso",
      Deno.readTextFileSync("./contracts/stx-bfaktory-sso.clar"),
      null,
      deployer
    );

    // Initialize pool
    const initResult = simnet.callPublicFn(
      "stx-bfaktory-sso",
      "initialize-bfaktory-pool",
      [Cl.uint(1000000)],
      bfaktoryProvider
    );

    expect(initResult.result).toBeOk();
    expect(initResult.result).toBe(Cl.bool(true));
  });

  it("should track pool info after initialization", () => {
    // Deploy and initialize
    simnet.deployContract(
      "stx-bfaktory-sso",
      Deno.readTextFileSync("./contracts/stx-bfaktory-sso.clar"),
      null,
      deployer
    );

    simnet.callPublicFn(
      "stx-bfaktory-sso",
      "initialize-bfaktory-pool",
      [Cl.uint(1000000)],
      bfaktoryProvider
    );

    // Check pool info
    const poolInfo = simnet.callReadOnlyFn(
      "stx-bfaktory-sso",
      "get-pool-info",
      [],
      deployer
    );

    expect(poolInfo.result).toBeOk();
    const poolData = poolInfo.result.expectOk().expectTuple();
    expect(poolData["initial-bfaktory"]).toBe(Cl.uint(1000000));
    expect(poolData["bfaktory-depositor"]).toBe(
      Cl.some(Cl.principal(bfaktoryProvider))
    );
  });

  it("should prevent double initialization", () => {
    // Deploy and initialize once
    simnet.deployContract(
      "stx-bfaktory-sso",
      Deno.readTextFileSync("./contracts/stx-bfaktory-sso.clar"),
      null,
      deployer
    );

    simnet.callPublicFn(
      "stx-bfaktory-sso",
      "initialize-bfaktory-pool",
      [Cl.uint(1000000)],
      bfaktoryProvider
    );

    // Try to initialize again - should fail
    const doubleInitResult = simnet.callPublicFn(
      "stx-bfaktory-sso",
      "initialize-bfaktory-pool",
      [Cl.uint(500000)],
      bfaktoryProvider
    );

    expect(doubleInitResult.result).toBeErr();
    expect(doubleInitResult.result).toBe(Cl.error(Cl.uint(405))); // ERR_ALREADY_INITIALIZED
  });

  it("should allow STX deposits for LP", () => {
    // Deploy and initialize
    simnet.deployContract(
      "stx-bfaktory-sso",
      Deno.readTextFileSync("./contracts/stx-bfaktory-sso.clar"),
      null,
      deployer
    );

    simnet.callPublicFn(
      "stx-bfaktory-sso",
      "initialize-bfaktory-pool",
      [Cl.uint(1000000)],
      bfaktoryProvider
    );

    // STX user deposits
    const depositResult = simnet.callPublicFn(
      "stx-bfaktory-sso",
      "deposit-stx-for-lp",
      [Cl.uint(500000)], // 0.5 STX
      stxUser1
    );

    expect(depositResult.result).toBeOk();

    // Check user LP tokens
    const userLPTokens = simnet.callReadOnlyFn(
      "stx-bfaktory-sso",
      "get-user-lp-tokens",
      [Cl.principal(stxUser1)],
      deployer
    );

    expect(userLPTokens.result).toBeOk();
    expect(Number(userLPTokens.result.expectOk().expectUint())).toBeGreaterThan(
      0
    );
  });

  it("should prevent bfaktory provider from depositing STX", () => {
    // Deploy and initialize
    simnet.deployContract(
      "stx-bfaktory-sso",
      Deno.readTextFileSync("./contracts/stx-bfaktory-sso.clar"),
      null,
      deployer
    );

    simnet.callPublicFn(
      "stx-bfaktory-sso",
      "initialize-bfaktory-pool",
      [Cl.uint(1000000)],
      bfaktoryProvider
    );

    // Bfaktory provider tries to deposit STX - should fail
    const depositResult = simnet.callPublicFn(
      "stx-bfaktory-sso",
      "deposit-stx-for-lp",
      [Cl.uint(250000)],
      bfaktoryProvider
    );

    expect(depositResult.result).toBeErr();
    expect(depositResult.result).toBe(Cl.error(Cl.uint(403))); // ERR_UNAUTHORIZED
  });

  it("should prevent deposits before initialization", () => {
    // Deploy contract but don't initialize
    simnet.deployContract(
      "stx-bfaktory-sso",
      Deno.readTextFileSync("./contracts/stx-bfaktory-sso.clar"),
      null,
      deployer
    );

    // Try to deposit without initialization - should fail
    const depositResult = simnet.callPublicFn(
      "stx-bfaktory-sso",
      "deposit-stx-for-lp",
      [Cl.uint(500000)],
      stxUser1
    );

    expect(depositResult.result).toBeErr();
    expect(depositResult.result).toBe(Cl.error(Cl.uint(404))); // ERR_NOT_INITIALIZED
  });
});
