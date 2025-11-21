SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtUpd21                                    */
/* Purpose: Rollback FinalLoc and TransitLoc once quit the task         */
/* Customer: Grainte Levis                                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author   Ver.  Purposes                                 */
/* 2025-02-21   NLT013   1.0   UWP-30476 Create Intial Version          */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1764ExtUpd21]
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

   DECLARE @cStorerKey              NVARCHAR( 15)
   DECLARE @cToLOC                  NVARCHAR( 10)
   DECLARE @cFinalLOC               NVARCHAR(10)
   DECLARE @cTaskStatus             NVARCHAR(10)
   DECLARE @cToLOCCat               NVARCHAR( 10)
   DECLARE @cFacilily               NVARCHAR( 5)
   DECLARE @cInputKey               NVARCHAR(3)

   SET @nTranCount = @@TRANCOUNT

   SELECT @cFacilily = Facility,
      @cStorerKey  = StorerKey,
      @cInputKey = InputKey
   FROM RDT.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nStep = 9 -- REASON CODE
      BEGIN
         IF @cInputKey = '1'
         BEGIN
            -- Get task info
            SELECT
               @cToLoc        = ToLoc,
               @cFinalLOC     = FinalLoc,
               @cTaskStatus   = Status
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskdetailKey = @cTaskDetailKey
               AND TaskType = 'RPF'
               AND StorerKey = @cStorerKey

            IF @cToLoc <> '' AND @cFinalLOC <> '' AND @cFinalLOC <> @cToLoc
            BEGIN
               SELECT @cToLOCCat = LocationCategory
               FROM dbo.LOC WITH(NOLOCK)
               WHERE Facility = @cFacilily
                  AND Loc = @cToLoc
            END

            BEGIN TRAN
            SAVE TRAN rdt_1764ExtUpd21

            BEGIN TRY
               IF @cToLOCCat IN ('PND', 'PND_IN', 'PND_OUT') AND @cTaskStatus IN ('0', 'X') AND @cFinalLOC <> '' AND @cFinalLOC <> @cToLoc
               BEGIN
                  UPDATE dbo.TaskDetail WITH (ROWLOCK)
                  SET ToLoc = @cFinalLOC,
                     FinalLoc = '',
                     EditDate = GETDATE(),
                     EditWho  = SUSER_SNAME(),
                     TransitLoc = '',
                     TrafficCop = NULL
                  WHERE TaskDetailKey = @cTaskdetailKey
                     AND StorerKey = @cStorerKey
               END
            END TRY
            BEGIN CATCH
               SET @nErrNo = 233651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPKTaskFail
               GOTO RollBackTran
            END CATCH

            COMMIT TRAN rdt_1764ExtUpd21 -- Only commit change made here
         END
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764ExtUpd21 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO