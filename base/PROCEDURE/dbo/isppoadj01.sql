SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispPOADJ01                                                  */
/* Creation Date: 09-May-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-1884 - CN DYSON post finalize adj update serial#        */      
/*        : builder                                                     */
/* Called By: ispPreFinalizeADJWrapper                                  */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispPOADJ01] 
            @c_AdjustmentKey  NVARCHAR(10)
         ,  @b_Success        INT = 1  OUTPUT 
         ,  @n_err            INT = 0  OUTPUT 
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt            INT
         , @n_Continue             INT 
         , @c_Userdefine01         NVARCHAR(50)        
         , @c_Storerkey            NVARCHAR(15)
         , @c_Sku                  NVARCHAR(20)
         , @c_SerialNoKey          NVARCHAR(10)
         , @n_Qty                  INT
         , @c_ID                   NVARCHAR(18)
         , @c_AdjustmentLineNumber NVARCHAR(5)
         , @c_Sourcekey            NVARCHAR(20)
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_AD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT ADJD.Storerkey, ADJD.Sku, ADJD.Qty, ADJD.Userdefine01, ADJD.Id, ADJD.AdjustmentLineNumber
      FROM ADJUSTMENTDETAIL ADJD (NOLOCK)
      JOIN SKU (NOLOCK) ON ADJD.Storerkey = SKU.Storerkey AND ADJD.Sku = SKU.Sku
      WHERE ADJD.Adjustmentkey = @c_AdjustmentKey
      AND ADJD.Finalizedflag = 'Y'
      AND ADJD.Qty <> 0
      AND SKU.SerialNoCapture = '1'
      AND ISNULL(ADJD.Userdefine01,'') <> ''
      GROUP BY ADJD.Storerkey, ADJD.Sku, ADJD.Qty, ADJD.Userdefine01, ADJD.AdjustmentLineNumber, ADJD.Id
      
      OPEN CUR_AD
      
      FETCH NEXT FROM CUR_AD INTO @c_Storerkey, @c_Sku, @n_Qty, @c_Userdefine01, @c_ID, @c_AdjustmentLineNumber
                                  
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN      	
      	 IF @n_Qty > 0 
      	 BEGIN
         	 	IF EXISTS (SELECT 1 FROM SERIALNO (NOLOCK) WHERE Storerkey = @c_Storerkey AND Sku = @c_Sku AND Serialno = @c_Userdefine01)
         	 	BEGIN
      	 	     UPDATE SERIALNO WITH (ROWLOCK)
      	 	     SET Status = '1'
      	 	     WHERE Storerkey = @c_Storerkey
      	 	     AND Sku = @c_Sku
      	 	     AND SerialNo = @c_Userdefine01      	 	
      	 	                	 	   
               SET @n_err = @@ERROR
               
               IF @n_err <> 0 
               BEGIN 
                  SET @n_continue= 3 
                  SET @n_err  = 72810
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Update SERIALNO Table Failed. (ispPOADJ01)'
                                + '( ' + RTRIM(@c_errmsg) + ' )'
               END       	    
         	 	END
         	 	ELSE
         	 	BEGIN
               EXECUTE nspg_GetKey 
                       @KeyName     = 'SERIALNO'
                     , @fieldlength = 10
                     , @keystring   = @c_SerialNoKey  OUTPUT
                     , @b_success   = @b_success     OUTPUT
                     , @n_err       = @n_err         OUTPUT
                     , @c_errmsg    = @c_errmsg      OUTPUT
                     , @b_resultset = 0
                     , @n_batch     = 1
               
               IF @b_success <> 1
               BEGIN 
                  SET @n_continue= 3 
                  SET @n_err  = 72800
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Generate SerialNoKey Failed. (ispPOADJ01)'
                                + '( ' + RTRIM(@c_errmsg) + ' )'
               END       
         	 	
      	       INSERT INTO SERIALNO (SerialNoKey, Orderkey, OrderLineNumber, Storerkey, Sku, SerialNo, Qty, Status, Id)
      	       VALUES (@c_SerialNoKey, '', '', @c_Storerkey, @c_Sku, @c_Userdefine01, @n_Qty, '1', @c_ID)
               
               SET @n_err = @@ERROR
               
               IF @n_err <> 0 
               BEGIN 
                  SET @n_continue= 3 
                  SET @n_err  = 72820
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Insert SERIALNO Table Failed. (ispPOADJ01)'
                                + '( ' + RTRIM(@c_errmsg) + ' )'
               END  
            END     	              
      	 END 
      	 ELSE
      	 BEGIN
      	 	  UPDATE SERIALNO WITH (ROWLOCK)
      	 	  SET Status = 'CANC'
      	 	  WHERE Storerkey = @c_Storerkey
      	 	  AND Sku = @c_Sku
      	 	  AND SerialNo = @c_Userdefine01      	 	  

            SET @n_err = @@ERROR
            
            IF @n_err <> 0 
            BEGIN 
               SET @n_continue= 3 
               SET @n_err  = 72830
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Update SERIALNO Table Failed. (ispPOADJ01)'
                             + '( ' + RTRIM(@c_errmsg) + ' )'
            END       	                
      	 END
      	 
      	 IF @n_Continue IN(1,2)
         BEGIN            	 
         	  SET @c_Sourcekey = RTRIM(@c_AdjustmentKey) + RTRIM(@c_AdjustmentLineNumber)
            
            EXEC ispITrnSerialNoAdjustment 
                 @c_TranType   = 'AJ'
                ,@c_StorerKey  = @c_Storerkey  
                ,@c_SKU        = @c_Sku
                ,@c_SerialNo   = @c_Userdefine01
                ,@n_QTY        = @n_Qty
                ,@c_SourceKey  = @c_Sourcekey
                ,@c_SourceType =  'ispPOADJ01'
                ,@b_Success    = @b_Success OUTPUT  
                ,@n_Err        = @n_err OUTPUT  
                ,@c_ErrMsg     = @c_errmsg OUTPUT

            IF @b_Success <> 1 
            BEGIN 
               SET @n_continue= 3 
               SET @n_err  = 72825
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Insert ITrnSerialNo Table Failed. (ispPOADJ01)'
                             + '( ' + RTRIM(@c_errmsg) + ' )'
            END                     
         END                                  
      	 
         FETCH NEXT FROM CUR_AD INTO @c_Storerkey, @c_Sku, @n_Qty, @c_Userdefine01, @c_ID, @c_AdjustmentLineNumber
      END
      CLOSE CUR_AD
      DEALLOCATE CUR_AD    
   END
   
   QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_AD') in (0 , 1)  
   BEGIN
      CLOSE CUR_AD
      DEALLOCATE CUR_AD
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPOADJ01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO