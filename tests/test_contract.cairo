use core::felt252;
use core::traits::Into;
use fortichain_contracts::base::types::Project;
use fortichain_contracts::interfaces::IFortichain::{
    IFortichainDispatcher, IFortichainDispatcherTrait,
};
use fortichain_contracts::interfaces::IMockUsdc::{IMockUsdcDispatcher, IMockUsdcDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{
    ClassHash, ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
    get_contract_address,
};

// use starknet::testing::warp;

fn contract() -> IFortichainDispatcher {
    let contract_class = declare("Fortichain").unwrap().contract_class();
    let erc20_contract = deploy_erc20();
    let erc20_address = erc20_contract.contract_address;

    let (contract_address, _) = contract_class
        .deploy(@array![erc20_address.into()].into())
        .unwrap();
    (IFortichainDispatcher { contract_address })
}

fn deploy_erc20() -> IMockUsdcDispatcher {
    let owner: ContractAddress = contract_address_const::<'owner'>();

    let contract_class = declare("MockUsdc").unwrap().contract_class();
    let (contract_address, _) = contract_class.deploy(@array![owner.into()]).unwrap();

    IMockUsdcDispatcher { contract_address }
}

#[test]
fn test_successful_register_project() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );
}

#[test]
fn test_successful_edit_project() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();

    let id: u256 = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );

    let new_smart_contract_address: ContractAddress = 0x1.try_into().unwrap();
    contract
        .edit_project(
            id,
            'Updated Name',
            "Updated Description",
            "DEFI, NFT, DAO",
            new_smart_contract_address,
            "updated@email.com",
            "https://test.com/new-document.pdf",
            "https://test.com/new-logo.png",
            'Gitlab',
            "https://gitlab.com/test/test",
            false,
            false,
            true,
        );

    let project = contract.view_project(id);
    assert(project.name == 'Updated Name', 'Name not updated');
    assert(project.smart_contract_address == new_smart_contract_address, 'Address not updated');
}

#[test]
#[should_panic]
fn test_failed_edit_project() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let id: u256 = 1;
    contract
        .edit_project(
            id,
            'Updated Name',
            "Updated Description",
            "DEFI, NFT, DAO",
            smart_contract_address,
            "updated@email.com",
            "https://test.com/new-document.pdf",
            "https://test.com/new-logo.png",
            'Gitlab',
            "https://gitlab.com/test/test",
            false,
            false,
            true,
        );
}

#[test]
fn test_view_project() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let id: u256 = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );
    let project = contract.view_project(id);
    assert(project.name == 'Test Name', 'Project Not Found');
}

#[test]
fn test_total_projects() {
    let contract = contract();
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );
    let total = contract.total_projects();
    assert(total == 1, 'Failed to fetch total');
}

#[test]
fn test_successful_close_project() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();

    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    start_cheat_caller_address(contract_address, creator_address);
    let id: u256 = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );

    contract.close_project(id, creator_address);

    stop_cheat_caller_address(creator_address);
}

#[test]
#[should_panic]
fn test_failed_close_project() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();

    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    start_cheat_caller_address(contract_address, creator_address);
    let id: u256 = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );
    stop_cheat_caller_address(creator_address);
    let creator_address: ContractAddress = 0x2.try_into().unwrap();
    contract.close_project(id, creator_address);
}

#[test]
fn test_successful_get_in_progress_projects() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    start_cheat_caller_address(contract_address, creator_address);
    let id = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );
    contract.mark_project_in_progress(id);
    stop_cheat_caller_address(creator_address);
    let in_progress = contract.all_in_progress_projects();
    assert(in_progress.len() == 1, 'Failed');
}

#[test]
fn test_successful_get_completed_projects() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    start_cheat_caller_address(contract_address, creator_address);
    let id = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );
    contract.mark_project_completed(id);
    stop_cheat_caller_address(creator_address);
    let completed = contract.all_completed_projects();
    assert(completed.len() == 1, 'Failed');
}

#[test]
fn test_successful_escrow_creation() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, creator_address);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(creator_address, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, creator_address);
    let id = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );

    let escrow_id = contract.fund_project(id, 200, 60);
    stop_cheat_caller_address(creator_address);

    let user_bal = token_dispatcher.get_balance(creator_address);
    let contract_bal = token_dispatcher.get_balance(contract_address);
    assert(escrow_id == 1, 'wrong id');

    let escrow = contract.view_escrow(escrow_id);

    assert(escrow.project_name == 'Test Name', ' wrong Name');
    assert(escrow.amount == 200, '60');
    assert(contract_bal == 200, 'Contract did not get the funds');
    assert(user_bal == 300, 'user bal error');
    assert(escrow.isLocked, 'lock error');
    assert(escrow.is_active, 'active error');
}

#[test]
#[should_panic]
fn test_escrow_creation_with_0_STRK() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, creator_address);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(creator_address, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, creator_address);
    let id = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );

    let _escrow_id = contract.fund_project(id, 0, 60);
    stop_cheat_caller_address(creator_address);
}

#[test]
#[should_panic]
fn test_escrow_creation_with_unlocktime_in_the_present() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, creator_address);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(creator_address, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, creator_address);
    let id = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );

    let _escrow_id = contract.fund_project(id, 60, 0);
    stop_cheat_caller_address(creator_address);
}


#[test]
#[should_panic]
fn test_escrow_creation_with_low_balance() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, creator_address);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(creator_address, 50);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, creator_address);
    let id = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );

    let _escrow_id = contract.fund_project(id, 60, 0);
    stop_cheat_caller_address(creator_address);
}

#[test]
#[should_panic]
fn test_escrow_creation_funding_another_person_project() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    let creator_address_2: ContractAddress = 0x165.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, creator_address_2);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(creator_address_2, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, creator_address_2);
    let id = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );

    let _escrow_id = contract.fund_project(id, 0, 60);
    stop_cheat_caller_address(creator_address);
}

#[test]
fn test_successful_add_escrow_funds() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, creator_address);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(creator_address, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, creator_address);
    let id = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );

    let escrow_id = contract.fund_project(id, 200, 60);

    contract.add_escrow_funding(escrow_id, 100);
    stop_cheat_caller_address(creator_address);

    let user_bal = token_dispatcher.get_balance(creator_address);
    let contract_bal = token_dispatcher.get_balance(contract_address);
    assert(escrow_id == 1, 'wrong id');

    let escrow = contract.view_escrow(escrow_id);

    assert(escrow.amount == 300, '60');
    assert(contract_bal == 300, 'Contract did not get the funds');
    assert(user_bal == 200, 'user bal error');
    assert(escrow.isLocked, 'lock error');
    assert(escrow.is_active, 'active error');
}

#[test]
#[should_panic]
fn test_add_escrow_funds_with_low_funds() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, creator_address);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(creator_address, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, creator_address);
    let id = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );

    let escrow_id = contract.fund_project(id, 200, 60);

    contract.add_escrow_funding(escrow_id, 301);
    stop_cheat_caller_address(creator_address);

    let user_bal = token_dispatcher.get_balance(creator_address);
    let contract_bal = token_dispatcher.get_balance(contract_address);
    assert(escrow_id == 1, 'wrong id');

    let _escrow = contract.view_escrow(escrow_id);
}


#[test]
#[should_panic]
fn test_add_escrow_funds_to_another_person_escrow() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    let creator_address_1: ContractAddress = 0x1642.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, creator_address);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(creator_address, 500);
    token_dispatcher.mint(creator_address_1, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, creator_address);
    let id = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );

    let escrow_id = contract.fund_project(id, 200, 60);

    stop_cheat_caller_address(creator_address);

    start_cheat_caller_address(contract_address, creator_address_1);
    token_dispatcher.approve_user(contract_address, 500);
    contract.add_escrow_funding(escrow_id, 100);
    stop_cheat_caller_address(creator_address_1);
}
#[test]
fn test_successful_pull_escrow_funds() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, creator_address);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(creator_address, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, creator_address);
    let id = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );

    let escrow_id = contract.fund_project(id, 200, 60);

    // fast forward time
    let current_time = get_block_timestamp();
    let one_hour_later = current_time + 3600;

    start_cheat_block_timestamp(contract_address, one_hour_later);

    contract.pull_escrow_funding(escrow_id);

    let user_bal = token_dispatcher.get_balance(creator_address);
    let contract_bal = token_dispatcher.get_balance(contract_address);
    assert(escrow_id == 1, 'wrong id');
    let escrow = contract.view_escrow(escrow_id);
    assert(escrow.amount == 0, '60');
    assert(contract_bal == 0, 'Contract did not get the funds');
    assert(user_bal == 500, 'user bal error');
    assert(!escrow.isLocked, 'lock error');
    assert(!escrow.is_active, 'active error');

    stop_cheat_caller_address(creator_address);
}

#[test]
#[should_panic]
fn test_adding_funds_after_pulling_escrow_funds_before_time() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, creator_address);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(creator_address, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, creator_address);
    let id = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );

    let escrow_id = contract.fund_project(id, 200, 60);

    contract.pull_escrow_funding(escrow_id);

    stop_cheat_caller_address(creator_address);
}


#[test]
#[should_panic]
fn test_adding_funds_after_pulling_escrow_funds() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, creator_address);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(creator_address, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, creator_address);
    let id = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );

    let escrow_id = contract.fund_project(id, 200, 60);

    // fast forward time
    let current_time = get_block_timestamp();
    let one_hour_later = current_time + 3600;

    start_cheat_block_timestamp(contract_address, one_hour_later);

    contract.pull_escrow_funding(escrow_id);

    contract.add_escrow_funding(escrow_id, 100);

    stop_cheat_caller_address(creator_address);
}

#[test]
#[should_panic]
fn test_pull_someone_elses_escrow_funds() {
    let contract = contract();
    let contract_address = contract.contract_address;
    let smart_contract_address: ContractAddress = 0x0.try_into().unwrap();
    let creator_address: ContractAddress = 0x1.try_into().unwrap();
    let malicious_address: ContractAddress = 0x1542.try_into().unwrap();
    let erc20_address = contract.get_erc20_address();
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, creator_address);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(creator_address, 500);
    token_dispatcher.approve_user(contract_address, 500);

    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, creator_address);
    let id = contract
        .register_project(
            'Test Name',
            "Test Description",
            "DEFI, NFT, Gaming",
            smart_contract_address,
            "test@email.com",
            "https://test.com/supporting-document.pdf",
            "https://test.com/logo.png",
            'Github',
            "https://github.com/test/test",
            true,
        );

    let escrow_id = contract.fund_project(id, 200, 60);
    stop_cheat_caller_address(creator_address);
    // fast forward time
    let current_time = get_block_timestamp();
    let one_hour_later = current_time + 3600;

    start_cheat_block_timestamp(contract_address, one_hour_later);

    start_cheat_caller_address(contract_address, malicious_address);

    contract.pull_escrow_funding(escrow_id);

    stop_cheat_caller_address(malicious_address);
}
