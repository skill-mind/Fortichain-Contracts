use fortichain_contracts::interfaces::IMockUsdc::{IMockUsdcDispatcher, IMockUsdcDispatcherTrait};
#[starknet::contract]
pub mod Fortichain {
    use core::array::{Array, ArrayTrait};
    use core::traits::Into;
    use fortichain_contracts::interfaces::IFortichain::IFortichain;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::storage::{
        Map, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use crate::base::errors::Errors::{ONLY_CREATOR_CAN_CLOSE, PROJECT_NOT_FOUND};
    use crate::base::types::{Escrow, Project, Report};
    use super::IMockUsdcDispatcherTrait;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;

    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        projects: Map<u256, Project>,
        escrows: Map<u256, Escrow>,
        escrows_balance: Map<u256, u256>,
        escrows_is_active: Map<u256, bool>,
        project_count: u256,
        escrows_count: u256,
        completed_projects: Map<u256, bool>,
        in_progress_projects: Map<u256, bool>,
        user_bounty_balances: Map<ContractAddress, u256>, // Tracks available bounties per user
        contract_paused: bool, // Pause state for emergency control
        strk_token_address: ContractAddress,
        contributor_reports: Map<(ContractAddress, u256), (felt252, bool)>,
        // the persons contract address and the project and
        // a link to the full report description and
        //  a status that only the validator can change
        approved_contributor_reports: Map<u256, Vec<ContractAddress>>,
        // project id and a list of the approved contributors
        paid_contributors: Map<(u256, ContractAddress), bool>,
        report_count: u256,
        reports: Map<u256, Report>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ProjectStatusChanged: ProjectStatusChanged,
        EscrowCreated: EscrowCreated,
        EscrowFundingPulled: EscrowFundingPulled,
        EscrowFundsAdded: EscrowFundsAdded,
        BountyWithdrawn: BountyWithdrawn,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProjectStatusChanged {
        pub project_id: u256,
        pub status: bool // true for completed, false for in-progress
    }
    #[derive(Drop, starknet::Event)]
    pub struct BountyWithdrawn {
        pub user: ContractAddress,
        pub amount: u256,
        pub recipient: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EscrowCreated {
        pub escrow_id: u256,
        pub owner: ContractAddress,
        pub unlock_time: u64,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EscrowFundsAdded {
        pub escrow_id: u256,
        pub owner: ContractAddress,
        pub new_amount: u256,
    }


    #[derive(Drop, starknet::Event)]
    pub struct EscrowFundingPulled {
        pub escrow_id: u256,
        pub owner: ContractAddress,
    }
    const PROJECT_OWNER_ROLE: felt252 = selector!("PROJECT_OWNER_ROLE");
    const RESEARCHER_ROLE: felt252 = selector!("RESEARCHER_ROLE");
    const VALIDATOR_ROLE: felt252 = selector!("VALIDATOR_ROLE");
    const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");
    const REPORT_READER: felt252 = selector!("REPORT_READER");


    #[constructor]
    fn constructor(ref self: ContractState, erc20: ContractAddress, owner: ContractAddress) {
        self.strk_token_address.write(erc20);
        self.ownable.initializer(owner);
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(VALIDATOR_ROLE, owner);
    }

    #[abi(embed_v0)]
    impl FortichainImpl of IFortichain<ContractState> {
        fn register_project(
            ref self: ContractState,
            project_info: ByteArray,
            smart_contract_address: ContractAddress,
            contact: ByteArray,
            signature_request: bool,
        ) -> u256 {
            let timestamp: u64 = get_block_timestamp();
            let id: u256 = self.project_count.read() + 1;
            let caller = get_caller_address();
            let project = Project {
                id,
                info_uri: project_info,
                creator_address: caller,
                smart_contract_address,
                contact,
                signature_request,
                is_active: true,
                is_completed: false,
                created_at: timestamp,
                updated_at: timestamp,
            };

            self.projects.write(id, project);
            self.project_count.write(id);
            self.in_progress_projects.write(id, true);

            id
        }

        fn edit_project(
            ref self: ContractState,
            id: u256,
            info_uri: ByteArray,
            smart_contract_address: ContractAddress,
            contact: ByteArray,
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

            if project.info_uri != info_uri {
                project.info_uri = info_uri;
            }
            if project.smart_contract_address != smart_contract_address {
                project.smart_contract_address = smart_contract_address;
            }
            if project.contact != contact {
                project.contact = contact;
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

            self.in_progress_projects.write(id, false);
            self.completed_projects.write(id, true);

            true
        }

        fn view_project(self: @ContractState, id: u256) -> Project {
            let project = self.projects.read(id);
            assert(project.id > 0, PROJECT_NOT_FOUND);
            project
        }
        fn view_escrow(self: @ContractState, id: u256) -> Escrow {
            let escrow = self.escrows.read(id);
            assert(escrow.id > 0, 'ESCROW not found');
            escrow
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

        fn fund_project(
            ref self: ContractState, project_id: u256, amount: u256, lockTime: u64,
        ) -> u256 {
            assert(amount > 0, 'Invalid fund amount');
            assert(lockTime > 0, 'unlock time not in the future');
            let caller = get_caller_address();
            let timestamp: u64 = get_block_timestamp();
            let receiver = get_contract_address();
            let id: u256 = self.escrows_count.read() + 1;
            let mut project = self.view_project(project_id);
            assert(project.creator_address == caller, 'Can only fund your project');

            let success = self.process_payment(caller, amount, receiver);
            assert(success, 'Tokens transfer failed');

            let escrow = Escrow {
                id,
                project_id: project.id,
                projectOwner: caller,
                amount: amount,
                isLocked: true,
                lockTime: timestamp + lockTime,
                is_active: true,
                created_at: timestamp,
                updated_at: timestamp,
            };

            self.escrows_count.write(id);
            self.escrows_is_active.write(id, true);
            self.escrows_balance.write(id, amount);
            self.escrows.write(id, escrow);

            self
                .emit(
                    Event::EscrowCreated(
                        EscrowCreated {
                            escrow_id: id, owner: caller, unlock_time: lockTime, amount: amount,
                        },
                    ),
                );

            id
        }
        fn pull_escrow_funding(ref self: ContractState, escrow_id: u256) -> bool {
            let cur_escrow_count = self.escrows_count.read();

            let caller = get_caller_address();
            let timestamp: u64 = get_block_timestamp();
            let contract = get_contract_address();

            assert((escrow_id > 0) && (escrow_id >= cur_escrow_count), 'invalid escrow id');
            let mut escrow = self.view_escrow(escrow_id);

            assert(escrow.lockTime <= timestamp, 'Unlock time in the future');
            assert(caller == escrow.projectOwner, 'not your escrow');

            assert(escrow.is_active, 'No funds to pull out');

            let amount = escrow.amount;

            escrow.amount = 0;
            escrow.lockTime = 0;
            escrow.isLocked = false;
            escrow.is_active = false;
            escrow.updated_at = timestamp;

            self.escrows_is_active.write(escrow_id, false);
            self.escrows_balance.write(escrow_id, 0);
            self.escrows.write(escrow_id, escrow);

            let token = self.strk_token_address.read();

            let erc20_dispatcher = super::IMockUsdcDispatcher { contract_address: token };

            let contract_bal = erc20_dispatcher.get_balance(contract);
            assert(contract_bal >= amount, 'Insufficient funds');
            let success = erc20_dispatcher.transferFrom(contract, caller, amount);
            assert(success, 'token withdrawal fail...');

            self
                .emit(
                    Event::EscrowFundingPulled(
                        EscrowFundingPulled { escrow_id: escrow_id, owner: caller },
                    ),
                );

            true
        }

        fn add_escrow_funding(ref self: ContractState, escrow_id: u256, amount: u256) -> bool {
            let cur_escrow_count = self.escrows_count.read();

            let caller = get_caller_address();
            let timestamp: u64 = get_block_timestamp();
            let contract = get_contract_address();

            assert((escrow_id > 0) && (escrow_id >= cur_escrow_count), 'invalid escrow id');
            let mut escrow = self.view_escrow(escrow_id);

            assert(escrow.lockTime >= timestamp, 'Escrow has Matured');
            assert(escrow.is_active, 'escrow not active');
            assert(caller == escrow.projectOwner, 'not your escrow');

            let success = self.process_payment(caller, amount, contract);
            assert(success, 'Tokens transfer failed');
            escrow.amount += amount;

            escrow.updated_at = timestamp;

            self.escrows_balance.write(escrow_id, escrow.amount);
            self.escrows.write(escrow_id, escrow);

            self
                .emit(
                    Event::EscrowFundsAdded(
                        EscrowFundsAdded {
                            escrow_id: escrow_id, owner: caller, new_amount: escrow.amount,
                        },
                    ),
                );

            true
        }

        fn process_payment(
            ref self: ContractState,
            payer: ContractAddress,
            amount: u256,
            recipient: ContractAddress,
        ) -> bool { // TODO: Uncomment code after ERC20 implementation
            let token = self.strk_token_address.read();

            let erc20_dispatcher = super::IMockUsdcDispatcher { contract_address: token };
            erc20_dispatcher.approve_user(get_contract_address(), amount);
            let contract_allowance = erc20_dispatcher.get_allowance(payer, get_contract_address());
            assert(contract_allowance >= amount, 'INSUFFICIENT_ALLOWANCE');
            let user_bal = erc20_dispatcher.get_balance(payer);
            assert(user_bal >= amount, 'Insufficient funds');
            let success = erc20_dispatcher.transferFrom(payer, recipient, amount);
            assert(success, 'token withdrawal fail...');
            success
        }

        fn get_erc20_address(self: @ContractState) -> ContractAddress {
            let token = self.strk_token_address.read();
            token
        }

        fn submit_report(ref self: ContractState, project_id: u256, link_to_work: felt252) -> bool {
            let project: Project = self.projects.read(project_id);
            let caller = get_caller_address();
            assert(project.id > 0, PROJECT_NOT_FOUND);
            self.contributor_reports.write((caller, project_id), (link_to_work, false));
            true
        }

        fn approve_a_report(
            ref self: ContractState, project_id: u256, submit_address: ContractAddress,
        ) {
            self.accesscontrol.assert_only_role(VALIDATOR_ROLE);
            let project: Project = self.projects.read(project_id);
            assert(project.id > 0, PROJECT_NOT_FOUND);
            let (x, mut y): (felt252, bool) = self
                .contributor_reports
                .read((submit_address, project_id));

            y = true;
            self.contributor_reports.write((submit_address, project_id), (x, y));

            self.approved_contributor_reports.entry(project_id).append().write(submit_address);
        }

        fn pay_an_approved_report(
            ref self: ContractState,
            project_id: u256,
            amount: u256,
            submitter_Address: ContractAddress,
        ) {
            assert(amount > 0, 'Invalid fund amount');
            let caller = get_caller_address();

            let mut project: Project = self.view_project(project_id);
            assert(project.creator_address == caller, 'Only project owner can pay');
            assert(project.is_active, 'Project not active');

            // get the owner of the report approve status
            let (_, mut y): (felt252, bool) = self
                .contributor_reports
                .read((submitter_Address, project_id));

            assert(y, 'Report not approved');

            let _get_list_of_approved_contributors: Array<ContractAddress> = self
                .get_list_of_approved_contributors(project_id);
            // should be checked here

            // assert that the report_id has not been paid
            let mut paid_report: bool = self.paid_contributors.read((project_id, caller));
            assert(!paid_report, 'Report already paid');
            paid_report = true;
            self.paid_contributors.write((project_id, submitter_Address), true);

            let timestamp: u64 = get_block_timestamp();
            project.updated_at = timestamp;
            self.projects.write(project_id, project);

            let success = self.process_payment(get_contract_address(), amount, submitter_Address);
            assert(success, 'Tokens transfer failed');
        }


        fn set_role(
            ref self: ContractState, recipient: ContractAddress, role: felt252, is_enable: bool,
        ) {
            self._set_role(recipient, role, is_enable);
        }
        fn is_validator(self: @ContractState, role: felt252, address: ContractAddress) -> bool {
            self.accesscontrol.has_role(role, address)
        }


        fn get_list_of_approved_contributors(
            ref self: ContractState, project_id: u256,
        ) -> Array<ContractAddress> {
            let project: Project = self.projects.read(project_id);
            assert(project.id > 0, PROJECT_NOT_FOUND);

            let report_vec = self.approved_contributor_reports.entry(project_id);
            let len = report_vec.len();
            let mut i: u64 = 0;
            let mut approved_contributors = ArrayTrait::new();

            while i < len {
                let address = report_vec.at(i).read();
                approved_contributors.append(address);
                i += 1;
            }
            approved_contributors
        }

        fn get_contributor_paid_status(
            ref self: ContractState, project_id: u256, submitter_address: ContractAddress,
        ) -> bool {
            let project: Project = self.projects.read(project_id);
            assert(project.id > 0, PROJECT_NOT_FOUND);

            let paid_report: bool = self.paid_contributors.read((project_id, submitter_address));
            paid_report
        }

        fn get_contributor_report(
            ref self: ContractState, project_id: u256, submitter_address: ContractAddress,
        ) -> (felt252, bool) {
            let project: Project = self.projects.read(project_id);
            assert(project.id > 0, PROJECT_NOT_FOUND);

            let (x, y): (felt252, bool) = self
                .contributor_reports
                .read((submitter_address, project_id));

            (x, y)
        }

        fn new_report(ref self: ContractState, project_id: u256, link_to_work: ByteArray) -> u256 {
            let project: Project = self.projects.read(project_id);
            assert(project.id > 0, PROJECT_NOT_FOUND);
            let caller = get_caller_address();
            let timestamp: u64 = get_block_timestamp();
            let id: u256 = self.report_count.read() + 1;
            let report = Report {
                id,
                contributor_address: caller,
                project_id,
                report_data: link_to_work.clone(),
                created_at: timestamp,
                updated_at: timestamp,
            };
            self.reports.write(id, report);
            self.report_count.write(id);

            id
        }

        fn get_report(self: @ContractState, report_id: u256) -> Report {
            self.accesscontrol.assert_only_role(REPORT_READER);
            let report = self.reports.read(report_id);
            assert(report.id > 0, 'Report not found');
            report
        }

        fn delete_report(ref self: ContractState, report_id: u256, project_id: u256) -> bool {
            let project: Project = self.projects.read(project_id);
            assert(project.id > 0, PROJECT_NOT_FOUND);
            let caller = get_caller_address();

            let report = self.reports.read(report_id);
            assert(report.id > 0, 'Report not found');

            let mut report = self.reports.read(report_id);
            assert(report.contributor_address == caller, 'Only report owner can update');
            report.project_id = 0;
            report.report_data = " ";
            report.updated_at = get_block_timestamp();

            self.reports.write(report_id, report);

            true
        }
        fn update_report(
            ref self: ContractState, report_id: u256, project_id: u256, link_to_work: ByteArray,
        ) -> bool {
            let project: Project = self.projects.read(project_id);
            assert(project.id > 0, PROJECT_NOT_FOUND);
            let caller = get_caller_address();

            let mut report = self.reports.read(report_id);
            assert(report.contributor_address == caller, 'Only report owner can update');
            report.report_data = link_to_work.clone();
            report.updated_at = get_block_timestamp();

            self.reports.write(report_id, report);

            true
        }


        fn withdraw_bounty(
            ref self: ContractState, amount: u256, recipient: ContractAddress,
        ) -> (bool, u256) {
            // Check if contract is paused
            assert(!self.contract_paused.read(), 'Contract is paused');

            let caller = get_caller_address();
            // Verify recipient is the caller (prevents unauthorized transfers)
            assert(caller == recipient, 'Invalid recipient address');

            // Check if caller is a validator or has an approved report
            let is_validator = self.accesscontrol.has_role(VALIDATOR_ROLE, caller);
            let has_approved_report = self.has_approved_report(caller);
            assert(is_validator || has_approved_report, 'Unauthorized: Not validator');

            // Validate amount
            assert(amount > 0, 'Invalid withdrawal amount');
            let available_balance = self.user_bounty_balances.read(caller);
            assert(available_balance >= amount, 'Insufficient bounty balance');

            // Prevent reentrancy by updating balance first
            let new_balance = available_balance - amount;
            self.user_bounty_balances.write(caller, new_balance);

            // Process payment
            let success = self.process_payment(get_contract_address(), amount, recipient);
            assert(success, 'Transfer failed');

            // Emit event
            let timestamp = get_block_timestamp();
            self
                .emit(
                    Event::BountyWithdrawn(
                        BountyWithdrawn {
                            user: caller,
                            amount: amount,
                            recipient: recipient,
                            timestamp: timestamp,
                        },
                    ),
                );

            (true, new_balance)
        }
        fn add_user_bounty_balance(ref self: ContractState, user: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            assert(amount > 0, 'Invalid amount');
            let current_balance = self.user_bounty_balances.read(user);
            self.user_bounty_balances.write(user, current_balance + amount);
        }
    }
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn get_completed_projects_as_array(self: @ContractState) -> Array<u256> {
            let mut projects = ArrayTrait::new();
            let project_count = self.project_count.read();
            for i in 1..=project_count {
                if self.completed_projects.read(i) {
                    projects.append(i);
                }
            }
            projects
        }

        fn get_in_progress_projects_as_array(self: @ContractState) -> Array<u256> {
            let mut projects = ArrayTrait::new();
            let project_count = self.project_count.read();
            for i in 1..=project_count {
                if self.in_progress_projects.read(i) {
                    projects.append(i);
                }
            }
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
            }
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
            self.completed_projects.write(project_id, true);
            self.in_progress_projects.write(project_id, false);
        }

        fn add_to_in_progress(ref self: ContractState, project_id: u256) {
            self.in_progress_projects.write(project_id, true);
            self.completed_projects.write(project_id, false);
        }

        fn contains_project(self: @ContractState, project_id: u256) -> bool {
            self.completed_projects.read(project_id) || self.in_progress_projects.read(project_id)
        }

        fn _set_role(
            ref self: ContractState, recipient: ContractAddress, role: felt252, is_enable: bool,
        ) {
            self.ownable.assert_only_owner();
            self.accesscontrol.assert_only_role(VALIDATOR_ROLE);
            assert!((role == VALIDATOR_ROLE || role == REPORT_READER), "role not enable");
            if is_enable {
                self.accesscontrol._grant_role(role, recipient);
            } else {
                self.accesscontrol._revoke_role(role, recipient);
            }
        }

        fn has_approved_report(self: @ContractState, user: ContractAddress) -> bool {
            let project_count = self.project_count.read();
            let mut i: u256 = 1;
            let mut result: bool = false;
            while i <= project_count {
                let (_link, approved) = self.contributor_reports.read((user, i));
                if approved {
                    result = true;
                    break;
                }
                i += 1;
            }
            result
        }
    }
}
