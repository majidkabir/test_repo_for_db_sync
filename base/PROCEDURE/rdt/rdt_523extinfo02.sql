SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_523ExtInfo02                                    */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 18-12-2017 1.0  ChewKP   WMS-3502 Created                            */  
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_523ExtInfo02]    
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT, 
   @nAfterStep      INT, 
   @nInputKey       INT,                
   @cStorerKey      NVARCHAR( 15), 
   @cFacility       NVARCHAR( 5),  
   @cLOC            NVARCHAR( 10), 
   @cID             NVARCHAR( 18), 
   @cSKU            NVARCHAR( 20), 
   @nQTY            INT,  
   @cSuggestedLOC   NVARCHAR( 10),  
   @cFinalLOC       NVARCHAR( 10), 
   @cOption         NVARCHAR( 1), 
   @cExtendedInfo1  NVARCHAR( 20) OUTPUT
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @nPABookingKey INT 
          ,@cToID         NVARCHAR(18) 

   IF @nFunc = 523 -- Putaway by SKU
   BEGIN
      IF @nAfterStep = 4  -- Suggest LOC, final LOC
      BEGIN
        
         SELECT @nPABookingKey = V_String19
         FROM rdt.rdtmobRec WITH (NOLOCK) 
         WHERE Mobile = @nMobile
         
         IF @nPABookingKey <> 0 
         BEGIN 
            SELECT @cToID = ID 
            FROM dbo.RFPutaway WITH (NOLOCK) 
            WHERE PABookingKey = @nPABookingKey
      
            SET @cExtendedInfo1 = @cToID
         END
         ELSE
         BEGIN
            SET @cExtendedInfo1 = ''
         END
      END
   END
   
Quit:
    
END

GO