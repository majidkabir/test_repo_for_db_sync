SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/**************************************************************************/  
/* Stored Procedure: lsp_Validate_KitDetail_Std                           */  
/* Creation Date: 20-JAN-2020                                             */  
/* Copyright: LFL                                                         */  
/* Written by: Wan                                                        */  
/*                                                                        */  
/* Purpose:                                                               */  
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
/* 2020-06-25  Wan01    1.1   LFWM-2153 - UAT CNKitting Module shows      */
/*                            lottable is required                        */
/* 2021-01-04  Wan02    1.2   LFWM-2448 - UAT - TW  Validation while      */
/*                            creating new kitting                        */
/* 2023-03-14  NJOW01   1.3   LFWM-3608 performance tuning for XML Reading*/
/**************************************************************************/   
CREATE   PROC [WM].[lsp_Validate_KitDetail_Std] (
  @c_XMLSchemaString    NVARCHAR(MAX) 
, @c_XMLDataString      NVARCHAR(MAX) 
, @b_Success            INT OUTPUT
, @n_Err                INT OUTPUT
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
   ,  @c_ColumnName        NVARCHAR(128) = N''
   ,  @c_DataType          NVARCHAR(128) = N''
   ,  @c_TableName         NVARCHAR(30)  = N''
   ,  @c_SQL               NVARCHAR(MAX) = N''
   ,  @c_SQLSchema         NVARCHAR(MAX) = N''
   ,  @c_SQLData           NVARCHAR(MAX) = N''   
   ,  @n_Continue          INT = 1 
   ,  @n_XMLHandle         INT                  --NJOW01
   ,  @c_SQLSchema_OXML    NVARCHAR(MAX) = N''  --NJOW01
   ,  @c_TableColumns_OXML NVARCHAR(MAX) = N''  --NJOW01

   /*  --NJOW01 Removed
   IF OBJECT_ID('tempdb..#KITDETAIL') IS NOT NULL
   BEGIN
      DROP TABLE #KITDETAIL
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
   CREATE TABLE #KITDETAIL( Rowid  INT NOT NULL IDENTITY(1,1) )   

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
      SET @c_TableColumns = @c_TableColumns + @c_ColumnName + ', '
      SET @c_SQLData = @c_SQLData + 'x.value(''@' + @c_TableName + @c_ColumnName + ''', ''' + @c_DataType + ''') AS ['  + @c_ColumnName + '], '
         
      FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_DataType
   END
   CLOSE CUR_SCHEMA
   DEALLOCATE CUR_SCHEMA
       
   IF LEN(@c_SQLSchema) > 0 
   BEGIN
      SET @c_SQL = N'ALTER TABLE #KITDETAIL  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
         
      EXEC (@c_SQL)

      SET @c_SQL = N' INSERT INTO #KITDETAIL' --+  @c_UpdateTable 
                  + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                  + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1) 
                  + ' FROM @x_XMLData.nodes(''Row'') TempXML (x) '  
         
      EXEC sp_executeSQl @c_SQL
                        , N'@x_XMLData xml'
                        , @x_XMLData
      
   END
   */

   DECLARE 
         @c_Facility             NVARCHAR(5)  = ''
      ,  @c_Status               NVARCHAR(10) = ''

      ,  @c_KitKey               NVARCHAR(10) = ''
      ,  @c_kitLineNo            NVARCHAR(5)  = ''

      ,  @c_Storerkey            NVARCHAR(15) = ''
      ,  @c_Sku                  NVARCHAR(20) = ''
      ,  @c_Type                 NVARCHAR(10) = ''
      ,  @c_Loc                  NVARCHAR(10) = ''
      ,  @n_Qty                  INT          = 0

      ,  @c_LottableLabel        NVARCHAR(20) = ''
      ,  @c_Lottable01Label      NVARCHAR(20) = ''
      ,  @c_Lottable02Label      NVARCHAR(20) = ''
      ,  @c_Lottable03Label      NVARCHAR(20) = ''
      ,  @c_Lottable04Label      NVARCHAR(20) = ''
      ,  @c_Lottable05Label      NVARCHAR(20) = ''
      ,  @c_Lottable06Label      NVARCHAR(20) = ''
      ,  @c_Lottable07Label      NVARCHAR(20) = ''
      ,  @c_Lottable08Label      NVARCHAR(20) = ''
      ,  @c_Lottable09Label      NVARCHAR(20) = ''
      ,  @c_Lottable10Label      NVARCHAR(20) = ''
      ,  @c_Lottable11Label      NVARCHAR(20) = ''
      ,  @c_Lottable12Label      NVARCHAR(20) = ''
      ,  @c_Lottable13Label      NVARCHAR(20) = ''
      ,  @c_Lottable14Label      NVARCHAR(20) = ''
      ,  @c_Lottable15Label      NVARCHAR(20) = ''
      ,  @c_LottableValue        NVARCHAR(30) = ''
      ,  @c_Lottable01           NVARCHAR(18) = ''
      ,  @c_Lottable02           NVARCHAR(18) = ''
      ,  @c_Lottable03           NVARCHAR(18) = ''
      ,  @dt_Lottable04          DATETIME 
      ,  @dt_Lottable05          DATETIME 
      ,  @c_Lottable06           NVARCHAR(30) = ''
      ,  @c_Lottable07           NVARCHAR(30) = ''
      ,  @c_Lottable08           NVARCHAR(30) = ''
      ,  @c_Lottable09           NVARCHAR(30) = ''
      ,  @c_Lottable10           NVARCHAR(30) = ''
      ,  @c_Lottable11           NVARCHAR(30) = ''
      ,  @c_Lottable12           NVARCHAR(30) = ''
      ,  @dt_Lottable13          DATETIME
      ,  @dt_Lottable14          DATETIME
      ,  @dt_Lottable15          DATETIME

      ,  @n_Cnt                  INT          = 1
      ,  @c_Cnt                  NVARCHAR(2)  = ''
      ,  @n_CheckLottables       INT          = 1  --(Wan02)

      ,  @c_VLDLotLabelExist     NVARCHAR(30) = ''

   SELECT TOP 1 
         @c_KitKey      = KD.KitKey
      ,  @c_KitLineNo   = KD.KitLineNumber
      ,  @c_Type        = KD.[Type]
      ,  @c_Storerkey   = KD.Storerkey
      ,  @c_Sku         = RTRIM(KD.Sku)
      ,  @n_Qty         = KD.Qty
      ,  @c_Loc         = ISNULL(KD.Loc,'')
      ,  @c_Lottable01  = KD.Lottable01
      ,  @c_Lottable02  = KD.Lottable02
      ,  @c_Lottable03  = KD.Lottable03
      ,  @dt_Lottable04 = KD.Lottable04
      ,  @dt_Lottable05 = KD.Lottable05
      ,  @c_Lottable06  = KD.Lottable06
      ,  @c_Lottable07  = KD.Lottable07
      ,  @c_Lottable08  = KD.Lottable08
      ,  @c_Lottable09  = KD.Lottable09
      ,  @c_Lottable10  = KD.Lottable10
      ,  @c_Lottable11  = KD.Lottable11
      ,  @c_Lottable12  = KD.Lottable12
      ,  @dt_Lottable13 = KD.Lottable13
      ,  @dt_Lottable14 = KD.Lottable14
      ,  @dt_Lottable15 = KD.Lottable15
   FROM  #VALDN KD   --NJOW01

   --(Wan02) - START
   SET @n_CheckLottables = 0
   IF EXISTS(  SELECT 1 FROM KITDETAIL AS k WITH (NOLOCK) 
               WHERE k.KITKey = @c_KitKey
               AND k.KITLineNumber = @c_kitLineNo
               AND k.[Type] = @c_Type
            )
   BEGIN
      SET @n_CheckLottables = 1
   END      
   --(Wan02) - END  
       
   IF @n_CheckLottables = 1      --(Wan02) - START
   BEGIN
      SET @c_Facility = ''
      SELECT @c_Facility = KH.Facility
      FROM KIT KH WITH (NOLOCK)
      WHERE KH.KitKey = @c_KitKey

      IF @c_Facility = '' AND @c_Loc <> ''
      BEGIN
         SELECT @c_Facility = L.Facility
         FROM LOC L WITH (NOLOCK)
         WHERE L.Loc = @c_Loc
      END

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

      SELECT @c_VLDLotLabelExist = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateLotLabelExist')
   
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

         SET @c_Cnt = RIGHT('0' + CONVERT(NVARCHAR(2), @n_Cnt),2) -- For 'EXLOTLBCHK' & 'MATCHLNAME' SeekCode

         IF @c_Type = 'T' AND @n_Cnt NOT IN (5)                  --(Wan01) 
         BEGIN
            IF @n_Cnt IN (3,5) AND @c_LottableLabel <> 'RCP_DATE'--(Wan01)
            BEGIN
               IF @c_LottableLabel <> '' AND (ISNULL(@c_LottableValue,'') = '' OR (@n_Cnt IN (4,5,13,14,15) AND @c_LottableValue = '19000101'))   
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 557551
                  SET @c_errmsg = 'Lottable ' + @c_Cnt + '(' + @c_LottableLabel + ') Cannot be BLANK! (lsp_Validate_KitDetail_Std)'
                                 + '|' + @c_Cnt + '|' + @c_LottableLabel
                  GOTO EXIT_SP
               END
            END                                                 --(Wan01)
         END
      
         IF @c_Facility <> '' AND @c_VLDLotLabelExist = '1' AND @c_LottableLabel = '' AND ISNULL(@c_LottableValue,'') <> ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 557552
            SET @c_errmsg = 'Lottable' + @c_Cnt + '''s Label Not Yet Setup In SKU: ' + @c_Sku + '. Edit disallow. (lsp_Validate_KitDetail_Std)'
                           + '|' + @c_Cnt + '|' + @c_Sku
            GOTO EXIT_SP
         END

         SET @n_Cnt = @n_Cnt + 1
      END 
   END      --(Wan02) - END
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