SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtInfo02                                   */
/* Purpose: Extended info                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-04-06   Ung       1.0   WMS-1579 Created                        */
/* 2022-07-13   Ung       1.1   WMS-20206 Add balance task              */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1764ExtInfo02]
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

   DECLARE @nQTY   INT
   DECLARE @cUCCNo NVARCHAR(20)

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nAfterStep = 4 -- SKU, QTY screen
      BEGIN
         -- Get UCC on task not yet pick
         SELECT 
            @nQTY = QTY, 
            @cUCCNo = CaseID
         FROM TaskDetail (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         IF @@ROWCOUNT = 1 
            SET @cExtendedInfo1 = RIGHT( RTRIM( @cUCCNo) + '--' + RTRIM(CAST( @nQTY AS NVARCHAR(5))), 20)
      END
      
      IF @nAfterStep = 5 -- Cont next task / close pallet
      BEGIN
         DECLARE @cMsg NVARCHAR( 20) = ''
         DECLARE @cStorerKey NVARCHAR( 20)
         DECLARE @cWaveKey NVARCHAR( 10)
         DECLARE @nOpenTask INT
         
         -- Get task info
         SELECT 
            @cStorerKey = StorerKey, 
            @cWaveKey = WaveKey
         FROM TaskDetail (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         -- Get open tasks
         SELECT @nOpenTask = COUNT(1)
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND WaveKey = @cWaveKey
            AND TaskType = 'RPF'
            AND Status = '0'
            
         SET @cMsg = rdt.rdtgetmessage( 188301, @cLangCode, 'DSP') --REMAIN TASK:
         SET @cMsg = RTRIM( @cMsg) + ' ' + CAST( @nOpenTask AS NVARCHAR(3))
         SET @cExtendedInfo1 = @cMsg
      END
   END
END

GO