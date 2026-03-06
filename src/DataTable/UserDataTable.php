<?php

namespace App\DataTable;

use App\Entity\User;
use Pentiminax\UX\DataTables\Attribute\AsDataTable;
use Pentiminax\UX\DataTables\Column\BooleanColumn;
use Pentiminax\UX\DataTables\Column\DateColumn;
use Pentiminax\UX\DataTables\Column\NumberColumn;
use Pentiminax\UX\DataTables\Column\TextColumn;
use Pentiminax\UX\DataTables\Model\AbstractDataTable;
use Pentiminax\UX\DataTables\Model\DataTable;

#[AsDataTable(User::class)]
final class UserDataTable extends AbstractDataTable
{
    public function configureDataTable(DataTable $table): DataTable
    {
        return $table
            ->serverSide()
            ->pageLength(25)
            ->searching()
            ->ordering()
            ->responsive();
    }

    public function configureColumns(): iterable
    {
        yield NumberColumn::new('id', 'ID')
            ->setWidth('80px')
            ->setOrderable(true);

        yield TextColumn::new('email', 'Email')
            ->setSearchable(true)
            ->setOrderable(true);

        yield BooleanColumn::new('isVerified', 'Verifie');

        yield TextColumn::new('roles', 'Roles')
            ->setSearchable(false);

        yield DateColumn::new('createdAt', 'Inscrit le')
            ->setFormat('d/m/Y H:i')
            ->setOrderable(true);
    }
}
