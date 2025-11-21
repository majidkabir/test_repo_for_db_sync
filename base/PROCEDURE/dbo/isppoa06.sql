SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPOA06                                           */  
/* Creation Date: 23-Oct-2018                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-6772 PH Remove partial allocation line if not meet      */
/*          orderdetail UOM.                                            */
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
CREATE PROC [dbo].[ispPOA06]    
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
            @c_Pickdetailkey         NVARCHAR(10),
            @c_UOM                   NVARCHAR(10)
                                                              
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0  
   SELECT @c_ErrMsg=''  
    
   IF @n_Continue=1 OR @n_Continue=2    
   BEGIN    
      IF ISNULL(RTRIM(@c_OrderKey),'') = '' AND ISNULL(RTRIM(@c_LoadKey),'') = '' AND ISNULL(RTRIM(@c_WaveKey),'') = ''
      BEGIN    
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63500    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey & Orderkey & Wavekey are Blank (ispPOA06)'
         GOTO EXIT_SP    
      END    
   END -- @n_Continue =1 or @n_Continue = 2    
   
   IF ISNULL(RTRIM(@c_OrderKey), '') <> ''
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey 
      FROM ORDERS WITH (NOLOCK)
      WHERE OrderKey = @c_OrderKey 
   END
   ELSE IF ISNULL(RTRIM(@c_LoadKey), '') <> ''
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey 
      FROM LoadplanDetail (NOLOCK)
      WHERE LoadKey = @c_LoadKey      
   END
   ELSE
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey 
      FROM WaveDetail (NOLOCK)
      WHERE WaveKey = @c_WaveKey      
   END
 
   OPEN CUR_ORDERKEY    

   FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey
     
   WHILE @@FETCH_STATUS <> -1  --loop order
   BEGIN       
      IF @b_debug=1    
      BEGIN    
         PRINT @c_OrderKey       
      END    
      
      DECLARE CURSOR_ORDLINENOTFULFILL CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT OD.OrderLineNumber, 
               CASE WHEN OD.UOM = PackUOM4 THEN '1'  --pallet
                    WHEN OD.UOM = PackUOM1 THEN '2'  --case                                                      
                    WHEN OD.UOM = PackUOM2 THEN '3'  --innerpack
                    WHEN OD.UOM = PackUOM3 THEN '6'  --each
                    ELSE '6' END AS UOM
         FROM ORDERS O (NOLOCK)
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         WHERE O.Orderkey = @c_Orderkey
         AND OD.OpenQty <> (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
         ORDER BY OD.OrderLineNumber    
      
      OPEN CURSOR_ORDLINENOTFULFILL         
                       
      FETCH NEXT FROM CURSOR_ORDLINENOTFULFILL INTO @c_OrderLineNumber, @c_UOM
             
      WHILE @@FETCH_STATUS <> -1    --loop orderdetail not fullfil 
      BEGIN           	      	 
         DECLARE CURSOR_DELPICK CURSOR FAST_FORWARD READ_ONLY FOR 
            SELECT PD.Pickdetailkey
            FROM PICKDETAIL PD (NOLOCK)
            WHERE PD.Orderkey = @c_Orderkey
            AND PD.OrderLineNumber = @c_OrderLineNumber
            AND PD.Uom > @c_UOM
            ORDER BY PD.Pickdetailkey
            
         OPEN CURSOR_DELPICK         
                         
         FETCH NEXT FROM CURSOR_DELPICK INTO @c_Pickdetailkey
          
         WHILE @@FETCH_STATUS <> -1  --loop pickdetail to delete   
         BEGIN
         	  DELETE FROM PICKDETAIL
         	  WHERE Pickdetailkey = @c_Pickdetailkey
         	          	  
         	  IF @@ERROR <> 0
         	  BEGIN
               SELECT @n_Continue = 3    
               SELECT @n_Err = 63510    
               SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error delete PICKDETAIL (ispPOA06)'
               GOTO EXIT_SP    
            END
         	
            FETCH NEXT FROM CURSOR_DELPICK INTO @c_Pickdetailkey
         END
         CLOSE CURSOR_DELPICK          
         DEALLOCATE CURSOR_DELPICK                                      	 
      	
         FETCH NEXT FROM CURSOR_ORDLINENOTFULFILL INTO @c_OrderLineNumber, @c_UOM
      END
      CLOSE CURSOR_ORDLINENOTFULFILL          
      DEALLOCATE CURSOR_ORDLINENOTFULFILL                     
     
      FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey       
   END -- WHILE @@FETCH_STATUS <> -1    
   
   CLOSE CUR_ORDERKEY        
   DEALLOCATE CUR_ORDERKEY  
   
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA06'    
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