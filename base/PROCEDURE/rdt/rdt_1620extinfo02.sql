SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1620ExtInfo02                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: UA Extended info to show Qty pick/unpick by style           */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2017-10-30 1.0  James    WMS3313. Created                            */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1620ExtInfo02]    
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
       
   DECLARE 
           @cStyle         NVARCHAR( 20),
           @cPutAwayZone   NVARCHAR( 10),
           @cPickZone      NVARCHAR( 10),
           @nQtyAllocated  INT,
           @nQtyPicked     INT,
           @nQtyPickLock   INT

   SELECT @cPutAwayZone = V_String10,
          @cPickZone = V_String11
   FROM RDT.RDTMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cExtendedInfo = ''

   IF @nStep IN (7, 8)
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cStyle = Style
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU

         SELECT @nQtyAllocated = ISNULL( SUM( PD.Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.OrderKey = @cOrderKey
         AND   SKU.Style = @cStyle

         SELECT @nQtyPicked = ISNULL( SUM( Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.OrderKey = @cOrderKey
         AND ( PD.Status = '3' OR PD.Status = '5')
         AND   SKU.Style = @cStyle

         SELECT @nQtyPickLock = ISNULL( SUM( PickQty), 0)
         FROM RDT.RDTPickLock RPL WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( RPL.StorerKey = SKU.StorerKey AND RPL.SKU = SKU.SKU)
         WHERE OrderKey = @cOrderKey
         AND   ( ISNULL( @cWaveKey, '') = '' OR RPL.WaveKey = @cWaveKey)
         AND   ( ISNULL( @cLoadKey, '') = '' OR RPL.LoadKey = @cLoadKey)
         AND   ( ISNULL( @cPutAwayZone, '') = '' OR RPL.PutAwayZone = @cPutAwayZone)
         AND   ( ISNULL( @cPickZone, '') = '' OR RPL.PickZone = @cPickZone)
         AND   RPL.Status = '1'
         AND   RPL.AddWho = SUSER_SNAME()
         AND   SKU.Style = @cStyle

         SET @cExtendedInfo = CAST( ( @nQtyPicked + @nQtyPickLock) AS NVARCHAR( 5)) + '/' + CAST( @nQtyAllocated AS NVARCHAR( 5))

         --insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5) values 
         --('rdt_1620ExtInfo02', getdate(), @cStorerKey, @cOrderKey, @cStyle, @nQtyAllocated, @nQtyPicked)
      END   -- @nInputKey = 1
   END      -- @nStep IN (7, 8)

   QUIT:    
END -- End Procedure  

GO