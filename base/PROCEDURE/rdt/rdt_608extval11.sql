SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608ExtVal11                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Calc suggest location, booking                                    */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 25-08-2021   Chermaine 1.0   WMS-17760 Created                             */
/* 08-09-2022   Ung       1.1   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtVal11]
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
   DECLARE @cLocationType  NVARCHAR(10)
   DECLARE @cRecType       NVARCHAR(10)
   DECLARE @cReturnType    NVARCHAR(10)

   IF @nFunc = 608 -- Piece return
   BEGIN    
   	IF @nStep = 2 -- ID, LOC
      BEGIN
      	IF NOT EXISTS (SELECT 1 from codelkup WHERE listname= 'RTNLOC2L10' and storerkey = @cStorerKey and code2 = @nFunc and code = @cLOC)
      	BEGIN
      		SET @nErrNo = 174351
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LocNotInCodeLK
            GOTO Quit
         END
            
	   	SELECT 
	   	   @cLocationType = UDF01
	   	FROM codelkup
	   	WHERE listname= 'RTNLOC2L10' 
	   	AND storerkey = @cStorerKey 
	   	AND code2 = @nFunc 
	   	AND code = @cLOC

		   SELECT 
		      @cRecType = recType
		   FROM receipt
		   WHERE storerkey = @cStorerKey 
		   AND receiptkey = @cReceiptKey

		   SELECT 
		      @cReturnType = UDF01
		   FROM codelkup
		   WHERE listname= "RECTYPE" 
		   AND storerkey = @cStorerKey 
		   AND code = @cRecType
		   
		   --For RSO, cannot receive to STO-R loc
		   IF @cReturnType = 'RSO' AND @cLocationType = '' 
		   BEGIN
		   	SET @nErrNo = 174352
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
            GOTO Quit
		   END
		   
		   --For STO-R, cannot receive to RSO loc
		   IF @cReturnType <> 'RSO' AND @cLocationType <> '' 
		   BEGIN
		   	SET @nErrNo = 174353
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
            GOTO Quit
		   END
      END  
      
      IF @nStep = 4 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get SKU info
            SELECT 
               @cRecType = Rectype 
            FROM Receipt WITH (NOLOCK) 
            WHERE storerKey = @cStorerKey 
               AND ReceiptKey = @cReceiptKey
            
            SELECT 
		         @cReturnType = UDF01
		      FROM codelkup
		      WHERE listname= 'RECTYPE'
		      AND storerkey = @cStorerKey 
		      AND code = @cRecType
		      
		      IF @cReturnType = 'RSO'
		      BEGIN
		      	SELECT 
		      	   @cLocationType = UDF01
		         FROM codelkup
		         WHERE listname= 'RTNLOC2L10' 
		         AND storerkey = @cStorerKey 
		         AND code2 = @nFunc 
		         AND code = @cLOC
		         
		         IF EXISTS (SELECT TOP 1 1 
		                    FROM receiptDetail WITH (NOLOCK) 
		                    WHERE storerKey = @cStorerKey 
		                    AND ReceiptKey = @cReceiptKey 
		                    AND sku = @cSku 
		                    --AND ExternReceiptKey <> ''
		                    AND lottable12 = '')
		         BEGIN
		         	-- input ISEG is matched with RSO
		         	IF EXISTS (SELECT TOP 1 1 
		         	           FROM receiptDetail WITH (NOLOCK) 
		         	           WHERE storerKey = @cStorerKey 
		         	           AND ReceiptKey = @cReceiptKey 
		         	           AND sku = @cSku 
		         	           AND lottable02 = @cLottable02
		         	           --AND ExternReceiptKey <> ''
		         	           AND lottable12 = '')
		         	BEGIN
		         		SELECT 
		         		   @nQTYExpected = SUM(QtyExpected), 
		         		   @nBeforeReceivedQTY = SUM(BeforeReceivedQTY) 
		         		FROM ReceiptDetail WITH (NOLOCK) 
		         		WHERE storerKey = @cStorerKey 
		         		AND ReceiptKey = @cReceiptKey 
		         		AND SKU = @cSKU
		         		
		         		IF (@nBeforeReceivedQty + @nQty) <= @nQtyExpected
		         		BEGIN
		         			--For normal receipt, cannot receive to exception loc
		         			IF @cLocationType = 'E'
		         			BEGIN
		         				SET @nErrNo = 174354
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NorRec-E Loc
                           GOTO Quit
		         			END
		         		END
		         		--For over-receipt, cannot receive to normal loc
		         		ELSE IF @cLocationType = 'N'
		         		BEGIN
		         			SET @nErrNo = 174355
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OverRec-ToLoc
                        GOTO Quit
		         		END	
		         	END
		         	ELSE --input ISEG is not matched with RSO
		         	BEGIN
		         		--For ISEG mismatch, cannot receive to normal loc
		         		IF @cLocationType = 'N'
		         		BEGIN
		         			SET @nErrNo = 174356
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ISEGMismatchLoc
                        GOTO Quit
		         		END
		         	END
		         END
		         ELSE --SKU not in ASN (exceptional)
		         BEGIN
		         	--For exception SKU, cannot receive to normal loc
		         	IF @cLocationType = 'N'
		         	BEGIN
		         		SET @nErrNo = 174357
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ExpSku->NorLoc
                     GOTO Quit
		         	END
		         END
		      END
         END         
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_608ExtVal11 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO