SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispSortNPackExtInfo6                                */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Sort and pack extended info show                            */  
/*          1. LOC; 2. style, color & size                              */  
/*                                                                      */
/* Called from: rdtfnc_SortAndPack                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author   Purposes                                   */  
/* 2017-Mar-21 1.0  James    WMS907. Created                            */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispSortNPackExtInfo6]  
   @cLoadKey         NVARCHAR(10),  
   @cOrderKey        NVARCHAR(10),  -- (james07)
   @cConsigneeKey    NVARCHAR(15),  
   @cLabelNo         NVARCHAR(20) OUTPUT,  
   @cStorerKey       NVARCHAR(15),  
   @cSKU             NVARCHAR(20),  
   @nQTY             INT,   
   @cExtendedInfo    NVARCHAR(20) OUTPUT,  
   @cExtendedInfo2   NVARCHAR(20) OUTPUT,
   @cLangCode        NVARCHAR(3),           -- (Chee01)
   @bSuccess         INT          OUTPUT,   -- (Chee01)
   @nErrNo           INT          OUTPUT,   -- (Chee01) 
   @cErrMsg          NVARCHAR(20) OUTPUT,   -- (Chee01)
   @nMobile          INT                    -- (Chee02)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @cStyle            NVARCHAR( 20),   
           @cColor            NVARCHAR( 10),
           @cSize             NVARCHAR( 10), 
           @cLOC              NVARCHAR( 10),
           @cColumnName       NVARCHAR( 20), 
           @cColumnValue      NVARCHAR( 20), 
           @cTableName        NVARCHAR( 20), 
           @cExecStatements   NVARCHAR( 4000), 
           @cExecArguments    NVARCHAR( 4000),
           @cUserDefineField  NVARCHAR( 1000),
           @cDataType         NVARCHAR( 128),
           @nStart            INT,
           @nLen              INT,
           @nStep             INT,
           @nInputKey         INT,
           @nFunc             INT

   SELECT @nStep = Step, 
          @nInputKey = InputKey, 
          @nFunc = Func
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SET @cExtendedInfo = ''
   SET @cExtendedInfo2 = ''

   IF @nStep = 2
   BEGIN
      SELECT @cLOC = UDF02
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE ListName = 'SortLOC'
      AND   Code = @cConsigneeKey
      AND   StorerKey = @cStorerKey

      SELECT @cStyle = Style, 
             @cColor = Color, 
             @cSize = Size
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU

      SET @cExtendedInfo = 'SORT LOC: ' + @cLOC

      IF LEN( ISNULL( @cStyle, '') + ISNULL( @cColor, '') + ISNULL( @cSize, '')) > 0
         SET @cExtendedInfo2 = ISNULL( @cStyle, '') + '/' + ISNULL( @cColor, '') + '/' + ISNULL( @cSize, '')
   END

   IF @nStep = 3
   BEGIN
      -- if label no = '' then is get next task, screen will remain in step 3
      IF ISNULL( @cLabelNo, '') <> ''
      BEGIN
         SELECT @cLOC = UDF02
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'SortLOC'
         AND   Code = @cConsigneeKey
         AND   StorerKey = @cStorerKey

         SET @cExtendedInfo = 'SORT LOC: ' + @cLOC

         SELECT @cColumnName = rdt.RDTGetConfig( @nFunc, 'ShowUserdefineInfo', @cStorerKey)

         /* Not use TABLENAME.FIELD format because svalue only can store 20 chars. 
            Too long if use in ORDERDETAIL
         SELECT @nStart = CHARINDEX( '.', @cUserDefineField) + 1
         SELECT @nLen = LEN( @cUserDefineField) - CHARINDEX( '.', @cUserDefineField) + 1
         SELECT @cTableName = SUBSTRING( @cUserDefineField, 1, @nStart - 2)
         SELECT @cColumnName = SUBSTRING( @cUserDefineField, @nStart, @nLen)
         */
         SELECT @cDataType = DATA_TYPE 
         FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_NAME = 'ORDERDETAIL' 
         AND COLUMN_NAME = @cColumnName

         IF ISNULL( @cDataType, '') <> ''
         BEGIN
            SET @cExecStatements = ''
            SET @cExecArguments = ''
            SET @cColumnValue = ''
         
            SELECT TOP 1 @cOrderKey = O.OrderKey
            FROM dbo.ORDERS O WITH (NOLOCK) 
            JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
            WHERE O.LoadKey = @cLoadKey
            AND   O.ConsigneeKey = @cConsigneeKey
            AND   OD.SKU = @cSKU

            SET @cExecStatements = 'SELECT @cColumnValue = ' + @cColumnName + ' ' +
                                    'FROM dbo.ORDERDETAIL' + ' WITH (NOLOCK) ' +
                                    'WHERE StorerKey = ''' + RTRIM(@cStorerKey)  + ''' ' + 
                                    'AND   OrderKey = ''' + RTRIM(@cOrderKey)  + ''' ' 

            SET @cExecArguments = N'@cColumnValue            NVARCHAR( 20)      OUTPUT ' 
            PRINT @cExecStatements
            EXEC sp_ExecuteSql @cExecStatements
                              , @cExecArguments
                              , @cColumnValue          OUTPUT

            SET @cExtendedInfo2 = @cColumnValue
         END
      END
      ELSE
      BEGIN
         SELECT @cLOC = UDF02
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'SortLOC'
         AND   Code = @cConsigneeKey
         AND   StorerKey = @cStorerKey

         SELECT @cStyle = Style, 
                @cColor = Color, 
                @cSize = Size
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU

         SET @cExtendedInfo = 'SORT LOC: ' + @cLOC

         IF LEN( ISNULL( @cStyle, '') + ISNULL( @cColor, '') + ISNULL( @cSize, '')) > 0
            SET @cExtendedInfo2 = ISNULL( @cStyle, '') + '/' + ISNULL( @cColor, '') + '/' + ISNULL( @cSize, '')
      END
   END

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cLOC = UDF02
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'SortLOC'
         AND   Code = @cConsigneeKey
         AND   StorerKey = @cStorerKey

         SET @cExtendedInfo = 'SORT LOC: ' + @cLOC

         SELECT @cColumnName = rdt.RDTGetConfig( @nFunc, 'ShowUserdefineInfo', @cStorerKey)

         /* Not use TABLENAME.FIELD format because svalue only can store 20 chars. 
            Too long if use in ORDERDETAIL
         SELECT @nStart = CHARINDEX( '.', @cUserDefineField) + 1
         SELECT @nLen = LEN( @cUserDefineField) - CHARINDEX( '.', @cUserDefineField) + 1
         SELECT @cTableName = SUBSTRING( @cUserDefineField, 1, @nStart - 2)
         SELECT @cColumnName = SUBSTRING( @cUserDefineField, @nStart, @nLen)
         */
         SELECT @cDataType = DATA_TYPE 
         FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_NAME = 'ORDERDETAIL' 
         AND COLUMN_NAME = @cColumnName

         IF ISNULL( @cDataType, '') <> ''
         BEGIN
            SET @cExecStatements = ''
            SET @cExecArguments = ''
            SET @cColumnValue = ''
         
            SELECT TOP 1 @cOrderKey = O.OrderKey
            FROM dbo.ORDERS O WITH (NOLOCK) 
            JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
            WHERE O.LoadKey = @cLoadKey
            AND   O.ConsigneeKey = @cConsigneeKey
            AND   OD.SKU = @cSKU

            SET @cExecStatements = 'SELECT @cColumnValue = ' + @cColumnName + ' ' +
                                    'FROM dbo.ORDERDETAIL' + ' WITH (NOLOCK) ' +
                                    'WHERE StorerKey = ''' + RTRIM(@cStorerKey)  + ''' ' + 
                                    'AND   OrderKey = ''' + RTRIM(@cOrderKey)  + ''' ' 

            SET @cExecArguments = N'@cColumnValue            NVARCHAR( 20)      OUTPUT ' 
            PRINT @cExecStatements
            EXEC sp_ExecuteSql @cExecStatements
                              , @cExecArguments
                              , @cColumnValue          OUTPUT

            SET @cExtendedInfo2 = @cColumnValue
         END
      END
      ELSE
      BEGIN
         SELECT @cLOC = UDF02
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'SortLOC'
         AND   Code = @cConsigneeKey
         AND   StorerKey = @cStorerKey

         SELECT @cStyle = Style, 
                @cColor = Color, 
                @cSize = Size
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU

         SET @cExtendedInfo = 'SORT LOC: ' + @cLOC

         IF LEN( ISNULL( @cStyle, '') + ISNULL( @cColor, '') + ISNULL( @cSize, '')) > 0
            SET @cExtendedInfo2 = ISNULL( @cStyle, '') + '/' + ISNULL( @cColor, '') + '/' + ISNULL( @cSize, '')
      END
   END

   IF @nStep = 7
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cLOC = UDF02
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'SortLOC'
         AND   Code = @cConsigneeKey
         AND   StorerKey = @cStorerKey

         SET @cExtendedInfo = 'SORT LOC: ' + @cLOC

         SELECT @cColumnName = rdt.RDTGetConfig( @nFunc, 'ShowUserdefineInfo', @cStorerKey)

         /* Not use TABLENAME.FIELD format because svalue only can store 20 chars. 
            Too long if use in ORDERDETAIL
         SELECT @nStart = CHARINDEX( '.', @cUserDefineField) + 1
         SELECT @nLen = LEN( @cUserDefineField) - CHARINDEX( '.', @cUserDefineField) + 1
         SELECT @cTableName = SUBSTRING( @cUserDefineField, 1, @nStart - 2)
         SELECT @cColumnName = SUBSTRING( @cUserDefineField, @nStart, @nLen)
         */
         SELECT @cDataType = DATA_TYPE 
         FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_NAME = 'ORDERDETAIL' 
         AND COLUMN_NAME = @cColumnName

         IF ISNULL( @cDataType, '') <> ''
         BEGIN
            SET @cExecStatements = ''
            SET @cExecArguments = ''
            SET @cColumnValue = ''
         
            SELECT TOP 1 @cOrderKey = O.OrderKey
            FROM dbo.ORDERS O WITH (NOLOCK) 
            JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
            WHERE O.LoadKey = @cLoadKey
            AND   O.ConsigneeKey = @cConsigneeKey
            AND   OD.SKU = @cSKU

            SET @cExecStatements = 'SELECT @cColumnValue = ' + @cColumnName + ' ' +
                                    'FROM dbo.ORDERDETAIL' + ' WITH (NOLOCK) ' +
                                    'WHERE StorerKey = ''' + RTRIM(@cStorerKey)  + ''' ' + 
                                    'AND   OrderKey = ''' + RTRIM(@cOrderKey)  + ''' ' 

            SET @cExecArguments = N'@cColumnValue            NVARCHAR( 20)      OUTPUT ' 
            PRINT @cExecStatements
            EXEC sp_ExecuteSql @cExecStatements
                              , @cExecArguments
                              , @cColumnValue          OUTPUT

            SET @cExtendedInfo2 = @cColumnValue
         END
      END
      ELSE
      BEGIN
         SELECT @cLOC = UDF02
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'SortLOC'
         AND   Code = @cConsigneeKey
         AND   StorerKey = @cStorerKey

         SELECT @cStyle = Style, 
                @cColor = Color, 
                @cSize = Size
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU

         SET @cExtendedInfo = 'SORT LOC: ' + @cLOC

         IF LEN( ISNULL( @cStyle, '') + ISNULL( @cColor, '') + ISNULL( @cSize, '')) > 0
            SET @cExtendedInfo2 = ISNULL( @cStyle, '') + '/' + ISNULL( @cColor, '') + '/' + ISNULL( @cSize, '')
      END
   END

QUIT:  
END -- End Procedure  

GO