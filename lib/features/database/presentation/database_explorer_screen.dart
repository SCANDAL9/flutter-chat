import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../../core/theme/umlstudio_tokens.dart';
import '../../../../core/theme/canvas_grid_painter.dart';
import '../../schema/domain/entity_descriptor.dart';
import '../../chat/presentation/chat_viewmodel.dart';

class DatabaseExplorerScreen extends StatefulWidget {
  const DatabaseExplorerScreen({super.key});

  @override
  State<DatabaseExplorerScreen> createState() => _DatabaseExplorerScreenState();
}

class _DatabaseExplorerScreenState extends State<DatabaseExplorerScreen> {
  // Caché de registros por entidad: Map<entityName, List<Map<String, dynamic>>>
  final Map<String, List<Map<String, dynamic>>> _tableData = {};
  final Map<String, bool> _isLoadingTable = {};
  final Map<String, String?> _tableErrors = {};
  final Set<String> _expandedTables = {};

  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<ChatViewModel>();
      _lastMessageCount = vm.messages.length;
      // Pre-cargar datos de la primera entidad si existe
      if (vm.entities.isNotEmpty) {
        _expandedTables.add(vm.entities.first.entityName);
        _fetchTableData(vm.entities.first);
      }
    });
  }

  Future<void> _fetchTableData(EntityDescriptor entity) async {
    final vm = context.read<ChatViewModel>();
    final baseUrl = vm.schemaRepo.baseUrl;
    final url = '$baseUrl/api/${entity.pluralRoute}';

    setState(() {
      _isLoadingTable[entity.entityName] = true;
      _tableErrors[entity.entityName] = null;
    });

    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
        setState(() {
          _tableData[entity.entityName] = list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          _isLoadingTable[entity.entityName] = false;
        });
      } else {
        setState(() {
          _tableErrors[entity.entityName] = "HTTP ${res.statusCode}";
          _isLoadingTable[entity.entityName] = false;
        });
      }
    } catch (e) {
      setState(() {
        _tableErrors[entity.entityName] = "Error de red: $e";
        _isLoadingTable[entity.entityName] = false;
      });
    }
  }

  Future<void> _refreshAllExpanded() async {
    final vm = context.read<ChatViewModel>();
    for (final entity in vm.entities) {
      if (_expandedTables.contains(entity.entityName)) {
        await _fetchTableData(entity);
      }
    }
  }

  EntityDescriptor? _findRelatedEntity(String fieldName, List<EntityDescriptor> allEntities) {
    final clean = fieldName.toLowerCase().replaceAll(RegExp(r'(_id|id)$'), '').trim();
    if (clean.isEmpty) return null;

    for (final ent in allEntities) {
      final eName = ent.entityName.toLowerCase();
      final rName = ent.pluralRoute.toLowerCase();
      if (eName == clean ||
          rName == clean ||
          rName == '${clean}s' ||
          rName == '${clean}es' ||
          clean.startsWith(eName) ||
          eName.startsWith(clean)) {
        return ent;
      }
    }
    return null;
  }

  Future<void> _deleteRecord(EntityDescriptor entity, dynamic id) async {
    final vm = context.read<ChatViewModel>();
    final baseUrl = vm.schemaRepo.baseUrl;
    final url = '$baseUrl/api/${entity.pluralRoute}/$id';

    try {
      final res = await http.delete(Uri.parse(url));
      if (res.statusCode == 200 || res.statusCode == 204) {
        final msg = "Registro de ${entity.entityName} con ID $id eliminado.";
        vm.ttsService.speak(msg);
        _showFeedback(msg, isSuccess: true);
        await _fetchTableData(entity);
      } else if (res.statusCode == 404 || res.statusCode == 500) {
        _showFeedback("El registro con ID $id no existe en el servidor.", isSuccess: false);
      } else {
        final err = "Error al eliminar: Código ${res.statusCode}";
        _showFeedback(err, isSuccess: false);
      }
    } catch (e) {
      _showFeedback("Error de conexión: $e", isSuccess: false);
    }
  }

  void _showFeedback(String message, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: isSuccess ? UmlStudioTokens.success : UmlStudioTokens.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UmlStudioTokens.radiusMd)),
      ),
    );
  }

  Future<void> _showCreateDialog(EntityDescriptor entity) async {
    final vm = context.read<ChatViewModel>();
    final formValues = <String, dynamic>{};
    final controllers = <String, TextEditingController>{};

    // Pre-cargar datos de entidades relacionadas para los dropdowns relacionales
    for (final field in entity.fields) {
      if (field.name.toLowerCase() == 'id') continue;
      final isFk = field.name.toLowerCase().endsWith('_id') ||
          (field.name.length > 2 && field.name.endsWith('Id'));
      if (isFk) {
        final rel = _findRelatedEntity(field.name, vm.entities);
        if (rel != null && !_tableData.containsKey(rel.entityName)) {
          await _fetchTableData(rel);
        }
      } else if (field.type == 'boolean') {
        formValues[field.name] = false;
      } else {
        controllers[field.name] = TextEditingController();
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          title: Row(
            children: [
              const Icon(Icons.add_circle_outline_rounded, color: UmlStudioTokens.deepSkyBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                "Nuevo ${entity.entityName}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: UmlStudioTokens.darkForeground),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: entity.fields.where((f) => f.name.toLowerCase() != 'id').map((field) {
                final isRequired = field.isRequired;
                final isNumeric = field.type == 'integer' || field.type == 'number';
                final isFk = field.name.toLowerCase().endsWith('_id') ||
                    (field.name.length > 2 && field.name.endsWith('Id'));
                final relEntity = isFk ? _findRelatedEntity(field.name, vm.entities) : null;
                final relRecords = relEntity != null ? (_tableData[relEntity.entityName] ?? []) : null;

                // 1. Selector relacional para claves foráneas (*_id)
                if (relEntity != null && relRecords != null && relRecords.isNotEmpty) {
                  final hasMatchingVal = relRecords.any((item) => item['id'] == formValues[field.name]);
                  final safeInitialVal = hasMatchingVal ? formValues[field.name] : null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: DropdownButtonFormField<dynamic>(
                      initialValue: safeInitialVal,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: "${field.name} (${relEntity.entityName})${isRequired ? ' *' : ''}",
                        labelStyle: TextStyle(
                          color: isRequired ? UmlStudioTokens.deepSkyBlue : UmlStudioTokens.darkTextMuted,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: UmlStudioTokens.dodgerBlue),
                        ),
                      ),
                      items: [
                        if (!isRequired)
                          const DropdownMenuItem<dynamic>(
                            value: null,
                            child: Text("(Sin selección)", style: TextStyle(color: UmlStudioTokens.darkTextMuted)),
                          ),
                        ...relRecords.map((item) {
                          final rId = item['id'];
                          final rLabel = item['nombre'] ?? item['name'] ?? item['title'] ?? item['email'] ?? "ID #$rId";
                          return DropdownMenuItem<dynamic>(
                            value: rId,
                            child: Text(
                              "$rLabel ($rId)",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          formValues[field.name] = val;
                        });
                      },
                    ),
                  );
                }

                // 2. Selector Booleano
                if (field.type == 'boolean') {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: DropdownButtonFormField<bool>(
                      initialValue: formValues[field.name] as bool? ?? false,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: "${field.name}${isRequired ? ' *' : ''}",
                        labelStyle: TextStyle(
                          color: isRequired ? UmlStudioTokens.deepSkyBlue : UmlStudioTokens.darkTextMuted,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: UmlStudioTokens.dodgerBlue),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem<bool>(value: true, child: Text("Verdadero (True)")),
                        DropdownMenuItem<bool>(value: false, child: Text("Falso (False)")),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          formValues[field.name] = val;
                        });
                      },
                    ),
                  );
                }

                // 3. Campo de texto estándar o número
                final ctrl = controllers.putIfAbsent(field.name, () => TextEditingController());
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: TextField(
                    controller: ctrl,
                    keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: "${field.name}${isRequired ? ' *' : ''}",
                      hintText: relEntity != null ? "ID de ${relEntity.entityName} (UUID o int)" : null,
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      labelStyle: TextStyle(
                        color: isRequired ? UmlStudioTokens.deepSkyBlue : UmlStudioTokens.darkTextMuted,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: UmlStudioTokens.dodgerBlue),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar", style: TextStyle(color: UmlStudioTokens.darkTextMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: UmlStudioTokens.dodgerBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                for (final f in entity.fields) {
                  if (f.name.toLowerCase() == 'id') continue;
                  if (f.isRequired) {
                    final isFk = f.name.toLowerCase().endsWith('_id') ||
                        (f.name.length > 2 && f.name.endsWith('Id'));
                    if (isFk && formValues[f.name] == null) {
                      _showFeedback("El campo '${f.name}' es obligatorio.", isSuccess: false);
                      return;
                    }
                    if (!isFk && f.type != 'boolean') {
                      final val = controllers[f.name]?.text.trim() ?? '';
                      if (val.isEmpty) {
                        _showFeedback("El campo '${f.name}' es obligatorio.", isSuccess: false);
                        return;
                      }
                    }
                  }
                }
                Navigator.pop(ctx, true);
              },
              child: const Text("Crear", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final payload = <String, dynamic>{};
      formValues.forEach((k, v) {
        if (v != null) payload[k] = v;
      });

      for (final entry in controllers.entries) {
        final val = entry.value.text.trim();
        if (val.isNotEmpty) {
          final field = entity.findField(entry.key);
          if (field?.type == 'integer') {
            payload[entry.key] = int.tryParse(val) ?? val;
          } else if (field?.type == 'number') {
            payload[entry.key] = double.tryParse(val) ?? val;
          } else {
            payload[entry.key] = val;
          }
        }
      }

      final baseUrl = vm.schemaRepo.baseUrl;
      final url = '$baseUrl/api/${entity.pluralRoute}';

      try {
        final res = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: utf8.encode(jsonEncode(payload)),
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          final msg = "${entity.entityName} creado exitosamente.";
          vm.ttsService.speak(msg);
          _showFeedback(msg, isSuccess: true);
          await _fetchTableData(entity);
        } else {
          _showFeedback("Error al crear: HTTP ${res.statusCode}", isSuccess: false);
        }
      } catch (e) {
        _showFeedback("Error de red: $e", isSuccess: false);
      }
    }
  }

  Future<void> _showEditDialog(EntityDescriptor entity, Map<String, dynamic> record) async {
    final vm = context.read<ChatViewModel>();
    final formValues = <String, dynamic>{};
    final controllers = <String, TextEditingController>{};

    for (final field in entity.fields) {
      if (field.name.toLowerCase() == 'id') continue;
      final isFk = field.name.toLowerCase().endsWith('_id') ||
          (field.name.length > 2 && field.name.endsWith('Id'));
      if (isFk) {
        formValues[field.name] = record[field.name];
        final rel = _findRelatedEntity(field.name, vm.entities);
        if (rel != null && !_tableData.containsKey(rel.entityName)) {
          await _fetchTableData(rel);
        }
      } else if (field.type == 'boolean') {
        formValues[field.name] = record[field.name] == true;
      } else {
        controllers[field.name] = TextEditingController(text: record[field.name]?.toString() ?? '');
      }
    }

    final id = record['id'];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: UmlStudioTokens.deepSkyBlue, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Editar ${entity.entityName} #$id",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: UmlStudioTokens.darkForeground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: entity.fields.where((f) => f.name.toLowerCase() != 'id').map((field) {
                final isNumeric = field.type == 'integer' || field.type == 'number';
                final isFk = field.name.toLowerCase().endsWith('_id') ||
                    (field.name.length > 2 && field.name.endsWith('Id'));
                final relEntity = isFk ? _findRelatedEntity(field.name, vm.entities) : null;
                final relRecords = relEntity != null ? (_tableData[relEntity.entityName] ?? []) : null;

                // 1. Selector relacional para claves foráneas (*_id)
                if (relEntity != null && relRecords != null && relRecords.isNotEmpty) {
                  final hasMatchingVal = relRecords.any((item) => item['id'] == formValues[field.name]);
                  final safeInitialVal = hasMatchingVal ? formValues[field.name] : null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: DropdownButtonFormField<dynamic>(
                      initialValue: safeInitialVal,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: "${field.name} (${relEntity.entityName})",
                        labelStyle: const TextStyle(color: UmlStudioTokens.darkTextMuted, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: UmlStudioTokens.dodgerBlue),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<dynamic>(
                          value: null,
                          child: Text("(Sin selección)", style: TextStyle(color: UmlStudioTokens.darkTextMuted)),
                        ),
                        ...relRecords.map((item) {
                          final rId = item['id'];
                          final rLabel = item['nombre'] ?? item['name'] ?? item['title'] ?? item['email'] ?? "ID #$rId";
                          return DropdownMenuItem<dynamic>(
                            value: rId,
                            child: Text(
                              "$rLabel ($rId)",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          formValues[field.name] = val;
                        });
                      },
                    ),
                  );
                }

                // 2. Selector Booleano
                if (field.type == 'boolean') {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: DropdownButtonFormField<bool>(
                      initialValue: formValues[field.name] as bool? ?? false,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: field.name,
                        labelStyle: const TextStyle(color: UmlStudioTokens.darkTextMuted, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: UmlStudioTokens.dodgerBlue),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem<bool>(value: true, child: Text("Verdadero (True)")),
                        DropdownMenuItem<bool>(value: false, child: Text("Falso (False)")),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          formValues[field.name] = val;
                        });
                      },
                    ),
                  );
                }

                // 3. Campo de texto estándar o número
                final ctrl = controllers.putIfAbsent(field.name, () => TextEditingController());
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: TextField(
                    controller: ctrl,
                    keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: field.name,
                      hintText: relEntity != null ? "ID de ${relEntity.entityName} (UUID o int)" : null,
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      labelStyle: const TextStyle(color: UmlStudioTokens.darkTextMuted, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: UmlStudioTokens.dodgerBlue),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar", style: TextStyle(color: UmlStudioTokens.darkTextMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: UmlStudioTokens.dodgerBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                for (final f in entity.fields) {
                  if (f.name.toLowerCase() == 'id') continue;
                  if (f.isRequired) {
                    final isFk = f.name.toLowerCase().endsWith('_id') ||
                        (f.name.length > 2 && f.name.endsWith('Id'));
                    if (isFk && formValues[f.name] == null) {
                      _showFeedback("El campo '${f.name}' es obligatorio.", isSuccess: false);
                      return;
                    }
                    if (!isFk && f.type != 'boolean') {
                      final val = controllers[f.name]?.text.trim() ?? '';
                      if (val.isEmpty) {
                        _showFeedback("El campo '${f.name}' es obligatorio.", isSuccess: false);
                        return;
                      }
                    }
                  }
                }
                Navigator.pop(ctx, true);
              },
              child: const Text("Guardar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && id != null) {
      final payload = <String, dynamic>{};
      formValues.forEach((k, v) {
        if (v != null) payload[k] = v;
      });

      for (final entry in controllers.entries) {
        final val = entry.value.text.trim();
        final field = entity.findField(entry.key);
        if (field?.type == 'integer') {
          payload[entry.key] = int.tryParse(val) ?? val;
        } else if (field?.type == 'number') {
          payload[entry.key] = double.tryParse(val) ?? val;
        } else {
          payload[entry.key] = val;
        }
      }

      final baseUrl = vm.schemaRepo.baseUrl;
      final url = '$baseUrl/api/${entity.pluralRoute}/$id';

      try {
        final res = await http.put(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: utf8.encode(jsonEncode(payload)),
        );
        if (res.statusCode == 200) {
          final msg = "Registro #$id de ${entity.entityName} actualizado.";
          vm.ttsService.speak(msg);
          _showFeedback(msg, isSuccess: true);
          await _fetchTableData(entity);
        } else {
          _showFeedback("Error al actualizar: HTTP ${res.statusCode}", isSuccess: false);
        }
      } catch (e) {
        _showFeedback("Error de red: $e", isSuccess: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChatViewModel>();

    // Detección reactiva de nuevos comandos de voz para refrescar las tablas sin salir de pantalla
    if (vm.messages.length > _lastMessageCount) {
      _lastMessageCount = vm.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshAllExpanded();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070A11), // Deepest Void Obsidian
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1322).withValues(alpha: 0.92),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: UmlStudioTokens.deepSkyBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Explorador de Base de Datos",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: UmlStudioTokens.darkForeground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "${vm.entities.length} Tablas detectadas (OpenAPI 3.0)",
              style: const TextStyle(fontSize: 11, color: UmlStudioTokens.darkTextMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet_rounded, color: UmlStudioTokens.deepSkyBlue, size: 21),
            tooltip: "Configurar Servidor",
            onPressed: () => _showServerConfigDialog(vm),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: UmlStudioTokens.deepSkyBlue, size: 22),
            tooltip: "Actualizar datos",
            onPressed: () {
              _refreshAllExpanded();
              _showFeedback("Datos actualizados desde el backend.", isSuccess: true);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Fondo de cuadrícula técnica
          Positioned.fill(
            child: Opacity(
              opacity: 0.65,
              child: CustomPaint(painter: CanvasGridPainter()),
            ),
          ),

          // Contenido principal de tablas colapsables
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: vm.entities.isEmpty
                      ? const Center(
                          child: Text(
                            "Sin entidades cargadas.\nConecta el backend para explorar las tablas.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: UmlStudioTokens.darkTextMuted, height: 1.5),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                          itemCount: vm.entities.length,
                          itemBuilder: (context, index) {
                            final entity = vm.entities[index];
                            return _buildEntityCard(entity);
                          },
                        ),
                ),
              ],
            ),
          ),

          // Muelle flotante con Atajo de Voz in-situ (no saca de la pantalla)
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: _buildInPlaceVoiceDock(vm),
          ),
        ],
      ),
    );
  }

  Future<void> _showServerConfigDialog(ChatViewModel vm) async {
    final controller = TextEditingController(text: vm.schemaRepo.baseUrl);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: const Row(
          children: [
            Icon(Icons.dns_rounded, color: UmlStudioTokens.deepSkyBlue, size: 20),
            SizedBox(width: 8),
            Text(
              "Servidor Backend",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Dirección base o puerto del backend Spring Boot:",
              style: TextStyle(fontSize: 12.5, color: UmlStudioTokens.darkTextMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "http://localhost:9000",
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar", style: TextStyle(color: UmlStudioTokens.darkTextMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UmlStudioTokens.dodgerBlue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Guardar y Conectar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await vm.updateBaseUrl(controller.text.trim());
      await _refreshAllExpanded();
      _showFeedback("Conectando con ${controller.text.trim()}...", isSuccess: true);
    }
  }

  Widget _buildEntityCard(EntityDescriptor entity) {
    final records = _tableData[entity.entityName] ?? [];
    final isLoading = _isLoadingTable[entity.entityName] ?? false;
    final error = _tableErrors[entity.entityName];
    final isExpanded = _expandedTables.contains(entity.entityName);

    return Material(
      color: const Color(0xFF0F172A).withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded ? UmlStudioTokens.dodgerBlue.withValues(alpha: 0.40) : Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedTables.add(entity.entityName);
                _fetchTableData(entity);
              } else {
                _expandedTables.remove(entity.entityName);
              }
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: UmlStudioTokens.dodgerBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.table_chart_rounded, size: 20, color: UmlStudioTokens.deepSkyBlue),
          ),
          title: Text(
            entity.entityName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          subtitle: Text(
            "/api/${entity.pluralRoute} • ${entity.fields.length} campos",
            style: const TextStyle(fontSize: 11.5, color: UmlStudioTokens.darkTextMuted),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: records.isNotEmpty ? UmlStudioTokens.success.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
                ),
                child: Text(
                  "${records.length} regs",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: records.isNotEmpty ? UmlStudioTokens.success : UmlStudioTokens.darkTextMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle_rounded, color: UmlStudioTokens.dodgerBlue, size: 22),
                tooltip: "Agregar registro",
                onPressed: () => _showCreateDialog(entity),
              ),
            ],
          ),
          children: [
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(UmlStudioTokens.deepSkyBlue),
                  ),
                ),
              )
            else if (error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(error, style: const TextStyle(color: UmlStudioTokens.danger, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text("Reintentar"),
                      onPressed: () => _fetchTableData(entity),
                    ),
                  ],
                ),
              )
            else if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  children: [
                    const Text(
                      "No hay registros en esta tabla.",
                      style: TextStyle(color: UmlStudioTokens.darkTextMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: UmlStudioTokens.dodgerBlue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 16, color: UmlStudioTokens.deepSkyBlue),
                      label: const Text("Crear Primer Registro", style: TextStyle(color: UmlStudioTokens.deepSkyBlue)),
                      onPressed: () => _showCreateDialog(entity),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Column(
                  children: records.map((record) => _buildRecordCard(entity, record)).toList(),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildRecordCard(EntityDescriptor entity, Map<String, dynamic> record) {
    final id = record['id'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131D30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: UmlStudioTokens.dodgerBlue.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "ID #$id",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: UmlStudioTokens.deepSkyBlue,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 19, color: UmlStudioTokens.deepSkyBlue),
                      tooltip: "Modificar",
                      padding: const EdgeInsets.all(8),
                      onPressed: () => _showEditDialog(entity, record),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: UmlStudioTokens.danger),
                      tooltip: "Eliminar",
                      padding: const EdgeInsets.all(8),
                      onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF0F172A),
                          title: const Text("Confirmar Eliminación", style: TextStyle(color: Colors.white)),
                          content: Text(
                            "¿Deseas eliminar el registro ID #$id de ${entity.entityName}?",
                            style: const TextStyle(color: UmlStudioTokens.darkTextMuted),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text("Cancelar", style: TextStyle(color: UmlStudioTokens.darkTextMuted)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: UmlStudioTokens.danger),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && id != null) {
                        await _deleteRecord(entity, id);
                      }
                    },
                  ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: record.entries
                .where((e) => e.key.toLowerCase() != 'id')
                .map((e) => RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "${e.key}: ",
                            style: const TextStyle(fontSize: 12, color: UmlStudioTokens.darkTextMuted),
                          ),
                          TextSpan(
                            text: "${e.value ?? 'null'}",
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInPlaceVoiceDock(ChatViewModel vm) {
    final isListening = vm.isListening;
    final isSpeaking = vm.isAssistantSpeaking;

    return ClipRRect(
      borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0B132B).withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
            border: Border.all(
              color: isListening
                  ? UmlStudioTokens.danger.withValues(alpha: 0.6)
                  : (isSpeaking ? UmlStudioTokens.success.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.15)),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Botón de micrófono reactivo
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
                  onTap: vm.toggleListening,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isListening
                            ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
                            : const [Color(0xFF38BDF8), Color(0xFF2563EB)],
                      ),
                    ),
                    child: Icon(
                      isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Texto de transcripción o sugerencia
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isListening
                          ? "Escuchando orden de voz..."
                          : (isSpeaking ? "Asistente respondiendo..." : "Comando de voz in-situ"),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isListening ? UmlStudioTokens.danger : (isSpeaking ? UmlStudioTokens.success : UmlStudioTokens.deepSkyBlue),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vm.currentPartialSpeech.isNotEmpty
                          ? "“${vm.currentPartialSpeech}”"
                          : (isListening
                              ? "Habla ahora (ej: 'eliminar ${vm.entities.isNotEmpty ? vm.entities.first.entityName.toLowerCase() : "registro"} 2')"
                              : "Toca el micro para editar/consultar con voz"),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
