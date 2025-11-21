SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_RCM_MB_CONVERSE_GenASN                         */  
/* Creation Date: 10-Mar-2022                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-19117 - CN_CONVERSE_Exceed_AutoASNBYLOADKEY(CR)         */  
/*                                                                      */  
/* Called By: MBOL Dynamic RCM configure at listname 'RCMConfig'        */   
/*                                                                      */  
/* Parameters:                                                          */  
/*                                                                      */  
/* GitLab Version: 1.1                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 10-Mar-2022  WLChooi   1.0   DevOps Combine Script                   */
/* 02-Nov-2022  Wan01     1.1   Fixed Create Multi Loadkey into ASN due */
/*                              to Loadkey not in correct sort order    */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_RCM_MB_CONVERSE_GenASN]  
      @c_Mbolkey  NVARCHAR(10),     
      @b_success  INT OUTPUT,  
      @n_err      INT OUTPUT,  
      @c_errmsg   NVARCHAR(225) OUTPUT,  
      @c_code     NVARCHAR(30) = ''  
AS  
BEGIN   
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue  INT,  
           @n_cnt       INT,  
           @n_starttcnt INT 
     
   DECLARE @c_Loadkey            NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)
         , @c_SKU                NVARCHAR(20)
         , @c_Lot                NVARCHAR(10)
         , @c_Lottable01         NVARCHAR(18)
         , @c_Lottable02         NVARCHAR(18)
         , @c_Lottable03         NVARCHAR(18)
         , @dt_Lottable04        DATETIME
         , @dt_Lottable05        DATETIME
         , @c_ID                 NVARCHAR(18)
         , @c_Loc                NVARCHAR(10)
         , @c_Packkey            NVARCHAR(10)
         , @c_Channel            NVARCHAR(20)
         , @c_PrevLoadkey        NVARCHAR(10)
         , @c_Receiptkey         NVARCHAR(10)
         , @c_ReceiptGroup       NVARCHAR(10)
         , @c_RecType            NVARCHAR(10)
         , @c_DocType            NVARCHAR(10)
         , @c_Facility           NVARCHAR(5)
         , @c_UOM                NVARCHAR(10)
         , @c_ReceiptLineNumber  NVARCHAR(5)
         , @n_Qty                INT
         , @c_ExternReceiptKey   NVARCHAR(50)

   SET @c_ReceiptGroup  = 'R'
   SET @c_RecType       = 'GRN'
   SET @c_DocType       = 'A'
   SET @c_Facility      = 'BS01'
   SET @c_UOM           = 'EA'

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt = @@TRANCOUNT, @c_errmsg = '', @n_err = 0 
   
   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT PH.ExternOrderKey, PH.StorerKey, PD.Sku, SUM(PD.Qty) AS Qty, PD.Lot
        , LA.Lottable01, LA.Lottable02, LA.Lottable03
        , LA.Lottable04, LA.Lottable05
        , PD.ID, PD.Loc, PD.PackKey
        , 'B2C' AS Channel
   FROM MBOLDETAIL MD (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON MD.OrderKey = OD.OrderKey
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber
                              AND PD.SKU = OD.SKU
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON MD.OrderKey = LPD.OrderKey
   JOIN PICKHEADER PH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
   JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.Lot = PD.Lot
   WHERE MD.MbolKey = @c_Mbolkey
   AND NOT EXISTS (SELECT 1 FROM RECEIPT (NOLOCK) 
                   WHERE ExternReceiptKey = 'LF' + TRIM(PH.ExternOrderKey)
                   AND Storerkey = PH.StorerKey)
   GROUP BY PH.ExternOrderKey, PH.StorerKey, PD.Sku, PD.Lot
          , LA.Lottable01, LA.Lottable02, LA.Lottable03
          , LA.Lottable04, LA.Lottable05
          , PD.ID, PD.Loc, PD.PackKey
   ORDER BY PH.ExternOrderKey                --(Wan01) - Add Order by Loadkey           
   
   OPEN CUR_LOOP
   
   FETCH NEXT FROM CUR_LOOP INTO @c_Loadkey, @c_Storerkey, @c_SKU, @n_Qty, @c_Lot
                               , @c_Lottable01, @c_Lottable02, @c_Lottable03
                               , @dt_Lottable04, @dt_Lottable05
                               , @c_ID, @c_Loc, @c_Packkey, @c_Channel
   
   WHILE @@FETCH_STATUS = 0  
   BEGIN    
      SET @c_ExternReceiptKey = 'LF' + TRIM(@c_Loadkey)

      IF @c_PrevLoadkey <> @c_Loadkey
      BEGIN
         SET @c_ReceiptLineNumber = '00000'
         EXECUTE nspg_getkey  
           'ReceiptKey'  
           , 10  
           , @c_Receiptkey    OUTPUT  
           , @b_Success       OUTPUT  
           , @n_Err           OUTPUT  
           , @c_ErrMsg        OUTPUT  

         IF @b_Success <> 1  
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 67005
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                            ': Get PickDetailKey Failed. (isp_RCM_MB_CONVERSE_GenASN)'
            GOTO QUIT_SP
         END
         ELSE
         BEGIN
            INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, ReceiptGroup, StorerKey
                               , RecType, DOCTYPE, Facility, UserDefine02)
            SELECT @c_Receiptkey, @c_ExternReceiptKey, @c_ReceiptGroup, @c_Storerkey
                 , @c_RecType, @c_DocType, @c_Facility, 'B2C'

            IF @@ERROR <> 0  
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 67010
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                               ': Insert Receipt Table Failed. (isp_RCM_MB_CONVERSE_GenASN)'
               GOTO QUIT_SP
            END
         END
      END

      SET @c_ReceiptLineNumber = RIGHT('00000' + CAST(CAST(@c_ReceiptLineNumber AS INT) + 1 AS NVARCHAR), 5)

      INSERT INTO dbo.RECEIPTDETAIL(ReceiptKey, ReceiptLineNumber, ExternReceiptKey, ExternLineNo, StorerKey, Sku
                                  , QtyExpected, ToLot, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05
                                  , ToId, ToLoc, Channel, PackKey, UOM, BeforeReceivedQty)
      SELECT @c_Receiptkey, @c_ReceiptLineNumber, @c_ExternReceiptKey, @c_ReceiptLineNumber, @c_Storerkey, @c_SKU
           , @n_Qty, @c_Lot, @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05
           , @c_ID, @c_Loc, @c_Channel, @c_Packkey, @c_UOM, @n_Qty
      
      IF @@ERROR <> 0  
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 67015
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                         ': Insert ReceiptDetail Table Failed. (isp_RCM_MB_CONVERSE_GenASN)'
         GOTO QUIT_SP
      END

      SET @c_PrevLoadkey = @c_Loadkey

      NEXT_LOOP:
      FETCH NEXT FROM CUR_LOOP INTO @c_Loadkey, @c_Storerkey, @c_SKU, @n_Qty, @c_Lot
                                  , @c_Lottable01, @c_Lottable02, @c_Lottable03
                                  , @dt_Lottable04, @dt_Lottable05
                                  , @c_ID, @c_Loc, @c_Packkey, @c_Channel
   END
   CLOSE CUR_LOOP  
   DEALLOCATE CUR_LOOP                                   
       
QUIT_SP:   
   IF (SELECT CURSOR_STATUS('LOCAL','CUR_LOOP')) >=0 
   BEGIN
      CLOSE CUR_LOOP           
      DEALLOCATE CUR_LOOP      
   END  

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RCM_MB_CONVERSE_GenASN'  
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