// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {VRFConsumerBaseV2} from "chainlink/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "chainlink/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
// forgefmt: disable-end

interface IConsumer {
  error RequestNotExists(uint256 requestId);
  error RequestNotFulfilled(uint256 requestId);

  event ConsumerSettingsConfigured(address indexed by);
  event RequestSent(uint256 requestId, uint32 numWords);
  event RequestFulfilled(uint256 requestId, uint256[] randomWords);

  struct RequestDetail {
    bool requested;
    bool fulfilled;
    uint256[] randomWords;
  }

  struct ConsumerSettings {
    // -----------SLOT 0-----------
    uint32 numWords;
    uint64 subsId; // subscription id
    address coordinator;
    // -----------SLOT 1-----------
    bytes32 keyHash; // chainlink network keyhash
    // -----------SLOT 2-----------
    uint16 numConfirms;
    uint32 gasLimit; // callback gas limit
  }

  function getRequestStatus(uint256 requestId_) external returns (bool fulfilled, uint256[] memory randomWords);
}

abstract contract Consumer is IConsumer, VRFConsumerBaseV2 {
  uint256 public latestRequestId;
  uint256[] public requestIds;

  ConsumerSettings private $csmSettings;
  mapping(uint256 => RequestDetail) private $detail;

  modifier onlyRequested(uint256 requestId_) {
    if (!_isRequested(requestId_)) {
      revert RequestNotExists(requestId_);
    }
    _;
  }

  modifier onlyFulfilled(uint256 requestId_) {
    if (!_isFulfilled(requestId_)) {
      revert RequestNotFulfilled(requestId_);
    }
    _;
  }

  constructor(ConsumerSettings memory settings_) VRFConsumerBaseV2(settings_.coordinator) {
    _configSettings(settings_);
  }

  function getRequestStatus(uint256 requestId_)
    public
    view
    onlyFulfilled(requestId_)
    returns (bool fulfilled, uint256[] memory randomWords)
  {
    RequestDetail memory req = $detail[requestId_];
    return (req.fulfilled, req.randomWords);
  }

  // override VRFConsumerBaseV2
  function fulfillRandomWords(uint256 requestId_, uint256[] memory randomWords_)
    internal
    override
    onlyRequested(requestId_)
  {
    _additionalHandler(requestId_, randomWords_);
    _fulfillRandomWords(requestId_, randomWords_);
  }

  function _additionalHandler(uint256 requestId_, uint256[] memory randomWords_) internal virtual {}

  function _fulfillRandomWords(uint256 requestId_, uint256[] memory randomWords) internal {
    $detail[requestId_].fulfilled = true;
    $detail[requestId_].randomWords = randomWords_;
    emit RequestFulfilled(requestId_, randomWords_);
  }

  function _configSettings(ConsumerSettings memory settings_) internal {
    $csmSettings = settings_;
    emit ConsumerSettingsConfigured(msg.sender);
  }

  function _requestRandomWords() internal {
    ConsumerSettings storage s = $csmSettings;

    uint256 requestId = VRFCoordinatorV2Interface(s.coordinator).requestRandomWords(
      s.keyHash, s.subsId, s.numConfirms, s.gasLimit, s.numWords
    );

    $detail[requestId] = RequestDetail({requested: true, fulfilled: false, randomWords: new uint256[](0)});

    requestIds.push(requestId);
    latestRequestId = requestId;

    emit RequestSent(requestId, s.numWords);
  }

  function _isFulfilled(uint256 requestId_) internal view returns (bool fulfilled) {
    RequestDetail memory req = $detail[requestId_];
    fulfilled = req.fulfilled;
  }

  function _isRequested(uint256 requestId_) internal view returns (bool requested) {
    RequestDetail memory req = $detail[requestId_];
    requested = req.requested;
  }
}
