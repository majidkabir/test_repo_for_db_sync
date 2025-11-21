SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_SKULabel09_RP                                  */
/*                                                                      */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose:  Receiving SKU label                                        */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 10-Oct-2018  Ung     1.0   WMS-6462 Created                          */
/* 17-Oct-2019  James   1.1   WMS-10894 Add username (james01)          */
/* 15-Jul-2022  Ung     1.2   WMS-20224 Add new mapping                 */
/************************************************************************/
CREATE   PROC [dbo].[isp_SKULabel09_RP] (
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

   DECLARE @cFromLOC          NVARCHAR( 10)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @cLottable01       NVARCHAR( 18)
   DECLARE @cSuggestedLOC     NVARCHAR( 10)
   DECLARE @cPackKey          NVARCHAR( 10)
   DECLARE @nPackQTYIndicator INT
   DECLARE @nCaseCNT          INT
   DECLARE @cBUSR5            NVARCHAR( 30)
   DECLARE @cRetailSKU        NVARCHAR( 20)
   DECLARE @cUDF02            NVARCHAR( 60)
   DECLARE @cUDF03            NVARCHAR( 60)

   SET @cPrintData = ''

   -- Parameter mapping
   SET @cFromLOC = @cByRef1
   SET @cSKU = @cByRef2
   SET @cLottable01 = @cByRef3
   SET @cSuggestedLOC = @cByRef4

   -- Get SKU info
   SELECT 
      @cPackKey = PackKey, 
      @nPackQTYIndicator = PackQTYIndicator, 
      @cBUSR5 = ISNULL( BUSR5, ''), 
      @cRetailSKU = ISNULL( RetailSKU, '')
   FROM SKU WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND SKU = @cSKU

   -- Get pack key info
   SELECT @nCaseCNT = CAST( CaseCNT AS INT)
   FROM Pack WITH (NOLOCK)
   WHERE PackKey = @cPackKey
   
   ---GET RFPUTAWAY.UDF02  by zoe
   SET @cUDF02 = 'QD'
   SELECT TOP 1
      @cUDF02 = ISNULL( UDF02, ''), 
      @cUDF03 = ISNULL( UDF03, '')
   FROM RFPutaway WITH (NOLOCK)
   WHERE FromLoc = @cFromLOC
      AND SuggestedLOC = @cSuggestedLOC
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU
      -- AND ISNULL( UDF02, '') <> ''
      AND ISNULL( UDF01, '') = '' -- piece only

   SET @cUDF02 = CASE WHEN ISNULL( @cUDF02, '') = '' THEN '-' ELSE  @cUDF02 END  --BY ZOE 2023/1/30
   SET @cUDF03 = CASE WHEN ISNULL( @cUDF03, '') = '' THEN '-' ELSE  @cUDF03 END  --BY ZOE 2023/1/30

   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field01>', RTRIM( @cSKU))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field02>', SUBSTRING( RTRIM( @cSuggestedLOC), 1, 3))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field03>', SUBSTRING( RTRIM( @cSuggestedLOC), 4, 3))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field04>', SUBSTRING( RTRIM( @cSuggestedLOC), 7, 2))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field05>', SUBSTRING( RTRIM( @cSuggestedLOC), 9, 1))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field06>', SUBSTRING( RTRIM( @cSuggestedLOC), 10, 1))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field07>', RTRIM( @cFromLOC))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field08>', RTRIM( @cLottable01))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field09>', RIGHT( SUSER_SNAME(), 4))  -- (james01)
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field10>', RTRIM( CAST( @nPackQTYIndicator AS NVARCHAR(2))))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field11>', RTRIM( @cPackKey))  
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field12>', RTRIM( CAST( @nCaseCNT AS NVARCHAR(3))))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field13>', RTRIM( @cBUSR5))
   -- SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field14>', RTRIM( @cDTOWProcess))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field15>', RTRIM( @cUDF02))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field16>', RTRIM( @cUDF03))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field17>', SUBSTRING( RTRIM( @cSKU), 1, 6))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field18>', SUBSTRING( RTRIM( @cSKU), 7, 3))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field19>', SUBSTRING( RTRIM( @cSKU), 10, 6))

   IF ISNULL( @cPrintTemplate, '') <> ''
      SET @cPrintData = @cPrintTemplate
END

GO