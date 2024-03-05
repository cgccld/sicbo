// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ConfirmedOwner} from
  "chainlink/src/v0.8/shared/access/ConfirmedOwner.sol";
import {VRFCoordinatorV2Interface} from
  "chainlink/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "chainlink/src/v0.8/vrf/VRFConsumerBaseV2.sol";

abstract contract ChainlinkConsumer is VRFConsumerBaseV2, ConfirmedOwner {
  event RequestSent(uint256 requestId, uint32 numWords);
  event RequestFulfilled(uint256 requestId, uint256[] randomWords);

  struct RequestStatus {
    bool exists; // whether a requestId exists
    bool fulfilled; // whether the request has been successfully fulfilled
    uint256[] randomWords;
  }

  mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */
  VRFCoordinatorV2Interface COORDINATOR;

  uint16 requestComfirmations;
  uint32 numWords;
  uint32 callbackGasLimit;
  uint64 s_subscriptionId;
  bytes32 keyHash;
  // past requests Id.
  uint256 public lastRequestId;
  uint256[] public requestIds;

  constructor(uint64 subscriptionId_, address owner_, address consumer_)
    ConfirmedOwner(owner_)
    VRFConsumerBaseV2(consumer_)
  {
    COORDINATOR = VRFCoordinatorV2Interface(consumer_);
    s_subscriptionId = subscriptionId_;
  }

  function _requestRandomWords() internal {
    uint256 requestId = COORDINATOR.requestRandomWords(
      keyHash,
      s_subscriptionId,
      requestComfirmations,
      callbackGasLimit,
      numWords
    );
    s_requests[requestId] = RequestStatus({
      randomWords: new uint256[](0),
      exists: true,
      fulfilled: false
    });
    requestIds.push(requestId);
    lastRequestId = requestId;
    emit RequestSent(requestId, numWords);
  }

  function fulfillRandomWords(uint256 requestId_, uint256[] memory randomWords_)
    internal
    override
  {
    require(s_requests[requestId_].exists, "RNF");
    s_requests[requestId_].fulfilled = true;
    s_requests[requestId_].randomWords = randomWords_;
    emit RequestFulfilled(requestId_, randomWords_);
  }

  function getRequestStatus(uint256 requestId_)
    public
    view
    returns (bool fulfilled, uint256[] memory randomWords)
  {
    require(s_requests[requestId_].exists, "RNF");
    RequestStatus memory req = s_requests[requestId_];
    return (req.fulfilled, req.randomWords);
  }
}
