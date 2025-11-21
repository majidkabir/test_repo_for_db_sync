SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispWVM02                                           */
/* Creation Date: 28-SEP-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-2819 - CN PVH Check Wave allocate mode by order type    */   
/*                     Wholesale - discrete                             */
/*                     Retail new launch - Wave conso                   */
/*                     Retail replenishment - load conso                */
/*                     (Copy from ispwvm01 for CN only)                 */
/*                                                                      */
/* Called By: isp_WaveCheckAllocateMode_Wrapper from Wave allocation    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 19-SEP-2018  NJOW01   1.0  WMS-6244 wholesales ecom allocate by load */
/*                            conso                                     */
/* 09-NOV-2020  NJOW02   1.1  WMS-15565 change condition to determine   */
/*                            wave mode                                 */
/************************************************************************/

CREATE PROC [dbo].[ispWVM02]   
   @c_WaveKey       NVARCHAR(10),
   @c_AllocateMode  NVARCHAR(10) OUTPUT,  --#LC=LoadConso(LoadConsoAllocation must turn on), #WC=Wave conso(WaveConsoAllocation must turn on & loadplan superorderflag must set) , #DC=Discrete  
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue      INT,
           @n_StartTCnt     INT,
           @c_OrdType       NVARCHAR(10),
           @c_Loadkey       NVARCHAR(10),           
           @c_BillToKey     NVARCHAR(15), --NJOW01
           @c_SalesMan      NVARCHAR(30), --NJOW02
           @c_WaveType      NVARCHAR(18), --NJOW02
           @c_Preallocatetype NVARCHAR(20), --NJOW02
           @c_Orderkey        NVARCHAR(10) --NJOW02
                                             
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	 
	 IF EXISTS (SELECT 1
	            FROM WAVEDETAIL WD (NOLOCK)
	            JOIN ORDERS O (NOLOCK)  ON WD.Orderkey = O.Orderkey
              LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'ORDERGROUP' AND O.OrderGroup = CL.Code AND O.Storerkey = CL.Storerkey
              WHERE WD.Wavekey = @c_Wavekey
              AND CL.Code IS NULL)
   BEGIN
      SELECT @n_continue = 3  
      SELECT @n_err = 36100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found invalid ordergroup. (ispWVM02)' 
      GOTO QUIT_SP
   END

	 IF EXISTS (SELECT 1
	            FROM WAVEDETAIL WD (NOLOCK)
	            JOIN ORDERS O (NOLOCK)  ON WD.Orderkey = O.Orderkey
              JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'ORDERGROUP' AND O.OrderGroup = CL.Code AND O.Storerkey = CL.Storerkey
              WHERE WD.Wavekey = @c_Wavekey
	            GROUP BY WD.Wavekey
	            HAVING COUNT(DISTINCT CL.Short) > 1)

   BEGIN
      SELECT @n_continue = 3  
      SELECT @n_err = 36100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found more than 1 ordergroup in a wave is not allowed. (ispWVM02)' 
      GOTO QUIT_SP
   END
	
	 SELECT TOP 1 @c_OrdType = CL.Short,
	              @c_BillToKey = O.BillToKey, --NJOW01
	              @c_SalesMan = O.Salesman, --NJOW02
	              @c_WaveType = W.WaveType --NJOW02
	 FROM WAVE W (NOLOCK) 
	 JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey
	 JOIN ORDERS O (NOLOCK)  ON WD.Orderkey = O.Orderkey
   JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'ORDERGROUP' AND O.OrderGroup = CL.Code AND O.Storerkey = CL.Storerkey
   WHERE W.Wavekey = @c_Wavekey
   
   --NJOW02 S
   IF @c_OrdType = '1'  --Wholesales,ECOM Multi-order(non-PTS)
      AND @c_Salesman <> 'TRF' AND @c_WaveType <> 'PTS'
   BEGIN
      SET @c_AllocateMode = '#DC'
   END

   IF @c_OrdType = '1'  --Wholesales,ECOM Multi-order(PTS)
      AND @c_Salesman <> 'TRF' AND @c_WaveType = 'PTS'
   BEGIN
      SET @c_AllocateMode = '#WC'
      SET @c_Preallocatetype = 'DISCRETE'
   END
     
   IF @c_OrdType = '2'  --Retail, new launch, replenishment, ecom single(non-PTS)
      AND @c_Salesman <> 'TRF' AND @c_WaveType <> 'PTS' 
      SET @c_AllocateMode = '#LC'  

   IF @c_OrdType = '2'  --Retail, new launch, replenishment, ecom single(PTS)
      AND @c_Salesman <> 'TRF' AND @c_WaveType = 'PTS' 
   BEGIN   
      SET @c_AllocateMode = '#WC'
      SET @c_Preallocatetype = 'LOADCONSO'
   END  
   
   IF @c_SalesMan = 'TRF'
      SET @c_AllocateMode = '#DC'     
   
   IF @c_Preallocatetype = "DISCRETE"
   BEGIN
      DECLARE CUR_WAVORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.Orderkey
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
         WHERE WD.Wavekey = @c_Wavekey
         ORDER BY O.Priority, O.Orderkey
         
      OPEN CUR_WAVORD
      
      FETCH NEXT FROM CUR_WAVORD INTO @c_Orderkey
          
      WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
      BEGIN
      	  EXEC nsp_orderprocessing_wrapper 
      	     @c_OrderKey = @c_Orderkey, 
      	     @c_oskey = '', 
      	     @c_docarton = 'N',
      	     @c_doroute = 'N', 
      	     @c_tblprefix= '', 
      	     @c_Extendparms = '',
      	     @c_StrategykeyParm = ''
      	              	
         FETCH NEXT FROM CUR_WAVORD INTO @c_Orderkey
      END
      CLOSE CUR_WAVORD
      DEALLOCATE CUR_WAVORD    
   END               	      	
         
   IF @c_Preallocatetype = "LOADCONSO"
   BEGIN
      DECLARE CURSOR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT O.Loadkey
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
         WHERE WD.Wavekey = @c_Wavekey
         AND O.Loadkey IS NOT NULL
         AND O.Loadkey <> ''
         ORDER BY O.Loadkey
         
      OPEN CURSOR_LOAD
   
      FETCH NEXT FROM CURSOR_LOAD INTO @c_loadkey
          
      WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
      BEGIN
      	 EXEC nsp_orderprocessing_wrapper 
      	     @c_OrderKey = '', 
      	     @c_oskey = @c_Loadkey, 
      	     @c_docarton = 'N',
      	     @c_doroute = 'N', 
      	     @c_tblprefix= '', 
      	     @c_Extendparms = '',
      	     @c_StrategykeyParm = ''
      	
         FETCH NEXT FROM CURSOR_LOAD INTO @c_loadkey
      END
      CLOSE CURSOR_LOAD
      DEALLOCATE CURSOR_LOAD             	
   END   
   --NJOW02 E
   
   /*
   IF @c_OrdType = '1'  --Wholesales
      AND @c_Salesman <> 'TRF' --NJOW02
   BEGIN
   	  IF EXISTS (SELECT 1 
   	             FROM CODELKUP (NOLOCK)
                 WHERE ListName = 'PVHCONSO'      
                 AND Code = @c_BIllTokey
                 AND Short = 'C')  --NJOW01
      BEGIN           
         SET @c_AllocateMode = '#LC' --NJOW01
      END
      ELSE                 	  
         SET @c_AllocateMode = '#DC'
   END  

   IF @c_OrdType = '2'  --Retail new launch A
      AND @c_Salesman <> 'TRF' AND @c_WaveType = 'PTS' --NJOW02
      SET @c_AllocateMode = '#WC'  

   --NJOW02
   IF @c_OrdType = '2'  --Retail new launch B
      AND @c_Salesman <> 'TRF' AND @c_WaveType <> 'PTS'
      SET @c_AllocateMode = '#LC'  

   IF @c_OrdType = '3'  --Retail replenishment
      SET @c_AllocateMode = '#LC'
      
   --NJOW02
   IF @c_SalesMan = 'TRF'
      SET @c_AllocateMode = '#DC'     
   
   --For retail new lauch have to run load conso to allocate full carton by load (control in pickcode for uom 2 only), after that run full conso carton by wave. 
   --It try to conso the carton by load first then wave.
   --load conso only allow conso carton allocation, the remain qty allocate by wave conso
   IF @c_AllocateMode = "#WC"
   BEGIN
      DECLARE CURSOR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT O.Loadkey
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
         WHERE WD.Wavekey = @c_Wavekey
         AND O.Loadkey IS NOT NULL
         AND O.Loadkey <> ''
         ORDER BY O.Loadkey
         
      OPEN CURSOR_LOAD
   
      FETCH NEXT FROM CURSOR_LOAD INTO @c_loadkey
          
      WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
      BEGIN
      	 EXEC nsp_orderprocessing_wrapper '', @c_Loadkey, 'N','N', '', '' 
      	
         FETCH NEXT FROM CURSOR_LOAD INTO @c_loadkey
      END
      CLOSE CURSOR_LOAD
      DEALLOCATE CURSOR_LOAD             	
   END
   */
            
   QUIT_SP:
   
	 IF @n_Continue=3  -- Error Occured - Process AND Return
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispWVM02'		
	    --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
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
END  

GO