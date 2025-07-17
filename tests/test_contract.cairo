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
