SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: ispPREWO01                                            */  
/* Creation Date: 21-SEP-2017                                              */  
/* Copyright: LFL                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: WMS-2933 CN BeamSuntory Split uncomplete qty to new work order */                                 
/*                                                                         */  
/* Called By:                                                              */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 1.0                                                       */  
/*                                                                         */  
/* Version: 7.0                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date       Ver  Author   Purposes                                       */  
/***************************************************************************/    
CREATE PROC [dbo].[ispPREWO01]    
(     @c_WorkOrderKey NVARCHAR(10)     
  ,   @b_Success      INT           OUTPUT  
  ,   @n_Err          INT           OUTPUT  
  ,   @c_ErrMsg       NVARCHAR(255) OUTPUT     
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_Continue               INT   
         , @n_StartTCount            INT    
         , @c_NewWorkOrderKey        NVARCHAR(10)
         , @n_WorkOrderLineCnt       INT
         , @c_NewWorkOrderLineNumber NVARCHAR(5)
         , @c_WorkOrderLineNumber    NVARCHAR(10)
         , @n_Qty                    INT
         , @c_WkOrdUdef1             NVARCHAR(18)
         , @n_RemainQty              INT

   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''   
   SET @n_Continue = 1    
   SET @n_StartTCount = @@TRANCOUNT
   SET @n_WorkOrderLineCnt = 0
   
   IF @n_continue IN(1,2)
   BEGIN
   	  IF EXISTS(SELECT 1 FROM WORKORDERDETAIL (NOLOCK) WHERE Workorderkey = @c_WorkOrderkey AND ISNULL(WkOrdUdef4,'') <> '')
   	  BEGIN
   	  	 SELECT @n_continue = 4
   	     GOTO QUIT_SP
   	  END
   	  
   	  IF EXISTS (SELECT 1 FROM WORKORDERDETAIL (NOLOCK) WHERE Workorderkey = @c_WorkOrderkey AND ISNUMERIC(WkOrdUdef1) <> 1)
   	  BEGIN
         SET @n_continue = 3      
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 82010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Qty In WkOrdUdef01. (ispPREWO01)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '         	  	
   	  END
   END

   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_WORKORDERDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT WorkOrderLineNumber, Qty, WkOrdUdef1 
         FROM WORKORDERDETAIL(NOLOCK)
         WHERE Workorderkey = @c_WorkOrderkey
         AND CONVERT(DECIMAL, WkOrdUdef1) - Qty > 0
         ORDER BY WorkOrderLineNumber
      OPEN CUR_WORKORDERDETAIL   
      
      FETCH NEXT FROM CUR_WORKORDERDETAIL INTO @c_WorkOrderLineNumber, @n_Qty, @c_WkOrdUdef1
      
      --Create work order
      IF @@FETCH_STATUS <> -1
      BEGIN
         SET @b_success = 1	  
         EXECUTE nspg_GetKey
                'WorkOrder                     '
               ,10 
               ,@c_NewWorkOrderKey OUTPUT 
               ,@b_success         OUTPUT 
               ,@n_err             OUTPUT 
               ,@c_errmsg          OUTPUT
         
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            GOTO QUIT_SP
         END
         ELSE
         BEGIN
            INSERT INTO WorkOrder
            (
            	WorkOrderKey,
            	ExternWorkOrderKey,
            	StorerKey,
            	Facility,
            	[Status],
            	ExternStatus,
            	[Type],
            	Reason,
            	TotalPrice,
            	GenerateCharges,
            	Remarks,
            	Notes1,
            	Notes2,
            	WkOrdUdef1,
            	WkOrdUdef2,
            	WkOrdUdef3,
            	WkOrdUdef4,
            	WkOrdUdef5,
            	WkOrdUdef6,
            	WkOrdUdef7,
            	WkOrdUdef8,
            	WkOrdUdef9,
            	WkOrdUdef10
            )      	
           SELECT @c_NewWorkOrderkey,
            	     ExternWorkOrderKey,
            	     StorerKey,
            	     Facility,
            	     '0',
            	     ExternStatus,
            	     [Type],
            	     Reason,
            	     TotalPrice,
            	     GenerateCharges,
            	     Remarks,
            	     Notes1,
            	     Notes2,
            	     WkOrdUdef1,
            	     WkOrdUdef2,
            	     WkOrdUdef3,
            	     WkOrdUdef4,
            	     WkOrdUdef5,
            	     WkOrdUdef6,
            	     WkOrdUdef7,
            	     WkOrdUdef8,
            	     WkOrdUdef9, 
            	     @c_WorkOrderkey --original workorderkey
            FROM WORKORDER (NOLOCK)
            WHERE WorkOrderkey = @c_WorkOrderkey	           	

            SELECT @n_err = @@ERROR
            IF  @n_err <> 0
            BEGIN            
               SET @n_continue = 3      
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
               SET @n_err = 82020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert WORKORDER Table Failed!. (ispPREWO01)'   
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '         	  	
            END   
         END
      END

      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)             
      BEGIN
    	   SET @n_WorkOrderLineCnt = @n_WorkOrderLineCnt + 1	
       	 SET @c_NewWorkOrderLineNumber = RIGHT('00000'+RTRIM(LTRIM(CAST(@n_WorkOrderLineCnt AS NVARCHAR))),5)
       	 SET @n_RemainQty = CONVERT(DECIMAL, @c_WkOrdUdef1) - @n_Qty       	

      	 INSERT INTO WorkOrderDetail
         (
         	WorkOrderKey,
         	WorkOrderLineNumber,
         	ExternWorkOrderKey,
         	ExternLineNo,
         	[Type],
         	Reason,
         	Unit,
         	Qty,
         	Price,
         	LineValue,
         	Remarks,
         	WkOrdUdef1,
         	WkOrdUdef2,
         	WkOrdUdef3,
         	WkOrdUdef4,
         	WkOrdUdef5,
         	[Status],
         	StorerKey,
         	Sku,
         	WkOrdUdef6,
         	WkOrdUdef7,
         	WkOrdUdef8,
         	WkOrdUdef9,
         	WkOrdUdef10
         )
          SELECT @c_NewWorkOrderkey,
         	       @c_NewWorkOrderLineNumber,
         	       ExternWorkOrderKey,
         	       ExternLineNo,
         	       [Type],
         	       Reason,
         	       Unit,
         	       @n_RemainQty,
         	       Price,
         	       LineValue,
         	       Remarks,
         	       CAST(@n_RemainQty AS NVARCHAR),
         	       WkOrdUdef2,
         	       WkOrdUdef3,
         	       WkOrdUdef4,
         	       WkOrdUdef5,
         	       '0',
         	       StorerKey,
         	       Sku,
         	       WkOrdUdef6,
         	       WkOrdUdef7,
         	       WkOrdUdef8,
         	       WkOrdUdef9,
         	       WkOrdUdef10
            FROM WORKORDERDETAIL(NOLOCK)
            WHERE WorkOrderkey = @c_WorkOrderkey
            AND WorkOrderLineNUmber = @c_WorkOrderLineNumber

         SELECT @n_err = @@ERROR
         IF  @n_err <> 0
         BEGIN            
            SET @n_continue = 3      
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 82030  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert WORKORDERDETAIL Table Failed!. (ispPREWO01)'   
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '         	  	
         END   
               	       	         
         FETCH NEXT FROM CUR_WORKORDERDETAIL INTO @c_WorkOrderLineNumber, @n_Qty, @c_WkOrdUdef1
      END
      CLOSE CUR_WORKORDERDETAIL
      DEALLOCATE CUR_WORKORDERDETAIL               
   END    
    
   QUIT_SP:  

   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCount  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      Execute nsp_logerror @n_err, @c_errmsg, 'ispPREWO01'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         COMMIT TRAN  
      END   
  
      RETURN  
   END   
END 

GO