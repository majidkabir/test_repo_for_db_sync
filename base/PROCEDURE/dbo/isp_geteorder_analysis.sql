SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetEOrder_Analysis                                  */
/* Creation Date: 09-MAY-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1719 - ECOM Nov 11 - Order Management screen            */
/*        :                                                             */
/* Called By: d_dw_eorder_analysis                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_GetEOrder_Analysis] 
           @c_Storerkey       NVARCHAR(15)
         , @c_Facility        NVARCHAR(5)
         , @c_ReleaseGroup    NVARCHAR(30)
         , @dt_StartDate      DATETIME = NULL
         , @dt_EndDate        DATETIME = NULL
         , @c_DateMode        NVARCHAR(10) 
         , @n_Originalx       INT
         , @n_OriginalWidth   INT  
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT
         , @n_Continue              INT 
         , @b_Success               INT
         , @c_ErrMsg                NVARCHAR(255)

         , @c_BuildParmCode         NVARCHAR(30)    
         , @c_BuildParmDescr        NVARCHAR(60)    
         , @n_TotalOpenQty          INT  
         , @n_TotalOpenOrder        INT                       
         , @n_TotalToRelease        INT  
         , @n_TotalOrder            FLOAT           
         , @n_TotalReleased         INT             
         , @dt_BuildDateTime        DATETIME        
         , @c_BuildBy               NVARCHAR(30)  
            
         , @c_SQL                   NVARCHAR(MAX)
         , @n_TotalOpenOrder_width  INT
         , @n_TotalToRelease_x      INT
         , @n_TotalToRelease_width  INT
         , @n_TotalReleased_x       INT
         , @n_TotalReleased_width   INT
         , @n_TotalWidth            INT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @c_BuildBy  = SUSER_SNAME()


   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   CREATE TABLE #TMP_EORDER_ANALYSIS
      (  RowNo                BIGINT         IDENTITY(1,1)  Primary Key
      ,  Storerkey            NVARCHAR(15)   NOT NULL DEFAULT('')
      ,  Facility             NVARCHAR(5)    NOT NULL DEFAULT('')
      ,  ReleaseGroup         NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  StartDate            DATETIME       NOT NULL DEFAULT(GETDATE()) 
      ,  EndDate              DATETIME       NOT NULL DEFAULT(GETDATE())   
      ,  BuildParmCode        NVARCHAR(30)   NOT NULL DEFAULT('')     
      ,  BuildParmDescr       NVARCHAR(60)   NOT NULL DEFAULT('')      
      ,  TotalOpenQty         INT            NOT NULL DEFAULT(0) 
      ,  TotalOpenOrder       INT            NOT NULL DEFAULT(0) 
      ,  TotalOpenOrder_x     INT            NOT NULL DEFAULT(0)
      ,  TotalOpenOrder_width INT            NOT NULL DEFAULT(0)
      ,  TotalToRelease       INT            NOT NULL DEFAULT(0) 
      ,  TotalToRelease_x     INT            NOT NULL DEFAULT(0)
      ,  TotalToRelease_width INT            NOT NULL DEFAULT(0)
      ,  TotalReleased        INT            NOT NULL DEFAULT(0)
      ,  TotalReleased_x      INT            NOT NULL DEFAULT(0)
      ,  TotalReleased_width  INT            NOT NULL DEFAULT(0)
      ,  TotalOrder           INT            NOT NULL DEFAULT(0)
      ,  BuildDateTime        DATETIME       NOT NULL DEFAULT(GETDATE())  
      ,  BuildBy              NVARCHAR(30)   NOT NULL DEFAULT('')
      )

   CREATE TABLE #TMP_EORDER_BUILDLOAD
      (  RowNo                   BIGINT   NOT NULL IDENTITY(1,1) PRIMARY KEY
      ,  Orderkey NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  Loadkey  NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  OpenQty  INT            NOT NULL DEFAULT(0)
      ,  Status   NVARCHAR(10)   NOT NULL DEFAULT('0')
      )

   DECLARE CUR_RELGRP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT CL.ListName
         ,Description = ISNULL(CL.Description,'')
   FROM CODELIST CL WITH (NOLOCK)
   WHERE CL.ListGroup = @c_ReleaseGroup
   AND   CL.UDF04 = 'ReleaseORD'
   ORDER BY CL.ListName

   OPEN CUR_RELGRP
   
   FETCH NEXT FROM CUR_RELGRP INTO @c_BuildParmCode
                                 , @c_BuildParmDescr
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      TRUNCATE TABLE #TMP_EORDER_BUILDLOAD

      SET @c_SQL = ''
      EXEC isp_Build_Loadplan                                                                                                                  
            @cParmCode     = @c_BuildParmCode                                                                                                                   
         ,  @cFacility     = @c_Facility                                                                                                                  
         ,  @cStorerKey    = @c_StorerKey                                                                                                                    
         ,  @nSuccess      = @b_Success   OUTPUT                                                                                                      
         ,  @cErrorMsg     = @c_ErrMsg    OUTPUT                                                                                                       
         ,  @bDebug        = 3                                                                                                                         
         ,  @cSQLPreview   = @c_SQL       OUTPUT 
         ,  @dt_StartDate  = @dt_StartDate  
         ,  @dt_EndDate    = @dt_EndDate 
         ,  @c_DateMode    = @c_DateMode
             
                                                                                                  
      --EXEC (@c_SQL) Execute to insert into #TMP_EORDER_BUILDLOAD at isp_build_loadplan

      SET @n_TotalOpenQty  = 0
      SET @n_TotalOpenOrder= 0
      SET @n_TotalToRelease= 0  
      SET @n_TotalReleased = 0


      SELECT @n_TotalOpenOrder    = ISNULL(SUM(CASE WHEN Status  < '2' THEN 1 ELSE 0 END),0)
            ,@n_TotalToRelease    = ISNULL(SUM(CASE WHEN Loadkey =  ''  AND Status = '2' THEN 1 ELSE 0 END),0)
            ,@n_TotalReleased     = ISNULL(SUM(CASE WHEN Loadkey <> ''  AND Status>= '2' THEN 1 ELSE 0 END),0)
            ,@n_TotalOrder        = COUNT(1)
            ,@n_TotalOpenQty      = ISNULL(SUM(CASE WHEN Status >= '2' AND Loadkey = '' THEN OpenQty ELSE 0 END),0)
      FROM #TMP_EORDER_BUILDLOAD
 
      SET @n_TotalWidth = @n_OriginalWidth
      IF @n_TotalOrder = 0 
      BEGIN
         SET @n_TotalWidth= 0
      END


      SET @n_TotalOpenOrder_width = CASE WHEN @n_TotalOrder = 0
                                         THEN 0
                                         ELSE ((@n_TotalOrder-@n_TotalToRelease- @n_TotalReleased)/@n_TotalOrder) * @n_TotalWidth
                                         END 

      
      SET @n_TotalToRelease_width = CASE WHEN @n_TotalOrder = 0 
                                         THEN 0 
                                         ELSE (@n_TotalToRelease/@n_TotalOrder) * @n_TotalWidth
                                         END
     

      SET @n_TotalReleased_width  = CASE WHEN @n_TotalReleased_width = @n_TotalWidth
                                         THEN @n_TotalReleased_width
                                         ELSE @n_TotalWidth - @n_TotalOpenOrder_width - @n_TotalToRelease_width
                                         END
      SET @n_TotalToRelease_x     = @n_Originalx + @n_TotalOpenOrder_width 
      SET @n_TotalReleased_x      = @n_TotalToRelease_x + @n_TotalToRelease_width
           
      SET @dt_BuildDateTime = GETDATE()

      INSERT INTO #TMP_EORDER_ANALYSIS
         (  Storerkey  
         ,  Facility   
         ,  ReleaseGroup 
         ,  StartDate  
         ,  EndDate  
         ,  BuildParmCode 
         ,  BuildParmDescr 
         ,  TotalOpenQty 
         ,  TotalOpenOrder 
         ,  TotalOpenOrder_x
         ,  TotalOpenOrder_width                  
         ,  TotalToRelease 
         ,  TotalToRelease_x
         ,  TotalToRelease_width          
         ,  TotalReleased
         ,  TotalReleased_x
         ,  TotalReleased_width
         ,  TotalOrder  
         ,  BuildDateTime  
         ,  BuildBy
         )
      VALUES 
         (  @c_Storerkey  
         ,  @c_Facility   
         ,  @c_ReleaseGroup 
         ,  @dt_StartDate  
         ,  @dt_EndDate 
         ,  @c_BuildParmCode 
         ,  @c_BuildParmDescr 
         ,  @n_TotalOpenQty
         ,  @n_TotalOpenOrder
         ,  @n_Originalx  
         ,  @n_TotalOpenOrder_width
         ,  @n_TotalToRelease  
         ,  @n_TotalToRelease_x
         ,  @n_TotalToRelease_width
         ,  @n_TotalReleased
         ,  @n_TotalReleased_x
         ,  @n_TotalReleased_width
         ,  @n_TotalOrder  
         ,  @dt_BuildDateTime
         ,  @c_BuildBy
         )   
      FETCH NEXT FROM CUR_RELGRP INTO @c_BuildParmCode
                                    , @c_BuildParmDescr                       
   END 
   CLOSE CUR_RELGRP
   DEALLOCATE CUR_RELGRP

   SELECT Storerkey  
         ,Facility   
         ,ReleaseGroup 
         ,StartDate  
         ,EndDate  
         ,StartDateText = CASE WHEN @c_DateMode = '1' THEN 'Start AddDate: '
                               ELSE 'Start Order Date: '
                               END
         ,EndDateText   = CASE WHEN @c_DateMode = '1' THEN 'End AddDate: '
                               ELSE 'End Order Date: '
                               END
         ,BuildParmCode 
         ,BuildParmDescr 
         ,TotalOpenQty 
         ,TotalOpenOrder
         ,TotalOpenOrder_x
         ,TotalOpenOrder_width   
         ,TotalOpenOrder_color =  255           -- RED (255,0,0)                
         ,TotalToRelease 
         ,TotalToRelease_x
         ,TotalToRelease_width
         ,TotalToRelease_color =  16711680      -- BLUE(0,0,255)
         ,TotalReleased
         ,TotalReleased_x
         ,TotalReleased_width
         ,TotalReleased_color  =  32768         -- GREEN(0,128,0) 
         ,TotalOrder
         ,BuildDateTime  
         ,BuildBy  
         ,NoOfOrderToRelease = 0                --@n_TotalToRelease 
         ,DateMode = @c_DateMode 
         ,'    ' rowfocusindicatorcol 
   FROM #TMP_EORDER_ANALYSIS

   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO