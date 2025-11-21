SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_PieceReceiving_Confirm                             */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2017-05-04 1.0  Ung     WMS-1817 Created                                */
/* 2018-08-02 1.1  Ung     WMS-5722 Add bulk serial no                     */
/***************************************************************************/
CREATE PROC [RDT].[rdt_PieceReceiving_Confirm](
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
   @cSerialNo      NVARCHAR( 30), 
   @nSerialQTY     INT, 
   @nBulkSNO       INT = 0, 
   @nBulkSNOQTY    INT = 0
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cRcptConfirmSP NVARCHAR( 20)

   -- Get storer configure
   SET @cRcptConfirmSP = rdt.RDTGetConfig( @nFunc, 'ReceiptConfirm_SP', @cStorerKey)
   IF @cRcptConfirmSP = '0'
      SET @cRcptConfirmSP = ''

   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   -- Custom receive logic
   IF @cRcptConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRcptConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cRcptConfirmSP) +
            ' @nFunc, @nMobile, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, ' +
            ' @cToLOC, @cToID, @cSKUCode, @cSKUUOM, @nSKUQTY, @cUCC, @cUCCSKU, @nUCCQTY, @cCreateUCC, @cLottable01, ' +
            ' @cLottable02, @cLottable03, @dLottable04, @dLottable05, @nNOPOFlag, @cConditionCode, @cSubreasonCode, ' + 
            ' @cReceiptLineNumber OUTPUT, @cSerialNo, @nSerialQTY, @nBulkSNO, @nBulkSNOQTY '

         SET @cSQLParam =
            '@nFunc          INT,            ' +
            '@nMobile        INT,            ' +
            '@cLangCode      NVARCHAR( 3),   ' +
            '@nErrNo         INT   OUTPUT,   ' +
            '@cErrMsg        NVARCHAR( 20) OUTPUT,  ' +
            '@cStorerKey     NVARCHAR( 15),  ' +
            '@cFacility      NVARCHAR( 5),   ' +
            '@cReceiptKey    NVARCHAR( 10),  ' +
            '@cPOKey         NVARCHAR( 10),  ' +
            '@cToLOC         NVARCHAR( 10),  ' +
            '@cToID          NVARCHAR( 18),  ' +
            '@cSKUCode       NVARCHAR( 20),  ' +
            '@cSKUUOM        NVARCHAR( 10),  ' +
            '@nSKUQTY        INT,            ' +
            '@cUCC           NVARCHAR( 20),  ' +
            '@cUCCSKU        NVARCHAR( 20),  ' +
            '@nUCCQTY        INT,            ' +
            '@cCreateUCC     NVARCHAR( 1),   ' +
            '@cLottable01    NVARCHAR( 18),  ' +
            '@cLottable02    NVARCHAR( 18),  ' +
            '@cLottable03    NVARCHAR( 18),  ' +
            '@dLottable04    DATETIME,       ' +
            '@dLottable05    DATETIME,       ' +
            '@nNOPOFlag      INT,            ' +
            '@cConditionCode NVARCHAR( 10),  ' +
            '@cSubreasonCode NVARCHAR( 10),  ' + 
            '@cReceiptLineNumber NVARCHAR( 5) OUTPUT, ' + 
            '@cSerialNo      NVARCHAR( 30),  ' + 
            '@nSerialQTY     INT,            ' + 
            '@nBulkSNO       INT,            ' + 
            '@nBulkSNOQTY    INT             '
            
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nFunc, @nMobile, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, 
            @cToLOC, @cToID, @cSKUCode, @cSKUUOM, @nSKUQTY, @cUCC, @cUCCSKU, @nUCCQTY, @cCreateUCC, @cLottable01, 
            @cLottable02, @cLottable03, @dLottable04, @dLottable05, @nNOPOFlag, @cConditionCode, @cSubreasonCode, 
            @cReceiptLineNumber OUTPUT, @cSerialNo, @nSerialQTY, @nBulkSNO, @nBulkSNOQTY

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
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
      @cToID          = @cTOID,
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
      @cSubreasonCode = @cSubreasonCode, 
      @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT, 
      @cSerialNo      = @cSerialNo, 
      @nSerialQTY     = @nSerialQTY, 
      @nBulkSNO       = @nBulkSNO, 
      @nBulkSNOQTY    = @nBulkSNOQTY

Quit:

END

GO