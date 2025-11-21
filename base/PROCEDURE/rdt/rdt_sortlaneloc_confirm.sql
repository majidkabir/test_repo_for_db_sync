SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_SortLaneLoc_Confirm                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-01-04 1.0  Ung        SOS265198. Created                        */
/* 2014-01-29 1.1  Ung        SOS300988 Add EventLog                    */
/************************************************************************/

CREATE PROC [RDT].[rdt_SortLaneLoc_Confirm] (
   @nMobile    INT,
   @nFunc      INT, 
   @cLangCode  NVARCHAR( 3), 
   @cUserName  NVARCHAR( 18), 
   @cStorerKey NVARCHAR( 15), 
   @cFacility   NVARCHAR( 5), 
   @cLane      NVARCHAR( 10),
   @cLOC       NVARCHAR( 10),
   @cID        NVARCHAR( 18), 
   @cLabelNo   NVARCHAR( 20),
   @nErrNo     INT       OUTPUT, 
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_SortLaneLoc_Confirm

   -- Stamp ID
   IF EXISTS (SELECT 1 FROM rdt.rdtSortLaneLocLog WITH (NOLOCK) WHERE Lane = @cLane AND LOC = @cLOC AND ID = '')
   BEGIN
      UPDATE rdt.rdtSortLaneLocLog SET
         ID = @cID
      WHERE Lane = @cLane 
         AND LOC = @cLOC
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 78801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UPD Log Fail
         GOTO RollBackTran
      END
   END

   -- Build pallet
   IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cID)
   BEGIN
      INSERT INTO dbo.DropID (DropID, DropLOC) VALUES (@cID, @cLane) 
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 78802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- INS DropIDFail
         GOTO RollBackTran
      END
   END 

   -- Add carton
   IF NOT EXISTS( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cID AND ChildID = @cLabelNo)
   BEGIN
      INSERT INTO dbo.DropIDDetail (DropID, ChildID) VALUES (@cID, @cLabelNo)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 78803
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- INS DID Fail
         GOTO RollBackTran
      END
   END 

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '4', -- Move
      @cUserID       = @cUserName,
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerkey,
      @cLocation     = @cLane, 
      @cRefNo1       = @cLabelNo, 
      @cDropID       = @cID
   GOTO Quit

RollBackTran:
      ROLLBACK TRAN rdt_SortLaneLoc_Confirm
Quit:         
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN

GO