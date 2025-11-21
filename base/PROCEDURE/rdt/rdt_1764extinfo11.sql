SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtInfo11                                   */
/* Purpose: Extended info                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2023-03-22   Ung       1.0   WMS-22053 Created                       */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1764ExtInfo11]
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

   DECLARE @cWaveKey    NVARCHAR( 10)
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cPickMethod NVARCHAR( 10)
   DECLARE @cToLOC      NVARCHAR( 10)
   DECLARE @cUCCNo      NVARCHAR( 20)
   DECLARE @nQTY        INT
   DECLARE @nTotalUCC   INT 
   DECLARE @nTotalTask  INT 
   DECLARE @nCompleted  INT 

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nAfterStep = 1 OR -- Drop ID screen
         @nAfterStep = 2    -- From LOC screen
      BEGIN
         -- Get task info
         SELECT 
            @cWaveKey = WaveKey, 
            @cToLOC = ToLOC
         FROM TaskDetail (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         SET @cExtendedInfo1 = @cWaveKey + @cToLOC
      END
      
      IF @nAfterStep = 3 -- From ID screen
      BEGIN
         -- Get task info
         SELECT 
            @cStorerKey = StorerKey, 
            @cWaveKey = WaveKey, 
            @cFromLOC = FromLOC, 
            @cFromID = FromID, 
            @cToLOC = ToLOC
         FROM TaskDetail (NOLOCK) 
         WHERE TaskDetailKey = @cTaskDetailKey
         
         -- Get stat
         SELECT @nTotalUCC = COUNT(1)
         FROM TaskDetail (NOLOCK) 
            JOIN LOC LOC2 WITH (NOLOCK) ON (TaskDetail.ToLOC = LOC2.LOC)
            JOIN PickZone PKZone2 WITH (NOLOCK) ON (LOC2.PickZone = PKZone2.PickZone)
         WHERE @cStorerKey = StorerKey
            AND WaveKey = @cWaveKey
            AND FromLOC = @cFromLOC
            AND FromID = @cFromID
            AND TaskType IN ('RPF')
            AND PKZone2.InLOC = @cToLOC

         DECLARE @cMsg NVARCHAR( 20)
         SET @cMsg = rdt.rdtgetmessage( 198051, @cLangCode, 'DSP') -- TOTAL UCC: 
         
         SET @cExtendedInfo1 = RTRIM( @cMsg) + ' ' + CAST( @nTotalUCC AS NVARCHAR(5))
      END

      IF @nAfterStep = 4 -- SKU, QTY screen
      BEGIN
         -- Get task info
         SELECT @cUCCNo = CaseID
         FROM TaskDetail (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         SET @cExtendedInfo1 = @cUCCNo
      END
   END
END

GO