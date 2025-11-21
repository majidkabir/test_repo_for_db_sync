SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_839DecodeSP04                                         */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2023-04-10   1.0  James      WMS-22147. Created                            */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_839DecodeSP04] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 
   @cBarcode     NVARCHAR( 2000), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cPickZone    NVARCHAR( 10), 
   @cDropID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cUPC         NVARCHAR( 30)  OUTPUT, 
   @nQTY         INT            OUTPUT, 
   @cLottable01  NVARCHAR( 18)  OUTPUT, 
   @cLottable02  NVARCHAR( 18)  OUTPUT, 
   @cLottable03  NVARCHAR( 18)  OUTPUT, 
   @dLottable04  DATETIME       OUTPUT, 
   @dLottable05  DATETIME       OUTPUT, 
   @cLottable06  NVARCHAR( 30)  OUTPUT, 
   @cLottable07  NVARCHAR( 30)  OUTPUT, 
   @cLottable08  NVARCHAR( 30)  OUTPUT, 
   @cLottable09  NVARCHAR( 30)  OUTPUT, 
   @cLottable10  NVARCHAR( 30)  OUTPUT, 
   @cLottable11  NVARCHAR( 30)  OUTPUT, 
   @cLottable12  NVARCHAR( 30)  OUTPUT, 
   @dLottable13  DATETIME       OUTPUT, 
   @dLottable14  DATETIME       OUTPUT, 
   @dLottable15  DATETIME       OUTPUT, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Delim        CHAR( 1) = ','
   DECLARE @nRowCount      INT = 0
   
   IF @nStep = 3 -- SKU/QTY
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
               SELECT @cUPC = CASE WHEN RIGHT(ColValue, 2) = 'BD' THEN
               SUBSTRING(ColValue, 1, LEN(ColValue) - 3)
               ELSE
               ColValue END FROM @t_DPCRec WHERE Seqno = 5
            ELSE  -- Pallet QR
               SELECT @cUPC = CASE WHEN RIGHT(ColValue, 2) = 'BD' THEN
               SUBSTRING(ColValue, 1, LEN(ColValue) - 3)
               ELSE
               ColValue END FROM @t_DPCRec WHERE Seqno = 8
         END
      END
   END
END

GO