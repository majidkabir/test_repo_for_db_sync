SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_830DecodeSP02                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode SKU by loc                                                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 10-10-2020  YeeKung   1.0   WMS-15415 Created                              */
/* 2024-10-22  PXL009    1.1   FCR-759 ID and UCC Length Issue                */
/******************************************************************************/

CREATE PROC rdt.rdt_830DecodeSP02 ( 
  @nMobile      INT,               
  @nFunc        INT,               
  @cLangCode    NVARCHAR( 3),      
  @nStep        INT,               
  @nInputKey    INT,               
  @cStorerKey   NVARCHAR( 15),        
  @cFacility    NVARCHAR( 20),   
  @cLOC         NVARCHAR( 10),   
  @cDropid      NVARCHAR( 20),
  @cpickslipno  NVARCHAR( 20), 
  @cBarcode     NVARCHAR( 60),
  @cFieldName   NVARCHAR( 10),     
  @cUPC         NVARCHAR( 20)  OUTPUT,
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
  @cUserDefine01 NVARCHAR(30)  OUTPUT,
  @nErrNo       INT            OUTPUT,
  @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   IF @nFunc = 830
   BEGIN
      IF @nStep = 3 
      BEGIN
         IF @nInputKey = 1
         BEGIN

            declare @ctempsku nvarchar(20),
                  @cZone nvarchar(20),
                  @cPH_OrderKey nvarchar(20),
                  @cPH_LoadKey nvarchar(20),
                  @nRowCount INT,
                  @nStartPos  INT,
                  @nEndPos  INT,
                  @nTtlQty INT

            IF LEN(@cUPC)>=16
            BEGIN

               IF (CHARINDEX ( '02' , @cUPC)=1 )
               BEGIN
                  SET @nStartPos=CHARINDEX ( '02' , @cUPC)

                  set @nStartPos=@nStartPos+2

                  SET @nEndPos=@nStartPos+14

                  SET @cUPC =SUBSTRING( @cUPC, @nStartPos, @nEndPos - @nStartPos) 


               END
            END

         END
      END
   END

Quit:

END

GO