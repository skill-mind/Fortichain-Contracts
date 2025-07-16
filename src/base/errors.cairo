pub mod Errors {
    pub const PROJECT_NOT_FOUND: felt252 = 'Project not found';
    pub const ONLY_OWNER_CAN_CLOSE: felt252 = 'Only owner can close project';
    pub const ONLY_OWNER_CAN_EDIT: felt252 = 'Only owner can edit project';
    pub const CAN_ONLY_CLOSE_AFTER_DEADLINE: felt252 = 'Can only close after deadline';
}
