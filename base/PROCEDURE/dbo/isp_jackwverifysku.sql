SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: isp_JACKWVerifySKU                                  */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: JACKW Piece Receiving.Verify if need capture SKU weight info*/    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2014-07-21 1.0  James    SOS315958 Created                           */ 
/* 2014-11-18 1.1  CSCHONG  Added Lottables 06-15 (CS01)                */   
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[isp_JACKWVerifySKU]    
   @nStep        INT, 
   @nInputKey    INT, 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
   @cToID        NVARCHAR( 18), 
   @cLottable01  NVARCHAR( 18), 
   @cLottable02  NVARCHAR( 18), 
   @cLottable03  NVARCHAR( 18), 
   @dLottable04  DATETIME,  
   @dLottable05  DATETIME,            --(CS01) 
   @cLottable06  NVARCHAR( 30),       --(CS01)
   @cLottable07  NVARCHAR( 30),       --(CS01)
   @cLottable08  NVARCHAR( 30),       --(CS01)
   @cLottable09  NVARCHAR( 30),       --(CS01)
   @cLottable10  NVARCHAR( 30),       --(CS01)
   @cLottable11  NVARCHAR( 30),       --(CS01)
   @cLottable12  NVARCHAR( 30),       --(CS01)
   @dLottable13  DATETIME,            --(CS01) 
   @dLottable14  DATETIME,            --(CS01) 
   @dLottable15  DATETIME,            --(CS01) 
   @cStorer      NVARCHAR( 15), 
   @cSKU         NVARCHAR( 20), 
   @c_oFieled01  NVARCHAR( 20) OUTPUT
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @cWeight NVARCHAR( 10)
   
   IF @nStep <> 5 AND @nInputKey <> 1
      GOTO Quit

   SELECT @cWeight = STDGrossWGT 
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @cStorer
   AND   SKU = @cSKU

   -- If no weight then need goto weight capture screen
   IF ISNULL( CAST( @cWeight AS FLOAT), '0') <= 0
      SET @c_oFieled01 = '1'
   ELSE
      SET @c_oFieled01 = ''
     
QUIT:    
END -- End Procedure  

GO