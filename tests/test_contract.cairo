use core::felt252;
use core::traits::Into;
use fortichain_contracts::interfaces::IFortichain::{
    IFortichainDispatcher, IFortichainDispatcherTrait,
};
use fortichain_contracts::interfaces::IMockUsdc::{IMockUsdcDispatcher, IMockUsdcDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};

// use starknet::testing::warp;

fn contract() -> IFortichainDispatcher {
    let contract_class = declare("Fortichain").unwrap().contract_class();
    let erc20_contract = deploy_erc20();
    let erc20_address = erc20_contract.contract_address;

    let mut constructor_calldata = array![];
    let erc20_address: ContractAddress = erc20_address.into();
    let owner: ContractAddress = OWNER().try_into().unwrap();
    erc20_address.serialize(ref constructor_calldata);
    owner.serialize(ref constructor_calldata);

    let (contract_address, _) = contract_class.deploy(@constructor_calldata).unwrap();
    (IFortichainDispatcher { contract_address })
}

fn deploy_erc20() -> IMockUsdcDispatcher {
    let owner: ContractAddress = contract_address_const::<'owner'>();

    let contract_class = declare("MockUsdc").unwrap().contract_class();
    let (contract_address, _) = contract_class.deploy(@array![owner.into()]).unwrap();

    IMockUsdcDispatcher { contract_address }
}

fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn VALIDATOR_ADDRESS() -> ContractAddress {
    'VALIDATOR_ADDRESS'.try_into().unwrap()
}
fn REPORT_ADDRESS() -> ContractAddress {
    'REPORT_READER'.try_into().unwrap()
}

const VALIDATOR_ROLE: felt252 = selector!("VALIDATOR_ROLE");
const REPORT_READER: felt252 = selector!("REPORT_READER");
const INVALID_ROLE: felt252 = selector!("INVALID_ROLE");

#[test]
fn test_successful_register_project() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    contract.register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
}

#[test]
fn test_successful_edit_project() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();

    let id: u256 = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    contract.edit_project(id, get_block_timestamp() + 1200);

    let project = contract.view_project(id);
    assert(project.deadline == get_block_timestamp() + 1200, 'deadline not updated');
}

#[test]
#[should_panic]
fn test_failed_edit_project() {
    let contract = contract();
    let id: u256 = 1;
    contract.edit_project(id, get_block_timestamp() + 1200);
}

#[test]
fn test_view_project() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let id: u256 = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    let project = contract.view_project(id);
    assert(project.info_uri == "12345", 'Project Not Found');
}

#[test]
fn test_total_projects() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    contract.register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    let total = contract.total_projects();
    assert(total == 1, 'Failed to fetch total');
}

#[test]
#[should_panic(expected: 'Can only close after deadline')]
fn test_close_project_before_deadline() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();

    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    start_cheat_caller_address(contract_address, project_owner);
    let id: u256 = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    contract.close_project(id);

    stop_cheat_caller_address(project_owner);
}

#[test]
fn test_close_project_success() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();

    let project_owner: ContractAddress = 0x1.try_into().unwrap();

    start_cheat_caller_address(contract_address, project_owner);
    let id: u256 = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    start_cheat_block_timestamp(contract_address, block_timestamp: get_block_timestamp() + 1200);
    contract.close_project(id);

    stop_cheat_caller_address(project_owner);
}

#[test]
#[should_panic]
fn test_failed_close_project() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();

    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    start_cheat_caller_address(contract_address, project_owner);
    let id: u256 = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    stop_cheat_caller_address(project_owner);
    let project_owner: ContractAddress = 0x2.try_into().unwrap();
    contract.close_project(id);
}

#[test]
fn test_successful_get_completed_projects() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    start_cheat_caller_address(contract_address, project_owner);
    let id = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    contract.mark_project_completed(id);
    stop_cheat_caller_address(project_owner);
    let completed = contract.all_completed_projects();
    assert(completed.len() == 1, 'Failed');
}

#[test]
fn test_successful_escrow_creation() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, project_owner);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(project_owner, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, project_owner);
    let id = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let escrow_id = contract.fund_project(id, 200);
    stop_cheat_caller_address(project_owner);

    let user_bal = token_dispatcher.get_balance(project_owner);
    let contract_bal = token_dispatcher.get_balance(contract_address);
    assert(escrow_id == 1, 'wrong id');

    let escrow = contract.view_escrow(escrow_id);

    assert(escrow.project_id == id, 'wrong ID');
    assert(escrow.initial_deposit == (200 * 95) / 100, 'wrong amount');
    assert(contract_bal == 200, 'Contract did not get the funds');
    assert(user_bal == 300, 'user bal error');
    assert(escrow.is_active, 'active error');
}

#[test]
#[should_panic]
fn test_escrow_creation_with_0_STRK() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, project_owner);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(project_owner, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, project_owner);
    let id = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let _escrow_id = contract.fund_project(id, 0);
    stop_cheat_caller_address(project_owner);
}


#[test]
#[should_panic]
fn test_escrow_creation_with_low_balance() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, project_owner);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(project_owner, 50);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, project_owner);
    let id = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let _escrow_id = contract.fund_project(id, 60);
    stop_cheat_caller_address(project_owner);
}

#[test]
#[should_panic]
fn test_escrow_creation_funding_another_person_project() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    let project_owner_2: ContractAddress = 0x165.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, project_owner_2);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(project_owner_2, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, project_owner_2);
    let id = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let _escrow_id = contract.fund_project(id, 0);
    stop_cheat_caller_address(project_owner);
}

#[test]
fn test_successful_add_escrow_funds() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, project_owner);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(project_owner, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, project_owner);
    let id = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let escrow_id = contract.fund_project(id, 200);
    let balance_after_first_fund: u256 = contract.view_escrow(escrow_id).initial_deposit;

    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 500);

    contract.add_escrow_funding(escrow_id, 100);
    stop_cheat_caller_address(project_owner);

    let user_bal = token_dispatcher.get_balance(project_owner);
    let contract_bal = token_dispatcher.get_balance(contract_address);
    assert(escrow_id == 1, 'wrong id');

    let escrow = contract.view_escrow(escrow_id);
    assert(
        escrow.initial_deposit == (balance_after_first_fund + ((100_u256 * 95_u256) / 100_u256)),
        'Incorrect balance',
    );
    assert(contract_bal == 300, 'Contract did not get the funds');
    assert(user_bal == 200, 'user bal error');
    assert(escrow.is_active, 'active error');
}

#[test]
#[should_panic]
fn test_add_escrow_funds_with_low_funds() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, project_owner);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(project_owner, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, project_owner);
    let id = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let escrow_id = contract.fund_project(id, 200);

    contract.add_escrow_funding(escrow_id, 301);
    stop_cheat_caller_address(project_owner);

    let _user_bal = token_dispatcher.get_balance(project_owner);
    let _contract_bal = token_dispatcher.get_balance(contract_address);
    assert(escrow_id == 1, 'wrong id');

    let _escrow = contract.view_escrow(escrow_id);
}


#[test]
#[should_panic]
fn test_add_escrow_funds_to_another_person_escrow() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    let project_owner_1: ContractAddress = 0x1642.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, project_owner);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(project_owner, 500);
    token_dispatcher.mint(project_owner_1, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, project_owner);
    let id = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let escrow_id = contract.fund_project(id, 200);

    stop_cheat_caller_address(project_owner);

    start_cheat_caller_address(contract_address, project_owner_1);
    token_dispatcher.approve_user(contract_address, 500);
    contract.add_escrow_funding(escrow_id, 100);
    stop_cheat_caller_address(project_owner_1);
}
// #[test]
// fn test_successful_pull_escrow_funds() {
//     let contract = contract();
//     let contract_address = contract.contract_address;
//     let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
//     let project_owner: ContractAddress = 0x1.try_into().unwrap();
//     let erc20_address = contract.get_erc20_address();
//     let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
//     start_cheat_caller_address(erc20_address, project_owner);
//     // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
//     token_dispatcher.mint(project_owner, 500);
//     token_dispatcher.approve_user(contract_address, 500);

//     stop_cheat_caller_address(erc20_address);
//     start_cheat_caller_address(contract_address, project_owner);
//     let id = contract
//         .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

//     let escrow_id = contract.fund_project(id, 200);

//     // fast forward time
//     let current_time = get_block_timestamp();
//     let one_hour_later = current_time + 3600;

//     start_cheat_block_timestamp(contract_address, one_hour_later);

//     contract.pull_escrow_funding(escrow_id);

//     let user_bal = token_dispatcher.get_balance(project_owner);
//     let contract_bal = token_dispatcher.get_balance(contract_address);
//     assert(escrow_id == 1, 'wrong id');
//     let escrow = contract.view_escrow(escrow_id);
//     assert(escrow.initial_deposit == 0, '60');
//     assert(contract_bal == 0, 'Contract did not get the funds');
//     assert(user_bal == 500, 'user bal error');
//     assert(!escrow.is_active, 'active error');

//     stop_cheat_caller_address(project_owner);
// }

// #[test]
// #[should_panic]
// fn test_adding_funds_after_pulling_escrow_funds_before_time() {
//     let contract = contract();
//     let contract_address = contract.contract_address;
//     let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
//     let project_owner: ContractAddress = 0x1.try_into().unwrap();
//     let erc20_address = contract.get_erc20_address();
//     let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
//     start_cheat_caller_address(erc20_address, project_owner);
//     // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
//     token_dispatcher.mint(project_owner, 500);
//     token_dispatcher.approve_user(contract_address, 500);

//     stop_cheat_caller_address(erc20_address);
//     start_cheat_caller_address(contract_address, project_owner);
//     let id = contract
//         .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

//     let escrow_id = contract.fund_project(id, 200, 60);

//     contract.pull_escrow_funding(escrow_id);

//     stop_cheat_caller_address(project_owner);
// }

// #[test]
// #[should_panic]
// fn test_adding_funds_after_pulling_escrow_funds() {
//     let contract = contract();
//     let contract_address = contract.contract_address;
//     let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
//     let project_owner: ContractAddress = 0x1.try_into().unwrap();
//     let erc20_address = contract.get_erc20_address();
//     let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
//     start_cheat_caller_address(erc20_address, project_owner);
//     // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
//     token_dispatcher.mint(project_owner, 500);
//     token_dispatcher.approve_user(contract_address, 500);

//     stop_cheat_caller_address(erc20_address);
//     start_cheat_caller_address(contract_address, project_owner);
//     let id = contract
//         .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

//     let escrow_id = contract.fund_project(id, 200, 60);

//     // fast forward time
//     let current_time = get_block_timestamp();
//     let one_hour_later = current_time + 3600;

//     start_cheat_block_timestamp(contract_address, one_hour_later);

//     contract.pull_escrow_funding(escrow_id);

//     contract.add_escrow_funding(escrow_id, 100);

//     stop_cheat_caller_address(project_owner);
// }

// #[test]
// #[should_panic]
// fn test_pull_someone_elses_escrow_funds() {
//     let contract = contract();
//     let contract_address = contract.contract_address;
//     let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
//     let project_owner: ContractAddress = 0x1.try_into().unwrap();
//     let malicious_address: ContractAddress = 0x1542.try_into().unwrap();
//     let erc20_address = contract.get_erc20_address();
//     let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
//     start_cheat_caller_address(erc20_address, project_owner);
//     // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
//     token_dispatcher.mint(project_owner, 500);
//     token_dispatcher.approve_user(contract_address, 500);

//     stop_cheat_caller_address(erc20_address);
//     start_cheat_caller_address(contract_address, project_owner);
//     let id = contract
//         .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

//     let escrow_id = contract.fund_project(id, 200, 60);
//     stop_cheat_caller_address(project_owner);
//     // fast forward time
//     let current_time = get_block_timestamp();
//     let one_hour_later = current_time + 3600;

//     start_cheat_block_timestamp(contract_address, one_hour_later);

//     start_cheat_caller_address(contract_address, malicious_address);

//     contract.pull_escrow_funding(escrow_id);

//     stop_cheat_caller_address(malicious_address);
// }

#[test]
fn test_set_role() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    contract.register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.set_role(VALIDATOR_ADDRESS(), VALIDATOR_ROLE, true);
    stop_cheat_caller_address(contract.contract_address);

    let is_validator = contract.is_validator(VALIDATOR_ROLE, VALIDATOR_ADDRESS());
    assert(is_validator, 'wrong is_validator value');
}

#[test]
#[should_panic]
fn test_set_role_should_panic_when_invalid_role_is_passed() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    contract.register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.set_role(VALIDATOR_ADDRESS(), INVALID_ROLE, true);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_role_should_panic_when_called_by_non_owner() {
    let contract = contract();

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.set_role(VALIDATOR_ADDRESS(), VALIDATOR_ROLE, true);
    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(contract.contract_address, VALIDATOR_ADDRESS());
    contract.set_role(VALIDATOR_ADDRESS(), VALIDATOR_ROLE, true);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
fn test_successful_report_submit() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, project_owner);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(project_owner, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, project_owner);
    let id = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    start_cheat_caller_address(contract_address, submitter_address);
    let submit_report = contract.submit_report(id, "0x1234");
    stop_cheat_caller_address(contract_address);

    assert(submit_report > 0, 'Failed to submit report');
    // let report_id = contract.total_reports(id);
    let (x, y): (ByteArray, bool) = contract.get_contributor_report(id, submitter_address);
    assert(x == "0x1234", 'Failed to write report');
    assert(!y, 'Failed write initail false');
}


#[test]
#[should_panic(expected: ('Project not found',))]
fn test_report_approve_should_panic_if_project_not_found() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let _smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, project_owner);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(project_owner, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, project_owner);
    let id = 40_256;

    start_cheat_caller_address(contract_address, submitter_address);
    let submit_report = contract.submit_report(id, "0x1234");
    stop_cheat_caller_address(contract_address);

    assert(submit_report > 0, 'Failed to submit report');
    // let report_id = contract.total_reports(id);
    let (x, y): (ByteArray, bool) = contract.get_contributor_report(id, submitter_address);
    assert(x == "0x1234", 'Failed to write report');
    assert(!y, 'Failed write initail false');
}

#[test]
fn test_approve_report_successfully() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, project_owner);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(project_owner, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, project_owner);
    let id = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.set_role(VALIDATOR_ADDRESS(), VALIDATOR_ROLE, true);
    stop_cheat_caller_address(contract.contract_address);

    let is_validator = contract.is_validator(VALIDATOR_ROLE, VALIDATOR_ADDRESS());
    assert(is_validator, 'wrong is_validator value');

    start_cheat_caller_address(contract_address, submitter_address);
    contract.submit_report(id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    contract.approve_report(id, submitter_address);
    stop_cheat_caller_address(contract_address);

    let (x, y): (ByteArray, bool) = contract.get_contributor_report(id, submitter_address);
    assert(x == "0x1234", 'Failed to get correct report');
    assert(y, 'Failed write approve report');

    let array_of_contributors = contract.get_list_of_approved_contributors(id);
    assert(array_of_contributors.len() == 1, 'wrong list of contributors');
    assert(*array_of_contributors.at(0) == submitter_address, 'wrong list of contributors');
}


#[test]
#[should_panic]
fn test_approve_report_should_panic_if_non_validator_tries_to_approve() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let random_address: ContractAddress = 0x664.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, project_owner);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(project_owner, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, project_owner);
    let id = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.set_role(VALIDATOR_ADDRESS(), VALIDATOR_ROLE, true);
    stop_cheat_caller_address(contract.contract_address);

    let is_validator = contract.is_validator(VALIDATOR_ROLE, VALIDATOR_ADDRESS());
    assert(is_validator, 'wrong is_validator value');

    start_cheat_caller_address(contract_address, submitter_address);
    contract.submit_report(id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, random_address);
    contract.approve_report(id, submitter_address);
    stop_cheat_caller_address(contract_address);

    let (x, y): (ByteArray, bool) = contract.get_contributor_report(id, submitter_address);
    assert(x == "0x1234", 'Failed to get correct report');
    assert(y, 'Failed write approve report');

    let array_of_contributors = contract.get_list_of_approved_contributors(id);
    assert(array_of_contributors.len() == 1, 'wrong list of contributors');
    assert(*array_of_contributors.at(0) == submitter_address, 'wrong list of contributors');
}


#[test]
#[should_panic(expected: ('Project not found',))]
fn test_approve_report_should_panic_if_project_not_found() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let _smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let random_address: ContractAddress = 0x664.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, project_owner);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(project_owner, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, project_owner);
    let id = 4_u256;
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.set_role(VALIDATOR_ADDRESS(), VALIDATOR_ROLE, true);
    stop_cheat_caller_address(contract.contract_address);

    let is_validator = contract.is_validator(VALIDATOR_ROLE, VALIDATOR_ADDRESS());
    assert(is_validator, 'wrong is_validator value');

    start_cheat_caller_address(contract_address, submitter_address);
    contract.submit_report(id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, random_address);
    contract.approve_report(id, submitter_address);
    stop_cheat_caller_address(contract_address);

    let (x, y): (ByteArray, bool) = contract.get_contributor_report(id, submitter_address);
    assert(x == "0x1234", 'Failed to get correct report');
    assert(y, 'Failed write approve report');

    let array_of_contributors = contract.get_list_of_approved_contributors(id);
    assert(array_of_contributors.len() == 1, 'wrong list of contributors');
    assert(*array_of_contributors.at(0) == submitter_address, 'wrong list of contributors');
}

// todo
// #[test]
// fn test_successful_pay_of_an_approved_validator() {
//     let contract = contract();
//     let contract_address = contract.contract_address;
//     let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
//     let project_owner: ContractAddress = 0x1.try_into().unwrap();
//     let submitter_address: ContractAddress = 0x4.try_into().unwrap();
//     let erc20_address = contract.get_erc20_address();
//     let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
//     start_cheat_caller_address(erc20_address, project_owner);
//     // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
//     token_dispatcher.mint(project_owner, 500);
//     token_dispatcher.approve_user(contract_address, 500);

//     stop_cheat_caller_address(erc20_address);
//     start_cheat_caller_address(contract_address, project_owner);
//     let id = contract
//         .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

//     let _escrow_id = contract.fund_project(id, 200);

//     start_cheat_caller_address(contract.contract_address, OWNER());
//     contract.set_role(VALIDATOR_ADDRESS(), VALIDATOR_ROLE, true);
//     contract.set_role(project_owner, VALIDATOR_ROLE, true);
//     stop_cheat_caller_address(contract.contract_address);

//     let is_validator = contract.is_validator(VALIDATOR_ROLE, VALIDATOR_ADDRESS());
//     assert(is_validator, 'wrong is_validator value');

//     start_cheat_caller_address(contract_address, submitter_address);
//     contract.submit_report(id, "0x1234");
//     stop_cheat_caller_address(contract_address);

//     start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
//     contract.approve_report(id, submitter_address);
//     stop_cheat_caller_address(contract_address);

//     let (x, y): (ByteArray, bool) = contract.get_contributor_report(id, submitter_address);
//     assert(x == "0x1234", 'Failed to get correct report');
//     assert(y, 'Failed write approve report');
//     start_cheat_caller_address(contract_address, project_owner);
//     contract.pay_approved_reports(id);
//     stop_cheat_caller_address(contract.contract_address);

//     let payment_status: bool = contract.get_contributor_paid_status(id, submitter_address);
//     assert(payment_status, 'Failed to pay the contributor');
// }

#[test]
fn test_successful_create_report() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, project_owner);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(project_owner, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, project_owner);
    let id = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(id, "report.com");
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.set_role(REPORT_ADDRESS(), REPORT_READER, true);
    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(contract.contract_address, REPORT_ADDRESS());
    let report = contract.get_report(report_id);
    assert(report.id == report_id, 'wrong report id');
    assert(report.project_id == id, 'wrong project id');
    assert(report.contributor_address == submitter_address, 'wrong submitter');
    assert(report.report_data == "report.com", 'wrong report url');
}

#[test]
fn test_successful_update_report() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let project_owner: ContractAddress = 0x1.try_into().unwrap();
    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, project_owner);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(project_owner, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, project_owner);
    let id = contract
        .register_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(id, "report.com");
    contract.update_report(report_id, id, "report.com/updated");
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.set_role(REPORT_ADDRESS(), REPORT_READER, true);
    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(contract.contract_address, REPORT_ADDRESS());
    let report = contract.get_report(report_id);
    assert(report.id == report_id, 'wrong report id');
    assert(report.project_id == id, 'wrong project id');
    assert(report.contributor_address == submitter_address, 'wrong submitter');
    assert(report.report_data == "report.com/updated", 'wrong report url');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Unauthorized: Not validator',))]
fn test_withdraw_bounty_unauthorized() {
    let contract = contract();
    let unauthorized = contract_address_const::<3>();

    // Try to withdraw without role or approved report
    start_cheat_caller_address(contract.contract_address, unauthorized);
    contract.withdraw_bounty(100, unauthorized);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Insufficient bounty balance',))]
fn test_withdraw_bounty_insufficient_balance() {
    let contract = contract();
    let validator = VALIDATOR_ADDRESS();
    let owner = OWNER();

    // Set up validator role
    start_cheat_caller_address(contract.contract_address, owner);
    contract.set_role(validator, VALIDATOR_ROLE, true);

    // Try to withdraw with zero balance
    start_cheat_caller_address(contract.contract_address, validator);
    contract.withdraw_bounty(100, validator);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Invalid recipient address',))]
fn test_withdraw_bounty_invalid_recipient() {
    let contract = contract();
    let erc20 = deploy_erc20();
    let validator = VALIDATOR_ADDRESS();
    let owner = OWNER();
    let other_address = contract_address_const::<3>();

    // Set up validator role and balance
    start_cheat_caller_address(contract.contract_address, owner);
    contract.set_role(validator, VALIDATOR_ROLE, true);
    start_cheat_caller_address(erc20.contract_address, owner);
    erc20.mint(contract.contract_address, 1000);
    start_cheat_caller_address(contract.contract_address, owner);
    contract.add_user_bounty_balance(validator, 500);

    // Try to withdraw to a different address
    start_cheat_caller_address(contract.contract_address, validator);
    contract.withdraw_bounty(200, other_address);
    stop_cheat_caller_address(contract.contract_address);
    stop_cheat_caller_address(erc20.contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Insufficient bounty balance',))]
fn test_withdraw_bounty_zero_balance_validator() {
    let contract = contract();
    let validator = VALIDATOR_ADDRESS();
    let owner = OWNER();

    // Set up validator role
    start_cheat_caller_address(contract.contract_address, owner);
    contract.set_role(validator, VALIDATOR_ROLE, true);

    // Attempt withdrawal with zero balance
    start_cheat_caller_address(contract.contract_address, validator);
    contract.withdraw_bounty(100, validator);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Insufficient bounty balance',))]
fn test_withdraw_bounty_large_amount_insufficient_validator() {
    let contract = contract();
    let erc20 = deploy_erc20();
    let owner = OWNER();
    let validator = VALIDATOR_ADDRESS();
    let large_amount =
        57896044618658097711785492504343953926634992332820282019728792003956564819968; // u256::MAX / 2

    // Set up validator role
    start_cheat_caller_address(contract.contract_address, owner);
    contract.set_role(validator, VALIDATOR_ROLE, true);

    // Mint smaller amount to contract
    start_cheat_caller_address(erc20.contract_address, owner);
    erc20.mint(contract.contract_address, 1000);

    // Add small bounty balance
    start_cheat_caller_address(contract.contract_address, owner);
    contract.add_user_bounty_balance(validator, 1000);

    // Attempt to withdraw large amount
    start_cheat_caller_address(contract.contract_address, validator);
    contract.withdraw_bounty(large_amount, validator);
    stop_cheat_caller_address(contract.contract_address);
    stop_cheat_caller_address(erc20.contract_address);
}
