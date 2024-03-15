// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./Migrate.s.sol";
import {SicBo} from "src/SicBo.sol";

contract SicboDeployer is BaseMigrate {
  function run() public {
    deploySicbo();
    // deployContract("SicBo.sol:SicBo", abi.encode());

    // SicBo(0xB0596333421960e09E60bB23Cf06Cad4B98Ad3A6).configQRNGSettings(IQRNGReceiver.QRNGSettings({
    //   size: 3,
    //   airnode: 0x6238772544f029ecaBfDED4300f13A3c4FE84E1D,
    //   airnodeRrp: 0x7f5AF7a37a33898544717AAa6c35c111dCe95b28,
    //   sponsorWallet: 0x41C94D66Eb7758Cc50BA2007B009d4b847D42dfc,
    //   endpointIdUint256Array: 0x9877ec98695c139310480b4323b9d474d48ec4595560348a2341218670f7fbc2
    // }));
  }

  function deploySicbo() public broadcast {
    address sibo = 0x2F08eC295cF70fD1D4985cEC1cDf756d8495a1de;
    address sicbo = deployContract(
      "Sicbo.sol:Sicbo",
      abi.encode(
        sibo,
        0x5498BB86BC934c8D34FDA08E81D444153d0D06aD,
        300,
        1_000_000_000_000_000_000,
        60,
        60
      )
    );
  }
}
