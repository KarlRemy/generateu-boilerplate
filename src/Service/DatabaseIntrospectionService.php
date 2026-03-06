<?php

namespace App\Service;

use Doctrine\DBAL\Connection;
use Doctrine\DBAL\Schema\AbstractSchemaManager;

class DatabaseIntrospectionService
{
    private AbstractSchemaManager $schemaManager;

    public function __construct(
        private readonly Connection $connection,
    ) {
        $this->schemaManager = $this->connection->createSchemaManager();
    }

    /** @return array<array{name: string, rows: int}> */
    public function listTables(): array
    {
        $tables = [];
        foreach ($this->schemaManager->listTableNames() as $tableName) {
            $count = (int) $this->connection->executeQuery(
                \sprintf('SELECT COUNT(*) FROM %s', $this->connection->quoteIdentifier($tableName))
            )->fetchOne();

            $tables[] = [
                'name' => $tableName,
                'rows' => $count,
            ];
        }

        usort($tables, fn($a, $b) => $a['name'] <=> $b['name']);
        return $tables;
    }

    /** @return array{columns: array, rows: array} */
    public function getTableData(string $tableName, int $limit = 100): array
    {
        // Validate table exists
        $existingTables = $this->schemaManager->listTableNames();
        if (!in_array($tableName, $existingTables, true)) {
            throw new \InvalidArgumentException(\sprintf('Table "%s" does not exist.', $tableName));
        }

        $columns = [];
        foreach ($this->schemaManager->listTableColumns($tableName) as $column) {
            $columns[] = [
                'name' => $column->getName(),
                'type' => $column->getType()->getName(),
                'nullable' => !$column->getNotnull(),
            ];
        }

        $rows = $this->connection->executeQuery(
            \sprintf(
                'SELECT * FROM %s ORDER BY 1 DESC LIMIT %d',
                $this->connection->quoteIdentifier($tableName),
                $limit
            )
        )->fetchAllAssociative();

        return [
            'columns' => $columns,
            'rows' => $rows,
        ];
    }
}
