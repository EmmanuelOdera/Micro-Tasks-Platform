module decentralized_micro_tasks::platform {

    use sui::sui::SUI;
    use sui::coin::Self;
    use sui::balance::{Self, Balance};
    use std::option::{none, some, is_some, contains, borrow};

    // Errors
    const EInvalidAssignment: u64 = 1;
    const EInvalidCompletion: u64 = 2;
    const EDispute: u64 = 3;
    const EAlreadyResolved: u64 = 4;
    const ENotCreatorOrAssignee: u64 = 5;
    const EInvalidWithdrawal: u64 = 6;

    // Struct definitions
    public struct Task has key, store {
        id: UID,
        creator: address,
        assignee: Option<address>,
        description: vector<u8>,
        reward: u64,
        escrow: Balance<SUI>,
        workSubmitted: bool,
        verified: bool,
        dispute: bool,
    }

    public struct Training has key, store {
        id: UID,
        creator: address,
        description: vector<u8>,
        reward: u64,
        escrow: Balance<SUI>,
        completed: bool,
        certified_users: vector<address>,
    }

    // Functions for task creation, assignment, completion, verification, and reward release

    // Create Task
    public entry fun create_task(description: vector<u8>, reward: u64, ctx: &mut TxContext) {
        let task_id = object::new(ctx);
        transfer::share_object(Task {
            id: task_id,
            creator: tx_context::sender(ctx),
            assignee: none(),
            description: description,
            reward: reward,
            escrow: balance::zero(),
            workSubmitted: false,
            verified: false,
            dispute: false,
        });
    }

    // Assign Task
    public entry fun assign_task(task: &mut Task, assignee: address, _ctx: &mut TxContext) {
        assert!(!is_some(&task.assignee), EInvalidAssignment);
        task.assignee = some(assignee);
    }

    // Complete Task
    public entry fun complete_task(task: &mut Task, _completion_details: vector<u8>, ctx: &mut TxContext) {
        assert!(contains(&task.assignee, &tx_context::sender(ctx)), EInvalidCompletion);
        task.workSubmitted = true;
    }

    // Verify Task Completion
    public entry fun verify_task_completion(task: &mut Task, ctx: &mut TxContext) {
        assert!(task.creator == tx_context::sender(ctx), ENotCreatorOrAssignee);
        task.verified = true;
    }

    // Release Reward
    public entry fun release_reward(task: &mut Task, ctx: &mut TxContext) {
        assert!(task.creator == tx_context::sender(ctx), ENotCreatorOrAssignee);
        assert!(task.workSubmitted && !task.dispute, EInvalidCompletion);
        assert!(is_some(&task.assignee), EInvalidAssignment);
        let assignee = *borrow(&task.assignee);
        let escrow_amount = balance::value(&task.escrow);
        let escrow_coin = coin::take(&mut task.escrow, escrow_amount, ctx);
        transfer::public_transfer(escrow_coin, assignee);

        // Reset task state
        task.assignee = none();
        task.workSubmitted = false;
        task.verified = false;
        task.dispute = false;
    }

    // Dispute Task
    public entry fun dispute_task(task: &mut Task, ctx: &mut TxContext) {
        assert!(task.creator == tx_context::sender(ctx), EDispute);
        task.dispute = true;
    }

    // Resolve Dispute
    public entry fun resolve_dispute(task: &mut Task, resolved: bool, ctx: &mut TxContext) {
        assert!(task.creator == tx_context::sender(ctx), EDispute);
        assert!(task.dispute, EAlreadyResolved);
        assert!(is_some(&task.assignee), EInvalidAssignment);
        let escrow_amount = balance::value(&task.escrow);
        let escrow_coin = coin::take(&mut task.escrow, escrow_amount, ctx);
        if (resolved) {
            let assignee = *borrow(&task.assignee);
            transfer::public_transfer(escrow_coin, assignee);
        } else {
            transfer::public_transfer(escrow_coin, task.creator);
        };

        // Reset task state
        task.assignee = none();
        task.workSubmitted = false;
        task.verified = false;
        task.dispute = false;
    }

    // View Task Details
    public entry fun view_task_details(task: &Task): (address, Option<address>, vector<u8>, u64, bool, bool, bool) {
        (
            task.creator,
            task.assignee,
            task.description,
            task.reward,
            task.workSubmitted,
            task.verified,
            task.dispute,
        )
    }

    // List Available Tasks
    public fun list_available_tasks(_tasks: &vector<Task>, ctx: &mut TxContext): vector<Task> {
        let mut available_tasks: vector<Task> = vector::empty(); // Declare as mutable
        let mut i: u64 = 0;
        while (i < vector::length(_tasks)) {
            let task = vector::borrow(_tasks, i);
            if (!is_some(&task.assignee)) {
                let new_task_id = object::new(ctx); // Generate a new UID
                let new_task = Task {
                    id: new_task_id,
                    creator: task.creator,
                    assignee: none(),
                    description: task.description,
                    reward: task.reward,
                    escrow: balance::zero(),
                    workSubmitted: task.workSubmitted,
                    verified: task.verified,
                    dispute: task.dispute,
                };
                vector::push_back(&mut available_tasks, new_task);
            };
            i = i + 1;
        };
        available_tasks
    }

    // Training Module Functions

    // Create Training
    public entry fun create_training(description: vector<u8>, reward: u64, ctx: &mut TxContext) {
        let training_id = object::new(ctx);
        transfer::share_object(Training {
            id: training_id,
            creator: tx_context::sender(ctx),
            description: description,
            reward: reward,
            escrow: balance::zero(),
            completed: false,
            certified_users: vector::empty(),
        });
    }

    // Complete Training
    public entry fun complete_training(training: &mut Training, ctx: &mut TxContext) {
        assert!(training.creator != tx_context::sender(ctx), EInvalidCompletion);
        training.completed = true;
    }

    // Certify User
    public entry fun certify_user(training: &mut Training, user: address, ctx: &mut TxContext) {
        assert!(training.creator == tx_context::sender(ctx), ENotCreatorOrAssignee);
        vector::push_back(&mut training.certified_users, user);
    }

    // Request Refund
    public entry fun request_refund(task: &mut Task, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == task.creator, ENotCreatorOrAssignee);
        assert!(task.workSubmitted == false, EInvalidWithdrawal);
        let escrow_amount = balance::value(&task.escrow);
        let escrow_coin = coin::take(&mut task.escrow, escrow_amount, ctx);
        transfer::public_transfer(escrow_coin, task.creator);

        // Reset task state
        task.assignee = none();
        task.workSubmitted = false;
        task.verified = false;
        task.dispute = false;
    }
}
