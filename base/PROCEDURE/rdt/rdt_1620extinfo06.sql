SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1620ExtInfo06                                   */    
/* Copyright: LF Logistics                                              */
/*                                                                      */    
/* Purpose: Puma display suggested id for loc.loseid = 0                */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 08-03-2023 1.0  James    WMS-21711. Created                          */    
/************************************************************************/    
    
CREATE   PROCEDURE [RDT].[rdt_1620ExtInfo06]    
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
       
   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @cId         NVARCHAR( 18)
   
   SET @cExtendedInfo = ''

   IF @nFunc = 1620
   BEGIN
      IF @nStep IN (7, 8, 19)
      BEGIN
         IF @nInputKey = 1
         BEGIN
         	SELECT @cFacility = Facility
         	FROM rdt.RDTMOBREC WITH (NOLOCK)
         	WHERE Mobile = @nMobile
         	
         	IF NOT EXISTS ( SELECT 1 
         	                FROM dbo.LOC WITH (NOLOCK)
         	                WHERE Loc = @cLoc
         	                AND   Facility = @cFacility
         	                AND   LoseId = '0') 
               GOTO Quit

            SELECT TOP 1 @cId = PD.ID
            FROM dbo.PICKDETAIL PD WITH (NOLOCK)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.Storerkey = SKU.StorerKey AND PD.Sku = SKU.Sku)
            WHERE PD.OrderKey = @cOrderKey
            AND   PD.Loc = @cLOC
            AND   PD.Status = '0'
            AND   PD.Storerkey = @cStorerKey
            ORDER BY SKU.Style, SKU.Sku   -- Follow the custom get task logic for this storer
            
            SET @cExtendedInfo = 'ID:' + @cId
         END   -- @nInputKey = 1
      END      -- @nStep IN (7, 8)
   END
   
   QUIT:    
END -- End Procedure  

GO