<?php
// Core PHP only: exercise Generic too, without adding pcntl to its contract.
declare(strict_types=1);

$directory = '/tmp/production-orphans';
if (!mkdir($directory, 0700) && !is_dir($directory)) {
    throw new RuntimeException('Cannot create fixture directory');
}
$batches = (int) ($argv[1] ?? 5);
$perBatch = (int) ($argv[2] ?? 40);
$snapshots = [];
$child = <<<'CHILD'
$pid = getmypid();
file_put_contents($argv[1] . '/.' . $pid . '.tmp', file_get_contents('/proc/self/stat'));
rename($argv[1] . '/.' . $pid . '.tmp', $argv[1] . '/' . $pid);
usleep(100000);
CHILD;

function state(string $record): ?array {
    // Strip the complete parenthesized comm before splitting numeric fields.
    if (preg_match('/^[0-9]+ \(.*\) (.*)$/s', trim($record), $match) !== 1) {
        return null; // /proc can disappear or return an empty read during reap.
    }
    $fields = explode(' ', $match[1]);
    if (count($fields) < 20) { return null; }
    return ['state' => $fields[0], 'ppid' => (int) $fields[1], 'starttime' => $fields[19]];
}

for ($batch = 1; $batch <= $batches; $batch++) {
    for ($i = 0; $i < $perBatch; $i++) {
        // The intermediate shell exits without waiting for background PHP.
        // proc_close reaps that shell, leaving only the orphan test children.
        $command = 'php -r ' . escapeshellarg($child) . ' ' . escapeshellarg($directory)
            . ' </dev/null >/dev/null 2>&1 &';
        $process = proc_open(['sh', '-c', $command], [
            0 => ['file', '/dev/null', 'r'], 1 => ['file', '/dev/null', 'w'],
            2 => ['file', '/dev/null', 'w'],
        ], $pipes);
        if (!is_resource($process) || proc_close($process) !== 0) {
            throw new RuntimeException('Cannot spawn orphan fixture');
        }
    }
    $deadline = microtime(true) + 15;
    do {
        $files = glob($directory . '/*');
        $live = 0;
        $zombies = [];
        foreach ($files as $file) {
            $pid = basename($file);
            $record = @file_get_contents('/proc/' . $pid . '/stat');
            if ($record === false) { continue; }
            $current = state($record);
            if ($current === null) { continue; }
            $original = state(file_get_contents($file));
            if ($original === null) { throw new RuntimeException('Incomplete child marker'); }
            if ($current['starttime'] !== $original['starttime']) { continue; }
            if ($current['state'] === 'Z') {
                $zombies[] = ['pid' => (int) $pid, 'ppid' => $current['ppid']];
            } else {
                $live++;
            }
        }
        if (count($files) >= $batch * $perBatch && $live === 0) { break; }
        usleep(50000);
    } while (microtime(true) < $deadline);
    if (count($files) !== $batch * $perBatch || $live !== 0) {
        throw new RuntimeException('Children did not complete: ' . count($files) . ', live=' . $live);
    }
    // Give the init time to reap after the child exit, then measure again next
    // iteration. The host also checks persistence with zombie-check.sh.
    $snapshots[] = ['batch' => $batch, 'created' => count($files), 'zombies' => $zombies];
}
file_put_contents('/tmp/production-orphan-report.tmp', json_encode([
    'controller_pid' => getmypid(), 'created' => $batches * $perBatch,
    'snapshots' => $snapshots,
], JSON_THROW_ON_ERROR));
rename('/tmp/production-orphan-report.tmp', '/tmp/production-orphan-report.json');
// Remain alive: namespace exit must not hide zombies in a long-lived worker.
while (true) { sleep(1); }
