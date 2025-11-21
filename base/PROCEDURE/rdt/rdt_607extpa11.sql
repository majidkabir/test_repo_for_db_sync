SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607ExtPA11                                            */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2023-07-26   James     1.0   WMS-23005. Created                            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_607ExtPA11]
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cRefNo       NVARCHAR( 20), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,           
   @cLottable01  NVARCHAR( 18), 
   @cLottable02  NVARCHAR( 18), 
   @cLottable03  NVARCHAR( 18), 
   @dLottable04  DATETIME,      
   @dLottable05  DATETIME,      
   @cLottable06  NVARCHAR( 30), 
   @cLottable07  NVARCHAR( 30), 
   @cLottable08  NVARCHAR( 30), 
   @cLottable09  NVARCHAR( 30), 
   @cLottable10  NVARCHAR( 30), 
   @cLottable11  NVARCHAR( 30), 
   @cLottable12  NVARCHAR( 30), 
   @dLottable13  DATETIME,      
   @dLottable14  DATETIME,      
   @dLottable15  DATETIME, 
   @cReasonCode  NVARCHAR( 10), 
   @cID          NVARCHAR( 18), 
   @cLOC         NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 10), 
   @cSuggID      NVARCHAR( 18)  OUTPUT, 
   @cSuggLOC     NVARCHAR( 10)  OUTPUT, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUDF10      NVARCHAR( 30)
   DECLARE @cStyle      NVARCHAR( 20)
   DECLARE @cFacility   NVARCHAR( 5)
   
   IF @nFunc = 607 -- Return v7
   BEGIN
   	SET @cSuggID = ''
   	SET @cSuggLOC = ''
   	
      SELECT @cUDF10 = UserDefine10
      FROM dbo.RECEIPT WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      IF @cUDF10 = 'SKU'
      BEGIN
      	SELECT TOP 1 @cSuggLOC = ToLoc
      	FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      	WHERE ReceiptKey = @cReceiptKey
      	AND   Sku = @cSKU
      	AND   UserDefine10 <> 'closed'
      	ORDER BY EditDate DESC
      END
      ELSE IF @cUDF10 = 'ARTICLE'
      BEGIN
      	SELECT @cStyle = Style
      	FROM dbo.SKU WITH (NOLOCK)
      	WHERE StorerKey = @cStorerKey
      	AND   Sku = @cSKU
      	
      	SELECT TOP 1 @cSuggLOC = ToLoc
      	FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
      	JOIN dbo.SKU SKU WITH (NOLOCK) ON ( RD.StorerKey = SKU.StorerKey AND RD.Sku = SKU.Sku)
      	WHERE RD.ReceiptKey = @cReceiptKey
      	AND   SKU.Style = @cStyle
      	AND   RD.UserDefine10 <> 'closed'
      	ORDER BY RD.EditDate DESC
      END  	
      
      IF @cSuggLOC = ''
      BEGIN
      	SELECT @cFacility = Facility
      	FROM dbo.RECEIPT WITH (NOLOCK)
      	WHERE ReceiptKey = @cReceiptKey
      	
      	SELECT TOP 1 @cSuggLOC = Loc
      	FROM dbo.LOC LOC WITH (NOLOCK)
      	WHERE LOC.HOSTWHCODE = @cReceiptKey
      	AND   LOC.Facility = @cFacility
      	AND   LOC.Status = 'HOLD'
      	AND   NOT EXISTS ( SELECT 1
      	                   FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
      	                   WHERE RD.ReceiptKey = @cReceiptKey
      	                   AND   LOC.LOC = RD.ToLoc)
      	ORDER BY LOC.LogicalLocation
      END
      
      IF @cSuggLOC = ''
         SET @cSuggLOC = 'NO LOC'
   END
   
Quit:

END

SET QUOTED_IDENTIFIER OFF


GO