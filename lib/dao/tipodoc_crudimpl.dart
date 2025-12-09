import 'package:myapp/dao/clientecrudimpl.dart';
import 'package:myapp/modelo/%20tipo_documento.dart';

class TipoDocCrudimpl {
  Future<List<TipoDocumento>> leerTipoDoc() async {
    try {
      final data = await supabase
          .from('tipo_documento')
          .select('*'); // ← sin tipo genérico

      if (data == null) {
        return [];
      }

      final List<Map<String, dynamic>> registros =
          (data as List).cast<Map<String, dynamic>>();

      return registros
          .map((mapa) => TipoDocumento.fromMap(mapa))
          .toList();

    } catch (e) {
      print('Error al leer los TipoDocumentos: $e');
      return [];
    }
  }
}

