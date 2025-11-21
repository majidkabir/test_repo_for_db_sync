SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_552ExtInfo01                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Look up and display location where SKU resides.             */
/*          If SKU already in Zone, retrieve LOC                        */
/*          If SKU not in Zone, look for empty pick loc.                */
/*          If pick loc not setup or full return error                  */
/*                                                                      */
/* Called from: rdtfnc_Return                                           */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 23-24-2015 1.0  James    SOS334084 - Created                         */
/************************************************************************/

CREATE PROC [dbo].[isp_552ExtInfo01] (
   @nMobile         INT,   
   @nFunc           INT,  
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,   
   @nInputKey       INT,    
   @cZone           NVARCHAR( 10), 
   @cReceiptKey     NVARCHAR( 10),   
   @cPOKey          NVARCHAR( 10),   
   @cSKU            NVARCHAR( 20),   
   @nQTY            INT,    
   @cLottable01     NVARCHAR( 18),    
   @cLottable02     NVARCHAR( 18),   
   @cLottable03     NVARCHAR( 18),  
   @dLottable04     DATETIME,     
   @cConditionCode  NVARCHAR( 10),  
   @cSubReason      NVARCHAR( 10),  
   @cToLOC          NVARCHAR( 10),  
   @cToID           NVARCHAR( 18),  
   @cExtendedInfo   NVARCHAR( 20)   OUTPUT,  
   @nErrNo          INT             OUTPUT, 
   @cErrMsg         NVARCHAR( 20)   OUTPUT  
 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cStorerKey     NVARCHAR( 15), 
           @cFacility      NVARCHAR( 5) 

   SELECT @cStorerKey = StorerKey, 
          @cFacility = Facility 
   FROM dbo.Receipt WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 5
      BEGIN
         SET @cZone = ''

         -- Look for sku in same zone
         SELECT TOP 1 @cZone = LOC.PutawayZone  
         FROM dbo.SKUxLOC SL WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         JOIN dbo.LotxLocxID LLI WITH (NOLOCK) on (SL.LOC = LLI.LOC AND SL.SKU = LLI.SKU)
         WHERE SL.StorerKey = @cStorerKey
         AND SL.SKU = @cSKU
         AND SL.LocationType IN ('CASE', 'PICK') 
         AND   (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0
         ORDER BY 1

         -- If no loc found for same sku then look for empty loc
         IF ISNULL( @cZone, '') = ''
            SELECT TOP 1 @cZone = LOC.PutawayZone  
            FROM dbo.SKUxLOC SL WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
            WHERE SL.StorerKey = @cStorerKey
            AND SL.SKU = @cSKU
            AND SL.LocationType IN ('CASE', 'PICK') 
            ORDER BY 1

         IF ISNULL( @cZone, '') = ''
         BEGIN
            SET @cExtendedInfo = ''
            GOTO Quit
         END
         ELSE
         BEGIN
            SET @cExtendedInfo = 'SKU LOC FOUND IN ' + @cZone
         END
      END
   END
   
   Quit:

END

GO