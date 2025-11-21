SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/**************************************************************************/  
/* Stored Procedure: lsp_Validate_CCDetail_Std                            */  
/* Creation Date: 09-MAR-2019                                             */  
/* Copyright: LFL                                                         */  
/* Written by: Wan                                                        */  
/*                                                                        */  
/* Purpose: LFWM-2394 - UAT - TW Unit Conversion, Lottable validation and */
/*          Lottable calculation not working when adding new row in Stock */
/*          Take Parameters                                               */  
/*                                                                        */  
/* Called By:                                                             */  
/*                                                                        */  
/*                                                                        */  
/* Version: 1.0                                                           */  
/*                                                                        */  
/* Data Modifications:                                                    */  
/*                                                                        */  
/* Updates:                                                               */  
/* Date        Author   Ver   Purposes                                    */ 
/* 2021-03-09  Wan01    1.0   Created.                                    */
/* 2023-03-14  NJOW01   1.1   LFWM-3608 performance tuning for XML Reading*/
/**************************************************************************/   
CREATE   PROC [WM].[lsp_Validate_CCDetail_Std] (
  @c_XMLSchemaString    NVARCHAR(MAX) 
, @c_XMLDataString      NVARCHAR(MAX) 
, @b_Success            INT           OUTPUT
, @n_Err                INT           OUTPUT
, @c_ErrMsg             NVARCHAR(250) OUTPUT
, @n_WarningNo          INT = 0       OUTPUT
, @c_ProceedWithWarning CHAR(1) = 'N'
, @c_IsSupervisor       CHAR(1) = 'N' 
, @c_XMLDataString_Prev NVARCHAR(MAX) = ''
) AS 
BEGIN
   SET ANSI_NULLS ON
   SET ANSI_PADDING ON
   SET ANSI_WARNINGS ON   
   SET QUOTED_IDENTIFIER ON
   SET CONCAT_NULL_YIELDS_NULL ON
   SET ARITHABORT ON
  
   DECLARE     
      @x_XMLSchema         XML
   ,  @x_XMLData           XML 
   ,  @c_TableColumns      NVARCHAR(MAX) = N''
   ,  @c_TableColumns_Upd  NVARCHAR(MAX) = N''
   ,  @c_ColumnName        NVARCHAR(128) = N''
   ,  @c_DataType          NVARCHAR(128) = N''
   ,  @c_TableName         NVARCHAR(30)  = N''
   ,  @c_SQL               NVARCHAR(MAX) = N''
   ,  @c_SQL2              NVARCHAR(MAX) = N''
   ,  @c_SQLSchema         NVARCHAR(MAX) = N''
   ,  @c_SQLData           NVARCHAR(MAX) = N''  
   ,  @n_Continue          INT = 1 
   ,  @n_XMLHandle         INT                  --NJOW01
   ,  @c_SQLSchema_OXML    NVARCHAR(MAX) = N''  --NJOW01
   ,  @c_TableColumns_OXML NVARCHAR(MAX) = N''  --NJOW01

   BEGIN TRY
        /* --NJOW01 Removed      
      IF OBJECT_ID('tempdb..#CCDetail') IS NOT NULL
      BEGIN
         DROP TABLE #CCDetail
      END
      */
      
      --NJOW01 S      
      IF OBJECT_ID('tempdb..#VALDN') IS NULL
      BEGIN
         CREATE TABLE #VALDN( Rowid  INT NOT NULL IDENTITY(1,1) )   
         
         SET @x_XMLSchema = CONVERT(XML, @c_XMLSchemaString)
         SET @x_XMLData = CONVERT(XML, @c_XMLDataString)
         
         EXEC sp_xml_preparedocument @n_XMLHandle OUTPUT, @c_XMLSchemaString      
         DECLARE CUR_SCHEMA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT ColName, DataType 
            FROM OPENXML (@n_XMLHandle, '/Table/Column',1)  
            WITH (ColName  NVARCHAR(128),  
                  DataType NVARCHAR(128))
                                    
         OPEN CUR_SCHEMA
         
         FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_DataType
         
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_TableName = ''
            IF CHARINDEX('.', @c_ColumnName) > 0 
            BEGIN
               SET @c_TableName  = LEFT(@c_ColumnName, CHARINDEX('.', @c_ColumnName))
               SET @c_ColumnName = RIGHT(@c_ColumnName, LEN(@c_ColumnName) -LEN(@c_TableName))
            END
         
            SET @c_SQLSchema  = @c_SQLSchema + @c_ColumnName + ' ' + @c_DataType + ' NULL, '
            SET @c_SQLSchema_OXML  = @c_SQLSchema_OXML + '['+@c_TableName+@c_ColumnName + '] ' + @c_DataType + ', '
            SET @c_TableColumns = @c_TableColumns + @c_ColumnName + ', '
            SET @c_TableColumns_OXML = @c_TableColumns_OXML + '[' + @c_TableName + @c_ColumnName + '], '
               
            FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_DataType
         END
         CLOSE CUR_SCHEMA
         DEALLOCATE CUR_SCHEMA
         EXEC sp_xml_removedocument @n_XMLHandle    
                       
         IF LEN(@c_SQLSchema) > 0 
         BEGIN
            SET @c_SQL = N'ALTER TABLE #VALDN  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
               
            EXEC (@c_SQL)
         
            EXEC sp_xml_preparedocument @n_XMLHandle OUTPUT, @c_XMLDataString
         
            
            SET @c_SQL = N' INSERT INTO #VALDN' 
                        + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                        + ' SELECT ' + SUBSTRING(@c_TableColumns_OXML, 1, LEN(@c_TableColumns_OXML) - 1)
                        + ' FROM  OPENXML (@n_XMLHandle, ''Row'',1) '
                        + ' WITH (' + SUBSTRING(@c_SQLSchema_OXML, 1, LEN(@c_SQLSchema_OXML) - 1) + ')'
                           
            EXEC sp_executeSQl @c_SQL
                              , N'@n_XMLHandle INT'
                              , @n_XMLHandle                                     
                                     
            EXEC sp_xml_removedocument @n_XMLHandle                         
         END
      END
      --NJOW01 E                      
      
      /*
      CREATE TABLE #CCDetail( Rowid  INT NOT NULL IDENTITY(1,1) )   

      SET @x_XMLSchema = CONVERT(XML, @c_XMLSchemaString)
      SET @x_XMLData = CONVERT(XML, @c_XMLDataString)

      DECLARE CUR_SCHEMA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT x.value('@ColName', 'NVARCHAR(128)') AS columnname
            ,x.value('@DataType','NVARCHAR(128)') AS datatype
      FROM @x_XMLSchema.nodes('/Table/Column') TempXML (x)
      
      OPEN CUR_SCHEMA

      FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_DataType

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_TableName = ''
         IF CHARINDEX('.', @c_ColumnName) > 0 
         BEGIN
            SET @c_TableName  = LEFT(@c_ColumnName, CHARINDEX('.', @c_ColumnName))
            SET @c_ColumnName = RIGHT(@c_ColumnName, LEN(@c_ColumnName) -LEN(@c_TableName))
         END

         SET @c_SQLSchema  = @c_SQLSchema + @c_ColumnName + ' ' + @c_DataType + ' NULL, '

         IF LEN(@c_SQLData + 'x.value(''@' +  @c_TableName + @c_ColumnName + ''', ''' + @c_DataType + ''') AS ['  + @c_ColumnName + '], ') <= 3000 
         BEGIN
            SET @c_TableColumns = @c_TableColumns + @c_ColumnName + ', '
            SET @c_SQLData = @c_SQLData + 'x.value(''@' + @c_TableName + @c_ColumnName + ''', ''' + @c_DataType + ''') AS ['  + @c_ColumnName + '], ' 
         END
         ELSE
         BEGIN
            SET @c_TableColumns_Upd = @c_TableColumns_Upd + @c_ColumnName + '= '+ 'x.value(''@' + @c_TableName + @c_ColumnName + ''', ''' + @c_DataType + '''), '
         END  
         FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_DataType
      END
      CLOSE CUR_SCHEMA
      DEALLOCATE CUR_SCHEMA
       
      IF LEN(@c_SQLSchema) > 0 
      BEGIN
         SET @c_SQL = N'ALTER TABLE #CCDetail  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
         
         EXEC (@c_SQL)

         SET @c_SQL = N' INSERT INTO #CCDetail' --+  @c_UpdateTable 
                     + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                     + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1) 
                     + ' FROM @x_XMLData.nodes(''Row'') TempXML (x) '  

         EXEC sp_executeSQl @c_SQL
                           , N'@x_XMLData xml'
                           , @x_XMLData

         IF @c_TableColumns_Upd <> ''
         BEGIN
            SET @c_SQL = N' UPDATE t SET ' --+  @c_UpdateTable 
                        +  SUBSTRING(@c_TableColumns_Upd, 1, LEN(@c_TableColumns_Upd) - 1)
                        + ' FROM #CCDetail t '
                        + ' JOIN @x_XMLData.nodes(''Row'') TempXML (x) ON 1=1'  
  
            EXEC sp_executeSQl @c_SQL
                              , N'@x_XMLData xml'
                              , @x_XMLData
         END
      END
      */

      DECLARE 
            @c_CCKey             NVARCHAR(10) = ''
         ,  @c_CCDetailKey       NVARCHAR(10)  = ''
         ,  @n_Cnt               INT          = 0
         ,  @n_CntNo             INT          = 0
         ,  @n_RowCnt            INT          = 0
         ,  @n_ExistsCnt         INT          = 1
         ,  @c_Cnt               NVARCHAR(2)  = ''
         ,  @c_CntNo             NVARCHAR(1)  = ''
      
         ,  @c_Storerkey         NVARCHAR(15) = ''
         ,  @c_Sku               NVARCHAR(20) = ''
         ,  @c_Loc               NVARCHAR(10) = ''      
         ,  @c_LottableLabel     NVARCHAR(20) = ''
         ,  @c_Lottable01Label   NVARCHAR(20) = ''
         ,  @c_Lottable02Label   NVARCHAR(20) = ''
         ,  @c_Lottable03Label   NVARCHAR(20) = ''
         ,  @c_Lottable04Label   NVARCHAR(20) = ''
         ,  @c_Lottable05Label   NVARCHAR(20) = ''
         ,  @c_Lottable06Label   NVARCHAR(20) = ''
         ,  @c_Lottable07Label   NVARCHAR(20) = ''
         ,  @c_Lottable08Label   NVARCHAR(20) = ''
         ,  @c_Lottable09Label   NVARCHAR(20) = ''
         ,  @c_Lottable10Label   NVARCHAR(20) = ''
         ,  @c_Lottable11Label   NVARCHAR(20) = ''
         ,  @c_Lottable12Label   NVARCHAR(20) = ''
         ,  @c_Lottable13Label   NVARCHAR(20) = ''
         ,  @c_Lottable14Label   NVARCHAR(20) = ''
         ,  @c_Lottable15Label   NVARCHAR(20) = ''
         ,  @c_LottableValue     NVARCHAR(30) = ''
         ,  @c_Lottable01        NVARCHAR(18) = ''
         ,  @c_Lottable02        NVARCHAR(18) = ''
         ,  @c_Lottable03        NVARCHAR(18) = ''
         ,  @dt_Lottable04       DATETIME 
         ,  @dt_Lottable05       DATETIME 
         ,  @c_Lottable06        NVARCHAR(30) = ''
         ,  @c_Lottable07        NVARCHAR(30) = ''
         ,  @c_Lottable08        NVARCHAR(30) = ''
         ,  @c_Lottable09        NVARCHAR(30) = ''
         ,  @c_Lottable10        NVARCHAR(30) = ''
         ,  @c_Lottable11        NVARCHAR(30) = ''
         ,  @c_Lottable12        NVARCHAR(30) = ''
         ,  @dt_Lottable13       DATETIME
         ,  @dt_Lottable14       DATETIME
         ,  @dt_Lottable15       DATETIME
         ,  @n_Qty               INT          = 0  
         ,  @n_Qty_Cnt2          INT          = 0 
         ,  @n_Qty_Cnt3          INT          = 0  

      SELECT TOP 1 
            @c_CCKey        = CCD.CCKey
         ,  @c_CCDetailKey  = CCD.CCDetailKey
         ,  @c_Storerkey    = CCD.Storerkey
         ,  @c_Sku          = RTRIM(CCD.Sku) 
         ,  @c_Loc          = CCD.Loc
         ,  @n_Qty          = CCD.Qty
         ,  @n_Qty_Cnt2     = CCD.Qty_Cnt2
         ,  @n_Qty_Cnt3     = CCD.Qty_Cnt3
      FROM  #VALDN CCD  --NJOW01

      SET @n_RowCnt = 0
      SELECT TOP 1 
            @n_CntNo =  CASE WHEN CCD.Qty <> @n_Qty THEN 1
                        WHEN CCD.Qty_Cnt2 <> @n_Qty_Cnt2 THEN 2
                        WHEN CCD.Qty_Cnt3 <> @n_Qty_Cnt3 THEN 3      
                        END
         ,  @n_RowCnt= 1
      FROM  CCDetail CCD WITH (NOLOCK)
      WHERE CCD.CCKey = @c_CCKey
      AND   CCD.CCDetailKey = @c_CCDetailKey
   
      --DEfault @n_CntNo = 1 if New Record
      IF @n_RowCnt = 0
      BEGIN
         SET @n_CntNo = 1
      END

      SET @n_Qty = 0 
      IF @n_CntNo > 0 
      BEGIN
         SELECT TOP 1 
               @c_Lottable01   = CASE WHEN @n_CntNo = 1 THEN CCD.Lottable01 
                                      WHEN @n_CntNo = 2 THEN CCD.Lottable01_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Lottable01_Cnt3
                                      END      
            ,  @c_Lottable02   = CASE WHEN @n_CntNo = 1 THEN CCD.Lottable02 
                                      WHEN @n_CntNo = 2 THEN CCD.Lottable02_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Lottable02_Cnt3
                                      END          
            ,  @c_Lottable03   = CASE WHEN @n_CntNo = 1 THEN CCD.Lottable03   
                                      WHEN @n_CntNo = 2 THEN CCD.Lottable03_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Lottable03_Cnt3
                                      END           
            ,  @dt_Lottable04  = CASE WHEN @n_CntNo = 1 THEN CCD.Lottable04  
                                      WHEN @n_CntNo = 2 THEN CCD.Lottable04_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Lottable04_Cnt3
                                      END            
            ,  @dt_Lottable05  = CASE WHEN @n_CntNo = 1 THEN CCD.Lottable05  
                                      WHEN @n_CntNo = 2 THEN CCD.Lottable05_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Lottable05_Cnt3
                                      END            
            ,  @c_Lottable06   = CASE WHEN @n_CntNo = 1 THEN CCD.Lottable06 
                                      WHEN @n_CntNo = 2 THEN CCD.Lottable06_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Lottable06_Cnt3
                                      END             
            ,  @c_Lottable07   = CASE WHEN @n_CntNo = 1 THEN CCD.Lottable07
                                      WHEN @n_CntNo = 2 THEN CCD.Lottable07_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Lottable07_Cnt3
                                      END              
            ,  @c_Lottable08   = CASE WHEN @n_CntNo = 1 THEN CCD.Lottable08
                                      WHEN @n_CntNo = 2 THEN CCD.Lottable08_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Lottable08_Cnt3
                                      END              
            ,  @c_Lottable09   = CASE WHEN @n_CntNo = 1 THEN CCD.Lottable09
                                      WHEN @n_CntNo = 2 THEN CCD.Lottable09_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Lottable09_Cnt3
                                      END              
            ,  @c_Lottable10   = CASE WHEN @n_CntNo = 1 THEN CCD.Lottable10 
                                      WHEN @n_CntNo = 2 THEN CCD.Lottable10_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Lottable10_Cnt3
                                      END                    
            ,  @c_Lottable11   = CASE WHEN @n_CntNo = 1 THEN CCD.Lottable11
                                      WHEN @n_CntNo = 2 THEN CCD.Lottable11_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Lottable11_Cnt3
                                      END                     
            ,  @c_Lottable12   = CASE WHEN @n_CntNo = 1 THEN CCD.Lottable12
                                      WHEN @n_CntNo = 2 THEN CCD.Lottable12_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Lottable12_Cnt3
                                      END                     
            ,  @dt_Lottable13  = CASE WHEN @n_CntNo = 1 THEN CCD.Lottable13 
                                      WHEN @n_CntNo = 2 THEN CCD.Lottable13_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Lottable13_Cnt3
                                      END                    
            ,  @dt_Lottable14  = CASE WHEN @n_CntNo = 1 THEN CCD.Lottable14
                                      WHEN @n_CntNo = 2 THEN CCD.Lottable14_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Lottable14_Cnt3
                                      END                     
            ,  @dt_Lottable15  = CASE WHEN @n_CntNo = 1 THEN CCD.Lottable15
                                      WHEN @n_CntNo = 2 THEN CCD.Lottable15_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Lottable15_Cnt3
                                      END                   
            ,  @n_Qty          = CASE WHEN @n_CntNo = 1 THEN CCD.Qty
                                      WHEN @n_CntNo = 2 THEN CCD.Qty_Cnt2 
                                      WHEN @n_CntNo = 3 THEN CCD.Qty_Cnt3
                                      ELSE 0
                                      END     
         FROM  #VALDN CCD  --NJOW01
         WHERE CCD.CCKey = @c_CCKey
         AND   CCD.CCDetailKey = @c_CCDetailKey 
      END

      IF @n_Qty > 0  
      BEGIN
         IF @c_Storerkey = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 559301
            SET @c_errmsg = 'Storerkey cannot be BLANK when Count Quantity > 0. (lsp_Validate_CCDetail_Std)'
            GOTO EXIT_SP
         END
      
         IF @c_Sku = '' OR @c_Loc = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 559302
            SET @c_errmsg = 'SKU or Location cannot be BLANK when Count Quantity > 0. (lsp_Validate_CCDetail_Std)'
            GOTO EXIT_SP
         END
      END 
      
      IF @n_Qty > 0 
      BEGIN
         SELECT @c_Lottable01Label = ISNULL(RTRIM(Lottable01Label),'')
              , @c_Lottable02Label = ISNULL(RTRIM(Lottable02Label),'')
              , @c_Lottable03Label = ISNULL(RTRIM(Lottable03Label),'')
              , @c_Lottable04Label = ISNULL(RTRIM(Lottable04Label),'')
              , @c_Lottable05Label = ISNULL(RTRIM(Lottable05Label),'')
              , @c_Lottable06Label = ISNULL(RTRIM(Lottable06Label),'')
              , @c_Lottable07Label = ISNULL(RTRIM(Lottable07Label),'')
              , @c_Lottable08Label = ISNULL(RTRIM(Lottable08Label),'')
              , @c_Lottable09Label = ISNULL(RTRIM(Lottable09Label),'')
              , @c_Lottable10Label = ISNULL(RTRIM(Lottable10Label),'')
              , @c_Lottable11Label = ISNULL(RTRIM(Lottable11Label),'')
              , @c_Lottable12Label = ISNULL(RTRIM(Lottable12Label),'')
              , @c_Lottable13Label = ISNULL(RTRIM(Lottable13Label),'')
              , @c_Lottable14Label = ISNULL(RTRIM(Lottable14Label),'')
              , @c_Lottable15Label = ISNULL(RTRIM(Lottable15Label),'')
         FROM SKU S WITH (NOLOCK)
         WHERE S.Storerkey = @c_Storerkey
         AND S.Sku = @c_Sku

         SET @n_Cnt = 1
         WHILE @n_Cnt <= 15
         BEGIN
            SET @c_LottableValue= CASE @n_Cnt WHEN 1  THEN @c_Lottable01
                                              WHEN 2  THEN @c_Lottable02
                                              WHEN 3  THEN @c_Lottable03
                                              WHEN 4  THEN CONVERT(NVARCHAR(10), @dt_Lottable04, 112)
                                              WHEN 5  THEN CONVERT(NVARCHAR(10), @dt_Lottable05, 112)
                                              WHEN 6  THEN @c_Lottable06
                                              WHEN 7  THEN @c_Lottable07
                                              WHEN 8  THEN @c_Lottable08
                                              WHEN 9  THEN @c_Lottable09
                                              WHEN 10 THEN @c_Lottable10
                                              WHEN 11 THEN @c_Lottable11
                                              WHEN 12 THEN @c_Lottable12
                                              WHEN 13 THEN CONVERT(NVARCHAR(10), @dt_Lottable13, 112)
                                              WHEN 14 THEN CONVERT(NVARCHAR(10), @dt_Lottable14, 112)
                                              WHEN 15 THEN CONVERT(NVARCHAR(10), @dt_Lottable15, 112)
                                              END
      
            SET @c_LottableLabel= CASE @n_Cnt WHEN 1  THEN @c_Lottable01Label
                                              WHEN 2  THEN @c_Lottable02Label
                                              WHEN 3  THEN @c_Lottable03Label
                                              WHEN 4  THEN @c_Lottable04Label
                                              WHEN 5  THEN @c_Lottable05Label
                                              WHEN 6  THEN @c_Lottable06Label
                                              WHEN 7  THEN @c_Lottable07Label
                                              WHEN 8  THEN @c_Lottable08Label
                                              WHEN 9  THEN @c_Lottable09Label
                                              WHEN 10 THEN @c_Lottable10Label
                                              WHEN 11 THEN @c_Lottable11Label
                                              WHEN 12 THEN @c_Lottable12Label
                                              WHEN 13 THEN @c_Lottable13Label
                                              WHEN 14 THEN @c_Lottable14Label
                                              WHEN 15 THEN @c_Lottable15Label
                                              END

            IF @c_LottableLabel <> '' AND (ISNULL(@c_LottableValue,'') = '' OR (@n_Cnt IN (4,5,13,14,15) AND @c_LottableValue = '19000101'))  
            BEGIN
               IF NOT ((@n_Cnt = '4' AND @c_LottableLabel = 'GENEXPDATE') OR (@n_Cnt = '5' AND @c_LottableLabel = 'RCP_DATE')) 
               BEGIN
                  SET @c_CntNo = RTRIM(CONVERT(NVARCHAR(1),@n_CntNo))
                  SET @n_Continue = 3  
                  SET @n_Err = 559303  
                  SET @c_errmsg = 'Lottable ' + @c_Cnt + '(' + @c_LottableLabel + ') For Sku''s: ' + @c_Sku +' Count: ' + @c_CntNo 
                                + ' Cannot be BLANK! (lsp_Validate_CCDetail_Std)'  
                                + '|' + @c_Cnt + '|' + @c_LottableLabel + '|' + @c_Sku + '|' + @c_CntNo 
                  GOTO EXIT_SP 
               END 
            END  

            SET @n_Cnt = @n_Cnt + 1
         END 
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   EXIT_SP:
   
   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0 
   END
   ELSE
   BEGIN
      SET @b_Success = 1   
   END
END -- Procedure

GO