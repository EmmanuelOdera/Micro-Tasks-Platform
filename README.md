# Decentralized Micro Tasks System on Sui Blockchain

## Introduction

This project implements a decentralized micro-task system using the Sui blockchain. It features task creation, assignment, completion, verification, and dispute resolution functionalities. The smart contract is written in Sui Move, a language designed for secure and efficient blockchain applications.

## Overview

The Decentralized Micro Tasks System includes the following functionalities:

- **Task Management:** Create tasks, assign tasks, complete tasks, and verify task completions.
- **Dispute Resolution:** Handle disputes and resolve them.
- **Training Module:** Create training sessions, complete training, and certify users.

## Modules and Functions

### Task Management Module

This module handles the creation of tasks, assignment to workers, completion, verification, and reward release.

#### Task Structure

```move
struct Task has key, store {
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
```

#### Functions

- **create_task(description: vector<u8>, reward: u64, ctx: &mut TxContext):**

Creates a new task with the given description and reward.

```move
public entry fun create_task(description: vector<u8>, reward: u64, ctx: &mut TxContext)
```

- **assign_task(task: &mut Task, assignee: address, ctx: &mut TxContext):**

Assigns the specified task to a worker.

```move
public entry fun assign_task(task: &mut Task, assignee: address, ctx: &mut TxContext)
```

- **complete_task(task: &mut Task, completion_details: vector<u8>, ctx: &mut TxContext):**

Marks the task as completed by the assignee.

```move
public entry fun complete_task(task: &mut Task, completion_details: vector<u8>, ctx: &mut TxContext)
```

- **verify_task_completion(task: &mut Task, ctx: &mut TxContext):**

Verifies the completion of the task by the creator.

```move
public entry fun verify_task_completion(task: &mut Task, ctx: &mut TxContext)
```

- **release_reward(task: &mut Task, ctx: &mut TxContext):**

Releases the reward to the assignee upon successful completion and verification of the task.

```move
public entry fun release_reward(task: &mut Task, ctx: &mut TxContext)
```

- **dispute_task(task: &mut Task, ctx: &mut TxContext):**

Marks the task as disputed by the creator.

```move
public entry fun dispute_task(task: &mut Task, ctx: &mut TxContext)
```

- **resolve_dispute(task: &mut Task, resolved: bool, ctx: &mut TxContext):**

Resolves the dispute for the task, transferring the reward to the assignee if resolved in their favor, or back to the creator if not.

```move
public entry fun resolve_dispute(task: &mut Task, resolved: bool, ctx: &mut TxContext)
```

- **view_task_details(task: &Task): (address, Option<address>, vector<u8>, u64, bool, bool, bool):**

Returns the details of the specified task.

```move
public entry fun view_task_details(task: &Task): (address, Option<address>, vector<u8>, u64, bool, bool, bool)
```

- **list_available_tasks(tasks: &vector<Task>, ctx: &mut TxContext): vector<Task>:**

Lists all available tasks that are not yet assigned.

```move
public fun list_available_tasks(tasks: &vector<Task>, ctx: &mut TxContext): vector<Task>
```

### Training Module

This module handles the creation of training sessions, completion, and certification of users.

#### Training Structure

```move
struct Training has key, store {
    id: UID,
    creator: address,
    description: vector<u8>,
    reward: u64,
    escrow: Balance<SUI>,
    completed: bool,
    certified_users: vector<address>,
}
```

#### Functions

- **create_training(description: vector<u8>, reward: u64, ctx: &mut TxContext):**

Creates a new training session with the given description and reward.

```move
public entry fun create_training(description: vector<u8>, reward: u64, ctx: &mut TxContext)
```

- **complete_training(training: &mut Training, ctx: &mut TxContext):**

Marks the training session as completed.

```move
public entry fun complete_training(training: &mut Training, ctx: &mut TxContext)
```

- **certify_user(training: &mut Training, user: address, ctx: &mut TxContext):**

Certifies the specified user for the training session.

```move
public entry fun certify_user(training: &mut Training, user: address, ctx: &mut TxContext)
```

### Error Codes

- **EInvalidAssignment:** Invalid task assignment.
- **EInvalidCompletion:** Invalid task completion.
- **EDispute:** Task is disputed.
- **EAlreadyResolved:** Task dispute already resolved.
- **ENotCreatorOrAssignee:** Not the creator or assignee of the task.
- **EInvalidWithdrawal:** Invalid withdrawal attempt.

## Installation and Deployment

### Prerequisites

Ensure you have the following installed on your system:

- Rust and Cargo
- Sui binaries (for running a local network and interacting with the Sui blockchain)

### Install Rust and Cargo

```bash
curl https://sh.rustup.rs -sSf | sh
```

### Install Sui

#### Pre-built Binaries

```bash
./download-sui-binaries.sh "v1.18.0" "devnet" "ubuntu-x86_64"
```

#### Build from Source

```bash
cargo install --locked --git https://github.com/MystenLabs/sui.git --branch devnet sui
```

### Running a Local Network

```bash
RUST_LOG="off,sui_node=info" sui-test-validator
```

### Create Wallet and Addresses

Create a new address:

```bash
sui client new-address ed25519
```

### Get Localnet SUI Tokens

```bash
curl --location --request POST 'http://127.0.0.1:9123/gas' --header 'Content-Type: application/json' \
--data-raw '{
    "FixedAmountRequest": {
        "recipient": "<ADDRESS>"
    }
}'
```

### Build and Publish Smart Contract

Build the package:

```bash
sui move build
```

Publish the package:

```bash
sui client publish --gas-budget 100000000 --json
```

Extract and export the necessary IDs from the publish output.

---

This README provides an overview of the `decentralized_micro_tasks` system, including installation and deployment instructions. Make sure to follow the steps carefully to set up and interact with the Sui blockchain.
