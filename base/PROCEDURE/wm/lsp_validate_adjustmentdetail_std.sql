SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/**************************************************************************/  
/* Stored Procedure: WM.lsp_Validate_AdjustmentDetail_Std                 */  
/* Creation Date: 30-JUL-2018                                             */  
/* Copyright: Maserk Logistics                                            */  
/* Written by: Wan                                                        */  
/*                                                                        */  
/* Purpose:                                                               */  
/*                                                                        */  
/* Called By:                                                             */  
/*                                                                        */  
/*                                                                        */  
/* Version: 1.7                                                           */  
/*                                                                        */  
/* Data Modifications:                                                    */  
/*                                                                        */  
/* Updates:                                                               */  
/* Date        Author   Ver   Purposes                                    */ 
/* 2020-03-03  Wan01    1.1   Validate Lot                                */
/* 2020-08-24  Wan02    1.2   LFWM-2296 - UAT[CN] SKE_ADJ_Lottable05      */
/* 2021-02-10  mingle01 1.2   Add Big Outer Begin try/Catch               */
/* 2021-04-23  Wan03    1.3   LFWM-2569 - UAT - TW  Finalize Adjustment   */
/*                            Alert                                       */
/* 2022-06-14  Wan04    1.2   LFWM-3501 - PROD & UAT - GIT SCE Adjustment */
/*                            Issue                                       */
/* 2022-06-14  Wan04    1.2   DevObj Combine script                       */
/* 2023-03-14  NJOW01   1.3   LFWM-3608 performance tuning for XML Reading*/
/* 2023-04-12  Wan05    1.4   LFWM-4145-[CN] Prod  Mannings Channel column*/
/*                            need to be limited by the settings in       */
/*                            CODELKUP in Inventory Adjustment screen     */
/* 2023-05-18  Wan06    1.5   LFWM-4116 - [CN]CONVERSE_ADJ_'Copy value to */
/*                            support all details in one Adjustmentkey    */
/* 2024-05-28  NJOW02   1.6   WMS-24558 - Fix @c_Lot Null in checking     */
/* 2024-08-02  Wan07    1.7   LFWM-4397 - RG [GIT] Serial Number Solution */
/*                            - Adjustment by Serial Number               */
/**************************************************************************/   
CREATE   PROC [WM].[lsp_Validate_AdjustmentDetail_Std] (
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
        /* --NJOW01 Removed
      IF OBJECT_ID('tempdb..#ADJUSTMENTDETAIL') IS NOT NULL
      BEGIN
         DROP TABLE #ADJUSTMENTDETAIL
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
      CREATE TABLE #ADJUSTMENTDETAIL( Rowid  INT NOT NULL IDENTITY(1,1) )   

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
         SET @c_SQL = N'ALTER TABLE #ADJUSTMENTDETAIL  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
            
         EXEC (@c_SQL)

         SET @c_SQL = N' INSERT INTO #ADJUSTMENTDETAIL' --+  @c_UpdateTable 
                     + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                     + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1) 
                     + ' FROM @x_XMLData.nodes(''Row'') TempXML (x) '  
            
         EXEC sp_executeSQl @c_SQL
                           , N'@x_XMLData xml'
                           , @x_XMLData
         
      END
      */

      DECLARE 
            @c_AdjustmentKey           NVARCHAR(10) = ''
         ,  @c_AdjustmentLineNo        NVARCHAR(5) = ''
         ,  @c_Facility                NVARCHAR(5)  = ''
         ,  @c_Storerkey               NVARCHAR(15) = ''
         ,  @c_Sku                     NVARCHAR(20) = ''
         ,  @c_FinalizedFlag_Ins       NVARCHAR(10) = ''
         ,  @c_FinalizedFlag_Del       NVARCHAR(10) = ''
         ,  @c_FinalizedFlag_H_Del     NVARCHAR(10) = ''
         ,  @c_Loc                     NVARCHAR(10) = ''
         ,  @c_UDF05                   NVARCHAR(20) = ''
         ,  @c_UCCNo                   NVARCHAR(20) = ''
         ,  @c_Packkey                 NVARCHAR(10) = ''       --(Wan03)           
         ,  @c_ReasonCode              NVARCHAR(30) = ''       --(Wan03) 
         ,  @n_Qty                     INT          = 0
         ,  @c_Channel                 NVARCHAR(20) = ''       --(Wan05)
         
         ,  @c_LottableLabel           NVARCHAR(20) = ''
         ,  @c_Lottable01Label         NVARCHAR(20) = ''
         ,  @c_Lottable02Label         NVARCHAR(20) = ''
         ,  @c_Lottable03Label         NVARCHAR(20) = ''
         ,  @c_Lottable04Label         NVARCHAR(20) = ''
         ,  @c_Lottable05Label         NVARCHAR(20) = ''
         ,  @c_Lottable06Label         NVARCHAR(20) = ''
         ,  @c_Lottable07Label         NVARCHAR(20) = ''
         ,  @c_Lottable08Label         NVARCHAR(20) = ''
         ,  @c_Lottable09Label         NVARCHAR(20) = ''
         ,  @c_Lottable10Label         NVARCHAR(20) = ''
         ,  @c_Lottable11Label         NVARCHAR(20) = ''
         ,  @c_Lottable12Label         NVARCHAR(20) = ''
         ,  @c_Lottable13Label         NVARCHAR(20) = ''
         ,  @c_Lottable14Label         NVARCHAR(20) = ''
         ,  @c_Lottable15Label         NVARCHAR(20) = ''
         ,  @c_LottableValue           NVARCHAR(30) = ''
         ,  @c_Lottable01              NVARCHAR(18) = ''
         ,  @c_Lottable02              NVARCHAR(18) = ''
         ,  @c_Lottable03              NVARCHAR(18) = ''
         ,  @dt_Lottable04             DATETIME 
         ,  @dt_Lottable05             DATETIME 
         ,  @c_Lottable06              NVARCHAR(30) = ''
         ,  @c_Lottable07              NVARCHAR(30) = ''
         ,  @c_Lottable08              NVARCHAR(30) = ''
         ,  @c_Lottable09              NVARCHAR(30) = ''
         ,  @c_Lottable10              NVARCHAR(30) = ''
         ,  @c_Lottable11              NVARCHAR(30) = ''
         ,  @c_Lottable12              NVARCHAR(30) = ''
         ,  @dt_Lottable13             DATETIME
         ,  @dt_Lottable14             DATETIME
         ,  @dt_Lottable15             DATETIME

         ,  @n_Cnt                     INT          = 1
         ,  @n_ExistsCnt               INT          = 1
         ,  @c_Cnt                     NVARCHAR(2)  = ''
         ,  @c_SeekCode                NVARCHAR(40) = ''
         ,  @c_MatchCfgValue           NVARCHAR(30) = ''

         ,  @c_Lot                     NVARCHAR(10) = ''       --(Wan01)   
         ,  @c_Getlot                  NVARCHAR(10) = ''       --(Wan01)  
         ,  @c_ID                      NVARCHAR(18) = ''       --(Wan07) 
         ,  @c_SerialNo                NVARCHAR(50) = ''       --(Wan07) 
         ,  @c_SerialNoCapture         NVARCHAR(1)  = ''       --(Wan07) 

         ,  @c_AdjStatusControl        NVARCHAR(30) = ''
         ,  @c_VLDLotLabelExist        NVARCHAR(30) = ''
         ,  @c_SkipUDF05UccChkInAdj    NVARCHAR(30) = ''
         ,  @c_AdjAllowZeroQty         NVARCHAR(30) = ''    --(Wan03)
         ,  @c_ChannelInventoryMgmt    NVARCHAR(30) = ''    --(Wan05)
         ,  @c_ASNFizUpdLotToSerialNo  NVARCHAR(10)=''      --(Wan07)
         
      IF EXISTS ( SELECT 1                                                          --(Wan06) - START
                 FROM tempdb.INFORMATION_SCHEMA.COLUMNS c 
                 JOIN tempdb.dbo.SysObjects AS s ON s.[name] = c.TABLE_NAME 
                 WHERE s.id = OBJECT_ID('tempdb..#VALDN')                     
                 AND   c.[COLUMN_NAME] = 'TrafficCop' 
                 )
      BEGIN
         SET @n_ExistsCnt = 0
         SET @c_SQL = N'SELECT @n_ExistsCnt=1 FROM #VALDN AD WHERE ad.TrafficCop IS NULL'
         
         EXEC sp_ExecuteSQL @c_SQL, N'@n_ExistsCnt INT OUTPUT', @n_ExistsCnt OUTPUT
         
         IF @n_ExistsCnt = 0
         BEGIN
            GOTO EXIT_SP
         END
      END                                                                           --(Wan06) - END
  
      SELECT TOP 1 
            @c_AdjustmentKey     = AD.AdjustmentKey
         ,  @c_AdjustmentLineNo  = AD.AdjustmentLineNumber
         ,  @c_Storerkey         = AD.Storerkey
         ,  @c_Sku               = AD.Sku
         ,  @c_FinalizedFlag_Ins = AD.FinalizedFlag
         ,  @c_Lot               = ISNULL(AD.Lot,'')          --(Wan01) --NJOW01
         ,  @c_Loc               = ISNULL(AD.Loc,'')
         ,  @c_ID                = ad.ID                      --(Wan06)  
         ,  @c_Lottable01        = AD.Lottable01
         ,  @c_Lottable02        = AD.Lottable02
         ,  @c_Lottable03        = AD.Lottable03
         ,  @dt_Lottable04       = AD.Lottable04
         ,  @dt_Lottable05       = AD.Lottable05
         ,  @c_Lottable06        = AD.Lottable06
         ,  @c_Lottable07        = AD.Lottable07
         ,  @c_Lottable08        = AD.Lottable08
         ,  @c_Lottable09        = AD.Lottable09
         ,  @c_Lottable10        = AD.Lottable10
         ,  @c_Lottable11        = AD.Lottable11
         ,  @c_Lottable12        = AD.Lottable12
         ,  @dt_Lottable13       = AD.Lottable13
         ,  @dt_Lottable14       = AD.Lottable14
         ,  @dt_Lottable15       = AD.Lottable15
         ,  @c_UDF05             = ISNULL(AD.UserDefine05,'')
         ,  @c_UCCNo             = ISNULL(AD.UCCNo,'')
         ,  @c_Packkey           = ISNULL(AD.Packkey,'')       --(Wan03) 
         ,  @c_ReasonCode        = ISNULL(AD.ReasonCode,'')    --(Wan03)  
         ,  @n_Qty               = ISNULL(AD.Qty,0)            --(Wan03) 
         ,  @c_Channel           = ad.channel                  --(Wan05) 
         ,  @c_SerialNo          = ad.SerialNo                 --(Wan07)           
      FROM  #VALDN AD  --NJOW01
      
      SELECT TOP 1 
            @c_FinalizedFlag_Del = AD.FinalizedFlag
      FROM  ADJUSTMENTDETAIL AD WITH (NOLOCK)
      WHERE AD.AdjustmentKey = @c_AdjustmentKey
      AND   AD.AdjustmentLineNumber =@c_AdjustmentLineNo

      SELECT @c_Facility = ADJ.facility
            ,@c_Storerkey= ADJ.Storerkey
            ,@c_FinalizedFlag_H_Del = ADJ.FinalizedFlag
      FROM ADJUSTMENT ADJ WITH (NOLOCK)
      WHERE ADJ.AdjustmentKey = @c_AdjustmentKey

      IF @c_Facility = '' AND @c_Loc <> ''
      BEGIN
         SELECT @c_Facility = L.Facility
         FROM LOC L WITH (NOLOCK)
         WHERE L.Loc = @c_Loc
      END
      
      --(Wan03) - START      
      SELECT @c_AdjAllowZeroQty = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AdjAllowZeroQty')  

      IF @c_AdjAllowZeroQty NOT IN ('1') AND @n_Qty = 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 552062
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Disallow to adjust 0 qty'
                       + '. (lsp_Validate_AdjustmentDetail_Std)'
         GOTO EXIT_SP               
      END
      --(Wan03) - END    

      BEGIN TRY
         EXECUTE dbo.nspGetRight 
               @c_facility  = @c_Facility
            ,  @c_storerkey = @c_Storerkey 
            ,  @c_sku       = NULL
            ,  @c_configkey = 'AdjStatusControl'
            ,  @b_Success   = @b_Success           OUTPUT
            ,  @c_authority = @c_AdjStatusControl  OUTPUT
            ,  @n_err       = @n_err               OUTPUT
            ,  @c_errmsg    = @c_errmsg            OUTPUT 
      END TRY

      BEGIN CATCH
         SET @n_err = 552051
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing nspGetRight - AdjStatusControl'
                        + '. (lsp_Validate_AdjustmentDetail_Std)'
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0        
      BEGIN        
         SET @n_continue = 3      
         GOTO EXIT_SP
      END 

      IF @c_AdjStatusControl = '1' 
      BEGIN
         IF @c_FinalizedFlag_H_Del = ''
         BEGIN
            SET @c_FinalizedFlag_H_Del = 'N'
         END

         IF @c_FinalizedFlag_Ins = ''
         BEGIN
            SET @c_FinalizedFlag_Ins = 'N'
         END

         IF @c_FinalizedFlag_Del = ''
         BEGIN
            SET @c_FinalizedFlag_Del = 'N'
         END

         IF @c_FinalizedFlag_Ins = @c_FinalizedFlag_Del
         BEGIN
            GOTO EXIT_SP
         END

         IF (@c_FinalizedFlag_H_Del = 'N' OR @c_FinalizedFlag_H_Del = 'S' OR @c_FinalizedFlag_H_Del = 'Y')
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 552052
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Disallow to open/submit/approve/reject detail record. (lsp_Validate_AdjustmentDetail_Std)'
            GOTO EXIT_SP
         END

         IF @c_FinalizedFlag_Ins IN ( 'A', 'R' ) AND @c_IsSupervisor <> 'Y'  
         BEGIN 
            SET @n_Continue = 3
            SET @n_Err = 552053
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': User is disallow to approve/reject detail record. (lsp_Validate_AdjustmentDetail_Std)'
            GOTO EXIT_SP
         END

         IF @c_FinalizedFlag_Ins NOT IN ( 'A', 'R' )
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 552054
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Disallow to Change Detail Finalized Status. (lsp_Validate_AdjustmentDetail_Std)'
            GOTO EXIT_SP
         END
      END
      
      SET @c_ChannelInventoryMgmt = '0'                  --(Wan05) - START
      SELECT @c_ChannelInventoryMgmt = fsgr.Authority
      FROM dbo.fnc_SelectGetRight(@c_Facility, @c_Storerkey, '', 'ChannelInventoryMgmt') AS fsgr 

      IF @c_ChannelInventoryMgmt = 1 AND @c_Channel = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 552064
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Channel is required. (lsp_Validate_AdjustmentDetail_Std)'
         GOTO EXIT_SP
      END                                                --(Wan05) - END

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
           , @c_SerialNoCapture = SerialNoCapture                                   --(Wan07)
      FROM SKU S WITH (NOLOCK)
      WHERE S.Storerkey = @c_Storerkey
      AND S.Sku = @c_Sku

      IF OBJECT_ID (N'tempdb..#TMP_LA', N'U') IS NOT NULL
      BEGIN
         DROP TABLE #TMP_LA
      END 

      CREATE TABLE #TMP_LA
         (  ListName    NVARCHAR(10) NOT NULL DEFAULT('')
         ,  Code        NVARCHAR(30) NOT NULL DEFAULT('')
         ,  ConfigValue NVARCHAR(30) NOT NULL DEFAULT('')  
         ,  SeekCode    NVARCHAR(40) NOT NULL DEFAULT('') PRIMARY KEY
         ) 

      IF OBJECT_ID (N'tempdb..#TMP_CFG', N'U') IS NOT NULL
      BEGIN
         DROP TABLE #TMP_CFG
      END 

      CREATE TABLE #TMP_CFG
         (  ConfigValue NVARCHAR(30) NOT NULL   DEFAULT('')
         ,  Code        NVARCHAR(30) NOT NULL   DEFAULT('')
         ) 
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateADJLot01_LN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateADJLot01_LN') , 'Lottable01'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateADJLot02_LN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateADJLot02_LN') , 'Lottable02' 
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateADJLot03_LN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateADJLot03_LN') , 'Lottable03'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateADJLot04_LN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateADJLot04_LN') , 'Lottable04'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateADJLot05_LN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateADJLot05_LN') , 'Lottable05'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateADJLot06_LN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateADJLot06_LN') , 'Lottable06'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateADJLot07_LN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateADJLot07_LN') , 'Lottable07'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateADJLot08_LN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateADJLot08_LN') , 'Lottable08'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateADJLot09_LN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateADJLot09_LN') , 'Lottable09'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateADJLot10_LN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateADJLot10_LN') , 'Lottable10'--(Wan02)
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateADJLot11_LN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateADJLot11_LN') , 'Lottable11'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateADJLot12_LN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateADJLot12_LN') , 'Lottable12' 
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateADJLot13_LN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateADJLot13_LN') , 'Lottable13'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateADJLot14_LN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateADJLot14_LN') , 'Lottable14'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateADJLot15_LN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateADJLot15_LN') , 'Lottable15'

      INSERT INTO #TMP_LA
         (  ListName    
         ,  Code        
         ,  ConfigValue 
         ,  SeekCode    
         ) 
      SELECT DISTINCT 
             ListName = ISNULL(CL.ListName,'')
            ,T.Code
            ,T.ConfigValue
            ,SeekCode = 'MATCHLNAME' + RTRIM(T.Code)
      FROM #TMP_CFG T
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON  T.ConfigValue = CL.ListName 
                                          AND T.Code = CL.Code

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
         IF @c_LottableLabel <> '' AND (ISNULL(@c_LottableValue,'') = '' OR (@n_Cnt IN (4,5,13,14,15) AND @c_LottableValue = '19000101'))
         BEGIN
            IF @c_LottableLabel <> 'RCP_DATE' AND @n_Cnt = 5                                              --(Wan02)
            BEGIN 
               SET @n_Continue = 3
               SET @n_Err = 552055
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Lottable ' + @c_Cnt + '(' + @c_LottableLabel + ') Cannot be BLANK!'
                             + ' (lsp_Validate_AdjustmentDetail_Std)'
                             + '|' + @c_Cnt + '|' + @c_LottableLabel
               GOTO EXIT_SP
            END                                                                                          --(Wan02)
         END

         IF @c_Facility <> ''  -- Validation if facility is not blank that able to get correct storerconfig value
         BEGIN
            SET @c_SeekCode = 'MATCHLNAME' + 'Lottable' + @c_Cnt
            SET @n_ExistsCnt = 0
            SET @c_MatchCfgValue = ''
            SELECT @n_ExistsCnt = 1
                  ,@c_MatchCfgValue = CASE WHEN T.ListName <> T.ConfigValue THEN RTRIM(T.ConfigValue) ELSE '' END 
            FROM #TMP_LA T 
            WHERE T.SeekCode = @c_SeekCode 
            AND T.ConfigValue NOT IN ('','0','1') 
    
            IF @n_ExistsCnt = 1 AND @c_MatchCfgValue <> ''
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 552056
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Lottable' + @c_Cnt + ' value does not match in List Name:' + @c_MatchCfgValue 
                             + '. (lsp_Validate_AdjustmentDetail_Std)'
                             + '|' + @c_Cnt + '|' + @c_MatchCfgValue
               GOTO EXIT_SP
            END
         
            IF @c_VLDLotLabelExist = '1' AND @c_LottableLabel = '' AND 
               (
                ( @n_Cnt NOT IN (4,5,13,14,15) AND ISNULL(@c_LottableValue,'') <> '' ) OR
                ( @n_Cnt IN (4,5,13,14,15) AND ISNULL(@c_LottableValue,'') <> '19000101' )
               )
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 552057
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Lottable' + @c_Cnt + '''s Label Not Yet Setup In SKU: ' + @c_Sku + '. Edit disallow. (lsp_Validate_AdjustmentDetail_Std)'
                             + '|' + @c_Cnt + '|' + @c_Sku
               GOTO EXIT_SP
            END
         END

         SET @n_Cnt = @n_Cnt + 1
      END 

      IF @c_UCCNo = '' AND @c_Facility <> ''
      BEGIN
         SELECT @c_SkipUDF05UccChkInAdj = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'SkipUDF05UccChkInAdj')
         IF @c_SkipUDF05UccChkInAdj <> '1'
         BEGIN
            SET @c_UCCNo = @c_UDF05
         END
      END

      IF @c_UCCNo <> '' 
      BEGIN
         SET @n_Cnt = 0
         SET @n_ExistsCnt = 0
         SELECT @n_Cnt = COUNT(1)
               ,@n_ExistsCnt = ISNULL(MAX(CASE WHEN Sku = @c_Sku THEN 1 ELSE 0 END),0)
         FROM   UCC WITH (NOLOCK) 
         WHERE  StorerKey = @c_StorerKey
         AND    UCCNo = @c_UCCNo

         IF @n_Cnt = 0
         BEGIN
            IF @n_Qty < 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 552058
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Cannot adjust negative qty to a non exist uccno. (lsp_Validate_AdjustmentDetail_Std)'
               GOTO EXIT_SP
            END
         END
         ELSE
         BEGIN
            IF @n_ExistsCnt = 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 552059
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Inconsistence UCC Sku and Adjustment sku. (lsp_Validate_AdjustmentDetail_Std)'
               GOTO EXIT_SP
            END
         END
      END

      --(Wan01) - START
      IF ISNULL(@c_Lot,'') <> ''   --NJOW01
      BEGIN
         IF NOT EXISTS (SELECT 1 
                        FROM LOT WITH (NOLOCK)
                        WHERE Lot = @c_lot
                        )
         BEGIN
            SET @c_Getlot = ''
            EXECUTE nsp_lotlookup
                  @c_Storerkey=@c_Storerkey 
               ,  @c_Sku=@c_Sku 
               ,  @c_Lottable01=@c_Lottable01 
               ,  @c_Lottable02=@c_Lottable02 
               ,  @c_Lottable03=@c_Lottable03 
               ,  @c_Lottable04=@dt_Lottable04 
               ,  @c_Lottable05=@dt_Lottable05 
               ,  @c_Lottable06=@c_Lottable06 
               ,  @c_Lottable07=@c_Lottable07 
               ,  @c_Lottable08=@c_Lottable08 
               ,  @c_Lottable09=@c_Lottable09 
               ,  @c_Lottable10=@c_Lottable10 
               ,  @c_Lottable11=@c_Lottable11 
               ,  @c_Lottable12=@c_Lottable12 
               ,  @c_Lottable13=@dt_Lottable13 
               ,  @c_Lottable14=@dt_Lottable14 
               ,  @c_Lottable15=@dt_Lottable15 
               ,  @c_lot=@c_Getlot        OUTPUT 
               ,  @b_Success=@b_Success   OUTPUT 
               ,  @n_err=@n_err           OUTPUT 
               ,  @c_errmsg=@c_errmsg     OUTPUT 

            IF @c_Getlot <> ''  
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 552060
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Invalid Lot found. (lsp_Validate_AdjustmentDetail_Std)'
                             + '|' + @c_Lot 
               GOTO EXIT_SP
            END
            ELSE
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 552061
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Lot is not required. Please empty lot for system to generate lot'
                             + '. (lsp_Validate_AdjustmentDetail_Std)'
               GOTO EXIT_SP
            END
         END
      END
      --(Wan01) - END 
      
      --(Wan04) - START
      IF @c_ReasonCode = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 552063
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Please Enter Reason Code. (lsp_Validate_AdjustmentDetail_Std)'
         GOTO EXIT_SP         
      END
      --(Wan04) - END

      --(Wan07) - START
      IF @c_SerialNoCapture NOT IN ('1','2','3') AND @c_SerialNo <> '' 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 552069
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) 
                        + ': SerialNo is NOT required.'
                        + '. SerialNo: ' + @c_SerialNo 
                     + '. (lsp_Validate_AdjustmentDetail_Std) |' + @c_SerialNo

         GOTO EXIT_SP
      END
      ELSE IF @c_SerialNoCapture IN ('1','2','3')
      BEGIN
         SELECT @c_ASNFizUpdLotToSerialNo = fsgr.Authority                                            --(Wan05)
         FROM dbo.fnc_SelectGetRight(@c_Facility, @c_Storerkey, '', 'ASNFizUpdLotToSerialNo')AS fsgr  --(Wan05)

         IF  @c_SerialNo <> '' AND @n_Qty NOT IN (-1,1)             
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 552067
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) 
                           + ': SerialNo adjust qty is allowed either -1 OR 1'
                           + '. SerialNo: ' + @c_SerialNo 
                        + '. (lsp_Validate_AdjustmentDetail_Std) |' + @c_SerialNo

            GOTO EXIT_SP
         END

         IF @c_ASNFizUpdLotToSerialNo = '1' --SerialNo Tracking 
         BEGIN
            IF @c_SerialNo = '' AND @c_SerialNoCapture IN ('1','2')
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 552065
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) 
                  + ': SerialNo is required.'
                  + '. (lsp_Validate_AdjustmentDetail_Std)'
               GOTO EXIT_SP  
            END
            ELSE IF @c_SerialNo <> ''
            BEGIN
               IF @c_ID = ''   
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 552066
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) 
                                 + ': ID is Required for SerialNo Adjusment'
                                 + '. SerialNo: ' + @c_SerialNo 
                                 + '. (lsp_Validate_AdjustmentDetail_Std) |' + @c_SerialNo
                  GOTO EXIT_SP
               END

               IF @c_Lot = '' AND @n_Qty = -1 
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 552068
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) 
                                 + ': Negative SerialNo Adjustment requires Lot #'
                                 + '. SerialNo: ' + @c_SerialNo  
                                 + '. (lsp_Validate_AdjustmentDetail_Std) |' + @c_SerialNo
               END
            END
         END
      END 
      --(Wan07) - END
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