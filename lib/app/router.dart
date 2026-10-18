import 'package:go_router/go_router.dart';

import '../features/editor/editor_page.dart';
import '../features/settings/about_page.dart';
import '../features/settings/appearance_page.dart';
import '../features/settings/cloud_backup_page.dart';
import '../features/settings/mcp_audit_page.dart';
import '../features/settings/mcp_servers_page.dart';
import '../features/settings/model_group_edit_page.dart';
import '../features/settings/model_groups_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/skills_page.dart';
import '../features/settings/task_mapping_page.dart';
import '../features/settings/token_stats_page.dart';
import '../features/settings/trash_page.dart';
import '../features/stats/writing_stats_page.dart';
import '../features/work_detail/batch_summary_page.dart';
import '../features/work_detail/entity_extraction_page.dart';
import '../features/work_detail/import_page.dart';
import '../features/work_detail/inspirations_page.dart';
import '../features/work_detail/plot_plan_page.dart';
import '../features/work_detail/continuity_scan_page.dart';
import '../features/work_detail/relation_graph_page.dart';
import '../features/work_detail/replace_page.dart';
import '../features/work_detail/style_guide_page.dart';
import '../features/work_detail/work_chat_page.dart';
import '../features/work_detail/work_detail_page.dart';
import '../features/works/new_work_page.dart';
import '../features/works/works_page.dart';
import '../features/search/search_page.dart';

/// 路由表：作品列表 → 作品详情 → 编辑器（PRD 4.1 的层级导航），设置页独立入口。
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      name: 'works',
      builder: (context, state) => const WorksPage(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
      routes: <RouteBase>[
        GoRoute(
          path: 'model-groups',
          name: 'modelGroups',
          builder: (context, state) => const ModelGroupsPage(),
        ),
        GoRoute(
          path: 'model-groups/:groupId',
          name: 'modelGroupEdit',
          builder: (context, state) {
            final raw = state.pathParameters['groupId']!;
            return ModelGroupEditPage(
              groupId: raw == 'new' ? null : int.parse(raw),
            );
          },
        ),
        GoRoute(
          path: 'task-mapping',
          name: 'taskMapping',
          builder: (context, state) => const TaskMappingPage(),
        ),
        GoRoute(
          path: 'token-stats',
          name: 'tokenStats',
          builder: (context, state) => const TokenStatsPage(),
        ),
        GoRoute(
          path: 'mcp-servers',
          name: 'mcpServers',
          builder: (context, state) => const McpServersPage(),
        ),
        GoRoute(
          path: 'mcp-audit',
          name: 'mcpAudit',
          builder: (context, state) => const McpAuditPage(),
        ),
        GoRoute(
          path: 'mcp-servers/:serverId',
          name: 'mcpServerEdit',
          builder: (context, state) {
            final raw = state.pathParameters['serverId']!;
            return McpServerEditPage(
              serverId: raw == 'new' ? null : int.parse(raw),
            );
          },
        ),
        GoRoute(
          path: 'skills',
          name: 'skills',
          builder: (context, state) => const SkillsPage(),
        ),
        GoRoute(
          path: 'skills/:skillId',
          name: 'skillEdit',
          builder: (context, state) {
            final raw = state.pathParameters['skillId']!;
            return SkillEditPage(skillId: raw == 'new' ? null : int.parse(raw));
          },
        ),
        GoRoute(
          path: 'appearance',
          name: 'appearance',
          builder: (context, state) => const AppearancePage(),
        ),
        GoRoute(
          path: 'writing-stats',
          name: 'writingStats',
          builder: (context, state) => const WritingStatsPage(),
        ),
        GoRoute(
          path: 'cloud-backup',
          name: 'cloudBackup',
          builder: (context, state) => const CloudBackupPage(),
        ),
        GoRoute(
          path: 'trash',
          name: 'trash',
          builder: (context, state) => const TrashPage(),
        ),
        GoRoute(
          path: 'about',
          name: 'about',
          builder: (context, state) => const AboutPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/new-work',
      name: 'newWork',
      builder: (context, state) => const NewWorkPage(),
    ),
    GoRoute(
      path: '/search',
      name: 'search',
      builder: (context, state) => const SearchPage(),
    ),
    GoRoute(
      path: '/work/:workId',
      name: 'workDetail',
      builder: (context, state) =>
          WorkDetailPage(workId: int.parse(state.pathParameters['workId']!)),
      routes: <RouteBase>[
        GoRoute(
          path: 'chapter/:chapterId',
          name: 'editor',
          builder: (context, state) => EditorPage(
            workId: int.parse(state.pathParameters['workId']!),
            chapterId: int.parse(state.pathParameters['chapterId']!),
            checkStart: int.tryParse(
              state.uri.queryParameters['checkStart'] ?? '',
            ),
            checkEnd: int.tryParse(state.uri.queryParameters['checkEnd'] ?? ''),
          ),
        ),
        GoRoute(
          path: 'inspirations',
          name: 'inspirations',
          builder: (context, state) => InspirationsPage(
            workId: int.parse(state.pathParameters['workId']!),
          ),
        ),
        GoRoute(
          path: 'import',
          name: 'import',
          builder: (context, state) =>
              ImportPage(workId: int.parse(state.pathParameters['workId']!)),
        ),
        GoRoute(
          path: 'relations',
          name: 'relations',
          builder: (context, state) => RelationGraphPage(
            workId: int.parse(state.pathParameters['workId']!),
          ),
        ),
        GoRoute(
          path: 'replace',
          name: 'workReplace',
          builder: (context, state) => WorkReplacePage(
            workId: int.parse(state.pathParameters['workId']!),
          ),
        ),
        GoRoute(
          path: 'style',
          name: 'workStyle',
          builder: (context, state) => StyleGuidePage(
            workId: int.parse(state.pathParameters['workId']!),
          ),
        ),
        GoRoute(
          path: 'extract',
          name: 'workExtract',
          builder: (context, state) => EntityExtractionPage(
            workId: int.parse(state.pathParameters['workId']!),
          ),
        ),
        GoRoute(
          path: 'plot',
          name: 'workPlot',
          builder: (context, state) =>
              PlotPlanPage(workId: int.parse(state.pathParameters['workId']!)),
        ),
        GoRoute(
          path: 'summaries',
          name: 'workSummaries',
          builder: (context, state) => BatchSummaryPage(
            workId: int.parse(state.pathParameters['workId']!),
          ),
        ),
        GoRoute(
          path: 'chat',
          name: 'workChat',
          builder: (context, state) =>
              WorkChatPage(workId: int.parse(state.pathParameters['workId']!)),
        ),
        GoRoute(
          path: 'continuity',
          name: 'workContinuity',
          builder: (context, state) => ContinuityScanPage(
            workId: int.parse(state.pathParameters['workId']!),
          ),
        ),
      ],
    ),
  ],
);
