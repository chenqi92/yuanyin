import 'dart:typed_data';

import 'package:smb_connect/src/connect/impl/smb2/server_message_block2_response.dart';
import 'package:smb_connect/src/connect/impl/smb2/smb2_constants.dart';
import 'package:smb_connect/src/connect/smb_util.dart';
import 'package:smb_connect/src/utils/base.dart';

/// SMB2 ECHO Response
class Smb2EchoResponse extends ServerMessageBlock2Response {
  int _structureSize = 0;

  Smb2EchoResponse(super.config) : super(command: Smb2Constants.SMB2_ECHO);

  int get structureSize => _structureSize;

  @override
  @protected
  int readBytesWireFormat(Uint8List buffer, int bufferIndex) {
    // StructureSize (2 bytes) + Reserved (2 bytes) = 4 bytes
    _structureSize = SMBUtil.readInt2(buffer, bufferIndex);
    // Reserved at bufferIndex + 2
    return 4;
  }

  @override
  @protected
  int writeBytesWireFormat(Uint8List dst, int dstIndex) {
    // Response 不需要写入
    return 0;
  }
}
