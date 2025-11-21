SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1815ExtUpd01                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2021-10-21  1.0  Chermaine WMS-17638 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1815ExtUpd01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cTaskDetailKey   NVARCHAR( 10),
   @cToLOC           NVARCHAR( 10),
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
   
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount       INT
   DECLARE @cSQL             NVARCHAR( MAX)
   DECLARE @cSQLParam        NVARCHAR( MAX)
   
   DECLARE 
      @cFinalLoc        NVARCHAR(20),
      @cSuggToLOC       NVARCHAR(20)
   
   IF @nStep = 1 -- FinalLoc
   BEGIN
      IF @nInputKey = 0
      BEGIN
      	SELECT  
            @cFinalLOC    = FinalLOC,  
            @cSuggToLOC   = ToLOC  
         FROM dbo.TaskDetail WITH (NOLOCK)  
         WHERE TaskDetailKey = @cTaskDetailKey  
   
         -- Suggested location
         IF @cFinalLoc <> '' 
         BEGIN
            -- Handling transaction
            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdtfnc_TM_Assist_Putaway -- For rollback or commit only our own transaction

            UPDATE TaskDetail WITH (ROWLOCK) SET    
                ToLOC      = '' 
               ,FinalLOC   = ''
               ,LogicalFromLoc = ''
               ,LogicalToLoc = ''
               ,EditDate   = GETDATE()
               ,EditWho    = SUSER_SNAME()
               ,TrafficCop = NULL        
            WHERE TaskDetailKey = @cTaskDetailKey    
      

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 177451
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
               GOTO RollBackTran
            END
         
            COMMIT TRAN rdtfnc_TM_Assist_Putaway -- Only commit change made here
         END

         GOTO Quit
      END
   END
   

RollBackTran:
   ROLLBACK TRAN rdtfnc_TM_Assist_Putaway -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO