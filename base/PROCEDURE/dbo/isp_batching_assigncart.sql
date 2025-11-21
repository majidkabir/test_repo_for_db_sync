SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: isp_Batching_AssignCart                               */
/* Creation Date: 20-Jan-2016                                              */
/* Copyright: LF                                                           */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: SOS#361158 - Assign cart device position to order and generate */
/*                       packheader for mode 1(Multi-S) 4(Multi-M)         */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[isp_Batching_AssignCart]  
(     @c_TaskBatchNo   NVARCHAR(10)   
  ,   @b_Success       INT           OUTPUT
  ,   @n_Err           INT           OUTPUT
  ,   @c_ErrMsg        NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_Continue INT,
           @n_StartTranCount INT,
           @c_Orderkey NVARCHAR(10),
           @c_Storerkey NVARCHAR(15),
           @c_DevicePosition NVARCHAR(10),
           @c_LogicalName NVARCHAR(10),
           @n_ordcnt INT          

   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT              

   SELECT @c_Storerkey = MAX(O.Storerkey),
  	      @n_ordcnt = COUNT(DISTINCT O.orderkey)
   FROM ORDERS O (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
   JOIN PACKTASK PT (NOLOCK) ON O.Orderkey = PT.Orderkey
   WHERE PT.TaskBatchNo = @c_TaskBatchNo
   AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) IN ('1','4') --1=Multi-S 4=Multi-M
   
   SELECT DevicePosition, 0 AS Status, LogicalName
   INTO #TMP_CartPosition
   FROM DEVICEPROFILE (NOLOCK)
   WHERE Devicetype = 'CART' 
   AND Priority = 'M' 
   AND Storerkey = @c_Storerkey
   
   IF (SELECT COUNT(DISTINCT DevicePosition) FROM #TMP_CartPosition) < @n_ordcnt
   BEGIN
      SET @n_continue = 3      
      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
      SET @n_err = 81010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insuffice Cart Device Position (isp_Batching_AssignCart)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
   END   
   	     
   IF @n_continue IN (1,2)
   BEGIN   	     	     	     	  
   	  DECLARE CUR_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	     SELECT DISTINCT O.Orderkey
   	     FROM ORDERS O (NOLOCK)
   	     JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
         JOIN PACKTASK PT (NOLOCK) ON O.Orderkey = PT.Orderkey
   	     WHERE PT.TaskBatchNo = @c_TaskBatchNo 
   	     AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) IN ('1','4')
   	     ORDER BY O.Orderkey

      OPEN CUR_ORDERS
      
      FETCH NEXT FROM CUR_ORDERS INTO @c_Orderkey

      WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN      	       	      	         
         SELECT TOP 1 @c_DevicePosition = DevicePosition,
                      @c_LogicalName = LogicalName
         FROM #TMP_CartPosition
         WHERE Status = 0
         ORDER BY LogicalName, DevicePosition
         
         UPDATE #TMP_CartPosition
         SET Status = Status + 1
         WHERE DevicePosition = @c_DevicePosition
         
         UPDATE PACKTASK 
         SET DevicePosition = @c_DevicePosition,
             LogicalName = @c_LogicalName
         WHERE Orderkey = @c_Orderkey
         AND TaskBatchNo = @c_TaskBatchNo     

         SET @n_err = @@ERROR      
         
         IF @n_err <> 0      
         BEGIN      
            SET @n_continue = 3      
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 81020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PACKHEADER Failed (isp_Batching_AssignCart)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
         END              	   
            
         FETCH NEXT FROM CUR_ORDERS INTO @c_Orderkey
      END	
      CLOSE CUR_ORDERS
      DEALLOCATE CUR_ORDERS        	    	       	     
   END
      
   QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_Batching_AssignCart'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN
   END 
END

GO