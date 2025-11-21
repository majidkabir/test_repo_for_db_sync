SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_JACKWExtInfoSP02                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: To retrieve ID & LOC where sku belong for return process.   */
/*          If SKU already in Zone, retrieve ID & LOC                   */
/*          If SKU not in Zone, retrieve base on ASN prev received SKU  */
/*                                                                      */
/* Called from: rdtfnc_Return                                           */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 06-08-2014 1.0  James    SOS317336 - Created                         */
/* 18-11-2014 1.1  CSCHONG  Added Lottables 06-15 (CS01)                */
/* 09-09-2015 1.1  James    Remove Lottables 06-15 temp as RDT Return   */
/*                          not ready for Lottables 06-15 (james01)     */
/************************************************************************/

CREATE PROC [dbo].[isp_JACKWExtInfoSP02] (
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
--   @dLottable05     DATETIME,            --(CS01) 
--   @cLottable06     NVARCHAR( 30),       --(CS01)
--   @cLottable07     NVARCHAR( 30),       --(CS01)
--   @cLottable08     NVARCHAR( 30),       --(CS01)
--   @cLottable09     NVARCHAR( 30),       --(CS01)
--   @cLottable10     NVARCHAR( 30),       --(CS01)
--   @cLottable11     NVARCHAR( 30),       --(CS01)
--   @cLottable12     NVARCHAR( 30),       --(CS01)
--   @dLottable13     DATETIME,            --(CS01) 
--   @dLottable14     DATETIME,            --(CS01) 
--   @dLottable15     DATETIME,            --(CS01) 
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

   DECLARE @cID         NVARCHAR( 18), 
           @cLOC        NVARCHAR( 10), 
           @cStorerKey  NVARCHAR( 15), 
           @cFacility   NVARCHAR( 5) 

   IF @nInputKey <> 1
      GOTO Quit

   IF @nStep NOT IN (3, 5, 6)
      GOTO Quit

   SELECT @cStorerKey = StorerKey, 
          @cFacility = Facility 
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SET @cID = ''
   SET @cLOC = ''

   IF @nStep IN (3, 5)
   BEGIN
      SELECT TOP 1 @cID = ISNULL( LLI.ID, '')
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.SKU = @cSKU
      AND   LOC.PutAwayZone = @cZone
      AND   LOC.Facility = @cFacility
      AND   (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0
      ORDER BY 1 DESC -- not empty come 1st

      IF ISNULL( @cID, '') = ''
         SELECT TOP 1 @cID = ISNULL( ToID, '')
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   SKU = @cSKU
         ORDER BY 1 DESC -- not empty come 1st

      SET @cExtendedInfo = @cID
   END

   IF @nStep IN (6)
   BEGIN
      SELECT TOP 1 @cLOC = ISNULL( LLI.LOC, '')
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.SKU = @cSKU
      AND   LLI.ID = @cToID
      AND   LOC.PutAwayZone = @cZone
      AND   LOC.Facility = @cFacility
      AND   (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0

      IF ISNULL( @cLOC, '') = ''
         SELECT TOP 1 @cLOC = ISNULL( ToLOC, '')
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   SKU = @cSKU
         AND   ToID = @cToID

      SET @cExtendedInfo = @cLOC
   END
   
   Quit:

END

GO