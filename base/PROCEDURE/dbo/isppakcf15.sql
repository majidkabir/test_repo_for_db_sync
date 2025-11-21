SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPAKCF15                                            */
/* Creation Date: 24-Nov-2020                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-15748 - [TW] Specialized Bike - Update SerialNo from       */ 
/*                      PackSerialNo during Pack Confirm                   */
/*                                                                         */
/* Called By: PostPackConfirmSP                                            */
/*                                                                         */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[ispPAKCF15]  
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
         , @n_Qty             INT
         , @c_SerialNoKey     NVARCHAR(10)
         , @c_SQL             NVARCHAR(MAX)
         , @c_CartonNo        NVARCHAR(10)
   
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug  = 0 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   IF @@TRANCOUNT = 0
      BEGIN TRAN
                           
   DECLARE cur_ORDLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT O.Orderkey, OD.OrderLineNumber, OD.Storerkey, OD.Sku, SUM(PD.Qty) AS Qty
   FROM PACKHEADER PH (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey      
   JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku      
   JOIN PICKDETAIL PD (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
                              AND OD.SKU = PD.SKU
   WHERE PH.Pickslipno = @c_Pickslipno
   AND SKU.SerialNoCapture IN ('1','3')
   AND EXISTS(SELECT 1 FROM SERIALNO SN (NOLOCK)
              JOIN PackSerialNo PSN (NOLOCK) ON SN.SerialNo = PSN.SerialNo AND SN.StorerKey = PSN.StorerKey 
                                            AND SN.SKU = PSN.SKU
              WHERE SN.Storerkey = SKU.Storerkey
              AND SN.Sku = SKU.Sku AND PSN.PickSlipNo = PH.PickSlipNo)
   GROUP BY O.Orderkey, OD.OrderLineNumber, OD.Storerkey, OD.Sku
   ORDER BY OD.Sku, OD.OrderLineNumber
   
   OPEN cur_ORDLINE  
          
   FETCH NEXT FROM cur_ORDLINE INTO @C_Orderkey, @c_OrderLineNumber, @c_Storerkey, @c_Sku, @n_Qty
          
   WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
   BEGIN    
      IF @b_Debug = 1
      BEGIN
         SELECT  '@c_Orderkey=' + RTRIM(@C_Orderkey), '@c_OrderLineNumber='+RTRIM(@c_OrderLineNumber), 
                 '@c_Storerkey=' + RTRIM(@c_Storerkey), '@c_Sku=' + RTRIM(@c_Sku), '@c_CartonNo=' + RTRIM(@c_CartonNo), 
                 '@n_Qty=' + CAST(@n_Qty AS NVARCHAR)
      END
     	      	   	
      SET @c_SQL = ' 
   	    DECLARE cur_SERIALNO CURSOR FAST_FORWARD READ_ONLY FOR 
   	    SELECT TOP ' + RTRIM(CAST(@n_Qty AS NVARCHAR)) + ' SN.SerialNokey
   	    FROM SERIALNO SN (NOLOCK)
   	    JOIN PackSerialNo PSN (NOLOCK) ON SN.SerialNo = PSN.SerialNo AND SN.StorerKey = PSN.StorerKey 
                                        AND SN.SKU = PSN.SKU
   	    WHERE PSN.Pickslipno = @c_PickSlipNo
   	    AND SN.Storerkey = @c_Storerkey
   	    AND SN.Sku = @c_Sku
   	    AND SN.Orderkey = '''' AND SN.OrderLineNumber = '''' AND SN.Pickslipno = ''''
   	    ORDER BY SN.SerialNokey '

      EXEC sp_executesql @c_SQL,
         N'@c_PickSlipNo NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20)',--, @c_CartonNo NVARCHAR(10)', 
         @c_PickSlipNo,
         @c_Storerkey,
         @c_Sku--,
         --@c_CartonNo
         
      IF @b_Debug = 1
         PRINT @c_SQL         
   	    
      OPEN cur_SERIALNO  

      FETCH NEXT FROM cur_SERIALNO INTO @c_SerialNoKey
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT '@c_SerialNoKey=' + RTRIM(@c_SerialNoKey) 
         END

         UPDATE SERIALNO WITH (ROWLOCK)
         SET Orderkey        = @c_Orderkey,
             OrderLineNumber = @c_OrderLineNumber,
             Pickslipno      = @c_PickSlipNo
         WHERE SerialNokey   = @c_SerialNokey

         SET @n_Err = @@ERROR
                             
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3 
            SELECT @n_Err = 38020
            SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update SERIALNO Table Failed. (ispPAKCF15)'
         END                               	          	  
      	  
         FETCH NEXT FROM cur_SERIALNO INTO @c_SerialNoKey
      END
      CLOSE cur_SERIALNO
      DEALLOCATE cur_SERIALNO      	       	       	 
   	 
      FETCH NEXT FROM cur_ORDLINE INTO @C_Orderkey, @c_OrderLineNumber, @c_Storerkey, @c_Sku, @n_Qty
   END
   
   DECLARE cur_CartonNo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PD.Pickslipno, PD.SKU, PD.CartonNo, 
          (SELECT SUM(PAD.Qty) FROM PACKDETAIL PAD (NOLOCK) WHERE PAD.PickSlipNo = PD.Pickslipno AND PAD.CartonNo = PD.CartonNo AND PAD.SKU = PD.SKU) AS Qty
   FROM PACKDETAIL PD (NOLOCK)
   JOIN PackSerialNo PSN (NOLOCK) ON PD.PickSlipNo = PSN.PickSlipNo AND PD.CartonNo = PSN.CartonNo 
                                 AND PD.LabelNo = PSN.LabelNo AND PD.LabelLine = PSN.LabelLine
   WHERE PD.Pickslipno = @c_Pickslipno
   GROUP BY PD.Pickslipno, PD.SKU, PD.CartonNo
   ORDER BY PD.SKU, PD.CartonNo
      
   OPEN cur_CartonNo  
          
   FETCH NEXT FROM cur_CartonNo INTO @c_Pickslipno, @c_Sku, @c_CartonNo, @n_Qty
          
   WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
   BEGIN     	   	
      SET @c_SQL = ' 
          DECLARE cur_SERIALNO CURSOR FAST_FORWARD READ_ONLY FOR 
          SELECT TOP ' + RTRIM(CAST(@n_Qty AS NVARCHAR)) + ' SN.SerialNokey
          FROM SERIALNO SN (NOLOCK)
          JOIN PackSerialNo PSN (NOLOCK) ON SN.SerialNo = PSN.SerialNo AND SN.StorerKey = PSN.StorerKey 
                                        AND SN.SKU = PSN.SKU
          WHERE PSN.Pickslipno = @c_PickSlipNo
          AND SN.Storerkey = @c_Storerkey
          AND SN.Sku = @c_Sku
          AND PSN.CartonNo = @c_CartonNo
          ORDER BY SN.SerialNokey '

      EXEC sp_executesql @c_SQL,
         N'@c_PickSlipNo NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_CartonNo NVARCHAR(10)', 
         @c_PickSlipNo,
         @c_Storerkey,
         @c_Sku,
         @c_CartonNo
         
      IF @b_Debug = 1
         PRINT @c_SQL         
   	    
      OPEN cur_SERIALNO  

      FETCH NEXT FROM cur_SERIALNO INTO @c_SerialNoKey
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            SELECT '@c_SerialNoKey=' + RTRIM(@c_SerialNoKey) 
         END

         UPDATE SERIALNO WITH (ROWLOCK)
         SET CartonNo      = @c_CartonNo
         WHERE SerialNokey = @c_SerialNokey

         SET @n_Err = @@ERROR
                             
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3 
            SELECT @n_Err = 38030
            SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update SERIALNO Table Failed. (ispPAKCF15)'
         END                               	          	  
      	  
            FETCH NEXT FROM cur_SERIALNO INTO @c_SerialNoKey
      END
      CLOSE cur_SERIALNO
      DEALLOCATE cur_SERIALNO      	       	       	 
   	 
      FETCH NEXT FROM cur_CartonNo INTO @c_Pickslipno, @c_Sku, @c_CartonNo, @n_Qty
   END

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'cur_ORDLINE') IN (0 , 1)
   BEGIN
      CLOSE cur_ORDLINE
      DEALLOCATE cur_ORDLINE   
   END
   
   IF CURSOR_STATUS('LOCAL', 'cur_CartonNo') IN (0 , 1)
   BEGIN
      CLOSE cur_CartonNo
      DEALLOCATE cur_CartonNo   
   END
   
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF15'
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