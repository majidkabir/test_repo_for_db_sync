SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1628ExtInfo01                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Macy extended info. Show Drop ID @ screen 1888 (step 8)     */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2016-09-19 1.0  James    SOS375742 Created                           */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1628ExtInfo01]    
   @nMobile       INT, 
   @nFunc         INT,       
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,
   @nInputKey     INT,
   @cWaveKey      NVARCHAR( 10), 
   @cLoadKey      NVARCHAR( 10), 
   @cOrderKey     NVARCHAR( 10), 
   @cDropID       NVARCHAR( 15), 
   @cStorerKey    NVARCHAR( 15), 
   @cSKU          NVARCHAR( 20), 
   @cLOC          NVARCHAR( 10), 
   @cExtendedInfo NVARCHAR( 20) OUTPUT 

AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @cPutAwayZone   NVARCHAR( 10),
           @cPickZone      NVARCHAR( 10),
           @cUserName      NVARCHAR( 18) 

   SET @cExtendedInfo = ''

   -- Drop ID not mandatory, skip display
   IF rdt.RDTGetConfig( @nFunc, 'ClusterPickScanDropID', @cStorerKey) = '0'
      GOTO Quit

   SELECT @cUserName = UserName, 
          @cPutAwayZone = V_String10, 
          @cPickZone = V_String11
   FROM rdt.rdtMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile
      
   IF @nInputKey = 1
   BEGIN
      IF @nStep = 7
      BEGIN   
         IF ISNULL( @cDropID, '') = ''
         BEGIN
            SELECT TOP 1 @cDropID = DropID
            FROM rdt.rdtPickLock WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   WaveKey = CASE WHEN ISNULL(@cWaveKey, '') = '' THEN WaveKey ELSE @cWaveKey END
            AND   LoadKey = CASE WHEN ISNULL(@cLoadKey, '') = '' THEN LoadKey ELSE @cLoadKey END
            AND   AddWho = @cUserName
            AND   PutAwayZone = CASE WHEN @cPutAwayZone = 'ALL' THEN PutAwayZone ELSE @cPutAwayZone END
            AND   PickZone = CASE WHEN ISNULL(@cPickZone, '') = '' THEN PickZone ELSE @cPickZone END
            AND   SKU = @cSKU
            AND   Status = '1'
         END
      END

      SET @cExtendedInfo = CASE WHEN LEN( RTRIM( @cDropID)) > 12 THEN @cDropID ELSE 'DROPID: ' + @cDropID END
   END
   Quit:    
END -- End Procedure  

GO