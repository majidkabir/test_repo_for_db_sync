SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_SKULabel13_RP                                  */
/*                                                                      */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose:  Receiving SKU label                                        */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 10-03-2021   YeeKung 1.0   WMS-16444 Created                         */
/************************************************************************/
CREATE PROC [dbo].[isp_SKULabel13_RP] (
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
   DECLARE @cPrice         NVARCHAR( 60)
   DECLARE @nNoofCopy      INT
   DECLARE @nCopy          INT =1

   SET @cSKU=@cByRef1
   SET @cPrice=@cByRef2
   SET @nNoofCopy =@cByRef3

   SET @cPrintData = ''

   IF ISNULL( @cPrintTemplate, '') <> ''
   BEGIN
      
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field01>', RTRIM( @cSKU))  
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field02>', RTRIM( @cPrice))

      WHILE (@nNoofCopy>=@nCopy)
      BEGIN
         SET @cPrintData = @cPrintData+@cPrintTemplate
         SET @nCopy=@nCopy+1
      END

   END

END

GO