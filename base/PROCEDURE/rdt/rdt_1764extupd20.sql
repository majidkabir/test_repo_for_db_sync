SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtUpd20                                    */
/* Purpose: Mattel, active the hold pick task once the repl task is done*/
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author   Ver.  Purposes                                 */
/* 2024-05-07   NLT013   1.0   UWP-19082 UWP-18889 Create Intial Version*/
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1764ExtUpd20]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT = 0
   ,@cDropID         NVARCHAR( 20) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT

   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cToLOC      NVARCHAR( 10)

   SET @nTranCount = @@TRANCOUNT

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         DECLARE @cReplPickListName NVARCHAR( 10)
         -- Get task info
         SELECT
            @cStorerKey    = StorerKey,
            @cFromID       = FromID,
            @cSKU          = SKU,
            @cToLoc        = ToLoc
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskdetailKey = @cTaskDetailKey
            AND TaskType = 'RPF'

         SET @cReplPickListName = rdt.RDTGetConfig( @nFunc, 'TM_RPLRELPICK', @cStorerKey) 
         IF @cReplPickListName IS NULL OR @cReplPickListName = ''
            SET @cReplPickListName = '0'

         BEGIN TRAN
         SAVE TRAN rdt_1764ExtUpd20

         BEGIN TRY
            UPDATE td
            SET td.Status = '0'
            FROM dbo.TaskDetail td WITH (NOLOCK)
            INNER JOIN dbo.CODELKUP lu WITH(NOLOCK)
               ON td.StorerKey = lu.StorerKey
               AND td.TaskType = ISNULL(lu.Code2, '')
            WHERE td.StorerKey   = @cStorerKey
               AND lu.LISTNAME   = @cReplPickListName
               AND td.Status     = 'H'
               AND td.SKU        = @cSKU
               AND td.FromLoc    = @cToLoc
         END TRY
         BEGIN CATCH
            SET @nErrNo = 214801
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPKTaskFail
            GOTO RollBackTran
         END CATCH

         COMMIT TRAN rdt_1764ExtUpd20 -- Only commit change made here
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764ExtUpd20 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO