# SQS Empty Receives Tracker

A cross-platform Bash script to report `NumberOfEmptyReceives` metrics for all SQS queues in a given AWS region. 

This metric tracks how often an SQS queue is polled but returns no messages—something that can increase AWS costs if done excessively, especially in Lambda and EC2 consumers. This tool helps identify inefficient polling and potential misconfigurations.

---

## Requirements

- Bash (works with Bash 3.2+, no associative arrays required)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) with credentials configured (via environment variables or AWS profiles)
- [jq](https://stedolan.github.io/jq/)

---

## Usage

```bash
./check_empty_receives.sh [-r region] [-d days] [-p profile]
```

### Options:

| Flag | Description |
|------|-------------|
| `-r` | AWS region (default: `us-west-2`) |
| `-d` | Number of days to check back (default: `1`) |
| `-p` | Optional AWS named profile to use |
| `-h` | Show usage help and exit |

### Example:

```bash
./check_empty_receives.sh -r us-east-1 -d 7 -p my-dev-profile
```

The script will print detailed metrics per queue and a CSV-style summary of total empty receives.

---

## Metric Handling Notes

The script automatically adjusts the CloudWatch `--period` argument to avoid exceeding AWS's 1,440 datapoint limit. For longer time ranges, it uses a coarser granularity (e.g., hourly or daily).

---

## Permissions Required

Your AWS IAM user or profile should have at least:

- `cloudwatch:GetMetricStatistics`
- `sqs:ListQueues`

---

## Platform Compatibility

- macOS (via Terminal, Zsh, or Homebrew-installed Bash)
- Windows (via WSL or Git Bash)
- Linux

---

## License

MIT — feel free to fork, modify, and use for commercial or personal projects.
