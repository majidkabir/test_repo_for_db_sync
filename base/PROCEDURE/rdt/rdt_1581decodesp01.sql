SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1581DecodeSP01                                        */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode QR code                                                    */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-03-28  James     1.0   WMS-21975 Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1581DecodeSP01] (
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nInputKey           INT,
   @cStorerKey          NVARCHAR( 15),
   @cReceiptKey         NVARCHAR( 10),
   @cPOKey              NVARCHAR( 10),
   @cLOC                NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cBarcode            NVARCHAR( 2000),
   @cSKU                NVARCHAR( 20)     OUTPUT,
   @nQTY                INT               OUTPUT,
   @cLottable01         NVARCHAR( 18)     OUTPUT,
   @cLottable02         NVARCHAR( 18)     OUTPUT,
   @cLottable03         NVARCHAR( 18)     OUTPUT,
   @dLottable04         DATETIME          OUTPUT,
   @cSerialNoCapture    NVARCHAR(1) = 0   OUTPUT,
   @nErrNo              INT               OUTPUT,
   @cErrMsg             NVARCHAR( 20)     OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cWeight        NVARCHAR( 5)
   DECLARE @c_Delim        CHAR( 1) = ','
   DECLARE @nRowCount      INT = 0
   
   IF @nStep = 5 -- SKU/QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cBarcode <> ''
         BEGIN
     
            DECLARE @t_DPCRec TABLE (  
               Seqno    INT,   
               ColValue VARCHAR(215)  
            )  
     
            INSERT INTO @t_DPCRec  
            SELECT * FROM dbo.fnc_DelimSplit(@c_Delim, @cBarcode)  
            SET @nRowCount = @@ROWCOUNT
            
            --SELECT * FROM @t_DPCRec
            --SELECT @nRowCount '@nRowCount'
            
            IF @nRowCount = 8  -- Bag QR
            BEGIN
               SELECT @cLottable03 = ColValue FROM @t_DPCRec WHERE Seqno = 4  
               SELECT @cSKU = ColValue FROM @t_DPCRec WHERE Seqno = 5
               SELECT @cWeight = ColValue FROM @t_DPCRec WHERE Seqno = 7
               SET @nQTY = CAST( @cWeight AS INT)
            END
            ELSE  -- Pallet QR
            BEGIN
               SELECT @cLottable03 = ColValue FROM @t_DPCRec WHERE Seqno = 5
               SELECT @cSKU = ColValue FROM @t_DPCRec WHERE Seqno = 8
               SELECT @cWeight = ColValue FROM @t_DPCRec WHERE Seqno = 7
               SET @nQTY = CAST( @cWeight AS INT)
            END
         END
      END
   END

Quit:

END

GO