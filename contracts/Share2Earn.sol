// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IERC20 {
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Share2Earn {
    IERC20 public shrToken; // The ERC20 token used for payments

    struct Link {
        address creator;
        uint256 cpc;
        uint256 balance;
    }

    uint256 public nextLinkId; // Counter for link IDs
    mapping(uint256 => Link) public links;
    mapping(address => uint256) public earnings;
    mapping(uint256 => uint256) public clickCounts; // To keep track of clicks for each link

    event LinkCreated(
        uint256 indexed linkId,
        address indexed creator,
        uint256 cpc,
        uint256 balance
    );
    event ClickRegistered(
        uint256 indexed linkId,
        address indexed sharer,
        uint256 reward
    );
    event EarningsWithdrawn(address indexed sharer, uint256 amount);
    event FundsAdded(
        uint256 indexed linkId,
        address indexed creator,
        uint256 amount
    );

    modifier onlyCreator(uint256 linkId) {
        require(links[linkId].creator == msg.sender, "Not the link creator");
        _;
    }

    constructor(address _shrTokenAddress) {
        shrToken = IERC20(_shrTokenAddress);
    }

    function createLink(uint256 cpc, uint256 initialBalance) public {
        require(initialBalance > 0, "Must deposit funds");

        uint256 linkId = nextLinkId++;
        links[linkId] = Link({
            creator: msg.sender,
            cpc: cpc,
            balance: 0 // Will be updated once tokens are transferred
        });

        _addFunds(linkId, initialBalance);

        emit LinkCreated(linkId, msg.sender, cpc, initialBalance);
    }

    function registerClick(uint256 linkId) public {
        Link storage link = links[linkId];
        require(link.creator != address(0), "Link does not exist");
        require(link.balance >= link.cpc, "Insufficient funds");

        link.balance -= link.cpc;
        earnings[msg.sender] += link.cpc;
        clickCounts[linkId] += 1;

        emit ClickRegistered(linkId, msg.sender, link.cpc);
    }

    function withdrawEarnings() public {
        uint256 amount = earnings[msg.sender];
        require(amount > 0, "No earnings to withdraw");

        earnings[msg.sender] = 0;
        require(shrToken.transfer(msg.sender, amount), "Token transfer failed");

        emit EarningsWithdrawn(msg.sender, amount);
    }

    function addFunds(
        uint256 linkId,
        uint256 amount
    ) public onlyCreator(linkId) {
        require(amount > 0, "Must deposit funds");

        _addFunds(linkId, amount);
    }

    function _addFunds(uint256 linkId, uint256 amount) internal {
        Link storage link = links[linkId];
        require(
            shrToken.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );

        link.balance += amount;

        emit FundsAdded(linkId, msg.sender, amount);
    }

    function getLinkDetails(
        uint256 linkId
    )
        public
        view
        returns (address creator, uint256 cpc, uint256 balance, uint256 clicks)
    {
        Link storage link = links[linkId];
        return (link.creator, link.cpc, link.balance, clickCounts[linkId]);
    }
}
