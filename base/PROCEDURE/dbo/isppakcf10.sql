SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPAKCF10                                            */
/* Creation Date: 27-Jun-2019                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-9237 TH Nuskin - Link serial number to lot/id              */
/*                                                                         */
/* Called By: PostPackConfirmSP                                            */
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
CREATE PROC [dbo].[ispPAKCF10]  
(     @c_PickSlipNo  NVARCHAR(10)   
  ,   @c_Storerkey   NVARCHAR(15)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug           INT
         , @n_Continue        INT 
         , @n_StartTCnt       INT 
 
   DECLARE @C_Orderkey        NVARCHAR(10)
         , @c_OrderLineNumber NVARCHAR(5)
         , @c_Sku             NVARCHAR(20)
         , @c_Lot             NVARCHAR(10)
         , @c_ID              NVARCHAR(18)
         , @n_Qty             INT
         , @c_SerialNoKey     NVARCHAR(10)
         , @c_SQL             NVARCHAR(MAX)
         , @c_Orderkey1sttime NVARCHAR(10)
   
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug  = 0 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   IF @@TRANCOUNT = 0
      BEGIN TRAN
                           
   DECLARE cur_ORDLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT O.Orderkey, OD.OrderLineNumber, OD.Storerkey, OD.Sku, PD.Lot, PD.ID, SUM(PD.Qty) AS Qty
   FROM PACKHEADER PH (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey      
   JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku      
   JOIN PICKDETAIL PD (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
   WHERE PH.Pickslipno = @c_Pickslipno
   AND SKU.SerialNoCapture IN ('1','3')
   AND EXISTS(SELECT 1 FROM SERIALNO SN (NOLOCK)
              WHERE SN.Orderkey = O.Orderkey
              AND SN.Storerkey = SKU.Storerkey
              AND SN.Sku = SKU.Sku)
   GROUP BY O.Orderkey, OD.OrderLineNumber, OD.Storerkey, OD.Sku, PD.Lot, PD.ID           
   ORDER BY OD.Sku, OD.OrderLineNumber, PD.Lot, PD.Id
   
   OPEN cur_ORDLINE  
          
   FETCH NEXT FROM cur_ORDLINE INTO @C_Orderkey, @c_OrderLineNumber, @c_Storerkey, @c_Sku, @c_Lot, @c_ID, @n_Qty

   IF @b_Debug = 1
   BEGIN
      SELECT  '@C_Orderke=' + RTRIM(@C_Orderkey), '@c_OrderLineNumber='+RTRIM(@c_OrderLineNumber), 
              '@c_Storerkey=' + RTRIM(@c_Storerkey), '@c_Sku=' + RTRIM(@c_Sku), '@c_Lot=' + RTRIM(@c_Lot), 
              '@c_ID=' + RTRIM(@c_ID), '@n_Qty=' + CAST(@n_Qty AS NVARCHAR)
   END
   
   SET @c_Orderkey1sttime = @c_Orderkey
          
   WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
   BEGIN      	      	   	
      IF ISNULL(@c_Orderkey1sttime,'') <> ''
      BEGIN
         UPDATE SERIALNO WITH (ROWLOCK)
      	  SET LotNo = ''
      	     ,ID = ''
      	  WHERE Orderkey = @c_Orderkey
      	  AND Storerkey = @c_Storerkey
      
         SET @n_Err = @@ERROR
                             
         IF @n_Err <> 0
         BEGIN
             SELECT @n_Continue = 3 
             SELECT @n_Err = 38010
             SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update SERIALNO Table Failed. (ispPAKCF10)'
         END                      
         
         SET @c_Orderkey1sttime = ''                  	 
      END
   	
      SET @c_SQL = ' 
   	    DECLARE cur_SERIALNO CURSOR FAST_FORWARD READ_ONLY FOR 
   	    SELECT TOP ' + RTRIM(CAST(@n_Qty AS NVARCHAR)) + ' SerialNokey
   	    FROM SERIALNO (NOLOCK)
   	    WHERE Orderkey = @c_Orderkey
   	    AND Storerkey = @c_Storerkey
   	    AND Sku = @c_Sku
   	    AND LotNo = ''''
   	    ORDER BY SerialNokey '

      EXEC sp_executesql @c_SQL,
         N'@c_Orderkey NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20)', 
         @c_Orderkey,
         @c_Storerkey,
         @c_Sku    
         
      IF @b_Debug = 1
         PRINT @c_SQL         

      OPEN cur_SERIALNO  

      FETCH NEXT FROM cur_SERIALNO INTO @c_SerialNoKey
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
      	  IF @b_Debug = 1
          BEGIN
             SELECT  '@c_SerialNoKey=' + RTRIM(@c_SerialNoKey) 
          END

      	  UPDATE SERIALNO WITH (ROWLOCK)
      	  SET OrderLineNumber = @c_OrderLineNumber
      	     ,LotNo = @c_Lot
      	     ,ID = @c_ID
      	  WHERE SerialNokey = @c_SerialNokey

         SET @n_Err = @@ERROR
                             
         IF @n_Err <> 0
         BEGIN
             SELECT @n_Continue = 3 
             SELECT @n_Err = 38020
             SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update SERIALNO Table Failed. (ispPAKCF10)'
         END                               	          	  
      	  
         FETCH NEXT FROM cur_SERIALNO INTO @c_SerialNoKey
      END
      CLOSE cur_SERIALNO
      DEALLOCATE cur_SERIALNO      	       	       	 
   	 
      FETCH NEXT FROM cur_ORDLINE INTO @C_Orderkey, @c_OrderLineNumber, @c_Storerkey, @c_Sku, @c_Lot, @c_ID, @n_Qty    
   END
   CLOSE cur_ORDLINE
   DEALLOCATE cur_ORDLINE
                           
    
   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF10'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END 
      RETURN
   END 
END

GO