// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@api3/rrp/requesters/RrpRequesterV0.sol";

interface IQRNGReceiver {
    error RequestNotExists(bytes32 requestId);
    error RequestNotFulfilled(bytes32 requestId);

    event QRNGSettingsConfigured(address indexed by);
    event RequestedSent(bytes32 indexed requestId);
    event RequestFulfilled(bytes32 indexed requestId, uint256[] response);

    struct RequestDetails {
        bool requested;
        bool fulfilled;
        uint256[] response;
    }

    struct QRNGSettings {
        uint32 size;
        address airnode;
        address sponsorWallet;
        bytes32 endpointIdUint256Array;
    }

    function getRequestStatus(
        bytes32 requestId_
    ) external returns (bool fulfilled, uint256[] memory response);
}

abstract contract QRNGReceiver is IQRNGReceiver, RrpRequesterV0 {
    bytes32 public latestRequestId;
    bytes32[] public requestIds;

    QRNGSettings private $qrngSettings;
    mapping(bytes32 => RequestDetails) private $details;

    modifier onlyRequested(bytes32 requestId_) {
        if (!_isRequested(requestId_)) {
            revert RequestNotExists(requestId_);
        }
        _;
    }

    modifier onlyFulfilled(bytes32 requestId_) {
        if (!_isFulfilled(requestId_)) {
            revert RequestNotFulfilled(requestId_);
        }
        _;
    }

    constructor(
        QRNGSettings memory settings_
    ) RrpRequesterV0(settings_.airnode) {
        _qrngConfigSettings(settings_);
    }

    function getRequestStatus(
        bytes32 requestId_
    )
        public
        view
        onlyFulfilled(requestId_)
        returns (bool fulfilled, uint256[] memory response)
    {
        RequestDetails memory req = $details[requestId_];
        return (req.fulfilled, req.response);
    }

    function fulfillRequest(
        bytes32 requestId_,
        bytes calldata data_
    ) external onlyAirnodeRrp onlyRequested(requestId_) {
        uint256[] memory response = abi.decode(data_, (uint256[]));
        _additionalHandler(requestId_, response);
        _fulfillRandomWords(requestId_, response);
    }

    function _additionalHandler(
        bytes32 requestId_,
        uint256[] memory response_
    ) internal virtual {}

    function _fulfillRandomWords(
        bytes32 requestId_,
        uint256[] memory response_
    ) internal {
        $details[requestId_].fulfilled = true;
        $details[requestId_].response = response_;
        emit RequestFulfilled(requestId_, response_);
    }

    function _qrngConfigSettings(QRNGSettings memory settings_) internal {
        $qrngSettings = settings_;
        emit QRNGSettingsConfigured(msg.sender);
    }

    function _requestRandom() internal {
        QRNGSettings storage s = $qrngSettings;

        bytes32 requestId = airnodeRrp.makeFullRequest(
            s.airnode,
            s.endpointIdUint256Array,
            address(this),
            s.sponsorWallet,
            address(this),
            this.fulfillRequest.selector,
            abi.encode(bytes32("1u"), bytes32("size"), s.size)
        );
        $details[requestId] = RequestDetails({
            requested: true,
            fulfilled: false,
            response: new uint256[](0)
        });

        requestIds.push(requestId);
        latestRequestId = requestId;

        emit RequestedSent(requestId);
    }

    function _isFulfilled(
        bytes32 requestId_
    ) internal view returns (bool fulfilled) {
        RequestDetails memory req = $details[requestId_];
        fulfilled = req.fulfilled;
    }

    function _isRequested(
        bytes32 requestId_
    ) internal view returns (bool requested) {
        RequestDetails memory req = $details[requestId_];
        requested = req.requested;
    }
}
