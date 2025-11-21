SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_SKULabel07                                     */
/*                                                                      */
/* Purpose: Print SKU LABEL                                             */
/*                                                                      */
/* Input Parameters: @cSKU,  @cSuggLOC                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Rev Author     Purposes                                 */
/* 2019-01-04   1.0 James      WMS7409. Created                         */
/* 2019-01-15   1.1 James      Add datetime (james01)                   */
/************************************************************************/
  
CREATE PROC [dbo].[isp_SKULabel07] (  
   @nMobile        INT,   
   @nFunc          INT,   
   @cLangCode      NVARCHAR( 3),   
   @cStorerKey     NVARCHAR( 15),   
   @cByRef1        NVARCHAR( 20),   
   @cByRef2        NVARCHAR( 20),   
   @cByRef3        NVARCHAR( 20),   
   @cByRef4        NVARCHAR( 20),   
   @cByRef5        NVARCHAR( 20),   
   @cByRef6        NVARCHAR( 20),   
   @cByRef7        NVARCHAR( 20),   
   @cByRef8        NVARCHAR( 20),   
   @cByRef9        NVARCHAR( 20),   
   @cByRef10       NVARCHAR( 20),   
   @cPrintTemplate NVARCHAR( MAX),   
   @cPrintData     NVARCHAR( MAX) OUTPUT,  
   @nErrNo         INT            OUTPUT,  
   @cErrMsg        NVARCHAR( 20)  OUTPUT  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cSKU     NVARCHAR( 20)  
   DECLARE @cSuggLOC NVARCHAR( 10)  
   DECLARE @cLOC     NVARCHAR( 10)  
   DECLARE @cDatetime NVARCHAR( 20)
     
   -- Parameter mapping  
   SET @cSKU      = @cByRef1  
   SET @cSuggLOC  = @cByRef2  
   SET @cLOC      = @cByRef3
   SET @cDatetime = RTRIM( CONVERT(NVARCHAR(23),CONVERT(DATETIME,GETDATE(),101),111)) + ' ' + 
                           CONVERT(NVARCHAR(15),CAST(GETDATE() AS TIME),100)
   -- 2019/1/15 10:29AM
       
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field01>', RTRIM( @cSKU))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field02>', RTRIM( @cSuggLOC))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field03>', RTRIM( @cLOC))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field04>', RTRIM( @cDatetime))  
  
   SET @cPrintData = @cPrintTemplate  
     
Quit:  

GO