module decentralized_micro_tasks::platform {

    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use std::option::{none, some, is_some, contains, borrow};

    // Errors
    const EInvalidAssignment: u64 = 1;
    const EInvalidCompletion: u64 = 2;
    const EDispute: u64 = 3;
    const EAlreadyResolved: u64 = 4;
    const ENotCreatorOrAssignee: u64 = 5;
    const EInvalidWithdrawal: u64 = 6;
    const EInsufficientEscrow: u64 = 7;
    const ETaskCancellationFailed: u64 = 8;

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
        completion_deadline: u64, // New: Task deadline for completion
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

    public struct Rating has key, store {
        id: UID,
        rater: address,
        ratee: address,
        rating: u8, // Rating out of 10
    }

    // Functions for task creation, assignment, completion, verification, and reward release

    // Create Task with initial escrow funding
    public entry fun create_task(description: vector<u8>, reward: u64, completion_deadline: u64, mut funding: Coin<SUI>, ctx: &mut TxContext) {
        assert!(coin::value(&funding) >= reward, EInsufficientEscrow);
        let task_id = object::new(ctx);
        let mut task = Task {
            id: task_id,
            creator: tx_context::sender(ctx),
            assignee: none(),
            description: description,
            reward: reward,
            escrow: balance::zero(),
            workSubmitted: false,
            verified: false,
            dispute: false,
            completion_deadline: completion_deadline,
        };
        balance::join(&mut task.escrow, coin::into_balance(funding)); // Fund the escrow
        transfer::share_object(task);
    }

    // Assign Task
    public entry fun assign_task(task: &mut Task, assignee: address, ctx: &mut TxContext) {
        assert!(!is_some(&task.assignee), EInvalidAssignment);
        task.assignee = some(assignee);
        // Reset state for reassignments (if needed)
        task.workSubmitted = false;
        task.verified = false;
        task.dispute = false;
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
        task.completion_deadline = 0; // Reset deadline
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
        task.completion_deadline = 0;
    }

    // Cancel Task by Creator before assignment
    public entry fun cancel_task(task: &mut Task, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == task.creator, ETaskCancellationFailed);
        assert!(!is_some(&task.assignee), ETaskCancellationFailed);
        let escrow_amount = balance::value(&task.escrow);
        let escrow_coin = coin::take(&mut task.escrow, escrow_amount, ctx);
        transfer::public_transfer(escrow_coin, task.creator);

        // Delete the task
        object::delete(task.id);
    }

    // Reassign Task if not completed by the deadline
    public entry fun reassign_task(task: &mut Task, new_assignee: address, ctx: &mut TxContext) {
        assert!(task.creator == tx_context::sender(ctx), ENotCreatorOrAssignee);
        assert!(tx_context::timestamp_ms(ctx) > task.completion_deadline, EInvalidCompletion);
        assert!(!task.workSubmitted, EInvalidCompletion);

        task.assignee = some(new_assignee);
        task.workSubmitted = false;
        task.verified = false;
        task.dispute = false;
    }

    // Rate Task performance
    public entry fun rate_task(task: &Task, ratee: address, rating: u8, ctx: &mut TxContext) {
        assert!(task.creator == tx_context::sender(ctx) || contains(&task.assignee, &tx_context::sender(ctx)), ENotCreatorOrAssignee);
        assert!(rating <= 10, EInvalidCompletion); // Rating should be out of 10
        let rating_id = object::new(ctx);
        let new_rating = Rating {
            id: rating_id,
            rater: tx_context::sender(ctx),
            ratee: ratee,
            rating: rating,
        };
        transfer::share_object(new_rating);
    }

    // View Task Details
    public entry fun view_task_details(task: &Task): (address, Option<address>, vector<u8>, u64, bool, bool, bool, u64) {
        (
            task.creator,
            task.assignee,
            task.description,
            task.reward,
            task.workSubmitted,
            task.verified,
            task.dispute,
            task.completion_deadline, // Include the deadline in the task details
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
                    completion_deadline: task.completion_deadline,
                };
                vector::push_back(&mut available_tasks, new_task);
            };
            i = i + 1;
        };
        available_tasks
    }

    // Training Module Functions

    // Create Training with initial escrow funding
    public entry fun create_training(description: vector<u8>, reward: u64, mut funding: Coin<SUI>, ctx: &mut TxContext) {
        assert!(coin::value(&funding) >= reward, EInsufficientEscrow);
        let training_id = object::new(ctx);
        let mut training = Training {
            id: training_id,
            creator: tx_context::sender(ctx),
            description: description,
            reward: reward,
            escrow: balance::zero(),
            completed: false,
            certified_users: vector::empty(),
        };
        balance::join(&mut training.escrow, coin::into_balance(funding)); // Fund the escrow
        transfer::share_object(training);
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
        task.completion_deadline = 0;
    }
}
