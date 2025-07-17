use starknet::ContractAddress;
use crate::base::types::{Escrow, Project, Report, Validator};

#[starknet::interface]
pub trait IFortichain<TContractState> {
    // --- Project Management ---
    fn create_project(
        ref self: TContractState,
        project_info: ByteArray,
        smart_contract_address: ContractAddress,
        signature_request: bool,
        deadline: u64,
    ) -> u256;
    fn edit_project(ref self: TContractState, project_id: u256, deadline: u64);

    fn close_project(ref self: TContractState, project_id: u256) -> bool;

    fn view_project(self: @TContractState, project_id: u256) -> Project;
    fn total_projects(self: @TContractState) -> u256;
    fn all_completed_projects(self: @TContractState) -> Array<Project>;
    fn all_in_progress_projects(self: @TContractState) -> Array<Project>;
    fn project_is_completed(ref self: TContractState, project_id: u256) -> bool;

    // --- Escrow & Funding ---
    fn view_escrow(self: @TContractState, escrow_id: u256) -> Escrow;
    fn fund_project(ref self: TContractState, project_id: u256, amount: u256) -> u256;
    // fn pull_escrow_funding(ref self: TContractState, escrow_id: u256) -> bool;
    fn add_escrow_funding(ref self: TContractState, escrow_id: u256, amount: u256) -> bool;

    // --- Payments ---
    fn pay_validator(ref self: TContractState, project_id: u256);
    fn process_payment(
        ref self: TContractState, payer: ContractAddress, amount: u256, recipient: ContractAddress,
    ) -> bool;

    fn get_erc20_address(self: @TContractState) -> ContractAddress;

    // --- Reports & Contributions ---
    fn submit_report(ref self: TContractState, project_id: u256, report_uri: ByteArray) -> u256;
    fn review_report(
        ref self: TContractState, project_id: u256, submit_address: ContractAddress, accept: bool,
    );
    fn pay_approved_researchers_reports(ref self: TContractState, project_id: u256);

    fn get_contributor_report(
        ref self: TContractState, project_id: u256, submitter_address: ContractAddress,
    ) -> (Report, bool);

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
    fn get_report(self: @TContractState, report_id: u256) -> Report;
    fn update_report(
        ref self: TContractState, report_id: u256, project_id: u256, report_uri: ByteArray,
    ) -> bool;

    fn register_validator_profile(
        ref self: TContractState, validator_data_uri: ByteArray, validator_address: ContractAddress,
    );
    fn approve_validator_profile(ref self: TContractState, validator_address: ContractAddress);
    fn reject_validator_profile(ref self: TContractState, validator_address: ContractAddress);

    fn assign_validator(
        ref self: TContractState, project_id: u256, validator_address: ContractAddress,
    );

    fn get_assigned_project_validator(self: @TContractState, project_id: u256) -> Validator;

    fn get_total_validators(self: @TContractState) -> u256;
    fn get_validator(
        self: @TContractState, validator_address: ContractAddress,
    ) -> (u256, Validator);
}
