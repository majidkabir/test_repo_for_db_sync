SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_732DecodeSP02                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode UCC (UCC storer config off), abstract SKU and QTY          */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 13-07-2018  Ung       1.0   WMS-5664 Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_732DecodeSP02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15), 
   @cCCKey         NVARCHAR( 10), 
   @cCCSheetNo     NVARCHAR( 10), 
   @cCountNo       NVARCHAR( 1), 
   @cBarcode       NVARCHAR( 60),
   @cLOC           NVARCHAR( 10)  OUTPUT, 
   @cUPC           NVARCHAR( 20)  OUTPUT, 
   @nQTY           INT            OUTPUT, 
   @cLottable01    NVARCHAR( 18)  OUTPUT, 
   @cLottable02    NVARCHAR( 18)  OUTPUT, 
   @cLottable03    NVARCHAR( 18)  OUTPUT, 
   @dLottable04    DATETIME       OUTPUT, 
   @dLottable05    DATETIME       OUTPUT, 
   @cLottable06    NVARCHAR( 30)  OUTPUT, 
   @cLottable07    NVARCHAR( 30)  OUTPUT, 
   @cLottable08    NVARCHAR( 30)  OUTPUT, 
   @cLottable09    NVARCHAR( 30)  OUTPUT, 
   @cLottable10    NVARCHAR( 30)  OUTPUT, 
   @cLottable11    NVARCHAR( 30)  OUTPUT, 
   @cLottable12    NVARCHAR( 30)  OUTPUT, 
   @dLottable13    DATETIME       OUTPUT, 
   @dLottable14    DATETIME       OUTPUT, 
   @dLottable15    DATETIME       OUTPUT, 
   @cUserDefine01  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine02  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine03  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine04  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine05  NVARCHAR( 60)  OUTPUT, 
   @nErrNo         INT            OUTPUT, 
   @cErrMsg        NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nLength     INT,
           @cBUSR1      NVARCHAR( 30), 
           @cStyle      NVARCHAR( 20), 
           @cQty        NVARCHAR( 5), 
           @bSuccess    INT
   
   IF @nFunc = 732 -- Simple CC (assisted)
   BEGIN
      IF @nStep = 4 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               SELECT TOP 1 
                  @cUPC = SKU, 
                  @nQTY = QTY
               FROM UCC WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND UCCNo = @cBarcode
                  
               IF @@ROWCOUNT = 0
                  SET @cUPC = @cBarcode
            END
         END
      END
   END

Quit:

END

GO