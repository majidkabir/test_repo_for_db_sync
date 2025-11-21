SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1770ExtInfo04                                   */
/* Purpose: Display remaining task in the same from loc                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2020-03-17   James     1.0   WMS-12417. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1770ExtInfo04]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cExtendedInfo1  NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFromLoc   NVARCHAR(10)
   DECLARE @cTaskType  NVARCHAR(10)
   DECLARE @nTotalTask INT

   -- Get TaskDetail info
   SELECT @cFromLoc = FromLoc,
          @cTaskType = TaskType
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey         

   -- TM Pallet Pick
   IF @nFunc = 1770
   BEGIN
      IF @nAfterStep = 1
      BEGIN
         -- Get total pallet
         SELECT @nTotalTask = COUNT( TaskDetailKey) 
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE FromLoc = @cFromLoc
         AND   TaskType = @cTaskType
         AND   [Status] = '0'

         SET @cExtendedInfo1 = 'REMAINING: ' + CAST( @nTotalTask AS NVARCHAR(3)) 
      END
   END
END

GO