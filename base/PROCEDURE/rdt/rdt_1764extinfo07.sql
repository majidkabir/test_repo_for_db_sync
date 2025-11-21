SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtInfo07                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2019-09-30   Ung       1.0   WMS-10572 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764ExtInfo07]
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

   DECLARE @cTaskType   NVARCHAR( 10)
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @nTotalTask  INT
   DECLARE @nFinishTask INT

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nAfterStep = 4 -- SKU, QTY
      BEGIN
         -- Get TaskDetail info
         SELECT 
            @cTaskType = TaskType, 
            @cStorerKey = StorerKey, 
            @cFromLOC = FromLOC, 
            @cLoadKey = LoadKey
         FROM TaskDetail WITH (NOLOCK) 
         WHERE TaskdetailKey = @cTaskdetailKey
      
         -- Get LOC info
         SELECT @cFacility = Facility FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC
      
         -- Get total task in LOC (1 task 1 carton)
         SELECT @nTotalTask = COUNT(1)
         FROM TaskDetail TD WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND TD.StorerKey = @cStorerKey
            AND TD.TaskType = @cTaskType 
            AND TD.FromLOC = @cFromLOC
            AND TD.LoadKey = @cLoadKey

         -- Get completed task in LOC, ID (1 task 1 carton)
         SELECT @nFinishTask = COUNT(1)
         FROM TaskDetail TD WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND TD.StorerKey = @cStorerKey
            AND TD.TaskType = @cTaskType 
            AND TD.FromLOC = @cFromLOC
            AND TD.LoadKey = @cLoadKey
            AND TD.Status >= '5'

         DECLARE @cMsg1 NVARCHAR( 20)
         SET @cMsg1 = rdt.rdtgetmessage( 144501, @cLangCode, 'DSP') --CARTON:
         
         SET @cExtendedInfo1 = 
            RTRIM( @cMsg1) + ' ' +  
            CAST( @nFinishTask AS NVARCHAR(5)) + '/' + 
            CAST( @nTotalTask AS NVARCHAR(5))
      END
   END

Quit:

END

GO