<?php
declare(strict_types=1);

function run(array $command): string {
    $process = proc_open($command, [0 => ['file', '/dev/null', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes);
    if (!is_resource($process)) {
        throw new RuntimeException('Cannot start Phar fixture command');
    }
    $stdout = stream_get_contents($pipes[1]);
    $stderr = stream_get_contents($pipes[2]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    if (proc_close($process) !== 0) {
        throw new RuntimeException('Phar fixture failed: ' . $stderr);
    }
    return $stdout;
}

if (!extension_loaded('Phar') || !class_exists(Phar::class)) {
    throw new RuntimeException('Phar extension/class missing');
}
if (Phar::canWrite()) {
    throw new RuntimeException('Default phar.readonly must remain enabled');
}

$path = sys_get_temp_dir() . '/production-' . bin2hex(random_bytes(6)) . '.phar';
$creator = <<<'PHP'
$archive = new Phar($argv[1]);
$archive->startBuffering();
$archive['main.php'] = '<?php echo "phar-execution-ok\n";';
$archive['payload.txt'] = 'phar-read-ok';
$archive->setStub(Phar::createDefaultStub('main.php'));
$archive->setSignatureAlgorithm(Phar::SHA256);
$archive->stopBuffering();
PHP;
try {
    // Only the fixture creator opts into writing; the image default stays on.
    run([PHP_BINARY, '-d', 'phar.readonly=0', '-r', $creator, $path]);
    $archive = new Phar($path);
    if (count($archive) !== 2 || file_get_contents('phar://' . $path . '/payload.txt') !== 'phar-read-ok') {
        throw new RuntimeException('Cannot read Phar archive contents');
    }
    if ($archive->getSignature()['hash_type'] !== 'SHA-256') {
        throw new RuntimeException('Unexpected Phar signature');
    }
    if (run([PHP_BINARY, $path]) !== "phar-execution-ok\n") {
        throw new RuntimeException('Cannot execute Phar archive');
    }
    echo "Phar archive read/execution passed; default readonly retained.\n";
} finally {
    if (is_file($path)) { unlink($path); }
}
