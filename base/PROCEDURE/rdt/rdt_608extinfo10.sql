SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_608ExtInfo10                                    */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Show suggested loc for PA                                   */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2023-03-05  1.0  YeeKung  WMS-22290. Created                         */
/************************************************************************/    

CREATE   PROC [RDT].[rdt_608ExtInfo10] (    
  @nMobile       INT,           
  @nFunc         INT,           
  @cLangCode     NVARCHAR( 3),  
  @nStep         INT,           
  @nAfterStep    INT,           
  @nInputKey     INT,           
  @cFacility     NVARCHAR( 5),  
  @cStorerKey    NVARCHAR( 15), 
  @cReceiptKey   NVARCHAR( 10), 
  @cPOKey        NVARCHAR( 10), 
  @cRefNo        NVARCHAR( 60), 
  @cID           NVARCHAR( 18), 
  @cLOC          NVARCHAR( 10), 
  @cMethod       NVARCHAR( 1),  
  @cSKU          NVARCHAR( 20), 
  @nQTY          INT,           
  @cLottable01   NVARCHAR( 18), 
  @cLottable02   NVARCHAR( 18), 
  @cLottable03   NVARCHAR( 18), 
  @dLottable04   DATETIME,      
  @dLottable05   DATETIME,      
  @cLottable06   NVARCHAR( 30), 
  @cLottable07   NVARCHAR( 30), 
  @cLottable08   NVARCHAR( 30), 
  @cLottable09   NVARCHAR( 30), 
  @cLottable10   NVARCHAR( 30), 
  @cLottable11   NVARCHAR( 30), 
  @cLottable12   NVARCHAR( 30), 
  @dLottable13   DATETIME,      
  @dLottable14   DATETIME,      
  @dLottable15   DATETIME,      
  @cRDLineNo     NVARCHAR( 10), 
  @cExtendedInfo NVARCHAR(20)  OUTPUT, 
  @nErrNo        INT           OUTPUT, 
  @cErrMsg       NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
   
   DECLARE  @cSuggestedLoc NVARCHAR(20),
            @cStyle NVARCHAR(20)

   IF @nStep IN(3,4)
   BEGIN
      IF @nInputKey = 1
      BEGIN

         SELECT @cSKU = I_Field03
         FROM rdt.rdtmobrec (NOLOCK)
         WHERE Mobile = @nmobile

         SELECT TOP 1 @cSuggestedLoc = LLI.LOC
         FROM dbo.lotxlocxid LLI WITH (NOLOCK)
            JOIN LOC LOC (NOLOCK) ON LLI.LOC = LOC.LOC
         WHERE SKU = @cSKU
            AND Storerkey = @cStorerKey
            AND Loc.LocationType = 'PICK'
         GROUP BY LLI.Loc
         HAVING SUM( qty -QtyAllocated - QtyPicked) > 0
         ORDER BY SUM( qty -QtyAllocated - QtyPicked) DESC

         IF ISNULL(@cSuggestedLoc,'') =''
         BEGIN
            SELECT @cStyle = style
            FROM SKU (NOLOCK)
            WHERE SKU = @cSKU
               AND Storerkey = @cStorerKey

            
            SELECT TOP 1 @cSuggestedLoc = LLI.LOC
            FROM dbo.lotxlocxid LLI WITH (NOLOCK)
               JOIN LOC LOC (NOLOCK) ON LLI.LOC = LOC.LOC
               JOIN SKU SKU (NOLOCK) ON SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey
            WHERE  SKU.Storerkey = @cStorerKey
               AND SKU.Style = @cStyle
               AND Loc.LocationType = 'PICK'
            GROUP BY LLI.Loc
            HAVING SUM( qty -QtyAllocated - QtyPicked) > 0
            ORDER BY SUM( qty -QtyAllocated - QtyPicked) DESC
         END

         
         IF ISNULL(@cSuggestedLoc,'') =''
         BEGIN
            SELECT @cSuggestedLoc = PutawayZone
            FROM SKU (NOLOCK)
            WHERE SKU = @cSKU
               AND Storerkey = @cStorerKey

         END

         SET @cExtendedInfo = 'SUGLOC: ' + @cSuggestedLoc
      END
   END
END     

GO