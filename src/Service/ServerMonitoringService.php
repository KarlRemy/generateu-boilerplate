<?php

namespace App\Service;

use Doctrine\DBAL\Connection;
use Symfony\Component\HttpKernel\Kernel;

class ServerMonitoringService
{
    public function __construct(
        private readonly Connection $connection,
        private readonly string $mercureUrl = '',
    ) {
    }

    public function getServerInfo(): array
    {
        return [
            'php_version' => PHP_VERSION,
            'symfony_version' => Kernel::VERSION,
            'php_sapi' => PHP_SAPI,
            'os' => PHP_OS,
            'extensions' => get_loaded_extensions(),
        ];
    }

    public function getMemoryInfo(): array
    {
        return [
            'usage' => $this->formatBytes(memory_get_usage(true)),
            'peak' => $this->formatBytes(memory_get_peak_usage(true)),
            'limit' => ini_get('memory_limit'),
        ];
    }

    public function getDiskInfo(): array
    {
        $path = '/';
        return [
            'free' => $this->formatBytes((int) disk_free_space($path)),
            'total' => $this->formatBytes((int) disk_total_space($path)),
            'used_percent' => round((1 - disk_free_space($path) / disk_total_space($path)) * 100, 1),
        ];
    }

    public function getUptime(): string
    {
        if (PHP_OS_FAMILY === 'Linux') {
            $uptime = @file_get_contents('/proc/uptime');
            if ($uptime !== false) {
                $seconds = (int) explode(' ', $uptime)[0];
                return $this->formatDuration($seconds);
            }
        }

        $result = @shell_exec('uptime -p 2>/dev/null');
        return $result ? trim($result) : 'N/A';
    }

    public function getServiceStatuses(): array
    {
        return [
            'postgresql' => $this->checkPostgresql(),
            'mercure' => $this->checkMercure(),
            'mailer' => $this->checkMailer(),
        ];
    }

    private function checkPostgresql(): array
    {
        try {
            $this->connection->executeQuery('SELECT 1');
            $version = $this->connection->executeQuery('SELECT version()')->fetchOne();
            return ['status' => 'ok', 'details' => $version];
        } catch (\Throwable $e) {
            return ['status' => 'error', 'details' => $e->getMessage()];
        }
    }

    private function checkMercure(): array
    {
        if (empty($this->mercureUrl)) {
            return ['status' => 'not_configured', 'details' => 'MERCURE_URL non definie'];
        }

        return ['status' => 'configured', 'details' => $this->mercureUrl];
    }

    private function checkMailer(): array
    {
        $dsn = $_ENV['MAILER_DSN'] ?? 'null://null';
        if ($dsn === 'null://null') {
            return ['status' => 'disabled', 'details' => 'Mailer desactive'];
        }
        return ['status' => 'configured', 'details' => preg_replace('/\/\/.*@/', '//*****@', $dsn)];
    }

    private function formatBytes(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        $i = 0;
        $size = (float) $bytes;
        while ($size >= 1024 && $i < count($units) - 1) {
            $size /= 1024;
            $i++;
        }
        return round($size, 2) . ' ' . $units[$i];
    }

    private function formatDuration(int $seconds): string
    {
        $days = intdiv($seconds, 86400);
        $hours = intdiv($seconds % 86400, 3600);
        $minutes = intdiv($seconds % 3600, 60);

        $parts = [];
        if ($days > 0) $parts[] = $days . 'j';
        if ($hours > 0) $parts[] = $hours . 'h';
        $parts[] = $minutes . 'min';

        return implode(' ', $parts);
    }
}
