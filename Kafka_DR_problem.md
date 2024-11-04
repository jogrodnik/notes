# Kafka KRaft Mode Configuration Across Regions: `india1` and `india2`

When running Kafka in KRaft mode with controllers split across two regions, here `india1` and `india2`, challenges can arise if one region goes down, as controllers in each region will attempt to connect to the full list of controllers. If `india2` goes down, controllers in `india1` may fail to establish a quorum and start properly.

## Recommended Configuration

### 1. Use an Odd Number of Controllers and Keep Quorum in `india1`

To ensure resilience and avoid cross-region dependencies in the controller quorum:
- Deploy **an odd number of controllers (e.g., 3 or 5)** exclusively in `india1`. This setup allows `india1` to form a quorum independently if `india2` becomes unavailable.
- You can place backup (standby) controllers in `india2`, but **do not add them to the active controller quorum**. Standby controllers can remain inactive and used only if a manual failover is needed.

### 2. Dynamic Controller Reassignment with Quorum-Retaining Configuration

If maintaining controllers across `india1` and `india2` is required, consider:
- Keeping quorum controllers in `india1` for resilience.
- Configuring standby nodes in `india2` for redundancy, but only promote them to quorum members during a failover.

### 3. Controller Configuration for Fault Tolerance

Place all required quorum controllers in `india1` to ensure that the system maintains quorum if `india2` becomes unavailable. This setup prevents quorum loss and ensures controllers in `india1` can start independently. Use the `kafka-storage.sh` command to configure storage and initialize controllers only in `india1`.

### 4. Automate Failover for Controller Node Replacement

If you need redundancy, controllers in `india2` can be configured as failover nodes. Here’s an approach for failover:

1. **Stop `india1` Controllers** when a failover to `india2` is necessary.
2. **Reassign Controller Roles to `india2`** by reinitializing with `kafka-storage.sh`.
3. **Start Kafka in `india2`** to take over operations.

## Starting `india1` Controllers Without `india2`

If all controllers were previously started across both regions, follow these steps if `india1` controllers fail to start due to dependence on `india2`:

1. **Stop All Controllers in Both Regions** (`india1` and `india2`) to reset the quorum state.
2. **Reconfigure for `india1` Quorum**:
   - Update configuration files to remove `india2` controllers from the quorum setup.
   - Run `kafka-storage.sh format` to initialize storage without references to `india2`.
3. **Start Only `india1` Controllers** with the updated configuration.

By maintaining a quorum solely within `india1`, you allow controllers to establish quorum independently, providing a robust setup even if `india2` is unavailable.

This configuration approach ensures that your Kafka KRaft cluster is resilient, minimizes cross-region dependencies, and supports failover scenarios effectively.

