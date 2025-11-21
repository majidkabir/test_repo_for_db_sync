SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


  
 CREATE PROC [dbo].[isp_GetLoadParmList] (
    @cStorerKey NVARCHAR(15),
    @cListName  NVARCHAR(10),
    @cStartCode NVARCHAR(30), 
    @cEndCode   NVARCHAR(30),
    @bSuccess   INT = 1 OUTPUT,
    @nErrNo     INT = 0 OUTPUT, 
    @cErrMsg    NVARCHAR(250) OUTPUT 
 )
 AS
BEGIN
   DECLARE 
            @cFieldName NVARCHAR(250), 
            @cSQL       NVARCHAR(MAX), 
            @cTableName NVARCHAR(80), 
            @cOperator  NVARCHAR(20), 
            @cItemValue NVARCHAR(4000), 
            @cColValue  NVARCHAR(250)
             

   SELECT @cFieldName = Long, @cOperator=c.UDF03, 
          @cItemValue = c.Notes 
   FROM   CODELKUP AS c WITH (NOLOCK)
   WHERE  c.LISTNAME = @cListName 
   AND    c.Code = @cStartCode
   AND    c.Short = 'CONDITION'

   IF OBJECT_ID('tempdb..#DropDown') IS NOT NULL 
      DROP TABLE #DropDown 
       
   CREATE TABLE #DropDown (
      SeqNo       INT IDENTITY(1,1),
      ItemValue   NVARCHAR(60), 
      ItemDesc    NVARCHAR(120),
      Selected    INT)
      
    SET @cTableName = SUBSTRING(@cFieldName, 1, CHARINDEX('.', @cFieldName) - 1)   
    
    --PRINT @cTableName
    
    SELECT @cSQL = N'SELECT ' + @cFieldName + N', ' + CHAR(13) +
                   RTRIM(@cFieldName) + N'+ '' ('' + CAST(COUNT(1) AS VARCHAR(10)) + '')'' AS [Description]' + CHAR(13) + 
                   N', 0 AS [Selected] ' + 
                   N' FROM ' + @cTableName + ' WITH (NOLOCK) ' + CHAR(13) + 
                   N' WHERE ' + @cTableName + '.StorerKey = ''' + @cStorerKey + ''' ' + CHAR(13) + 
                   N' AND  (' + @cFieldName + ' <> '''' AND ' + @cFieldName + ' IS NOT NULL )' + CHAR(13) + 
                   N' AND ' + @cTableName + '.LoadKey = ''''' + 
                   N' AND ' + @cTableName + '.STATUS < ''9''' +
                   N' GROUP BY ' + @cFieldName +  + CHAR(13) + 
                   N' ORDER BY 1 ' 

   --PRINT @cSQL           
    
    INSERT #DropDown (ItemValue, ItemDesc, Selected)  
    EXEC( @cSQL ) 

   IF @cOperator = '='
   BEGIN
       UPDATE #DropDown
       SET [Selected] = 1
       WHERE ItemValue IN (SELECT Notes  
         FROM CODELKUP AS c WITH (NOLOCK)
         WHERE  c.LISTNAME = @cListName 
         AND    c.Code BETWEEN @cStartCode AND @cEndCode 
         AND    c.Short = 'CONDITION' 
         AND    c.UDF03 = '=')   
   END                     
   ELSE
   IF @cOperator = 'IN' 
   BEGIN
      DECLARE 
      @nStartPosition INT, 
      @nEndPosition   INT,
      @nCol           INT 
      
      SET @nCol = 0 
      SET @nStartPosition = 1 
      SET @nEndPosition = 0 

      SET @cColValue = ''

      WHILE 1=1
      BEGIN
         SET @nEndPosition = CHARINDEX(',', @cItemValue, @nStartPosition)

         IF @nEndPosition > 0 
         BEGIN
            SET @cColValue = SUBSTRING( @cItemValue, @nStartPosition, @nEndPosition - @nStartPosition)
            SET @cColValue = LTRIM(RTRIM(REPLACE(@cColValue, '''', '')))
            SET @cColValue = LTRIM(RTRIM(REPLACE(@cColValue, '"', '')))
    
            UPDATE #DropDown
               SET [Selected] = 1
            WHERE ItemValue = @cColValue 
            
            SET @nStartPosition = @nEndPosition + 1 
            IF @nStartPosition > LEN(@cItemValue)
               BREAK
         END 
         ELSE
            BREAK 
      END 
      IF (@nEndPosition < = 0 ) AND @nStartPosition <= LEN(@cItemValue)
      BEGIN
         SET @cColValue = SUBSTRING( @cItemValue, @nStartPosition, ( LEN(@cItemValue) - @nStartPosition) + 1 )
         SET @cColValue = LTRIM(RTRIM(REPLACE(@cColValue, '''', '')))
         SET @cColValue = LTRIM(RTRIM(REPLACE(@cColValue, '"', '')))
         UPDATE #DropDown
            SET [Selected] = 1
         WHERE ItemValue = @cColValue 
         
      END 
         
   END
    
    SELECT ItemValue, ItemDesc, Selected  
    FROM #DropDown 
    ORDER BY SeqNo 
       
END -- Procedure 

GO