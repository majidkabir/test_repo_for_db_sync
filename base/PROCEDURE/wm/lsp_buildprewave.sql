SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_BuildPreWave                                    */                                                                                  
/* Creation Date:                                                       */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-3672 - [CN] LOREAL_New Tab for order analysis          */                                                                                  
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.2                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2022-08-02  Wan      1.0   Created & DevOps Combine Script           */
/* 2022-09-22  Wan01    1.1   LFWM-3748 - [CN] LOREAL_Prewave add filter*/
/*                            condition                                 */
/* 2022-11-04  Wan02    1.2   Correct Default @c_Action = 'PREWAVE'     */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_BuildPreWave]                                                                                                                       
      @c_BuildParmKey      NVARCHAR(10) 
   ,  @c_Facility          NVARCHAR(5)                                                                                                                     
   ,  @c_StorerKey         NVARCHAR(15)                                                                                                                     
   ,  @c_Action            NVARCHAR(10)   = 'PREWAVE' -- 'Get', 'PreWave'        --(Wan02)  
   ,  @c_SortPreference    NVARCHAR(500)= ''          -- Sort column + Sort type (ASC/DESC), If multiple Columns Sorting, seperate by ','
   ,  @b_Success           INT            = 1  OUTPUT  
   ,  @n_err               INT            = 0  OUTPUT                                                                                                             
   ,  @c_ErrMsg            NVARCHAR(255)  = '' OUTPUT 
   ,  @c_UserName          NVARCHAR(128)  = ''              
   ,  @b_debug             INT            = 0
   ,  @c_SearchCondition   NVARCHAR(2000) = ''        -- eg: NoOfOrders >= 10 AND Column01 = 'XX'                                                                                                                              
AS 
BEGIN
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF                                                                                                                          
   
   DECLARE @n_Continue                 INT            = 1
         , @n_StartTCnt                INT            = @@TRANCOUNT  
                                                                                                                              
   DECLARE @d_StartBatchTime           DATETIME       = GETDATE() 
         , @d_StartTime                DATETIME       = GETDATE()                                                                                                                  
         , @d_EndTime                  DATETIME                                                                                                                        
         , @d_StartTime_Debug          DATETIME       = GETDATE()                                                                                                                     
         , @d_EndTime_Debug            DATETIME                                                                                                                        
         , @d_EditDate                 DATETIME                                                                                                                        
                          
         , @n_cnt                      INT            = 0 
         , @n_BuildGroupCnt            INT            = 0    
                                                                                                                                                                                                 
         , @n_MaxOpenQty               INT            = 0
         
         , @c_ParmBuildType            NVARCHAR(10)   = ''
         , @c_FieldName                NVARCHAR(100)  = '' 
         , @c_FieldLabel               NVARCHAR(50)   = ''                                                                                                   
         , @c_OrAnd                    NVARCHAR(10)   = ''                                                                                                                 
         , @c_Operator                 NVARCHAR(60)   = ''
         , @c_Value                    NVARCHAR(4000) = ''   
             
         , @c_TableName                NVARCHAR(30)   = ''                                                                                                                
         , @c_ColName                  NVARCHAR(100)  = ''                                                                                                                 
         , @c_ColType                  NVARCHAR(128)  = ''
                                                                                                                    
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
         , @c_FieldLabel01             NVARCHAR(50)   = ''                                                                                                                  
         , @c_FieldLabel02             NVARCHAR(50)   = ''                                                                                                                  
         , @c_FieldLabel03             NVARCHAR(50)   = ''                                                                                                                  
         , @c_FieldLabel04             NVARCHAR(50)   = ''                                                                                                                  
         , @c_FieldLabel05             NVARCHAR(50)   = ''                                                                                                                  
         , @c_FieldLabel06             NVARCHAR(50)   = ''                                                                                                                  
         , @c_FieldLabel07             NVARCHAR(50)   = ''                                                                                                                  
         , @c_FieldLabel08             NVARCHAR(50)   = ''                                                                                                                  
         , @c_FieldLabel09             NVARCHAR(50)   = '' 
         , @c_FieldLabel10             NVARCHAR(50)   = '' 
               
         , @c_SQLField                 NVARCHAR(2000) = ''
         , @c_SQLFieldLabel            NVARCHAR(2000) = ''
         , @c_SQLFieldGroupBy          NVARCHAR(2000) = ''    
         , @c_SQLBuildByGroup          NVARCHAR(4000) = ''
         , @c_SQLBuildByGroupWhere     NVARCHAR(4000) = ''
         , @c_SQLBuildWaveWhere        NVARCHAR(MAX)  = ''     
                                                                                                              
         , @c_SQL                      NVARCHAR(MAX)  = ''
         , @c_SQLParms                 NVARCHAR(2000) = ''
         
   DECLARE @CUR_BUILD_GROUP             CURSOR
   
   SET @b_Success = 1
   SET @n_Err     = 0
               
   IF SUSER_SNAME() <> @c_UserName    
   BEGIN
      EXEC [WM].[lsp_SetUser] 
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
          
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END   
                    
      IF SUSER_SNAME() <> @c_UserName
      BEGIN
         EXECUTE AS LOGIN = @c_UserName      
      END
   END                                 
                                                                 
   BEGIN TRY 
      IF @c_Action = 'GET'
      BEGIN
         ;WITH fl AS 
         (  SELECT RowID = ROW_NUMBER() OVER (ORDER BY b.BuildParmPreWaveLineNo)
                  ,b.FieldLabel   
            FROM  dbo.BUILDPARMPREWAVE AS b WITH (NOLOCK)                                                                                                                               
            WHERE b.BuildParmKey = @c_BuildParmKey                                                                                                                                
            AND   b.[Type] IN ('GROUP')                                                                                                                             
         )
         SELECT @c_SQL = STRING_AGG ('SET @c_FieldLabel0' + CONVERT(CHAR(1),fl.RowID) + '=''' + fl.FieldLabel + '''', ' ') 
         WITHIN GROUP (ORDER BY fl.RowID ASC)
         FROM fl
    
         SET @c_SQLParms = N'@c_FieldLabel01 NVARCHAR(50) OUTPUT'
                         +', @c_FieldLabel02 NVARCHAR(50) OUTPUT'
                         +', @c_FieldLabel03 NVARCHAR(50) OUTPUT'
                         +', @c_FieldLabel04 NVARCHAR(50) OUTPUT'
                         +', @c_FieldLabel05 NVARCHAR(50) OUTPUT'                         
                                                                           
         EXEC sp_ExecuteSQL @c_SQL
                           ,@c_SQLParms
                           ,@c_FieldLabel01  OUTPUT
                           ,@c_FieldLabel02  OUTPUT                           
                           ,@c_FieldLabel03  OUTPUT
                           ,@c_FieldLabel04  OUTPUT 
                           ,@c_FieldLabel05  OUTPUT  
         GOTO EXIT_SP
      END
   
      IF OBJECT_ID('tempdb..#TMP_ORDERS','u') IS NOT NULL  
      BEGIN 
         DROP TABLE #TMP_ORDERS   
      END   
                                                                                                                                        
      CREATE TABLE #TMP_ORDERS                                                                                                                                    
      (                                                                                                                                                           
         OrderKey       NVARCHAR(10)   NULL  
      )   

      IF OBJECT_ID('tempdb..#TMP_SKUTOTQTY','u') IS NOT NULL  
      BEGIN 
         DROP TABLE #TMP_SKUTOTQTY   
      END 
                                                                                                                                           
      CREATE TABLE #TMP_SKUTOTQTY                                                                                                                                    
      (                                                                                                                                                           
         RowID          INT            NOT NULL DEFAULT(0)                 
      ,  Storerkey      NVARCHAR(15)   NOT NULL DEFAULT('')            
      ,  Sku            NVARCHAR(20)   NOT NULL DEFAULT('')            
      ,  Qty            INT            NOT NULL DEFAULT(0)             
      )   

      EXEC [WM].[lsp_Build_Wave]                                                                                                                       
         @c_BuildParmKey      = @c_BuildParmKey                                                                                                                  
      ,  @c_Facility          = @c_Facility                                                                                                                      
      ,  @c_StorerKey         = @c_StorerKey     
      ,  @c_BuildWaveType     = @c_Action    --DEFAULT BLANK = BuildWave, Analysis, PreWave & etc
      ,  @c_GenByBuildValue   = 'Y'          --DEFAULT Y = Use BuildValue, Otherwise use Value
      ,  @c_SQLBuildWave      = @c_SQLBuildWaveWhere  OUTPUT                                  
      ,  @b_Success           = @b_Success OUTPUT  
      ,  @n_err               = @n_err     OUTPUT                                                                                                             
      ,  @c_ErrMsg            = @c_ErrMsg  OUTPUT 
      ,  @c_UserName          = @c_UserName             
      ,  @b_debug             = @b_debug   

      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         GOTO EXIT_SP
      END

      DELETE FROM dbo.BUILDPREWAVE WHERE BuildParmKey = @c_BuildParmKey
      
      IF @@ERROR <> 0                                                                                                                     
      BEGIN                                                          
         SET @n_Continue = 3                                                                                                                                     
         SET @n_Err     = 560851                                                                                                                                               
         SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                        + ': Delete BUILDPREWAVE fail. (lsp_BuildPreWave)'                                                                                                           
         GOTO EXIT_SP                                                                                                                                             
      END
                                                                                                                                                            
      IF @b_debug = 2                                                                                                                                              
      BEGIN                                                                                                                                                       
         SET @d_StartTime_Debug = GETDATE()                                               
         PRINT 'SP-lsp_BuildPreWave DEBUG-START...'                                                                                                             
         PRINT '--1.Do Generate SQL Statement--'                                                                                                                  
      END                                                                                                                                                         
  
      ------------------------------------------------------
      -- Get Build Wave Restriction - Max Open Qty: 
      ------------------------------------------------------

      SET @n_MaxOpenQty= 0

      SELECT TOP 1
              @n_MaxOpenQty = CASE WHEN BP.Restriction01 = '2_MaxQtyPerBuild' THEN BP.RestrictionBuildValue01
                                   WHEN BP.Restriction02 = '2_MaxQtyPerBuild' THEN BP.RestrictionBuildValue02
                                   WHEN BP.Restriction03 = '2_MaxQtyPerBuild' THEN BP.RestrictionBuildValue03 
                                   WHEN BP.Restriction04 = '2_MaxQtyPerBuild' THEN BP.RestrictionBuildValue04   
                                   WHEN BP.Restriction05 = '2_MaxQtyPerBuild' THEN BP.RestrictionBuildValue05
                                   ELSE 0
                                   END                                                                   
      FROM BUILDPARM BP WITH (NOLOCK)                                                                                                                                 
      WHERE BP.BuildParmKey = @c_BuildParmKey 
      ORDER BY  CASE WHEN BP.Restriction01 = '2_MaxQtyPerBuild' THEN BP.RestrictionBuildValue01
                     WHEN BP.Restriction02 = '2_MaxQtyPerBuild' THEN BP.RestrictionBuildValue02
                     WHEN BP.Restriction03 = '2_MaxQtyPerBuild' THEN BP.RestrictionBuildValue03 
                     WHEN BP.Restriction04 = '2_MaxQtyPerBuild' THEN BP.RestrictionBuildValue04   
                     WHEN BP.Restriction05 = '2_MaxQtyPerBuild' THEN BP.RestrictionBuildValue05
                     ELSE 0
                     END DESC
   
      
      --------------------------------------------------
      -- Get Pre Wave Grouping Condition
      --------------------------------------------------
      SET @n_BuildGroupCnt = 0                                                                                                                                                   
      SET @c_SQLBuildByGroupWhere = ''
      SET @CUR_BUILD_GROUP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                                                                         
      SELECT TOP 5 
            b.FieldName
         ,  b.FieldLabel   
         ,  b.Operator
         ,  b.[Type]                                                                                                           
      FROM  dbo.BUILDPARMPREWAVE AS b WITH (NOLOCK)                                                                                                                               
      WHERE b.BuildParmKey = @c_BuildParmKey                                                                                                                                
      AND   b.[Type] IN ('GROUP')                                                                                                                             
      ORDER BY b.BuildParmPreWaveLineNo                                                                                                                                              
                                                                                                                                                            
      OPEN @CUR_BUILD_GROUP                                                                                                                                    
                                                                                                                                                            
      FETCH NEXT FROM @CUR_BUILD_GROUP INTO @c_FieldName
                                          , @c_FieldLabel
                                          , @c_Operator
                                          , @c_ParmBuildType                                                                               
      WHILE @@FETCH_STATUS <> -1                             
      BEGIN                                                                                                                                                       
         SET @c_TableName = LEFT(@c_FieldName, CHARINDEX('.', @c_FieldName) - 1)                                                                                   
         SET @c_ColName   = SUBSTRING(@c_FieldName,                                                                                                                
                              CHARINDEX('.', @c_FieldName) + 1, LEN(@c_FieldName) - CHARINDEX('.', @c_FieldName))    
                                                                                                                                                            
         SET @c_ColType = ''                                                                                                                                       
         SELECT @c_ColType = DATA_TYPE                                                                                                                             
         FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)                                                                                                                       
         WHERE  TABLE_NAME = @c_TableName                                                                                                                          
         AND    COLUMN_NAME = @c_ColName                                                                                                                            
                                                                                                                                                            
         IF ISNULL(RTRIM(@c_ColType), '') = ''                                                                                                                     
         BEGIN                                                          
            SET @n_Continue = 3                                                                                                                                     
            SET @n_Err     = 560852                                                                                                                                               
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                           + ': Invalid Group Column Name: ' + @c_FieldName  
                           + ' (lsp_BuildPreWave)' 
                           + '|' + @c_FieldName                                                                                                                  
            GOTO EXIT_SP                                                                                                                                             
         END                                                                                                                                                      
                                                                                                                                                            
         IF @c_ParmBuildType = 'GROUP'                                                                                                                                
         BEGIN 
            SET @n_BuildGroupCnt = @n_BuildGroupCnt + 1                      --Fixed counter increase for 'GROUP' only   
            IF ISNULL(RTRIM(@c_TableName), '') NOT IN('ORDERS')                                                                                                         
            BEGIN                                                                                                                                                 
               SET @n_Continue = 3 
               SET @n_Err    = 560853                                                                                                                                                
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                             + ': Grouping Only Allow Refer To Orders Table''s Fields. Invalid Table: ' + RTRIM(@c_FieldName)                                        
                             + '. (lsp_BuildPreWave)'
                             + '|' + RTRIM(@c_FieldName) 
               GOTO EXIT_SP                                                                                                                                          
            END                                                                                                                                                   
                                                                                                                                                            
            IF @c_ColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')                                                   
            BEGIN                                                                                                                                                 
               SET @n_Continue = 3 
               SET @n_Err    = 560854                                                                                                                                                 
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                             + ': Numeric/Text Column Type Is Not Allowed For PreWave Grouping: ' + RTRIM(@c_FieldName)  
                             + '. (lsp_BuildPreWave)'
                             + '|' + RTRIM(@c_FieldName)                                                                   
               GOTO EXIT_SP                                                                                                                                          
            END                                                                                                                                                   
                                                                                                                                
            IF @c_ColType IN ('char', 'nvarchar', 'varchar', 'nchar', 'datetime')                                                                                                      
            BEGIN 
               IF @c_ColType = 'datetime'  
               BEGIN
                  SET @c_SQLField = @c_SQLField + CHAR(13) +  ', CONVERT(NVARCHAR(10),' + RTRIM(@c_FieldName) + ',112)' 
               END
               ELSE
               BEGIN
                  SET @c_SQLField = @c_SQLField + CHAR(13) + ',' + RTRIM(@c_FieldName) 
               END
                                                                                                                                                                                                                                                   
               SET @c_SQLBuildByGroupWhere = @c_SQLBuildByGroupWhere 
                                    + CHAR(13) + CASE WHEN @c_ColType = 'datetime'
                                                      THEN ' AND CONVERT(NVARCHAR(10),' + RTRIM(@c_FieldName) + ',112)='   
                                                      ELSE ' AND ' + RTRIM(@c_FieldName) + '='  
                                                      END                                                                          
                                    + CASE WHEN @n_BuildGroupCnt = 1  THEN '@c_Field01'                                                                                                      
                                           WHEN @n_BuildGroupCnt = 2  THEN '@c_Field02'                                                                                                      
                                           WHEN @n_BuildGroupCnt = 3  THEN '@c_Field03'                                                                                                      
                                           WHEN @n_BuildGroupCnt = 4  THEN '@c_Field04'                                                                                                      
                                           WHEN @n_BuildGroupCnt = 5  THEN '@c_Field05'                                                                                                      
                                           WHEN @n_BuildGroupCnt = 6  THEN '@c_Field06'                                                                                                      
                                           WHEN @n_BuildGroupCnt = 7  THEN '@c_Field07'                                                                                                      
                                           WHEN @n_BuildGroupCnt = 8  THEN '@c_Field08'                                                                                                      
                                           WHEN @n_BuildGroupCnt = 9  THEN '@c_Field09'                                                                                                      
                                           WHEN @n_BuildGroupCnt = 10 THEN '@c_Field10' 
                                           END 
                                           
               IF @n_BuildGroupCnt = 1  SET @c_FieldLabel01 = @c_FieldLabel
               IF @n_BuildGroupCnt = 2  SET @c_FieldLabel02 = @c_FieldLabel
               IF @n_BuildGroupCnt = 3  SET @c_FieldLabel03 = @c_FieldLabel
               IF @n_BuildGroupCnt = 4  SET @c_FieldLabel04 = @c_FieldLabel
               IF @n_BuildGroupCnt = 5  SET @c_FieldLabel05 = @c_FieldLabel
               IF @n_BuildGroupCnt = 6  SET @c_FieldLabel06 = @c_FieldLabel
               IF @n_BuildGroupCnt = 7  SET @c_FieldLabel07 = @c_FieldLabel
               IF @n_BuildGroupCnt = 8  SET @c_FieldLabel08 = @c_FieldLabel
               IF @n_BuildGroupCnt = 9  SET @c_FieldLabel09 = @c_FieldLabel
               IF @n_BuildGroupCnt = 10 SET @c_FieldLabel10 = @c_FieldLabel               
                                                                                                                                          
            END                                                                                                                                                   
         END 

         NEXT_GROUP:                                                                                
         FETCH NEXT FROM @CUR_BUILD_GROUP INTO @c_FieldName
                                             , @c_FieldLabel
                                             , @c_Operator
                                             , @c_ParmBuildType                                                                              
      END                                                                                                                                                         
      CLOSE @CUR_BUILD_GROUP                                                                                                                                   
      DEALLOCATE @CUR_BUILD_GROUP  

      BUILD_WAVE_SQL:                                                               

      IF @n_BuildGroupCnt > 0
      BEGIN
         SET @c_SQLFieldGroupBy = @c_SQLField

         WHILE @n_BuildGroupCnt < 5
         BEGIN
            SET @c_SQLField = @c_SQLField
                            + CHAR(13) + ','''''

            SET @n_BuildGroupCnt = @n_BuildGroupCnt + 1
         END
         
 
         SET @c_SQLBuildByGroup  = N' SELECT @c_BuildParmKey'
                                 +', COUNT(DISTINCT ORDERS.Orderkey)'
                                 + @c_SQLField
                                 + @c_SQLBuildWaveWhere
                                 + CHAR(13) + ' GROUP BY ORDERS.Storerkey ' + @c_SQLFieldGroupBy                                                                                                      
                                 + CHAR(13) + ' ORDER BY ORDERS.Storerkey ' + @c_SQLFieldGroupBy    
         
         --PRINT @c_SQLBuildByGroup                                                                                                                                                                     
         INSERT INTO dbo.BuildPreWave ( BuildParmKey, NoOfOrders
                                       ,Column01, Column02, Column03, Column04, Column05
                                      )
         EXEC SP_EXECUTESQL @c_SQLBuildByGroup 
               , N'@c_BuildParmKey NVARCHAR(10), @c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5) 
                  ,@n_MaxOpenQty INT'
               , @c_BuildParmKey
               , @c_StorerKey
               , @c_Facility                                                                                          
               , @n_MaxOpenQty 
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
      
      IF @c_SortPreference = ''
      BEGIN
         SET @c_SortPreference = ' ORDER BY BuildPreWave.NoOfOrders DESC'
      END
      ELSE
      BEGIN
         SET @c_SortPreference = ' ORDER BY ' + @c_SortPreference  
      END
      
      --(Wan01) - START
      IF @c_SearchCondition <> ''
      BEGIN
         SET @c_SearchCondition =  ' AND ' + @c_SearchCondition
      END
      
      BEGIN TRY
      SET @c_SQL = N'SELECT BuildPreWave.RowID'  
                 + ', BuildPreWave.BuildParmKey' 
                 + ', BuildPreWave.[Status]'            
                 + ', BuildPreWave.NoOfOrders'           
                 + ', BuildPreWave.Column01'        
                 + ', BuildPreWave.Column02'  
                 + ', BuildPreWave.Column03'
                 + ', BuildPreWave.Column04'
                 + ', BuildPreWave.Column05'
                 + ', ColumnLabel01 = @c_FieldLabel01'        
                 + ', ColumnLabel02 = @c_FieldLabel02'  
                 + ', ColumnLabel03 = @c_FieldLabel03'
                 + ', ColumnLabel04 = @c_FieldLabel04'
                 + ', ColumnLabel05 = @c_FieldLabel05'
                 + ' FROM dbo.BuildPreWave WITH (NOLOCK)' 
                 + ' WHERE BuildPreWave.BuildParmKey = @c_BuildParmKey' 
                 --+ ' AND BuildPreWave.[Status] = ''0''' 
                 + @c_SearchCondition                                --Wan01                           
                 + @c_SortPreference

      SET @c_SQLParms = '@c_BuildParmKey  NVARCHAR(10)'
                      +',@c_FieldLabel01  NVARCHAR(50)'
                      +',@c_FieldLabel02  NVARCHAR(50)'
                      +',@c_FieldLabel03  NVARCHAR(50)'
                      +',@c_FieldLabel04  NVARCHAR(50)'
                      +',@c_FieldLabel05  NVARCHAR(50)'               
           
      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParms
                        ,@c_BuildParmKey
                        ,@c_FieldLabel01
                        ,@c_FieldLabel02
                        ,@c_FieldLabel03
                        ,@c_FieldLabel04
                        ,@c_FieldLabel05
      END TRY
      BEGIN CATCH
         SET @b_Success = 0
         SET @c_ErrMsg  = ERROR_MESSAGE() 
      END CATCH
   END     
   --(Wan01) - END                                                                                                                                                           
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END                                                                                                                                                       
   REVERT 
END

GO