SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_537ExtVal02                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Check empty pallet. Build pallet rules                      */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-07-05 1.0  yeekung    wms-22977 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_537ExtVal02] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cFacility    NVARCHAR( 5),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
   @nQTY         INT,
   @cReasonCode  NVARCHAR( 10),
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
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLineNo NVARCHAR(5)

   IF @nFunc = 537 -- Line receiving
   BEGIN
      IF @nStep = 4-- LineNo
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cLineNo = I_Field02
            FROM RDT.Rdtmobrec (NOLOCK)
            WHERE mobile = @nMobile
               
            -- ID not in current ASN
            IF NOT EXISTS( SELECT 1 FROM ReceiptDetail WITH (NOLOCK) 
                           WHERE ReceiptKey = @cReceiptKey 
                              AND Lottable01 = @cID
                              AND Storerkey = @cStorerKey
                              AND receiptlinenumber = @cLineNo)
            BEGIN
               SET @nErrNo = 203651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidID
               GOTO QUIT
            END

         END
      END

   END

Quit:


GO