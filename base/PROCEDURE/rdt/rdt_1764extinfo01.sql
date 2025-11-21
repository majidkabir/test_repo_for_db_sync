SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtInfo01                                   */
/* Purpose: Extended info                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-01-27   Ung       1.0   SOS331666 Created                       */
/* 2021-09-30   James     1.1   WMS-18045 Add Wave.Descr (james01)      */
/* 2022-03-29   Ung       1.2   WMS-19137 Add task counter              */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1764ExtInfo01]
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

   DECLARE @cUOM        NVARCHAR(10)
   DECLARE @cTaskType   NVARCHAR(10)
   DECLARE @cWaveKey    NVARCHAR( 10)
   DECLARE @cDescr      NVARCHAR( 60)
   
   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      -- Get TaskDetail info
      SET @cTaskType = ''
      SET @cUOM = ''
      SELECT 
         @cTaskType = TaskType, 
         @cUOM = UOM, 
         @cWaveKey = WaveKey 
      FROM TaskDetail WITH (NOLOCK) 
      WHERE TaskdetailKey = @cTaskdetailKey
      
      IF @nAfterStep = 6   -- TOLOC 
      BEGIN
         SELECT @cDescr = Descr 
         FROM dbo.WAVE WITH (NOLOCK) 
         WHERE WaveKey = @cWaveKey
         
         IF @cTaskType = 'RP1'
            SET @cExtendedInfo1 = 'UOM: ' + @cUOM + '     RM:' + SUBSTRING( @cDescr, 1, 10)
      END
      
      IF @nAfterStep = 7   -- Get next task
      BEGIN
         IF @cTaskType = 'RP1'
            SET @cExtendedInfo1 = 'LAST UOM: ' + @cUOM
      
         IF @cTaskType = 'RPF'
         BEGIN
            DECLARE @cPutawayZone NVARCHAR( 10)
            SELECT @cPutawayZone = PutawayZone
            FROM dbo.TaskDetail TD WITH (NOLOCK) 
               JOIN dbo.LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)
            WHERE TaskdetailKey = @cTaskdetailKey
            
            IF @cPutawayZone <> ''
            BEGIN
               -- Get outstanding task
               DECLARE @nOpenTask INT
               SELECT @nOpenTask = COUNT(1)
               FROM dbo.TaskDetail TD WITH (NOLOCK) 
                  JOIN dbo.LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)
               WHERE TD.TaskType = 'RPF'
                  AND TD.Status = '0'
                  AND LOC.PutawayZone = @cPutawayZone
                  
               SET @cExtendedInfo1 = 'REMAIN TASK: ' + CAST( @nOpenTask AS NVARCHAR(5))
            END
         END
      END
   
   END

Quit:

END

GO