SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_TM_Assist_Move_Confirm                          */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Validate location type                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-03-04   Ung       1.0   SOS332730 Created                       */
/* 2015-07-01   James     1.1   Add function id to rdt_move (james01)   */
/* 2016-01-26   Ung       1.2   Add PickMethod = NMV                    */
/* 2021-06-15   James     1.3   WMS-16966 Add ExtendedMoveCfmSP(james02)*/
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_TM_Assist_Move_Confirm]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cFinalLOC       NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cExtendedMoveCfmSP   NVARCHAR( 20)
   DECLARE @cSQL                 NVARCHAR( MAX)
   DECLARE @cSQLParam            NVARCHAR( MAX)
   
   SET @cExtendedMoveCfmSP = rdt.rdtGetConfig( @nFunc, 'ExtendedMoveCfmSP', @cStorerKey)
   IF @cExtendedMoveCfmSP = '0'
      SET @cExtendedMoveCfmSP = ''  
      
   -- Extended putaway
   IF @cExtendedMoveCfmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedMoveCfmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedMoveCfmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailKey, @cFinalLOC, ' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,                  ' +
            '@nFunc           INT,                  ' +
            '@cLangCode       NVARCHAR( 3),         ' +
            '@nStep           INT,                  ' +
            '@nInputKey       INT,                  ' +
            '@cFacility       NVARCHAR( 5),         ' +
            '@cStorerKey      NVARCHAR( 15),        ' +
            '@cTaskdetailKey  NVARCHAR( 10),        ' +
            '@cFinalLOC       NVARCHAR( 10),        ' +
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailKey, @cFinalLOC, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Fail
      END
   END
   ELSE
   BEGIN
      DECLARE @cFromLOC NVARCHAR(10)
      DECLARE @cFromID  NVARCHAR(18)
      DECLARE @cPickMethod NVARCHAR(10)

      -- Get task info
      SELECT 
         @cFromLOC = FromLOC, 
         @cFromID = FromID,
         @cPickMethod = PickMethod
      FROM TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskDetailKey
   
      -- Handling transaction
      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_TM_Assist_Move_Confirm -- For rollback or commit only our own transaction

      -- Move by ID
      IF @cPickMethod <> 'NMV'
      BEGIN
         EXECUTE rdt.rdt_Move
            @nMobile     = @nMobile,
            @cLangCode   = @cLangCode, 
            @nErrNo      = @nErrNo  OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT,
            @cSourceType = 'rdt_TM_Assist_Move_Confirm', 
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility, 
            @cFromLOC    = @cFromLOC, 
            @cToLOC      = @cFinalLoc, 
            @cFromID     = @cFromID, 
            @cToID       = NULL,  -- NULL means not changing ID
            @nFunc       = @nFunc 
         IF @nErrNo <> 0
            GOTO RollbackTran
      END
   
      -- Update task
      UPDATE dbo.TaskDetail SET
         Status = '9',
         ToLOC = @cFinalLoc,
         UserKey = SUSER_SNAME(),
         EditWho = SUSER_SNAME(),
         EditDate = GETDATE(), 
         Trafficcop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 52251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
         GOTO RollbackTran
      END

      COMMIT TRAN rdt_TM_Assist_Move_Confirm -- Only commit change made here
      GOTO Quit

      RollBackTran:
         ROLLBACK TRAN rdt_TM_Assist_Move_Confirm -- Only rollback change made here
      Quit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
   END
   
   Fail:
END

GO