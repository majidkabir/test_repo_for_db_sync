SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_SKULabel12_RP                                  */
/*                                                                      */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose:  Receiving SKU label                                        */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 05-01-2020   YeeKung 1.0   WMS-15842 Created                         */
/************************************************************************/
CREATE PROC [dbo].[isp_SKULabel12_RP] (
   @nMobile     INT,   
   @nFunc       INT,   
   @cLangCode   NVARCHAR( 3),   
   @cStorerKey  NVARCHAR( 15),   
   @cByRef1     NVARCHAR( 20),   
   @cByRef2     NVARCHAR( 20),   
   @cByRef3     NVARCHAR( 20),   
   @cByRef4     NVARCHAR( 20),   
   @cByRef5     NVARCHAR( 20),   
   @cByRef6     NVARCHAR( 20),   
   @cByRef7     NVARCHAR( 20),   
   @cByRef8     NVARCHAR( 20),   
   @cByRef9     NVARCHAR( 20),   
   @cByRef10    NVARCHAR( 20),   
   @cPrintTemplate NVARCHAR( MAX),   
   @cPrintData  NVARCHAR( MAX) OUTPUT,  
   @nErrNo      INT            OUTPUT,  
   @cErrMsg     NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 char max     
) 
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cSKUDesc       NVARCHAR( 60)
   DECLARE @nQTY           INT
   DECLARE @nCaseCnt       INT
   DECLARE @cLottable02    Nvarchar(20)
   DECLARE @CPrinttemp2    NVARCHAR(max)

   SET @cSKU=@cByRef1
   SET @cSKUDesc=@cByRef2
   SET @cLottable02=@cByRef3
   SET @nQty= CAST (@cByRef4 AS INT )
   SET @nCaseCnt= CAST (@cByRef5 AS INT)

   SELECT @cSKUDesc=DESCR
   FROM dbo.sku (NOLOCK) 
   where sku=@cSKU
      and storerkey=@cstorerkey

   SET @cPrintData = ''

   IF ISNULL( @cPrintTemplate, '') <> ''
   BEGIN
      WHILE (@nQty/@nCaseCnt<>0)
      BEGIN
         SET @CPrinttemp2=@cPrintTemplate

         SET @CPrinttemp2 = REPLACE (@CPrinttemp2, '<Field01>', RTRIM( @cSKU))  
         SET @CPrinttemp2 = REPLACE (@CPrinttemp2, '<Field02>', RTRIM( @cSKUDesc))
         SET @CPrinttemp2 = REPLACE (@CPrinttemp2, '<Field03>', RTRIM( @cLottable02))
         SET @CPrinttemp2 = REPLACE (@CPrinttemp2, '<Field04>', RTRIM( CAST (@nCaseCnt AS NVARCHAR(5))))

         SET @cPrintData = @cPrintData+@CPrinttemp2  

         SET @nQty=@nQty-@nCaseCnt
      END

      IF @nQty>0
      BEGIN
         SET @CPrinttemp2=@cPrintTemplate

         SET @CPrinttemp2 = REPLACE (@CPrinttemp2, '<Field01>', RTRIM( @cSKU))  
         SET @CPrinttemp2 = REPLACE (@CPrinttemp2, '<Field02>', RTRIM( @cSKUDesc))
         SET @CPrinttemp2 = REPLACE (@CPrinttemp2, '<Field03>', RTRIM( @cLottable02))
         SET @CPrinttemp2 = REPLACE (@CPrinttemp2, '<Field04>', RTRIM( CAST (@nQty AS NVARCHAR(5))))

         SET @cPrintData = @cPrintData+@CPrinttemp2  

      END
   END
END

GO