SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_600ExtInfo07                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 25-05-2023  yeekung    1.0   WMS-22369 Created                             */
/* 26-06-2023  yeekung    1.1   WMS-22921 change count UCC                    */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_600ExtInfo07]
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nAfterStep    INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cPOKey        NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cID           NVARCHAR( 18),
   @cSKU          NVARCHAR( 20),
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,
   @nQTY         INT,
   @cReasonCode  NVARCHAR( 10),
   @cSuggToLOC   NVARCHAR( 10),
   @cFinalLOC    NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 10),
   @cExtendedInfo NVARCHAR(20)  OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 600 -- Normal receive v7
   BEGIN
      IF @nAfterStep = 4 -- QTY
      BEGIN

         DECLARE @nTTlUCC INT
         SELECT 
            @nTTlUCC = Count(*)
         FROM UCC UCC WITH (NOLOCK) 
         JOIN   Receipt   R   (Nolock)   ON   UCC.ExternKey   = R.ExternReceiptKey AND R.Storerkey  = UCC.Storerkey 
         WHERE R.ReceiptKey = @cReceiptKey
            AND R.Storerkey = @cStorerKey
            AND UCC.ID = @cID --(yeekung01)

         -- Show statistic
         SET @cExtendedInfo = 'UCC/ID:' + CAST (@nTTlUCC AS NVARCHAR(5))
      END
   END
END

GO