SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580RcptCfm15                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2019-10-29 1.0  James   WMS-5467 Created                                */
/* 2023-04-13 1.1  James   WMS-21975 Change I_Field02->V_Barcode (james01) */
/***************************************************************************/
CREATE   PROC [RDT].[rdt_1580RcptCfm15](
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
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
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT, 
   @cSerialNo      NVARCHAR( 30) = '', 
   @nSerialQTY     INT = 0, 
   @nBulkSNO       INT = 0,
   @nBulkSNOQTY    INT = 0
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cInField02  NVARCHAR( 60)
   DECLARE @n_Seqno     INT
   DECLARE @c_ColValue  NVARCHAR( 60)
   DECLARE @cSUSR3      NVARCHAR( 18)
   DECLARE @nQtyExpected_Total         INT
   DECLARE @nBeforeReceivedQty_Total   INT
   DECLARE @cReceivingTypeNotAllowOverRcpt  NVARCHAR( 20)
   
   SELECT @cInField02 = r.V_Barcode
   FROM RDT.RDTMOBREC AS r WITH (NOLOCK)
   WHERE r.Mobile = @nMobile
   
   DECLARE @c_Delim CHAR(1)       
   DECLARE @t_WCSRec TABLE (      
      Seqno    INT,       
      ColValue VARCHAR(215) )      
  
   SET @c_Delim = ';'  
   INSERT INTO @t_WCSRec     
   SELECT * FROM dbo.fnc_DelimSplit(@c_Delim, @cInField02)   
  
   DECLARE @curD CURSOR    
   SET @curD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT Seqno, ColValue FROM @t_WCSRec ORDER BY Seqno  
   OPEN @curD  
   FETCH NEXT FROM @curD INTO @n_Seqno, @c_ColValue  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      IF @n_Seqno = 1 SET @cToID = @c_ColValue  
      IF @n_Seqno = 2 SET @cSKUCode = @c_ColValue  
      IF @n_Seqno = 3 SET @cLottable01 = @c_ColValue  
      IF @n_Seqno = 4 SET @nSKUQTY = CAST( @c_ColValue AS INT)  
  
      FETCH NEXT FROM @curD INTO @n_Seqno, @c_ColValue  
   END 
   
   SET @cReceivingTypeNotAllowOverRcpt = rdt.RDTGetConfig( @nFunc, 'ReceivingTypeNotAllowOverRcpt', @cStorerKey) 
   
   SELECT @cSUSR3 = SUSR3 
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKUCode

   IF @cReceivingTypeNotAllowOverRcpt = @cSUSR3
   BEGIN
      SELECT @nQtyExpected_Total = ISNULL( SUM( QtyExpected), 0),
             @nBeforeReceivedQty_Total = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   Sku = @cSKUCode
      
      IF (@nBeforeReceivedQty_Total + @nSKUQTY) > @nQtyExpected_Total
      BEGIN
         SET @nErrNo = 151101
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Received
         GOTO Quit
      END
   END

   -- Get ASN
   SELECT TOP 1 
      @cLottable02 = RD.Lottable02,
      @cLottable03 = RD.Lottable03
   FROM ReceiptDetail RD WITH (NOLOCK) 
   WHERE RD.ReceiptKey = @cReceiptKey
   AND   RD.SKU = @cSKUCode
   AND   RD.Lottable01 = @cLottable01
   ORDER BY 1      

   EXEC rdt.rdt_Receive
      @nFunc          = @nFunc,
      @nMobile        = @nMobile,
      @cLangCode      = @cLangCode,
      @nErrNo         = @nErrNo  OUTPUT,
      @cErrMsg        = @cErrMsg OUTPUT,
      @cStorerKey     = @cStorerKey,
      @cFacility      = @cFacility,
      @cReceiptKey    = @cReceiptKey,
      @cPOKey         = @cPOKey,
      @cToLOC         = @cToLOC,
      @cToID          = @cToID,
      @cSKUCode       = @cSKUCode,
      @cSKUUOM        = @cSKUUOM,
      @nSKUQTY        = @nSKUQTY,
      @cUCC           = @cUCC,
      @cUCCSKU        = @cUCCSKU,
      @nUCCQTY        = @nUCCQTY,
      @cCreateUCC     = @cCreateUCC,
      @cLottable01    = @cLottable01,
      @cLottable02    = @cLottable02,   
      @cLottable03    = @cLottable03,
      @dLottable04    = @dLottable04,
      @dLottable05    = @dLottable05,
      @nNOPOFlag      = @nNOPOFlag,
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = @cSubreasonCode
      
   IF @nErrNo <> 0
      GOTO Quit

Quit:

END

GO