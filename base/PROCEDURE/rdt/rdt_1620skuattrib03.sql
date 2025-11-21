SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1620SkuAttrib03                                 */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Vans Show Alternate SKU (sku or altsku or retailsku or      */  
/*          manufacturersku or upc)                                     */
/*                                                                      */  
/* Called from: rdt_ClusterPickSkuAttribute                             */  
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */  
/* 2019-05-09  1.0  James    WMS8817. Created                           */  
/************************************************************************/  

CREATE PROC [RDT].[rdt_1620SkuAttrib03] (  
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,
   @nInputKey     INT,
   @cStorerKey    NVARCHAR( 15),  
   @cSKU          NVARCHAR( 20),  
   @cAltSKU       NVARCHAR( 30)  OUTPUT,  
   @cDescr        NVARCHAR( 60)  OUTPUT,  
   @cStyle        NVARCHAR( 20)  OUTPUT,  
   @cColor        NVARCHAR( 10)  OUTPUT,  
   @cSize         NVARCHAR( 5)   OUTPUT,  
   @cColor_Descr  NVARCHAR( 30)  OUTPUT,  
   @cAttribute01  NVARCHAR( 20)  OUTPUT,  
   @cAttribute02  NVARCHAR( 20)  OUTPUT,  
   @cAttribute03  NVARCHAR( 20)  OUTPUT,  
   @cAttribute04  NVARCHAR( 20)  OUTPUT,  
   @cAttribute05  NVARCHAR( 20)  OUTPUT,  
   @cAttribute06  NVARCHAR( 20)  OUTPUT,  
   @cAttribute07  NVARCHAR( 20)  OUTPUT,  
   @cAttribute08  NVARCHAR( 20)  OUTPUT,  
   @cAttribute09  NVARCHAR( 20)  OUTPUT,  
   @cAttribute10  NVARCHAR( 20)  OUTPUT,  
   @nErrNo        INT            OUTPUT,  
   @cErrMsg       NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 char max  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @csValue        NVARCHAR( 20)
   DECLARE @cColumnName    NVARCHAR( 20)
   DECLARE @cTableName     NVARCHAR( 20)
   DECLARE @cDataType      NVARCHAR(128)
   DECLARE @nDelimiter     INT
   DECLARE @cSQL           NVARCHAR(1000)
   DECLARE @cSQLParam      NVARCHAR(1000)

   SET @cAltSKU = ''
   SET @cAttribute01 = ''
   SET @cAttribute02 = ''
   SET @cAttribute03 = ''

   IF ISNULL( @cSKU, '') = ''
      SELECT @cSKU = V_SKU FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   IF @cSKU = ''
      GOTO Fail

   SET @csValue = rdt.RDTGetConfig( @nFunc, 'ClusterPickCustomSKUToDisplay', @cStorerKey)
   IF @csValue = ''
      GOTO Fail

   SET @nDelimiter = 0
   SET @nDelimiter = CHARINDEX( '.', @csValue)
   IF @nDelimiter = 0
      GOTO Fail

   SET @cColumnName = ''
   SET @cColumnName = SUBSTRING( @csValue, ( @nDelimiter + 1), ( LEN( @csValue) - @nDelimiter))
   IF @cColumnName = ''
      GOTO Fail

   SET @cTableName = ''
   SET @cTableName = SUBSTRING( @csValue, 1, ( @nDelimiter - 1))
   IF @cTableName = ''
      GOTO Fail

   SET @cDataType = ''
   SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @cTableName AND COLUMN_NAME = @cColumnName
   IF @cDataType = '' OR @cDataType <> 'nvarchar'
      GOTO Fail

   SET @cSQL = 
      ' SELECT @cAltSKU = ' + RTRIM( @cColumnName) + 
      ' ,@cDescr = Descr     '+
      ' ,@cStyle = SKU.Style ' + 
      ' ,@cColor = SKU.Color ' +
      ' ,@cSize  = SKU.Size  ' + 
      ' ,@cColor_Descr = SKU.BUSR7 ' + 
      ' FROM dbo.' + @cTableName + ' WITH (NOLOCK) ' + 
      ' WHERE StorerKey = @cStorerKey ' + 
      ' AND   SKU = ''' + @cSKU + ''''

   SET @cSQLParam =
      ' @cStorerKey   NVARCHAR( 15), ' + 
      ' @cAltSKU      NVARCHAR( 30) OUTPUT, ' +
      ' @cDescr       NVARCHAR( 60) OUTPUT, ' + 
      ' @cStyle       NVARCHAR( 20) OUTPUT, ' +
      ' @cColor       NVARCHAR( 10) OUTPUT, ' +
      ' @cSize        NVARCHAR( 5)  OUTPUT, ' +
      ' @cColor_Descr NVARCHAR( 30) OUTPUT  ' 

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
      @cStorerKey, 
      @cAltSKU       OUTPUT,
      @cDescr        OUTPUT,
      @cStyle        OUTPUT,
      @cColor        OUTPUT,
      @cSize         OUTPUT,
      @cColor_Descr  OUTPUT

   IF rdt.RDTGetConfig( @nFunc, 'ReplaceDescrWithColorSize', @cStorerKey) = 1
   BEGIN
      SET @cColor_Descr = SUBSTRING( @cDescr, 1, 20)
      SET @cColor = @cColor + ' '
      SET @cDescr = ''
   END

   GOTO Quit         

   Fail:
      SET @cAltSKU = ''

   Quit:

END  

GO