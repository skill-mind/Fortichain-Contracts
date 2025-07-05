use starknet::ContractAddress;

#[derive(Drop, Serde, PartialEq, starknet::Store)]
pub struct Project {
    pub id: u256,
    pub info_uri: ByteArray,
    pub creator_address: ContractAddress,
    pub smart_contract_address: ContractAddress,
    pub contact: ByteArray,
    pub signature_request: bool,
    pub is_active: bool,
    pub is_completed: bool,
    pub created_at: u64,
    pub updated_at: u64,
}
#[derive(Drop, Copy, Serde, PartialEq, starknet::Store)]
pub struct Escrow {
    pub id: u256,
    pub project_id: u256,
    pub projectOwner: ContractAddress,
    pub amount: u256,
    pub isLocked: bool,
    pub lockTime: u64,
    pub is_active: bool,
    pub created_at: u64,
    pub updated_at: u64,
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
