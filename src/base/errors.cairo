pub mod Errors {
    pub const PROJECT_NOT_FOUND: felt252 = 'Project not found';
    pub const ONLY_OWNER_CAN_CLOSE: felt252 = 'Only owner can close project';
    pub const ONLY_OWNER_CAN_EDIT: felt252 = 'Only owner can edit project';
    pub const CAN_ONLY_CLOSE_AFTER_DEADLINE: felt252 = 'Can only close after deadline';
    pub const ONLY_VALIDATOR: felt252 = 'Caller non validator';
    pub const NOT_AUTHORIZED: felt252 = 'Not authorized';
    pub const REQUEST_NOT_FOUND: felt252 = 'Request not found';
    pub const EMPTY_DETAILS_URI: felt252 = 'Details URI is empty';
}
