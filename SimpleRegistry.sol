pragma solidity ^0.8.0;

contract SimpleRegistry {
    struct Name {
        address payable owner;
        uint256 expires;
        uint256 cost;
    }

    uint256 constant public MAX_COMMITMENT_DURATION = 1 days;
    uint256 constant public LOCK_DURATION = 10 days;

    mapping (bytes32 => uint256) private _commitments;
    mapping (uint256 => Name) private _names;
    mapping (address => uint256) private _balances;

    /**
     * @dev The function register commitment as a first part name registration
     * note Unused commitments stores forever
     */
    function commit(bytes32 commitment) external {
        require(_commitments[commitment] + MAX_COMMITMENT_DURATION <= block.timestamp, "Commitment exists");
        _commitments[commitment] = block.timestamp;
    }

    /**
     * @dev The function registers name using commitment's reveal.
     * The function requires strict `value` equals name registration price.
     * note There is no unlock funds when name expired.
     *      It leads to losing funds when new registration happens.
     * note Front-Running attack:
     *      In addition to commit/reveal approach it is possible to use blockNumber check guard.
     *      The guard can prevent execution of the attack in one block before 'register' txn.
     */
    function register(string calldata name, address payable account, bytes32 salt) external payable {
        _reveal(buildCommitment(name, account, salt));

        uint256 nameId = uint256(keccak256(abi.encodePacked(name)));
        require(!_isAvailable(nameId), "Name is not available");

        uint256 price = getPrice(name);
        require(msg.value == price, "Value is wrong");

        // TODO: unlock funds for different account if required
        _names[nameId] = Name(account, block.timestamp + LOCK_DURATION, price);
    }

    /**
     * @dev The function renews name when the name is not yet expired.
     */
    function renew(string calldata name) external payable {
        uint256 nameId = uint256(keccak256(abi.encodePacked(name)));
        require(_isAvailable(nameId), "Name is not registered");

        uint price = getPrice(name);
        require(msg.value == price, "Value is wrong");

        _names[nameId].expires = _names[nameId].expires + LOCK_DURATION;
        _names[nameId].cost = _names[nameId].cost + price;
    }

    /**
     * @dev The function returns an owner of a registered and not expired name.
     */
    function getOwner(string calldata name) external view returns(address) {
        uint256 nameId = uint256(keccak256(abi.encodePacked(name)));
        require(_isAvailable(nameId), "Name does not exists or expired");
        return _names[nameId].owner;
    }

    /**
     * @dev The function unlocks funds from expired name and withdraw it to the owner.
     */
    function unlockAndWithdraw(string calldata name) external {
        uint256 nameId = uint256(keccak256(abi.encodePacked(name)));
        _unlockFunds(nameId);

        address payable owner = _names[nameId].owner;
        owner.transfer(_balances[owner]);
    }

    /**
     * @dev The read function builds commitment based on provided parameters,
     *      including `salt` - random security key.
     */
    function buildCommitment(string memory name, address account, bytes32 salt) public view returns(bytes32) {
        return keccak256(abi.encodePacked(name, account, salt, address(this)));
    }

    /**
     * @dev The function calculates name price based on name length.
     */
    function getPrice(string memory name) public pure returns(uint256) {
        uint256 len = bytes(name).length;
        require(len > 2, "Name length must be greater than 2");
        if(len >= 10)
            return 0.01 ether;
        return (11 - len) * 1e16;
    }

    function _reveal(bytes32 commitment) internal {
        uint256 _commitment = _commitments[commitment];
        require(
            _commitment < block.timestamp && _commitment + MAX_COMMITMENT_DURATION >= block.timestamp,
            "Commitment invalid"
        );
        delete(_commitments[commitment]);
    }

    function _isAvailable(uint256 nameId) internal view returns (bool) {
        return _names[nameId].owner != address(0) && _names[nameId].expires >= block.timestamp;
    }

    function _unlockFunds(uint256 nameId) internal {
        require(_names[nameId].owner != address(0), "Name does not exist");
        require(_names[nameId].expires < block.timestamp, "Name has not expired");

        _balances[_names[nameId].owner] = _balances[_names[nameId].owner] + _names[nameId].cost;
        delete(_names[nameId]);
    }
}
