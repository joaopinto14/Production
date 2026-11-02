#!/usr/bin/env python3
"""Read-only mapping of host zombie PIDs to Docker services and parent PIDs.

Run on the affected Docker host. No environment values or command arguments
are collected; services are never stopped, signalled or restarted.
"""
from collections import defaultdict
import subprocess


def docker(*args):
    return subprocess.check_output(["docker", *args], text=True).strip()


def main():
    total = 0
    containers = docker("ps", "--no-trunc", "--format", "{{.ID}}\t{{.Names}}\t{{.Image}}")
    for line in containers.splitlines():
        container, name, image = line.split("\t", 2)
        try:
            init_pid = int(docker("inspect", "--format", "{{.State.Pid}}", container))
            rows = docker("top", container, "-eo", "pid,ppid,stat,comm").splitlines()[1:]
        except subprocess.CalledProcessError:
            print(f"{name}: could not inspect (check Docker access or whether the container exited)")
            continue
        processes = {}
        for row in rows:
            pid, parent, state, command = row.split(None, 3)
            processes[int(pid)] = dict(parent=int(parent), state=state, command=command)
        groups = defaultdict(list)
        for pid, item in processes.items():
            if item["state"].startswith("Z"):
                groups[item["parent"]].append(pid)
        count = sum(map(len, groups.values()))
        total += count
        print(f"{name} ({image}): {count} zombie(s); container PID 1 = host PID {init_pid}")
        for parent, children in sorted(groups.items(), key=lambda item: -len(item[1]))[:20]:
            owner = processes.get(parent, {})
            kind = "container main process" if parent == init_pid else "parent inside container" if owner else "parent outside this process listing"
            print(f"  PPID {parent} [{owner.get('command', 'unknown')}, {owner.get('state', '?')}]: "
                  f"{len(children)} zombie(s), {kind}; sample PIDs {children[:5]}")
    print(f"Total inside running Docker containers: {total}")
    print("A snapshot does not prove persistence; repeat and compare parents. Zombies outside Docker are not included.")


if __name__ == "__main__":
    main()
