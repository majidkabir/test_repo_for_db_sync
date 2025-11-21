SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispPOA16                                           */    
/* Creation Date: 12-Dec-2020                                           */    
/* Copyright: LFL                                                       */    
/* Written by: WLChooi                                                  */    
/*                                                                      */    
/* Purpose: WMS-15808 - Drop Partial Allocated Order For Certain Courier*/  
/*                                                                      */    
/* Called By: StorerConfig.ConfigKey = PostAllocationSP                 */    
/*                                                                      */    
/* GitLab Version: 1.0                                                  */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Rev   Purposes                                  */ 
/************************************************************************/    
CREATE PROC [dbo].[ispPOA16]      
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
   SET CONCAT_NULL_YIELDS_NULL OFF           
      
   DECLARE  @n_Continue              INT,      
            @n_StartTCnt             INT, -- Holds the current transaction count  
            @c_Pickdetailkey         NVARCHAR(10),  
            @c_FullAlloc             NVARCHAR(30),
            @c_Storerkey             NVARCHAR(15),
            @c_Facility              NVARCHAR(5)  
                                                                            
   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue = 1, @b_Success = 1, @n_Err = 0, @c_ErrMsg = ''    
   
   IF @n_Continue IN (1,2)
   BEGIN
   	IF ISNULL(RTRIM(@c_OrderKey), '') <> ''  
      BEGIN   
         SELECT @c_Storerkey = O.StorerKey,
                @c_Facility  = O.Facility
         FROM ORDERS O (NOLOCK)  
         WHERE O.Orderkey = @c_Orderkey
      END
      ELSE IF ISNULL(RTRIM(@c_Loadkey), '') <> ''  
      BEGIN
         SELECT @c_Storerkey = O.StorerKey,
                @c_Facility  = O.Facility
         FROM LoadPlanDetail LPD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON LPD.OrderKey = O.OrderKey  
         WHERE LPD.Loadkey = @c_Loadkey  
      END 
      ELSE IF ISNULL(RTRIM(@c_Wavekey), '') <> ''  
      BEGIN
         SELECT @c_Storerkey = O.StorerKey,
                @c_Facility  = O.Facility
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
         WHERE WD.Wavekey = @c_Wavekey  
      END 
   END
   
   SELECT @c_FullAlloc = ISNULL(CL.Code,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'PKCODECFG'
   AND CL.Long = 'nspPR_PH09'
   AND CL.Code = 'FULLALLOC'
   AND CL.Storerkey = @c_Storerkey
   AND CL.Short = 'Y'
   AND (CL.Code2 = @c_Facility OR CL.Code2 = '')
   ORDER BY CASE WHEN CL.Code2 = '' THEN 2 ELSE 1 END

   IF @c_FullAlloc <> 'FULLALLOC'
      GOTO EXIT_SP
      
   CREATE TABLE #TMP_ORD (  
      Orderkey      NVARCHAR(10) NULL
   )  
  
   IF @n_continue IN(1,2)   
   BEGIN  
      IF ISNULL(RTRIM(@c_OrderKey), '') <> ''  
      BEGIN  
         INSERT INTO #TMP_ORD (Orderkey)  
         SELECT DISTINCT O.Orderkey  
         FROM ORDERS O (NOLOCK)  
         JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'COURIERLBL' AND CL.Storerkey = O.Storerkey  
                                  AND CL.Code = O.Salesman AND CL.Short = 'Y'  
         WHERE O.Orderkey = @c_Orderkey AND O.[Status] < '2'
      END
      ELSE IF ISNULL(RTRIM(@c_Loadkey), '') <> ''  
      BEGIN
         INSERT INTO #TMP_ORD (Orderkey)  
         SELECT DISTINCT O.Orderkey  
         FROM LoadPlanDetail LPD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON LPD.OrderKey = O.OrderKey
         JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'COURIERLBL' AND CL.Storerkey = O.Storerkey  
                                  AND CL.Code = O.Salesman AND CL.Short = 'Y'  
         WHERE LPD.LoadKey = @c_Loadkey AND O.[Status] < '2'
      END 
      ELSE IF ISNULL(RTRIM(@c_Wavekey), '') <> ''  
      BEGIN
         INSERT INTO #TMP_ORD (Orderkey)
         SELECT DISTINCT O.Orderkey  
         FROM WaveDetail WD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
         JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'COURIERLBL' AND CL.Storerkey = O.Storerkey  
                                  AND CL.Code = O.Salesman AND CL.Short = 'Y'  
         WHERE WD.Wavekey = @c_Wavekey AND O.[Status] < '2'  
      END 
      ELSE 
      BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 63500      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey, Wave and Orderkey are Blank (ispPOA16)'  
         GOTO EXIT_SP      
      END    
   END  
  
   IF @n_continue IN(1,2)   
   BEGIN   
   	BEGIN TRAN
   	            
      DECLARE cur_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT Pickdetailkey
         FROM PickDetail PD (NOLOCK) 
         JOIN #TMP_ORD t ON t.Orderkey = PD.OrderKey
         ORDER BY Pickdetailkey  
        
      OPEN cur_ORD    
            
      FETCH NEXT FROM cur_ORD INTO @c_Pickdetailkey  
            
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN       
      	--SELECT @c_Pickdetailkey
         DELETE FROM PICKDETAIL
         WHERE PickDetailKey = @c_Pickdetailkey
  
         SET @n_err = @@ERROR  
           
         IF @n_err <> 0                                                                                                                                                               
         BEGIN                                                                                                                                                                                  
            SELECT @n_Continue = 3                                                                                                                                                              
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 65010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                            
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PICKDETAIL Failed. (ispPOA16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
         END  
  
         FETCH NEXT FROM cur_ORD INTO @c_Pickdetailkey  
      END      
   END  
           
EXIT_SP:  
   IF OBJECT_ID('tempdb..#TMP_ORD') IS NOT NULL
      DROP TABLE #TMP_ORD
      
   IF CURSOR_STATUS('LOCAL', 'cur_ORD') IN (0 , 1)
   BEGIN
      CLOSE cur_ORD
      DEALLOCATE cur_ORD   
   END 
   
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA16'      
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