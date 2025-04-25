#[starknet::contract]
mod Fortichain {
    use core::array::{Array, ArrayTrait};
    use core::num::traits::Zero;
    use core::option::OptionTrait;
    use core::traits::Into;
    use fortichain_contracts::interfaces::IFortichain::IFortichain;
    use starknet::storage::{
        Map, Mutable, MutableVecTrait, StorageBase, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{
        ClassHash, ContractAddress, get_block_timestamp, get_caller_address, get_contract_address,
    };
    use crate::base::errors::Errors::{ONLY_CREATOR_CAN_CLOSE, PROJECT_NOT_FOUND};
    use crate::base::types::Project;

    #[storage]
    struct Storage {
        projects: Map<u256, Project>,
        project_count: u256,
        completed_projects: Vec<u256>,
        in_progress_projects: Vec<u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ProjectStatusChanged: ProjectStatusChanged,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProjectStatusChanged {
        pub project_id: u256,
        pub status: bool // true for completed, false for in-progress
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl FortichainImpl of IFortichain<ContractState> {
        fn register_project(
            ref self: ContractState,
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
        ) -> u256 {
            let timestamp: u64 = get_block_timestamp();
            let id: u256 = self.project_count.read() + 1;
            let caller = get_caller_address();
            let project = Project {
                id,
                creator_address: caller,
                name,
                description,
                category,
                smart_contract_address,
                contact,
                supporting_document_url,
                logo_url,
                repository_provider,
                repository_url,
                signature_request,
                is_active: true,
                is_completed: false,
                created_at: timestamp,
                updated_at: timestamp,
            };

            self.projects.write(id, project);
            self.project_count.write(id);
            self.in_progress_projects.push(id);

            id
        }

        fn edit_project(
            ref self: ContractState,
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
        ) {
            let project: Project = self.projects.read(id);
            assert(project.id > 0, PROJECT_NOT_FOUND);
            let caller = get_caller_address();
            assert(project.creator_address == caller, ONLY_CREATOR_CAN_CLOSE);
            let mut project = self.projects.read(id);
            let timestamp: u64 = get_block_timestamp();
            if project.name != name {
                project.name = name;
            }
            if project.description != description {
                project.description = description;
            }
            if project.category != category {
                project.category = category;
            }
            if project.smart_contract_address != smart_contract_address {
                project.smart_contract_address = smart_contract_address;
            }
            if project.contact != contact {
                project.contact = contact;
            }
            if project.supporting_document_url != supporting_document_url {
                project.supporting_document_url = supporting_document_url;
            }
            if project.logo_url != logo_url {
                project.logo_url = logo_url;
            }
            if project.repository_provider != repository_provider {
                project.repository_provider = repository_provider;
            }
            if project.repository_url != repository_url {
                project.repository_url = repository_url;
            }
            if project.signature_request != signature_request {
                project.signature_request = signature_request;
            }
            if project.is_active != is_active {
                project.is_active = is_active;
            }
            if project.is_completed != is_completed {
                project.is_completed = is_completed;
            }
            project.updated_at = timestamp;

            self.projects.write(project.id, project);
        }

        fn close_project(
            ref self: ContractState, id: u256, creator_address: ContractAddress,
        ) -> bool {
            let project: Project = self.projects.read(id);
            assert(project.id > 0, PROJECT_NOT_FOUND);
            assert(project.creator_address == creator_address, ONLY_CREATOR_CAN_CLOSE);
            let mut project = self.projects.read(id);
            let timestamp: u64 = get_block_timestamp();
            project.is_active = false;
            project.is_completed = true;
            project.updated_at = timestamp;
            self.projects.write(project.id, project);

            true
        }

        fn view_project(self: @ContractState, id: u256) -> Project {
            let project = self.projects.read(id);
            assert(project.id > 0, PROJECT_NOT_FOUND);
            project
        }

        fn total_projects(self: @ContractState) -> u256 {
            let total: u256 = self.project_count.read();
            total
        }

        fn all_completed_projects(self: @ContractState) -> Array<Project> {
            self.get_project_by_completion_status(true)
        }

        fn all_in_progress_projects(self: @ContractState) -> Array<Project> {
            self.get_project_by_completion_status(false)
        }

        fn mark_project_completed(ref self: ContractState, id: u256) {
            let caller = get_caller_address();
            let mut project = self.projects.read(id);

            assert(project.creator_address == caller, ONLY_CREATOR_CAN_CLOSE);

            project.is_active = false;
            project.is_completed = true;
            project.updated_at = get_block_timestamp();
            self.projects.write(id, project);

            self.update_project_completion_status(id, true);

            self
                .emit(
                    Event::ProjectStatusChanged(
                        ProjectStatusChanged { project_id: id, status: true },
                    ),
                );
        }

        fn mark_project_in_progress(ref self: ContractState, id: u256) {
            let caller = get_caller_address();
            let mut project = self.projects.read(id);

            assert(project.creator_address == caller, ONLY_CREATOR_CAN_CLOSE);

            project.is_active = true;
            project.is_completed = false;
            project.updated_at = get_block_timestamp();
            self.projects.write(id, project);

            self.update_project_completion_status(id, false);

            self
                .emit(
                    Event::ProjectStatusChanged(
                        ProjectStatusChanged { project_id: id, status: false },
                    ),
                );
        }
    }
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn get_completed_projects_as_array(self: @ContractState) -> Array<u256> {
            let mut projects = ArrayTrait::new();
            for i in 0..self.completed_projects.len() {
                let id: u256 = self.completed_projects.at(i).read();
                projects.append(id);
            };
            projects
        }

        fn get_in_progress_projects_as_array(self: @ContractState) -> Array<u256> {
            let mut projects = ArrayTrait::new();
            for i in 0..self.in_progress_projects.len() {
                let id: u256 = self.in_progress_projects.at(i).read();
                projects.append(id);
            };
            projects
        }

        fn get_project_by_completion_status(
            self: @ContractState, completed: bool,
        ) -> Array<Project> {
            let project_ids = if completed {
                self.get_completed_projects_as_array()
            } else {
                self.get_in_progress_projects_as_array()
            };

            let mut projects = ArrayTrait::new();
            for i in 0..project_ids.len() {
                let project_id = *project_ids[i];
                let project = self.projects.read(project_id);
                projects.append(project);
            };
            projects
        }

        fn update_project_completion_status(
            ref self: ContractState, project_id: u256, completed: bool,
        ) {
            if completed {
                self.add_to_completed(project_id);
            } else {
                self.add_to_in_progress(project_id);
            }
        }

        fn add_to_completed(ref self: ContractState, project_id: u256) {
            if !self.contains_project(self.get_completed_projects_as_array(), project_id) {
                self.completed_projects.push(project_id);
            }
        }

        fn add_to_in_progress(ref self: ContractState, project_id: u256) {
            if !self.contains_project(self.get_in_progress_projects_as_array(), project_id) {
                self.in_progress_projects.push(project_id);
            }
        }

        fn contains_project(self: @ContractState, projects: Array<u256>, project_id: u256) -> bool {
            let mut status: bool = false;
            for i in 0..projects.len() {
                if *projects[i] == project_id {
                    status = true;
                }
            };
            status
        }
    }
}
