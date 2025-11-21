SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_555DecodeSP01                                   */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: IT69 label decode                                           */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2022-10-18  1.0  James       WMS-20940. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_555DecodeSP01]
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15),
   @cBarcode       NVARCHAR( 60),
   @cID            NVARCHAR( 18)  OUTPUT,
   @cSKU           NVARCHAR( 20)  OUTPUT,
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
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nLblLength              INT,
           @cTempOrderKey           NVARCHAR( 10),       
           @cTempSKU                NVARCHAR( 20),
           @cTempLottable02         NVARCHAR( 18),
           @cShowErrMsgInNewScn     NVARCHAR( 1),       
           @cDecodeUCCNo            NVARCHAR( 1),
           @cTempPickSlipNo         NVARCHAR( 10),
           @nIsMoveOrders           INT = 0 
   
   SET @nErrNo = 0
            
   IF @nStep = 1 -- LOC/ID/SKU
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @cTempSKU = SUBSTRING( RTRIM( @cBarcode), 3, 13) -- SKU      
         SET @cTempLottable02 = SUBSTRING( RTRIM( @cBarcode), 16, 12) -- Lottable02      
         SET @cTempLottable02 = RTRIM( @cTempLottable02) + '-' -- Lottable02      
         SET @cTempLottable02 = RTRIM( @cTempLottable02) + SUBSTRING( RTRIM( @cBarcode), 28, 2) -- Lottable02      

         SET @cSKU = @cTempSKU      
         SET @cLottable02 = @cTempLottable02      
      END
   END

Quit:
END

GO