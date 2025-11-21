SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1831ExtUpd02                                          */
/* Purpose: Insert loadkey into log table                                     */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2021-12-13  1.0  yeekung   WMS18493 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1831ExtUpd02] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR( 15),
   @cParam1      NVARCHAR( 20),
   @cParam2      NVARCHAR( 20),
   @cParam3      NVARCHAR( 20),
   @cParam4      NVARCHAR( 20),
   @cParam5      NVARCHAR( 20),
   @cSKU         NVARCHAR( 20), 
   @nQty         NVARCHAR( 20), 
   @cLabelNo     NVARCHAR( 20), 
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR(20) OUTPUT
)
AS

   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cLoadKey    NVARCHAR( 10),
           @cWavekey    NVARCHAR( 10),
           @cFacility   NVARCHAR( 5),
           @cUserName   NVARCHAR( 18)

   SET @nErrNo = 0

   SET @cWavekey = @cParam1

   SELECT @cFacility = Facility, 
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nStep = 0 -- Init
   BEGIN
      -- Clear previous stored record
      DELETE FROM RDT.rdtSortAndPackLog
      WHERE AddWho = @cUserName

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 180001    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- DeleteLog Fail    
         GOTO Quit   
      END
   END

   IF @nStep = 1 -- Search Criteria
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM orders o(NOLOCK)
                     JOIN wave W (NOLOCK)  ON o.UserDefine09=w.WaveKey
                     WHERE w.WaveKey=@cWavekey
                     AND o.StorerKey=@cStorerKey)
         BEGIN
            SET @nErrNo = 180002    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidWave    
            GOTO Quit   
         END

         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtSortAndPackLog WITH (NOLOCK) 
                       WHERE wavekey = @cWavekey
                       AND   AddWho = @cUserName
                       AND   Status < '9')    
         BEGIN
            INSERT INTO rdt.rdtSortAndPackLog (	Mobile, Username,	StorerKey, wavekey,loadkey, [Status])
            SELECT DISTINCT @nMobile, @cUserName,@cStorerKey,@cWavekey,o.LoadKey,'0'
            FROM orders o(NOLOCK)
            JOIN wave W (NOLOCK)  ON o.UserDefine09=w.WaveKey
            WHERE w.WaveKey=@cWavekey
            AND o.StorerKey=@cStorerKey
            GROUP BY o.LoadKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 180003    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InsertLog Fail    
               GOTO Quit   
            END
         END
      END
   END

   IF @nStep = 3 -- Qty
   BEGIN
      IF @nInputKey = 0 -- ESC
      BEGIN
         SELECT @cLoadKey = LoadKey
         FROM rdt.rdtSortAndPackLog WITH (NOLOCK) 
         WHERE AddWho = @cUserName
         AND   Status = '1'
         AND   SKU = @cSKU

         UPDATE rdt.rdtSortAndPackLog WITH (ROWLOCK) SET 
            SKU = '',
            [Status] = '0'
         WHERE LoadKey = @cLoadKey
         AND   UserName = @cUserName
         AND   SKU = @cSKU
         AND   [Status] = '1'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 180004    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdLog Fail    
            GOTO Quit   
         END
      END
   END

   Quit:


GO