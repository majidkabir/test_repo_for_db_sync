SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_SortCartonToPallet_Confirm                         */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Purpose: Save carton to pallet                                          */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2023-07-18   1.0  Ung      WMS-22855 Created                            */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_SortCartonToPallet_Confirm](
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cUpdateTable  NVARCHAR( 20), -- DROPID/PALLET
   @cCartonID     NVARCHAR( 20),
   @cPalletID     NVARCHAR( 20),
   @cSuggID       NVARCHAR( 18),
   @cSuggLOC      NVARCHAR( 10),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT, 
   @cUDF01        NVARCHAR( 30), 
   @cUDF02        NVARCHAR( 30), 
   @cUDF03        NVARCHAR( 30), 
   @cUDF04        NVARCHAR( 30), 
   @cUDF05        NVARCHAR( 30), 
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cCartonIDSP NVARCHAR( 20)
   DECLARE @cDefaultLOC NVARCHAR( 10)

   -- Storer config
   SET @cCartonIDSP = rdt.RDTGetConfig( @nFunc, 'CartonIDSP', @cStorerKey)
   IF @cCartonIDSP NOT IN ('PickDetailDropID', 'PickDetailCaseID', 'PackDetailLabelNo', 'PackDetailDropID')
      SET @cCartonIDSP = 'PickDetailDropID'
   SET @cDefaultLOC = rdt.rdtGetConfig( @nFunc, 'DefaultLOC', @cStorerKey)
   IF @cDefaultLOC = '0'
      SET @cDefaultLOC = ''

   -- Check LOC
   IF @cSuggLOC = ''
   BEGIN
      -- Set default LOC
      IF @cDefaultLOC <> ''
         SET @cSuggLOC = @cDefaultLOC
      
      -- Check LOC needed
      IF @cUpdateTable = 'PALLET' AND @cSuggLOC = ''
      BEGIN
         SET @nErrNo = 204001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need LOC
         GOTO Quit
      END
   END

	DECLARE @nTranCount INT
	SET @nTranCount = @@TRANCOUNT
	BEGIN TRAN
	SAVE TRAN Confirm

   -- DropID table
   IF @cUpdateTable = 'DROPID'
   BEGIN
      -- Create DropID
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cPalletID)
      BEGIN
         INSERT INTO dbo.DROPID (Dropid, Droploc, DropIDType, Status, UDF01, UDF02, UDF03, UDF04, UDF05)
         VALUES (@cPalletID, @cSuggLOC, @nFunc, '0', @cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 204002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins DROPIDFail
            GOTO RollBackTran
         END
      END

      -- Create DropIDDetail
      INSERT INTO dbo.DropIDDetail (Dropid, ChildID) VALUES (@cPalletID, @cCartonID)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 204003
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins DPDtl Fail
         GOTO RollBackTran
      END
   END
   
   -- Pallet table
   IF @cUpdateTable = 'PALLET'
   BEGIN
      -- Pallet
      IF NOT EXISTS (SELECT 1 FROM dbo.Pallet WITH (NOLOCK) WHERE PalletKey = @cPalletID)
      BEGIN
         INSERT INTO dbo.Pallet (PalletKey, StorerKey, Status, PalletType, AddDate, AddWho, EditDate, EditWho) 
         VALUES (@cPalletID, @cStorerKey, '0', @nFunc, GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME())
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 204004
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Ins PLT Fail
            GOTO RollBackTran
         END
      END
      
      -- PalletDetail
      IF NOT EXISTS( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletID AND CaseID = @cCartonID)
      BEGIN
         INSERT INTO dbo.PalletDetail
            (PalletKey, PalletLineNumber, CaseID, StorerKey, SKU, LOC, QTY, Status, 
            UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, 
            AddDate, AddWho, EditDate, EditWho)
         VALUES
            (@cPalletID, '0', @cCartonID, @cStorerKey, @cSKU, @cSuggLOC, @nQTY, '0', 
            @cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05, 
            GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME())
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 204005
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Ins PLTDt Fail
            GOTO RollbackTran
         END         
      END
   END

   -- Eventlog
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '4', -- Move
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerkey,
      @cToLocation   = @cSuggLOC,
      @cToID         = @cPalletID,
      @cCartonID     = @cCartonID, 
      @cRefNo1       = @cUDF01, 
      @cRefNo2       = @cUDF02, 
      @cRefNo3       = @cUDF03, 
      @cRefNo4       = @cUDF04, 
      @cRefNo5       = @cUDF05 
   
   COMMIT TRAN Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO