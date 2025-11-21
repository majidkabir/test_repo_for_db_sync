SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RCM_ASN_ManualUpd                                   */
/* Creation Date: 17-APR-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4549 - SG MHD - Update Manual ASN from PO               */
/*        :                                                             */
/* Called By: Custom RCM Menu                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_RCM_ASN_ManualUpd]
      @c_Receiptkey  NVARCHAR(10)   
   ,  @b_success     INT OUTPUT
   ,  @n_err         INT OUTPUT
   ,  @c_errmsg      NVARCHAR(225) OUTPUT
   ,  @c_code        NVARCHAR(30)=''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

         , @c_RecType            NVARCHAR(10)
         , @c_ExternStatus       NVARCHAR(10)

         --, @n_SumQtyReceived     INT
         --, @n_TotalRDLines       INT
         , @n_NoOfRDSkuLot       INT

         --, @n_SumQtyOrdered      INT
         --, @n_TotalPOLines       INT
         , @n_NoOfPOSkuLot       INT

         , @c_ReceiptLineNumber  NVARCHAR(5)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @c_Lottable03         NVARCHAR(18)
         , @n_QtyReceived        INT
         , @c_ExternReceiptKey   NVARCHAR(30)

         , @c_POkey              NVARCHAR(10)
         , @c_SellerName         NVARCHAR(30)
         , @c_SellerAddress1     NVARCHAR(30)
         , @c_SellerAddress2     NVARCHAR(30)
         , @c_UserDefine01       NVARCHAR(30)
         , @c_UserDefine02       NVARCHAR(30)
         , @c_UserDefine03       NVARCHAR(30)
         , @c_UserDefine04       NVARCHAR(30)
         , @c_UserDefine05       NVARCHAR(30)
         , @dt_UserDefine06      DATETIME    
         , @dt_UserDefine07      DATETIME    
         , @c_UserDefine08       NVARCHAR(30)
         , @c_UserDefine09       NVARCHAR(30)
         , @c_UserDefine10       NVARCHAR(30)
         , @c_POStatus           NVARCHAR(10)

         , @c_POLineNumber       NVARCHAR(5)
         , @c_ExternLineNo       NVARCHAR(20)
         , @n_QtyOrdered         INT

         , @c_transmitlogkey     NVARCHAR(10)
  
         , @CUR_RD               CURSOR
         , @CUR_CHECK            CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_POkey          = ''    
   SET @c_SellerName     = ''
   SET @c_SellerAddress1 = ''
   SET @c_SellerAddress2 = ''
   SET @c_UserDefine01   = ''
   SET @c_UserDefine02   = ''
   SET @c_UserDefine03   = ''
   SET @c_UserDefine04   = ''
   SET @c_UserDefine05   = ''
   SET @c_UserDefine08   = ''
   SET @c_UserDefine09   = ''
   SET @c_UserDefine10   = ''

   SELECT @c_RecType = RH.RecType
         ,@c_ExternReceiptKey = ISNULL(RTRIM(RH.ExternReceiptkey),'')
         ,@c_ExternStatus = ISNULL(RH.ASNStatus,'0')
   FROM RECEIPT RH WITH (NOLOCK)
   WHERE RH.ReceiptKey = @c_ReceiptKey
 
   IF @c_RecType <> 'NIF'
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65010
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Not Manual ASN. (isp_RCM_ASN_ManualUpd)'
      GOTO QUIT_SP
   END

   IF @c_ExternStatus <> '9'
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65020
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': ASN has not closed yet. (isp_RCM_ASN_ManualUpd)'
      GOTO QUIT_SP
   END

   SELECT TOP 1 @c_POkey = POKey 
      ,  @c_SellerName = ISNULL(RTRIM(PH.SellerName),'')
      ,  @c_SellerAddress1 = ISNULL(RTRIM(PH.SellerAddress1),'')
      ,  @c_SellerAddress2 = ISNULL(RTRIM(PH.SellerAddress2),'')
      ,  @c_UserDefine01 = ISNULL(RTRIM(PH.UserDefine01),'')
      ,  @c_UserDefine02 = ISNULL(RTRIM(PH.UserDefine02),'')
      ,  @c_UserDefine03 = ISNULL(RTRIM(PH.UserDefine03),'')
      ,  @c_UserDefine04 = ISNULL(RTRIM(PH.UserDefine04),'')
      ,  @c_UserDefine05 = ISNULL(RTRIM(PH.UserDefine05),'')
      ,  @dt_UserDefine06= PH.UserDefine06
      ,  @dt_UserDefine07= PH.UserDefine07
      ,  @c_UserDefine08 = ISNULL(RTRIM(PH.UserDefine08),'')
      ,  @c_UserDefine09 = ISNULL(RTRIM(PH.UserDefine09),'')
      ,  @c_UserDefine10 = ISNULL(RTRIM(PH.UserDefine10),'')
      ,  @c_POStatus =  PH.Status
   FROM PO PH WITH (NOLOCK)
   WHERE PH.ExternPOKey = @c_ExternReceiptKey


   IF @c_POkey = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65030
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Extern PO #Not Found. (isp_RCM_ASN_ManualUpd)'
      GOTO QUIT_SP
   END

   IF @c_POStatus = '9'
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65040
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': PO Ststus is ''9''. (isp_RCM_ASN_ManualUpd)'
      GOTO QUIT_SP
   END

   SELECT RD.ReceiptKey 
      ,  RD.Storerkey
      ,  RD.Sku
      ,  RD.Lottable03
      ,  NoOfRDSkuLot= 0
      ,  QtyReceived = 0
   INTO #ASN
   FROM RECEIPTDETAIL RD WITH (NOLOCK)
   WHERE 1=2

   SELECT #ASN.ReceiptKey 
      ,  #ASN.Storerkey
      ,  #ASN.Sku
      ,  #ASN.Lottable03
      ,  NoOfPOSkuLot= 0
      ,  QtyOrdered  = 0
   INTO #PO
   FROM #ASN 
   WHERE 1 = 2

   SET @n_QtyReceived = 0;
   SET @n_QtyOrdered  = 0;

   INSERT INTO #ASN ( ReceiptKey, Storerkey, Sku, Lottable03, NoOfRDSkuLot, QtyReceived )
   SELECT   ReceiptKey = @c_ReceiptKey
         ,  RD.Storerkey
         ,  RD.Sku
         ,  Lottable03 = ISNULL(RTRIM(RD.Lottable03),'') 
         ,  NoOfRDSkuLot = COUNT(1)
         ,  QtyReceived= ISNULL(SUM(RD.QtyReceived),0)
   FROM RECEIPTDETAIL RD WITH (NOLOCK)
   WHERE RD.ReceiptKey = @c_Receiptkey
   AND   RD.QtyReceived > 0
   GROUP BY RD.Storerkey
         ,  RD.Sku
         ,  ISNULL(RTRIM(RD.Lottable03),'')

   INSERT INTO #PO ( ReceiptKey, Storerkey, Sku, Lottable03, NoOfPOSkuLot, QtyOrdered )
   SELECT   RH.ReceiptKey
         ,  PD.Storerkey
         ,  PD.Sku
         ,  Lottable03 = ISNULL(RTRIM(PD.Lottable03),'')
         ,  NoOfRDSkuLot= COUNT(1)
         ,  QtyOrdered= ISNULL(SUM(PD.QtyOrdered),0)
   FROM RECEIPT RH WITH (NOLOCK) 
   JOIN PO WITH (NOLOCK) ON (RH.ExternReceiptKey = PO.ExternPOKey)
   JOIN PODETAIL PD WITH (NOLOCK) ON (PO.Pokey = PD.POKey)
   WHERE RH.ReceiptKey = @c_Receiptkey
   AND PD.QtyOrdered > 0
   AND PD.QtyReceived = 0
   GROUP BY RH.ReceiptKey 
         ,  PD.Storerkey
         ,  PD.Sku
         ,  ISNULL(RTRIM(PD.Lottable03),'') 

   SET @CUR_CHECK = CURSOR FAST_FORWARD FOR
   SELECT #ASN.QtyReceived, #ASN.NoOfRDSkuLot, #PO.QtyOrdered, #PO.NoOfPOSkuLot
   FROM #ASN WITH (NOLOCK) 
   FULL OUTER JOIN #PO  WITH (NOLOCK) ON (#ASN.ReceiptKey = #PO.ReceiptKey)
                                      AND(#ASN.Storerkey  = #PO.Storerkey)
                                      AND(#ASN.Sku        = #PO.Sku)
                                      AND(#ASN.Lottable03 = #PO.Lottable03)
   OPEN @CUR_CHECK

   FETCH NEXT FROM @CUR_CHECK INTO @n_QtyReceived
                                 , @n_NoOfRDSkuLot
                                 , @n_QtyOrdered   
                                 , @n_NoOfPOSkuLot   

   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @n_QtyReceived IS NULL
      BEGIN
         BREAK 
      END

      IF @n_QtyOrdered IS NULL
      BEGIN
         BREAK 
      END

      IF @n_QtyReceived <> @n_QtyOrdered
      BEGIN
         BREAK 
      END

      IF @n_NoOfRDSkuLot <> @n_NoOfPOSkuLot
      BEGIN
         BREAK 
      END
   
      --SET @n_SumQtyReceived= @n_SumQtyReceived+ @n_QtyReceived
      --SET @n_SumQtyORdered = @n_SumQtyORdered + @n_QtyOrdered

      FETCH NEXT FROM @CUR_CHECK INTO @n_QtyReceived
                                    , @n_NoOfRDSkuLot
                                    , @n_QtyOrdered   
                                    , @n_NoOfPOSkuLot   
   END 
   CLOSE @CUR_CHECK
   DEALLOCATE @CUR_CHECK

   IF (ISNULL(@n_QtyReceived,0) > 0 OR ISNULL(@n_QtyOrdered,0) > 0 ) AND ISNULL(@n_QtyReceived,0) <> ISNULL(@n_QtyOrdered,0)
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65050
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': ASN Sku and Lottable03 Received qty not tally with Ordered qty'
                    + '. (isp_RCM_ASN_ManualUpd)'
      GOTO QUIT_SP
   END
 
   IF (ISNULL(@n_NoOfRDSkuLot,0) > 0 OR ISNULL(@n_NoOfPOSkuLot,0) > 0 ) AND ISNULL(@n_NoOfRDSkuLot,0) <> ISNULL(@n_NoOfPOSkuLot,0)
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65060
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Not Of ASN Sku and Lottable03 Line not tally with PO Sku and Lottable03 Line'
                    + '. (isp_RCM_ASN_ManualUpd)'
      GOTO QUIT_SP
   END

   BEGIN TRAN
   SET @CUR_RD = CURSOR LOCAL FAST_FORWARD FOR
   SELECT RD.ReceiptLineNumber
         ,RD.Storerkey
         ,RD.Sku
         ,RD.Lottable03
         ,RD.QtyReceived
         --,RD.ExternReceiptKey
   FROM RECEIPTDETAIL RD WITH (NOLOCK)
   WHERE RD.ReceiptKey = @c_Receiptkey
   AND   RD.QtyReceived > 0

   OPEN @CUR_RD

   FETCH NEXT FROM @CUR_RD INTO @c_ReceiptLineNumber
                              , @c_Storerkey
                              , @c_Sku
                              , @c_Lottable03
                              , @n_QtyReceived

   WHILE @@FETCH_STATUS = 0
   BEGIN
      
      SET @c_POLineNumber = ''
      SET @c_ExternLineNo = ''
      SELECT TOP 1 @c_POLineNumber = PD.POLineNumber
            , @c_ExternLineNo = PD.ExternLineNo
      FROM PODETAIL PD WITH (NOLOCK)
      WHERE PD.POKey = @c_POKey
      AND   PD.Storerkey = @c_Storerkey      
      AND   PD.Sku = @c_Sku     
      AND   PD.Lottable03 = @c_Lottable03
      AND   PD.QtyReceived= 0

      UPDATE PODETAIL WITH (ROWLOCK)
      SET QtyReceived = QtyOrdered
      WHERE POKey = @c_POKey
      AND   POLineNumber = @c_POLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 65070
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Update PODetail Fail. (isp_RCM_ASN_ManualUpd)'
         GOTO QUIT_SP
      END
      
      UPDATE RECEIPTDETAIL WITH (ROWLOCK)
      SET  POKey = @c_POKey      
         , POLineNumber = @c_POLineNumber
         , ExternLineNo = @c_ExternLineNo 
         , TrafficCop = NULL
         , EditWho = SUSER_NAME()
         , EditDate= GETDATE()
      WHERE Receiptkey = @c_ReceiptKey
      AND   ReceiptLineNumber = @c_ReceiptLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 65080
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Update ReceiptDetail Fail. (isp_RCM_ASN_ManualUpd)'
         GOTO QUIT_SP
      END

      FETCH NEXT FROM @CUR_RD INTO @c_ReceiptLineNumber
                                 , @c_Storerkey
                                 , @c_Sku
                                 , @c_Lottable03
                                 , @n_QtyReceived
   END
   CLOSE @CUR_RD
   DEALLOCATE @CUR_RD

   UPDATE RECEIPT WITH (ROWLOCK)
   SET  RecType         = 'NORMAL'
      --, POKey           = @c_POKey  
      --, CarrierKey      = @c_SellerName           
      --, CarrierAddress1 = @c_SellerAddress1        
      --, CarrierAddress2 = @c_SellerAddress2        
      --, UserDefine01    = @c_UserDefine01         
      --, UserDefine02    = @c_UserDefine02         
      --, UserDefine03    = @c_UserDefine03         
      --, UserDefine04    = @c_UserDefine04         
      --, UserDefine05    = @c_UserDefine05         
      --, UserDefine06    = @dt_UserDefine06        
      --, UserDefine07    = @dt_UserDefine07        
      --, UserDefine08    = @c_UserDefine08         
      --, UserDefine09    = @c_UserDefine09         
      --, UserDefine10    = @c_UserDefine10         
      , Trafficcop      = NULL
      , EditWho         = SUSER_NAME()
      , EditDate        = GETDATE()
   WHERE Receiptkey = @c_Receiptkey

   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65090
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Update Receipt Fail. (isp_RCM_ASN_ManualUpd)'
      GOTO QUIT_SP
   END  

   SET @c_transmitlogkey = ''
   SELECT @c_transmitlogkey = TL3.transmitlogkey
   FROM TRANSMITLOG3 TL3 WITH (NOLOCK)
   WHERE TL3.TableName = 'RCPTLOG'
   AND TL3.key1 = @c_ReceiptKey
   AND TL3.key3 = 'MHD' 
   AND TL3.TransmitFlag = 'IGNOR'

   IF @c_transmitlogkey <> ''
   BEGIN
      UPDATE TRANSMITLOG3 WITH (ROWLOCK)
      SET  TransmitFlag = '0'
         , EditWho  = SUSER_NAME()
         , EditDate = GETDATE()
         , TrafficCop = NULL
      WHERE transmitlogkey = @c_transmitlogkey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 65100
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Update TRANSMITLOG3 Fail. (isp_RCM_ASN_ManualUpd)'
         GOTO QUIT_SP
      END  

   END

   IF EXISTS ( SELECT 1 
               FROM PO WITH (NOLOCK)
               WHERE POKey = @c_POKey
               AND   Status < '9'
            )
   BEGIN
      UPDATE PO WITH (ROWLOCK)
      SET  Status   = '9'
         , EditWho  = SUSER_NAME()
         , EditDate = GETDATE()
      WHERE POKey = @c_POKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 65110
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Update PO Fail. (isp_RCM_ASN_ManualUpd)'
         GOTO QUIT_SP
      END  
   END

QUIT_SP:

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RCM_ASN_ManualUpd'
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