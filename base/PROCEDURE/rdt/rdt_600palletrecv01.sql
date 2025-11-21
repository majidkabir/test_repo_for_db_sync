SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600PalletRecv01                                       */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Default lottable for receiving                                    */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 09-Jun-2022  yeekung    1.0  WMS-19757 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_600PalletRecv01]
   @nMobile      INT,            
   @nFunc        INT,            
   @cLangCode    NVARCHAR( 3),   
   @nStep        INT,            
   @nInputKey    INT,            
   @cStorerKey   NVARCHAR( 15),  
   @cReceiptKey  NVARCHAR( 10),  
   @cPOKey       NVARCHAR( 10),  
   @cLOC         NVARCHAR( 10),  
   @cID          NVARCHAR( 18),  
   @cSKU         NVARCHAR( 20),  
   @nQTY         INT,            
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
   @cPalletRecv  NVARCHAR( 1)   OUTPUT, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 600 -- Normal receive v7
   BEGIN
      IF EXISTS (SELECT 1
                 FROM UCC (NOLOCK) 
                 WHERE storerkey=@cstorerkey
                 AND userdefined01=@cLottable02
                 AND userdefined03=@cLottable09
                 and status=0)
      BEGIN
         SET @cPalletRecv=0
      END
      ELSE
      BEGIN
         SET @cPalletRecv=1
      END
   END
END

GO