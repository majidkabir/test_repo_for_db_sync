SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1665DeleteSP01                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2020-10-16 1.0  James    WMS-15062 Created                                 */
/* 2022-10-17 1.1  Ung      WMS-20952 Add PalletDetailTrackingNo              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1665DeleteSP01] (
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
         @cOrderKey = UserDefine01,
         @cPDStatus = Status,
         @cPDLineNo = PalletLineNumber
      FROM PalletDetail WITH (NOLOCK)
      WHERE PalletKey = @cPalletKey
         AND TrackingNo = @cTrackNo
   ELSE
      SELECT
         @cOrderKey = UserDefine01,
         @cPDStatus = Status,
         @cPDLineNo = PalletLineNumber
      FROM PalletDetail WITH (NOLOCK)
      WHERE PalletKey = @cPalletKey
         AND CaseID = @cTrackNo
         
   -- Get pallet info
   SELECT @cPHStatus = Status FROM Pallet WITH (NOLOCK) WHERE PalletKey = @cPalletKey

   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1665DeleteSP01 -- For rollback or commit only our own transaction

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
         SET @nErrNo = 160001
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
            SET @nErrNo = 160002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PLDtl Fail
            GOTO RollbackTran
         END
      END
   END

   -- PalletDetail
   DELETE PalletDetail WHERE PalletKey = @cPalletKey AND PalletLineNumber = @cPDLineNo
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 160003
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
         SET @nErrNo = 160004
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
         SET @nErrNo = 160005
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL MBDtl Fail
         GOTO RollbackTran
      END
   END

   COMMIT TRAN rdt_1665DeleteSP01

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
   ROLLBACK TRAN rdt_1665DeleteSP01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO