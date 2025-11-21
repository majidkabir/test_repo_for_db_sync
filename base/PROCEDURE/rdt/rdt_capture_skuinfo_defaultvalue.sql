SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_Capture_SKUInfo_DefaultValue                    */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Update SKU setting                                          */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author       Purposes                               */  
/* 2018-11-23  1.0  James        WMS7002. Created                       */
/* 2019-09-11  1.1  Pakyuen      INC0851231-Change the loop condition   */   
/* 2019-11-08  1.2  Ung          Fix header missing                     */   
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_Capture_SKUInfo_DefaultValue]  
   @nMobile          INT,  
   @nFunc            INT,  
   @cLangCode        NVARCHAR( 3),  
   @cStorerKey       NVARCHAR( 15),  
   @cUCCNo           NVARCHAR( 20),  
   @cSKU             NVARCHAR( 20),  
   @nQty             INT,  
   @cParam1Label     NVARCHAR( 20),   
   @cParam2Label     NVARCHAR( 20),   
   @cParam3Label     NVARCHAR( 20),   
   @cParam4Label     NVARCHAR( 20),   
   @cParam5Label     NVARCHAR( 20),   
   @cParam1Value     NVARCHAR( 60)  OUTPUT,   
   @cParam2Value     NVARCHAR( 60)  OUTPUT,   
   @cParam3Value     NVARCHAR( 60)  OUTPUT,   
   @cParam4Value     NVARCHAR( 60)  OUTPUT,   
   @cParam5Value     NVARCHAR( 60)  OUTPUT,   
   @nErrNo           INT            OUTPUT,  
   @cErrMsg          NVARCHAR( 20)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cExecStatements   NVARCHAR( 1000)  
   DECLARE @cSelectStatements NVARCHAR( 1000)  
   DECLARE @cFilterStatements NVARCHAR( 1000)  
   DECLARE @cExecArguments    NVARCHAR( 1000)  
   DECLARE @bDebug            INT  
   DECLARE @nLoop             INT   
   DECLARE @cTemp1Value       NVARCHAR( 60)  
   DECLARE @cTemp2Value       NVARCHAR( 60)  
   DECLARE @cTemp3Value       NVARCHAR( 60)  
   DECLARE @cTemp4Value       NVARCHAR( 60)  
   DECLARE @cTemp5Value       NVARCHAR( 60)  
  
     
   SET @bDebug = 0  
   SET @nLoop = 1  
   SET @cSelectStatements = ' '  
  
   WHILE @nLoop <= 5  --INC0851231
   BEGIN  
      IF LEFT( @cParam1Label, 1) = '*'  
         SET @cParam1Label = RIGHT( @cParam1Label, LEN( @cParam1Label) - 1)  
  
      IF LEFT( @cParam2Label, 1) = '*'  
         SET @cParam2Label = RIGHT( @cParam2Label, LEN( @cParam2Label) - 1)  
  
      IF LEFT( @cParam3Label, 1) = '*'  
         SET @cParam3Label = RIGHT( @cParam3Label, LEN( @cParam3Label) - 1)  
  
      IF LEFT( @cParam4Label, 1) = '*'  
         SET @cParam4Label = RIGHT( @cParam4Label, LEN( @cParam4Label) - 1)  
  
      IF LEFT( @cParam5Label, 1) = '*'  
         SET @cParam5Label = RIGHT( @cParam5Label, LEN( @cParam5Label) - 1)  
  
      SET @cSelectStatements =   
          @cSelectStatements +   
          CASE WHEN @nLoop = 1 AND @cParam1Label <> '' THEN '@cTemp1Value = ' + @cParam1Label + ', '   
               WHEN @nLoop = 2 AND @cParam2Label <> '' THEN '@cTemp2Value = ' + @cParam2Label + ', '   
               WHEN @nLoop = 3 AND @cParam3Label <> '' THEN '@cTemp3Value = ' + @cParam3Label + ', '   
               WHEN @nLoop = 4 AND @cParam4Label <> '' THEN '@cTemp4Value = ' + @cParam4Label + ', '   
               WHEN @nLoop = 5 AND @cParam5Label <> '' THEN '@cTemp5Value = ' + @cParam5Label + ', '   
               ELSE ''   
          END  
  
      SET @nLoop = @nLoop + 1  
   END  
  
   SET @cSelectStatements = LEFT( @cSelectStatements, LEN( RTRIM( @cSelectStatements)) - 1)  
  
   SET @cExecStatements = N'SELECT '            
  
   SET @cFilterStatements = N' FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU'  
  
   SET @cExecStatements = @cExecStatements + @cSelectStatements + @cFilterStatements  
                               
   IF @bDebug = 1            
   SELECT @cExecStatements          
                
   SET @cExecArguments =   
      N'@cStorerKey    NVARCHAR( 15),  ' +      
       '@cSKU          NVARCHAR( 20),  ' +  
       '@cParam1Label  NVARCHAR( 20),  ' +  
       '@cParam2Label  NVARCHAR( 20),  ' +  
       '@cParam3Label  NVARCHAR( 20),  ' +  
       '@cParam4Label  NVARCHAR( 20),  ' +  
       '@cParam5Label  NVARCHAR( 20),  ' +  
       '@cTemp1Value   NVARCHAR( 60)   OUTPUT, ' +  
       '@cTemp2Value   NVARCHAR( 60)   OUTPUT, ' +  
       '@cTemp3Value   NVARCHAR( 60)   OUTPUT, ' +  
       '@cTemp4Value   NVARCHAR( 60)   OUTPUT, ' +  
       '@cTemp5Value   NVARCHAR( 60)   OUTPUT  '   
  
   EXEC sp_ExecuteSql @cExecStatements, @cExecArguments,   
      @cStorerKey,   
      @cSKU,   
      @cParam1Label,  
      @cParam1Label,  
      @cParam1Label,  
      @cParam1Label,  
      @cParam1Label,  
      @cTemp1Value   OUTPUT,  
      @cTemp2Value   OUTPUT,  
      @cTemp3Value   OUTPUT,  
      @cTemp4Value   OUTPUT,  
      @cTemp5Value   OUTPUT  
  
  
      SET @cParam1Value = ISNULL( @cTemp1Value, '')  
      SET @cParam2Value = ISNULL( @cTemp2Value, '')  
      SET @cParam3Value = ISNULL( @cTemp3Value, '')  
      SET @cParam4Value = ISNULL( @cTemp4Value, '')  
      SET @cParam5Value = ISNULL( @cTemp5Value, '')  
Quit:                        
  
END  

GO