SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispORDD01                                          */
/* Creation Date: 07-May-2024                                           */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: UWP-18748 UK Demeter - JCB Unallocation restore orderdetail */   
/*          quantity from userdefine01                                  */
/*                                                                      */
/* Called By: isp_OrderdetailTrigger_Wrapper from Orderdetail Trigger   */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 2                                                           */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 2024-06-04  Wan01    1.1   UWP-18393-Unallocation for Mixed Sku Pallet*/
/* 2024-06-24  Wan02    1.1   UWP-18393-Fix                             */
/************************************************************************/
CREATE   PROC ispORDD01   
   @c_Action        NVARCHAR(10),
   @c_Storerkey     NVARCHAR(15),  
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue        INT,
           @n_StartTCnt       INT,
           @c_OrderKey        NVARCHAR(10), 
           @c_OrderLineNumber NVARCHAR(5), 
           @n_OpenQty         INT
         , @n_QtyAlloc        INT = 0                                               --(Wan02)
         , @c_OrdLineNo_Orig  NVARCHAR(5) = ''                                      --(Wan01)
                                                       
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END     

   IF @c_Action IN('UPDATE') 
   BEGIN
      IF EXISTS (SELECT  1
                  FROM #INSERTED I
                  JOIN #DELETED D ON I.Orderkey = D.Orderkey AND I.OrderLineNumber = D.OrderLineNumber
                  LEFT JOIN PICKDETAIL PD (NOLOCK) ON I.Orderkey = PD.Orderkey AND I.OrderLineNumber = PD.OrderLineNumber
                  WHERE I.Storerkey = @c_Storerkey
                  --AND I.QtyAllocated + I.QtyPicked = 0                            --(Wan02)
                  AND D.QtyAllocated + D.QtyPicked > I.QtyAllocated + I.QtyPicked   --(Wan02)
                  AND ISNUMERIC(I.Userdefine01) = 1
                  AND I.Status <> '9'
                  AND I.ShippedQty = 0
                  --AND I.OpenQty <> CAST(I.Userdefine01 AS INT)
                  )--AND PD.Orderkey IS NULL)                                       --(Wan02)              
      BEGIN
         DECLARE CUR_ORDLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT I.Orderkey, I.OrderLineNumber, CAST(I.Userdefine01 AS INT)
               ,OrdLineNo_Orig = CASE WHEN I.UserDefine02 = D.UserDefine02
                                      THEN I.UserDefine02 
                                      ELSE '' END
               ,QtyAlloc = I.QtyAllocated + I.QtyPicked                             --(Wan02)
         FROM #INSERTED I
         JOIN #DELETED D ON I.Orderkey = D.Orderkey AND I.OrderLineNumber = D.OrderLineNumber
         LEFT JOIN PICKDETAIL PD (NOLOCK) ON I.Orderkey = PD.Orderkey AND I.OrderLineNumber = PD.OrderLineNumber
         WHERE I.Storerkey = @c_Storerkey
         --AND  I.QtyAllocated + I.QtyPicked = 0                                    --(Wan02)
         AND D.QtyAllocated + D.QtyPicked > I.QtyAllocated + I.QtyPicked            --(Wan02)
         AND ISNUMERIC(I.Userdefine01) = 1
         AND I.ShippedQty = 0
         AND I.Status <> '9'
         --AND I.OpenQty <> CAST(I.Userdefine01 AS INT)
         --AND PD.Orderkey IS NULL                                                  --(Wan02)
            
         OPEN CUR_ORDLINE
      
         FETCH FROM CUR_ORDLINE INTO @c_OrderKey, @c_OrderLineNumber, @n_OpenQty
                                    ,@c_OrdLineNo_Orig, @n_QtyAlloc                 --(Wan01)
         
         WHILE @@FETCH_STATUS = 0 AND @n_Continue IN(1,2)
         BEGIN  
            IF @n_OpenQty = 0 AND @n_QtyAlloc = 0 AND LEN(@c_OrdLineNo_Orig) = 5    --(Wan01) - START   
            BEGIN
               DELETE ORDERDETAIL WITH (ROWLOCK)
               WHERE Orderkey = @c_Orderkey
               AND OrderLineNumber = @c_OrderLineNumber

               SET @n_err = @@ERROR

               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                  SET @n_err = 81030  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Orderdetail Failed. (ispORDD01)'
                              + '( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                                                            
               END 
            END
            ELSE
            BEGIN                                                                   --(WAN01) - END
               UPDATE ORDERDETAIL WITH (ROWLOCK)
               SET OpenQty = CASE WHEN @n_QtyAlloc < @n_OpenQty THEN @n_OpenQty ELSE @n_QtyAlloc END, --(Wan02)
                   Userdefine01 = CASE WHEN @n_QtyAlloc = 0 THEN '' ELSE Userdefine01  END            --(Wan02)
               WHERE Orderkey = @c_Orderkey
               AND OrderLineNumber = @c_OrderLineNumber
              
               SET @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                  SET @n_err = 81010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Orderdetail Failed. (ispORDD01)'
                              + '( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                                                            
               END         
            END

            IF @n_continue IN (1,2)                                                 --(Wan01)
            BEGIN 
               UPDATE ORDERS WITH (ROWLOCK)
               SET OpenQty = (SELECT SUM(OpenQty) FROM ORDERDETAIL(NOLOCK) WHERE Orderkey = @c_Orderkey)
                  ,Trafficcop = NULL
               WHERE Orderkey = @c_Orderkey
            
               SET @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                  SET @n_err = 81020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Orders Failed. (ispORDD01)'
                              + '( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                                                            
               END         
            END                                                                     --(Wan01)
            
            FETCH FROM CUR_ORDLINE INTO @c_OrderKey, @c_OrderLineNumber, @n_OpenQty
                                       ,@c_OrdLineNo_Orig, @n_QtyAlloc              --(Wan02)                           --(Wan01)
         END
         CLOSE CUR_ORDLINE
         DEALLOCATE CUR_ORDLINE                 
      END             
   END
                  
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORDD01'
      IF @c_Action IN('DELETE')       
         RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
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