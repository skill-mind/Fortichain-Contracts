use starknet::ContractAddress;
use crate::base::types::{Escrow, Project, Report};

#[starknet::interface]
pub trait IFortichain<TContractState> {
    // --- Project Management ---
    fn register_project(
        ref self: TContractState,
        project_info: ByteArray,
        smart_contract_address: ContractAddress,
        contact: ByteArray,
        signature_request: bool,
    ) -> u256;

    fn edit_project(
        ref self: TContractState,
        id: u256,
        info_uri: ByteArray,
        smart_contract_address: ContractAddress,
        contact: ByteArray,
        signature_request: bool,
        is_active: bool,
        is_completed: bool,
    );

    fn close_project(ref self: TContractState, id: u256, creator_address: ContractAddress) -> bool;

    fn view_project(self: @TContractState, id: u256) -> Project;
    fn total_projects(self: @TContractState) -> u256;
    fn all_completed_projects(self: @TContractState) -> Array<Project>;
    fn all_in_progress_projects(self: @TContractState) -> Array<Project>;

    fn mark_project_completed(ref self: TContractState, id: u256);
    fn mark_project_in_progress(ref self: TContractState, id: u256);

    // --- Escrow & Funding ---
    fn view_escrow(self: @TContractState, id: u256) -> Escrow;
    fn fund_project(
        ref self: TContractState, project_id: u256, amount: u256, lockTime: u64,
    ) -> u256;
    fn pull_escrow_funding(ref self: TContractState, escrow_id: u256) -> bool;
    fn add_escrow_funding(ref self: TContractState, escrow_id: u256, amount: u256) -> bool;

    // --- Payments ---
    fn process_payment(
        ref self: TContractState, payer: ContractAddress, amount: u256, recipient: ContractAddress,
    ) -> bool;

    fn get_erc20_address(self: @TContractState) -> ContractAddress;

    // --- Reports & Contributions ---
    fn submit_report(ref self: TContractState, project_id: u256, link_to_work: felt252) -> bool;
    fn approve_a_report(
        ref self: TContractState, project_id: u256, submit_address: ContractAddress,
    );
    fn pay_an_approved_report(
        ref self: TContractState,
        project_id: u256,
        amount: u256,
        submitter_Address: ContractAddress,
    );

    fn get_contributor_report(
        ref self: TContractState, project_id: u256, submitter_address: ContractAddress,
    ) -> (felt252, bool);

    fn get_list_of_approved_contributors(
        ref self: TContractState, project_id: u256,
    ) -> Array<ContractAddress>;

    fn get_contributor_paid_status(
        ref self: TContractState, project_id: u256, submitter_address: ContractAddress,
    ) -> bool;

    // --- Role Management & Validators ---
    fn set_role(
        ref self: TContractState, recipient: ContractAddress, role: felt252, is_enable: bool,
    );

    fn is_validator(self: @TContractState, role: felt252, address: ContractAddress) -> bool;
    fn new_report(ref self: TContractState, project_id: u256, link_to_work: ByteArray) -> u256;
    fn get_report(self: @TContractState, report_id: u256) -> Report;
    fn delete_report(ref self: TContractState, report_id: u256, project_id: u256) -> bool;
    fn update_report(
        ref self: TContractState, report_id: u256, project_id: u256, link_to_work: ByteArray,
    ) -> bool;
    fn withdraw_bounty(
        ref self: TContractState, amount: u256, recipient: ContractAddress,
    ) -> (bool, u256);
    fn add_user_bounty_balance(ref self: TContractState, user: ContractAddress, amount: u256);
}
