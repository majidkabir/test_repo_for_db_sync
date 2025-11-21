SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdtMHDDupFrMatchVal                                 */  
/* Copyright      : LF Logistic                                         */  
/*                                                                      */  
/* Purpose: Determine copy value from which ReceiptDetail line          */  
/*                                                                      */  
/* Date         Rev  Author      Purposes                               */  
/* 09-Jun-2014  1.0  James       Created                                */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdtMHDDupFrMatchVal]  
    @nMobile     INT  
   ,@nFunc       INT  
   ,@cLangCode   NVARCHAR(  3)  
   ,@cReceiptKey NVARCHAR( 10)  
   ,@cPOKey      NVARCHAR( 10)  
   ,@cToLOC      NVARCHAR( 10)  
   ,@cToID       NVARCHAR( 18)  
   ,@cLottable01 NVARCHAR( 18)  
   ,@cLottable02 NVARCHAR( 18)  
   ,@cLottable03 NVARCHAR( 18)  
   ,@dLottable04 DATETIME   
   ,@cSKU        NVARCHAR( 20)  
   ,@cUCC        NVARCHAR( 20)  
   ,@nQTY        INT  
   ,@cOrg_ReceiptLineNumber       NVARCHAR( 5)  
   ,@nOrg_QTYExpected             INT  
   ,@nOrg_BeforeReceivedQTY       INT  
   ,@cReceiptLineNumber           NVARCHAR( 5)  
   ,@nQTYExpected                 INT  
   ,@nBeforeReceivedQTY           INT  
   ,@cReceiptLineNumber_Borrowed  NVARCHAR( 5)  
   ,@cDuplicateFromLineNo         NVARCHAR( 5) OUTPUT   
   ,@nErrNo      INT              OUTPUT  
   ,@cErrMsg     NVARCHAR( 20)    OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   -- New line  
   SELECT TOP 1  
      @cDuplicateFromLineNo = ReceiptLineNumber  
   FROM ReceiptDetail WITH (NOLOCK)  
   WHERE ReceiptKey = @cReceiptKey  
      AND SKU = @cSKU  
      AND Lottable01 = @cLottable01  
      AND Lottable02 = @cLottable02  
      --AND Lottable03 = @cLottable03
   GROUP BY ReceiptLineNumber, ExternReceiptKey, ExternLineNo
   ORDER BY CASE WHEN SUM(QtyExpected) - SUM(BeforeReceivedQty) > 0 
                 THEN SUM(QtyExpected) - SUM(BeforeReceivedQty) ELSE 999999999 END,    
            ExternReceiptKey, ExternLineNo  
  
QUIT:  
END -- End Procedure  

GO