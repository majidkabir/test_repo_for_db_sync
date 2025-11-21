SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_NIKEKR_PopulatePOTOASN                            */
/* Creation Date: 18-Jun-2021                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-17167 - [KR] NIKE auto Receipt Confirm (Exceed - NEW)      */
/*                                                                         */
/* Called By: SQL Job                                                      */
/*                                                                         */
/* GitLab Version: 1.2                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 2021-10-01   WLChooi 1.1   DevOps Combine Script                        */
/* 2021-10-01   WLChooi 1.2   Add Errormsg if Receiptdetail is empty (WL01)*/
/***************************************************************************/  
CREATE PROCEDURE [dbo].[isp_NIKEKR_PopulatePOTOASN] (
      @c_Storerkey     NVARCHAR(15)   = 'NIKEKR'
    , @c_Recipients    NVARCHAR(2000) = '' --email address delimited by ; 
)
AS
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_POKey                 NVARCHAR(10),
           @c_ExternReceiptKey      NVARCHAR(20),
           @c_SKU                   NVARCHAR(20),
           @c_PackKey               NVARCHAR(10),
           @c_UOM                   NVARCHAR(5),
           @c_SKUDescr              NVARCHAR(60),
           @c_OrderLine             NVARCHAR(5),
           @c_Facility              NVARCHAR(5),
           @c_ExternOrderLine       NVARCHAR(10),
           @dt_ReceiptDate          DATETIME,
           @c_RecType               NVARCHAR(10),
           @c_UserDefine01          NVARCHAR(50),
           @c_UserDefine02          NVARCHAR(50),
           @c_UserDefine03          NVARCHAR(50),
           @c_DocType               NVARCHAR(1)

   DECLARE @c_Lottable01            NVARCHAR(18),
           @c_Lottable02            NVARCHAR(18),
           @c_Lottable03            NVARCHAR(18),
           @d_Lottable04            DATETIME,
           @d_Lottable05            DATETIME,
           @c_Lottable06            NVARCHAR(30),
           @c_Lottable07            NVARCHAR(30),
           @c_Lottable08            NVARCHAR(30),
           @c_Lottable09            NVARCHAR(30),
           @c_Lottable10            NVARCHAR(30),
           @c_Lottable11            NVARCHAR(30),
           @c_Lottable12            NVARCHAR(30),
           @d_Lottable13            DATETIME,
           @d_Lottable14            DATETIME,
           @d_Lottable15            DATETIME,
           @b_debug                 INT = 0

   DECLARE @c_NewReceiptKey         NVARCHAR(10),
           @c_ReceiptLine           NVARCHAR(5),
           @n_LineNo                int,
           @c_ConsigneeKey          NVARCHAR(15),
           @n_ExpectedQty           int,
           @n_QtyReceived           int,
           @c_Toloc                 NVARCHAR(30),
           @c_ExternLineNo          NVARCHAR(20),
           @c_AltSKU                NVARCHAR(20),
           @c_ReceiptLineNo         NVARCHAR(5),
           @n_cnt                   INT,
           @c_GetReason             NVARCHAR(255),
           @n_ChannelID             BIGINT = 0,
           @c_Channel               NVARCHAR(20) = '',
           @c_POGroup               NVARCHAR(20) = ''
    
   DECLARE @n_continue              INT,
           @b_success               INT,
           @n_err                   INT,
           @c_errmsg                NVARCHAR(255)

   DECLARE @c_Body                  NVARCHAR(MAX),          
           @c_Subject               NVARCHAR(255),          
           @c_Date                  NVARCHAR(20),           
           @c_SendEmail             NVARCHAR(1)
           --@c_Recipients            NVARCHAR(2000) = ''

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = ''

   CREATE TABLE #TMP_PO (  
      POKey   NVARCHAR(10)
   ) 

   CREATE TABLE #TMP_RESULT (  
      POKey   NVARCHAR(10)
    , Reason  NVARCHAR(255)
   ) 

   INSERT INTO #TMP_PO (POKey)
   SELECT DISTINCT PO.POKey
   FROM PO (NOLOCK)
   JOIN CODELKUP CL (NOLOCK) ON CL.Storerkey = PO.StorerKey AND CL.LISTNAME = 'NIKE1082'
                            AND CL.Code = PO.PoGroup
   WHERE PO.[Status] = '0'
   AND PO.ExternStatus = '0'
   AND ISNULL(PO.Notes,'') NOT LIKE 'FAILED%'
   AND PO.StorerKey = @c_Storerkey
                           
   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TP.POKey
   FROM #TMP_PO TP

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_POKey

   WHILE @@FETCH_STATUS <> -1 AND @n_continue IN (1,2)
   BEGIN
      --Retrieve info
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN             
         SELECT TOP 1 @c_ExternReceiptKey = PO.ExternPOKey
                    , @c_StorerKey        = PO.StorerKey
                    , @dt_ReceiptDate     = GETDATE()
                    , @c_RecType          = 'NORMAL'
                    , @c_Facility         = OH.Facility
                    , @c_UserDefine01     = PO.UserDefine01
                    , @c_UserDefine02     = PO.UserDefine02
                    , @c_UserDefine03     = PO.UserDefine03
                    , @c_DocType          = 'A'
                    , @c_Channel          = ISNULL(PODET.Channel,'')
                    , @c_POGroup          = PO.PoGroup
         FROM PO (NOLOCK)
         JOIN PODETAIL PODET (NOLOCK) ON PODET.POKey = PO.POKey
         JOIN ORDERS OH (NOLOCK) ON OH.ExternOrderKey = PO.ExternPOKey
         JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
         WHERE PO.POKey = @c_POKey
         
         IF @@ROWCOUNT = 0
            GOTO QUIT_SP  
      END   
      
      -- Create receipt
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN          
         IF EXISTS (SELECT 1 FROM RECEIPT WITH (NOLOCK) 
                    WHERE ExternReceiptKey = @c_ExternReceiptKey
                    AND StorerKey = @c_StorerKey)
         BEGIN
         	 GOTO QUIT_SP
         END
         ELSE
         BEGIN 
            -- get next receipt key
            SELECT @b_success = 0
            EXECUTE   nspg_getkey
               "RECEIPT"
               , 10
               , @c_NewReceiptKey OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT
               
            IF @b_success = 1
            BEGIN
               INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, StorerKey, ReceiptDate, RECType, Facility, UserDefine01, UserDefine02, UserDefine03, ReceiptGroup)
               VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_StorerKey, @dt_ReceiptDate, @c_RecType, @c_Facility, @c_UserDefine01, @c_UserDefine02, @c_UserDefine03, @c_POGroup)
            END
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63520   
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed To Generate Receipt Key! (isp_NIKEKR_PopulatePOTOASN)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         
               INSERT INTO #TMP_RESULT (POKey, Reason)
               SELECT @c_POKey, 'Failed To Generate Receipt Key'
               
               GOTO QUIT_SP
            END   
         END
      END 
      
      -- Create receiptdetail    
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN          
         SELECT @c_OrderLine = SPACE(5), @n_LineNo = 0
         SELECT @c_ExternOrderLine = SPACE(5)
      
         DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT PODETAIL.ExternLineNo,
                   PODETAIL.SKU,
                   ISNULL(S.ALTSKU,''),
                   SUM(ISNULL(PD.Qty,0)),
                   S.PACKKey,
                   PD.Loc,
                   PODETAIL.UserDefine01,
                   PODETAIL.UserDefine03,
                   PODETAIL.Lottable01,
                   PODETAIL.Lottable02,
                   PODETAIL.Lottable03,
                   PODETAIL.Lottable04,
                   PODETAIL.Lottable05,
                   ISNULL(PODETAIL.Lottable06,''),
                   ISNULL(PODETAIL.Lottable07,''),
                   ISNULL(PODETAIL.Lottable08,''),
                   ISNULL(PODETAIL.Lottable09,''),
                   ISNULL(PODETAIL.Lottable10,''),
                   ISNULL(PODETAIL.Lottable11,''),
                   ISNULL(PODETAIL.Lottable12,''),
                   PODETAIL.Lottable13,
                   PODETAIL.Lottable14,
                   PODETAIL.Lottable15,
                   ISNULL(PD.Channel_ID,0),
                   P.PackUOM3
            FROM PO (NOLOCK)
            JOIN PODETAIL WITH (NOLOCK) ON PO.POKey = PODETAIL.POKey 
            JOIN ORDERS OH WITH (NOLOCK) ON OH.ExternOrderKey = PO.ExternPOKey
            JOIN PICKDETAIL PD WITH (NOLOCK) ON OH.OrderKey = PD.OrderKey
            JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.sku AND PODETAIL.Sku = S.SKU
            JOIN PACK P WITH (NOLOCK) ON P.PackKey = S.PACKKey
            WHERE PO.POKey = @c_POKey
            GROUP BY PODETAIL.ExternLineNo,
                     PODETAIL.SKU,
                     ISNULL(S.ALTSKU,''),
                     S.PACKKey,
                     PD.Loc,
                     PODETAIL.UserDefine01,
                     PODETAIL.UserDefine03,
                     PODETAIL.Lottable01,
                     PODETAIL.Lottable02,
                     PODETAIL.Lottable03,
                     PODETAIL.Lottable04,
                     PODETAIL.Lottable05,
                     ISNULL(PODETAIL.Lottable06,''),
                     ISNULL(PODETAIL.Lottable07,''),
                     ISNULL(PODETAIL.Lottable08,''),
                     ISNULL(PODETAIL.Lottable09,''),
                     ISNULL(PODETAIL.Lottable10,''),
                     ISNULL(PODETAIL.Lottable11,''),
                     ISNULL(PODETAIL.Lottable12,''),
                     PODETAIL.Lottable13,
                     PODETAIL.Lottable14,
                     PODETAIL.Lottable15,
                     ISNULL(PD.Channel_ID,0),
                     P.PackUOM3
                                          
         OPEN PICK_CUR
               
         FETCH NEXT FROM PICK_CUR INTO @c_ExternLineNo, @c_sku, @c_AltSKU, @n_QtyReceived, @c_PackKey, @c_toloc
                                     , @c_UserDefine01, @c_UserDefine03
                                     , @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05 
                                     , @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                                     , @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                                     , @n_ChannelID, @c_UOM
      
         WHILE @@FETCH_STATUS <> -1
         BEGIN         
            SET @n_LineNo = @n_LineNo + 1
      
            SELECT @c_ReceiptLine = RIGHT( '0000' + LTRIM(RTRIM(CAST(@n_LineNo AS NVARCHAR(5 )))), 5)
      
            IF @n_QtyReceived IS NULL
               SELECT @n_QtyReceived = 0                      
      
            INSERT INTO RECEIPTDETAIL (ReceiptKey,                ReceiptLineNumber,   ExternReceiptKey, 
                                       StorerKey,                 SKU,                 ExternLineNo,
                                       QtyExpected,               QtyReceived,         POKey,
                                       ToLoc,                     AltSku,
                                       UserDefine01,              UserDefine03,
                                       BeforeReceivedQty,         Packkey,             UOM,
                                       Lottable01,                Lottable02,          Lottable03,            Lottable04,       Lottable05,
                                       Lottable06,                Lottable07,          Lottable08,            Lottable09,       Lottable10,
                                       Lottable11,                Lottable12,          Lottable13,            Lottable14,       Lottable15,
                                       Channel,                   Channel_ID)
                               VALUES (@c_NewReceiptKey,          @c_ReceiptLine,      @c_ExternReceiptKey,
                                       @c_StorerKey,              @c_SKU,              @c_ExternLineNo,
                                       ISNULL(@n_QtyReceived,0),  0,                   @c_POKey,
                                       @c_Toloc,                  @c_AltSKU,
                                       @c_UserDefine01,           @c_UserDefine03,
                                       ISNULL(@n_QtyReceived,0),  @c_PackKey,          @c_UOM,
                                       @c_Lottable01,             @c_Lottable02,       @c_Lottable03,         @d_Lottable04,    @d_Lottable05, 
                                       @c_Lottable06,             @c_Lottable07,       @c_Lottable08,         @c_Lottable09,    @c_Lottable10,
                                       @c_Lottable11,             @c_Lottable12,       @d_Lottable13,         @d_Lottable14,    @d_Lottable15,
                                       @c_Channel,                @n_ChannelID
                                       )
        
            FETCH NEXT FROM PICK_CUR INTO @c_ExternLineNo, @c_sku, @c_AltSKU, @n_QtyReceived, @c_PackKey, @c_toloc
                                        , @c_UserDefine01, @c_UserDefine03
                                        , @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05 
                                        , @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                                        , @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                                        , @n_ChannelID, @c_UOM
         END -- WHILE @@FETCH_STATUS <> -1
         CLOSE PICK_CUR
         DEALLOCATE PICK_CUR
         
         --WL01 S
         IF NOT EXISTS (SELECT 1 FROM RECEIPTDETAIL (NOLOCK)
                        WHERE ReceiptKey = @c_NewReceiptKey)  
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63535
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Receiptdetail for #' + @c_NewReceiptKey + ' is empty. Please validate the data. (isp_NIKEKR_PopulatePOTOASN)' + ' ( '
                            + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         
            INSERT INTO #TMP_RESULT (POKey, Reason)
            SELECT @c_POKey, 'Empty Receiptdetail #' + @c_NewReceiptKey
            
            GOTO QUIT_SP
         END
         --WL01 E
      END
      
      --Finalize
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN                                                       
         EXEC dbo.ispFinalizeReceipt      
                  @c_ReceiptKey        = @c_NewReceiptKey      
                 ,@b_Success           = @b_Success  OUTPUT      
                 ,@n_err               = @n_err     OUTPUT      
                 ,@c_ErrMsg            = @c_ErrMsg    OUTPUT       
                                      
         IF @b_Success <> 1      
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63525
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ASN Finalize Error (isp_NIKEKR_PopulatePOTOASN)' + ' ( '
                            + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         
            INSERT INTO #TMP_RESULT (POKey, Reason)
            SELECT @c_POKey, 'ASN Finalize Error'
            
            GOTO QUIT_SP
         END       
      END

      --Update ASNStatus
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN   
         UPDATE RECEIPT
         SET ASNStatus  = '9'
           , TrafficCop = NULL
           , EditWho    = SUSER_SNAME()
           , EditDate   = GETDATE()
         WHERE ReceiptKey = @c_NewReceiptKey
         
         SELECT @n_err = @@ERROR
         
         IF @n_err <> 0     
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63530
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update ASNStatus Error (isp_NIKEKR_PopulatePOTOASN)' + ' ( '
                            + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         
            INSERT INTO #TMP_RESULT (POKey, Reason)
            SELECT @c_POKey, 'Update ASNStatus Error'
            
            GOTO QUIT_SP
         END 
      END

      --Close PO
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN   
         UPDATE PO
         SET [Status]     = '9'
           , ExternStatus = '9'
         WHERE POKey = @c_POKey
         
         SELECT @n_err = @@ERROR
         
         IF @n_err <> 0     
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63535
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Failed to close PO (isp_NIKEKR_PopulatePOTOASN)' + ' ( '
                            + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         
            INSERT INTO #TMP_RESULT (POKey, Reason)
            SELECT @c_POKey, 'Close PO Failed'
            
            GOTO QUIT_SP
         END 
      END

      INSERT INTO #TMP_RESULT (POKey, Reason)
      SELECT @c_POKey, 'Processed Successfully'

      FETCH NEXT FROM CUR_LOOP INTO @c_POKey
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

QUIT_SP:
   --Send alert by email
   IF EXISTS (SELECT 1 FROM #TMP_RESULT)
   BEGIN   	
      SET @c_SendEmail = 'Y'                                                            
      SET @c_Date = CONVERT(NVARCHAR(10), GETDATE(), 103)  
      SET @c_Subject = TRIM(@c_Storerkey) + ' Auto Populate PO to ASN Alert - ' + @c_Date  
      SET @c_Body = '<style type="text/css">       
               p.a1  {  font-family: Arial; font-size: 12px;  }      
               table {  font-family: Arial; margin-left: 0em; border-collapse:collapse;}      
               table, td, th {padding:3px; font-size: 12px; }
               td { vertical-align: top}
               </style>'
   
      SET @c_Body = @c_Body + '<p>Dear All, </p>'  
      SET @c_Body = @c_Body + '<p>Please be informed that the POKey below has been processed.</p>'  
      SET @c_Body = @c_Body + '<p>Kindly refer to the Remark for more info.</p>'  + CHAR(13)
         
      SET @c_Body = @c_Body + '<table border="1" cellspacing="0" cellpadding="5">'   
      SET @c_Body = @c_Body + '<tr bgcolor=silver><th>POKey</th><th>Error Message</th></tr>'  
      
      DECLARE CUR_EMAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                       
         SELECT T.POKey, T.Reason    
         FROM #TMP_RESULT T
         ORDER BY T.POKey
        
      OPEN CUR_EMAIL              
        
      FETCH NEXT FROM CUR_EMAIL INTO @c_POKey, @c_GetReason   
        
      WHILE @@FETCH_STATUS <> -1       
      BEGIN
         SET @c_Body = @c_Body + '<tr><td>' + RTRIM(@c_POKey) + '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_GetReason) + '</td>'  
         SET @c_Body = @c_Body + '</tr>'  

         IF @c_GetReason <> 'Processed Successfully'
         BEGIN
            UPDATE PO WITH (ROWLOCK)
            SET Notes      = 'FAILED - ' + TRIM(ISNULL(@c_GetReason,'')),
                TrafficCop = NULL,
                EditWho    = SUSER_SNAME(),
                EditDate   = GETDATE()
            WHERE POKey = @c_POKey
         END
   
         --SET @n_Err = @@ERROR 
          
         --IF @n_Err <> 0  
         --BEGIN           
         --   SELECT @n_continue = 3
         --   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63210
         --   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update PO for PO# ' + RTRIM(@c_POKey) + ' Failed! (isp_NIKEKR_PopulatePOTOASN)' + ' ( '
         --                  + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         --END
                                            
         FETCH NEXT FROM CUR_EMAIL INTO @c_POKey, @c_GetReason        
      END  
      CLOSE CUR_EMAIL              
      DEALLOCATE CUR_EMAIL           
      
      SET @c_Body = @c_Body + '</table>'  

      IF @b_debug = 1
      BEGIN 
         PRINT @c_Subject
         PRINT @c_Body
      END

      IF @c_SendEmail = 'Y' AND ISNULL(@c_Recipients,'') <> ''
      BEGIN           
         EXEC msdb.dbo.sp_send_dbmail   
               @recipients      = @c_Recipients,  
               @copy_recipients = NULL,  
               @subject         = @c_Subject,  
               @body            = @c_Body,  
               @body_format     = 'HTML' ;  
                 
         SET @n_Err = @@ERROR  

         IF @n_Err <> 0  
         BEGIN           
            --SELECT @n_continue = 3
            --SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63220
            --SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Executing sp_send_dbmail alert Failed! (isp_NIKEKR_PopulatePOTOASN)' + ' ( '
            --               + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '            
            
            UPDATE PO WITH (ROWLOCK)
            SET Notes      = Notes + ' - EMAIL FAILED',
                TrafficCop = NULL,
                EditWho    = SUSER_SNAME(),
                EditDate   = GETDATE()
            WHERE POKey = @c_POKey                          
         END  
      END 
   END

   IF OBJECT_ID('tempdb..#TMP_RESULT') IS NOT NULL
      DROP TABLE #TMP_RESULT

   IF OBJECT_ID('tempdb..#TMP_PO') IS NOT NULL
      DROP TABLE #TMP_PO

   IF CURSOR_STATUS('LOCAL', 'CUR_EMAIL') IN (0 , 1)
   BEGIN
      CLOSE CUR_EMAIL
      DEALLOCATE CUR_EMAIL   
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
	 
	    --IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
	    --BEGIN
	       --ROLLBACK TRAN
	    --END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_NIKEKR_PopulatePOTOASN'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
	    -- WHILE @@TRANCOUNT >= @n_starttcnt
	    -- BEGIN
	    --    COMMIT TRAN
	    -- END
      RETURN
   END            
END

GO