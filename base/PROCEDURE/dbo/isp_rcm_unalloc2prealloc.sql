SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_UnAlloc2PreAlloc                           */
/* Creation Date: 11-Mar-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 333505-Unallocate and migrate to pre-allocate pickdetail    */
/*                                                                      */
/* Called By: Dynamic RCM from Shipment Order                           */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_RCM_UnAlloc2PreAlloc]
   @c_orderkey NVARCHAR(10),   
   @b_success  int OUTPUT,
   @n_err      int OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30)=''
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_cnt int,
           @n_starttcnt int
           
   DECLARE @c_orderlinenumber NVARCHAR(5),
           @c_storerkey NVARCHAR(15),
           @c_sku NVARCHAR(20),
           @c_lot NVARCHAR(10),
           @c_uom NVARCHAR(10),
           @n_uomqty INT,
           @n_qty INT,
           @c_packkey NVARCHAR(10),
           @c_preallocatestrategykey NVARCHAR(10),
           @c_preallocatepickcode NVARCHAR(10),
           @c_docartonize NVARCHAR(1),
           @c_pickmethod NVARCHAR(1),
           @c_PreAllocatePickDetailKey NVARCHAR(10),
           @c_oprun NVARCHAR(10)
              
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
   
   IF NOT EXISTS(SELECT 1 FROM ORDERS(NOLOCK) WHERE SOStatus='3' AND orderkey = @c_Orderkey)
   BEGIN
	    SELECT @n_continue = 3
			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60095   
			SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Only SOStatus=3 Is Allowed To Unallocate. (isp_RCM_UnAlloc2PreAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			GOTO ENDPROC
   END

  SELECT PreAllocatePickDetailKey, OrderKey, OrderLineNumber, PreAllocateStrategyKey,  
         PreAllocatePickCode, Lot, StorerKey, Sku, Qty, UOMQty, UOM, PackKey, DOCartonize, Runkey, PickMethod
  INTO #TMP_PREALLOCATEPICKDETAIL
  FROM PREALLOCATEPICKDETAIL (NOLOCK)
  WHERE 1=2
   
   DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Lot, PD.UOM, SUM(PD.UOMQty) AS UOMQty, 
             SUM(PD.Qty) AS Qty, PD.Packkey, PSTG.PreAllocateStrategykey, PSTG.PreAllocatePickCode,
             PD.DoCartonize, PD.PickMethod
      FROM PICKDETAIL PD (NOLOCK)
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey
                        AND PD.Sku = SKU.Sku
      JOIN STRATEGY STG (NOLOCK) ON SKU.Strategykey = STG.Strategykey
      JOIN (SELECT Preallocatestrategykey, UOM, MIN(PreAllocatePickCode) AS PreAllocatePickCode      
            FROM PREALLOCATESTRATEGYDETAIL (NOLOCK)
            GROUP BY Preallocatestrategykey, UOM) PSTG ON STG.PreAllocateStrategykey =  PSTG.PreAllocateStrategykey
                                                   AND PSTG.UOM = PD.UOM
      WHERE Orderkey = @c_Orderkey
      GROUP BY PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Lot, PD.UOM, PD.Packkey,  
               PSTG.PreAllocateStrategykey, PSTG.PreAllocatePickCode, PD.DoCartonize, PD.PickMethod
          
   OPEN CUR_PICK
   
   FETCH NEXT FROM CUR_PICK INTO @c_orderlinenumber, @c_storerkey, @c_sku, @c_lot, @c_uom, @n_uomqty, @n_qty, @c_packkey,
                                 @c_preallocatestrategykey, @c_preallocatepickcode, @c_docartonize, @c_pickmethod

   WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 OR @n_continue = 2)
   BEGIN
    	DELETE FROM PICKDETAIL 
    	WHERE Orderkey = @c_Orderkey
    	AND OrderLineNumber = @c_orderlinenumber
    	AND Lot = @c_lot
    	AND UOM = @c_UOM
    	AND Packkey = @c_Packkey
    	AND docartonize = @c_docartonize
    	AND pickmethod = @c_pickmethod    	
    	
      SELECT @n_err = @@ERROR
	   	IF @n_err <> 0
	   	BEGIN
	   		 SELECT @n_continue = 3
				 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60096   
				 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Delete PICKDETAIL Table. (isp_RCM_UnAlloc2PreAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
				 GOTO ENDPROC
			END
						   			     	
   	  SELECT @b_success = 0  
      EXECUTE nspg_getkey 'PreAllocatePickDetailKey', 10, @c_PreAllocatePickDetailKey OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT  
      IF @b_success = 1  
      BEGIN            	
 	       SELECT @b_success = 0  
         EXECUTE  nspg_getkey 'PREOPRUN', 9, @c_oprun OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT  

         IF @b_success = 1  
         BEGIN  
            INSERT INTO #TMP_PREALLOCATEPICKDETAIL (PreAllocatePickDetailKey, OrderKey, OrderLineNumber, PreAllocateStrategyKey,  
                                           PreAllocatePickCode, Lot, StorerKey, Sku, Qty, UOMQty, UOM, PackKey, DOCartonize, Runkey, PickMethod)                                          
            VALUES  (@c_PreAllocatePickDetailKey, @c_orderkey, @c_OrderLineNumber, @c_PreAllocateStrategyKey, @c_PreAllocatePickCode,  
                     @c_lot, @c_StorerKey, @c_sku, @n_qty, @n_uomqty, @c_uom, @c_PackKey, @c_docartonize, @c_oprun, @c_pickmethod)  

            SELECT @n_err = @@ERROR
	   	      IF @n_err <> 0
	   	      BEGIN
	   	      	 SELECT @n_continue = 3
			      	 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60097   
			      	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert PreAllocatePickDetail Table. (isp_RCM_UnAlloc2PreAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			      	 GOTO ENDPROC
			      END			      
         END
         ELSE         
            SELECT @n_continue = 3, @n_err = 60098, @c_errmsg = 'isp_RCM_UnAlloc2PreAlloc ' + rtrim(@c_errmsg)

      END
      ELSE
         SELECT @n_continue = 3, @n_err = 60099, @c_errmsg = 'isp_RCM_UnAlloc2PreAlloc ' + rtrim(@c_errmsg)
   	  
      FETCH NEXT FROM CUR_PICK INTO @c_orderlinenumber, @c_storerkey, @c_sku, @c_lot, @c_uom, @n_uomqty, @n_qty, @c_packkey,
                                    @c_preallocatestrategykey, @c_preallocatepickcode, @c_docartonize, @c_pickmethod
   END
   CLOSE CUR_PICK
   DEALLOCATE CUR_PICK       
   
   UPDATE ORDERS WITH (ROWLOCK)
   SET SOStatus = 'CANC'
   WHERE Orderkey = @c_Orderkey
   
   SELECT @n_err = @@ERROR
	 IF @n_err <> 0
	 BEGIN
	 	 SELECT @n_continue = 3
	 	 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60100   
	 	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ORDERS Table. (isp_RCM_UnAlloc2PreAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
	 	 GOTO ENDPROC
	 END
	 
	 INSERT INTO PREALLOCATEPICKDETAIL (PreAllocatePickDetailKey, OrderKey, OrderLineNumber, PreAllocateStrategyKey,  
                                      PreAllocatePickCode, Lot, StorerKey, Sku, Qty, UOMQty, UOM, PackKey, DOCartonize, Runkey, PickMethod)
   SELECT PreAllocatePickDetailKey, OrderKey, OrderLineNumber, PreAllocateStrategyKey,  
          PreAllocatePickCode, Lot, StorerKey, Sku, Qty, UOMQty, UOM, PackKey, DOCartonize, Runkey, PickMethod
   FROM #TMP_PREALLOCATEPICKDETAIL    	 

   SELECT @n_err = @@ERROR
	 IF @n_err <> 0
	 BEGIN
	 	 SELECT @n_continue = 3
	 	 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60101   
	 	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert PREALLOCATEPICKDETAIL Table. (isp_RCM_UnAlloc2PreAlloc)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
	 	 GOTO ENDPROC
	 END
   
ENDPROC: 
 
   IF @n_continue=3  -- Error Occured - Process And Return
	 BEGIN
	    SELECT @b_success = 0
	    IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
	    BEGIN
	       ROLLBACK TRAN
	    END
	 ELSE
	    BEGIN
	       WHILE @@TRANCOUNT > @n_starttcnt
 	      BEGIN
	          COMMIT TRAN
	       END
	    END
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_UnAlloc2PreAlloc'
	    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
	    RETURN
	 END
	 ELSE
	    BEGIN
	       SELECT @b_success = 1
	       WHILE @@TRANCOUNT > @n_starttcnt
	       BEGIN
	          COMMIT TRAN
	       END
	       RETURN
	    END	   
END -- End PROC

GO