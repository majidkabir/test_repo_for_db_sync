SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_826SKUInfoCfm01                                 */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Update SKU setting                                          */  
/*                                                                      */  
/* Called from: rdt_Capture_SKUInfo_Confirm                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author       Purposes                               */  
/* 2018-11-23  1.0  James        WMS7002. Created                       */
/* 2019-09-11  1.1  Pakyuen      INC0851231-Change the loop condition   */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_826SKUInfoCfm01]  
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
   @cParam1Value     NVARCHAR( 60),   
   @cParam2Value     NVARCHAR( 60),   
   @cParam3Value     NVARCHAR( 60),   
   @cParam4Value     NVARCHAR( 60),   
   @cParam5Value     NVARCHAR( 60),   
   @nErrNo           INT           OUTPUT,  
   @cErrMsg          NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cExecStatements   NVARCHAR( 1000)  
   DECLARE @cUpdateStatements NVARCHAR( 1000)  
   DECLARE @cFilterStatements NVARCHAR( 1000)  
   DECLARE @cExecArguments    NVARCHAR( 1000)  
   DECLARE @cColumnName       NVARCHAR( 30)  
   DECLARE @cColumnValue      NVARCHAR( 60)  
   DECLARE @bDebug            INT  
   DECLARE @nLoop             INT   
   DECLARE @cType             NVARCHAR( 10)  
  
   SET @bDebug = 0  
   SET @nLoop = 1  
   SET @cUpdateStatements = 'SET '  
  
   WHILE @nLoop <= 5  --INC0851231
   BEGIN  
      IF @nLoop = 1 AND @cParam1Label <> ''  
      BEGIN  
         SET @cColumnName = @cParam1Label  
         SET @cColumnValue = @cParam1Value  
      END  
  
      IF @nLoop = 2 AND @cParam2Label <> ''  
      BEGIN  
         SET @cColumnName = @cParam2Label  
         SET @cColumnValue = @cParam2Value  
      END  
  
      IF @nLoop = 3 AND @cParam3Label <> ''  
      BEGIN  
         SET @cColumnName = @cParam3Label  
         SET @cColumnValue = @cParam3Value  
      END  
  
      IF @nLoop = 4 AND @cParam4Label <> ''  
      BEGIN  
         SET @cColumnName = @cParam4Label  
         SET @cColumnValue = @cParam4Value  
      END  
  
      IF @nLoop = 5 AND @cParam5Label <> ''  
      BEGIN  
         SET @cColumnName = @cParam5Label  
         SET @cColumnValue = @cParam5Value  
      END  
  
      IF LEFT( @cColumnName, 1) = '*'  
         SET @cColumnName = RIGHT( @cColumnName, LEN( @cColumnName) - 1)  
  
      IF @cColumnName <> ''  
      BEGIN  
         SELECT @cType = DATA_TYPE  
         FROM INFORMATION_SCHEMA.COLUMNS   
         WHERE TABLE_NAME = 'SKU'  
         AND   COLUMN_NAME = @cColumnName  
  
         SET @cUpdateStatements = @cUpdateStatements +   
            CASE WHEN @cType = 'FLOAT' THEN   
                  @cColumnName + ' = CAST( ' + @cColumnValue + ' AS FLOAT) / ' + CAST( @nQty AS NVARCHAR( 5))   
                  WHEN @cType = 'INT' THEN   
                  @cColumnName + ' = CAST( ' + @cColumnValue + ' AS FLOAT) / ' + CAST( @nQty AS NVARCHAR( 5))   
                  ELSE   
                  @cColumnName + ' = ''' + @cColumnValue + ''''  
            END  
  
         SET @cUpdateStatements = @cUpdateStatements + ', '  
      END  
  
      SET @nLoop = @nLoop + 1  
      SET @cColumnValue = ''  
      SET @cColumnName = ''  
   END  
  
   SET @cUpdateStatements = LEFT( @cUpdateStatements, LEN( RTRIM( @cUpdateStatements)) - 1)  
  
   SET @cExecStatements = N'UPDATE dbo.SKU '            
  
   SET @cFilterStatements = N' WHERE StorerKey = @cStorerKey AND SKU = @cSKU'  
   SET @cFilterStatements = @cFilterStatements + ' IF @@ERROR <> 0 SET @nErrNo = @@ERROR'  
  
   SET @cExecStatements = @cExecStatements + @cUpdateStatements + @cFilterStatements  
                               
   IF @bDebug = 1            
   SELECT @cExecStatements          
                
   SET @cExecArguments =   
      N'@cStorerKey    NVARCHAR( 15),  ' +      
       '@cSKU          NVARCHAR(20),   ' +  
       '@nErrNo        INT    OUTPUT   '   
  
   EXEC sp_ExecuteSql @cExecStatements, @cExecArguments, @cStorerKey, @cSKU, @nErrNo OUTPUT  
  
   IF @nErrNo <> 0  
   BEGIN  
      SET @nErrNo = 132151  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Update SKU Err  
      GOTO Quit  
   END  
  
Quit:                        
  
END  

GO