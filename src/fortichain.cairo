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
    use crate::base::errors::Errors::{
        CAN_ONLY_CLOSE_AFTER_DEADLINE, ONLY_OWNER_CAN_CLOSE, ONLY_OWNER_CAN_EDIT, PROJECT_NOT_FOUND,
    };
    use crate::base::types::{Escrow, Project, Report, Validator};
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
        project_count: u256,
        escrows_count: u256,
        completed_projects: Map<u256, bool>,
        in_progress_projects: Map<u256, bool>,
        user_bounty_balances: Map<ContractAddress, u256>, // Tracks available bounties per user
        contract_paused: bool, // Pause state for emergency control
        strk_token_address: ContractAddress,
        contributor_reports: Map<(ContractAddress, u256), (ByteArray, bool)>,
        // the persons contract address and the project and
        // a link to the full report description and
        //  a status that only the validator can change
        approved_contributor_reports: Map<u256, Vec<ContractAddress>>,
        // project id and a list of the approved contributors
        paid_contributors: Map<(u256, ContractAddress), bool>,
        validators: Map<ContractAddress, (u256, Validator)>,
        project_validators: Map<u256, Validator>,
        project_escrows: Map<u256, Escrow>,
        total_validators: u256,
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
        ProjectCreated: ProjectCreated,
        ProjectClosed: ProjectClosed,
        ProjectEdited: ProjectEdited,
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
    pub struct ProjectCreated {
        pub project_id: u256,
        pub project_owner: ContractAddress,
        pub created_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProjectClosed {
        pub project_id: u256,
        pub project_owner: ContractAddress,
        pub closed_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProjectEdited {
        pub project_id: u256,
        pub project_owner: ContractAddress,
        pub edited_at: u64,
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
        fn create_project(
            ref self: ContractState,
            project_info: ByteArray,
            smart_contract_address: ContractAddress,
            signature_request: bool,
            deadline: u64,
        ) -> u256 {
            let timestamp: u64 = get_block_timestamp();
            assert(deadline > get_block_timestamp(), 'Deadline not in future');
            assert(0.try_into().unwrap() != smart_contract_address, 'Zero contract address');
            let id: u256 = self.project_count.read() + 1;
            let caller = get_caller_address();
            let project = Project {
                id,
                info_uri: project_info,
                project_owner: caller,
                smart_contract_address,
                signature_request,
                is_active: true,
                is_completed: false,
                created_at: timestamp,
                updated_at: timestamp,
                deadline,
                validator_paid: false,
                researchers_paid: false,
            };

            self.projects.write(id, project);
            self.project_count.write(id);
            self.in_progress_projects.write(id, true);

            self
                .emit(
                    Event::ProjectCreated(
                        ProjectCreated {
                            project_id: id,
                            project_owner: caller,
                            created_at: get_block_timestamp(),
                        },
                    ),
                );

            id
        }

        fn edit_project(ref self: ContractState, project_id: u256, deadline: u64) {
            let mut project = self.projects.read(project_id);
            assert(project.id > 0, PROJECT_NOT_FOUND);
            let caller = get_caller_address();
            assert(project.project_owner == caller, ONLY_OWNER_CAN_EDIT);
            assert(deadline > get_block_timestamp(), 'Deadline has passed');
            let timestamp: u64 = get_block_timestamp();
            project.updated_at = timestamp;
            project.deadline = deadline;
            self.projects.write(project.id, project);

            self
                .emit(
                    Event::ProjectEdited(
                        ProjectEdited {
                            project_id, project_owner: caller, edited_at: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn close_project(ref self: ContractState, project_id: u256) -> bool {
            let caller = get_caller_address();
            let mut project = self.projects.read(project_id);
            assert(project.id > 0, PROJECT_NOT_FOUND);
            assert(project.project_owner == caller, ONLY_OWNER_CAN_CLOSE);
            assert(project.deadline < get_block_timestamp(), CAN_ONLY_CLOSE_AFTER_DEADLINE);
            let timestamp: u64 = get_block_timestamp();
            project.is_active = false;
            project.is_completed = true;
            project.updated_at = timestamp;
            self.projects.write(project.id, project.clone());

            self.in_progress_projects.write(project_id, false);
            self.completed_projects.write(project_id, true);
            self.update_project_completion_status(project_id, true);

            self
                .emit(
                    Event::ProjectClosed(
                        ProjectClosed {
                            project_id,
                            project_owner: project.project_owner,
                            closed_at: get_block_timestamp(),
                        },
                    ),
                );

            true
        }

        fn view_project(self: @ContractState, project_id: u256) -> Project {
            let project = self.projects.read(project_id);
            assert(project.id > 0, PROJECT_NOT_FOUND);
            project
        }
        fn view_escrow(self: @ContractState, escrow_id: u256) -> Escrow {
            let escrow = self.escrows.read(escrow_id);
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

        fn project_is_completed(ref self: ContractState, project_id: u256) -> bool {
            !self.in_progress_projects.read(project_id) && self.completed_projects.read(project_id)
        }

        fn fund_project(ref self: ContractState, project_id: u256, amount: u256) -> u256 {
            let caller = get_caller_address();
            let timestamp: u64 = get_block_timestamp();
            let mut project = self.view_project(project_id);
            assert(amount > 0, 'Zero fund amount');
            assert(project.project_owner == caller, 'Only owner can fund project');
            assert(
                project.deadline > get_block_timestamp() && project.is_active, 'Project not active',
            );
            assert(
                self.project_escrows.read(project.id).id == 0
                    && !self.project_escrows.read(project.id).is_active,
                'Project has an active escrow',
            );
            let token = self.strk_token_address.read();
            let erc20_dispatcher = super::IMockUsdcDispatcher { contract_address: token };
            assert(erc20_dispatcher.get_balance(caller) > amount, 'Insufficient balance');
            let receiver = get_contract_address();
            let id: u256 = self.escrows_count.read() + 1;

            let success = self.process_payment(caller, amount, receiver);
            assert(success, 'Tokens transfer failed');

            let escrow = Escrow {
                id,
                project_id: project.id,
                projectOwner: caller,
                initial_deposit: (amount * 95_u256) / 100_u256,
                current_amount: (amount * 95_u256) / 100_u256,
                is_active: true,
                created_at: timestamp,
                updated_at: timestamp,
                validator_paid: false,
                researchers_paid: false,
            };

            self.escrows_count.write(id);
            self.escrows.write(id, escrow);
            self.project_escrows.write(project.id, escrow);

            self
                .emit(
                    Event::EscrowCreated(
                        EscrowCreated { escrow_id: id, owner: caller, amount: amount },
                    ),
                );

            id
        }

        // fn pull_escrow_funding(ref self: ContractState, escrow_id: u256) -> bool {
        //     let cur_escrow_count = self.escrows_count.read();

        //     let caller = get_caller_address();
        //     let timestamp: u64 = get_block_timestamp();
        //     let contract = get_contract_address();

        //     assert((escrow_id > 0) && (escrow_id <= cur_escrow_count), 'invalid escrow id');
        //     let mut escrow = self.view_escrow(escrow_id);
        //     let project = self.view_project(escrow.project_id);
        //     assert(timestamp > project.deadline, 'Invalid time');

        //     assert(escrow.lockTime <= timestamp, 'Unlock time in the future');
        //     assert(caller == escrow.projectOwner, 'not your escrow');

        //     assert(escrow.is_active, 'Escrow not active');
        //     assert(escrow.current_amount > 0, 'No funds to pull out');

        //     let amount = escrow.current_amount;

        //     escrow.current_amount = 0;
        //     escrow.lockTime = 0;
        //     escrow.isLocked = false;
        //     escrow.is_active = false;
        //     escrow.updated_at = timestamp;

        //     self.project_escrows.write(project.id, escrow);
        //     self.escrows.write(escrow_id, escrow);

        //     let token = self.strk_token_address.read();

        //     let erc20_dispatcher = super::IMockUsdcDispatcher { contract_address: token };

        //     let contract_bal = erc20_dispatcher.get_balance(contract);
        //     assert(contract_bal >= amount, 'Insufficient funds');
        //     let success = erc20_dispatcher.transferFrom(contract, caller, amount);
        //     assert(success, 'token withdrawal fail...');

        //     self
        //         .emit(
        //             Event::EscrowFundingPulled(
        //                 EscrowFundingPulled { escrow_id: escrow_id, owner: caller },
        //             ),
        //         );

        //     true
        // }

        fn add_escrow_funding(ref self: ContractState, escrow_id: u256, amount: u256) -> bool {
            let cur_escrow_count = self.escrows_count.read();
            assert((escrow_id > 0) && (escrow_id <= cur_escrow_count), 'invalid escrow id');
            let mut escrow = self.view_escrow(escrow_id);
            let initial_deposit = escrow.initial_deposit;
            let current_amount = escrow.current_amount;
            let project = self.projects.read(escrow.project_id);
            assert(get_block_timestamp() < project.deadline, 'Invalid time');

            let caller = get_caller_address();
            let timestamp: u64 = get_block_timestamp();
            let contract = get_contract_address();

            assert(escrow.is_active, 'escrow not active');
            assert(caller == escrow.projectOwner, 'not your escrow');

            let success = self.process_payment(caller, amount, contract);
            assert(success, 'Tokens transfer failed');
            escrow.updated_at = timestamp;
            escrow.initial_deposit = initial_deposit + (amount * 95_u256) / 100_u256;
            escrow.current_amount = current_amount + (amount * 95_u256) / 100_u256;
            self.escrows.write(escrow_id, escrow);

            self
                .emit(
                    Event::EscrowFundsAdded(
                        EscrowFundsAdded {
                            escrow_id: escrow_id, owner: caller, new_amount: escrow.initial_deposit,
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

        fn submit_report(ref self: ContractState, project_id: u256, report_uri: ByteArray) -> u256 {
            let project: Project = self.projects.read(project_id);
            assert(project.id > 0, PROJECT_NOT_FOUND);
            let caller = get_caller_address();
            let timestamp: u64 = get_block_timestamp();
            let id: u256 = self.report_count.read() + 1;

            let report = Report {
                id,
                contributor_address: caller,
                project_id,
                report_data: report_uri.clone(),
                created_at: timestamp,
                updated_at: timestamp,
            };
            self.reports.write(id, report);
            self.report_count.write(id);
            self.contributor_reports.write((caller, project_id), (report_uri, false));

            id
        }

        fn approve_report(
            ref self: ContractState, project_id: u256, submit_address: ContractAddress,
        ) {
            self.accesscontrol.assert_only_role(VALIDATOR_ROLE);
            let project: Project = self.projects.read(project_id);
            assert(project.id > 0, PROJECT_NOT_FOUND);
            let (x, mut y): (ByteArray, bool) = self
                .contributor_reports
                .read((submit_address, project_id));

            y = true;
            self.contributor_reports.write((submit_address, project_id), (x, y));

            self.approved_contributor_reports.entry(project_id).append().write(submit_address);
        }

        fn pay_validator(ref self: ContractState, project_id: u256) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            let mut project = self.view_project(project_id);
            let mut escrow = self.project_escrows.read(project.id);
            let validator = self.project_validators.read(project.id);

            assert(
                project.is_completed
                    && project.deadline < get_block_timestamp()
                    && !project.is_active,
                'Project ongoing',
            );

            assert(validator.id > 0, 'No validator assigned');

            assert(!project.validator_paid && !escrow.validator_paid, 'Validator already paid');

            assert(escrow.id > 0 && escrow.is_active, 'No escrow available');
            assert(escrow.current_amount > 0, 'No escrow funds');

            let validator_pay = (escrow.initial_deposit * 45_u256) / 100_u256;

            let success = self
                .process_payment(
                    get_contract_address(), validator_pay, validator.validator_address,
                );
            assert(success, 'Tokens transfer failed');

            escrow.validator_paid = true;
            escrow.current_amount -= validator_pay;

            self.project_escrows.write(project_id, escrow);
            project.validator_paid = true;
            self.projects.write(project_id, project);
        }

        fn pay_researchers(ref self: ContractState, project_id: u256) {}

        fn pay_approved_reports(ref self: ContractState, project_id: u256) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            let mut project: Project = self.view_project(project_id);
            assert(project.is_active, 'Project not active');
            let mut escrow = self.project_escrows.read(project_id);
            assert(escrow.id > 0, 'Invalid Escrow');
            assert(!escrow.researchers_paid, 'Researchers have been paid');
            assert(escrow.current_amount > 0, 'Zero escrow balance');

            // get the owner of the report approve status
            // let (_, mut y): (ByteArray, bool) = self
            //     .contributor_reports
            //     .read((submitter_Address, project_id));

            // assert(y, 'Report not approved');

            let list_of_approved_contributors: Array<ContractAddress> = self
                .get_list_of_approved_contributors(project_id);

            let len = list_of_approved_contributors.len();
            let mut i: u32 = 0;

            while i != len {
                let address: ContractAddress = *list_of_approved_contributors.at(i);
                self.paid_contributors.write((project_id, address), true);
                let success = self
                    .process_payment(
                        get_contract_address(),
                        ((escrow.initial_deposit * 50_u256) / 100_u256) / len.into(),
                        address,
                    );
                assert(success, 'Tokens transfer failed');
                i += 1;
            }

            project.researchers_paid = true;
            project.updated_at = get_block_timestamp();
            self.projects.write(project_id, project);

            escrow.researchers_paid = true;
            escrow.updated_at = get_block_timestamp();
            self.escrows.write(escrow.id, escrow)
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
        ) -> (ByteArray, bool) {
            let project: Project = self.projects.read(project_id);
            assert(project.id > 0, PROJECT_NOT_FOUND);

            let (x, y): (ByteArray, bool) = self
                .contributor_reports
                .read((submitter_address, project_id));

            (x, y)
        }

        fn get_report(self: @ContractState, report_id: u256) -> Report {
            self.accesscontrol.assert_only_role(REPORT_READER);
            let report = self.reports.read(report_id);
            assert(report.id > 0, 'Report not found');
            report
        }

        fn update_report(
            ref self: ContractState, report_id: u256, project_id: u256, report_uri: ByteArray,
        ) -> bool {
            let project: Project = self.projects.read(project_id);
            assert(project.id > 0, PROJECT_NOT_FOUND);
            let caller = get_caller_address();

            let mut report = self.reports.read(report_id);
            assert(report.contributor_address == caller, 'Only report owner can update');
            report.report_data = report_uri.clone();
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

        fn register_validator_profile(
            ref self: ContractState,
            validator_data_uri: ByteArray,
            validator_address: ContractAddress,
        ) {
            let current_total = self.total_validators.read();

            let validator = Validator {
                id: current_total + 1,
                validator_data_uri,
                validator_address,
                created_at: get_block_timestamp(),
                updated_at: get_block_timestamp(),
                status: 'pending',
            };

            self.validators.write(validator_address, (current_total + 1, validator));
            self.total_validators.write(current_total + 1);
        }

        fn approve_validator_profile(ref self: ContractState, validator_address: ContractAddress) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            let (id, mut validator) = self.validators.read(validator_address);
            validator.status = 'approved';

            self.validators.write(validator_address, (id, validator));
            self.set_role(validator_address, VALIDATOR_ROLE, true);
        }

        fn reject_validator_profile(ref self: ContractState, validator_address: ContractAddress) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            let (id, mut validator) = self.validators.read(validator_address);
            validator.status = 'rejected';

            self.validators.write(validator_address, (id, validator));
        }

        fn get_validator(
            self: @ContractState, validator_address: ContractAddress,
        ) -> (u256, Validator) {
            self.validators.read(validator_address)
        }

        fn get_total_validators(self: @ContractState) -> u256 {
            self.total_validators.read()
        }

        fn assign_validator(
            ref self: ContractState, project_id: u256, validator_address: ContractAddress,
        ) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            let cur_validator = self.project_validators.read(project_id);

            assert(
                cur_validator.validator_address == 0.try_into().unwrap(),
                'Project already has a validator',
            );

            let (_, validator) = self.validators.read(validator_address);
            assert(validator.status == 'approved', 'Unapproved validator');

            self.project_validators.write(project_id, validator)
        }

        fn get_assigned_project_validator(self: @ContractState, project_id: u256) -> Validator {
            self.project_validators.read(project_id)
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
            assert!(
                (role == VALIDATOR_ROLE || role == REPORT_READER || role == ADMIN_ROLE),
                "role not enable",
            );
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
