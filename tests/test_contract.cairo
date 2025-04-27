use core::felt252;
use core::traits::Into;
use fortichain_contracts::base::types::Project;
use fortichain_contracts::interfaces::IFortichain::{
    IFortichainDispatcher, IFortichainDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{
    ClassHash, ContractAddress, get_block_timestamp, get_caller_address, get_contract_address,
};

fn contract() -> IFortichainDispatcher {
    let contract_class = declare("Fortichain").unwrap().contract_class();

    let (contract_address, _) = contract_class.deploy(@array![].into()).unwrap();
    (IFortichainDispatcher { contract_address })
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
