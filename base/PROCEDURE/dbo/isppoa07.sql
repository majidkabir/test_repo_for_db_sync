SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPOA07                                           */  
/* Creation Date: 18-Apr-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-8771 CN Fabory convert UOM 2 to UOM 1 if full pallet    */
/*          pick and only 1 loadplan and 1 sku                          */
/*                                                                      */  
/* Called By: StorerConfig.ConfigKey =  PostallocationSP                */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[ispPOA07]    
     @c_OrderKey    NVARCHAR(10) = '' 
   , @c_LoadKey     NVARCHAR(10) = ''
   , @c_Wavekey     NVARCHAR(10) = ''
   , @b_Success     INT           OUTPUT    
   , @n_Err         INT           OUTPUT    
   , @c_ErrMsg      NVARCHAR(250) OUTPUT    
   , @b_debug       INT = 0    
AS    
BEGIN    
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
    
   DECLARE  @n_Continue              INT,    
            @n_StartTCnt             INT, -- Holds the current transaction count
            @c_Pickdetailkey         NVARCHAR(10),
            @c_Storerkey             NVARCHAR(15),
            @c_Loc                   NVARCHAR(10),
            @c_ID                    NVARCHAR(18)
                                                              
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0  
   SELECT @c_ErrMsg=''  
    
   IF @n_Continue=1 OR @n_Continue=2    
   BEGIN    
      IF ISNULL(RTRIM(@c_OrderKey),'') = '' AND ISNULL(RTRIM(@c_LoadKey),'') = '' AND ISNULL(RTRIM(@c_WaveKey),'') = ''
      BEGIN    
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63500    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey & Orderkey & Wavekey are Blank (ispPOA07)'
         GOTO EXIT_SP    
      END    
   END -- @n_Continue =1 or @n_Continue = 2    
   
   IF ISNULL(RTRIM(@c_OrderKey), '') <> ''
   BEGIN
      DECLARE CUR_LOCID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.Storerkey, PD.Loc, PD.ID 
      FROM ORDERS O (NOLOCK)
      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
      OUTER APPLY (SELECT SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS QtyAvailable
                   FROM LOTXLOCXID LLI (NOLOCK) 
                   WHERE LLI.Storerkey = PD.Storerkey
                   AND LLI.Loc = PD.Loc
                   AND LLI.Id = PD.ID) AS LOCQty                   
      oUTER APPLY (SELECT COUNT(DISTINCT PD2.Sku) AS noofsku,
                          COUNT(DISTINCT O2.Loadkey) AS noofload
                   FROM PICKDETAIL PD2 (NOLOCK)  
                   JOIN ORDERS O2 (NOLOCK) ON PD2.Orderkey = O2.Orderkey
                   WHERE PD2.Storerkey = PD.Storerkey
                   AND PD2.LOC = PD.Loc
                   AND PD2.Id = PD.Id
                   AND PD2.Status <> '9') AS LOCState
      WHERE O.OrderKey = @c_OrderKey 
      AND PD.UOM = '2'
      GROUP BY PD.Storerkey, PD.Loc, PD.Id, ISNULL(LOCQty.QtyAvailable,0) ,ISNULL(LOCState.noofsku,0), ISNULL(LOCState.noofload,0) 
      HAVING ISNULL(LOCQty.QtyAvailable,0) = 0 AND ISNULL(LOCState.noofsku,0) = 1 AND ISNULL(LOCState.noofload,0) = 1 
   END
   ELSE IF ISNULL(RTRIM(@c_LoadKey), '') <> ''
   BEGIN
      DECLARE CUR_LOCID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.Storerkey, PD.Loc, PD.ID 
      FROM ORDERS O (NOLOCK)
      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON O.Orderkey = LPD.Orderkey
      OUTER APPLY (SELECT SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS QtyAvailable
                   FROM LOTXLOCXID LLI (NOLOCK) 
                   WHERE LLI.Storerkey = PD.Storerkey
                   AND LLI.Loc = PD.Loc
                   AND LLI.Id = PD.ID) AS LOCQty                   
      oUTER APPLY (SELECT COUNT(DISTINCT PD2.Sku) AS noofsku,
                          COUNT(DISTINCT O2.Loadkey) AS noofload
                   FROM PICKDETAIL PD2 (NOLOCK)  
                   JOIN ORDERS O2 (NOLOCK) ON PD2.Orderkey = O2.Orderkey
                   WHERE PD2.Storerkey = PD.Storerkey
                   AND PD2.LOC = PD.Loc
                   AND PD2.Id = PD.Id
                   AND PD2.Status <> '9') AS LOCState
      WHERE LPD.Loadkey = @c_Loadkey
      AND PD.UOM = '2'
      GROUP BY PD.Storerkey, PD.Loc, PD.Id, ISNULL(LOCQty.QtyAvailable,0) ,ISNULL(LOCState.noofsku,0), ISNULL(LOCState.noofload,0) 
      HAVING ISNULL(LOCQty.QtyAvailable,0) = 0 AND ISNULL(LOCState.noofsku,0) = 1 AND ISNULL(LOCState.noofload,0) = 1 
   END
   ELSE
   BEGIN
      DECLARE CUR_LOCID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.Storerkey, PD.Loc, PD.ID 
      FROM ORDERS O (NOLOCK)
      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
      JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey
      OUTER APPLY (SELECT SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS QtyAvailable
                   FROM LOTXLOCXID LLI (NOLOCK) 
                   WHERE LLI.Storerkey = PD.Storerkey
                   AND LLI.Loc = PD.Loc
                   AND LLI.Id = PD.ID) AS LOCQty                   
      oUTER APPLY (SELECT COUNT(DISTINCT PD2.Sku) AS noofsku,
                          COUNT(DISTINCT O2.Loadkey) AS noofload
                   FROM PICKDETAIL PD2 (NOLOCK)  
                   JOIN ORDERS O2 (NOLOCK) ON PD2.Orderkey = O2.Orderkey
                   WHERE PD2.Storerkey = PD.Storerkey
                   AND PD2.LOC = PD.Loc
                   AND PD2.Id = PD.Id
                   AND PD2.Status <> '9') AS LOCState
      WHERE WD.Wavekey = @c_Wavekey
      AND PD.UOM = '2'
      GROUP BY PD.Storerkey, PD.Loc, PD.Id, ISNULL(LOCQty.QtyAvailable,0) ,ISNULL(LOCState.noofsku,0), ISNULL(LOCState.noofload,0) 
      HAVING ISNULL(LOCQty.QtyAvailable,0) = 0 AND ISNULL(LOCState.noofsku,0) = 1 AND ISNULL(LOCState.noofload,0) = 1 
   END
 
   OPEN CUR_LOCID    

   FETCH NEXT FROM CUR_LOCID INTO @c_Storerkey, @c_Loc, @c_Id
     
   WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
   BEGIN             
      DECLARE CURSOR_PICK CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT PD.Pickdetailkey
         FROM PICKDETAIL PD (NOLOCK) 
         WHERE PD.Storerkey = @c_Storerkey
         AND PD.Loc = @c_Loc 
         AND PD.ID = @c_Id
         AND PD.Status <> '9'          
         
      OPEN CURSOR_PICK         
                       
      FETCH NEXT FROM CURSOR_PICK INTO @c_Pickdetailkey
             
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN             	
         UPDATE PICKDETAIL WITH (ROWLOCK)
         SET UOM = '1' ,
             UOMQty = 1,
             Trafficcop = NULL
         WHERE Pickdetailkey = @c_Pickdetailkey
                  	          	  
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3    
            SELECT @n_Err = 63510    
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error update PICKDETAIL (ispPOA07)'
         END
         	      	
         FETCH NEXT FROM CURSOR_PICK INTO @c_Pickdetailkey
      END
      CLOSE CURSOR_PICK          
      DEALLOCATE CURSOR_PICK                     
     
      FETCH NEXT FROM CUR_LOCID INTO @c_Storerkey, @c_Loc, @c_Id
   END -- WHILE @@FETCH_STATUS <> -1       
   CLOSE CUR_LOCID        
   DEALLOCATE CUR_LOCID  
   
EXIT_SP:
    
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_Success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
      ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @n_StartTCnt    
         BEGIN    
            COMMIT TRAN    
         END    
      END    
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA07'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_Success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END    
    
END -- Procedure  

GO