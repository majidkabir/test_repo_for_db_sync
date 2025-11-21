SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: isp_CtnLabel02                                         */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2023-08-15 1.0  yeekung  WMS-23293 Created                              */
/***************************************************************************/

CREATE   PROC [dbo].[isp_CtnLabel02] (
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

   DECLARE @cParams1    NVARCHAR( 60)
          ,@cParams2    NVARCHAR( 60)
          ,@cParams3    NVARCHAR( 60)
          ,@cParams4    NVARCHAR( 60)
          ,@cParams5    NVARCHAR( 60)
          ,@cParams6    NVARCHAR( 60)
          ,@cParams7    NVARCHAR( 60)
          ,@cParams8    NVARCHAR( 60)
          ,@cParams9    NVARCHAR( 60)
          ,@cParams10    NVARCHAR( 60)
          ,@cParams11   NVARCHAR( 60)
          ,@cParams12   NVARCHAR( 60)
          ,@cLottable01 NVARCHAR(60)

   SET @cPrintData = @cPrintTemplate

   SELECT @cParams1 = R.UserDefine01,
          @cParams2 = R.IncoTerms,
          @cParams3 = RDT.rdtFormatDate(rd.lottable05),
          @cParams4 = SKU.Style,
          @cParams5 = RD.UserDefine02,
          @cParams6 = RD.ReceiptLineNumber,
          @cLottable01 = RD.Lottable01,
          @cParams8 = SKU.Size,
          @cParams9 = CAST(Rd.QtyExpected AS NVARCHAR(5)),
          @cParams10 = RD.UserDefine01,
          @cParams11 = RD.UserDefine01,
          @cParams12 = SKU.BUSR4
   FROM Receipt R (NOLOCK) 
   JOIN Receiptdetail RD (NOLOCK) ON R.receiptkey = RD.ReceiptKey
   JOIN SKU SKU (NOLOCK) ON  RD.SKU = SKU.SKU AND RD.Storerkey = SKU.Storerkey
   WHERE RD.receiptkey = @cByRef1
      AND RD.UserDefine01 = @cByRef2
      AND RD.Storerkey = @cStorerKey

   IF EXISTS (SELECT 1 
               FROM CODELKUP (NOLOCK)
               WHERE Code = @cLottable01
               AND LISTNAME = 'LVSPLCC'
               AND Storerkey = @cStorerKey
               )
   BEGIN
      SELECT @cParams7= long
      FROM CODELKUP (NOLOCK)
      WHERE Code = @cLottable01
      AND LISTNAME = 'LVSPLCC'
      AND Storerkey = @cStorerKey
   END
   ELSE
   BEGIN
      SET @cParams7 = ''
   END


   SET @cPrintData = REPLACE (@cPrintData,'<Field01>',RTRIM(ISNULL(@cParams1 ,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field02>',RTRIM(ISNULL(@cParams2 ,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field03>',RTRIM(ISNULL(@cParams3 ,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field04>',RTRIM(ISNULL(@cParams4 ,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field05>',RTRIM(ISNULL(@cParams5 ,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field06>',RTRIM(ISNULL(@cParams6 ,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field07>',RTRIM(ISNULL(@cParams7 ,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field08>',RTRIM(ISNULL(@cParams8 ,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field09>',RTRIM(ISNULL(@cParams9 ,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field10>',RTRIM(ISNULL(@cParams10,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field11>',RTRIM(ISNULL(@cParams11,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field12>',RTRIM(ISNULL(@cParams12,'')))

   SET @cCodePage = '850'

   GOTO Quit

Quit:

GO