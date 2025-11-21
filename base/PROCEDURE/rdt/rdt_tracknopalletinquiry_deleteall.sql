SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_TrackNoPalletInquiry_DeleteAll                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-07-17 1.0  Ung      WMS-4225 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_TrackNoPalletInquiry_DeleteAll] (
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
   DECLARE @cPDLineNo NVARCHAR( 5)
   DECLARE @cUserName NVARCHAR( 10)
   DECLARE @cPHStatus NVARCHAR( 10)
   DECLARE @cPDStatus NVARCHAR( 10)
      
   SET @cUserName = LEFT( SUSER_SNAME(), 10)

   -- Get pallet info
   SELECT @cPHStatus = Status FROM Pallet WITH (NOLOCK) WHERE PalletKey = @cPalletKey
         
   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_TrackNoPalletInquiry -- For rollback or commit only our own transaction

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
         SET @nErrNo = 126401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Pallet Fail
         GOTO RollbackTran
      END
   END

   -- Loop PalletDetail
   DECLARE @curTrackNo CURSOR
   SET @curTrackNo = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT PD.PalletLineNumber, PD.Status, PD.UserDefine01 -- OrderKey
      FROM PalletDetail PD WITH (NOLOCK) 
      WHERE PalletKey = @cPalletKey
   OPEN @curTrackNo 
   FETCH NEXT FROM @curTrackNo INTO @cPDLineNo, @cPDStatus, @cOrderKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
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
            SET @nErrNo = 126402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PLDtl Fail
            GOTO RollbackTran
         END
      END
      
      -- PalletDetail
      DELETE PalletDetail WHERE PalletKey = @cPalletKey AND PalletLineNumber = @cPDLineNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 126403
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL PLDtl Fail
         GOTO RollbackTran
      END

      -- MBOLDetail 
      -- Order with multi carton, delete MBOLDetail also. It will be blocked at scan to container module
      IF EXISTS( SELECT 1 FROM MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)
      BEGIN
         DELETE MBOLDetail WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 126404
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL MBDtl Fail
            GOTO RollbackTran
         END
      END
      
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
      
      FETCH NEXT FROM @curTrackNo INTO @cPDLineNo, @cPDStatus, @cOrderKey
   END

   -- Delete the pallet
   DELETE Pallet WHERE PalletKey = @cPalletKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 126405
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL Pallet Fail
      GOTO RollbackTran
   END

   -- Delete the MBOL
   IF NOT EXISTS( SELECT 1 FROM MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey)
   BEGIN
      DELETE MBOL WHERE MBOLKey = @cMBOLKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 126406
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL MBOL Fail
         GOTO RollbackTran
      END
   END
   
   
   COMMIT TRAN rdt_TrackNoPalletInquiry
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_TrackNoPalletInquiry -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO