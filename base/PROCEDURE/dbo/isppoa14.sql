SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispPOA14                                           */    
/* Creation Date: 26-Aug-2020                                           */    
/* Copyright: LFL                                                       */    
/* Written by: WLChooi                                                  */    
/*                                                                      */    
/* Purpose: WMS-14894 - CN NIKE ECOM PostAlloc Order Mark               */  
/*                                                                      */    
/* Called By: StorerConfig.ConfigKey = PostAllocationSP                 */    
/*                                                                      */    
/* GitLab Version: 1.4                                                  */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Rev   Purposes                                  */ 
/* 21-Oct-2020  SHONG   1.1   Performance Tuning                        */
/* 09-Jul-2021  NJOW01  1.2   WMS-17326 Remove lottable01 if hostwhcode */
/* 23-Sep-2021  WLChooi 1.3   DevOps Combine Script                     */
/* 23-Sep-2021  WLChooi 1.4   WMS-18020 - Add Pickzone Mark Logic (WL01)*/
/************************************************************************/    
CREATE PROC [dbo].[ispPOA14]      
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
            @c_Orderkey2             NVARCHAR(10),  
            @c_Putawayzone           NVARCHAR(4000),  
            @c_OrderLinenumber       NVARCHAR(5),
            @c_Storerkey             NVARCHAR(15),   --WL01
            @c_Option2               NVARCHAR(50),   --WL01
            @n_LOCScore              INT,            --WL01
            @c_Pickzone              NVARCHAR(50)    --WL01
                                                                            
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''    
     
   CREATE TABLE #TMP_ORD (  
      Orderkey      NVARCHAR(10) NULL,  
      Putawayzone   NVARCHAR(10) NULL
   )  
  
   CREATE TABLE #TMP_ORD_Final (  
      Orderkey      NVARCHAR(10) NULL,  
      Putawayzone   NVARCHAR(4000) NULL
   )  
   
   --WL01 S
   CREATE TABLE #TMP_PZ (  
      Orderkey      NVARCHAR(10) NULL,  
      Pickzone      NVARCHAR(50) NULL
   )  
  
   CREATE TABLE #TMP_PZ_Final (  
      Orderkey      NVARCHAR(10) NULL,  
      Pickzone      NVARCHAR(4000) NULL
   )  

   IF @n_continue IN(1,2)   
   BEGIN  
      IF ISNULL(RTRIM(@c_OrderKey), '') <> ''  
      BEGIN  
         INSERT INTO #TMP_PZ (Orderkey, Pickzone)
         SELECT O.Orderkey, LOC.PickZone
         FROM PICKDETAIL PD (NOLOCK)  
         JOIN LOC LOC (NOLOCK) ON LOC.LOC = PD.LOC  
         JOIN ORDERS O (NOLOCK) ON O.Orderkey = PD.Orderkey  
         WHERE (O.Orderkey = @c_Orderkey)  
         AND O.DocType = 'E'  
         AND O.Status = '2'
         GROUP BY O.Orderkey, LOC.PickZone
         ORDER BY O.Orderkey  
      END
      ELSE IF ISNULL(RTRIM(@c_Loadkey), '') <> ''  
      BEGIN
         INSERT INTO #TMP_PZ (Orderkey, Pickzone)
         SELECT O.Orderkey, LOC.PickZone 
         FROM PICKDETAIL PD (NOLOCK)  
         JOIN LOC LOC (NOLOCK) ON LOC.LOC = PD.LOC  
         JOIN ORDERS O (NOLOCK) ON O.Orderkey = PD.Orderkey  
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = O.Orderkey  
         WHERE (LPD.Loadkey = @c_Loadkey)  
         AND O.DocType = 'E'  
         GROUP BY O.Orderkey, LOC.PickZone  
         ORDER BY O.Orderkey  
      END 
      ELSE IF ISNULL(RTRIM(@c_Wavekey), '') <> ''  
      BEGIN
         INSERT INTO #TMP_PZ (Orderkey, Pickzone)
         SELECT O.Orderkey, LOC.PickZone
         FROM PICKDETAIL PD (NOLOCK)  
         JOIN LOC LOC (NOLOCK) ON LOC.LOC = PD.LOC  
         JOIN ORDERS O (NOLOCK) ON O.Orderkey = PD.Orderkey  
         JOIN WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = O.Orderkey  
         WHERE (WD.Wavekey = @c_Wavekey)  
         AND O.DocType = 'E'  
         GROUP BY O.Orderkey, LOC.PickZone
         ORDER BY O.Orderkey  
      END 
      ELSE 
      BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 63505    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey, Wave and Orderkey are Blank (ispPOA14)'  
         GOTO EXIT_SP      
      END    

      INSERT INTO #TMP_PZ_Final
      SELECT DISTINCT t2.Orderkey,   
             STUFF((SELECT RTRIM(t1.Pickzone) FROM #TMP_PZ t1  
                    WHERE t1.Orderkey = t2.Orderkey  
                    ORDER BY t1.Pickzone FOR XML PATH('')),1,0,'' )
      FROM #TMP_PZ t2  
      ORDER BY t2.Orderkey  
   END  

   IF @n_continue IN(1,2)   
   BEGIN  
      SELECT TOP 1 @c_Storerkey = OH.Storerkey
      FROM ORDERS OH (NOLOCK)
      JOIN #TMP_PZ_Final TPF ON TPF.Orderkey = OH.OrderKey

      SELECT @c_Option2 = ISNULL(SC.OPTION2,'')
      FROM STORERCONFIG SC (NOLOCK)
      WHERE SC.ConfigKey = 'PostAllocationSP'
      AND SC.SValue = 'ispPOA14'
      AND SC.StorerKey = @c_Storerkey
   END

   --Mark Pickzone & Update Orders.Capacity = MAX(LOC.Score)
   IF @n_continue IN(1,2)
   BEGIN               
      DECLARE cur_PZ CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT Orderkey, Pickzone  
         FROM #TMP_PZ_Final   
         ORDER BY Orderkey  
        
      OPEN cur_PZ    
            
      FETCH NEXT FROM cur_PZ INTO @c_Orderkey2, @c_Pickzone  
            
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN       
         SELECT @n_LOCScore = MAX(LOC.Score)
         FROM PICKDETAIL PD (NOLOCK)
         JOIN LOC LOC (NOLOCK) ON PD.LOC = LOC.Loc
         WHERE PD.OrderKey = @c_Orderkey2

         UPDATE ORDERS WITH (ROWLOCK)  
         SET M_Address4 = SUBSTRING(@c_Pickzone, 1, 45),  
             Capacity   = @n_LOCScore,
             EditDate   = GETDATE(),  
             EditWho    = SUSER_SNAME(),  
             TrafficCop = NULL  
         WHERE Orderkey = @c_Orderkey2  

         SET @n_err = @@ERROR  
           
         IF @n_err <> 0                                                                                                                                                               
         BEGIN                                                                                                                                                                                  
            SELECT @n_Continue = 3                                                                                                                                                              
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 35005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                            
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update ORDERS table failed. (ispPOA13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
         END  
  
         FETCH NEXT FROM cur_PZ INTO @c_Orderkey2, @c_Pickzone  
      END  
      CLOSE cur_PZ
      DEALLOCATE cur_PZ        
   END
   --WL01 E

   IF @n_continue IN(1,2) AND @c_Option2 = 'MARKPUTAWAYZONE'   --WL01  
   BEGIN  
      -- Comment by SHONG, This statement causing blocking issues, need to split into smaller section
      --INSERT INTO #TMP_ORD (Orderkey, Putawayzone)  
      --SELECT O.Orderkey, LOC.Putawayzone  
      --FROM PICKDETAIL PD (NOLOCK)  
      --JOIN LOC LOC (NOLOCK) ON LOC.LOC = PD.LOC  
      --LEFT JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = PD.Orderkey  
      --LEFT JOIN WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = LPD.Orderkey  
      --JOIN ORDERS O (NOLOCK) ON O.Orderkey = PD.Orderkey  
      --JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'NKEEXWH' AND CL.Storerkey = PD.Storerkey  
      --                        AND CL.Code = LOC.Putawayzone  
      --WHERE (LPD.Loadkey = @c_Loadkey OR ISNULL(@c_Loadkey,'') = '')  
      --AND (WD.Wavekey = @c_Wavekey OR ISNULL(@c_Wavekey,'') = '')  
      --AND (O.Orderkey = @c_Orderkey OR ISNULL(@c_Orderkey,'') = '')  
      --AND O.DocType = 'E'  
      --GROUP BY O.Orderkey, LOC.Putawayzone  
      --ORDER BY O.Orderkey  

      IF ISNULL(RTRIM(@c_OrderKey), '') <> ''  
      BEGIN  
         INSERT INTO #TMP_ORD (Orderkey, Putawayzone)
         SELECT O.Orderkey, LOC.Putawayzone
         FROM PICKDETAIL PD (NOLOCK)  
         JOIN LOC LOC (NOLOCK) ON LOC.LOC = PD.LOC  
         JOIN ORDERS O (NOLOCK) ON O.Orderkey = PD.Orderkey  
         JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'NKEEXWH' AND CL.Storerkey = PD.Storerkey  
                                 AND CL.Code = LOC.Putawayzone  
         WHERE (O.Orderkey = @c_Orderkey)  
         AND O.DocType = 'E'  
         AND O.Status = '2'  --NJOW02  Auto allocation tuning
         GROUP BY O.Orderkey, LOC.Putawayzone
         ORDER BY O.Orderkey  
      END
      ELSE IF ISNULL(RTRIM(@c_Loadkey), '') <> ''  
      BEGIN
         INSERT INTO #TMP_ORD (Orderkey, Putawayzone)
         SELECT O.Orderkey, LOC.Putawayzone 
         FROM PICKDETAIL PD (NOLOCK)  
         JOIN LOC LOC (NOLOCK) ON LOC.LOC = PD.LOC  
         JOIN ORDERS O (NOLOCK) ON O.Orderkey = PD.Orderkey  
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = O.Orderkey  
         JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'NKEEXWH' AND CL.Storerkey = PD.Storerkey  
                                 AND CL.Code = LOC.Putawayzone  
         WHERE (LPD.Loadkey = @c_Loadkey)  
         AND O.DocType = 'E'  
         GROUP BY O.Orderkey, LOC.Putawayzone  
         ORDER BY O.Orderkey  
      END 
      ELSE IF ISNULL(RTRIM(@c_Wavekey), '') <> ''  
      BEGIN
         INSERT INTO #TMP_ORD (Orderkey, Putawayzone)
         SELECT O.Orderkey, LOC.Putawayzone
         FROM PICKDETAIL PD (NOLOCK)  
         JOIN LOC LOC (NOLOCK) ON LOC.LOC = PD.LOC  
         JOIN ORDERS O (NOLOCK) ON O.Orderkey = PD.Orderkey  
         JOIN WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = O.Orderkey  
         JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'NKEEXWH' AND CL.Storerkey = PD.Storerkey  
                                 AND CL.Code = LOC.Putawayzone  
         WHERE (WD.Wavekey = @c_Wavekey)  
         AND O.DocType = 'E'  
         GROUP BY O.Orderkey, LOC.Putawayzone
         ORDER BY O.Orderkey  
      END 
      ELSE 
      BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 63500      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey, Wave and Orderkey are Blank (ispPOA14)'  
         GOTO EXIT_SP      
      END    

      IF (SELECT COUNT(1) FROM #TMP_ORD) = 0  --NJOW01 Auto allocation tuning
        GOTO UPDATE_LOTTABLE

      INSERT INTO #TMP_ORD_Final
      SELECT DISTINCT t2.Orderkey,   
             STUFF((SELECT RTRIM(t1.Putawayzone) FROM #TMP_ORD t1  
                    WHERE t1.Orderkey = t2.Orderkey  
                    ORDER BY t1.Putawayzone FOR XML PATH('')),1,0,'' )
      FROM #TMP_ORD t2  
      ORDER BY t2.Orderkey  
   END  
  
   IF @n_continue IN(1,2) AND @c_Option2 = 'MARKPUTAWAYZONE'   --WL01
   BEGIN               
      DECLARE cur_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT Orderkey, Putawayzone  
         FROM #TMP_ORD_Final   
         ORDER BY Orderkey  
        
      OPEN cur_ORD    
            
      FETCH NEXT FROM cur_ORD INTO @c_Orderkey2, @c_Putawayzone  
            
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN       
         --SELECT @c_Orderkey2, @c_Putawayzone  
  
         UPDATE ORDERS WITH (ROWLOCK)  
         SET B_Address4 = SUBSTRING(@c_Putawayzone, 1, 45),  
             EditDate = GETDATE(),  
             EditWho = SUSER_SNAME(),  
             TrafficCop = NULL  
         WHERE Orderkey = @c_Orderkey2  
  
         SET @n_err = @@ERROR  
           
         IF @n_err <> 0                                                                                                                                                               
         BEGIN                                                                                                                                                                                  
            SELECT @n_Continue = 3                                                                                                                                                              
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 35010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                            
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update ORDERS table failed. (ispPOA13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
         END  
  
         FETCH NEXT FROM cur_ORD INTO @c_Orderkey2, @c_Putawayzone  
      END  
      CLOSE cur_ORD  
      DEALLOCATE cur_ORD        
   END  
   
   --NJOW02
   UPDATE_LOTTABLE:
   IF @n_continue IN(1,2)
   BEGIN
      IF ISNULL(RTRIM(@c_OrderKey), '') <> ''
      BEGIN
      	  IF NOT EXISTS(SELECT 1 
      	                FROM ORDERS O (NOLOCK)
      	                JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
      	                WHERE O.Orderkey = @c_Orderkey
      	                AND O.b_company = '3940' 
      	                AND OD.Lottable01 = '001'
      	               )    
      	  BEGIN
      	  	 GOTO EXIT_SP  --auto allocation tuning
      	  END                         
      	     	  
         DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT O.OrderKey
            FROM ORDERS O (NOLOCK)
            WHERE O.OrderKey = @c_OrderKey 
            AND O.b_company = '3940'        
      END
      ELSE IF ISNULL(RTRIM(@c_LoadKey), '') <> ''
      BEGIN
         DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT O.OrderKey
            FROM LOADPLANDETAIL LPD (NOLOCK)
            JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
            WHERE LPD.LoadKey = @c_LoadKey     
            AND O.b_company = '3940'        
      END
      ELSE
      BEGIN
         DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT O.OrderKey
            FROM WAVEDETAIL WD (NOLOCK)
            JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
            WHERE WD.WaveKey = @c_WaveKey
            AND O.b_company = '3940'                 
      END          
             
      OPEN CUR_ORDERKEY    
      
      FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey
        
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2) --loop order
      BEGIN          	
      	  DECLARE CUR_ORDERDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      	     SELECT OD.OrderLineNumber
      	     FROM ORDERDETAIL OD (NOLOCK)
      	     WHERE OD.Orderkey = @c_Orderkey
      	     AND OD.Lottable01 = '001'
      	     ORDER BY OD.OrderLineNumber
      
         OPEN CUR_ORDERDET    
         
         FETCH NEXT FROM CUR_ORDERDET INTO @c_OrderLinenumber
           
         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2) --loop order detail
         BEGIN       
         	 UPDATE ORDERDETAIL WITH (ROWLOCK)
         	 SET Lottable01 = '',
         	     TrafficCop = NULL
         	 WHERE Orderkey = @c_Orderkey
         	 AND OrderLineNumber = @c_OrderLineNumber
         	      	
            IF @@ERROR <> 0
            BEGIN
               SELECT @n_Continue = 3    
               SELECT @n_Err = 35020    
               SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error update ORDERDETAIL table. (ispPOA20)'
            END
      
            FETCH NEXT FROM CUR_ORDERDET INTO @c_OrderLinenumber
      	  END   
      	  CLOSE CUR_ORDERDET
      	  DEALLOCATE CUR_ORDERDET
      	        
         FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey    
      END -- WHILE @@FETCH_STATUS <> -1    
      
      CLOSE CUR_ORDERKEY        
      DEALLOCATE CUR_ORDERKEY                        
   END
           
EXIT_SP:  
   --WL01 S
   IF OBJECT_ID('tempdb..#TMP_ORD') IS NOT NULL
      DROP TABLE #TMP_ORD

   IF OBJECT_ID('tempdb..#TMP_ORD_Final') IS NOT NULL
      DROP TABLE #TMP_ORD_Final

   IF OBJECT_ID('tempdb..#TMP_PZ') IS NOT NULL
      DROP TABLE #TMP_PZ

   IF OBJECT_ID('tempdb..#TMP_PZ_Final') IS NOT NULL
      DROP TABLE #TMP_PZ_Final

   IF CURSOR_STATUS('LOCAL', 'cur_PZ') IN (0 , 1)
   BEGIN
      CLOSE cur_PZ
      DEALLOCATE cur_PZ   
   END

   IF CURSOR_STATUS('LOCAL', 'cur_ORD') IN (0 , 1)
   BEGIN
      CLOSE cur_ORD
      DEALLOCATE cur_ORD   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_ORDERKEY') IN (0 , 1)
   BEGIN
      CLOSE CUR_ORDERKEY
      DEALLOCATE CUR_ORDERKEY   
   END
   --WL01 E

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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA14'      
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