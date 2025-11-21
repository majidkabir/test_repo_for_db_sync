SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1770ExtInfo01                                   */
/* Purpose: Display custom info                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-10-08   Ung       1.0   SOS322481 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1770ExtInfo01]
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

   DECLARE @cStorerKey NVARCHAR(15)
   DECLARE @cTaskType  NVARCHAR(10)
   DECLARE @cOrderKey  NVARCHAR(10)
   DECLARE @cWaveKey   NVARCHAR(10)
   DECLARE @cAreaKey   NVARCHAR(10)
   DECLARE @nTotal     INT
   DECLARE @nPick      INT

   -- Get TaskDetail info
   SELECT
      @cStorerKey = StorerKey, 
      @cTaskType = TaskType,
      @cOrderKey = OrderKey, 
      @cWaveKey = WaveKey, 
      @cAreaKey = AreaKey
   FROM TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey         

   -- TM Pallet Pick
   IF @nFunc = 1770
   BEGIN
      IF @nAfterStep = 4
      BEGIN
         -- Get total pallet
         SELECT @nTotal = COUNT(1) 
         FROM TaskDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND TaskType = @cTaskType
            AND OrderKey = @cOrderKey
            AND WaveKey = @cWaveKey

         -- Get picking/picked pallet
         SELECT @nPick = COUNT(1) 
         FROM TaskDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND TaskType = @cTaskType
            AND AreaKey = @cAreaKey
            AND OrderKey = @cOrderKey
            AND WaveKey = @cWaveKey       
            AND Status IN ('3', '9') 
            
         SET @cExtendedInfo1 = 'PICK/TOTAL: ' + CAST( @nPick AS NVARCHAR(3)) + '/' + CAST( @nTotal AS NVARCHAR(3))
      END
      
      IF @nAfterStep = 5
      BEGIN
         IF @cOrderKey <> ''
         BEGIN
            -- Get total pallet
            SELECT @nTotal = COUNT(1) 
            FROM TaskDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND TaskType = @cTaskType
               AND OrderKey = @cOrderKey
               AND WaveKey = @cWaveKey
               AND AreaKey = @cAreaKey

            -- Get picked pallet
            SELECT @nPick = COUNT(1) 
            FROM TaskDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND TaskType = @cTaskType
               AND AreaKey = @cAreaKey
               AND OrderKey = @cOrderKey
               AND WaveKey = @cWaveKey       
               AND Status = '9'
               
            IF @nPick = @nTotal
               SET @cExtendedInfo1 = 'ORDER FULLY PICKED'
         END
      END
   END
END

GO