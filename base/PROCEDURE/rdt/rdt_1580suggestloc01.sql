SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580SuggestLoc01                                */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: To set Loc by ASN                                           */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 09-06-2021  1.0  Chermaine   WMS-16328. Created                      */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1580SuggestLoc01]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cReceiptKey  NVARCHAR( 10) 
   ,@cPOKey       NVARCHAR( 10) 
   ,@cExtASN      NVARCHAR( 20)
   ,@cToLOC       NVARCHAR( 10) 
   ,@cToID        NVARCHAR( 18) 
   ,@cLottable01  NVARCHAR( 18) 
   ,@cLottable02  NVARCHAR( 18) 
   ,@cLottable03  NVARCHAR( 18) 
   ,@dLottable04  DATETIME  
   ,@cSKU         NVARCHAR( 20) 
   ,@nQTY         INT
   ,@nAfterStep   INT
   ,@cSuggestedLoc NVARCHAR( 10) OUTPUT
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   --Default toloc form the top 1 receiptdetail.toloc where QtyExpected > 0 and isnull(toloc,ÆÆ) <> æÆ  if it is not found, do not default any value.
   
   IF @cReceiptKey <> ''
   BEGIN
   	SELECT TOP 1 
   	   @cSuggestedLoc = toLoc 
   	FROM RECEIPTDETAIL WITH (NOLOCK) 
   	WHERE StorerKey = @cStorerKey 
   	AND QtyExpected > 0 
   	AND toLoc <> '' 
   	AND receiptKey = @cReceiptKey  
   	ORDER BY EditDate
   END

   QUIT:
END

GO