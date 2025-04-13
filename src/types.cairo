use starknet::ContractAddress;


#[derive(Drop, Serde)]
pub struct RegisterProject {
    pub project_id: u256,
    pub name: felt252,
    pub project_description: felt252,
    pub categories: felt252,
    pub smart_contract_address: ContractAddress,
    pub contact_info: felt252,
    pub supporting_document: Array<MediaMessageResponse>,
    pub repo_name: felt252,
    pub signature_request: bool,
}


#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct MediaMessage {
    pub file_hash: felt252,
    pub file_name: felt252,
    pub file_type: felt252,
    pub file_size: u64,
    pub recipients_count: u32,
    pub upload_date: u64,
}

