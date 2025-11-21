SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/**************************************************************************/  
/* Stored Procedure: lsp_Validate_TransferDetail_Std                      */  
/* Creation Date: 30-JUL-2018                                             */  
/* Copyright: LFL                                                         */  
/* Written by: Wan                                                        */  
/*                                                                        */  
/* Purpose:                                                               */  
/*                                                                        */  
/* Called By:                                                             */  
/*                                                                        */  
/*                                                                        */  
/* Version: 1.3                                                           */  
/*                                                                        */  
/* Data Modifications:                                                    */  
/*                                                                        */  
/* Updates:                                                               */  
/* Date         Author   Ver  Purposes                                    */ 
/* 2021-02-10   mingle01 1.1  Add Big Outer Begin try/Catch               */
/* 2023-03-09   NJOW01   1.2  LFWM-3608 performance tuning for XML Reading*/
/* 2023-05-23   Wan01    1.3  LFWM-3608 performance tuning, Skip Validation*/
/*                            Trafficcop IS NOT NULL                      */
/* 2024-08-12   Wan02    1.4  LFWM-4446 - RG[GIT] Serial Number Solution  */
/*                            - Transfer by Serial Number                 */
/**************************************************************************/
CREATE   PROC [WM].[lsp_Validate_TransferDetail_Std] (
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
   ,  @n_XMLHandle         INT    --NJOW01
   ,  @c_SQLSchema_OXML    NVARCHAR(MAX) = N''  --NJOW01
   ,  @c_TableColumns_OXML NVARCHAR(MAX) = N''  --NJOW01
   
   --(mingle01) - START
   BEGIN TRY
      /*  --NJOW01 Removed
      IF OBJECT_ID('tempdb..#TRANSFERDETAIL') IS NOT NULL
      BEGIN
         DROP TABLE #TRANSFERDETAIL
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
      CREATE TABLE #TRANSFERDETAIL( Rowid  INT NOT NULL IDENTITY(1,1) )   
      
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
         SET @c_SQL = N'ALTER TABLE #TRANSFERDETAIL  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
            
         EXEC (@c_SQL)

         SET @c_SQL = N' INSERT INTO #TRANSFERDETAIL' --+  @c_UpdateTable 
                     + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                     + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1) 
                     + ' FROM @x_XMLData.nodes(''Row'') TempXML (x) '  
            
         EXEC sp_executeSQl @c_SQL
                           , N'@x_XMLData xml'
                           , @x_XMLData
         
      END
      */

      DECLARE 
            @c_ToFacility           NVARCHAR(5)  = ''
         ,  @c_Status               NVARCHAR(10) = ''

         ,  @c_TransferKey          NVARCHAR(10) = ''
         ,  @c_TransferLineNo       NVARCHAR(5)  = ''

         ,  @c_ToStorerkey          NVARCHAR(15) = ''
         ,  @c_ToSku                NVARCHAR(20) = ''
         ,  @c_ToLot                NVARCHAR(10) = ''                               --(Wan02)
         ,  @c_ToLoc                NVARCHAR(10) = ''
         ,  @c_Userdefine02         NVARCHAR(20) = ''
         ,  @c_UCCNo                NVARCHAR(20) = ''
         ,  @n_FromQty              INT          = 0
         ,  @n_ToQty                INT          = 0

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
         ,  @c_ToLottable01         NVARCHAR(18) = ''
         ,  @c_ToLottable02         NVARCHAR(18) = ''
         ,  @c_ToLottable03         NVARCHAR(18) = ''
         ,  @dt_ToLottable04        DATETIME 
         ,  @dt_ToLottable05        DATETIME 
         ,  @c_ToLottable06         NVARCHAR(30) = ''
         ,  @c_ToLottable07         NVARCHAR(30) = ''
         ,  @c_ToLottable08         NVARCHAR(30) = ''
         ,  @c_ToLottable09         NVARCHAR(30) = ''
         ,  @c_ToLottable10         NVARCHAR(30) = ''
         ,  @c_ToLottable11         NVARCHAR(30) = ''
         ,  @c_ToLottable12         NVARCHAR(30) = ''
         ,  @dt_ToLottable13        DATETIME
         ,  @dt_ToLottable14        DATETIME
         ,  @dt_ToLottable15        DATETIME

         ,  @c_Facility             NVARCHAR(5) = ''                                --(Wan02)
         ,  @c_FromStorerkey        NVARCHAR(15) = ''                               --(Wan02)
         ,  @c_FromSku              NVARCHAR(20) = ''                               --(Wan02)
         ,  @c_FromLot              NVARCHAR(10) = ''                               --(Wan02)
         ,  @c_FromID               NVARCHAR(18) = ''                               --(Wan02)
         ,  @c_ToID                 NVARCHAR(18) = ''                               --(Wan02)
         ,  @c_FromSerialNo         NVARCHAR(50) = ''                               --(Wan02)
         ,  @c_ToSerialNo           NVARCHAR(50) = ''                               --(Wan02)
         ,  @c_SerialNoCapture      NVARCHAR(1)  = ''                               --(Wan02)

         ,  @n_Cnt                  INT          = 1
         ,  @n_ExistsCnt            INT          = 1
         ,  @c_Cnt                  NVARCHAR(2)  = ''
         ,  @c_SeekCode             NVARCHAR(40) = ''
         ,  @c_MatchCfgValue        NVARCHAR(30) = ''

         ,  @c_ValidateTrfLot01_LN  NVARCHAR(30) = ''
         ,  @c_ValidateTrfLot02_LN  NVARCHAR(30) = ''
         ,  @c_ValidateTrfLot03_LN  NVARCHAR(30) = ''
         ,  @c_VLDLotLabelExist     NVARCHAR(30) = ''
         ,  @c_InvTrfItf            NVARCHAR(30) = ''
         ,  @c_CheckTrfQtyDiff      NVARCHAR(30) = ''
         ,  @c_UCCTracking          NVARCHAR(30) = ''
         ,  @c_ASNFizUpdLotToSerialNo  NVARCHAR(10)=''      --(Wan02)

      IF EXISTS ( SELECT 1                                                          --(Wan01) - START
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
      END                                                                           --(Wan01) - END

      SELECT TOP 1 
            @c_TransferKey     = TFD.TransferKey
         ,  @c_TransferLineNo  = TFD.TransferLineNumber
         ,  @c_FromStorerkey   = TFD.FromStorerkey                                  --(Wan02)
         ,  @c_ToStorerkey     = TFD.ToStorerkey
         ,  @c_FromSku         = TFD.FromSku                                        --(Wan02)
         ,  @c_ToSku           = RTRIM(TFD.ToSku)
         ,  @c_FromLot         = TFD.FromLot                                        --(Wan02)
         ,  @c_ToLot           = TFD.ToLot                                          --(Wan02)
         ,  @c_ToLoc           = ISNULL(TFD.ToLoc,'')
         ,  @c_FromID          = TFD.FromID                                         --(Wan02)
         ,  @c_ToID            = TFD.ToID                                           --(Wan02)
         ,  @n_FromQty         = TFD.FromQty
         ,  @n_ToQty           = TFD.ToQty
         ,  @c_Userdefine02    = ISNULL(RTRIM(TFD.Userdefine02),'')
         ,  @c_ToLottable01    = TFD.ToLottable01
         ,  @c_ToLottable02    = TFD.ToLottable02
         ,  @c_ToLottable03    = TFD.ToLottable03
         ,  @dt_ToLottable04   = TFD.ToLottable04
         ,  @dt_ToLottable05   = TFD.ToLottable05
         ,  @c_ToLottable06    = TFD.ToLottable06
         ,  @c_ToLottable07    = TFD.ToLottable07
         ,  @c_ToLottable08    = TFD.ToLottable08
         ,  @c_ToLottable09    = TFD.ToLottable09
         ,  @c_ToLottable10    = TFD.ToLottable10
         ,  @c_ToLottable11    = TFD.ToLottable11
         ,  @c_ToLottable12    = TFD.ToLottable12
         ,  @dt_ToLottable13   = TFD.ToLottable13
         ,  @dt_ToLottable14   = TFD.ToLottable14
         ,  @dt_ToLottable15   = TFD.ToLottable15
         ,  @c_FromSerialNo    = TFD.FromSerialNo
         ,  @c_ToSerialNo      = TFD.ToSerialNo
      FROM  #VALDN TFD  --NJOW01

      IF @n_FromQty = 0 AND @n_ToQty = 0
      BEGIN
         GOTO EXIT_SP
      END

      SELECT TOP 1 
               @c_Facility   = TFH.Facility
            ,  @c_Status     = TFH.[Status]           
      FROM  [TRANSFER] TFH WITH (NOLOCK) 
      WHERE TFH.TransferKey = @c_TransferKey  
    
      IF @c_Status = 'CANC'
      BEGIN
         GOTO EXIT_SP
      END

      IF @c_ToFacility = '' AND @c_ToLoc <> ''
      BEGIN
         SELECT @c_ToFacility = L.Facility
         FROM LOC L WITH (NOLOCK)
         WHERE L.Loc = @c_ToLoc
      END

      IF @c_ToFacility <> ''
      BEGIN
         IF @n_ToQty > 0 AND @n_ToQty <> @n_FromQty
         BEGIN
            SELECT @c_InvTrfItf = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'InvTrfItf')

            IF @c_InvTrfItf = '1'  
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 557501
               SET @c_errmsg = 'To Qty Must be Same As From Qty! (lsp_Validate_TransferDetail_Std)'
               GOTO EXIT_SP
            END
         END

         SELECT @c_CheckTrfQtyDiff = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'CheckTrfQtyDiff')

         IF @c_CheckTrfQtyDiff = '1'
         BEGIN 
            IF @n_FromQty = 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 557502
               SET @c_errmsg = 'From Qty should be greater than 0 in Line# : ' + @c_TransferLineNo 
                             + '.(lsp_Validate_TransferDetail_Std). |' +  @c_TransferLineNo
               GOTO EXIT_SP
            END

            IF @n_ToQty = 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 557503
               SET @c_errmsg = 'To Qty should be greater than 0 in Line#: ' + @c_TransferLineNo 
                             + '.(lsp_Validate_TransferDetail_Std). |' +  @c_TransferLineNo
               GOTO EXIT_SP
            END

            IF @n_ToQty <> @n_FromQty
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 557504
               SET @c_errmsg = 'From/To Qty does not match in Line#: ' + @c_TransferLineNo 
                             + '. (lsp_Validate_TransferDetail_Std). |' +  @c_TransferLineNo
               GOTO EXIT_SP
            END
         END

         SELECT @c_UCCTracking = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'UCCTracking')

         IF @c_UCCTracking = '1'
         BEGIN
            SET @c_UCCNo = @c_Userdefine02

            IF @c_UCCNo = ''
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 557505
               SET @c_errmsg = 'To UCC is Required. (lsp_Validate_TransferDetail_Std)'
               GOTO EXIT_SP
            END
         END
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
           , @c_SerialNoCapture = S.SerialNoCapture                                 --(Wan02)
      FROM SKU S WITH (NOLOCK)
      WHERE S.Storerkey = @c_ToStorerkey
      AND S.Sku = @c_ToSku

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
      INSERT INTO #TMP_LA
         (  ListName    
         ,  Code        
         ,  ConfigValue 
         ,  SeekCode    
         ) 
      SELECT DISTINCT 
             CL.ListName
            ,CL.Code
            ,''
            ,SeekCode = 'EXLOTLBCHK' + RTRIM(CL.Code)
      FROM CODELKUP CL WITH (NOLOCK)
      WHERE CL.ListName = 'EXLOTLBCHK'
      AND CL.Code Like 'LOTTABLE%'
      AND CHARINDEX('T', CL.long) > 0

      IF OBJECT_ID (N'tempdb..#TMP_CFG', N'U') IS NOT NULL
      BEGIN
         DROP TABLE #TMP_CFG
      END 

      CREATE TABLE #TMP_CFG
         (  ConfigValue NVARCHAR(30) NOT NULL   DEFAULT('')
         ,  Code        NVARCHAR(30) NOT NULL   DEFAULT('')
         ) 
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateTrfLot01_LN = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateTrfLot01_LN') , 'Lottable01'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateTrfLot02_LN = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateTrfLot02_LN') , 'Lottable02' 
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateTrfLot03_LN = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateTrfLot03_LN') , 'Lottable03'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateTrfLot04_LN = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateTrfLot04_LN') , 'Lottable04' 
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateTrfLot05_LN = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateTrfLot05_LN') , 'Lottable05'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateTrfLot06_LN = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateTrfLot06_LN') , 'Lottable06'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateTrfLot07_LN = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateTrfLot07_LN') , 'Lottable07' 
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateTrfLot08_LN = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateTrfLot08_LN') , 'Lottable08'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateTrfLot09_LN = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateTrfLot09_LN') , 'Lottable09' 
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateTrfLot10_LN = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateTrfLot10_LN') , 'Lottable10'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateTrfLot11_LN = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateTrfLot11_LN') , 'Lottable11'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateTrfLot12_LN = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateTrfLot12_LN') , 'Lottable12' 
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateTrfLot13_LN = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateTrfLot13_LN') , 'Lottable13'
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateTrfLot14_LN = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateTrfLot14_LN') , 'Lottable14' 
      INSERT INTO #TMP_CFG ( ConfigValue, Code )
      SELECT ValidateTrfLot15_LN = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateTrfLot15_LN') , 'Lottable15'

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

      SELECT @c_VLDLotLabelExist = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'ValidateLotLabelExist')
      
      SET @n_Cnt = 1
      WHILE @n_Cnt <= 15
      BEGIN
         SET @c_LottableValue= CASE @n_Cnt WHEN 1  THEN @c_ToLottable01
                                           WHEN 2  THEN @c_ToLottable02
                                           WHEN 3  THEN @c_ToLottable03
                                           WHEN 4  THEN CONVERT(NVARCHAR(10), @dt_ToLottable04, 112)
                                           WHEN 5  THEN CONVERT(NVARCHAR(10), @dt_ToLottable05, 112)
                                           WHEN 6  THEN @c_ToLottable06
                                           WHEN 7  THEN @c_ToLottable07
                                           WHEN 8  THEN @c_ToLottable08
                                           WHEN 9  THEN @c_ToLottable09
                                           WHEN 10 THEN @c_ToLottable10
                                           WHEN 11 THEN @c_ToLottable11
                                           WHEN 12 THEN @c_ToLottable12
                                           WHEN 13 THEN CONVERT(NVARCHAR(10), @dt_ToLottable13, 112)
                                           WHEN 14 THEN CONVERT(NVARCHAR(10), @dt_ToLottable14, 112)
                                           WHEN 15 THEN CONVERT(NVARCHAR(10), @dt_ToLottable15, 112)
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

         IF @n_Cnt = 1 AND @c_LottableLabel = 'HMCE' AND  ISNULL(@c_LottableValue,'') <> '' 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 557506
            SET @c_errmsg = 'Please Empty To Lottable01 (' + @c_LottableLabel + ') for SKU: '
                          + @c_ToSku + '. (lsp_Validate_TransferDetail_Std)'
                          + '|' + @c_LottableLabel + '|' + @c_ToSku
            GOTO EXIT_SP
         END   

         SET @c_Cnt = RIGHT('0' + CONVERT(NVARCHAR(2), @n_Cnt),2) -- For 'EXLOTLBCHK' & 'MATCHLNAME' SeekCode
         IF @c_LottableLabel <> '' AND (ISNULL(@c_LottableValue,'') = '' OR (@n_Cnt IN (4,5,13,14,15) AND @c_LottableValue = '19000101'))
         BEGIN
            SET @c_SeekCode = 'EXLOTLBCHK' + 'Lottable' + @c_Cnt

            IF NOT EXISTS (SELECT 1 FROM #TMP_LA T WHERE T.SeekCode = @c_SeekCode )
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 557507
               SET @c_errmsg = 'To Lottable ' + @c_Cnt + '(' + @c_LottableLabel + ') Cannot be BLANK'
                             + '! (lsp_Validate_TransferDetail_Std)|' + @c_Cnt + '|' + @c_LottableLabel
               GOTO EXIT_SP
            END
         END

         IF @c_ToFacility <> '' -- Validation if facility is not blank that able to get correct storerconfig value 
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
               SET @n_Err = 557508
               SET @c_errmsg = 'To Lottable' + @c_Cnt + ' value does not match in List Name:' + @c_MatchCfgValue
                             + '. (lsp_Validate_TransferDetail_Std)'
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
               SET @n_Err = 557509
               SET @c_errmsg = 'To Lottable' + @c_Cnt + '''s Label Not Yet Setup In SKU: ' + @c_ToSku
                             + '. Edit disallow. (lsp_Validate_TransferDetail_Std)'
                             + '|' + @c_Cnt + '|' + @c_ToSku
               GOTO EXIT_SP
            END
         END
         SET @n_Cnt = @n_Cnt + 1
      END 

      IF @c_SerialNoCapture NOT IN ('1','2','3')
      BEGIN
         IF @c_ToSerialNo <> '' OR @c_FromSerialNo <> ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 557510
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err)
               + ': From & To ToSerialNo is Not required. SerialNo: ' + @c_ToSerialNo
               + '. Please make sure From & To SerialNo are same value'
               + '. (lsp_Validate_TransferDetail_Std) |' + @c_ToSerialNo
            GOTO EXIT_SP
         END
      END
      ELSE IF @c_SerialNoCapture IN ('1','2','3')
      BEGIN
         SELECT @c_ASNFizUpdLotToSerialNo = fsgr.Authority                                            --(Wan05)
         FROM dbo.fnc_SelectGetRight(@c_ToFacility, @c_ToStorerkey, '', 'ASNFizUpdLotToSerialNo')AS fsgr  --(Wan05)

         IF @c_ASNFizUpdLotToSerialNo = '1' AND @c_ToSerialNo = '' AND  --SerialNo Tracking
            @c_SerialNoCapture IN ('1','2')
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 557511
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err)
               + ': To SerialNo is required.'
               + '. (lsp_Validate_TransferDetail_Std)'
            GOTO EXIT_SP
         END

         IF @c_ToSerialNo <> ''
         BEGIN
            IF @c_ASNFizUpdLotToSerialNo = '1' AND (@c_FromID = '' OR @c_ToID = '')
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 557512
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                              + ': From & To ID is Required for SerialNo Transfer'
                              + '. From SerialNo: ' + @c_ToSerialNo
                              + '. (lsp_Validate_AdjustmentDetail_Std) |' + @c_ToSerialNo
               GOTO EXIT_SP
            END

            IF @c_FromLot = ''
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 557513
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                              + ': Invalid Transfer SerialNo FromLot'
                              + '. To SerialNo: ' + @c_ToSerialNo
                           + '. (lsp_Validate_TransferDetail_Std) |' + @c_ToSerialNo
               GOTO EXIT_SP
            END

            IF @n_ToQty NOT IN (1)
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 557514
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                              + ': Invalid Transfer To SerialNo qty'
                              + '. To SerialNo: ' + @c_ToSerialNo
                           + '. (lsp_Validate_TransferDetail_Std) |' + @c_ToSerialNo
               GOTO EXIT_SP
            END

            IF @c_FromSerialNo <> @c_ToSerialNo OR
               @c_FromSku <> @c_ToSku OR
               @c_FromID <> @c_ToID                                                 --2024-09-25
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 557515
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                              + ': Serialno transfer are required same From & To Sku'
                              + ', ID And Serialno'                                 --2024-09-25
                              + '. To SerialNo: ' + @c_ToSerialNo
                           + '. (lsp_Validate_TransferDetail_Std) |' + @c_ToSerialNo
               GOTO EXIT_SP
            END
         END
      END
      --(Wan02) - END
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