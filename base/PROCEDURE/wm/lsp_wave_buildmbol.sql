SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_Wave_BuildMBOL                                  */                                                                                  
/* Creation Date:                                                       */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: WM - Wave Creation                                          */                                                                                  
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.4                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */ 
/* 28-Dec-2020  SWT01   1.0   Adding Begin Try/Catch                    */
/* 04-Jan-2021 SWT02    1.1   Do not execute login if user already      */
/*                            changed                                   */
/* 2021-02-24  Wan01    1.2   Fixed to call lsp_SetUser SP & Quip SP    */
/*                            if @c_UserName <> SUSER_SNAME()           */
/* 2021-08--5  Wan02    1.3   Fixed Linkage issue                       */
/* 2022-09-20  SPChin   1.4   JSM-96335 - Extend ExternOrderkey Length  */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_Wave_BuildMBOL]                                                                                                                       
      @c_Wavekey        NVARCHAR(10)  
   ,  @c_Facility       NVARCHAR(5)                                                                                                                     
   ,  @c_StorerKey      NVARCHAR(15)                                                                                                                            
   ,  @b_Success        INT            = 1  OUTPUT  
   ,  @n_err            INT            = 0  OUTPUT                                                                                                             
   ,  @c_ErrMsg         NVARCHAR(255)  = '' OUTPUT 
   ,  @c_UserName       NVARCHAR(128)  = ''              
   ,  @b_debug          INT            = 0                                                                                                                              
AS                                                                                                                                                          
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF                                                                                                                          
   
   DECLARE @n_Continue                 BIT            = 1
         , @n_StartTCnt                INT            = @@TRANCOUNT  
                                                                                                                               
                                                                                                                                                                  
   DECLARE @d_StartBatchTime           DATETIME       = GETDATE() 
         , @d_StartTime                DATETIME       = GETDATE()                                                                                                                  
         , @d_EndTime                  DATETIME                                                                                                                        
         , @d_StartTime_Debug          DATETIME       = GETDATE()                                                                                                                     
         , @d_EndTime_Debug            DATETIME                                                                                                                        
         , @d_EditDate                 DATETIME        
         
         , @c_BuildKeyFacility         NVARCHAR(5)    = ''
         , @c_BuildKeyStorerkey        NVARCHAR(10)   = ''                                                                                                                
             
         , @n_cnt                      INT            = 0 
         , @n_BuildGroupCnt            INT            = 0                 
         , @n_idx                      INT            = 0    
                                                                                    
         , @n_MaxMBOLOrders            INT            = 0                                                                                                               
         , @n_MaxOpenQty               INT            = 0
         , @n_MaxMBOL                  INT            = 0

         , @c_Restriction              NVARCHAR(30) = '' 
         , @c_Restriction01            NVARCHAR(30) = ''      
         , @c_Restriction02            NVARCHAR(30) = ''
         , @c_Restriction03            NVARCHAR(30) = ''
         , @c_Restriction04            NVARCHAR(30) = ''
         , @c_Restriction05            NVARCHAR(30) = ''
         , @c_RestrictionValue         NVARCHAR(10) = ''
         , @c_RestrictionValue01       NVARCHAR(10) = ''
         , @c_RestrictionValue02       NVARCHAR(10) = ''
         , @c_RestrictionValue03       NVARCHAR(10) = ''
         , @c_RestrictionValue04       NVARCHAR(10) = '' 
         , @c_RestrictionValue05       NVARCHAR(10) = ''
                                                  
         , @c_BuildParmKey             NVARCHAR(10)   = ''
         , @c_ParmBuildType            NVARCHAR(10)   = ''
         , @c_FieldName                NVARCHAR(100)  = ''                                                                                                                     
         , @c_Operator                 NVARCHAR(60)   = ''

         , @c_TableName                NVARCHAR(30)   = ''                                                                                                                
         , @c_ColName                  NVARCHAR(100)  = ''                                                                                                                 
         , @c_ColType                  NVARCHAR(128)  = ''

         , @b_GroupFlag                BIT            = 0          
         , @c_SortBy                   NVARCHAR(2000) = ''                                                                                                                
         , @c_SortSeq                  NVARCHAR(10)   = ''  
         , @c_GroupBySortField         NVARCHAR(2000) = ''                                                                                                                      
                                                                                                            
         , @c_Field01                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field02                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field03                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field04                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field05                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field06                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field07                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field08                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field09                  NVARCHAR(60)   = '' 
         , @c_Field10                  NVARCHAR(60)   = ''  
         , @c_SQLField                 NVARCHAR(2000) = ''
         , @c_SQLFieldGroupBy          NVARCHAR(2000) = ''                 
         , @c_SQLBuildByGroup          NVARCHAR(4000) = ''
         , @c_SQLBuildByGroupWhere     NVARCHAR(4000) = ''  
                                                                                                                         
         , @c_SQL                      NVARCHAR(MAX)  = ''
         , @c_SQLParms                 NVARCHAR(2000) = ''
         , @c_SQLWhere                 NVARCHAR(2000) = ''  
         , @c_SQLGroupBy               NVARCHAR(2000) = ''  

         , @n_Num                      INT            = 0
              
         , @n_OrderCnt                 INT            = 0
         , @n_MBOLCnt                  INT            = 0
         , @n_MaxOrders                INT            = 0
         , @n_OpenQty                  INT            = 0
         , @n_TotalOrders              INT            = 0                                                                                                                 
         , @n_TotalOpenQty             INT            = 0
         , @n_TotalOrderCnt            INT            = 0
         , @n_Weight                   FLOAT          = 0.00
         , @n_Cube                     FLOAT          = 0.00
         , @n_TotalWeight              FLOAT          = 0.00
         , @n_TotalCube                FLOAT          = 0.00

         , @c_BUILDMBOLKey             NVARCHAR(10)   = ''
         , @c_MBOLkey                  NVARCHAR(10)   = ''  
         , @c_Loadkey                  NVARCHAR(10)   = ''
         , @c_Orderkey                 NVARCHAR(10)   = '' 
         , @c_ExternOrderkey           NVARCHAR(50)   = ''	--JSM-96335
         , @c_Route                    NVARCHAR(10)   = ''
         , @d_OrderDate                DATETIME       = NULL
         , @d_DeliveryDate             DATETIME       = NULL
         
   DECLARE @CUR_BUILD_SORT             CURSOR
         , @CUR_BUILDMBOL              CURSOR

   SET @b_Success = 1
   SET @n_Err     = 0
 
    -- SWT02 - (Wan01) - Move up
   IF SUSER_SNAME() <> @c_UserName
   BEGIN              
      SET @n_Err = 0 
      EXEC [WM].[lsp_SetUser] 
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
              
      --(Wan01)           
      IF @n_Err <> 0       
      BEGIN                
         GOTO EXIT_SP
      END
      
      EXECUTE AS LOGIN = @c_UserName      
   END

   IF @n_Err <> 0 
   BEGIN
      GOTO EXIT_SP
   END 
   
   BEGIN TRY -- SWT01 - Begin Outer Begin Try
   
   CREATE TABLE #tWaveOrder                                                                                                                                    
   (                                           
      RNum              INT NOT NULL PRIMARY KEY                                                                  
   ,  OrderKey          NVARCHAR(10)   NULL DEFAULT ('') 
   ,  Loadkey           NVARCHAR(10)   NULL DEFAULT ('')                                                                                                                               
   ,  ExternOrderKey    NVARCHAR(50)   NULL DEFAULT ('')	--JSM-96335                                                                                                                       
   ,  [Route]           NVARCHAR(10)   NULL DEFAULT ('')
   ,  OrderDate         DATETIME       NULL                                                                                                                         
   ,  DeliveryDate      DATETIME       NULL                                                                                                                                  
   ,  [Weight]          FLOAT          NULL DEFAULT (0.00)                                                                                                                       
   ,  [Cube]            FLOAT          NULL DEFAULT (0.00)                                                                                                                           
   ,  AddWho            NVARCHAR(128)  NULL DEFAULT ('')                                                                                                                       
   )                                                                                                              
                                                                                                                                                            
   IF @b_debug = 2                                                                                                                                              
   BEGIN                                                                                                                                                       
      SET @d_StartTime_Debug = GETDATE()                                               
      PRINT 'SP-lsp_Wave_BuildMBOL DEBUG-START...'                                                                                                             
      PRINT '--1.Do Generate SQL Statement--'                                                                                                                  
   END                                                                                                                                                         
  
   SET @n_err = 0                                                                                                                                              
   SET @c_ErrMsg = ''                                                                                                                                         
   SET @b_Success = 1   
   
   SET @n_Cnt = 0
   SELECT TOP 1 @n_Cnt = 1
         ,@c_BuildKeyFacility = BPCFG.Facility
         ,@c_BuildKeyStorerkey= BPCFG.Storerkey
         ,@c_BuildParmKey     = BP.BuildParmKey
   FROM BUILDPARM BP WITH (NOLOCK)   
   JOIN BUILDPARMGROUPCFG BPCFG WITH (NOLOCK) ON BP.ParmGroup = BPCFG.ParmGroup
                                             AND BPCFG.[Type] = 'WaveBuildMBOL'
   WHERE BPCFG.Facility = @c_Facility
   AND   BPCFG.Storerkey= @c_Storerkey
   ORDER BY BP.BuildParmKey

   IF @n_Cnt = 0
   BEGIN
      GOTO DEFAULT_BUILD_BY_CONSIGNEE
   END

   IF @n_Cnt = 1 AND @c_BuildKeyStorerkey <> @c_Storerkey AND
      (@c_BuildKeyFacility <> '' AND (@c_BuildKeyFacility <> @c_Facility))
   BEGIN
      SET @n_Continue = 3                                                                                                                                     
      SET @n_Err     = 556051                                                                                                                                               
      SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                     + ': Invalid Wave MBOL Group. Its Storer/Facility unmatch with Wave''s storer/Facility.' 
                     + ' (lsp_Wave_BuildMBOL)'                                                                                            
      GOTO EXIT_SP           
   END

   ------------------------------------------------------
   -- Get Build MBOL Restriction: 
   ------------------------------------------------------

   SET @c_Operator  = ''
   SET @n_MaxMBOLOrders = 0
   SET @n_MaxOpenQty= 0

   SELECT @c_Restriction01          = BP.Restriction01
         ,@c_Restriction02          = BP.Restriction02
         ,@c_Restriction03          = BP.Restriction03
         ,@c_Restriction04          = BP.Restriction04
         ,@c_Restriction05          = BP.Restriction05
         ,@c_RestrictionValue01     = BP.RestrictionValue01
         ,@c_RestrictionValue02     = BP.RestrictionValue02
         ,@c_RestrictionValue03     = BP.RestrictionValue03
         ,@c_RestrictionValue04     = BP.RestrictionValue04
         ,@c_RestrictionValue05     = BP.RestrictionValue05
   FROM BUILDPARM BP WITH (NOLOCK)                                                                                                                                 
   WHERE BP.BuildParmKey = @c_BuildParmKey 
   
   SET @n_idx = 1
   WHILE @n_idx <= 5
   BEGIN
      SET @c_Restriction = CASE WHEN @n_idx = 1 THEN @c_Restriction01
                                WHEN @n_idx = 2 THEN @c_Restriction02
                                WHEN @n_idx = 3 THEN @c_Restriction03
                                WHEN @n_idx = 4 THEN @c_Restriction04
                                WHEN @n_idx = 5 THEN @c_Restriction05
                                END
      SET @c_RestrictionValue = CASE WHEN @n_idx = 1 THEN @c_RestrictionValue01
                                     WHEN @n_idx = 2 THEN @c_RestrictionValue02
                                     WHEN @n_idx = 3 THEN @c_RestrictionValue03
                                     WHEN @n_idx = 4 THEN @c_RestrictionValue04
                                     WHEN @n_idx = 5 THEN @c_RestrictionValue05
                                     END

      IF @c_Restriction = '1_MaxOrderPerBuild'
      BEGIN
         SET @n_MaxMBOLOrders = @c_RestrictionValue  
      END

      IF @c_Restriction = '2_MaxQtyPerBuild'
      BEGIN
         SET @n_MaxOpenQty = @c_RestrictionValue  
      END

      IF @c_Restriction = '3_MaxBuild'
      BEGIN
         SET @n_MaxMBOL = @c_RestrictionValue  
      END
 
      SET @n_idx = @n_idx + 1
   END

   --------------------------------------------------
   -- Get Build MBOL By Sorting & Grouping Condition
   --------------------------------------------------
   SET @n_BuildGroupCnt = 0                                                                                                                                                   
   SET @c_GroupBySortField = ''
   SET @c_SQLBuildByGroupWhere = ''
   SET @CUR_BUILD_SORT = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                                                                         
   SELECT TOP 10 
         BPD.FieldName
      ,  BPD.Operator
      ,  BPD.[Type]                                                                                                           
   FROM  BUILDPARMDETAIL BPD WITH (NOLOCK)                                                                                                                               
   WHERE BPD.BuildParmKey = @c_BuildParmKey                                                                                                                                
   AND   BPD.[Type]  IN ('SORT','GROUP')                                                                                                                             
   ORDER BY BPD.BuildParmLineNo                                                                                                                                              
                                                                                                                                                            
   OPEN @CUR_BUILD_SORT                                                                                                                                    
                                                                                                                                                            
   FETCH NEXT FROM @CUR_BUILD_SORT INTO @c_FieldName
                                       ,@c_Operator
                                       ,@c_ParmBuildType                                                                               
   WHILE @@FETCH_STATUS <> -1                             
   BEGIN                                                                                                                                                       
      -- Get Column Type                                                                                                                                       
      SET @c_TableName = LEFT(@c_FieldName, CHARINDEX('.', @c_FieldName) - 1)                                                                                   
      SET @c_ColName   = SUBSTRING(@c_FieldName,                                                                                                                
                         CHARINDEX('.', @c_FieldName) + 1, LEN(@c_FieldName) - CHARINDEX('.', @c_FieldName))                                                            
                       
      IF @c_TableName NOT IN ('ORDERS')
      BEGIN
         SET @n_Continue = 3                                                                                                                                     
         SET @n_Err     = 556052                                                                                                                                               
         SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                        + ': Only allow Sort/Group for ORDERS table. (lsp_Wave_BuildMBOL)'                                                                                            
         GOTO EXIT_SP              
      END
                                                                                                                                                                  
      SET @c_ColType = ''                                                                                                                                       
      SELECT @c_ColType = DATA_TYPE                                                                                                                             
      FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)                                                                                                                       
      WHERE  TABLE_NAME = @c_TableName                                                                                                                          
      AND    COLUMN_NAME = @c_ColName                                                                                                                            
                                                                                                                                                            
      IF ISNULL(RTRIM(@c_ColType), '') = ''                                                                                                                     
      BEGIN                                                          
         SET @n_Continue = 3                                                                                                                                     
         SET @n_Err     = 556053                                                                                                                                               
         SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                        + ': Invalid Sort/Group Column Name: ' + @c_FieldName  
                        + '. (lsp_Wave_BuildMBOL)'
                        + '|' + @c_FieldName                                                                                        
         GOTO EXIT_SP                                                                                                                                             
      END                                                                                                                                                      
                                                                                                                                                            
      IF @c_ParmBuildType = 'SORT'                                                                                                                                   
      BEGIN                                                                                                                                                    
         IF @c_Operator = 'DESC'                                                                                                                                
            SET @c_SortSeq = 'DESC'                                                                                                                             
         ELSE                                                                                                                                                  
            SET @c_SortSeq = ''                                                                                                                                 

            IF ISNULL(@c_GroupBySortField,'') = ''                                                                                                 
               SET @c_GroupBySortField = CHAR(13) + @c_FieldName                                                                                                          
            ELSE                                                                                                                                               
               SET @c_GroupBySortField = @c_GroupBySortField + CHAR(13) + ', ' +  RTRIM(@c_FieldName)                                                                    
                                                                                                                                                            
         IF ISNULL(@c_SortBy,'') = ''                                                                                                                           
            SET @c_SortBy = CHAR(13) + @c_FieldName + ' ' + RTRIM(@c_SortSeq)                                                                                               
         ELSE                                                                                                                                                  
            SET @c_SortBy = @c_SortBy + CHAR(13) + ', ' +  RTRIM(@c_FieldName) + ' ' + RTRIM(@c_SortSeq)                                                                     
      END        
                                                                                                                                                            
      IF @c_ParmBuildType = 'GROUP'                                                                                                                                  
      BEGIN 
         SET @n_BuildGroupCnt = @n_BuildGroupCnt + 1                      --Fixed counter increase for 'GROUP' only   
         IF ISNULL(RTRIM(@c_TableName), '') NOT IN('ORDERS')                                                                                                         
         BEGIN                                                                                                                                                 
            SET @n_Continue = 3 
            SET @n_Err    = 556054                                                                                                                                                
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                          + ': Grouping Only Allow Refer To Orders Table''s Fields. Invalid Table: '+ RTRIM(@c_FieldName)
                          + '. (lsp_Wave_BuildMBOL)'
                          + '|' + @c_FieldName                                                                      
            GOTO EXIT_SP                                                                                                                                          
         END                                                                                                                                                   
                                                                                                                                                            
         IF @c_ColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')                                                   
         BEGIN                                                                                                                                                 
            SET @n_Continue = 3 
            SET @n_Err     = 556055                                                                   
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                          + ': Numeric/Text Column Type Is Not Allowed For Ship Ref. Unit Grouping: ' + RTRIM(@c_FieldName)
                          + '. (lsp_Wave_BuildMBOL)'
                          + '|' + @c_FieldName                                                                        
            GOTO EXIT_SP                                                                                                                                          
         END                                                                                                                                                   
                                                                                                                                
         IF @c_ColType IN ('char', 'nvarchar', 'varchar', 'nchar') -- SWT02                                                                                                      
         BEGIN                                                                                                                                                 
            SET @c_SQLField = @c_SQLField + CHAR(13) + ',' + RTRIM(@c_FieldName)                                                                                       
            SET @c_SQLBuildByGroupWhere = @c_SQLBuildByGroupWhere 
                                 + CHAR(13) + ' AND ' + RTRIM(@c_FieldName) + '='                                                                            
                                 + CASE WHEN @n_BuildGroupCnt = 1  THEN '@c_Field01'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 2  THEN '@c_Field02'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 3  THEN '@c_Field03'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 4  THEN '@c_Field04'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 5  THEN '@c_Field05'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 6  THEN '@c_Field06'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 7  THEN '@c_Field07'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 8  THEN '@c_Field08'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 9  THEN '@c_Field09'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 10 THEN '@c_Field10' END                                                                                                 
            SET @b_GroupFlag = 1                                                                                                                            
         END                                                                                                                                                   
                                                                                                                                                            
         IF @c_ColType IN ('datetime')                                                                                                                          
         BEGIN                                                                                                                                                 
            SET @c_SQLField = @c_SQLField + CHAR(13) +  ', CONVERT(NVARCHAR(10),' + RTRIM(@c_FieldName) + ',112)'                                                       
            SET @c_SQLBuildByGroupWhere = @c_SQLBuildByGroupWhere 
                                 + CHAR(13) + ' AND CONVERT(NVARCHAR(10),' + RTRIM(@c_FieldName) + ',112)='                      
                                 + CASE WHEN @n_BuildGroupCnt = 1  THEN '@c_Field01'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 2  THEN '@c_Field02'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 3  THEN '@c_Field03'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 4  THEN '@c_Field04'                                                                   
                                        WHEN @n_BuildGroupCnt = 5  THEN '@c_Field05'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 6  THEN '@c_Field06'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 7  THEN '@c_Field07'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 8  THEN '@c_Field08'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 9  THEN '@c_Field09'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 10 THEN '@c_Field10' END                                                                                                 
            SET @b_GroupFlag = 1                                                                                                                            
         END                                                                                                                                                   
      END 
                                                               
      FETCH NEXT FROM @CUR_BUILD_SORT INTO @c_FieldName
                                          ,@c_Operator
                                          ,@c_ParmBuildType                                                                              
   END                                                                                                                                                         
   CLOSE @CUR_BUILD_SORT                                                                                                                                   
   DEALLOCATE @CUR_BUILD_SORT  

   DEFAULT_BUILD_BY_CONSIGNEE:
   IF ISNULL(@c_SQLBuildByGroupWhere,'') = '' AND ISNULL(@c_SortBy,'') = ''
   BEGIN   
      SET @n_BuildGroupCnt = 2 
      SET @c_SQLField = ',ORDERS.Consigneekey'
           + CHAR(13) + ',ORDERS.C_Company'                                                                                                                            
      SET @c_SQLBuildByGroupWhere = @c_SQLBuildByGroupWhere
                       + CHAR(13) + 'AND ORDERS.Consigneekey = @c_Field01'
                       + CHAR(13) + 'AND ORDERS.C_Company = @c_Field02'
   END

   IF ISNULL(@c_SortBy,'') = '' 
   BEGIN                                                                                                                                
      SET @c_SortBy = 'WAVEDETAIL.WaveDetailKey'
   END
   ------------------------------------------------------
   -- Construct Build MBOL SQL
   ------------------------------------------------------ 
  
   SET @c_SQL = N'INSERT INTO #tWaveOrder(RNum,OrderKey,Loadkey,ExternOrderKey'
      + CHAR(13) + ',[Route],OrderDate,DeliveryDate'
      + CHAR(13) + ',[Weight],[Cube],AddWho)' 
      + CHAR(13) + ' SELECT ROW_NUMBER() OVER (ORDER BY ' + RTRIM(@c_SortBy) + ') AS Number'
      + CHAR(13) + ',ORDERS.OrderKey,ORDERS.Loadkey,ORDERS.ExternOrderKey'
      + CHAR(13) + ',ORDERS.[Route],ORDERS.OrderDate,ORDERS.DeliveryDate'
      + CHAR(13) + ',SUM(ORDERDETAIL.OpenQty * SKU.StdGrossWgt), SUM(ORDERDETAIL.OpenQty * SKU.StdCube)'
      + CHAR(13) + ',''*'' + RTRIM(sUser_sName())'

   SET @c_SQLWhere = N'FROM WAVEDETAIL WITH (NOLOCK) '
      + CHAR(13) + 'JOIN ORDERS WITH (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey'  
      + CHAR(13) + 'JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey'  
      + CHAR(13) + 'JOIN SKU WITH (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku'   --(Wan02)                  
      + CHAR(13) + 'WHERE WAVEDETAIL.Wavekey = @c_Wavekey'                          
      + CHAR(13) + 'AND ORDERS.StorerKey = @c_StorerKey'                                                                                            
      + CHAR(13) + 'AND ORDERS.Facility = @c_Facility'                                                                                               
      + CHAR(13) + 'AND ORDERS.Status < ''9''' 
      + CHAR(13) + 'AND ORDERS.SOStatus NOT IN (''CANC'', ''9'')'
      + CHAR(13) + 'AND (ORDERS.MBOLKey IS NULL OR ORDERS.MBOLKey = '''')'  

   SET @c_SQLWhere = @c_SQLWhere 

   SET @c_SQLGroupBy = CHAR(13) + N'GROUP BY'
                     + CHAR(13) +  'WAVEDETAIL.WaveDetailkey'
                     + CHAR(13) + ',ORDERS.OrderKey'
                     + CHAR(13) + ',ORDERS.Loadkey'
                     + CHAR(13) + ',ORDERS.ExternOrderKey'
                     + CHAR(13) + ',ORDERS.[Route]'
                     + CHAR(13) + ',ORDERS.OrderDate'
                     + CHAR(13) + ',ORDERS.DeliveryDate'

   IF @c_GroupBySortField <> ''
   BEGIN
      SET @c_SQLGroupBy= @c_SQLGroupBy+ ', ' + @c_GroupBySortField
   END

   SET @c_SQL = @c_SQL + @c_SQLWhere + @c_SQLBuildByGroupWhere + @c_SQLGroupBy 


   IF @c_SQLBuildByGroupWhere <> ''
   BEGIN
      SET @n_MaxMBOL = 0
          
      SET @c_SQLFieldGroupBy = @c_SQLField

      WHILE @n_BuildGroupCnt < 10
      BEGIN
         SET @c_SQLField = @c_SQLField
                         + CHAR(13) + ','''''

         SET @n_BuildGroupCnt = @n_BuildGroupCnt + 1
      END
      SET @c_SQLBuildByGroup  = N'DECLARE CUR_MBOLGRP CURSOR FAST_FORWARD READ_ONLY FOR '
                              + CHAR(13) + ' SELECT @c_Storerkey'
                              + CHAR(13) + @c_SQLField
                              + CHAR(13) + @c_SQLWhere
                              + CHAR(13) + ' GROUP BY ORDERS.Storerkey ' 
                              + CHAR(13) + @c_SQLFieldGroupBy
                              + CHAR(13) + ' ORDER BY ORDERS.Storerkey ' 
                              + CHAR(13) + @c_SQLFieldGroupBy 
                                                                                                                                                                                                                   
      EXEC SP_EXECUTESQL @c_SQLBuildByGroup 
            , N'@c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5), @c_WaveKey NVARCHAR(10)'  
            , @c_StorerKey                                                                                          
            , @c_Facility 
            , @c_Wavekey                                                                                        
                                                                                                                                                                                                                     
      OPEN CUR_MBOLGRP                                                                                                                                         
      FETCH NEXT FROM CUR_MBOLGRP INTO @c_Storerkey
                                    ,  @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05                                              
                                    ,  @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10 
                                                         
      WHILE @@FETCH_STATUS = 0                                                                                                                                 
      BEGIN 
         GOTO START_BUILDMBOL                                                                                                                                
         RETURN_BUILDMBOL:                                                                                                                                   
                                                                                                                                                            
         FETCH NEXT FROM CUR_MBOLGRP INTO @c_Storerkey
                                       ,  @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05                                              
                                       ,  @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
      END                                                                                                                                                      
      CLOSE CUR_MBOLGRP                                                                                              
      DEALLOCATE CUR_MBOLGRP

      GOTO END_BUILDMBOL                                                                                                                                       
   END

START_BUILDMBOL:                                                                                                                                            
   TRUNCATE TABLE #tWaveOrder                                                                                                                                     
                                                                                                                                 
   IF @b_debug = 2                                                                                                                                              
   BEGIN                                                                                                                                                       
      SET @d_EndTime_Debug = GETDATE()                                                                                                                         
      PRINT '--Finish Generate SQL Statement--(Check Result In [Select View])'                                                                                 
      PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)                                                                        
      PRINT '--2.Do Execute SQL Statement--'                                                                                                                   
      SET @d_StartTime_Debug = GETDATE()
   END                                                                                                                                                         
 
   SET @c_SQLParms= N'@c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60), @c_Field03 NVARCHAR(60), @c_Field04 NVARCHAR(60)'
                  +', @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60)'
                  +', @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60), @c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5), @c_WaveKey NVARCHAR(10)'

   EXEC SP_EXECUTESQL @c_SQL
                     ,@c_SQLParms
                     ,@c_Field01                                                                                                                                      
                     ,@c_Field02                                                                                                                                      
                     ,@c_Field03             
                     ,@c_Field04                                           
                     ,@c_Field05                                                                                                                                      
                     ,@c_Field06                                                                                                                                      
                     ,@c_Field07                                                                                                                                      
                     ,@c_Field08                                                                                                                                      
                     ,@c_Field09                                                                                                                                      
                     ,@c_Field10
                     ,@c_StorerKey 
                     ,@c_Facility
                     , @c_Wavekey    
                         
   IF @b_debug = 2                                                                                                                                              
   BEGIN                                                                                                                                                       
      SET @d_EndTime_Debug = GETDATE()                                                                                                                         
      PRINT '--Finish Execute SQL Statement--(Check Temp DataStore In [Select View])'                                                                          
      PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)                                                                        
      SELECT * FROM #tWaveOrder                                                                                                                                
      PRINT '--3.Do Initial Value Set Up--'                                                                                                                 
      SET @d_StartTime_Debug = GETDATE()                                                                                                                       
   END                                                                                                                                                         
           
   SET @n_MaxOrders =  @n_MaxMBOLOrders                                                                                                                                   
   IF @n_MaxMBOLOrders = 0                                                                                                                                          
   BEGIN                                                                                                                                                       
      SELECT @n_MaxOrders = COUNT(DISTINCT OrderKey)           
      FROM   #tWaveOrder                                                                                                                                       
   END                                                                                                                                                         
                 
   IF @b_debug = 2                                                                                                                                              
   BEGIN                                                                                                                                                       
      SET @d_EndTime_Debug = GETDATE()                                                                                                                         
      PRINT '--Finish Initial Value Setup--'                                                                                                                   
      PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)                                                                        
      PRINT '@n_MaxOrders = ' + CAST(@n_MaxOrders AS NVARCHAR(20)) 
          + ' ,@n_MaxOpenQty = ' +  CAST(@n_MaxOpenQty AS NVARCHAR(20))    
      PRINT '--4.Do Buil Ship Ref. Unit--'                                                                                                                          
      SET @d_StartTime_Debug = GETDATE()                                                                                                                       
   END                                                                                                                                                         
                                                                                                                                                           
   WHILE @@TRANCOUNT > 0                                                                                                                                       
      COMMIT TRAN;                                                                                                                                             

   SET @n_OrderCnt     = 0 
   SET @n_TotalOrderCnt= 0   
   SET @n_TotalOpenQty = 0   
   SET @c_MBOLkey      = '' 
                                                                                                                                                        
   SET @CUR_BUILDMBOL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RNUM, OrderKey, Loadkey, ExternOrderKey, [Route], OrderDate, DeliveryDate, [Weight], [Cube]
   FROM #tWaveOrder 
   ORDER BY RNum

   OPEN @CUR_BUILDMBOL 
   FETCH NEXT FROM @CUR_BUILDMBOL INTO  @n_Num, @c_Orderkey, @c_Loadkey, @c_ExternOrderkey
                                      , @c_Route, @d_OrderDate, @d_DeliveryDate
                                      , @n_Weight, @n_Cube                                                                                                                       
   WHILE @@FETCH_STATUS <> -1 
   BEGIN                                                                                                                                                       
      IF @@TRANCOUNT = 0                                                                                                                                       
         BEGIN TRAN;                                                                                                                                           
                          
      IF @n_OpenQty > @n_MaxOpenQty AND @n_MaxOpenQty > 0
      BEGIN
         IF @n_TotalOpenQty = 0 AND @c_MBOLkey = ''
         BEGIN 
            SET @n_Continue = 3 
            SET @n_Err     = 556056                                                                                                                             
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                           + ': No Order to Generate. (lsp_Wave_BuildMBOL)'                                                                                                                                                 
            GOTO EXIT_SP
         END
         BREAK
      END 

      IF @c_MBOLkey = ''
      BEGIN
         IF @n_MaxMBOL > 0 AND @n_MaxMBOL >= @n_MBOLCnt
         BEGIN
            GOTO END_BUILDMBOL         
         END

         SET @d_StartTime = GETDATE()  
         SET @b_success = 1                                                                                                                                   
         BEGIN TRY
            EXECUTE nspg_GetKey                                                                                                                                      
                  'MBOL'                                                                                                                                           
                  , 10                                                                                                                                                 
                  , @c_MBOLkey  OUTPUT                                                                                                                                 
                  , @b_success  OUTPUT                                                                                                                                   
                  , @n_err      OUTPUT                                                                                                                                       
                  , @c_ErrMsg   OUTPUT                                                                                                                                    
         END TRY
         
         BEGIN CATCH
            SET @n_Err     = 556057                                                                                                                             
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                           + ': Error Executing nspg_GetKey - MBOL. (lsp_Wave_BuildMBOL)' 
         END CATCH
                                                                                                                                                                     
         IF @b_success <> 1 OR @n_Err <> 0                                                                                                                                   
         BEGIN 
            SET @n_Continue = 3  
            GOTO EXIT_SP
         END  
          
         BEGIN TRY
            INSERT INTO MBOL(MBOLkey, Facility )   
            VALUES(@c_MBOLkey, @c_Facility)         
         END TRY                             
                                                                                                                                    
         BEGIN CATCH                                                                                                                                                
            SET @n_Continue = 3  
            SET @c_ErrMsg  = ERROR_MESSAGE()
            SET @n_Err     = 556058  
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                           + ': Insert Into MBOL Failed. (lsp_Wave_BuildMBOL) ' 
                           + '(' + @c_ErrMsg + ')' 

            IF (XACT_STATE()) = -1  
            BEGIN
               ROLLBACK TRAN

               WHILE @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
            END                                                          
            GOTO EXIT_SP     
         END CATCH  
                                                                                                                                                                            
         SET @n_OrderCnt      = 0    
         SET @n_TotalOpenQty  = 0 
         SET @n_TotalWeight   = 0.00
         SET @n_TotalCube     = 0.00
         SET @n_MBOLCnt       = @n_MBOLCnt + 1 
         SET @c_BUILDMBOLKey  = @c_MBOLkey          
      END

      IF @c_MBOLkey = ''
      BEGIN 
         GOTO EXIT_SP
      END

      BEGIN TRAN                                                                                                                                      
      SET @d_EditDate = GETDATE()   
      
      --SET @b_success = 1                                                                                                                                    
      
     BEGIN TRY
         EXEC isp_InsertMBOLDetail 
               @cMBOLKey        = @c_MBOLKey 
            ,  @cFacility       = @c_Facility 
            ,  @cOrderKey       = @c_OrderKey 
            ,  @cLoadKey        = @c_Loadkey 
            ,  @nStdGrossWgt    = @n_Weight
            ,  @nStdCube        = @n_Cube 
            ,  @cExternOrderKey = @c_ExternOrderkey 
            ,  @dOrderDate      = @d_OrderDate 
            ,  @dDelivery_Date  = @d_DeliveryDate 
            ,  @cRoute          = @c_Route 
            ,  @b_Success       = @b_Success OUTPUT
            ,  @n_err           = @n_err     OUTPUT
            ,  @c_errmsg        = @c_errmsg  OUTPUT
      END TRY
      BEGIN CATCH
         SET @n_Err = 556059
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_InsertMBOLDetail. (lsp_Wave_BuildMBOL)'
                       + '(' + @c_ErrMsg + ')'    

         IF (XACT_STATE()) = -1  
         BEGIN
            ROLLBACK TRAN

            WHILE @@TRANCOUNT < @n_StartTCnt
            BEGIN
               BEGIN TRAN
            END
         END  
      END CATCH

      IF @b_Success = 0 OR @n_Err > 0
      BEGIN
         SET @n_Continue = 3
         GOTO EXIT_SP 
      END

      WHILE @@TRANCOUNT > 0
      BEGIN 
         COMMIT TRAN    
      END

      SET @n_TotalWeight  = @n_TotalWeight + @n_Weight
      SET @n_TotalCube    = @n_TotalCube + @n_Cube

      SET @n_OrderCnt     = @n_OrderCnt + 1    
      SET @n_TotalOrderCnt= @n_TotalOrderCnt + 1 
      SET @n_TotalOpenQty = @n_TotalOpenQty + @n_OpenQty

      IF (@n_OrderCnt >= @n_MaxOrders) OR
         (@n_TotalOpenQty >= @n_MaxOpenQty AND @n_MaxOpenQty > 0)
      BEGIN
         SET @c_MBOLkey = ''
      END

      IF @b_debug = 1 
      BEGIN                      
         SELECT @@TRANCOUNT AS [TranCounts]  
         SELECT @c_MBOLkey 'MBOLkey', @n_OpenQty '@n_OpenQty', @n_TotalOpenQty '@n_TotalOpenQty'          
      END

      FETCH NEXT FROM @CUR_BUILDMBOL INTO  @n_Num, @c_Orderkey, @c_Loadkey, @c_ExternOrderkey
                                         , @c_Route, @d_OrderDate, @d_DeliveryDate
                                         , @n_Weight, @n_Cube   
   END -- WHILE(@@FETCH_STATUS <> -1)                                                                                                                                           
   CLOSE @CUR_BUILDMBOL
   DEALLOCATE @CUR_BUILDMBOL
   
   IF @c_SQLBuildByGroup <> '' 
   BEGIN                                                                                                      
      GOTO RETURN_BUILDMBOL                                                                                                                                    
   END

 END_BUILDMBOL:                                                                                                                                              
                  
   IF @b_debug = 2                                                                                                                                              
   BEGIN                                                                                                                                                       
      SET @d_EndTime_Debug = GETDATE()                                                    
      PRINT '--Finish Build Ship Ref. Unit--'                                                                                     
      PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)                                                                        
      PRINT '--5.Insert Trace Log--'                                                                                                                           
      SET @d_StartTime_Debug = GETDATE()                                                                                                                       
   END                                                                                                                                                         

   SET @c_ErrMsg = ''                                                                                                                                         
   SET @n_Continue = 0                                                                                                                                           
   IF @b_debug = 2                                                                                                                                              
   BEGIN    
      SET @d_EndTime_Debug = GETDATE()                                                                                                                         
      PRINT '--Finish Insert Trace Log--'          
      PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)                                                                        
   END   
                                                                                                                                                         
   END TRY  
  
   BEGIN CATCH      
      GOTO EXIT_SP  
   END CATCH -- (SWT01) - End Big Outer Begin try.. end Try Begin Catch.. End Catch   
             --                                                                                                                                                            
EXIT_SP:    
   IF @n_Continue = 3                                                                                                                                            
   BEGIN                                                                                                                                                       
      SET @b_Success = 0                                                                                                                                         
      SET @c_ErrMsg = @c_ErrMsg + ' Load #:' + @c_MBOLkey                                                                                                   
 
      IF @@TRANCOUNT > 0 
      BEGIN
         ROLLBACK TRAN
      END                                                                                                                                    
   END                                                                                                                                                         
   ELSE                                                                                                                                                        
   BEGIN                                                                                                                                                       
      WHILE @@TRANCOUNT > 0                                                                                                                    
      BEGIN                                                                                                                                                    
          COMMIT TRAN                                                                                                                                          
      END 
      SET @b_Success = 1                                                                      
   END     
  
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN                                                                                                                         
      BEGIN TRAN                                                                                                                                               
   END

   REVERT                                                                                                                                                            
   IF @b_debug = 2                                                                                                                                              
   BEGIN                                                                                                                                                       
      PRINT 'SP-lsp_Wave_BuildMBOL DEBUG-STOP...'                                               
      PRINT '@b_Success = ' + CAST(@b_Success AS NVARCHAR(2))                                                                                                    
      PRINT '@c_ErrMsg = ' + @c_ErrMsg                                                                                                                        
   END                                                                                                                                                         
-- End Procedure

GO