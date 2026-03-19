import 'dart:typed_data';

import 'package:smb_connect/src/configuration.dart';
import 'package:smb_connect/src/connect/common/request.dart';
import 'package:smb_connect/src/connect/impl/smb1/server_message_block.dart';
import 'package:smb_connect/src/connect/impl/smb1/smb_com_constants.dart';
import 'package:smb_connect/src/connect/smb_util.dart';
import 'package:smb_connect/src/utils/base.dart';

/// SMB_COM_ECHO Response
class SmbComEchoResponse extends ServerMessageBlock {
  int sequenceNumber = 0;

  SmbComEchoResponse(super.config)
      : super(command: SmbComConstants.SMB_COM_ECHO);

  @override
  @protected
  int readParameterWordsWireFormat(Uint8List buffer, int bufferIndex) {
    sequenceNumber = SMBUtil.readInt2(buffer, bufferIndex);
    return 2;
  }

  @override
  @protected
  int readBytesWireFormat(Uint8List buffer, int bufferIndex) {
    // Echo data - we don't need to read it
    return byteCount;
  }

  @override
  @protected
  int writeParameterWordsWireFormat(Uint8List dst, int dstIndex) => 0;

  @override
  @protected
  int writeBytesWireFormat(Uint8List dst, int dstIndex) => 0;
}

/// SMB_COM_ECHO Request
///
/// 用于检测连接是否仍然有效（心跳）
class SmbComEcho extends ServerMessageBlock implements Request<SmbComEchoResponse> {
  final int _echoCount;
  final Uint8List? _echoData;

  SmbComEcho(super.config, {int echoCount = 1, Uint8List? echoData})
      : _echoCount = echoCount,
        _echoData = echoData,
        super(command: SmbComConstants.SMB_COM_ECHO);

  @override
  SmbComEchoResponse getResponse() {
    return super.getResponse() as SmbComEchoResponse;
  }

  @override
  SmbComEchoResponse initResponse(Configuration config) {
    SmbComEchoResponse resp = SmbComEchoResponse(config);
    setResponse(resp);
    return resp;
  }

  @override
  @protected
  int writeParameterWordsWireFormat(Uint8List dst, int dstIndex) {
    // EchoCount: 2 bytes
    SMBUtil.writeInt2(_echoCount, dst, dstIndex);
    return 2;
  }

  @override
  @protected
  int writeBytesWireFormat(Uint8List dst, int dstIndex) {
    if (_echoData != null && _echoData.isNotEmpty) {
      dst.setRange(dstIndex, dstIndex + _echoData.length, _echoData);
      return _echoData.length;
    }
    return 0;
  }

  @override
  @protected
  int readParameterWordsWireFormat(Uint8List buffer, int bufferIndex) => 0;

  @override
  @protected
  int readBytesWireFormat(Uint8List buffer, int bufferIndex) => 0;

  @override
  String toString() {
    return "SmbComEcho[${super.toString()},echoCount=$_echoCount]";
  }
}
