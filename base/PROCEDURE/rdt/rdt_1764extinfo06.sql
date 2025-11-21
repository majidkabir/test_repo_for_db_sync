SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtInfo06                                   */
/* Purpose: Extended info                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2019-08-13   James     1.0   WMS-10205 Created                       */
/* 2020-03-17   James     1.1   WMS-12417 Add new ext info (james01)    */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764ExtInfo06]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@cTaskdetailKey  NVARCHAR( 10) 
   ,@cExtendedInfo1  NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cTaskType   NVARCHAR( 10)
   DECLARE @nReplenQty  INT
   DECLARE @nTotalTask INT

   -- Get TaskDetail info
   SELECT @cFromLOC = FromLoc,
          @cFromID = FromID,
          @cTaskType = TaskType
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskdetailKey

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      -- (james01)
      IF @nAfterStep IN ( 1, 2) -- Drop ID / From Loc
      BEGIN
         -- Get total pallet
         SELECT @nTotalTask = COUNT( TaskDetailKey) 
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE FromLoc = @cFromLoc
         AND   TaskType = @cTaskType
         AND   [Status] = '0'

         SET @cExtendedInfo1 = 'REMAINING: ' + CAST( @nTotalTask AS NVARCHAR(3)) 
      END

      IF @nAfterStep = 3 -- From Id
      BEGIN
         SELECT @nReplenQty = ISNULL( SUM( Qty), 0)
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskType = @cTaskType
         AND   FromLOC = @cFromLOC
         AND   FromID = @cFromID
         AND   Status = '3'

         SET @cExtendedInfo1 = 'REPLEN QTY: ' + CAST( @nReplenQty AS NVARCHAR( 5))
      END
   END

Quit:

END

GO