import { createConfig, http } from "wagmi";
import { lineaSepolia, hardhat } from "wagmi/chains";
import { mock } from "wagmi/connectors";

export const config = createConfig({
  multiInjectedProviderDiscovery: false,
  chains: [hardhat, lineaSepolia],
  connectors: [
    mock({
      accounts: [
        '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
        '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
        '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
      ],
    }),
  ],
  syncConnectedChain: true,
  transports: {
    [hardhat.id]: http("http://127.0.0.1:8545/"),
    [lineaSepolia.id]: http(
      `https://linea-sepolia.infura.io/v3/${import.meta.env.VITE_INFURA_PROJECT_ID}`
    ),
  },
});

declare module "wagmi" {
  interface Register {
    config: typeof config;
  }
}