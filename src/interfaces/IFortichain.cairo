use starknet::ContractAddress;
use crate::base::types::{Escrow, Project};
#[starknet::interface]
pub trait IFortichain<TContractState> {
    fn register_project(
        ref self: TContractState,
        name: felt252,
        description: ByteArray,
        category: ByteArray,
        smart_contract_address: ContractAddress,
        contact: ByteArray,
        supporting_document_url: ByteArray,
        logo_url: ByteArray,
        repository_provider: felt252,
        repository_url: ByteArray,
        signature_request: bool,
    ) -> u256;

    fn edit_project(
        ref self: TContractState,
        id: u256,
        name: felt252,
        description: ByteArray,
        category: ByteArray,
        smart_contract_address: ContractAddress,
        contact: ByteArray,
        supporting_document_url: ByteArray,
        logo_url: ByteArray,
        repository_provider: felt252,
        repository_url: ByteArray,
        signature_request: bool,
        is_active: bool,
        is_completed: bool,
    );

    fn close_project(ref self: TContractState, id: u256, creator_address: ContractAddress) -> bool;

    fn view_project(self: @TContractState, id: u256) -> Project;

    fn view_escrow(self: @TContractState, id: u256) -> Escrow;

    fn total_projects(self: @TContractState) -> u256;

    fn all_completed_projects(self: @TContractState) -> Array<Project>;

    fn all_in_progress_projects(self: @TContractState) -> Array<Project>;

    fn mark_project_completed(ref self: TContractState, id: u256);

    fn mark_project_in_progress(ref self: TContractState, id: u256);

    fn fund_project(
        ref self: TContractState, project_id: u256, amount: u256, lockTime: u64,
    ) -> u256;

    fn pull_escrow_funding(ref self: TContractState, escrow_id: u256) -> bool;

    fn add_escrow_funding(ref self: TContractState, escrow_id: u256, amount: u256) -> bool;

    fn process_payment(
        ref self: TContractState, payer: ContractAddress, amount: u256, recipient: ContractAddress,
    ) -> bool;

    fn get_erc20_address(self: @TContractState) -> ContractAddress;

    fn submit_report(ref self: TContractState, project_id: u256, link_to_work: felt252) -> bool;

    fn approve_a_report(ref self: TContractState, project_id: u256, report_id: u256);

    fn pay_an_approved_report(
        ref self: TContractState, project_id: u256, amount: u256, report_id: u256,
    );
}

