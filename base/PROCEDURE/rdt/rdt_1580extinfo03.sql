SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580ExtInfo03                                      */
/* Copyright      : LFLogistics                                            */
/*                                                                         */
/* Purpose: Display Count                                                  */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2022-05-19 1.0  Ung        WMS-19667 Migrate from ispPieceRcvExtInfo11  */
/***************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtInfo03] (
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

   DECLARE @nCartonQTY INT

   IF @nFunc = 1580 -- Piece receiving
   BEGIN
      IF @nAfterStep = 5 -- SKU, QTY
      BEGIN
         IF @cLottable01 <> '' -- Carton ID
         BEGIN
            SELECT @nCartonQTY = ISNULL( SUM( BeforeReceivedQty), 0)
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE Receiptkey = @cReceiptKey
               AND ToLOC = @cToLOC
               AND ToID = @cToID
               AND Storerkey  = @cStorerKey
               -- AND SKU = @cSKU
               AND Lottable01 = @cLottable01

            DECLARE @cMsg NVARCHAR( 20)
            SET @cMsg = rdt.rdtgetmessage( 184001, @cLangCode, 'DSP') --CARTON QTY:
            
            SET @cExtendedInfo = RTRIM( @cMsg) + ' ' + CAST( @nCartonQTY AS NVARCHAR(5))
         END
      END
   END
END

GO