SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO




/***************************************************************************/
/* Store procedure: isp_PriceLabel02                                       */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2023-04-26 1.0  yeekung  WMS-22236 Created                              */
/***************************************************************************/

CREATE   PROC [dbo].[isp_PriceLabel02] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cByRef1          NVARCHAR( 20),
   @cByRef2          NVARCHAR( 20),
   @cByRef3          NVARCHAR( 20),
   @cByRef4          NVARCHAR( 20),
   @cByRef5          NVARCHAR( 20),
   @cByRef6          NVARCHAR( 20),
   @cByRef7          NVARCHAR( 20),
   @cByRef8          NVARCHAR( 20),
   @cByRef9          NVARCHAR( 20),
   @cByRef10         NVARCHAR( 20),
   @cPrintTemplate   NVARCHAR( MAX),
   @cPrintData       NVARCHAR( MAX) OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT,
   @cCodePage        NVARCHAR( 50)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey   NVARCHAR( 10)
          ,@cTax01      NVARCHAR( 60)
          ,@cTax02      NVARCHAR( 60)


   SET @cCodePage = '850'
   
   SET @cPrintData =  @cPrintTemplate

   SELECT   @cTax01 = '$' + CAST(CONVERT(DECIMAL(10,2),CAST(tax01 AS FLOAT)) AS NVARCHAR),
            @cTax02 = '$' + CAST(CONVERT(DECIMAL(10,2),CAST(tax02 AS FLOAT)) AS NVARCHAR)  
   FROM ORDERDETAIL (NOLOCK)
   WHERE ORDERKEY = @cByRef2
      AND SKU = @cByRef5   
      AND Storerkey = @cStorerKey

   SET @cPrintData = REPLACE (@cPrintData,'<Field01>',@cTax01)
   SET @cPrintData = REPLACE (@cPrintData,'<Field02>',@cTax02)


   GOTO Quit

Quit:


GO