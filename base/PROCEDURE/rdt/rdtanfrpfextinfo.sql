SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtANFRPFExtInfo                                    */
/* Purpose: Extended info                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-01-29   Ung       1.0   SOS296465 Created                       */
/* 2014-06-24   Ung       1.2   SOS314511 RPF for transfer UCC          */
/* 2020-01-06   Chermaine 1.3   WMS-11674 Remove qty (cc01)             */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtANFRPFExtInfo]
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
         DECLARE @cWaveKey NVARCHAR(10)
         
         -- Get TaskDetail info
         SELECT @cWaveKey = WaveKey FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
         
         -- RPF for PTS
         IF @cWaveKey <> ''
         BEGIN
            -- Get UCC on task not yet pick
            SELECT TOP 1 
               @nQTY = UCC.QTY, 
               @cUCCNo = PD.DropID
            FROM PickDetail PD WITH (NOLOCK)
               JOIN UCC WITH (NOLOCK) ON (PD.DropID = UCC.UCCNo)
            WHERE TaskDetailKey = @cTaskDetailKey
               AND PD.Status = '0'
            ORDER BY PD.PickDetailKey
   
            IF @@ROWCOUNT = 1 
               SET @cExtendedInfo1 = @cUCCNo--RIGHT( RTRIM( @cUCCNo) + '--' + RTRIM(CAST( @nQTY AS NVARCHAR(5))), 20)   --(cc01)
         END

         -- RPF for transfer
         IF @cWaveKey = ''
         BEGIN
            -- Get UCC on task not yet pick
            SELECT TOP 1 
               @nQTY = UCC.QTY, 
               @cUCCNo = TD.CaseID
            FROM TaskDetail TD WITH (NOLOCK)
               JOIN UCC WITH (NOLOCK) ON (TD.CaseID = UCC.UCCNo AND TD.StorerKey = UCC.StorerKey)
            WHERE TaskDetailKey = @cTaskDetailKey
   
            IF @@ROWCOUNT = 1 
               SET @cExtendedInfo1 = @cUCCNo --RIGHT( RTRIM( @cUCCNo) + '--' + RTRIM(CAST( @nQTY AS NVARCHAR(5))), 20)  --(cc01)
         END
      END
   END
END

GO