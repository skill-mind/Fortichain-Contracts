use core::felt252;
use core::traits::Into;
use fortichain_contracts::base::types::Report;
use fortichain_contracts::fortichain::Fortichain;
use fortichain_contracts::interfaces::IFortichain::{
    IFortichainDispatcher, IFortichainDispatcherTrait,
};
use fortichain_contracts::interfaces::IMockUsdc::{IMockUsdcDispatcher, IMockUsdcDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, get_block_timestamp};


// Accounts
fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn OTHER() -> ContractAddress {
    'OTHER'.try_into().unwrap()
}

fn VALIDATOR_ADDRESS() -> ContractAddress {
    'VALIDATOR_ADDRESS'.try_into().unwrap()
}
fn REPORT_ADDRESS() -> ContractAddress {
    'REPORT_READER'.try_into().unwrap()
}

// Roles
const VALIDATOR_ROLE: felt252 = selector!("VALIDATOR_ROLE");
const REPORT_READER: felt252 = selector!("REPORT_READER");
const INVALID_ROLE: felt252 = selector!("INVALID_ROLE");
const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");

// Fortichain contract deployment
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

// ERC20 deployment
fn deploy_erc20() -> IMockUsdcDispatcher {
    let owner: ContractAddress = 'owner'.try_into().unwrap();

    let contract_class = declare("MockUsdc").unwrap().contract_class();
    let (contract_address, _) = contract_class.deploy(@array![owner.into()]).unwrap();

    IMockUsdcDispatcher { contract_address }
}

#[test]
fn test_successful_create_project() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
}

#[test]
#[should_panic(expected: 'Deadline not in future')]
fn test_create_project_with_past_deadline_fails() {
    let contract = contract();
    let timestamp = get_block_timestamp();
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.create_project("12345", smart_contract_address, true, timestamp);
}

#[test]
#[should_panic(expected: 'Zero contract address')]
fn test_create_project_with_zero_address() {
    let contract = contract();
    let timestamp = get_block_timestamp();
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.create_project("12345", smart_contract_address, true, timestamp + 100);
}

#[test]
fn test_create_project_event_emission() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();
    let mut spy = spy_events();

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    // Assert event emitted
    let expected_event = Fortichain::Event::ProjectCreated(
        Fortichain::ProjectCreated {
            project_id: 1, project_owner: OWNER(), created_at: get_block_timestamp(),
        },
    );
    spy.assert_emitted(@array![(contract.contract_address, expected_event)]);
}

#[test]
fn test_successful_edit_project() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    start_cheat_caller_address(contract.contract_address, OWNER());
    let id: u256 = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    contract.edit_project(id, get_block_timestamp() + 1200);

    let project = contract.view_project(id);
    assert(project.deadline == get_block_timestamp() + 1200, 'Project not edited');
}

#[test]
fn test_edit_project_event_emission() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let mut spy = spy_events();

    start_cheat_caller_address(contract.contract_address, OWNER());
    let id: u256 = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    contract.edit_project(id, get_block_timestamp() + 1200);

    // Assert event emitted
    let expected_event = Fortichain::Event::ProjectEdited(
        Fortichain::ProjectEdited {
            project_id: 1, project_owner: OWNER(), edited_at: get_block_timestamp(),
        },
    );
    spy.assert_emitted(@array![(contract.contract_address, expected_event)]);
}

#[test]
#[should_panic(expected: 'Project not found')]
fn test_edit_invalid_project() {
    let contract = contract();
    let id: u256 = 1;
    contract.edit_project(id, get_block_timestamp() + 1200);
}

#[test]
#[should_panic(expected: 'Deadline has passed')]
fn test_edit_project_after_deadline() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    start_cheat_caller_address(contract.contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    start_cheat_block_timestamp(contract.contract_address, get_block_timestamp() + 1200);
    contract.edit_project(id, get_block_timestamp() + 1200);
}

#[test]
fn test_view_project() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();
    let id: u256 = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    let project = contract.view_project(id);
    assert(project.info_uri == "12345", 'Project Not Found');
}

#[test]
fn test_total_projects() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();
    contract.create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    let total = contract.total_projects();
    assert(total == 1, 'Incorrect total projects');
}

#[test]
#[should_panic(expected: 'Can only close after deadline')]
fn test_close_project_before_deadline() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    start_cheat_caller_address(contract_address, OWNER());
    let id: u256 = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    contract.close_project(id);

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'Only owner can close project')]
fn test_close_project_by_non_project_owner() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    start_cheat_caller_address(contract_address, OWNER());
    let id: u256 = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    stop_cheat_caller_address(contract_address);

    start_cheat_block_timestamp(contract_address, block_timestamp: get_block_timestamp() + 1200);
    contract.close_project(id);
}

#[test]
#[should_panic(expected: 'Project not found')]
fn test_close_invalid_project() {
    let contract = contract();
    contract.close_project(6);
}

#[test]
fn test_close_project_success() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    start_cheat_caller_address(contract_address, OWNER());
    let id: u256 = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    start_cheat_block_timestamp(contract_address, block_timestamp: get_block_timestamp() + 1200);
    contract.close_project(id);

    stop_cheat_caller_address(contract_address);

    assert(contract.project_is_completed(id), 'Project not closed')
}

#[test]
fn test_close_project_event_emission() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();
    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, OWNER());
    let id: u256 = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    start_cheat_block_timestamp(contract_address, block_timestamp: get_block_timestamp() + 1200);
    contract.close_project(id);

    stop_cheat_caller_address(contract_address);

    // Assert event emitted
    let expected_event = Fortichain::Event::ProjectClosed(
        Fortichain::ProjectClosed {
            project_id: id, project_owner: OWNER(), closed_at: get_block_timestamp() + 1200,
        },
    );
    spy.assert_emitted(@array![(contract.contract_address, expected_event)]);
}

// #[test]
// fn test_successful_get_completed_projects() {
//     let contract = contract();
//     let contract_address = contract.contract_address;
//     let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

//     start_cheat_caller_address(contract_address, OWNER());
//     contract.create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
//     stop_cheat_caller_address(contract_address);
//     let completed = contract.all_completed_projects();
//     assert(completed.len() == 1, 'Failed');
// }

#[test]
#[should_panic(expected: 'Zero fund amount')]
fn test_fund_project_with_zero_amount() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();
    start_cheat_caller_address(contract.contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    contract.fund_project(id, 0);
}

#[test]
#[should_panic(expected: 'Project not active')]
fn test_fund_inactive_project() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();
    start_cheat_caller_address(contract.contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    start_cheat_block_timestamp(contract.contract_address, get_block_timestamp() + 1100);
    contract.close_project(id);

    contract.fund_project(id, 100);
}

#[test]
#[should_panic(expected: 'Only owner can fund project')]
fn test_fund_project_by_non_owner() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    start_cheat_caller_address(contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, OTHER());
    contract.fund_project(id, 200);
}

#[test]
fn test_fund_project_success() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let escrow_id = contract.fund_project(id, 200);
    stop_cheat_caller_address(contract_address);

    let user_bal = token_dispatcher.get_balance(OWNER());
    let contract_bal = token_dispatcher.get_balance(contract_address);
    assert(escrow_id == 1, 'wrong id');

    let escrow = contract.view_escrow(escrow_id);

    assert(escrow.project_id == id, 'wrong ID');
    assert(escrow.initial_deposit == 200, 'wrong amount');
    assert(escrow.current_amount == (200 * 95) / 100, 'wrong amount');
    assert(contract_bal == 200, 'Contract did not get the funds');
    assert(user_bal == 300, 'user bal error');
    assert(escrow.is_active, 'active error');
}

#[test]
fn test_fund_project_escrow_created_event_emission() {
    let contract = contract();
    let mut spy = spy_events();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let escrow_id = contract.fund_project(id, 200);
    stop_cheat_caller_address(contract_address);

    // Assert event emitted
    let expected_event = Fortichain::Event::EscrowCreated(
        Fortichain::EscrowCreated { escrow_id, owner: OWNER(), amount: 200 },
    );
    spy.assert_emitted(@array![(contract.contract_address, expected_event)]);
}

#[test]
#[should_panic(expected: 'Project has an active escrow')]
fn test_fund_project_with_active_escrow() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    contract.fund_project(id, 200);

    contract.fund_project(id, 200);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'Insufficient balance')]
fn test_fund_project_with_insufficient_balance() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 100);
    token_dispatcher.approve_user(contract_address, 100);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    contract.fund_project(id, 600);
}

#[test]
fn test_successful_add_escrow_funds() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let escrow_id = contract.fund_project(id, 200);
    let balance_after_first_fund: u256 = contract.view_escrow(escrow_id).initial_deposit;

    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 500);

    contract.add_escrow_funding(escrow_id, 100);
    stop_cheat_caller_address(contract_address);

    let user_bal = token_dispatcher.get_balance(OWNER());
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
fn test_successful_add_escrow_funds_event_emission() {
    let contract = contract();
    let mut spy = spy_events();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let escrow_id = contract.fund_project(id, 200);
    let balance_after_first_fund: u256 = contract.view_escrow(escrow_id).initial_deposit;

    contract.add_escrow_funding(escrow_id, 100);
    stop_cheat_caller_address(contract_address);

    // Assert event emitted
    let expected_event = Fortichain::Event::EscrowFundsAdded(
        Fortichain::EscrowFundsAdded {
            escrow_id,
            owner: OWNER(),
            new_amount: balance_after_first_fund + ((100_u256 * 95_u256) / 100_u256),
            timestamp: get_block_timestamp(),
        },
    );
    spy.assert_emitted(@array![(contract.contract_address, expected_event)]);
}

#[test]
#[should_panic]
fn test_add_escrow_funds_with_low_funds() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let escrow_id = contract.fund_project(id, 200);

    contract.add_escrow_funding(escrow_id, 301);
    stop_cheat_caller_address(contract_address);

    let _user_bal = token_dispatcher.get_balance(OWNER());
    let _contract_bal = token_dispatcher.get_balance(contract_address);
    assert(escrow_id == 1, 'wrong id');

    let _escrow = contract.view_escrow(escrow_id);
}


#[test]
#[should_panic]
fn test_add_escrow_funds_to_another_person_escrow() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let project_owner_1: ContractAddress = 0x1642.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.mint(project_owner_1, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let escrow_id = contract.fund_project(id, 200);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, project_owner_1);
    token_dispatcher.approve_user(contract_address, 500);
    contract.add_escrow_funding(escrow_id, 100);
    stop_cheat_caller_address(project_owner_1);
}
// #[test]
// fn test_successful_pull_escrow_funds() {
//     let contract = contract();
//     let contract_address = contract.contract_address;
//     let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();
//
//     let erc20_address = contract.get_erc20_address();
//     let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
//     start_cheat_caller_address(erc20_address, project_owner);
//     // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
//     token_dispatcher.mint(project_owner, 500);
//     token_dispatcher.approve_user(contract_address, 500);

//     stop_cheat_caller_address(erc20_address);
//     start_cheat_caller_address(contract_address, project_owner);
//     let id = contract
//         .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

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

//     stop_cheat_caller_address(contract_address);
// }

// #[test]
// #[should_panic]
// fn test_adding_funds_after_pulling_escrow_funds_before_time() {
//     let contract = contract();
//     let contract_address = contract.contract_address;
//     let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();
//
//     let erc20_address = contract.get_erc20_address();
//     let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
//     start_cheat_caller_address(erc20_address, project_owner);
//     // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
//     token_dispatcher.mint(project_owner, 500);
//     token_dispatcher.approve_user(contract_address, 500);

//     stop_cheat_caller_address(erc20_address);
//     start_cheat_caller_address(contract_address, project_owner);
//     let id = contract
//         .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

//     let escrow_id = contract.fund_project(id, 200, 60);

//     contract.pull_escrow_funding(escrow_id);

//     stop_cheat_caller_address(contract_address);
// }

// #[test]
// #[should_panic]
// fn test_adding_funds_after_pulling_escrow_funds() {
//     let contract = contract();
//     let contract_address = contract.contract_address;
//     let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();
//
//     let erc20_address = contract.get_erc20_address();
//     let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
//     start_cheat_caller_address(erc20_address, project_owner);
//     // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
//     token_dispatcher.mint(project_owner, 500);
//     token_dispatcher.approve_user(contract_address, 500);

//     stop_cheat_caller_address(erc20_address);
//     start_cheat_caller_address(contract_address, project_owner);
//     let id = contract
//         .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

//     let escrow_id = contract.fund_project(id, 200, 60);

//     // fast forward time
//     let current_time = get_block_timestamp();
//     let one_hour_later = current_time + 3600;

//     start_cheat_block_timestamp(contract_address, one_hour_later);

//     contract.pull_escrow_funding(escrow_id);

//     contract.add_escrow_funding(escrow_id, 100);

//     stop_cheat_caller_address(contract_address);
// }

// #[test]
// #[should_panic]
// fn test_pull_someone_elses_escrow_funds() {
//     let contract = contract();
//     let contract_address = contract.contract_address;
//     let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();
//
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
//         .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

//     let escrow_id = contract.fund_project(id, 200, 60);
//     stop_cheat_caller_address(contract_address);
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
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();
    contract.create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

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
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();
    contract.create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

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
fn test_register_validator_profile() {
    let contract = contract();
    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    assert(contract.get_total_validators() == 1, 'Create validator failed');
}

#[test]
fn test_approve_validator_profile() {
    let contract = contract();
    let contract_address = contract.contract_address;
    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    stop_cheat_caller_address(contract_address);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    start_cheat_caller_address(contract_address, OWNER());
    contract.approve_validator_profile(VALIDATOR_ADDRESS());

    let (_, validator) = contract.get_validator(VALIDATOR_ADDRESS());

    assert(validator.status == 'approved', 'Validator approval failed');
}

#[test]
fn test_reject_validator_profile() {
    let contract = contract();
    let contract_address = contract.contract_address;
    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    stop_cheat_caller_address(contract_address);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    start_cheat_caller_address(contract_address, OWNER());
    contract.reject_validator_profile(VALIDATOR_ADDRESS());

    let (_, validator) = contract.get_validator(VALIDATOR_ADDRESS());

    assert(validator.status == 'rejected', 'Validator rejection failed');
}

#[test]
fn test_assign_validator() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();
    start_cheat_caller_address(contract.contract_address, OWNER());
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    contract.set_role(OWNER(), ADMIN_ROLE, true);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    contract.approve_validator_profile(VALIDATOR_ADDRESS());

    contract.assign_validator(project_id, VALIDATOR_ADDRESS());

    assert(
        contract
            .get_assigned_project_validator(project_id)
            .validator_address == VALIDATOR_ADDRESS(),
        'INVALID VALIDATOR',
    );
}


#[test]
fn test_successful_report_submit() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    start_cheat_caller_address(contract_address, submitter_address);
    let submit_report = contract.submit_report(id, "0x1234");
    stop_cheat_caller_address(contract_address);

    assert(submit_report > 0, 'Failed to submit report');
    // let report_id = contract.total_reports(id);
    let (x, y): (Report, bool) = contract.get_contributor_report(id, submitter_address);
    assert(x.report_uri == "0x1234", 'Failed to write report');
    assert(!y, 'Failed write initail false');
}

#[test]
fn test_successful_report_submit_event_emission() {
    // basic setup
    let contract = contract();
    let mut spy = spy_events();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(id, "0x1234");
    stop_cheat_caller_address(contract_address);

    assert(report_id > 0, 'Failed to submit report');
    // let report_id = contract.total_reports(id);
    let (x, y): (Report, bool) = contract.get_contributor_report(id, submitter_address);
    assert(x.report_uri == "0x1234", 'Failed to write report');
    assert(!y, 'Failed write initail false');

    // Assert event emitted
    let expected_event = Fortichain::Event::ReportSubmitted(
        Fortichain::ReportSubmitted { report_id, project_id: id, timestamp: get_block_timestamp() },
    );
    spy.assert_emitted(@array![(contract.contract_address, expected_event)]);
}

#[test]
fn test_successful_update_report() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(id, "1234");
    contract.update_report(report_id, id, "123467");
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.set_role(REPORT_ADDRESS(), REPORT_READER, true);
    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(contract.contract_address, REPORT_ADDRESS());
    let report = contract.get_report(report_id);
    assert(report.id == report_id, 'wrong report id');
    assert(report.project_id == id, 'wrong project id');
    assert(report.researcher_address == submitter_address, 'wrong submitter');
    assert(report.report_uri == "123467", 'wrong report url');
}

#[test]
fn test_successful_update_report_event_emission() {
    let contract = contract();
    let mut spy = spy_events();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, OWNER());
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(project_id, "1234");
    contract.update_report(report_id, project_id, "123467");
    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.set_role(REPORT_ADDRESS(), REPORT_READER, true);
    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(contract.contract_address, REPORT_ADDRESS());

    // Assert event emitted
    let expected_event = Fortichain::Event::ReportUpdated(
        Fortichain::ReportUpdated { project_id, report_id, timestamp: get_block_timestamp() },
    );
    spy.assert_emitted(@array![(contract.contract_address, expected_event)]);
}

#[test]
#[should_panic(expected: ('Project not found',))]
fn test_report_review_should_panic_if_project_not_found() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let _smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, OWNER());
    let id = 40_256;

    start_cheat_caller_address(contract_address, submitter_address);
    let submit_report = contract.submit_report(id, "0x1234");
    stop_cheat_caller_address(contract_address);

    assert(submit_report > 0, 'Failed to submit report');
    // let report_id = contract.total_reports(id);
    let (x, y): (Report, bool) = contract.get_contributor_report(id, submitter_address);
    assert(x.report_uri == "0x1234", 'Failed to write report');
    assert(!y, 'Failed write initail false');
}

#[test]
fn test_review_report_successfully() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    contract.approve_validator_profile(VALIDATOR_ADDRESS());

    contract.assign_validator(id, VALIDATOR_ADDRESS());

    start_cheat_caller_address(contract_address, submitter_address);
    contract.submit_report(id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    contract.review_report(id, submitter_address, true);
    stop_cheat_caller_address(contract_address);

    let (x, y): (Report, bool) = contract.get_contributor_report(id, submitter_address);
    assert(x.report_uri == "0x1234", 'Failed to get correct report');
    assert(y, 'Failed write review report');
}

#[test]
fn test_review_report_successfully_event_emission() {
    // basic setup
    let contract = contract();
    let mut spy = spy_events();

    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    contract.approve_validator_profile(VALIDATOR_ADDRESS());

    contract.assign_validator(project_id, VALIDATOR_ADDRESS());

    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(project_id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    contract.review_report(project_id, submitter_address, true);
    stop_cheat_caller_address(contract_address);

    let (x, y): (Report, bool) = contract.get_contributor_report(project_id, submitter_address);
    assert(x.report_uri == "0x1234", 'Failed to get correct report');
    assert(y, 'Failed write review report');

    // Assert event emitted
    let expected_event = Fortichain::Event::ReportReviewed(
        Fortichain::ReportReviewed {
            project_id,
            report_id,
            validator: VALIDATOR_ADDRESS(),
            accepted: true,
            timestamp: get_block_timestamp(),
        },
    );
    spy.assert_emitted(@array![(contract.contract_address, expected_event)]);
}

#[test]
fn test_review_report_approve_successfully() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    contract.set_role(OWNER(), ADMIN_ROLE, true);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    contract.approve_validator_profile(VALIDATOR_ADDRESS());

    contract.assign_validator(id, VALIDATOR_ADDRESS());

    start_cheat_caller_address(contract_address, submitter_address);
    contract.submit_report(id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    contract.review_report(id, submitter_address, true);
    stop_cheat_caller_address(contract_address);

    let array_of_contributors = contract.get_list_of_approved_contributors(id);
    assert(array_of_contributors.len() == 1, 'wrong list of contributors');
    assert(*array_of_contributors.at(0) == submitter_address, 'wrong list of contributors');
}

#[test]
fn test_review_report_reject_successfully() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    contract.set_role(OWNER(), ADMIN_ROLE, true);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    contract.approve_validator_profile(VALIDATOR_ADDRESS());

    contract.assign_validator(id, VALIDATOR_ADDRESS());

    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    contract.review_report(id, submitter_address, false);
    stop_cheat_caller_address(contract_address);

    let array_of_contributors = contract.get_list_of_approved_contributors(id);
    assert(array_of_contributors.len() == 0, 'wrong list of contributors');
    assert(contract.get_report(report_id).status == 'REJECTED', 'Report rejection failed');
}


#[test]
#[should_panic]
fn test_review_report_should_panic_if_non_validator_tries_to_approve() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let random_address: ContractAddress = 0x664.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, OWNER());
    let id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    start_cheat_caller_address(contract.contract_address, OWNER());
    contract.set_role(VALIDATOR_ADDRESS(), VALIDATOR_ROLE, true);
    stop_cheat_caller_address(contract.contract_address);

    let is_validator = contract.is_validator(VALIDATOR_ROLE, VALIDATOR_ADDRESS());
    assert(is_validator, 'wrong is_validator value');

    start_cheat_caller_address(contract_address, submitter_address);
    contract.submit_report(id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, random_address);
    contract.review_report(id, submitter_address, true);
    stop_cheat_caller_address(contract_address);

    let (x, y): (Report, bool) = contract.get_contributor_report(id, submitter_address);
    assert(x.report_uri == "0x1234", 'Failed to get correct report');
    assert(y, 'Failed write approve report');

    let array_of_contributors = contract.get_list_of_approved_contributors(id);
    assert(array_of_contributors.len() == 1, 'wrong list of contributors');
    assert(*array_of_contributors.at(0) == submitter_address, 'wrong list of contributors');
}


#[test]
#[should_panic(expected: ('Project not found',))]
fn test_review_report_should_panic_if_project_not_found() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let _smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let random_address: ContractAddress = 0x664.try_into().unwrap();

    start_cheat_caller_address(contract_address, OWNER());
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
    contract.review_report(id, submitter_address, true);
    stop_cheat_caller_address(contract_address);

    let (x, y): (Report, bool) = contract.get_contributor_report(id, submitter_address);
    assert(x.report_uri == "0x1234", 'Failed to get correct report');
    assert(y, 'Failed write approve report');

    let array_of_contributors = contract.get_list_of_approved_contributors(id);
    assert(array_of_contributors.len() == 1, 'wrong list of contributors');
    assert(*array_of_contributors.at(0) == submitter_address, 'wrong list of contributors');
}

#[test]
fn test_pay_validator_successfully() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let escrow_id = contract.fund_project(project_id, 200);
    stop_cheat_caller_address(contract_address);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    start_cheat_caller_address(contract_address, OWNER());
    contract.approve_validator_profile(VALIDATOR_ADDRESS());

    contract.assign_validator(project_id, VALIDATOR_ADDRESS());
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    contract.submit_report(project_id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    contract.review_report(project_id, submitter_address, true);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, OWNER());
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 1100);
    contract.close_project(project_id);
    let escrow_before = contract.view_escrow(escrow_id);
    contract.pay_validator(project_id);
    let escrow_after = contract.view_escrow(escrow_id);
    assert(token_dispatcher.get_balance(VALIDATOR_ADDRESS()) == 90, 'Validator not paid');
    assert_eq!(
        escrow_after.current_amount,
        escrow_before.current_amount - ((escrow_before.initial_deposit * 45_u256) / 100_u256),
        "Escrow current amount invalid",
    );
    assert(contract.view_escrow(escrow_id).validator_paid, 'Validator not paid');
    assert(contract.view_project(project_id).validator_paid, 'Validator not paid');
}

#[test]
#[should_panic(expected: 'Project ongoing')]
fn test_pay_validator_should_fail_while_project_ongoing() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    stop_cheat_caller_address(contract_address);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    start_cheat_caller_address(contract_address, OWNER());
    contract.approve_validator_profile(VALIDATOR_ADDRESS());

    contract.assign_validator(project_id, VALIDATOR_ADDRESS());
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    contract.submit_report(project_id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    contract.review_report(project_id, submitter_address, true);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, OWNER());
    contract.pay_validator(project_id);
}

#[test]
#[should_panic(expected: 'No validator assigned')]
fn test_pay_validator_should_fail_when_no_validator_is_assigned_to_project() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, OWNER());
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 1100);
    contract.close_project(project_id);
    contract.pay_validator(project_id);
}

#[test]
#[should_panic(expected: 'Validator already paid')]
fn test_pay_validator_should_fail_if_validator_has_already_been_paid() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let escrow_id = contract.fund_project(project_id, 200);
    stop_cheat_caller_address(contract_address);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    start_cheat_caller_address(contract_address, OWNER());
    contract.approve_validator_profile(VALIDATOR_ADDRESS());

    contract.assign_validator(project_id, VALIDATOR_ADDRESS());
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    contract.submit_report(project_id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    contract.review_report(project_id, submitter_address, true);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, OWNER());
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 1100);
    contract.close_project(project_id);
    contract.pay_validator(project_id);
    contract.pay_validator(project_id);
}

#[test]
#[should_panic(expected: 'No escrow available')]
fn test_pay_validator_should_fail_if_project_has_not_been_funded() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    start_cheat_caller_address(contract_address, OWNER());
    contract.approve_validator_profile(VALIDATOR_ADDRESS());

    contract.assign_validator(project_id, VALIDATOR_ADDRESS());
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    contract.submit_report(project_id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    contract.review_report(project_id, submitter_address, true);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, OWNER());
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 1100);
    contract.close_project(project_id);
    contract.pay_validator(project_id);
}

#[test]
#[should_panic(expected: 'No reports not reviewed')]
fn test_pay_validator_should_fail_if_reports_have_not_been_reviewed() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    contract.fund_project(project_id, 250);

    stop_cheat_caller_address(contract_address);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    start_cheat_caller_address(contract_address, OWNER());
    contract.approve_validator_profile(VALIDATOR_ADDRESS());

    contract.assign_validator(project_id, VALIDATOR_ADDRESS());
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    contract.submit_report(project_id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, OWNER());
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 1100);
    contract.close_project(project_id);
    contract.pay_validator(project_id);
}


#[test]
fn test_pay_validator_event_emission() {
    // basic setup
    let contract = contract();
    let mut spy = spy_events();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let escrow_id = contract.fund_project(project_id, 200);
    stop_cheat_caller_address(contract_address);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    start_cheat_caller_address(contract_address, OWNER());
    contract.approve_validator_profile(VALIDATOR_ADDRESS());

    contract.assign_validator(project_id, VALIDATOR_ADDRESS());
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    contract.submit_report(project_id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    contract.review_report(project_id, submitter_address, true);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, OWNER());
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 1100);
    contract.close_project(project_id);
    let escrow_before = contract.view_escrow(escrow_id);
    contract.pay_validator(project_id);

    // Assert event emitted
    let expected_event = Fortichain::Event::ValidatorPaid(
        Fortichain::ValidatorPaid {
            project_id,
            validator: VALIDATOR_ADDRESS(),
            amount: (escrow_before.initial_deposit * 45_u256) / 100_u256,
            timestamp: get_block_timestamp() + 1100,
        },
    );
    spy.assert_emitted(@array![(contract.contract_address, expected_event)]);
}


#[test]
fn test_pay_approved_researchers_reports() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let escrow_id = contract.fund_project(project_id, 200);
    stop_cheat_caller_address(contract_address);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    start_cheat_caller_address(contract_address, OWNER());
    contract.approve_validator_profile(VALIDATOR_ADDRESS());

    contract.assign_validator(project_id, VALIDATOR_ADDRESS());
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    contract.submit_report(project_id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    contract.review_report(project_id, submitter_address, true);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, OWNER());
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 1100);
    contract.close_project(project_id);
    contract.pay_validator(project_id);
    let escrow_after = contract.view_escrow(escrow_id);

    contract.pay_approved_researchers_reports(project_id);

    assert(
        token_dispatcher.get_balance(submitter_address) == escrow_after.current_amount,
        'researcher not paid',
    );
}


#[test]
#[should_panic(expected: 'No escrow available')]
fn test_pay_approved_researchers_reports_should_fail_if_no_escrow() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    stop_cheat_caller_address(contract_address);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    start_cheat_caller_address(contract_address, OWNER());
    contract.approve_validator_profile(VALIDATOR_ADDRESS());

    contract.assign_validator(project_id, VALIDATOR_ADDRESS());
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    contract.submit_report(project_id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    contract.review_report(project_id, submitter_address, true);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, OWNER());
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 1100);
    contract.close_project(project_id);
    contract.pay_validator(project_id);

    contract.pay_approved_researchers_reports(project_id);
}

#[test]
fn pay_approved_researchers_reports_event_emission() {
    // basic setup
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, OWNER());
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    let escrow_id = contract.fund_project(project_id, 200);
    stop_cheat_caller_address(contract_address);

    contract.register_validator_profile("1234", VALIDATOR_ADDRESS());

    start_cheat_caller_address(contract_address, OWNER());
    contract.approve_validator_profile(VALIDATOR_ADDRESS());

    contract.assign_validator(project_id, VALIDATOR_ADDRESS());
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    contract.submit_report(project_id, "0x1234");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    contract.review_report(project_id, submitter_address, true);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, OWNER());
    start_cheat_block_timestamp(contract_address, get_block_timestamp() + 1100);
    contract.close_project(project_id);
    contract.pay_validator(project_id);
    let escrow_after = contract.view_escrow(escrow_id);

    let mut spy = spy_events();

    contract.pay_approved_researchers_reports(project_id);

    // Assert event emitted
    let expected_event = Fortichain::Event::ResearchersPaid(
        Fortichain::ResearchersPaid {
            project_id: 1,
            validator: VALIDATOR_ADDRESS(),
            amount: (escrow_after.initial_deposit * 50_u256) / 100_u256,
            timestamp: get_block_timestamp() + 1100,
        },
    );
    spy.assert_emitted(@array![(contract.contract_address, expected_event)]);
}

#[test]
fn test_provide_more_details_successfully() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let requester_address: ContractAddress = 0x5.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(project_id, "initial_report");
    stop_cheat_caller_address(contract_address);

    // Check initial state
    let initial_count = contract.get_more_details_request_count();
    let initial_requests = contract.get_more_details_requests(report_id);
    assert!(initial_requests.len() == 0, "Should have no requests initially");

    start_cheat_caller_address(contract_address, requester_address);
    contract.provide_more_details(report_id, "Please provide more details about methodology");
    stop_cheat_caller_address(contract_address);

    // Verify the request was created
    let new_count = contract.get_more_details_request_count();
    let requests = contract.get_more_details_requests(report_id);

    assert(new_count == initial_count + 1, 'Request count should increment');
    assert(requests.len() == 1, 'Should have one request');

    // Test direct ID lookup
    let request = contract.get_request_by_id(1);
    assert(request.id == 1, 'Wrong request ID');
    assert(request.report_id == report_id, 'Wrong report ID');
    assert(request.requester == requester_address, 'Wrong requester');
    assert(request.details == "Please provide more details about methodology", 'Wrong details');
    assert!(!request.is_completed, "Should not be completed initially");
    assert(request.requested_at == get_block_timestamp(), 'Wrong timestamp');

    // Verify the returned data
    let from_vec = requests.at(0);
    assert(from_vec.id == @request.id, 'Vec and Map data should match');
    assert(from_vec.details == @request.details, 'Vec and Map data should match');
}

#[test]
fn test_provide_more_details_with_different_requesters() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let requester1: ContractAddress = 0x5.try_into().unwrap();
    let requester2: ContractAddress = 0x6.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(project_id, "initial_report");
    stop_cheat_caller_address(contract_address);

    // Multiple requesters can ask for more details
    start_cheat_caller_address(contract_address, requester1);
    contract.provide_more_details(report_id, "Question from requester 1");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, requester2);
    contract.provide_more_details(report_id, "Question from requester 2");
    stop_cheat_caller_address(contract_address);

    // Verify both requests were created
    let requests = contract.get_more_details_requests(report_id);
    assert(requests.len() == 2, 'Should have two requests');

    // Test direct ID lookups
    let request1 = contract.get_request_by_id(1);
    let request2 = contract.get_request_by_id(2);

    assert(request1.id == 1, 'Wrong first request ID');
    assert(request2.id == 2, 'Wrong second request ID');
    assert(request1.requester == requester1, 'Wrong first requester');
    assert(request2.requester == requester2, 'Wrong second requester');
    assert(request1.details == "Question from requester 1", 'Wrong first details');
    assert(request2.details == "Question from requester 2", 'Wrong second details');
    assert(request1.report_id == report_id, 'Wrong first report ID');
    assert(request2.report_id == report_id, 'Wrong second report ID');

    let request_ids = contract.get_request_ids_for_report(report_id);
    assert(request_ids.len() == 2, 'Should have two request IDs');
    assert(*request_ids.at(0) == 1, 'Wrong first request ID');
    assert(*request_ids.at(1) == 2, 'Wrong second request ID');
}

#[test]
fn test_provide_more_details_multiple_requests_same_report() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let requester_address: ContractAddress = 0x5.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(project_id, "initial_report");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, requester_address);
    contract.provide_more_details(report_id, "First question");
    contract.provide_more_details(report_id, "Second question");
    contract.provide_more_details(report_id, "Third question");
    stop_cheat_caller_address(contract_address);

    // Verify all three requests were created
    let requests = contract.get_more_details_requests(report_id);
    assert(requests.len() == 3, 'Should have three requests');
    assert(contract.get_more_details_request_count() == 3, 'Global count should be 3');

    // Test direct ID lookups
    let request1 = contract.get_request_by_id(1);
    let request2 = contract.get_request_by_id(2);
    let request3 = contract.get_request_by_id(3);

    assert(request1.details == "First question", 'Wrong first question');
    assert(request2.details == "Second question", 'Wrong second question');
    assert(request3.details == "Third question", 'Wrong third question');

    // All should have same requester and report_id
    assert(request1.requester == requester_address, 'Wrong requester 1');
    assert(request2.requester == requester_address, 'Wrong requester 2');
    assert(request3.requester == requester_address, 'Wrong requester 3');

    assert(request1.report_id == report_id, 'Wrong report ID 1');
    assert(request2.report_id == report_id, 'Wrong report ID 2');
    assert(request3.report_id == report_id, 'Wrong report ID 3');

    // Test get_requests_by_requester
    start_cheat_caller_address(contract_address, requester_address);
    let requester_requests = contract.get_requests_by_requester();
    assert!(requester_requests.len() == 3, "Should have 3 requests by requester");
}

#[test]
fn test_request_id_increments_across_different_reports() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let requester_address: ContractAddress = 0x5.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    let project_id1 = contract
        .create_project("Project 1", smart_contract_address, true, get_block_timestamp() + 1000);
    let project_id2 = contract
        .create_project("Project 2", smart_contract_address, true, get_block_timestamp() + 1000);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    let report_id1 = contract.submit_report(project_id1, "Report 1");
    let report_id2 = contract.submit_report(project_id2, "Report 2");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, requester_address);
    contract.provide_more_details(report_id1, "Question for report 1");
    contract.provide_more_details(report_id2, "Question for report 2");
    contract.provide_more_details(report_id1, "Another question for report 1");
    stop_cheat_caller_address(contract_address);

    // Verify the IDs are incremented correctly across reports
    let request1 = contract.get_request_by_id(1);
    let request2 = contract.get_request_by_id(2);
    let request3 = contract.get_request_by_id(3);

    assert(request1.id == 1, 'Wrong ID for request 1');
    assert(request2.id == 2, 'Wrong ID for request 2');
    assert(request3.id == 3, 'Wrong ID for request 3');

    assert(request1.report_id == report_id1, 'Wrong report for request 1');
    assert(request2.report_id == report_id2, 'Wrong report for request 2');
    assert(request3.report_id == report_id1, 'Wrong report for request 3');

    // Verify requests are properly distributed
    let report1_requests = contract.get_more_details_requests(report_id1);
    let report2_requests = contract.get_more_details_requests(report_id2);

    assert(report1_requests.len() == 2, 'Report 1 should have 2 requests');
    assert(report2_requests.len() == 1, 'Report 2 should have 1 request');

    // Test request IDs for each report
    let report1_ids = contract.get_request_ids_for_report(report_id1);
    let report2_ids = contract.get_request_ids_for_report(report_id2);

    assert!(report1_ids.len() == 2, "Report 1 should have 2 request IDs");
    assert!(report2_ids.len() == 1, "Report 2 should have 1 request ID");
    assert(*report1_ids.at(0) == 1, 'Wrong first ID for report 1');
    assert(*report1_ids.at(1) == 3, 'Wrong second ID for report 1');
    assert(*report2_ids.at(0) == 2, 'Wrong ID for report 2');
}

#[test]
fn test_mark_request_as_completed() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let requester_address: ContractAddress = 0x5.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(project_id, "initial_report");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, requester_address);
    contract.provide_more_details(report_id, "Please provide more details");
    contract.provide_more_details(report_id, "Another question");
    stop_cheat_caller_address(contract_address);

    // Initially both requests should be incomplete
    let request1 = contract.get_request_by_id(1);
    let request2 = contract.get_request_by_id(2);
    assert!(!request1.is_completed, "Request 1 should not be completed");
    assert!(!request2.is_completed, "Request 2 should not be completed");

    // Mark first request as completed
    start_cheat_caller_address(contract_address, requester_address);
    contract.mark_request_as_completed(1);
    stop_cheat_caller_address(contract_address);

    // Verify the completion status
    let updated_request1 = contract.get_request_by_id(1);
    let updated_request2 = contract.get_request_by_id(2);
    assert(updated_request1.is_completed, 'Request 1 should be completed');
    assert!(!updated_request2.is_completed, "Request 2 should still be incomplete");

    // Test get_pending_requests_for_report
    let pending = contract.get_pending_requests_for_report(report_id);
    assert(pending.len() == 1, 'Should have 1 pending request');
    assert(*(pending.at(0).id) == 2, 'Wrong pending request ID');
}

#[test]
#[should_panic(expected: 'Not authorized')]
fn test_mark_request_as_completed_unauthorized() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let requester_address: ContractAddress = 0x5.try_into().unwrap();
    let unauthorized_user: ContractAddress = 0x7.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(project_id, "initial_report");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, requester_address);
    contract.provide_more_details(report_id, "Please provide more details");
    stop_cheat_caller_address(contract_address);

    // Try to mark as completed by unauthorized user
    start_cheat_caller_address(contract_address, unauthorized_user);
    contract.mark_request_as_completed(1);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'Request not found')]
fn test_get_request_by_id_not_found() {
    let contract = contract();

    // Try to access non-existent request
    contract.get_request_by_id(999);
}

#[test]
fn test_get_more_details_requests_for_non_existent_report() {
    let contract = contract();

    // Should return empty array for non-existent report
    let requests = contract.get_more_details_requests(999);
    assert(requests.len() == 0, 'Should return empty array');

    let request_ids = contract.get_request_ids_for_report(999);
    assert(request_ids.len() == 0, 'Should return empty ID array');
}

#[test]
fn test_get_requests_by_requester_multiple_users() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let requester1: ContractAddress = 0x5.try_into().unwrap();
    let requester2: ContractAddress = 0x6.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(project_id, "initial_report");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, requester1);
    contract.provide_more_details(report_id, "Question 1 from requester 1");
    contract.provide_more_details(report_id, "Question 2 from requester 1");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, requester2);
    contract.provide_more_details(report_id, "Question from requester 2");
    stop_cheat_caller_address(contract_address);

    // Test filtering by requester
    start_cheat_caller_address(contract_address, requester1);
    let requester1_requests = contract.get_requests_by_requester();
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, requester2);
    let requester2_requests = contract.get_requests_by_requester();
    stop_cheat_caller_address(contract_address);

    assert!(requester1_requests.len() == 2, "Requester 1 should have 2 requests");
    assert!(requester2_requests.len() == 1, "Requester 2 should have 1 request");

    assert(*((requester1_requests.at(0)).requester) == requester1, 'Wrong requester for request 1');
    assert(*((requester1_requests.at(1)).requester) == requester1, 'Wrong requester for request 2');
    assert(*((requester2_requests.at(0)).requester) == requester2, 'Wrong requester for request 3');
}

#[test]
fn test_reject_report_successfully() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    // Register and approve validator
    contract.register_validator_profile("validator_data", VALIDATOR_ADDRESS());
    contract.approve_validator_profile(VALIDATOR_ADDRESS());
    contract.assign_validator(project_id, VALIDATOR_ADDRESS());
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(project_id, "report_to_reject");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    contract.reject_report(report_id);
    stop_cheat_caller_address(contract_address);

    // Verify the report status is now REJECTED
    let report = contract.get_report(report_id);
    assert(report.status == 'REJECTED', 'Report should be rejected');
}

#[test]
#[should_panic(expected: 'Caller non validator')]
fn test_reject_report_should_fail_when_non_validator_tries() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();
    let non_validator: ContractAddress = 0x7.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(project_id, "report_to_reject");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, non_validator);
    contract.reject_report(report_id);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'Report not found')]
fn test_reject_report_should_fail_with_invalid_report_id() {
    let contract = contract();
    let contract_address = contract.contract_address;

    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(VALIDATOR_ADDRESS(), VALIDATOR_ROLE, true);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    contract.reject_report(999); // Non-existent report 
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_reject_report_already_approved_report() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 'project'.try_into().unwrap();

    let submitter_address: ContractAddress = 0x4.try_into().unwrap();

    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, OWNER());
    token_dispatcher.mint(OWNER(), 500);
    token_dispatcher.approve_user(contract_address, 500);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract_address, OWNER());
    contract.set_role(OWNER(), ADMIN_ROLE, true);
    let project_id = contract
        .create_project("12345", smart_contract_address, true, get_block_timestamp() + 1000);

    // Register and approve validator
    contract.register_validator_profile("validator_data", VALIDATOR_ADDRESS());
    contract.approve_validator_profile(VALIDATOR_ADDRESS());
    contract.assign_validator(project_id, VALIDATOR_ADDRESS());
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, submitter_address);
    let report_id = contract.submit_report(project_id, "report_content");
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, VALIDATOR_ADDRESS());
    // First approve the report
    contract.review_report(project_id, submitter_address, true);
    // Then try to reject
    contract.reject_report(report_id);
    stop_cheat_caller_address(contract_address);

    // Verify the report status is now REJECTED
    let report = contract.get_report(report_id);
    assert(report.status == 'REJECTED', 'Report should be rejected');
}
