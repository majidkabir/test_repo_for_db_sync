SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_607RcvInfo01                                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 05-01-2018 1.0  ChewKP   WMS-3551 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_607RcvInfo01] (
    @nMobile      INT,        
    @nFunc        INT,          
    @cLangCode    NVARCHAR( 3), 
    @nStep        INT,          
    @nInputKey    INT,          
    @cStorerKey   NVARCHAR( 15),
    @cReceiptKey  NVARCHAR( 10),
    @cPOKey       NVARCHAR( 10),
    @cLOC         NVARCHAR( 10),
    @cID          NVARCHAR( 18)  OUTPUT, 
    @cSKU         NVARCHAR( 20)  OUTPUT, 
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

   
          


   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @nFunc = 607
   BEGIN
      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = NULL
      SET @dLottable05 = NULL
      SET @cLottable06 = ''
      SET @cLottable07 = ''
      SET @cLottable08 = ''
      SET @cLottable09 = ''
      SET @cLottable10 = ''
      SET @cLottable11 = ''
      SET @cLottable12 = ''
      SET @dLottable13 = NULL
      SET @dLottable14 = NULL
      SET @dLottable15 = NULL

   END
     
   


END



GO