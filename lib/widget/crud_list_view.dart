import 'package:flutter/material.dart';
import 'package:myapp/widget/responsive.dart';

/// Describes one column of a [CrudListView]: how to label it and how to
/// render a cell for a given item. On mobile, the column marked [isTitle]
/// becomes the accordion header (falls back to the first column), the one
/// marked [isSubtitle] becomes the header subtitle, and the rest are shown
/// as label/value rows inside the expanded body.
class CrudColumn<T> {
  final String label;
  final Widget Function(T item) cellBuilder;
  final bool isTitle;
  final bool isSubtitle;

  const CrudColumn({
    required this.label,
    required this.cellBuilder,
    this.isTitle = false,
    this.isSubtitle = false,
  });
}

/// Renders [items] as a [DataTable] on wide screens and as a list of
/// [ExpansionTile]s on narrow ones, sharing the loading/empty states and the
/// edit/delete actions between both layouts. Search, filtering and the
/// add/refresh controls stay in the calling screen and are passed in as
/// [toolbar].
class CrudListView<T> extends StatelessWidget {
  final List<T> items;
  final List<CrudColumn<T>> columns;
  final bool isLoading;
  final IconData emptyIcon;
  final String emptyText;
  final void Function(T item)? onEdit;
  final void Function(T item)? onDelete;
  final Widget? toolbar;

  /// Extra per-row action buttons rendered before edit/delete, for screens
  /// with actions beyond the standard edit/delete pair.
  final List<Widget> Function(T item)? extraActions;

  const CrudListView({
    super.key,
    required this.items,
    required this.columns,
    required this.isLoading,
    required this.emptyIcon,
    required this.emptyText,
    this.onEdit,
    this.onDelete,
    this.toolbar,
    this.extraActions,
  });

  bool get _hasActions => onEdit != null || onDelete != null || extraActions != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (toolbar != null) ...[
          toolbar!,
          const SizedBox(height: 24),
        ],
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              emptyText,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return isMobile(constraints.maxWidth) ? _buildMobileList() : _buildTable();
      },
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
          columns: [
            for (final column in columns) DataColumn(label: Text(column.label)),
            if (_hasActions) const DataColumn(label: Text('Acciones')),
          ],
          rows: items.map((item) {
            return DataRow(
              cells: [
                for (final column in columns) DataCell(column.cellBuilder(item)),
                if (_hasActions) DataCell(_buildActions(item)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActions(T item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (extraActions != null) ...extraActions!(item),
        if (onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF0085FF)),
            onPressed: () => onEdit!(item),
            tooltip: 'Editar',
          ),
        if (onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            onPressed: () => onDelete!(item),
            tooltip: 'Eliminar',
          ),
      ],
    );
  }

  Widget _buildMobileList() {
    CrudColumn<T>? titleColumn;
    CrudColumn<T>? subtitleColumn;
    for (final column in columns) {
      if (column.isTitle && titleColumn == null) titleColumn = column;
      if (column.isSubtitle && subtitleColumn == null) subtitleColumn = column;
    }
    titleColumn ??= columns.first;
    final detailColumns = columns.where(
      (c) => c != titleColumn && c != subtitleColumn,
    );

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ExpansionTile(
            title: titleColumn!.cellBuilder(item),
            subtitle: subtitleColumn?.cellBuilder(item),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              for (final column in detailColumns)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          column.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Expanded(child: column.cellBuilder(item)),
                    ],
                  ),
                ),
              if (_hasActions)
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildActions(item),
                ),
            ],
          ),
        );
      },
    );
  }
}
