<?php

namespace App\Controller\Admin;

use App\DataTable\UserDataTable;
use App\Repository\UserRepository;
use App\Service\DatabaseIntrospectionService;
use App\Service\ServerMonitoringService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/admin')]
class AdminDashboardController extends AbstractController
{
    #[Route('', name: 'app_admin_dashboard')]
    public function dashboard(
        ServerMonitoringService $monitoring,
        UserRepository $userRepository,
    ): Response {
        return $this->render('admin/dashboard.html.twig', [
            'server' => $monitoring->getServerInfo(),
            'memory' => $monitoring->getMemoryInfo(),
            'disk' => $monitoring->getDiskInfo(),
            'uptime' => $monitoring->getUptime(),
            'services' => $monitoring->getServiceStatuses(),
            'recent_users' => $userRepository->findRecentRegistrations(10),
        ]);
    }

    #[Route('/users', name: 'app_admin_users')]
    public function users(Request $request, UserDataTable $dataTable): Response
    {
        $dataTable->handleRequest($request);

        if ($dataTable->isRequestHandled()) {
            return $dataTable->getResponse();
        }

        return $this->render('admin/users/index.html.twig', [
            'datatable' => $dataTable,
        ]);
    }

    #[Route('/tables', name: 'app_admin_tables')]
    public function tables(DatabaseIntrospectionService $db): Response
    {
        return $this->render('admin/tables/index.html.twig', [
            'tables' => $db->listTables(),
        ]);
    }

    #[Route('/tables/{tableName}', name: 'app_admin_table_show')]
    public function tableShow(string $tableName, DatabaseIntrospectionService $db): Response
    {
        try {
            $data = $db->getTableData($tableName);
        } catch (\InvalidArgumentException $e) {
            throw $this->createNotFoundException($e->getMessage());
        }

        return $this->render('admin/tables/show.html.twig', [
            'table_name' => $tableName,
            'columns' => $data['columns'],
            'rows' => $data['rows'],
        ]);
    }
}
