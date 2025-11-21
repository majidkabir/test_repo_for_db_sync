SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPOA09                                           */  
/* Creation Date: 30-May-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLCHOOI                                                  */  
/*                                                                      */  
/* Purpose: WMS-9147 TH-NIKE enhance Build Load for Auto delete Orders  */
/*                                                                      */  
/* Called By: StorerConfig.ConfigKey = PostAllocationSP                 */  
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
CREATE PROC [dbo].[ispPOA09]    
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
            @c_OrderLineNumber       NVARCHAR(5),
            @c_DocType               NVARCHAR(20),
            @c_GetOrderKey           NVARCHAR(10),
            @c_MaxOrderKey           NVARCHAR(10),
            @c_PickZone              NVARCHAR(10),
            @b_NotLast               INT = 0,
            @n_Qty                   INT = 0,
            @c_FinalizeFlag          NVARCHAR(5)

   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0  
   SELECT @c_ErrMsg=''

   CREATE TABLE #Temp_Ord(
   Loadkey     NVARCHAR(10),
   Orderkey    NVARCHAR(10),
   Pickzone    NVARCHAR(10),
   Qty         INT
   ) 
   
   SELECT TOP 1 @c_LoadKey = Loadkey
   FROM ORDERS (NOLOCK)
   WHERE Orderkey = @c_OrderKey 

   SELECT @c_FinalizeFlag = FinalizeFlag
   FROM LOADPLAN (NOLOCK)
   WHERE Loadkey = @c_LoadKey

   IF (@c_FinalizeFlag = 'Y')
      GOTO EXIT_SP

   --Check in the load, if all the other orderkey in the load (exclude this current one) have status 2 OR CANC, then the current orderkey is the last one.
   IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE LoadKey = @c_LoadKey AND STATUS NOT IN ('2','CANC') AND ORDERKEY <> @c_OrderKey )
   BEGIN
      SET @b_NotLast = 1
   END

   --Filter orderkey and save into temp table
   IF (@n_Continue=1 OR @n_Continue=2) 
   BEGIN
      INSERT INTO #Temp_Ord
      SELECT ORD.Loadkey, ORD.Orderkey, LOC.Pickzone, SUM(PD.Qty)
      FROM Pickdetail PD (NOLOCK) 
      JOIN LOC (NOLOCK) ON LOC.LOC = PD.LOC
      JOIN ORDERS ORD (NOLOCK) ON ORD.Orderkey = PD.Orderkey 
      WHERE ORD.Orderkey = @c_OrderKey 
      AND ( --ORD.Status IN ('0','1') OR
      LOC.PICKZONE IN ('NIKE-M3') )
      GROUP BY ORD.Loadkey, ORD.Orderkey, LOC.Pickzone
   END

   IF @b_debug=1    
   BEGIN    
      SELECT * FROM #Temp_Ord
   END 

   --For last step, update orders.status = CANC
   DECLARE CUR_CANCORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OrderKey, Pickzone, SUM(Qty) 
   FROM #Temp_Ord
   WHERE Orderkey = @c_OrderKey AND Pickzone IN ('NIKE-M3')
   GROUP BY OrderKey, Pickzone

   --For deleting loadkey
   DECLARE CUR_LOADKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OrderKey 
   FROM LOADPLANDETAIL (NOLOCK)
   WHERE Loadkey = @c_LoadKey

   --For orders.status = 2, allocated orders need to be unallocated
   --Delete pickdetail
   DECLARE CUR_ALLOCATED CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OrderKey 
   FROM Orders (NOLOCK)
   WHERE Loadkey = @c_LoadKey AND Status NOT IN ('0','CANC')

   --Unallocate all the orders in the load where orders.status = 2, allocated, if this current orderkey is the last one
   IF (@n_Continue=1 OR @n_Continue=2) AND @b_NotLast = 0   
   BEGIN 
    --  PRINT 'Step 1'  

      OPEN CUR_ALLOCATED    

      FETCH NEXT FROM CUR_ALLOCATED INTO @c_GetOrderKey
   
      WHILE @@FETCH_STATUS <> -1  --loop order
      BEGIN       
         IF @b_debug=1    
         BEGIN  
            PRINT 'Now unallocating ' + @c_GetOrderKey 
         END    

         DELETE FROM PICKDETAIL
         WHERE ORDERKEY = @c_GetOrderKey

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3    
            SELECT @n_Err = 63500    
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while deleting from Pickdetail table. Orderkey =  ' + @c_GetOrderKey + ' (ispPOA09)'
            GOTO EXIT_SP    
         END

         FETCH NEXT FROM CUR_ALLOCATED INTO @c_GetOrderKey       
      END -- WHILE @@FETCH_STATUS <> -1    
   
      CLOSE CUR_ALLOCATED   
   END
   
   --Delete all records from Loadplandetail, if this current orderkey is the last one
   IF (@n_Continue=1 OR @n_Continue=2) AND @b_NotLast = 0
   BEGIN 
   --   PRINT 'Step 2' 

      OPEN CUR_LOADKEY    
      
      FETCH NEXT FROM CUR_LOADKEY INTO @c_GetOrderKey
      
      WHILE @@FETCH_STATUS <> -1  --loop order
      BEGIN       
         IF @b_debug=1    
         BEGIN    
            PRINT 'Now deleting Orderkey: ' + @c_GetOrderKey + ' from Loadkey: ' + @c_Loadkey
         END
         
         DELETE FROM LOADPLANDETAIL
         WHERE ORDERKEY = @c_GetOrderKey
         
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3    
            SELECT @n_Err = 63510    
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while deleting from LoadPlanDetail table. Orderkey = ' + @c_GetOrderKey 
                            + ' Loadkey = ' + @c_Loadkey + ' (ispPOA09)'
            GOTO EXIT_SP    
         END

      FETCH NEXT FROM CUR_LOADKEY INTO @c_GetOrderKey       
      END -- WHILE @@FETCH_STATUS <> -1    
   
      CLOSE CUR_LOADKEY        
      DEALLOCATE CUR_LOADKEY  
   END  
   
   --Delete Loadkey from Loadplan, if this current orderkey is the last one
   IF (@n_Continue=1 OR @n_Continue=2) AND @b_NotLast = 0
   BEGIN   
   --   PRINT 'Step 3' 
       
      IF @b_debug=1    
      BEGIN   
         PRINT 'Now deleting Loadkey: ' + @c_Loadkey
      END

      DELETE FROM LOADPLAN
      WHERE LOADKEY = @c_LoadKey

      IF @@ERROR <> 0
      BEGIN
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63520    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while deleting from LoadPlan table. Loadkey = ' + @c_LoadKey + ' (ispPOA09)'
         GOTO EXIT_SP    
      END
   END
      
   IF EXISTS (SELECT 1 FROM #Temp_Ord WHERE Loadkey = @c_LoadKey)
   BEGIN
      --Update the Status and SOStatus of all the orders in the temp table 
      IF @n_Continue=1 OR @n_Continue=2    
      BEGIN  
      --   PRINT 'Step 4' 

         OPEN CUR_CANCORDERKEY    

         FETCH NEXT FROM CUR_CANCORDERKEY INTO @c_GetOrderKey, @c_PickZone, @n_Qty
     
         WHILE @@FETCH_STATUS <> -1  --loop order
         BEGIN       
            IF @b_debug=1    
            BEGIN   
               PRINT 'Now updating Status and SOStatus for Orderkey: '+ @c_GetOrderKey + ' Qty = ' + CAST(@n_Qty AS NVARCHAR(20)) + ' on Pickzone ' + @c_PickZone   
            END
            
            DELETE FROM PICKDETAIL
            WHERE ORDERKEY = @c_GetOrderKey

            IF @@ERROR <> 0
            BEGIN
               SELECT @n_Continue = 3    
               SELECT @n_Err = 63540    
               SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while deleting from Pickdetail table. Orderkey =  ' + @c_GetOrderKey + ' (ispPOA09)'
               GOTO EXIT_SP    
            END

            UPDATE ORDERS
            SET Status = 'CANC', SOStatus = 'CANC', TrafficCop = NULL
            WHERE ORDERKEY = @c_GetOrderKey

            IF @@ERROR <> 0
            BEGIN
               SELECT @n_Continue = 3    
               SELECT @n_Err = 63550    
               SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while updating Orders table. Orderkey = ' + @c_GetOrderKey + ' (ispPOA09)'
               GOTO EXIT_SP    
            END

            UPDATE ORDERDETAIL
            SET FreeGoodQty = @n_Qty, TrafficCop = NULL
            WHERE ORDERKEY = @c_GetOrderKey

            IF @@ERROR <> 0
            BEGIN
               SELECT @n_Continue = 3    
               SELECT @n_Err = 63560    
               SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while updating Orderdetail table. Orderkey = ' + @c_GetOrderKey + ' (ispPOA09)'
               GOTO EXIT_SP    
            END

            FETCH NEXT FROM CUR_CANCORDERKEY INTO @c_GetOrderKey, @c_PickZone, @n_Qty       
         END -- WHILE @@FETCH_STATUS <> -1    
   
         CLOSE CUR_CANCORDERKEY        
         DEALLOCATE CUR_CANCORDERKEY 
      END 
   END

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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA09'    
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