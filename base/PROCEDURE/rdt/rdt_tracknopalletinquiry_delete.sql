SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: rdt_TrackNoPalletInquiry_Delete                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-03-20 1.0  Ung      WMS-4225 Created                                  */
/* 2020-10-16 1.1  James    WMS-15062 Add custom delete sp (james01)          */
/* 2022-10-17 1.2  Ung      WMS-20952 Add PalletDetailTrackingNo              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_TrackNoPalletInquiry_Delete] (
   @nMobile           INT,
   @nFunc             INT,
   @cLangCode         NVARCHAR( 3),
   @nStep             INT,
   @nInputKey         INT,
   @cFacility         NVARCHAR( 5),
   @cStorerKey        NVARCHAR( 15),
   @cPalletKey        NVARCHAR( 20),
   @cMBOLKey          NVARCHAR( 10),
   @cTrackNo          NVARCHAR( 20),
   @nErrNo            INT            OUTPUT,
   @cErrMsg           NVARCHAR( 20)  OUTPUT 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cDeleteSP   NVARCHAR( 20)

   -- Get storer config
   SET @cDeleteSP = rdt.RDTGetConfig( @nFunc, 'DeleteSP', @cStorerKey)
   IF @cDeleteSP = '0'
      SET @cDeleteSP = ''

   /***********************************************************************************************
                                              Custom Delete
   ***********************************************************************************************/
   -- Check confirm SP blank
   IF @cDeleteSP <> ''
   BEGIN
      -- Confirm SP
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cDeleteSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cPalletKey, @cMBOLKey, @cTrackNo, ' +
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
      SET @cSQLParam =
         ' @nMobile        INT,           ' +
         ' @nFunc          INT,           ' +
         ' @cLangCode      NVARCHAR( 3),  ' +
         ' @nStep          INT,           ' +
         ' @nInputKey      INT,           ' +
         ' @cFacility      NVARCHAR( 5) , ' +
         ' @cStorerKey     NVARCHAR( 15), ' +
         ' @cPalletKey     NVARCHAR( 20), ' +
         ' @cMBOLKey       NVARCHAR( 10), ' +
         ' @cTrackNo       NVARCHAR( 20), ' +
         ' @nErrNo         INT           OUTPUT, ' +
         ' @cErrMsg        NVARCHAR(250) OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cPalletKey, @cMBOLKey, @cTrackNo,
         @nErrNo OUTPUT, @cErrMsg OUTPUT

      GOTO Exit_SP
   END

   /***********************************************************************************************
                                              Standard Delete
   ***********************************************************************************************/

   DECLARE @cOrderKey NVARCHAR( 10)
   DECLARE @cSOStatus NVARCHAR( 10)
   DECLARE @cUDF04    NVARCHAR( 20)
   DECLARE @cPHStatus NVARCHAR( 10)
   DECLARE @cPDStatus NVARCHAR( 10)
   DECLARE @cPDLineNo NVARCHAR( 5)
   DECLARE @cPalletDetailTrackingNo NVARCHAR( 1)
   
   SET @cPalletDetailTrackingNo = rdt.rdtGetConfig( @nFunc, 'PalletDetailTrackingNo', @cStorerKey)

   -- Get carton info
   IF @cPalletDetailTrackingNo = '1'
      SELECT
         @cOrderKey = PD.UserDefine01,
         @cPDStatus = PD.Status,
         @cPDLineNo = PD.PalletLineNumber
      FROM PalletDetail PD WITH (NOLOCK)
         JOIN CartonTrack CT WITH (NOLOCK) ON (PD.TrackingNo = CT.TrackingNo)
      WHERE PD.PalletKey = @cPalletKey
         AND PD.TrackingNo = @cTrackNo
   ELSE
      SELECT
         @cOrderKey = PD.UserDefine01,
         @cPDStatus = PD.Status,
         @cPDLineNo = PD.PalletLineNumber
      FROM PalletDetail PD WITH (NOLOCK)
         JOIN CartonTrack CT WITH (NOLOCK) ON (PD.CaseID = CT.TrackingNo)
      WHERE PD.PalletKey = @cPalletKey
         AND PD.CaseID = @cTrackNo

   -- Get pallet info
   SELECT @cPHStatus = Status FROM Pallet WITH (NOLOCK) WHERE PalletKey = @cPalletKey

   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_TrackNoPalletInquiry_Delete -- For rollback or commit only our own transaction

   -- Reopen pallet
   IF @cPHStatus = '9'
   BEGIN
      UPDATE Pallet SET
         Status = '0',
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME(),
         TrafficCop = NULL
      WHERE PalletKey = @cPalletKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 121501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PLDtl Fail
         GOTO RollbackTran
      END

      IF @cPDStatus = '9'
      BEGIN
         UPDATE PalletDetail SET
            Status = '0',
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME(),
            TrafficCop = NULL
         WHERE PalletKey = @cPalletKey
            AND PalletLineNumber = @cPDLineNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 121502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PLDtl Fail
            GOTO RollbackTran
         END
      END
   END

   -- PalletDetail
   DELETE PalletDetail WHERE PalletKey = @cPalletKey AND PalletLineNumber = @cPDLineNo
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 121503
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL PLDtl Fail
      GOTO RollbackTran
   END

   -- Close back the pallet
   IF @cPHStatus = '9'
   BEGIN
      UPDATE Pallet SET
         Status = '9',
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME(),
         TrafficCop = NULL
      WHERE PalletKey = @cPalletKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 121504
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PLDtl Fail
         GOTO RollbackTran
      END
   END

   -- MBOLDetail
   -- Order with multi carton, delete MBOLDetail also. It will be blocked at scan to container module
   IF EXISTS( SELECT 1 FROM MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)
   BEGIN
      DELETE MBOLDetail WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 121505
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL MBDtl Fail
         GOTO RollbackTran
      END
   END

   COMMIT TRAN rdt_TrackNoPalletInquiry_Delete

   DECLARE @cUserName NVARCHAR(10)
   SET @cUserName = LEFT( SUSER_SNAME(), 10)

   -- Eventlog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '3', --
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @cRefNo1     = @cMBOLKey,
      -- @cRefNo2     = @cLoadKey,
      @cRefNo3     = @cOrderKey,
      @cRefNo4     = @cTrackNo

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_TrackNoPalletInquiry_Delete -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

Exit_SP:

END

GO