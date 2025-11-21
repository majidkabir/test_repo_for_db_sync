SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_OTMPlanModeAllocationCheck                     */  
/* Creation Date: 28-Jan-2015                                           */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 330996-OTM Plan Mode Allocation Checking                    */  
/*                                                                      */  
/* Called By: nsp_OrderProcessing_Wrapper                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Rev   Purposes                                  */  
/* 28-AUG-2015 YTWan    1.1   SOS#349412 Mercury - WMS LoadPlan OTM     */
/*                            Enhancement. (Wan01)                      */
/************************************************************************/  
CREATE PROC [dbo].[isp_OTMPlanModeAllocationCheck]    
     @c_OrderKey         NVARCHAR(10)  
   , @c_LoadKey          NVARCHAR(10) 
   , @c_Wavekey          NVARCHAR(10) = ''    
   , @b_Success     INT           OUTPUT    
   , @n_Err         INT           OUTPUT    
   , @c_ErrMsg      NVARCHAR(250) OUTPUT
   , @c_checkfunc   NVARCHAR(50) = ''     --blank call by allocation, 'ADDLOAD' --(Wan01)    
AS    
BEGIN    
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF   
    
   DECLARE  @n_Continue          INT,    
            @n_StartTCnt         INT, -- Holds the current transaction count    
            @c_Storerkey         NVARCHAR(15),
            @c_Facility          NVARCHAR(5),
            @c_OTMPlanModeConfig NVARCHAR(10),
            @c_ProcessMode       NVARCHAR(10),
            @c_FoundOrderkey     NVARCHAR(10)
                  
   SELECT @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1, @b_Success = 1, @n_Err = 0, @c_ErrMsg = ''  
   
   IF ISNULL(@c_OrderKey, '') <> ''
   BEGIN
   	SET @c_ProcessMode = 'ORDER'
      SELECT TOP 1 @c_StorerKey = StorerKey,
                   @c_Facility = o.Facility
      FROM ORDERS o (NOLOCK)
      WHERE o.OrderKey = @c_OrderKey  
   END 
   ELSE IF ISNULL(@c_LoadKey, '') <> ''
   BEGIN
   	SET @c_ProcessMode = 'LOADPLAN'
      SELECT TOP 1 @c_StorerKey = o.StorerKey,
                   @c_Facility = o.facility
      FROM ORDERS o (NOLOCK) 
      JOIN LoadPlanDetail lpd (NOLOCK) ON lpd.OrderKey = o.OrderKey
      WHERE lpd.LoadKey = @c_Loadkey                  
   END  
   ELSE 
   BEGIN IF ISNULL(@c_WaveKey, '') <> ''
   	SET @c_ProcessMode = 'WAVE'   	
      SELECT TOP 1 @c_StorerKey = o.StorerKey, 
                   @c_Facility = o.facility
      FROM ORDERS o (NOLOCK) 
      JOIN WaveDetail wd (NOLOCK) ON wd.OrderKey = o.OrderKey
      WHERE wd.WaveKey = @c_Wavekey                  
      --ORDER BY o.ExternLoadkey          
   END
   
   EXECUTE nspGetRight @c_Facility,  
          @c_StorerKey,  
          NULL,         -- Sku  
          'OTMPLANMODE',       
          @b_Success           OUTPUT,  
          @c_OTMPlanModeConfig OUTPUT,  
          @n_Err               OUTPUT,  
          @c_ErrMsg            OUTPUT  

   IF @b_Success <> 1  
   BEGIN  
      SELECT @n_continue = 3
      SELECT @c_errmsg = 'isp_OTMPlanModeAllocationCheck :' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
      GOTO EXIT_SP    
   END  
  
   IF (@n_Continue = 1 OR @n_Continue = 2) AND @c_OTMPlanModeConfig = '1' 
   BEGIN      	     	  
   	  IF @c_ProcessMode = 'ORDER'
   	  BEGIN
   	  	 IF EXISTS (SELECT 1 
                    FROM ORDERS o (NOLOCK)
                    JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'OTMPLANMOD' AND o.Type = CL.Code AND CL.UDF01 = 'PlanTS'
                                              AND (o.Storerkey = CL.Storerkey OR ISNULL(CL.Storerkey,'') = '')
                    LEFT JOIN LOADPLAN LP (NOLOCK) ON o.Loadkey = LP.Loadkey
                    WHERE o.OrderKey = @c_OrderKey  
                    AND ISNULL(LP.ExternLoadkey,'') = '')
         BEGIN
            SELECT @n_Continue = 3    
            SELECT @n_Err = 63500    
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Order ' + RTRIM(ISNULL(@c_Orderkey,'')) + ' Pending for OTM Planning. (isp_OTMPlanModeAllocationCheck)'
            GOTO EXIT_SP    
         END
   	  END

   	  IF @c_ProcessMode = 'LOADPLAN'
   	  BEGIN
          SELECT TOP 1 @c_FoundOrderkey = o.Orderkey
          FROM LOADPLAN LP (NOLOCK)
          JOIN LOADPLANDETAIL lpd (NOLOCK) ON LP.Loadkey = lpd.LoadKey
          JOIN ORDERS o (NOLOCK) ON lpd.Orderkey = o.Orderkey
          JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'OTMPLANMOD' AND o.Type = CL.Code AND CL.UDF01 = 'PlanTS'
                                        AND (o.Storerkey = CL.Storerkey OR ISNULL(CL.Storerkey,'') = '')
          WHERE LP.LoadKey = @c_Loadkey                  
          AND ISNULL(LP.ExternLoadkey,'') = ''
          ORDER BY o.Orderkey
          
          IF ISNULL(@c_FoundOrderkey,'') <> ''
          BEGIN
            SELECT @n_Continue = 3    
            SELECT @n_Err = 63501    
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Load Plan ' + RTRIM(ISNULL(@c_Loadkey,'')) + ' Pending for OTM Planning. (isp_OTMPlanModeAllocationCheck)'
            GOTO EXIT_SP    
          END
      END    

   	  IF @c_ProcessMode = 'WAVE'
   	  BEGIN
          SELECT TOP 1 @c_FoundOrderkey = O.Orderkey
          FROM WaveDetail wd (NOLOCK) 
          JOIN ORDERS o (NOLOCK) ON wd.OrderKey = o.OrderKey
          JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'OTMPLANMOD' AND o.Type = CL.Code AND CL.UDF01 = 'PlanTS'
                                        AND (o.Storerkey = CL.Storerkey OR ISNULL(CL.Storerkey,'') = '')
          LEFT JOIN LOADPLAN LP (NOLOCK) ON o.Loadkey = LP.Loadkey                                        
          WHERE wd.WaveKey = @c_Wavekey                  
          AND ISNULL(LP.ExternLoadkey,'') = ''
          ORDER BY o.Orderkey
          
          IF ISNULL(@c_FoundOrderkey,'') <> ''
          BEGIN
            SELECT @n_Continue = 3    
            SELECT @n_Err = 63502    
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Wave Plan ' + RTRIM(ISNULL(@c_Wavekey,'')) + ' Pending for OTM Planning. (isp_OTMPlanModeAllocationCheck)'
            GOTO EXIT_SP    
          END
      END    
   END 


   --(Wan01) - START
   IF (@n_Continue = 1 OR @n_Continue = 2) AND @c_checkfunc = 'ADDLOAD' AND @c_OTMPlanModeConfig = '2' 
   BEGIN
      IF @c_ProcessMode = 'ORDER'
      BEGIN
         IF EXISTS (SELECT 1 
                    FROM ORDERS o (NOLOCK)
                    JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'OTMPLANMOD' AND o.Type = CL.Code AND CL.UDF01 = 'PlanTS'
                                              AND (o.Storerkey = CL.Storerkey OR ISNULL(CL.Storerkey,'') = '')
                    LEFT JOIN LOADPLAN LP (NOLOCK) ON o.Loadkey = LP.Loadkey
                    WHERE o.OrderKey = @c_OrderKey  
                    AND ISNULL(LP.ExternLoadkey,'') = '')
         BEGIN
            SET @n_Continue=3
            SET @c_ErrMsg='This order ' + @c_OrderKey + ' Storer is Plan-To-Ship. LoadPlan should be created by TPEX. Are you sure you want to create LoadPlan?'
            GOTO EXIT_SP    
         END
      END

   END
   --(Wan01) - END

EXIT_SP:
    
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_Success = 0  
      --(Wan01) - START
      IF @c_OTMPlanModeConfig = '2'
      BEGIN
         SET @b_Success = -1
      END
      --(Wan01) - END  
      --IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt    
      --BEGIN    
      --   ROLLBACK TRAN    
      --END    
      --ELSE    
      --BEGIN    
      --   WHILE @@TRANCOUNT > @n_StartTCnt    
      --   BEGIN    
      --     COMMIT TRAN    
      --   END    
      --END    
      --EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_OTMPlanModeAllocationCheck'    
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN  
      SELECT @b_Success = 1    
      --WHILE @@TRANCOUNT > @n_StartTCnt    
      --BEGIN    
      --   COMMIT TRAN    
      --END    
      RETURN    
   END        
END -- Procedure  

GO