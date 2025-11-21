SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819PalletCrit01                                */
/*                                                                      */
/* Purpose: Putaway by id get suggested loc in defined PA zone only     */
/*                                                                      */
/* Called from: rdtfnc_PutawayByID                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2019-01-28  1.0  James    WMS-7793 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819PalletCrit01] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cStorerKey    NVARCHAR( 15),
   @cParam1       NVARCHAR( 20),
   @cParam2       NVARCHAR( 20),
   @cParam3       NVARCHAR( 20),
   @cParam4       NVARCHAR( 20),
   @cParam5       NVARCHAR( 20),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nIdentifier       INT,
           @cTableName        NVARCHAR( 60),
           @cColumnName       NVARCHAR( 60),
           @cField2Validate   NVARCHAR( 100),
           @cDataType         NVARCHAR( 128),
           @cErrMsg1          NVARCHAR( 20),
           @cErrMsg2          NVARCHAR( 20),
           @cErrMsg3          NVARCHAR( 20),
           @cErrMsg4          NVARCHAR( 20),
           @cErrMsg5          NVARCHAR( 20),
           @cValue            NVARCHAR( 60),
           @cCode             NVARCHAR( 10),
           @cPalletCriteria   NVARCHAR( 20),
           @nDebug            INT,
           @nCount            INT,
           @cExecStatements   NVARCHAR( 4000), 
           @cExecArguments    NVARCHAR( 4000)


   -- Check mandatory field
   DECLARE CUR_VALIDATE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT Code, Notes
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE ListName = 'RDTPAValid'
   AND   StorerKey = @cStorerKey
   AND   ISNULL( UDF01, '') = '1' -- Turned on
   ORDER BY 1
   OPEN CUR_VALIDATE
   FETCH NEXT FROM CUR_VALIDATE INTO @cCode, @cField2Validate
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @nIdentifier = CHARINDEX('.', @cField2Validate)
      SET @cTableName = LEFT( @cField2Validate, ( @nIdentifier - 1))
      SET @cColumnName = RIGHT( @cField2Validate, (LEN( @cField2Validate) - @nIdentifier))
      --SELECT '@nIdentifier', @nIdentifier, '@cTableName', @cTableName, '@cColumnName', @cColumnName

      SELECT @cDataType = DATA_TYPE 
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_NAME = @cTableName 
      AND COLUMN_NAME = @cColumnName

      IF @cDataType = ''            
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '134051'
         SET @cErrMsg2 = rdt.rdtgetmessage( 134051, @cLangCode, 'DSP') -- INVALID COLUME NAME
         SET @cErrMsg3 = @cColumnName
         SET @cErrMsg4 = ''
         SET @cErrMsg5 = ''
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
         @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
         END
         CLOSE CUR_VALIDATE
         DEALLOCATE CUR_VALIDATE
         GOTO Quit
      END                            

      SET @cValue = ''
      SET @cValue = CASE 
                     WHEN @cCode = 'UDF01' THEN @cParam1
                     WHEN @cCode = 'UDF02' THEN @cParam2
                     WHEN @cCode = 'UDF03' THEN @cParam3
                     WHEN @cCode = 'UDF04' THEN @cParam4
                     WHEN @cCode = 'UDF05' THEN @cParam5
                     ELSE '' END

      IF @cValue = ''            
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '134052'
         SET @cErrMsg2 = rdt.rdtgetmessage( 134052, @cLangCode, 'DSP') -- VALUE REQUIRED FOR
         SET @cErrMsg3 = @cColumnName
         SET @cErrMsg4 = ''
         SET @cErrMsg5 = ''
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
         @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
         END
         CLOSE CUR_VALIDATE
         DEALLOCATE CUR_VALIDATE
         GOTO Quit
      END                            

      -- No velue key in then no validation req
      -- Check blank value in step 1
      IF ISNULL( @cValue, '') = '' 
         GOTO FETCH_NEXT   -- Continue next record to validate


         SET @cExecStatements = ''
         SET @cExecArguments = ''
         SET @nCount = 0

         SET @cExecStatements = 'SELECT @nCount = 1 ' + 
                                 'FROM dbo.' + @cTableName + ' WITH (NOLOCK) ' +
                                 'WHERE ' + 
                                    CASE WHEN @cDataType IN ('int', 'float') 
                                         THEN ' ISNULL( ' + @cColumnName + ', 0) = CAST( ' + @cValue + ' AS INT)'
                                         WHEN @cDataType = 'datetime'
                                         THEN ' CONVERT( NVARCHAR( 20), ' + @cColumnName + ', 103) = ''' + 
                                                CONVERT( NVARCHAR( 20), CONVERT( DATETIME, @cValue, 103), 103) + ''' '
                                         ELSE ' ISNULL( ' + @cColumnName + ', '''') = ''' + @cValue + ''' '
                                    END 
            
         SET @cExecArguments = N'@nCount            INT      OUTPUT ' 

         IF @nDebug = 1
         BEGIN
            PRINT @cExecStatements
            PRINT @cExecArguments
         END

         EXEC sp_ExecuteSql @cExecStatements
                           , @cExecArguments
                           , @nCount          OUTPUT

         IF ISNULL( @nCount, 0) = 0
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '134053'
            SET @cErrMsg2 = @cColumnName
            SET @cErrMsg3 = rdt.rdtgetmessage( 134053, @cLangCode, 'DSP') -- VALUE NOT EXISTS
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
            CLOSE CUR_VALIDATE
            DEALLOCATE CUR_VALIDATE
            GOTO Quit
         END

      FETCH_NEXT:
      FETCH NEXT FROM CUR_VALIDATE INTO @cCode, @cField2Validate
   END
   CLOSE CUR_VALIDATE
   DEALLOCATE CUR_VALIDATE               

   Quit:
END


GO