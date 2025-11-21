SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveAnalysis                                    */                                                                                  
/* Creation Date:                                                       */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1790 - SPs for Wave Release Screen -                   */
/*          ( Wave Creation Tab - HomeScreen )                          */                                                                                  
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
/* 2021-02-15  mingle01 1.1   Add Big Outer Begin try/Catch             */ 
/* 2021-09-02  Wan01    1.2   LFWM-3014 - UAT CN Wave Control  Wave     */
/*                            Generate Task                             */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_WaveAnalysis]                                                                                                                     
      @c_Wavekey        NVARCHAR(10)                                                                                                                     
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_Continue          INT = 1

         ,  @n_NOOfOrders        INT = 0
         ,  @n_NoOfOpen          INT = 0
         ,  @n_NoOfPartialAlloc  INT = 0
         ,  @n_NoOfAllocated     INT = 0
         ,  @n_TotalAllocate     INT = 0
         ,  @n_NoOfPicked        INT = 0
         ,  @n_NoOfReplenish     INT = 0
         ,  @n_NoOfTasks         INT = 0
         ,  @n_NoOfTaskInProg    INT = 0
         ,  @n_NoOfTaskCompleted INT = 0

         ,  @c_Facility          NVARCHAR(5)    = ''
         ,  @c_Storerkey         NVARCHAR(15)   = ''
         ,  @c_BuildParmKey      NVARCHAR(10)   = ''
   
   --(mingle01) - START
   BEGIN TRY
      SELECT @c_Facility = BWL.Facility
            ,@c_Storerkey= BWL.Storerkey
            ,@c_BuildParmKey = BWL.BuildParmKey
      FROM   WAVE  WH WITH (NOLOCK)
      JOIN   BUILDWAVELOG BWL WITH (NOLOCK) ON (WH.BatchNo = BWL.BatchNo)                                                                                                                          
      WHERE  WH.Wavekey = @c_Wavekey

      SELECT @n_NOOfOrders      = COUNT(DISTINCT OH.Orderkey)
            ,@n_NoOfOpen        = SUM(CASE WHEN OH.[Status] = '0' THEN 1 ELSE 0 END)
            ,@n_NoOfPartialAlloc= SUM(CASE WHEN OH.[Status] = '1' THEN 1 ELSE 0 END)
            ,@n_NoOfAllocated   = SUM(CASE WHEN OH.[Status] = '2' THEN 1 ELSE 0 END)
            ,@n_TotalAllocate   = SUM(CASE WHEN OH.[Status] <='2' THEN 1 ELSE 0 END)
            ,@n_NoOfPicked      = SUM(CASE WHEN OH.[Status] = '5' THEN 1 ELSE 0 END)
      FROM WAVE WH WITH (NOLOCK)
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON (WH.Wavekey = WD.Wavekey)
      JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey= OH.Orderkey)
      WHERE WH.Wavekey = @c_Wavekey

      SELECT @n_NoOfTasks         = COUNT(1)
            ,@n_NoOfTaskInProg    = SUM(CASE WHEN TD.Status BETWEEN '1' AND '8' THEN 1 ELSE 0 END)       --(Wan01)
            ,@n_NoOfTaskCompleted = SUM(CASE WHEN TD.Status = '9' THEN 1 ELSE 0 END)                     --(Wan01)
      --FROM WAVE WH WITH (NOLOCK)                                               --(Wan01)
      --JOIN WAVEDETAIL WD WITH (NOLOCK) ON (WH.Wavekey = WD.Wavekey)            --(Wan01)
      --JOIN PICKDETAIL PD WITH (NOLOCK) ON (WD.Orderkey= PD.Orderkey)           --(Wan01)
      --JOIN TASKDETAIL TD WITH (NOLOCK) ON (PD.TaskdeailKey = TD.TaskdeailKey)  --(Wan01)
      FROM TASKDETAIL TD WITH (NOLOCK)                                           --(Wan01)   
      WHERE TD.Wavekey = @c_Wavekey                                              --(Wan01)  
   END TRY
   
   BEGIN CATCH
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END 

EXIT_SP:

   SELECT   Facility          = @c_Facility  
         ,  Storerkey         = @c_Storerkey 
         ,  BuildParmKey      = @c_BuildParmKey 
         ,  NOOfOrders        = @n_NOOfOrders        
         ,  NoOfOpen          = @n_NoOfOpen          
         ,  NoOfPartialAlloc  = @n_NoOfPartialAlloc  
         ,  NoOfAllocated     = @n_NoOfAllocated     
         ,  TotalAllocate     = @n_TotalAllocate     
         ,  NoOfPicked        = @n_NoOfPicked        
         ,  NoOfReplenish     = @n_NoOfReplenish     
         ,  NoOfTasks         = @n_NoOfTasks         
         ,  NoOfTaskInProg    = @n_NoOfTaskInProg    
         ,  NoOfTaskCompleted = @n_NoOfTaskCompleted
          
END

GO