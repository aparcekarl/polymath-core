pragma solidity ^0.4.24;

import "../../TransferManager/ITransferManager.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title This TransferManager is used to validate the transaction where partial balance of an 
 * investor is not allowed to trnasfer beside investor is present in the exemption list
 */
contract RestrictedPartialSaleTM is ITransferManager {

    // permission definition
    bytes32 internal constant OPERATOR = "OPERATOR";

    address[] public exemptAddresses;

    mapping(address => uint256) public exemptIndex;


    // Emit when the token holder is added/removed from the exemption list
    event ChangedExemptWalletList(address indexed _wallet, bool _exempted);

    /**
     * @notice Constructor
     * @param _securityToken Address of the security token
     * @param _polyAddress Address of the polytoken
     */
    constructor (address _securityToken, address _polyAddress)
    public
    Module(_securityToken, _polyAddress)
    {
    }

    /**
    * @notice This function returns the signature of configure function
    */
    function getInitFunction() public pure returns (bytes4) {
        return this.configure.selector;
    }

    /**
     * @notice Used to initialize the variables of the contract
     * @param _treasuryWallet Ethereum address of the treasury wallet
     */
    function configure(address _treasuryWallet) external onlyFactory {
        _changeExemptionWalletList(_treasuryWallet, true);
    }

    /** 
     * @notice Used to verify the transfer transaction and prevent a transfer if it passes the allowed amount of token holders
     * @param _from Address of the sender
     * @param _amount Amount to send
     */
    function verifyTransfer(
        address _from,
        address /* _to */,
        uint256 _amount,
        bytes /* _data */,
        bool /* _isTransfer */
    )
        public
        returns(Result)
    {
        if (!paused && _from != address(0) && exemptIndex[_from] == 0) {
            return (ISecurityToken(securityToken).balanceOf(_from) == _amount ? Result.NA : Result.INVALID);
        }
        return Result.NA;
    }

    /**
     * @notice Add/Remove wallet address from the exempt list
     * @param _wallet Ethereum wallet/contract address that need to be exempted
     * @param _exempted Boolean value used to add (i.e true) or remove (i.e false) from the list
     */
    function changeExemptWalletList(address _wallet, bool _exempted) external withPerm(OPERATOR) {
        _changeExemptionWalletList(_wallet, _exempted);
    }

    /**
     * @notice Add/Remove multiple wallet addresses from the exempt list
     * @param _wallet Ethereum wallet/contract addresses that need to be exempted
     * @param _exempted Boolean value used to add (i.e true) or remove (i.e false) from the list
     */
    function changeExemptWalletListMulti(address[] _wallet, bool[] _exempted) public withPerm(OPERATOR) {
        require(_wallet.length == _exempted.length, "Length mismatch");
        for (uint256 i = 0; i < _wallet.length; i++) {
            _changeExemptionWalletList(_wallet[i], _exempted[i]);
        }
    }

    function _changeExemptionWalletList(address _wallet, bool _exempted) internal {
        require(_wallet != address(0), "Invalid address");
        uint256 exemptIndexWallet = exemptIndex[_wallet];
        require((exemptIndexWallet == 0) == _exempted, "Exemption state doesn't change");
        if (_exempted) {
            exemptAddresses.push(_wallet);
            exemptIndex[_wallet] = exemptAddresses.length;
        } else {
            exemptAddresses[exemptIndexWallet - 1] = exemptAddresses[exemptAddresses.length - 1];
            exemptIndex[exemptAddresses[exemptIndexWallet - 1]] = exemptIndexWallet;
            delete exemptIndex[_wallet];
            exemptAddresses.length --;
        }
        emit ChangedExemptWalletList(_wallet, _exempted);
    }

    /**
     * @notice return the exempted addresses list
     */
    function getExemptAddresses() external view returns(address[]) {
        return exemptAddresses;
    }

    /**
     * @notice Return the permissions flag that are associated with Restricted partial trnasfer manager
     * @return bytes32 array
     */
    function getPermissions() public view returns(bytes32[] memory) {
        bytes32[] memory allPermissions = new bytes32[](1);
        allPermissions[0] = OPERATOR;
        return allPermissions;
    }
}