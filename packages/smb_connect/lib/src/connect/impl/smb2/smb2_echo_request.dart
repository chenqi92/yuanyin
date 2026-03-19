import 'dart:typed_data';

import 'package:smb_connect/src/configuration.dart';
import 'package:smb_connect/src/connect/impl/smb2/server_message_block2.dart';
import 'package:smb_connect/src/connect/impl/smb2/server_message_block2_request.dart';
import 'package:smb_connect/src/connect/impl/smb2/smb2_constants.dart';
import 'package:smb_connect/src/connect/impl/smb2/smb2_echo_response.dart';
import 'package:smb_connect/src/connect/smb_util.dart';
import 'package:smb_connect/src/utils/base.dart';

/// SMB2 ECHO Request
///
/// 用于检测连接是否仍然有效（心跳）
class Smb2EchoRequest extends ServerMessageBlock2Request<Smb2EchoResponse> {
  Smb2EchoRequest(super.config) : super(command: Smb2Constants.SMB2_ECHO);

  @override
  @protected
  Smb2EchoResponse createResponse(
      Configuration config, ServerMessageBlock2Request<Smb2EchoResponse> req) {
    return Smb2EchoResponse(config);
  }

  @override
  int size() {
    // SMB2 ECHO Request: StructureSize (2 bytes) + Reserved (2 bytes) = 4 bytes
    return ServerMessageBlock2.size8(Smb2Constants.SMB2_HEADER_LENGTH + 4);
  }

  @override
  @protected
  int writeBytesWireFormat(Uint8List dst, int dstIndex) {
    // StructureSize: 4
    SMBUtil.writeInt2(4, dst, dstIndex);
    // Reserved: 0
    SMBUtil.writeInt2(0, dst, dstIndex + 2);
    return 4;
  }

  @override
  @protected
  int readBytesWireFormat(Uint8List buffer, int bufferIndex) {
    return 0;
  }
}
