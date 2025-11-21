SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Scan_To_Pallet_Confirm                          */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-05-12 1.0  Ung        WMS-13218 Created                         */
/* 2021-01-12 1.1  James      WMS-15914 Stamp tracking no into          */
/*                            PackInfo.TrackingNo (james01)             */
/************************************************************************/

CREATE PROC [RDT].[rdt_Scan_To_Pallet_Confirm] (
    @nMobile            INT
   ,@nFunc              INT
   ,@cLangCode          NVARCHAR( 3)
   ,@nStep              INT
   ,@nInputKey          INT
   ,@cFacility          NVARCHAR( 5)
   ,@cStorerKey         NVARCHAR( 15)
   ,@cPalletKey         NVARCHAR( 30)
   ,@cLOC               NVARCHAR( 10)
   ,@cCaseID            NVARCHAR( 20)
   ,@cCapturePackInfo   NVARCHAR( 10)
   ,@cCartonType        NVARCHAR( 10)
   ,@cCube              NVARCHAR( 10)
   ,@cWeight            NVARCHAR( 10)
   ,@cRefNo             NVARCHAR( 20)
   ,@cPickSlipNo        NVARCHAR( 10) 
   ,@nCartonNo          INT
   ,@cSKU               NVARCHAR( 20)
   ,@nQTY               INT
   ,@nErrNo             INT           OUTPUT
   ,@cErrMsg            NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cConfirmSP  NVARCHAR( 20)
   
   -- Get storer configure
   SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''

   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   -- Custom logic
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  ' +
            ' @cPalletKey, @cLOC, @cCaseID, @cCapturePackInfo, @cCartonType, @cCube, @cWeight, @cRefNo, ' + 
            ' @cPickSlipNo, @nCartonNo, @cSKU, @nQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            ' @nMobile           INT,           ' + 
            ' @nFunc             INT,           ' + 
            ' @cLangCode         NVARCHAR( 3),  ' + 
            ' @nStep             INT,           ' + 
            ' @nInputKey         INT,           ' + 
            ' @cFacility         NVARCHAR( 5),  ' + 
            ' @cStorerKey        NVARCHAR( 15), ' +   
            ' @cPalletKey        NVARCHAR( 30), ' +   
            ' @cLOC              NVARCHAR( 10), ' +   
            ' @cCaseID           NVARCHAR( 20), ' + 
            ' @cCapturePackInfo  NVARCHAR( 10), ' +   
            ' @cCartonType       NVARCHAR( 10), ' + 
            ' @cCube             NVARCHAR( 10), ' + 
            ' @cWeight           NVARCHAR( 10), ' + 
            ' @cRefNo            NVARCHAR( 20), ' + 
            ' @cPickSlipNo       NVARCHAR( 10), ' + 
            ' @nCartonNo         INT,           ' + 
            ' @cSKU              NVARCHAR( 20), ' +   
            ' @nQTY              INT,           ' + 
            ' @nErrNo            INT           OUTPUT, ' + 
            ' @cErrMsg           NVARCHAR( 20) OUTPUT  '
            
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cPalletKey, @cLOC, @cCaseID, @cCapturePackInfo, @cCartonType, @cCube, @cWeight, @cRefNo, 
            @cPickSlipNo, @nCartonNo, @cSKU, @nQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
   DECLARE @cPalletLineNumber NVARCHAR( 5)
   SELECT @cPalletLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( PalletLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
   FROM dbo.PalletDetail WITH (NOLOCK)
   WHERE PalletKey = @cPalletKey
      AND StorerKey = @cStorerKey

   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_Scan_To_Pallet_Confirm -- For rollback or commit only our own transaction

   INSERT INTO dbo.PalletDetail
      (PalletKey, PalletLineNumber, CaseId, StorerKey, Sku, Loc, Qty, Status, 
      AddDate, AddWho, EditDate, EditWho)
   VALUES
      (@cPalletKey, @cPalletLineNumber, @cCaseID, @cStorerKey, @cSKU, @cLOC, @nQty, '0', 
      GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME())
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 152151
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Ins PLTDt Fail
      GOTO RollbackTran
   END

   -- Capture PackInfo (before)
   IF @cCapturePackInfo = '1'
   BEGIN
      -- Get cube
      DECLARE @nCube FLOAT
      SELECT @nCube = Cube
	   FROM Cartonization WITH (NOLOCK)
	      INNER JOIN Storer WITH (NOLOCK) ON (Storer.CartonGroup = Cartonization.CartonizationGroup)
	   WHERE Storer.StorerKey = @cStorerKey
	      AND Cartonization.CartonType = @cCartonType

      -- Insert PackInfo
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo  = @nCartonNo)
      BEGIN
         INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, Qty, Weight, Cube, CartonType)
         VALUES (@cPickSlipNo, @nCartonNo, 0, 0, @nCube, @cCartonType)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 152152
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
            GOTO RollbackTran
         END
      END
   END

   -- Capture PackInfo (after)
   ELSE IF CHARINDEX( '2', @cCapturePackInfo) > 0
   BEGIN
      DECLARE @fCube FLOAT
      DECLARE @fWeight FLOAT
      SET @fCube = CAST( @cCube AS FLOAT)
      SET @fWeight = CAST( @cWeight AS FLOAT)

      -- PackInfo
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
      BEGIN
         INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, Qty, Weight, Cube, CartonType, RefNo, TrackingNo)
         VALUES (@cPickSlipNo, @nCartonNo, 0, @fWeight, @fCube, @cCartonType, @cRefNo, @cRefNo)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 152153
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
            GOTO RollbackTran
         END
      END
      ELSE
      BEGIN
         UPDATE dbo.PackInfo SET
            CartonType = @cCartonType,
            Weight = @fWeight,
            [Cube] = @fCube,
            RefNo = @cRefNo, 
            TrackingNo = @cRefNo
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 152154
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail
            GOTO RollbackTran
         END
      END
   END

   DECLARE @cRefNo1 NVARCHAR(20)
   DECLARE @cRefNo2 NVARCHAR(20)
   SET @cRefNo1 = SUBSTRING( @cPalletKey, 1, 15)
   SET @cRefNo2 = SUBSTRING( @cPalletKey, 16, 15)

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '14',
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerkey,
      @cLocation     = @cLOC,
      @cID           = @cCaseID,
      @cSKU          = @cSKU,
      @nQTY          = @nQTY,
      @cRefNo1       = @cRefNo1,
      @cRefNo2       = @cRefNo2   

   COMMIT TRAN rdt_Scan_To_Pallet_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Scan_To_Pallet_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END


GO