SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispASNFZ08                                            */
/* Creation Date: 27-JUN-2016                                              */
/* Copyright: LF                                                           */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: SOS#372360 - TH-MFG Order allocate upon ASN finalize           */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/* 2020-02-03  Wan01    1.1   Dead Lock Fixed.Loadplan generate PO/ASN. It */
/*                            could create multi ASN. When finalize ASNs   */
/*                            with same loadkey and trigger Load Allocation*/
/*                            same time, dead lock occurs                  */
/***************************************************************************/  
CREATE PROC [dbo].[ispASNFZ08]  
(     @c_Receiptkey  NVARCHAR(10)   
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
  ,   @c_ReceiptLineNumber NVARCHAR(5)=''
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_Continue INT,
           @n_StartTranCount INT,
           @c_Loadkey NVARCHAR(10),
           @c_Userdefine01 NVARCHAR(30),
           @c_Storerkey NVARCHAR(15),
           @c_Sku NVARCHAR(20), 
           @c_ExternPokey NVARCHAR(18), 
           @c_ExternOrderkey NVARCHAR(18),
           @c_Orderkey NVARCHAR(10), 
           @n_QtyReceived INT,
           @c_Pokey NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5),
           @n_OriginalQty INT

   DECLARE  @CUR_ORD CURSOR      --(Wan01) 
   
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT  

   IF OBJECT_ID('tempdb..#ALLOC_ORDER','u') IS NOT NULL
   BEGIN
      DROP TABLE #ALLOC_ORDER;
   END
   
   CREATE TABLE #ALLOC_ORDER
      (  RowID       INT            NOT NULL IDENTITY(1,1)
      ,  Orderkey    NVARCHAR(10)   NOT NULL DEFAULT('')
      ) 

   IF @n_continue IN (1,2)
   BEGIN
      SELECT TOP 1 @c_Loadkey = RD.Lottable01
      FROM RECEIPTDETAIL RD (NOLOCK) 
      JOIN LOADPLAN LP (NOLOCK) ON RD.Lottable01 = LP.Loadkey
      WHERE RD.Receiptkey = @c_Receiptkey
      AND RD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' THEN @c_ReceiptLineNumber ELSE RD.ReceiptLineNumber END
            
      IF ISNULL(@c_Loadkey,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63500
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid loadkey at RECEIPTDETAIL.Lottable01 (ispASNFZ08)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP          
      END
      
      UPDATE RECEIPT WITH (ROWLOCK)
      SET Loadkey = @c_Loadkey
         ,TrafficCop = NULL
      WHERE Receiptkey = @c_Receiptkey          

      SELECT @n_err = @@ERROR
      IF  @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63510
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update RECEIPT Table Failed! (ispASNFZ08)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP                                
      END
      
      DECLARE CUR_RECEIPTDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT RD.Storerkey, RD.Sku, RD.Lottable01 AS Loadkey, RD.Lottable02 As ExternOrderky, RD.Lottable03 As ExternPokey, RD.Userdefine10 AS Orderkey, RD.Pokey,
                SUM(RD.QtyReceived) AS QtyReceived
           FROM RECEIPTDETAIL RD (NOLOCK)            
           WHERE RD.Receiptkey = @c_Receiptkey
         AND RD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' THEN @c_ReceiptLineNumber ELSE RD.ReceiptLineNumber END
         GROUP BY  RD.Storerkey, RD.Sku, RD.Lottable01, RD.Lottable02, RD.Lottable03, RD.Userdefine10, RD.Pokey      

      OPEN CUR_RECEIPTDETAIL  
      FETCH NEXT FROM CUR_RECEIPTDETAIL INTO  @c_Storerkey, @c_Sku, @c_Loadkey, @c_ExternOrderkey, @c_ExternPokey, @c_Orderkey, @c_Pokey, @n_QtyReceived

      WHILE @@FETCH_STATUS = 0  
      BEGIN   
         SET @c_OrderLineNumber = ''
         SET @n_OriginalQty = 0

         SELECT @c_Orderkey = O.Orderkey, @c_OrderLineNumber = MIN(OD.OrderLineNumber), @n_OriginalQty = SUM(OD.OriginalQty)
         FROM ORDERS O (NOLOCK) 
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         WHERE O.ExternOrderkey = @c_ExternOrderkey
         --AND O.Orderkey = @c_Orderkey
         AND O.Loadkey = @c_Loadkey
         AND O.Storerkey = @c_Storerkey
         AND OD.Sku = @c_Sku
         GROUP BY O.Orderkey
         HAVING SUM(OD.OriginalQty) < @n_QtyReceived

         IF ISNULL(@c_OrderLineNUmber,'') <> ''
         BEGIN
            UPDATE ORDERDETAIL WITH (ROWLOCK)
            SET OriginalQty = OriginalQty + (@n_QtyReceived - @n_OriginalQty),
              OpenQty = OpenQty + (@n_QtyReceived - @n_OriginalQty)
            WHERE Orderkey = @c_Orderkey
            AND OrderLineNumber = @c_OrderLineNumber
            AND Storerkey = @c_Storerkey
            AND Sku = @c_Sku    

            SELECT @n_err = @@ERROR
            IF  @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63520
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update ORDERDETAIL Table Failed! (ispASNFZ08)' + ' ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO QUIT_SP                                
            END
         END   

         --(Wan01) - START
         IF @c_Orderkey <> '' AND @c_Orderkey IS NOT NULL
         BEGIN
            IF NOT EXISTS( SELECT 1 
                           FROM #ALLOC_ORDER
                           WHERE Orderkey = @c_Orderkey
                         )
            BEGIN                             
               INSERT INTO #ALLOC_ORDER (Orderkey)
               VALUES (@c_Orderkey)               
            END  
         END   
         --(Wan01) - END               
                           
         FETCH NEXT FROM CUR_RECEIPTDETAIL INTO  @c_Storerkey, @c_Sku, @c_Loadkey, @c_ExternOrderkey, @c_ExternPokey, @c_Orderkey, @c_Pokey, @n_QtyReceived
      END
      CLOSE CUR_RECEIPTDETAIL  
      DEALLOCATE CUR_RECEIPTDETAIL                                                 
        
      --(Wan01) - START
      --Allocate by Orderkey to avaoid dead lock when 1 loadkey from multi ASN finalize and loadkey allocation at same time 
      
      --EXEC nsp_orderprocessing_wrapper '',@c_Loadkey, 'N','N', '', 'LP' 
      SET @CUR_ORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT Orderkey 
      FROM #ALLOC_ORDER         
      ORDER BY RowID

      OPEN @CUR_ORD  
      FETCH NEXT FROM @CUR_ORD INTO  @c_Orderkey 

      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         EXEC nsp_orderprocessing_wrapper @c_Orderkey,'', 'Y','N', '', ''
         
         IF @@ERROR <> ''
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(char(250),@n_err)
            SET @n_err = 63530
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Allocate Load''s order fail! (ispASNFZ08)' + ' ( '
                         + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP             
         END
         
         FETCH NEXT FROM @CUR_ORD INTO  @c_Orderkey          
      END
      CLOSE @CUR_ORD
      DEALLOCATE @CUR_ORD      
      --(Wan01) - END       
   END
   
   QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispASNFZ08'
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