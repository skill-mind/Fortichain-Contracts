use starknet::ContractAddress;

#[derive(Drop, Clone, Serde, PartialEq, starknet::Store)]
pub struct Project {
    pub id: u256,
    pub info_uri: ByteArray,
    pub project_owner: ContractAddress,
    pub smart_contract_address: ContractAddress,
    pub signature_request: bool,
    pub is_active: bool,
    pub is_completed: bool,
    pub created_at: u64,
    pub updated_at: u64,
    pub deadline: u64,
    pub validator_paid: bool,
    pub researchers_paid: bool,
}

#[derive(Drop, Copy, Serde, PartialEq, starknet::Store)]
pub struct Escrow {
    pub id: u256,
    pub project_id: u256,
    pub projectOwner: ContractAddress,
    pub initial_deposit: u256,
    pub current_amount: u256,
    pub is_active: bool,
    pub created_at: u64,
    pub updated_at: u64,
    pub validator_paid: bool,
    pub researchers_paid: bool,
}


#[derive(Drop, Clone, Serde, PartialEq, starknet::Store)]
pub struct Report {
    pub id: u256,
    pub contributor_address: ContractAddress,
    pub project_id: u256,
    pub report_data: ByteArray,
    pub created_at: u64,
    pub updated_at: u64,
}


#[derive(Drop, Clone, Serde, PartialEq, starknet::Store)]
pub struct Validator {
    pub id: u256,
    pub validator_data_uri: ByteArray,
    pub validator_address: ContractAddress,
    pub created_at: u64,
    pub updated_at: u64,
    pub status: felt252,
}
