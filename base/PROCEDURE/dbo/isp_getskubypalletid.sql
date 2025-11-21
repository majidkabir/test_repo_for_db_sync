SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: isp_GetSKUByPalletID                                */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Decode pallet id and return sku if                          */
/*          1 pallet 1 sku No Scanned                                   */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2014-03-27 1.0  James    SOS305458 Created                           */    
/* 2014-05-08 1.1  James    SOS310761 - Extra pallet id check (james01) */
/* 2014-06-16 1.2  James    SOS313838 - New Pallet ID check (james02)   */
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[isp_GetSKUByPalletID]    
   @nMobile         INT,      
   @cStorer         NVARCHAR( 15),     
   @cReceiptKey     NVARCHAR( 10),    
   @cPOKey          NVARCHAR( 10),     
   @cLOC            NVARCHAR( 10),     
   @cID             NVARCHAR( 30), -- (cutomize Plt ID 30 digits)
   @cSKU            NVARCHAR( 20),       
   @nQTY            INT,       
   @cUOM            NVARCHAR( 10),    
   @cLottable01     NVARCHAR( 18),       
   @cLottable02     NVARCHAR( 18),       
   @cLottable03     NVARCHAR( 18),       
   @cLottable04     NVARCHAR( 16),       
   @cLottable05     NVARCHAR( 16),       
   @cO_ID           NVARCHAR( 18) OUTPUT,       
   @cO_SKU          NVARCHAR( 20) OUTPUT,       
   @nO_QTY          INT           OUTPUT,       
   @cO_UOM          NVARCHAR( 10) OUTPUT,       
   @cO_Lottable01   NVARCHAR( 18) OUTPUT,       
   @cO_Lottable02   NVARCHAR( 18) OUTPUT,       
   @cO_Lottable03   NVARCHAR( 18) OUTPUT,       
   @cO_Lottable04   NVARCHAR( 16) OUTPUT,       
   @cO_Lottable05   NVARCHAR( 16) OUTPUT,       
   @cExtendedInfo   NVARCHAR( 20) OUTPUT, 
   @cExtendedInfo2  NVARCHAR( 20) OUTPUT, 
   @nValid          INT           OUTPUT  
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @nSKUCount      INT, 
           @nLotCount      INT 

   SET @nValid = 1

   IF ISNULL( @cID, '') = '' 
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                      WHERE StorerKey = @cStorer
                      AND   ReceiptKey = @cReceiptKey
                      AND   ISNULL( ToID, '') = ''
                      AND   FinalizeFlag = 'N')
      BEGIN
         SET @nValid = 0
         GOTO Quit
      END
      ELSE
         GOTO Quit
   END

/*-- comment (james02)
   IF LEN( RTRIM( @cID)) < 18  
      SET @cO_ID = RTRIM( @cID)
   ELSE
      SET @cO_ID = RIGHT( @cID, 18)
*/

   IF SUBSTRING (@cID, 1, 4) = '(00)' 
      SET @cO_ID = SUBSTRING (RTRIM( @cID), 5, 18)
   ELSE
      SET @cO_ID = LEFT( RTRIM( @cID), 18)

   SET @cO_SKU = ''
   SET @nSKUCount = 0
   SET @cO_Lottable01 = ''
   SET @cO_Lottable02 = ''
   SET @cO_Lottable03 = ''
   SET @cO_Lottable04 = ''

   IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                   WHERE StorerKey = @cStorer
                   AND   ReceiptKey = @cReceiptKey
                   AND   ToID = @cO_ID
                   AND   FinalizeFlag = 'N')
   BEGIN
      SET @nValid = 0
      GOTO Quit
   END

   -- Check if pallet fully received. Return error if it has   (james01)
   IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
               WHERE receiptkey = @cReceiptKey
               AND   TOID = @cO_ID
               HAVING (ISNULL( SUM( BEFORERECEIVEDQTY), 0) = ISNULL( SUM( QtyExpected), 0)))
   BEGIN
      SET @nValid = 0
      GOTO Quit
   END

   SELECT @nSKUCount = COUNT( DISTINCT SKU)
   FROM dbo.ReceiptDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorer
   AND   ReceiptKey = @cReceiptKey
   AND   ToID = @cO_ID
   
   IF @nSKUCount = 1
      -- If 1 pallet only contain 1 SKU
      SELECT TOP 1 @cO_SKU = SKU 
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorer
      AND   ReceiptKey = @cReceiptKey
      AND   ToID = @cO_ID

   SELECT @nLotCount = COUNT( DISTINCT CASE WHEN RTRIM( ISNULL( Lottable01, '')) = '' THEN 'L1' ELSE RTRIM( ISNULL( Lottable01, '')) END 
                                      + CASE WHEN RTRIM( ISNULL( Lottable02, '')) = '' THEN 'L2' ELSE RTRIM( ISNULL( Lottable02, '')) END 
                                      + CASE WHEN RTRIM( ISNULL( Lottable03, '')) = '' THEN 'L3' ELSE RTRIM( ISNULL( Lottable03, '')) END 
                                      + CASE WHEN ISNULL( Lottable04, 0) = 0 THEN 'L4' ELSE CAST ( Lottable04 AS NVARCHAR( 20)) END )
   FROM dbo.ReceiptDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorer
   AND   ReceiptKey = @cReceiptKey
   AND   ToID = @cO_ID
   AND   SKU = @cO_SKU

   IF @nLotCount = 1
      -- If 1 pallet + SKU only contain 1 distinct batch no/lottables
      SELECT 
         @cO_Lottable01 = Lottable01, 
         @cO_Lottable02 = Lottable02, 
         @cO_Lottable03 = Lottable03, 
         @cO_Lottable04 = Lottable04 
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorer
      AND   ReceiptKey = @cReceiptKey
      AND   ToID = @cO_ID
      AND   SKU = @cO_SKU

   

QUIT:    
END -- End Procedure    

GO