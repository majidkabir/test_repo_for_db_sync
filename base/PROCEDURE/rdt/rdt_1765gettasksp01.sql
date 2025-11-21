SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1765GetTaskSP01                                 */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: ANF Replen To Logic                                         */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2014-06-26  1.0  ChewKP   Created                                    */
/* 2020-10-19  1.1  LZG      INC1297036 - Added ELSE IF to return first */
/*                                        matching condition (ZG01)     */
/************************************************************************/

CREATE PROC [RDT].[rdt_1765GetTaskSP01] (
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @cUserName           NVARCHAR( 15),
   @cAreaKey            NVARCHAR( 5),
   @cPrevTaskDetailKey  NVARCHAR( 10),
   @cTaskDetailKey      NVARCHAR( 10),
   @nStep               INT           OUTPUT,
   @nErrNo              INT           OUTPUT,
   @cErrMsg             NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @cPrevFromLoc NVARCHAR(10)
           ,@cPrevFromID  NVARCHAR(18)
           ,@cPrevSKU     NVARCHAR(20)
           ,@cPrevToLoc   NVARCHAR(10)

           ,@cFromLoc     NVARCHAR(10)
           ,@cFromID      NVARCHAR(18)
           ,@cSKU         NVARCHAR(20)
           ,@cToLoc       NVARCHAR(10)
           ,@nTranCount   INT


   SET @nErrNo   = 0
   SET @cErrMsg  = ''


   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1765GetTaskSP01

   SELECT   @cPrevFromLoc = FromLoc
          , @cPrevFromID  = FromID
          , @cPrevSKU     = SKU
          , @cPrevToLoc   = ToLoc
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailkey = @cPrevTaskDetailKey


   SELECT   @cFromLoc = FromLoc
          , @cFromID  = FromID
          , @cSKU     = SKU
          , @cToLoc   = ToLoc
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailkey = @cTaskDetailKey




   IF ISNULL(RTRIM(@cPrevFromLoc),'') <> ISNULL(RTRIM(@cFromLoc),'' )
   BEGIN
       SET @nStep = 1
   END

   ELSE IF @cPrevFromID <> @cFromID       -- ZG01
   BEGIN
       SET @nStep = 2
   END

   ELSE IF @cPrevToLoc <> @cToLoc         -- ZG01
   BEGIN
       SET @nStep = 3
   END



   ELSE IF @cPrevSKU = @cSKU AND (@cPrevFromLoc = @cFromLoc AND @cPrevFromID = @cFromID AND @cPrevToLoc = @cToLoc)       -- ZG01
   BEGIN
       SET @nStep = 4
   END
   ELSE
   BEGIN
      SET @nStep = 3
   END


   GOTO QUIT

RollBackTran:
   ROLLBACK TRAN rdt_1765GetTaskSP01 -- Only rollback change made here

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_1765GetTaskSP01


END

GO