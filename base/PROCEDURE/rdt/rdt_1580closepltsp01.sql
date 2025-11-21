SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_1580ClosePltSP01                                */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Purpose: Display Count                                               */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-07-22 1.0  Chermaine  WMS-16328 Created                         */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_1580ClosePltSP01] (  
  @cReceiptKey   NVARCHAR( 10),   
  @cPOKey        NVARCHAR( 10),   
  @cLOC          NVARCHAR( 10),   
  @cToID         NVARCHAR( 18),   
  @cLottable01   NVARCHAR( 18),   
  @cLottable02   NVARCHAR( 18),   
  @cLottable03   NVARCHAR( 18),   
  @dLottable04   DATETIME,    
  @cStorer       NVARCHAR( 15),   
  @cSKU          NVARCHAR( 20),   
  @cClosePallet  NVARCHAR( 1) OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   IF EXISTS (SELECT 1 FROM RECEIPT WITH (NOLOCK) WHERE StorerKey = @cStorer AND ReceiptKey = @cReceiptKey AND UserDefine03 = 'DT')
   BEGIN
   	SET @cClosePallet = '0'
   END
   ELSE
   BEGIN
   	SET @cClosePallet = '1'
   END  
END  

GO