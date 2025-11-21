SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1580ExtInfo01                                   */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Display Count                                               */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2018-04-19 1.0  ChewKP   WMS-4126 Created                            */
/* 2022-05-19 1.1  Ung      WMS-19667 Migrate to new ExtendedInfoSP     */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1580ExtInfo01] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nAfterStep      INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cReceiptKey     NVARCHAR( 10)
   ,@cPOKey          NVARCHAR( 10)
   ,@cRefNo          NVARCHAR( 20)
   ,@cToLOC          NVARCHAR( 10)
   ,@cToID           NVARCHAR( 18)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@tVar            VariableTable READONLY
   ,@cExtendedInfo   NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nBeforeReceivedQty     INT
          ,@nQtyExpected           INT

   IF @nStep = 4
   BEGIN
      SET @nBeforeReceivedQty = 0
      SET @nQtyExpected = 0

      SET @cExtendedInfo = 'SKU CNT: ' + RIGHT(Replicate(' ',4) + CAST(@nBeforeReceivedQty As VARCHAR(4)), 4)  + ' / ' + RIGHT(Replicate(' ',4) + CAST(@nQtyExpected As VARCHAR(4)), 4)
   END

   IF @nAfterStep = 5
   BEGIN
      SELECT
      @nBeforeReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0) +  1 ,
      @nQtyExpected = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE Receiptkey = @cReceiptKey
      --AND   POKey      = @cPOKey
      AND   SKU        = @cSKU
      --AND   ToID       = @cToID
      AND   ToLoc      = @cToLoc
      AND   Storerkey  = @cStorerKey
      AND   FinalizeFlag = 'N'

      SET @cExtendedInfo = 'SKU CNT: ' + RIGHT(Replicate(' ',4) + CAST(@nBeforeReceivedQty As VARCHAR(4)), 4)  + ' / ' + RIGHT(Replicate(' ',4) + CAST(@nQtyExpected As VARCHAR(4)), 4)
      --SELECT @nScanCount '@nScanCount' , @nCaseCnt '@nCaseCnt' , @cOutPutText '@cOutPutText'
   END

END

GO