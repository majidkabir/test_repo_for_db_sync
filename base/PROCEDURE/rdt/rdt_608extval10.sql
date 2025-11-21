SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608ExtVal10                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Calc suggest location, booking                                    */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 25-01-2021   Chermaine 1.0   WMS-16119 Created                             */
/* 08-09-2022   Ung       1.1   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtVal10]
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cPOKey        NVARCHAR( 10),
   @cRefNo        NVARCHAR( 60),
   @cID           NVARCHAR( 18),
   @cLOC          NVARCHAR( 10),
   @cMethod       NVARCHAR( 1),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
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
   @cRDLineNo     NVARCHAR( 10),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT
   DECLARE @nQTYExpected   INT
   DECLARE @nBeforeReceivedQTY INT

   IF @nFunc = 608 -- Piece return
   BEGIN      
      IF @nStep = 4 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get SKU info
            DECLARE @cRecType  NVARCHAR(10)
            
            SELECT @cRecType = Rectype FROM Receipt WITH (NOLOCK) WHERE storerKey = @cStorerKey AND ReceiptKey = @cReceiptKey
            SELECT @nQTYExpected = SUM(QtyExpected), @nBeforeReceivedQTY = SUM(BeforeReceivedQTY) FROM ReceiptDetail WITH (NOLOCK) WHERE storerKey = @cStorerKey AND ReceiptKey = @cReceiptKey AND SKU = @cSKU
            
            SET @nQTYExpected = CASE WHEN ISNULL(@nQTYExpected,'')='' THEN 0 ELSE @nQTYExpected END
            SET @nBeforeReceivedQTY = CASE WHEN ISNULL(@nBeforeReceivedQTY,'')='' THEN 0 ELSE @nBeforeReceivedQTY END

            IF (@nBeforeReceivedQTY + @nQty) > @nQTYExpected
            BEGIN
            	IF EXISTS (SELECT TOP 1 1 FROM Codelkup WITH(nolock) WHERE Listname='RECTYPE' AND Storerkey=@cStorerKey AND UDF02='N' AND Code= @cRecType)
               BEGIN
            	   SET @nErrNo = 162451
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OverRec-RECType
                  GOTO Quit
               END
            
               IF EXISTS (SELECT TOP 1 1 FROM Codelkup WITH(nolock) WHERE Listname='RTNLOC2L10' AND Storerkey=@cStorerKey AND UDF01='N' AND Code2='608' AND Code= @cLOC)
               BEGIN
            	   SET @nErrNo = 162452
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OverRec-ToLoc
                  GOTO Quit
               END
            END

            IF NOT EXISTS (SELECT TOP 1 1 FROM  Codelkup WITH(nolock) WHERE Listname='RTNLOC2L10' AND Storerkey=@cStorerKey AND Code2='608' AND Code= @cLOC)
            BEGIN
            	SET @nErrNo = 162453
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LocNotInCodeLK
               GOTO Quit
            END
         END         
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_608ExtVal10 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END


GO