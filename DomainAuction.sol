// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

// We first import some OpenZeppelin Contracts.
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DomainAuctions is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address payable public contractOwner;

    uint256 auctionDuration;
    uint256 totalAuctions;

    string public tld; // top level domain
    string svgPartOne =
        '<svg xmlns="http://www.w3.org/2000/svg" width="270" height="270" fill="none"><path fill="url(#B)" d="M0 0h270v270H0z"/><defs><filter id="A" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse" height="270" width="270"><feDropShadow dx="0" dy="1" stdDeviation="2" flood-opacity=".225" width="200%" height="200%"/></filter></defs><path d="M72.863 42.949c-.668-.387-1.426-.59-2.197-.59s-1.529.204-2.197.59l-10.081 6.032-6.85 3.934-10.081 6.032c-.668.387-1.426.59-2.197.59s-1.529-.204-2.197-.59l-8.013-4.721a4.52 4.52 0 0 1-1.589-1.616c-.384-.665-.594-1.418-.608-2.187v-9.31c-.013-.775.185-1.538.572-2.208a4.25 4.25 0 0 1 1.625-1.595l7.884-4.59c.668-.387 1.426-.59 2.197-.59s1.529.204 2.197.59l7.884 4.59a4.52 4.52 0 0 1 1.589 1.616c.384.665.594 1.418.608 2.187v6.032l6.85-4.065v-6.032c.013-.775-.185-1.538-.572-2.208a4.25 4.25 0 0 0-1.625-1.595L41.456 24.59c-.668-.387-1.426-.59-2.197-.59s-1.529.204-2.197.59l-14.864 8.655a4.25 4.25 0 0 0-1.625 1.595c-.387.67-.585 1.434-.572 2.208v17.441c-.013.775.185 1.538.572 2.208a4.25 4.25 0 0 0 1.625 1.595l14.864 8.655c.668.387 1.426.59 2.197.59s1.529-.204 2.197-.59l10.081-5.901 6.85-4.065 10.081-5.901c.668-.387 1.426-.59 2.197-.59s1.529.204 2.197.59l7.884 4.59a4.52 4.52 0 0 1 1.589 1.616c.384.665.594 1.418.608 2.187v9.311c.013.775-.185 1.538-.572 2.208a4.25 4.25 0 0 1-1.625 1.595l-7.884 4.721c-.668.387-1.426.59-2.197.59s-1.529-.204-2.197-.59l-7.884-4.59a4.52 4.52 0 0 1-1.589-1.616c-.385-.665-.594-1.418-.608-2.187v-6.032l-6.85 4.065v6.032c-.013.775.185 1.538.572 2.208a4.25 4.25 0 0 0 1.625 1.595l14.864 8.655c.668.387 1.426.59 2.197.59s1.529-.204 2.197-.59l14.864-8.655c.657-.394 1.204-.95 1.589-1.616s.594-1.418.609-2.187V55.538c.013-.775-.185-1.538-.572-2.208a4.25 4.25 0 0 0-1.625-1.595l-14.993-8.786z" fill="#fff"/><defs><linearGradient id="B" x1="0" y1="0" x2="270" y2="270" gradientUnits="userSpaceOnUse"><stop stop-color="#cb5eee"/><stop offset="1" stop-color="#0cd7e4" stop-opacity=".99"/></linearGradient></defs><text x="32.5" y="231" font-size="27" fill="#fff" filter="url(#A)" font-family="Plus Jakarta Sans,DejaVu Sans,Noto Color Emoji,Apple Color Emoji,sans-serif" font-weight="bold">';
    string svgPartTwo = "</text></svg>";

    mapping(string => address) public domains;
    mapping(string => string) public records;

    mapping(uint256 => string) public names;

    error InvalidName(string name);

    event Start(uint256 indexed tokenId, address owner, uint256 startAmount);
    event End(uint256 indexed tokenId, address bidder, uint256 price);
    event Cancel(uint256 indexed tokenId, address owner);
    event Bid(uint256 indexed tokenId, address indexed sender, uint256 amount);
    event Withdraw(
        uint256 indexed tokenId,
        address indexed bidder,
        uint256 amount
    );

    // mapping that keeps track of auction ending time
    mapping(uint256 => uint256) auctionEnd;
    mapping(uint256 => uint256) allAuctions;

    struct DomainAuction {
        address payable owner;
        address bidder;
        uint256 bid;
        uint256 price;
        uint256 sellingPrice;
        bool forSale;
    }

    mapping(uint256 => DomainAuction) auctions;
    mapping(uint256 => mapping(address => uint256)) bids;

    constructor(string memory _tld) payable ERC721("Domain Auctions", "DAT") {
        contractOwner = payable(msg.sender);
        tld = _tld;
        auctionDuration = 3 hours;
        totalAuctions = 0;
    }

     /**
     * @dev Returns the length of a given string
     *
     * @param s The string to measure the length of
     * @return The length of the input string
     */
    function strlen(string memory s) internal pure returns (uint) {
        uint len;
        uint i = 0;
        uint bytelength = bytes(s).length;
        for(len = 0; i < bytelength; len++) {
            bytes1 b = bytes(s)[i];
            if(b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
        return len;
    }

    // This function is to register new nft domain and create auction
    function register(string calldata name, uint256 currentBid) public payable {
        if (!valid(name)) revert InvalidName(name);
        require(domains[name] == address(0));

        uint256 _price = price(name);
        require(msg.value == _price, "Insufficient balance");

        string memory _name = string(abi.encodePacked(name, ".", tld));
        string memory finalSvg = string(
            abi.encodePacked(svgPartOne, _name, svgPartTwo)
        );
        uint256 newRecordId = _tokenIds.current();
        _tokenIds.increment();
        uint256 length = strlen(name); // length of name is returned
        string memory strLen = Strings.toString(length);

        string memory json = Base64.encode(
            abi.encodePacked(
                '{"name": "',
                _name,
                '", "description": "A domain on the Domain Auction", "image": "data:image/svg+xml;base64,',
                Base64.encode(bytes(finalSvg)),
                '","length":"',
                strLen,
                '"}'
            )
        );

        string memory finalTokenUri = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        _safeMint(msg.sender, newRecordId);
        _setTokenURI(newRecordId, finalTokenUri);
        domains[name] = msg.sender;

        names[newRecordId] = name;

        auctions[newRecordId] = DomainAuction(
            payable(msg.sender),
            msg.sender,
            currentBid,
            0,
            0,
            false
        );
    }

    // This function will give us the price of a domain based on length
    function price(string calldata name) public pure returns (uint256) {
        uint256 len = strlen(name);
        require(len > 0, "Empty string");
        if (!valid(name)) revert InvalidName(name);
        if (len == 3) {
            return 5 * 10**17;
        } else if (len == 4) {
            return 3 * 10**17;
        } else {
            return 1 * 10**17;
        }
    }

    // This function is to get address of nft domain
    function getAddress(string calldata name) public view returns (address) {
        // Check that the owner is the transaction sender
        return domains[name];
    }

    // This function is to set record for nft domain
    function setRecord(string calldata name, string calldata record) public {
        require(domains[name] == msg.sender, "only admins of domain can set the record");
        records[name] = record;
    }

    // This function is to get record of nft domain
    function getRecord(string calldata name)
        public
        view
        returns (string memory)
    {
        return records[name];
    }

    // This function is for owner to withdraw
    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Owner failed to withdraw balance");
    }

    // This function is to get all domain name
    function getAllNames() public view returns (string[] memory) {
        string[] memory allNames = new string[](_tokenIds.current());
        for (uint256 i = 0; i < _tokenIds.current(); i++) {
            allNames[i] = names[i];
        }
        return allNames;
    }

    function valid(string calldata name) public pure returns (bool) {
        return strlen(name) >= 3 && strlen(name) <= 10; // compares the length of name to 3 and 10
    }

    function start(
        uint256 tokenId,
        uint256 _price,
        uint256 _sellingPrice
    ) public canAuction(tokenId) {
        require(_price > 0, "Enter a valid price");
        require(_sellingPrice > 0, "Enter a valid selling price");
        DomainAuction storage auction = auctions[tokenId];
        auction.forSale = true;
        auction.price = _price;
        auction.sellingPrice = _sellingPrice;

        auctionEnd[totalAuctions] = block.timestamp + 240;// change back
        allAuctions[totalAuctions] = tokenId;

        totalAuctions++;

        emit Start(tokenId, auction.owner, _price);
    }

    // This function will bid for an aution
    function bid(uint256 tokenId)
        external
        payable
        isExpired(tokenId)
        isNotSeller(tokenId)
    {
        DomainAuction storage auction = auctions[tokenId];

        uint256 bidValue = bids[tokenId][msg.sender] + msg.value;
        require(bidValue > auction.bid, "Bid value is too low!");
        bids[tokenId][auction.bidder] = auction.bid;

        // new bidder is assigned and bids  values are updated
        auction.bidder = msg.sender;
        auction.bid = bidValue;
        bids[tokenId][auction.bidder] = 0;

        emit Bid(tokenId, auction.bidder, bidValue);
    }

    function resetHelper(uint tokenId) internal {
        DomainAuction storage auction = auctions[tokenId];
        auction.bid = 0;
        auction.bidder = msg.sender;
        auction.price = 0;
        auction.sellingPrice = 0;
        auction.forSale = false;
    }

    // ending the auction and tranfering the nft to highest bidder
    function end(uint256 tokenId) external isSeller(tokenId) {
        DomainAuction storage auction = auctions[tokenId];

        if (auction.bidder != address(0)) {
            address winner = auction.bidder;
            resetHelper(tokenId);
            (bool sent, ) = auction.owner.call{value: auction.bid}("");
            require(sent, "Could not pay owner!");
            safeTransferFrom(address(this), winner, tokenId);
            auction.owner = payable(winner);
            emit End(tokenId, auction.bidder, auction.bid);
        } else {
            resetHelper(tokenId);
            safeTransferFrom(address(this), auction.owner, tokenId);
            emit Cancel(tokenId, auction.owner);
        }
    }

    // This function will withdraw a bid from the marketplace
    function withdrawBid(uint256 tokenId)
        external
        payable
        isBidder(tokenId)
        isNotLeader(tokenId)
    {
        uint256 amount = bids[tokenId][msg.sender];
        bids[tokenId][msg.sender] = 0;
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "Could not withdraw");
        emit Withdraw(tokenId, msg.sender, amount);
    }

    // This function will cancel an auction
    function cancel(uint256 tokenId)
        external
        isExpired(tokenId)
        isSeller(tokenId)
    {
        DomainAuction storage auction = auctions[tokenId];
        bids[tokenId][auction.bidder] += auction.bid;
        resetHelper(tokenId);
        safeTransferFrom(address(this), auction.owner, tokenId);
        emit Cancel(tokenId, auction.owner);
    }


    modifier isSeller(uint256 tokenId) {
        require(
            auctions[tokenId].owner == msg.sender,
            "Only owner can perform this action!"
        );
        _;
    }

    modifier canAuction(uint256 tokenId) {
        DomainAuction storage auction = auctions[tokenId];
        require(
            msg.sender == auction.owner && msg.sender == auction.bidder,
            "You are not the owner"
        );
        require(
            auction.forSale == false,
            "This domain is already in an auction"
        );
        require(
            auction.price == 0 && auction.sellingPrice == 0,
            "Domain isn't available"
        );
        _;
    }

    modifier isNotSeller(uint256 tokenId) {
        DomainAuction storage auction = auctions[tokenId];
        require(msg.sender != auction.owner, "You can't bid on your domain");
        require(msg.sender != auction.bidder, "You can't outbid yourself");
        require(
            msg.value > auction.bid && msg.value >= auction.price,
            "You need to bid higher than the current bid"
        );
        _;
    }

    modifier isBidder(uint256 tokenId) {
        require(
            bids[tokenId][msg.sender] > 0,
            "You did not bid in this auction!"
        );
        _;
    }

    modifier isNotLeader(uint256 tokenId) {
        require(
            auctions[tokenId].bidder != msg.sender,
            "You can not withdraw as a current leader!"
        );
        _;
    }

    modifier isExpired(uint256 tokenId) {
        require(block.timestamp <= auctionEnd[tokenId], "The auction is over");
        _;
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}
