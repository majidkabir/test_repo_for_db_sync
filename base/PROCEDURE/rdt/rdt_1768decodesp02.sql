SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1768DecodeSP02                                        */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: HM decode label return SKU + Lottable02                           */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 27-04-2018  James     1.0   WMS4614 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1768DecodeSP02] (
   @nMobile        INT,           
   @nFunc          INT,           
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,           
   @nInputKey      INT,           
   @cStorerKey     NVARCHAR( 15), 
   @cBarcode       NVARCHAR( 60), 
   @cTaskDetailKey NVARCHAR( 10), 
   @cLOC           NVARCHAR( 10),                
   @cID            NVARCHAR( 18),                
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

   DECLARE @cLot02_1   NVARCHAR( 18),
           @cLot02_2   NVARCHAR( 18)

   IF @cBarcode = ''
      GOTO Quit

   IF @nFunc = 1768 -- TMCC SKU
   BEGIN
      IF @nStep IN ( 1, 2) -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SET @cUPC = SUBSTRING( RTRIM( @cBarcode), 3, 13)

            SET @cLot02_1 = SUBSTRING( RTRIM( @cBarcode), 16, 12)
            SET @cLot02_2 = SUBSTRING( RTRIM( @cBarcode), 28, 2)
            SET @cLottable01 = substring( RTRIM( @cBarcode), 16, 6)
            SET @cLottable02 = RTRIM( @cLot02_1) + '-' + RTRIM( @cLot02_2)
            SET @cLottable03 = 'STD'-- temp hardcoded, IN LIT will find out how to get it
            SET @dLottable04 = NULL -- IN LIT confirm lot04 always null

            --insert into traceinfo (tracename, timein, col1, col2, col3, col4) values 
            --('1768', getdate(), @cLottable01, @cLottable02, @cLottable03, @dLottable04)
         END   -- ENTER
      END   -- @nStep = 3
   END

Quit:

END

GO