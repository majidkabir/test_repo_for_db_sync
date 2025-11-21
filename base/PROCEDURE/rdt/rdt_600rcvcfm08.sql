SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600RcvCfm08                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Copy receive QTY to L12                                           */
/*                                                                            */
/* Date        Author      Ver.  Purposes                                     */
/* 25-11-2020  Chermaine   1.0   WMS-15711 Created                            */
/* 19-11-2020  YeeKung   1.1   WMS-15597 Add SerialNo(yeekung01)              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_600RcvCfm08] (
   @nFunc          INT,           
   @nMobile        INT,           
   @cLangCode      NVARCHAR( 3),  
   @cStorerKey     NVARCHAR( 15), 
   @cFacility      NVARCHAR( 5),  
   @cReceiptKey    NVARCHAR( 10), 
   @cPOKey         NVARCHAR( 10), 
   @cToLOC         NVARCHAR( 10), 
   @cToID          NVARCHAR( 18), 
   @cSKUCode       NVARCHAR( 20), 
   @cSKUUOM        NVARCHAR( 10), 
   @nSKUQTY        INT,           
   @cUCC           NVARCHAR( 20), 
   @cUCCSKU        NVARCHAR( 20), 
   @nUCCQTY        INT,           
   @cCreateUCC     NVARCHAR( 1),  
   @cLottable01    NVARCHAR( 18), 
   @cLottable02    NVARCHAR( 18), 
   @cLottable03    NVARCHAR( 18), 
   @dLottable04    DATETIME,      
   @dLottable05    DATETIME,      
   @cLottable06    NVARCHAR( 30), 
   @cLottable07    NVARCHAR( 30), 
   @cLottable08    NVARCHAR( 30), 
   @cLottable09    NVARCHAR( 30), 
   @cLottable10    NVARCHAR( 30), 
   @cLottable11    NVARCHAR( 30), 
   @cLottable12    NVARCHAR( 30), 
   @dLottable13    DATETIME,      
   @dLottable14    DATETIME,      
   @dLottable15    DATETIME,      
   @nNOPOFlag      INT,           
   @cConditionCode NVARCHAR( 10), 
   @cSubreasonCode NVARCHAR( 10), 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
   @cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT,
   @cSerialNo      NVARCHAR( 30) = '',   
   @nSerialQTY     INT = 0,   
   @nBulkSNO       INT = 0,   
   @nBulkSNOQTY    INT = 0 
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nFunc = 600 -- Normal receiving
   BEGIN
   	DECLARE @nToReceive           INT
   	DECLARE @nBeforeReceivedQTY   INT
   	DECLARE @nQTYExpected_Total   INT
   	DECLARE @b_success            INT
   	DECLARE @cAllow_OverReceipt   NVARCHAR( 1) 
   	DECLARE @c_Option5             NVARCHAR(4000)
   	DECLARE @cIncludeReceiptGroup NVARCHAR(4000)
   	
   	SET @nToReceive = 0
   	
   	-- Storer config 'Allow_OverReceipt'  
      EXECUTE dbo.nspGetRight  
         NULL, -- Facility  
         @cStorerKey,  
         '',  --SKU
         'Allow_OverReceipt',  
         @b_success              OUTPUT,  
         @cAllow_OverReceipt     OUTPUT,  
         @nErrNo                 OUTPUT,  
         @cErrMsg                OUTPUT,
         @c_Option5              OUTPUT  
         
      IF @b_success <> 1  
      BEGIN  
         SET @nErrNo = 160901  
         SET @cErrMsg = rdt.rdtgetmessage( 60301, @cLangCode, 'DSP') --'nspGetRight'  
         GOTO Quit  
      END  
      
      IF ISNULL(@c_Option5,'') <> ''  
      BEGIN  
         SELECT @cIncludeReceiptGroup = dbo.fnc_GetParamValueFromString('@cIncludeReceiptGroup', @c_Option5, @cIncludeReceiptGroup)   
      END
             
   	SELECT 
   	   @nBeforeReceivedQTY = SUM( BeforeReceivedQTY)
   	   ,@nQTYExpected_Total = SUM(QTYExpected) 
   	FROM receiptDetail (NOLOCK)
   	WHERE receiptKey = @cReceiptKey
   	AND SKU = @cSKUCode
   	
   	
   	--over receive
      IF (@nSKUQTY + @nBeforeReceivedQTY) > @nQTYExpected_Total
      BEGIN
      	IF @cAllow_OverReceipt  = 1 AND ISNULL(@cIncludeReceiptGroup,'') <> ''  
         BEGIN  
         	IF NOT EXISTS (SELECT 1 FROM RECEIPT (NOLOCK) WHERE Receiptkey = @cReceiptKey AND ReceiptGroup IN (SELECT ColValue from dbo.fnc_delimsplit (',',@cIncludeReceiptGroup)) )  
      	   BEGIN
      	   	--over receive with config but not in ReceiptGroup(option5)
      	   	SET @nToReceive = 0
      	   	
      		   SET @nErrNo = 160902  
               SET @cErrMsg = rdt.rdtgetmessage( 60301, @cLangCode, 'DSP') --'DiffRcvGroup' 
      	   	GOTO Quit
      	   END  
      	   ELSE
      	   BEGIN
      	   	--over Receive with config but in ReceiptGroup(option5)
      	   	SET @nToReceive = 1
      	   END
         END
         
      	IF @cAllow_OverReceipt = 1 AND ISNULL(@cIncludeReceiptGroup,'') = ''
      	BEGIN
      		--over receive with config 
      		SET @nToReceive = 1
      	END	
      END
      ELSE
      BEGIN
      	--no over receive
      	SET @nToReceive = 1
      END
      
      
      IF @nToReceive = 1
      BEGIN
      	-- Receive
         EXEC rdt.rdt_Receive_V7
            @nFunc         = @nFunc,
            @nMobile       = @nMobile,
            @cLangCode     = @cLangCode,
            @nErrNo        = @nErrNo OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT,
            @cStorerKey    = @cStorerKey,
            @cFacility     = @cFacility,
            @cReceiptKey   = @cReceiptKey,
            @cPOKey        = @cPOKey,  
            @cToLOC        = @cToLOC,
            @cToID         = @cToID,
            @cSKUCode      = @cSKUCode,
            @cSKUUOM       = @cSKUUOM,
            @nSKUQTY       = @nSKUQTY,
            @cUCC          = '',
            @cUCCSKU       = '',
            @nUCCQTY       = '',
            @cCreateUCC    = '',
            @cLottable01   = @cLottable01,
            @cLottable02   = @cLottable02,
            @cLottable03   = @cLottable03,
            @dLottable04   = @dLottable04,
            @dLottable05   = NULL,
            @cLottable06   = @cLottable06,
            @cLottable07   = @cLottable07,
            @cLottable08   = @cLottable08,
            @cLottable09   = @cLottable09,
            @cLottable10   = @cLottable10,
            @cLottable11   = @cLottable11,
            @cLottable12   = @cLottable12,
            @dLottable13   = @dLottable13,
            @dLottable14   = @dLottable14,
            @dLottable15   = @dLottable15,
            @nNOPOFlag     = @nNOPOFlag,
            @cConditionCode = @cConditionCode,
            @cSubreasonCode = '', 
            @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT  
      END
       
   END
   
Quit:
   
END

GO