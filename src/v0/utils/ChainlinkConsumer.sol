// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ConfirmedOwner} from
  "chainlink/src/v0.8/shared/access/ConfirmedOwner.sol";
import {VRFCoordinatorV2Interface} from
  "chainlink/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "chainlink/src/v0.8/vrf/VRFConsumerBaseV2.sol";

abstract contract ChainlinkConsumer is VRFConsumerBaseV2, ConfirmedOwner {
  event ConsumerConfigured();
  event RequestSent(uint256 requestId, uint32 numWords);
  event RequestFulfilled(uint256 requestId, uint256[] randomWords);

  struct RequestStatus {
    bool exists; 
    bool fulfilled; 
    uint256[] randomWords;
  }

  struct Config {
    uint16 confirmations;
    uint32 numWords;
    uint32 callbackGasLimit;
    uint64 subscriptionId;
    bytes32 keyHash;
  }

  Config $config;
  uint256 public latestRequestId;
  VRFCoordinatorV2Interface COORDINATOR;

  uint256[] public requestIds;
  mapping(uint256 => RequestStatus) internal _s_requests; /* requestId --> requestStatus */

  constructor(uint64 subscriptionId_, address owner_, address coordinator_)
    ConfirmedOwner(owner_)
    VRFConsumerBaseV2(coordinator_)
  {
    COORDINATOR = VRFCoordinatorV2Interface(coordinator_);
    $config = Config({
      confirmations: 3,
      numWords: 1,
      callbackGasLimit: 100_000,
      subscriptionId: subscriptionId_,
      keyHash: 0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61 
    });
  }
  
  function config(Config calldata config_) external onlyOwner {
    $config = config_;
    emit ConsumerConfigured();
  }

  function _requestRandomWords() internal {
    Config storage c = $config;
    uint256 requestId = COORDINATOR.requestRandomWords(
      c.keyHash,
      c.subscriptionId,
      c.confirmations,
      c.callbackGasLimit,
      c.numWords
    );
    _s_requests[requestId] = RequestStatus({
      randomWords: new uint256[](0),
      exists: true,
      fulfilled: false
    });
    requestIds.push(requestId);
    latestRequestId = requestId;

    emit RequestSent(requestId, c.numWords);
  }

  function fulfillRandomWords(uint256 requestId_, uint256[] memory randomWords_)
    internal
    override
  {
    require(_s_requests[requestId_].exists, "RNF");
    _s_requests[requestId_].fulfilled = true;
    _s_requests[requestId_].randomWords = randomWords_;
    emit RequestFulfilled(requestId_, randomWords_);
  }

  function getRequestStatus(uint256 requestId_)
    public
    view
    returns (bool fulfilled, uint256[] memory randomWords)
  {
    require(_s_requests[requestId_].exists, "RNF");
    RequestStatus memory req = _s_requests[requestId_];
    return (req.fulfilled, req.randomWords);
  }
}
