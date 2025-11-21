SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_EAutoAlloc_GetSummary                               */
/* Creation Date: 28-MAR-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-4406 - ECOM Auto Allocation Dashboard                  */
/*        :                                                             */
/* Called By: d_dw_eautoalloc_summary_grid                              */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2018-06-08  WAN01    1.1   Fixed for @c_SQLCondition is blank        */
/************************************************************************/
CREATE PROC [dbo].[isp_EAutoAlloc_GetSummary] 
           @c_Storerkey          NVARCHAR(15)
         , @c_Facility           NVARCHAR(5)
         , @c_BuildParmGroup     NVARCHAR(30)
         , @dt_StartDate         DATETIME
         , @dt_EndDate           DATETIME  
         , @c_DateMode           NCHAR(1)         
         , @n_Originalx          INT
         , @n_OriginalWidth      INT  
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 
         , @b_Success            INT
         , @c_ErrMsg             NVARCHAR(255)
                                 
         , @c_BuildParmCode      NVARCHAR(30)    
         , @c_BuildParmDescr     NVARCHAR(60) 
                                 
         , @c_SQLSelect          NVARCHAR(MAX)
         , @c_SQL                NVARCHAR(MAX) 
         , @c_SQLParms           NVARCHAR(MAX)
         , @n_WherePosition      INT
         , @n_GroupByPosition    INT
         , @c_SQLCondition       NVARCHAR(MAX)          
         
         , @n_OrdersOpen         INT
         , @n_OrdersNAL          INT
         , @n_OrdersIP           INT
         , @n_OrdersAL           INT        
         , @n_OrdersALL          INT  
                                 
         , @n_OrdersOpen_x       INT
         , @n_OrdersOpen_width   NUMERIC(15,5)
         , @n_OrdersIP_x         INT
         , @n_OrdersIP_width     NUMERIC(15,5)
         , @n_OrdersAL_x         INT
         , @n_OrdersAL_width     NUMERIC(15,5)
         , @n_Width              NUMERIC(15,5)
         , @n_MinWidth           NUMERIC(15,5)   
         
         , @CUR_BLPARMS             CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_MinWidth = 50.0

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   CREATE TABLE #TMP_EORDER_ALLOCSUM
      (  RowNo             BIGINT         IDENTITY(1,1)  Primary Key
      ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT('')
      ,  Facility          NVARCHAR(5)    NOT NULL DEFAULT('')
      ,  BuildParmGroup    NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  StartDate         DATETIME       NOT NULL DEFAULT(GETDATE()) 
      ,  EndDate           DATETIME       NOT NULL DEFAULT(GETDATE())   
      ,  DateMode          CHAR(1)        NOT NULL DEFAULT('')
      ,  BuildParmCode     NVARCHAR(30)   NOT NULL DEFAULT('')     
      ,  BuildParmDescr    NVARCHAR(60)   NOT NULL DEFAULT('')      
      ,  OrdersOpen        INT            NOT NULL DEFAULT(0) 
      ,  OrdersOpen_x      INT            NOT NULL DEFAULT(0)
      ,  OrdersOpen_width  INT            NOT NULL DEFAULT(0)
      ,  OrdersIP          INT            NOT NULL DEFAULT(0) 
      ,  OrdersIP_x        INT            NOT NULL DEFAULT(0)
      ,  OrdersIP_width    INT            NOT NULL DEFAULT(0)
      ,  OrdersAL          INT            NOT NULL DEFAULT(0)
      ,  OrdersAL_x        INT            NOT NULL DEFAULT(0)
      ,  OrdersAL_width    INT            NOT NULL DEFAULT(0)
      ,  OrdersALL         INT                NULL DEFAULT(0)
      )
                          
   SET @CUR_BLPARMS = CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT CL.ListName
         ,Description = ISNULL(CL.Description,'')
   FROM CODELIST CL WITH (NOLOCK)
   WHERE CL.ListGroup = @c_BuildParmGroup
   AND   CL.UDF04 = 'BACKENDALLOC'
   ORDER BY CL.ListName

   OPEN @CUR_BLPARMS
   
   FETCH NEXT FROM @CUR_BLPARMS INTO   @c_BuildParmCode
                                  ,    @c_BuildParmDescr
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_SQLSelect = ''
      SET @n_OrdersNAL = 0
      SET @n_OrdersIP  = 0
      SET @n_OrdersAL  = 0

      EXEC dbo.isp_Gen_BuildLoad_Select 
           @cParmCode  = @c_BuildParmCode 
        ,  @cFacility  = @c_Facility 
        ,  @cStorerKey = @c_StorerKey
        ,  @nSuccess   = @b_Success    OUTPUT 
        ,  @cErrorMsg  = @c_ErrMsg     OUTPUT 
        ,  @cSQLSelect = @c_SQLSelect  OUTPUT    
        ,  @cBatchNo   = '' 

      SET @n_WherePosition =  CHARINDEX(' FROM ', @c_SQLSelect, 1)
      SET @n_GroupByPosition = CHARINDEX('GROUP BY',  @c_SQLSelect, 1)
   
      IF @n_GroupByPosition = 0 
         SET @n_GroupByPosition = LEN(@c_SQLSelect) 
   

      SET @c_SQLCondition = SUBSTRING( @c_SQLSelect,
                                       @n_WherePosition, 
                                       @n_GroupByPosition - @n_WherePosition) 
                
      SET @c_SQL = N'SELECT @n_OrdersNAL = ISNULL(SUM(O.OrdersNAL),0)'
                 + ',@n_OrdersIP = ISNULL(SUM(O.OrdersIP),0)'
                 + ',@n_OrdersAL = ISNULL(SUM(O.OrdersAL),0)'
                 + ' FROM '
                 + '(SELECT OrdersNAL= CASE WHEN ORDERS.Status IN (''0'', ''1'') THEN 1 ELSE 0 END'
                 + ', OrdersIP = ( SELECT COUNT(DISTINCT aabd.Orderkey)'
                 +               ' FROM AUTOALLOCBATCHDETAIL aabd WITH (NOLOCK)'
                 +               ' WHERE aabd.Orderkey = ORDERS.Orderkey' 
                 +               ' )'
                 + ', OrdersAL = CASE WHEN ORDERS.Status = ''2'' THEN 1 ELSE 0 END'
                 + ' ' + @c_SQLCondition  
                 --(Wan01) - START
                 + CASE WHEN RTRIM(@c_SQLCondition) = '' 
                        THEN ' FROM ORDERS WITH (NOLOCK) WHERE ORDERS.Storerkey = @c_Storerkey AND ORDERS.Facility = @c_Facility'
                        ELSE ''
                        END  
                 --(Wan01) - END       
                 + CASE WHEN @c_DateMode = '1' 
                        THEN ' AND ORDERS.AddDate BETWEEN @dt_StartDate AND @dt_EndDate'   
                        ELSE ' AND ORDERS.OrderDate BETWEEN @dt_StartDate AND @dt_EndDate'
                        END
                 + ' GROUP BY ORDERS.Orderkey, ORDERS.Status) O '

      SET @c_SQLParms = N'@c_Storerkey    NVARCHAR(15) '
                      + ',@c_Facility     NVARCHAR(5) '
                      + ',@dt_StartDate   DATETIME '
                      + ',@dt_EndDate     DATETIME '
                      + ',@n_OrdersNAL    INT   OUTPUT '
                      + ',@n_OrdersIP     INT   OUTPUT '
                      + ',@n_OrdersAL     INT   OUTPUT '

      EXECUTE sp_ExecuteSQL  @c_SQL
                           , @c_SQLParms
                           , @c_Storerkey
                           , @c_Facility
                           , @dt_StartDate    
                           , @dt_EndDate      
                           , @n_OrdersNAL OUTPUT
                           , @n_OrdersIP  OUTPUT
                           , @n_OrdersAL  OUTPUT
             
      SET @n_OrdersOpen   = @n_OrdersNAL - @n_OrdersIP 
      SET @n_OrdersAll    = @n_OrdersOpen +  @n_OrdersIP + @n_OrdersAL

      SET @n_Width = @n_OriginalWidth

      IF @n_OrdersAll = 0 
      BEGIN
         SET @n_Width= 0
      END

      SET @n_OrdersOpen_x = @n_Originalx
      SET @n_OrdersOpen_width= CASE WHEN @n_OrdersAll = 0
                                    THEN 0
                                    ELSE (@n_OrdersOpen/(@n_OrdersAll * 1.00)) * @n_Width
                                    END 

      IF @n_OrdersOpen_width > 0 AND @n_OrdersOpen_width < @n_MinWidth 
      BEGIN
         SET @n_OrdersOpen_width = @n_MinWidth
      END

      SET @n_OrdersOpen_width = @n_OrdersOpen_width - (@n_OrdersOpen_width % @n_MinWidth)
      
      SET @n_OrdersIP_width  = CASE WHEN @n_OrdersAll = 0 
                                    THEN 0 
                                    --WHEN @n_OrdersAL  = 0 
                                    --THEN @n_Width - @n_OrdersOpen_width - 0 
                                    ELSE (@n_OrdersIP/(@n_OrdersAll * 1.00)) * @n_Width
                                    END
      IF @n_OrdersIP_width > 0 AND @n_OrdersIP_width < @n_MinWidth 
      BEGIN
         SET @n_OrdersIP_width = @n_MinWidth

      END
      
      SET @n_OrdersIP_width = @n_OrdersIP_width - (@n_OrdersIP_width % @n_MinWidth)
     
      SET @n_OrdersAL_width = 0
      IF @n_OrdersAL > 0 
      BEGIN
         SET @n_OrdersAL_width = @n_Width - @n_OrdersOpen_width - @n_OrdersIP_width
         IF @n_OrdersAL_width <= 0
         BEGIN
            SET @n_OrdersAL_width = @n_MinWidth
            IF @n_OrdersOpen_width > @n_OrdersIP_width
            BEGIN
               SET @n_OrdersOpen_width = @n_OrdersOpen_width - @n_MinWidth
            END
            ELSE
            BEGIN
               SET @n_OrdersIP_width = @n_OrdersIP_width - @n_MinWidth
            END
         END
      END

                                         
      SET @n_OrdersIP_x     = @n_Originalx + @n_OrdersOpen_width 
      SET @n_OrdersAL_x     = @n_OrdersIP_x + @n_OrdersIP_width
           
      INSERT INTO #TMP_EORDER_ALLOCSUM
         (  Storerkey  
         ,  Facility 
         ,  BuildParmGroup
         ,  StartDate  
         ,  EndDate 
         ,  DateMode              
         ,  BuildParmCode 
         ,  BuildParmDescr 
         ,  OrdersOpen 
         ,  OrdersOpen_x
         ,  OrdersOpen_width                  
         ,  OrdersIP 
         ,  OrdersIP_x
         ,  OrdersIP_width          
         ,  OrdersAL
         ,  OrdersAL_x
         ,  OrdersAL_width
         ,  OrdersALL         
         )
      VALUES 
         (  @c_Storerkey  
         ,  @c_Facility   
         ,  @c_BuildParmGroup    
         ,  @dt_StartDate  
         ,  @dt_EndDate 
         ,  @c_DateMode 
         ,  @c_BuildParmCode 
         ,  @c_BuildParmDescr 
         ,  @n_OrdersOpen 
         ,  @n_OrdersOpen_x
         ,  @n_OrdersOpen_width                  
         ,  @n_OrdersIP 
         ,  @n_OrdersIP_x
         ,  @n_OrdersIP_width          
         ,  @n_OrdersAL
         ,  @n_OrdersAL_x
         ,  @n_OrdersAL_width
         ,  @n_OrdersALL
         )   
      FETCH NEXT FROM @CUR_BLPARMS INTO   @c_BuildParmCode
                                     ,    @c_BuildParmDescr                     
   END 
   CLOSE @CUR_BLPARMS
   DEALLOCATE @CUR_BLPARMS

   SELECT   Storerkey  
         ,  Facility 
         ,  BuildParmGroup
         ,  StartDate  
         ,  EndDate    
         ,  DateMode                    
         ,  BuildParmCode 
         ,  BuildParmDescr 
         ,  OrdersOpen 
         ,  OrdersOpen_x
         ,  OrdersOpen_width  
         ,  OrdersOpen_color=  255      -- RED (255,0,0)              
         ,  OrdersIP 
         ,  OrdersIP_x
         ,  OrdersIP_width 
         ,  OrdersIP_color  =  16711680 -- BLUE(0,0,255)                              
         ,  OrdersAL
         ,  OrdersAL_x
         ,  OrdersAL_width 
         ,  OrdersAL_color  =  32768    -- GREEN(0,128,0)            
         ,  selectrow = ''                  
         ,  selectrowctrl = ''              
         ,  rowfocusindicatorcol = '    '   
   FROM #TMP_EORDER_ALLOCSUM

   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO