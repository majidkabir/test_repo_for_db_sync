SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/**************************************************************************/  
/* Stored Procedure: lsp_Validate_InventoryHold_Std                       */  
/* Creation Date: 05-SEP-2018                                             */  
/* Copyright: LFL                                                         */  
/* Written by: Wan                                                        */  
/*                                                                        */  
/* Purpose:                                                               */  
/*                                                                        */  
/* Called By: WM.lsp_Wrapup_Validation_Wrapper                            */  
/*                                                                        */  
/*                                                                        */  
/* Version: 1.0                                                           */  
/*                                                                        */  
/* Data Modifications:                                                    */  
/*                                                                        */  
/* Updates:                                                               */  
/* Date         Author   Ver  Purposes                                    */ 
/* 2021-02-10   mingle01 1.1  Add Big Outer Begin try/Catch               */
/* 2023-03-14   NJOW01   1.2  LFWM-3608 performance tuning for XML Reading*/
/**************************************************************************/   
CREATE   PROC [WM].[lsp_Validate_InventoryHold_Std] (
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
   
   --(mingle01) - START
   BEGIN TRY
      /*  --NJOW01 Removed    
      IF OBJECT_ID('tempdb..#INVENTORYHOLD') IS NOT NULL
      BEGIN
         DROP TABLE #INVENTORYHOLD
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
      CREATE TABLE #INVENTORYHOLD( Rowid  INT NOT NULL IDENTITY(1,1) )   

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
         SET @c_SQL = N'ALTER TABLE #INVENTORYHOLD  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
            
         EXEC (@c_SQL)

         SET @c_SQL = N' INSERT INTO #INVENTORYHOLD' --+  @c_UpdateTable 
                     + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                     + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1) 
                     + ' FROM @x_XMLData.nodes(''Row'') TempXML (x) '  
            
         EXEC sp_executeSQl @c_SQL
                           , N'@x_XMLData xml'
                           , @x_XMLData
      END
      */

      DECLARE
            @c_InventoryHoldKey  NVARCHAR(10) = '' 
         ,  @c_Storerkey         NVARCHAR(15) = ''
         ,  @c_Sku               NVARCHAR(20) = ''
         ,  @c_Lot               NVARCHAR(10) = ''
         ,  @c_Loc               NVARCHAR(10) = ''
         ,  @c_ID                NVARCHAR(18) = ''
         ,  @c_Status            NVARCHAR(10) = ''
         ,  @c_Hold              NVARCHAR(1)  = ''
         ,  @c_Lottable01        NVARCHAR(18) = ''  
         ,  @c_Lottable02        NVARCHAR(18) = ''  
         ,  @c_Lottable03        NVARCHAR(18) = ''  
         ,  @c_Lottable04        NVARCHAR(8)  = ''  
         ,  @c_Lottable05        NVARCHAR(8)  = ''  
         ,  @c_Lottable06        NVARCHAR(30) = ''  
         ,  @c_Lottable07        NVARCHAR(30) = ''  
         ,  @c_Lottable08        NVARCHAR(30) = ''  
         ,  @c_Lottable09        NVARCHAR(30) = ''  
         ,  @c_Lottable10        NVARCHAR(30) = ''  
         ,  @c_Lottable11        NVARCHAR(30) = ''  
         ,  @c_Lottable12        NVARCHAR(30) = ''  
         ,  @c_Lottable13        NVARCHAR(8)  = ''  
         ,  @c_Lottable14        NVARCHAR(8)  = ''  
         ,  @c_Lottable15        NVARCHAR(8)  = ''  

         ,  @n_Count             INT          = 0
         ,  @c_InvHoldKey        NVARCHAR(10) = ''

      SELECT TOP 1 
            @c_InventoryHoldKey = ISNULL(RTRIM(IH.InventoryHoldKey),'')
         ,  @c_Storerkey  = ISNULL(RTRIM(IH.Storerkey),'')
         ,  @c_Sku        = ISNULL(RTRIM(IH.Sku),'')
         ,  @c_Lot        = ISNULL(RTRIM(IH.Lot),'') 
         ,  @c_Loc        = ISNULL(RTRIM(IH.Loc),'') 
         ,  @c_ID         = ISNULL(RTRIM(IH.ID),'')
         ,  @c_Status     = ISNULL(RTRIM(IH.[Status]),'')  
         ,  @c_Hold       = ISNULL(RTRIM(IH.Hold),'')
         ,  @c_Lottable01 = ISNULL(RTRIM(IH.Lottable01),'')   
         ,  @c_Lottable02 = ISNULL(RTRIM(IH.Lottable02),'')   
         ,  @c_Lottable03 = ISNULL(RTRIM(IH.Lottable03),'')   
         ,  @c_Lottable04 = ISNULL(CONVERT(NCHAR(8),IH.Lottable04,112),'19000101')  
         ,  @c_Lottable05 = ISNULL(CONVERT(NCHAR(8),IH.Lottable05,112),'19000101')  
         ,  @c_Lottable06 = ISNULL(RTRIM(IH.Lottable06),'')  
         ,  @c_Lottable07 = ISNULL(RTRIM(IH.Lottable07),'')   
         ,  @c_Lottable08 = ISNULL(RTRIM(IH.Lottable08),'')   
         ,  @c_Lottable09 = ISNULL(RTRIM(IH.Lottable09),'')   
         ,  @c_Lottable10 = ISNULL(RTRIM(IH.Lottable10),'')   
         ,  @c_Lottable11 = ISNULL(RTRIM(IH.Lottable11),'')   
         ,  @c_Lottable12 = ISNULL(RTRIM(IH.Lottable12),'')   
         ,  @c_Lottable13 = ISNULL(CONVERT(NCHAR(8),IH.Lottable13,112),'19000101')  
         ,  @c_Lottable14 = ISNULL(CONVERT(NCHAR(8),IH.Lottable14,112),'19000101')  
         ,  @c_Lottable15 = ISNULL(CONVERT(NCHAR(8),IH.Lottable15,112),'19000101') 
      FROM  #VALDN IH  --NJOW01
      ORDER BY RowId 

      IF @c_Lottable04 = '19000101' SET @c_Lottable04 = ''
      IF @c_Lottable05 = '19000101' SET @c_Lottable05 = ''
      IF @c_Lottable13 = '19000101' SET @c_Lottable13 = ''
      IF @c_Lottable14 = '19000101' SET @c_Lottable14 = ''
      IF @c_Lottable15 = '19000101' SET @c_Lottable15 = ''

      IF @c_lot = '' AND @c_id = '' AND @c_loc = ''                                                                         
      AND @c_lottable01 = '' AND @c_lottable02 = '' AND @c_lottable03 = '' AND @c_lottable04 = '' AND @c_lottable05 = '' 
      AND @c_lottable06 = '' AND @c_lottable07 = '' AND @c_lottable08 = '' AND @c_lottable09 = '' AND @c_lottable10 = '' 
      AND @c_lottable11 = '' AND @c_lottable12 = '' AND @c_lottable13 = '' AND @c_lottable14 = '' AND @c_lottable15 = ''  
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 551401
         SET @c_errmsg = 'Either Lot / Movable Unit / Loc / Lottables must have value'
                       + '. (lsp_Validate_InventoryHold_Std)'
         GOTO EXIT_SP
      END 

      IF (@c_lot <> '' OR @c_id <> '' OR @c_loc <> '') AND  
         (@c_lottable01 <> '' OR @c_lottable02 <> '' OR @c_lottable03 <> '' OR @c_lottable04 <> '' OR @c_lottable05 <> '' OR 
          @c_lottable06 <> '' OR @c_lottable07 <> '' OR @c_lottable08 <> '' OR @c_lottable09 <> '' OR @c_lottable10 <> '' OR 
          @c_lottable11 <> '' OR @c_lottable12 <> '' OR @c_lottable13 <> '' OR @c_lottable14 <> '' OR @c_lottable15 <> '' ) 
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 551402
         SET @c_errmsg = 'Either (Lot / Movable Unit / Loc) have value OR (Lottables) have value. Cannot be both'
                       + '. (lsp_Validate_InventoryHold_Std)'
         GOTO EXIT_SP
      END 

      IF (@c_lottable01 <> '' OR @c_lottable02 <> '' OR @c_lottable03 <> '' OR @c_lottable04 <> '' OR @c_lottable05 <> '')
      BEGIN
         IF @c_StorerKey = '' OR @c_SKU = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 551403
            SET @c_errmsg = 'Storer and SKU cannot be BLANK'
                          + '. (lsp_Validate_InventoryHold_Std)'
            GOTO EXIT_SP
         END
      END

      IF @c_Status = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 551404
         SET @c_errmsg = 'Status must have value'
                       + '. (lsp_Validate_InventoryHold_Std)'
         GOTO EXIT_SP
      END 

      IF @c_hold = '0' 
      BEGIN
         SET @n_Count = 0

         SELECT @n_Count = 1
         FROM   CODELKUP CL(NOLOCK)
         WHERE  CL.ListName = 'NOUNHOLD'
         AND    CL.Code = @c_Status
      
         IF @n_Count > 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 551405
            SET @c_errmsg = 'Not Allowed To Unhold For'
                          + ' Status = ' + RTRIM(@c_Status)
                          + '. (lsp_Validate_InventoryHold_Std)'
                          + ' |' + RTRIM(@c_Status)
            GOTO EXIT_SP         
         END
      END

      IF NOT EXISTS (SELECT 1 
                     FROM INVENTORYHOLD IH WITH (NOLOCK) 
                     WHERE IH.InventoryHoldKey = @c_InventoryHoldKey
                    )
      BEGIN
         SET @n_Count = 0
         SET @c_InvHoldKey = ''

         IF @c_Lot <> ''
         BEGIN
            SELECT TOP 1 @n_Count = 1
                  ,@c_InvHoldKey = IH.InventoryHoldKey
            FROM   INVENTORYHOLD IH WITH (NOLOCK) 
            WHERE  IH.Lot = @c_Lot
            AND    IH.[Status] = @c_Status

            IF @n_Count > 0
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 551406
               SET @c_errmsg = 'Duplicate Lot + Status in InventoryHold table,'
                             + ' InventoryHoldKey = ' + RTRIM(@c_InvHoldKey)
                             + '. (lsp_Validate_InventoryHold_Std)'
                             + ' |' + RTRIM(@c_InvHoldKey)
               GOTO EXIT_SP 
            END
         END

         IF @c_ID <> ''
         BEGIN
            SELECT TOP 1 @n_Count = 1
                  ,@c_InvHoldKey = IH.InventoryHoldKey
            FROM   INVENTORYHOLD IH WITH (NOLOCK) 
            WHERE  IH.ID = @c_ID
            AND    IH.[Status] = @c_Status

            IF @n_Count > 0
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 551407
               SET @c_errmsg = 'Duplicate ID + Status in InventoryHold table,'
                             + ' InventoryHoldKey = ' + RTRIM(@c_InvHoldKey)
                             + '. (lsp_Validate_InventoryHold_Std)'
                             + ' |' + RTRIM(@c_InvHoldKey)
               GOTO EXIT_SP 
            END
         END

         IF @c_Loc <> ''
         BEGIN
            SELECT TOP 1 @n_Count = 1
                  ,@c_InvHoldKey = IH.InventoryHoldKey
            FROM   INVENTORYHOLD IH WITH (NOLOCK) 
            WHERE  IH.Loc = @c_Loc
            AND    IH.[Status] = @c_Status

            IF @n_Count > 0
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 551408
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Duplicate Loc + Status in InventoryHold table,'
                             + ' InventoryHoldKey = ' + RTRIM(@c_InvHoldKey)
                             + '. (lsp_Validate_InventoryHold_Std)'
                             + ' |' + RTRIM(@c_InvHoldKey)
               GOTO EXIT_SP 
            END
         END
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
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