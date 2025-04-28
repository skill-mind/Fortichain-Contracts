use starknet::ContractAddress;

#[derive(Drop, Serde, PartialEq, starknet::Store)]
pub struct Project {
    pub id: u256,
    pub creator_address: ContractAddress,
    pub name: felt252,
    pub description: ByteArray,
    pub category: ByteArray,
    pub smart_contract_address: ContractAddress,
    pub contact: ByteArray,
    pub supporting_document_url: ByteArray,
    pub logo_url: ByteArray,
    pub repository_provider: felt252,
    pub repository_url: ByteArray,
    pub signature_request: bool,
    pub is_active: bool,
    pub is_completed: bool,
    pub created_at: u64,
    pub updated_at: u64,
}
#[derive(Drop, Copy, Serde, PartialEq, starknet::Store)]
pub struct Escrow {
    pub id: u256,
    pub project_name: felt252,
    pub projectOwner: ContractAddress,
    pub amount: u256,
    pub isLocked: bool,
    pub lockTime: u64,
    pub is_active: bool,
    pub created_at: u64,
    pub updated_at: u64,
}

