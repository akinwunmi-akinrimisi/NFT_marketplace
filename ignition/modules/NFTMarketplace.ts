const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("NFTMarketplaceModule", (m) => {
  const nFTMarketplace = m.contract(
    "NFTMarketplace",
    ["0x9e83cA6Dbc6d9e0DAE3EA83b0762BEf6dE20708d"],
    {}
  );

  return { nFTMarketplace };
});

// deploye address: 0xAFd4c57e6a4531088a0217e3366De483515FeAE1
