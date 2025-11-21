SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_826SKUInfoCfm02                                 */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Update SKU setting                                          */  
/*                                                                      */  
/* Called from: rdt_Capture_SKUInfo_Confirm                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author       Purposes                               */  
/* 2021-07-30  1.0  James        WMS-17546. Created                     */
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_826SKUInfoCfm02]  
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
  
   DECLARE @cExecStatements      NVARCHAR( 1000)  
   DECLARE @cUpdateStatements    NVARCHAR( 1000)  
   DECLARE @cFilterStatements1   NVARCHAR( 1000)  
   DECLARE @cFilterStatements2   NVARCHAR( 1000)
   DECLARE @cExecArguments       NVARCHAR( 1000)  
   DECLARE @cColumnName          NVARCHAR( 30)  
   DECLARE @cColumnValue         NVARCHAR( 60)  
   DECLARE @bDebug               INT  
   DECLARE @nLoop                INT   
   DECLARE @cType                NVARCHAR( 10)  
   DECLARE @cFilterColumnName    NVARCHAR( 20)
   DECLARE @cFilterColumnValue   NVARCHAR( 20)
   DECLARE @cSQL                 NVARCHAR( 1000)
   DECLARE @cSQLParam            NVARCHAR( 1000)
   DECLARE @cSKUColumnValue      NVARCHAR( 30)
   DECLARE @nTranCount           INT
   
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN rdt_826SKUInfoCfm02  
      
   SET @bDebug = 0  
   SET @nLoop = 1  
   --SET @cUpdateStatements = 'SET '  
  
   WHILE @nLoop <= 5
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
                 @cColumnName + ' = CAST( ' + @cColumnValue + ' AS FLOAT) '   
                 WHEN @cType = 'INT' THEN   
                 @cColumnName + ' = CAST( ' + @cColumnValue + ' AS INT) '   
                 ELSE   
                 @cColumnName + ' = ''' + @cColumnValue + ''''  
            END  
  
         SET @cUpdateStatements = @cUpdateStatements + ', '  

         -- Build condition ( column to filter when update)
         DECLARE @curFilter CURSOR
         SET @curFilter = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT Long
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'SKUCHKCOND'
         AND   Storerkey = @cStorerKey
         AND   Short = '1'
         AND   UDF01 = 'Dynamic'
         ORDER BY 1
         OPEN @curFilter
         FETCH NEXT FROM @curFilter INTO @cFilterColumnName
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @cFilterColumnName <> ''  
            BEGIN  
               SELECT @cType = DATA_TYPE  
               FROM INFORMATION_SCHEMA.COLUMNS   
               WHERE TABLE_NAME = 'SKU'  
               AND   COLUMN_NAME = @cFilterColumnName  
  
               IF @@ROWCOUNT > 0
               BEGIN
                  SET @cSQL = 
                     ' SELECT @cSKUColumnValue = ' + @cFilterColumnName + ' FROM dbo.SKU WITH (NOLOCK) '  
                  SET @cSQL = @cSQL +  ' WHERE StorerKey = @cStorerKey AND SKU = @cSKU' 

               SET @cSQLParam = 
                  '@cStorerKey   NVARCHAR( 15), ' +  
                  '@cSKU         NVARCHAR( 20), ' +  
                  '@cSKUColumnValue       NVARCHAR( 30)   OUTPUT ' 

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
                  @cStorerKey, @cSKU, @cSKUColumnValue OUTPUT
      
                  SET @cFilterStatements2 = @cFilterStatements2 + ' AND ' +   
                     CASE WHEN @cType = 'FLOAT' THEN   
                           @cFilterColumnName + ' = CAST( ' + @cSKUColumnValue + ' AS FLOAT) '   
                           WHEN @cType = 'INT' THEN   
                           @cFilterColumnName + ' = CAST( ' + @cSKUColumnValue + ' AS INT) '   
                           ELSE   
                           @cFilterColumnName + ' = ''' + @cSKUColumnValue + ''''  
                     END  
               END
            END  
            FETCH NEXT FROM @curFilter INTO @cFilterColumnName
         END
         CLOSE @curFilter
         DEALLOCATE @curFilter

         -- Build condition ( for column that need special condition only update)
         SELECT @cFilterColumnValue = UDF01
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'SKUCHKCOND'
         AND   Storerkey = @cStorerKey
         AND   Short = '1'
         AND   Long = @cColumnName

         IF @cColumnName <> ''  
         BEGIN  
            SELECT @cType = DATA_TYPE  
            FROM INFORMATION_SCHEMA.COLUMNS   
            WHERE TABLE_NAME = 'SKU'  
            AND   COLUMN_NAME = @cColumnName  
  
            IF @@ROWCOUNT > 0
            BEGIN
               SET @cFilterStatements2 = @cFilterStatements2 + ' AND ' +   
                  CASE WHEN @cType = 'FLOAT' THEN   
                        @cColumnName + ' = CAST( ' + @cFilterColumnValue + ' AS FLOAT) '   
                        WHEN @cType = 'INT' THEN   
                        @cColumnName + ' = CAST( ' + @cFilterColumnValue + ' AS INT) '   
                        ELSE   
                        @cColumnName + ' = ''' + @cFilterColumnValue + ''''  
                  END  
            END
         END  

         -- Update sku table here
         SET @cUpdateStatements = LEFT( @cUpdateStatements, LEN( RTRIM( @cUpdateStatements)) - 1)  
  
         SET @cExecStatements = N'UPDATE dbo.SKU SET '            
  
         SET @cFilterStatements1 = N' WHERE StorerKey = @cStorerKey '--AND SKU = @cSKU'  
  
         SET @cExecStatements = @cExecStatements + @cUpdateStatements + @cFilterStatements1 + @cFilterStatements2

         SET @cExecStatements = @cExecStatements + ' IF @@ERROR <> 0 SET @nErrNo = @@ERROR'

         IF @bDebug = 1            
         SELECT @cExecStatements          
                
         SET @cExecArguments =   
            N'@cStorerKey    NVARCHAR( 15),  ' +      
             '@cSKU          NVARCHAR(20),   ' +  
             '@nErrNo        INT    OUTPUT   '   

         -- SELECT @cExecStatements '@cExecStatements'
         EXEC sp_ExecuteSql @cExecStatements, @cExecArguments, @cStorerKey, @cSKU, @nErrNo OUTPUT  

         IF ISNULL( @nErrNo, 0) <> 0  
         BEGIN  
            SET @nErrNo = 172551  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Update SKU Err  
            GOTO RollBackTran  
         END 
         
         -- Reset variable here for next column
         SET @cExecStatements = '' 
         SET @cExecArguments = ''
         SET @cUpdateStatements = '' 
         SET @cFilterStatements1 = ''
         SET @cFilterStatements2 = ''
      END  
  
      SET @nLoop = @nLoop + 1  
      SET @cColumnValue = ''  
      SET @cColumnName = ''  
   END  
  
   GOTO Quit  
  
   RollBackTran:  
      ROLLBACK TRAN rdt_826SKUInfoCfm02  
  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN rdt_826SKUInfoCfm02  
  
    
Fail:                            
  
END  

GO