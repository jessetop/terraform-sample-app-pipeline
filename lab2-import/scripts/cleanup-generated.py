#!/usr/bin/env python3
"""
cleanup-generated.py

Cleans up Terraform generated config by removing computed attributes,
null values, tags_all blocks, and empty blocks.

Usage: python3 cleanup-generated.py generated.tf > cleaned.tf
   or: python3 cleanup-generated.py generated.tf --in-place

What this script removes:
- tags_all blocks (computed from tags + default_tags)
- Attributes set to null
- Computed/read-only attributes (arn, id, owner_id, etc.)
- Empty blocks
- IPv6 attributes (not used in this lab)
"""

import re
import sys

# Computed attributes to remove
COMPUTED_ATTRS = [
    r'^\s+arn\s*=',
    r'^\s+id\s*=',
    r'^\s+owner_id\s*=',
    r'^\s+unique_id\s*=',
    r'^\s+main_route_table_id\s*=',
    r'^\s+default_network_acl_id\s*=',
    r'^\s+default_security_group_id\s*=',
    r'^\s+default_route_table_id\s*=',
    r'^\s+association_id\s*=',
    r'^\s+ipv6',
    r'^\s+assign_ipv6',
    r'^\s+enable_classiclink',
    r'^\s+enable_dns_hostnames\s*=\s*false',
    r'^\s+instance_tenancy\s*=\s*"default"',
]

def cleanup(content):
    lines = content.split('\n')
    result = []
    skip_until_closing_brace = False
    brace_depth = 0

    for line in lines:
        # Skip tags_all blocks
        if re.match(r'^\s+tags_all\s*=\s*\{', line):
            skip_until_closing_brace = True
            brace_depth = 1
            continue

        if skip_until_closing_brace:
            brace_depth += line.count('{') - line.count('}')
            if brace_depth <= 0:
                skip_until_closing_brace = False
            continue

        # Skip lines with = null
        if re.match(r'^\s+\w+\s*=\s*null\s*$', line):
            continue

        # Skip computed attributes
        skip = False
        for pattern in COMPUTED_ATTRS:
            if re.match(pattern, line):
                skip = True
                break
        if skip:
            continue

        result.append(line)

    # Collapse multiple blank lines
    output = '\n'.join(result)
    output = re.sub(r'\n{3,}', '\n\n', output)

    return output.strip() + '\n'

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 cleanup-generated.py <generated.tf> [--in-place]", file=sys.stderr)
        print("\nOutput goes to stdout by default. Use --in-place to modify the file.", file=sys.stderr)
        sys.exit(1)

    input_file = sys.argv[1]
    in_place = '--in-place' in sys.argv or '-i' in sys.argv

    try:
        with open(input_file, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found", file=sys.stderr)
        sys.exit(1)

    cleaned = cleanup(content)

    if in_place:
        with open(input_file, 'w') as f:
            f.write(cleaned)
        print(f"Cleaned {input_file} in place", file=sys.stderr)
    else:
        print(cleaned)

    # Print reminder
    print("\n=== Cleanup complete ===", file=sys.stderr)
    print("Manual steps still needed:", file=sys.stderr)
    print("  1. Replace hardcoded vpc_id with: aws_vpc.legacy.id", file=sys.stderr)
    print("  2. Replace hardcoded AMI with: data.aws_ami.amazon_linux_2023.id", file=sys.stderr)
    print("  3. Add lifecycle { prevent_destroy = true } to critical resources", file=sys.stderr)
    print("  4. Run: terraform plan", file=sys.stderr)

if __name__ == '__main__':
    main()
