SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_LBI3                                            */
/* Creation Date: 24-OCT-2016                                           */
/* Copyright: LF                                                        */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: WMS-522 - CN - MAST Backroom Order to ASN function          */
/*                                                                      */
/* Input Parameters: Orderkey                                           */
/*                                                                      */
/* Output Parameters: NONE                                              */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: isp_ShipMbol                                              */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/*Date         Author  Ver. Purposes                                    */
/*21-Mar-2017  NJOW01  1.0  WMS-1322 change codelkup and mappings       */
/*15-May-2017  NJOW02  1.1  WMS-1858 add lottable07-08 mapping          */
/*16-Jun-2017  NJOW03  1.2  WMS-1322 add lottable02 mapping by config   */
/*14-Aug-2017  Wan01   1.3  WMS-2686-CN Mast_Central_RSS_SOPopulateToASN*/
/*30-Jan-2018  CSCHONG 1.4  WMS-3870-revise lottable03 logic (CS01)     */
/************************************************************************/

CREATE PROC  [dbo].[ispPopulateTOASN_LBI3]
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @n_err             INT
         , @b_Success         INT
         , @c_ErrMsg          NVARCHAR(255)

         , @c_Loadkey         NVARCHAR(10)
         , @c_RecType         NVARCHAR(10)
         , @c_Carrierkey      NVARCHAR(30) 
         , @c_Facility        NVARCHAR(5)
         , @c_Storerkey       NVARCHAR(15)
         , @c_Consigneekey    NVARCHAR(15)
         , @n_CTNQTY1         INT

         , @c_FoundReceiptKey NVARCHAR(10)
         , @c_NewReceiptKey   NVARCHAR(10)
         , @c_ToStorerkey     NVARCHAR(15)
         , @c_ToFacility      NVARCHAR(5)
         , @c_MBOLKey         NVARCHAR(10)
         , @c_MBOLEditDate    NVARCHAR(20)

         , @c_ReceiptLine     NVARCHAR(5)
         , @c_Sku             NVARCHAR(20)
         , @c_AltSku          NVARCHAR(20)
         , @c_Packkey         NVARCHAR(10)
         , @c_UOM             NVARCHAR(10)
         , @c_ToLoc           NVARCHAR(10)
         , @c_DropID          NVARCHAR(20)
         , @c_Lottable10      NVARCHAR(36)
         , @n_QtyToReceived   INT
         , @c_Lottable02      NVARCHAR(18) --NJOW03
         , @d_Lottable04      DATETIME  
         , @c_Lottable08      NVARCHAR(30)
         , @c_UDF04           NVARCHAR(30)
         , @c_UDF05           NVARCHAR(30) --NJOW03
         , @n_FacilityFound   INT
         , @n_LineNo          INT
         , @c_OrdType         NVARCHAR(10) --NJOW02
         , @c_OrdDoctype      NVARCHAR(2)  --CS01
         , @c_MastToFacility  NVARCHAR(5)  --CS01

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @b_Success  = 1
   SET @c_errmsg   = ''

   SET @c_ToStorerkey = ''
   SET @c_Storerkey = ''
   SET @c_Consigneekey = ''
   SET @c_MBOLKey = ''
   SET @c_Loadkey = ''
   SET @c_Facility= ''
   SET @c_RecType = ''

   SELECT @c_ToStorerkey = ISNULL(RTRIM(CL.UDF01),'')
        , @c_RecType     = ISNULL(RTRIM(CL.UDF02),'')
        , @c_Storerkey   = ORDERS.Storerkey
        , @c_Consigneekey= ISNULL(RTRIM(ORDERS.Consigneekey),'')
        , @c_MBOLKey     = ORDERS.MBOLKey
        , @c_Loadkey     = ORDERS.Loadkey
        , @c_Facility    = ORDERS.Facility        
       -- , @c_ToFacility  = ISNULL(RTRIM(CL.UDF03),'') --NJOW01    --CS01
        , @c_UDF04       = CL.UDF04 --NJOW01 
        , @c_UDF05       = CL.UDF05 --NJOW03
        , @c_OrdType     = ORDERS.Type --NJOW02
        , @c_OrdDoctype = ORDERS.DocType    --CS01
   FROM  ORDERS      WITH (NOLOCK)
   JOIN  CODELKUP CL WITH (NOLOCK) ON (CL.Listname = 'ORDTYP2ASN')
                                   AND (ORDERS.Type = CL.Code)
                                   AND (ORDERS.Consigneekey = CL.Short) --NJOW01
   WHERE ORDERS.OrderKey =  @c_OrderKey
   
   IF @@ROWCOUNT = 0  --NJOW01
      GOTO QUIT_SP

   /* --NJOW01 removed
   IF NOT EXISTS (SELECT 1 
                  FROM CODELKUP(NOLOCK)
                  WHERE Listname = 'BRASN'
                  AND Code = @c_Consigneekey
                  AND ISNULL(Long,'') = '1')
   BEGIN
      GOTO QUIT_SP
   END 
   */
   
   --CS01 Start
   
   SELECT @c_MastToFacility = ISNULL(RTRIM(CL.UDF03),'')
   FROM  ORDERS      WITH (NOLOCK)
   JOIN  CODELKUP CL WITH (NOLOCK) ON (CL.Listname = 'MASTFAC')
                                   AND (ORDERS.doctype = CL.UDF04)
                                   AND (ORDERS.facility = CL.Short) 
                                   AND CL.Storerkey=ORDERS.StorerKey
   WHERE ORDERS.OrderKey =  @c_OrderKey
   
   SELECT @c_ToFacility = ISNULL(RTRIM(CL.short),'')
   FROM  ORDERS      WITH (NOLOCK)
   JOIN  CODELKUP CL WITH (NOLOCK) ON (CL.Listname = 'MASTFAC')
                                   AND (ORDERS.doctype = CL.UDF04)
                                   AND (CL.code = @c_MastToFacility) 
                                   AND CL.Storerkey=ORDERS.StorerKey
   WHERE ORDERS.OrderKey =  @c_OrderKey
     
   --CS01 END

   SELECT @c_MBOLEditDate = CONVERT(NVARCHAR(20),MBOL.EditDate,120)
   FROM MBOL WITH (NOLOCK)
   WHERE MBOL.MBOLKey = @c_MBOLKey

   BEGIN TRAN

	--CS01 start
   SET @c_Carrierkey = ''
  -- SELECT TOP 1 @c_Carrierkey = ISNULL(RTRIM(CL.Short),'')
  SELECT TOP 1 @c_Carrierkey = ISNULL(RTRIM(CL.code),'')
   FROM CODELKUP CL WITH (NOLOCK) 
   WHERE CL.ListName = 'MASTFAC' 
   AND   CL.short = @c_Facility
   AND CL.UDF04 =  @c_OrdDoctype
   --CS01 End
   
   /* --NJOW01 removed
   SET @c_ToFacility = ''
   SELECT TOP 1 @c_ToFacility = ISNULL(RTRIM(CL.UDF04),'')
   FROM CODELKUP CL WITH (NOLOCK) 
   WHERE CL.ListName = 'MASTFAC'
   AND   CL.Short = @c_Facility
   */
      
   SET @c_ToLoc = ''
   SET @n_FacilityFound = 0
   SELECT @c_ToLoc = ISNULL(RTRIM(FACILITY.UserDefine04),'')
         ,@n_FacilityFound = 1
   FROM FACILITY WITH (NOLOCK) 
   WHERE Facility = @c_ToFacility

   IF @n_FacilityFound = 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63410
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Facility: ' + RTRIM(ISNULL(@c_ToFacility,'')) +
                     ' (ispPopulateTOASN_LBI3)' 
      GOTO QUIT_SP
   END

   IF NOT EXISTS ( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc)
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63420
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Loc (Facility.Userdefine04): ' + RTRIM(ISNULL(@c_ToLoc,'')) +
                     ' (ispPopulateTOASN_LBI3)'
      GOTO QUIT_SP
   END
   
   SET @c_FoundReceiptKey = ''
             
   SELECT TOP 1 @c_FoundReceiptKey = Receiptkey
   FROM RECEIPT(NOLOCK)
   WHERE ExternReceiptkey = @c_Loadkey
   AND Storerkey = @c_ToStorerKey
   AND Rectype = @c_RecType
   AND Facility = @c_ToFacility
   AND Doctype = 'A'
          
   IF ISNULL(RTRIM(@c_ToStorerKey),'') = ''  
   BEGIN              
      SET @n_continue = 3
      SET @n_err = 63430
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': To Storer Key is BLANK! (ispPopulateTOASN_LBI3)'
      GOTO QUIT_SP
   END

   SET @n_CTNQTY1 = 1
   SELECT @n_CTNQTY1 = ISNULL(COUNT(DISTINCT PD.DropID),0)
   FROM ORDERS     OH WITH (NOLOCK) 
   JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
   WHERE OH.Loadkey = @c_Loadkey

   SET @c_NewReceiptKey = @c_FoundReceiptKey

   IF ISNULL(@c_FoundReceiptKey,'') = ''
   BEGIN
      -- get next receipt key
      SET @b_success = 0
      EXECUTE   nspg_getkey
      'RECEIPT'
      , 10
      , @c_NewReceiptKey OUTPUT
      , @b_success OUTPUT
      , @n_err OUTPUT
      , @c_errmsg OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 63440
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_LBI3)'
                        + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '

         GOTO QUIT_SP
      END

      INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, StorerKey, RecType, Facility, DocType, CarrierKey, POKey,
                           CTNQTY1, NoofMasterCtn, UserDefine01, Userdefine02, Userdefine03 )  --(Wan01)  --(CS01)
      VALUES (@c_NewReceiptKey, @c_LoadKey, @c_ToStorerKey, @c_RecType, @c_ToFacility, 'A', @c_Carrierkey, @c_Loadkey,
               @n_CTNQTY1, @n_CTNQTY1, @c_Facility, @c_MastToFacility,'25')--@c_Consigneekey)             --(Wan01)  --CS01

      SET @n_err = @@Error
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 63450
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_LBI3)' + ' ( '  
                        + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
         GOTO QUIT_SP
      END
   END

   SET @n_LineNo = 1
         
   IF ISNULL(@c_FoundReceiptKey,'') <> ''
   BEGIN
      SELECT @n_LineNo = ISNULL(CONVERT(INT,MAX(ReceiptLineNumber)) + 1,1)
      FROM RECEIPTDETAIL WITH(NOLOCK)
      WHERE Receiptkey = @c_FoundReceiptKey
   END

   DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PICKDETAIL.SKU 
         ,AltSku = ISNULL(RTRIM(SKU.AltSku),'')
         ,PACK.PackKey 
         ,PACK.PackUOM3 
         ,ISNULL(RTRIM(PICKDETAIL.DropID),'')
         ,Qty = SUM(PICKDETAIL.Qty) 
         ,Lottable02 = CASE WHEN @c_UDF05 = 'LOTTABLE02' THEN LOTATTRIBUTE.Lottable02 ELSE '' END  --NJOW03
         ,Lottable04 = CASE WHEN @c_UDF04 = 'LOTTABLE04' THEN LOTATTRIBUTE.Lottable04 ELSE NULL END  --NJOW01
         ,Lottable03 = LOTATTRIBUTE.Lottable03 --NJOW01
   FROM ORDERS WITH (NOLOCK)  
   JOIN PICKDETAIL WITH (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey) 
   JOIN LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot) --NJOW01
   JOIN SKU    WITH (NOLOCK) ON (SKU.StorerKey = PICKDETAIL.StorerKey AND SKU.Sku = PICKDETAIL.Sku)
   JOIN PACK   WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   WHERE ( PICKDETAIL.Qty > 0 ) AND
         ( ORDERS.OrderKey = @c_orderkey ) 
   GROUP BY PICKDETAIL.SKU 
         ,  ISNULL(RTRIM(SKU.AltSku),'') 
         ,  PACK.PackKey 
         ,  PACK.PackUOM3 
         ,  ISNULL(RTRIM(PICKDETAIL.DropID),'')
         ,  CASE WHEN @c_UDF05 = 'LOTTABLE02' THEN LOTATTRIBUTE.Lottable02 ELSE '' END  --NJOW03
         ,  CASE WHEN @c_UDF04 = 'LOTTABLE04' THEN LOTATTRIBUTE.Lottable04 ELSE NULL END --NJOW01
         ,  LOTATTRIBUTE.Lottable03  --NJOW01
   ORDER BY PICKDETAIL.Sku
   
   OPEN CUR_PICK
   
   FETCH NEXT FROM CUR_PICK INTO @c_SKU
                              ,  @c_ALTSKU
                              ,  @c_PackKey
                              ,  @c_UOM
                              ,  @c_DropID
                              ,  @n_QtyToReceived
                              ,  @c_Lottable02  --NJOW03
                              ,  @d_Lottable04  --NJOW01
                              ,  @c_Lottable08  --NJOW01

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_ReceiptLine = RIGHT('00000' + CONVERT(NVARCHAR(5), @n_LineNo),5)
      
      SET @c_Lottable10 = '0'
      SELECT @c_Lottable10 = CONVERT(NVARCHAR(10), ISNULL(SUM(PD.Qty),'0') )
      FROM ORDERS     OH WITH (NOLOCK)  
      JOIN PICKDETAIL PD WITH (NOLOCK) ON (PD.Orderkey = OH.Orderkey) 
      WHERE OH.Loadkey = @c_Loadkey
      AND PD.Storerkey = @c_StorerKey
      AND PD.Sku = @c_Sku
      AND PD.DropID = @c_DropID

      IF LEN(@c_DropID) = 18
      BEGIN                                  
         IF EXISTS (SELECT 1 FROM PACKDETAIL WITH (NOLOCK) WHERE Labelno = '00'+ @c_DropID)
         BEGIN
            SET @c_DropID = '00'+ @c_DropID
         END
      END  
      
      INSERT INTO RECEIPTDETAIL (ReceiptKey,          ReceiptLineNumber,   ExternReceiptkey,
                                 ExternLineNo,        StorerKey,           SKU,      AltSku,
                                 BeforeReceivedQty,   QtyExpected,         QtyReceived,         
                                 PackKey,             UOM,                 ToLoc,               
                                 ConditionCode,       
                                 Lottable03,          Lottable09,          Lottable10,          
                                 CaseCnt,             FinalizeFlag,        Userdefine01,
                                 UserDefine06,				Lottable02,
                                 Lottable04,					Lottable08,  --NJOW01
                                 Lottable07  --NJOW02
                              ,  Lottable06        ,  Lottable11        --(Wan01)
                                 )
                  VALUES        (@c_NewReceiptKey,    @c_ReceiptLine,      @c_LoadKey,
                                 @c_ReceiptLine,      @c_ToStorerKey,      @c_SKU,  @c_ALTSKU,
                                 0,                   @n_QtyToReceived,    0,                   
                                 @c_Packkey,          @c_UOM,              @c_Toloc,            
                                 'OK',                
                                -- @c_Consigneekey,      --CS01
                                 @c_Lottable08,           --CS01
                                 @c_DropID,           @c_Lottable10,                     
                                 @n_QtyToReceived,      'N',               @c_DropID,
                                 @c_MBOLEditDate,			@c_Lottable02,
                                 @d_Lottable04,				@c_Lottable08,  --NJOW01
                                 @c_OrdType --NJOW02
                              ,  @c_LoadKey        ,  @c_NewReceiptKey  --(Wan01)
                                 )

      SET @n_err = @@Error
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 63460
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table ReceiptDetail (ispPopulateTOASN_LBI3)' + ' ( '  
                        + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
         GOTO QUIT_SP
      END

      SET @n_LineNo = @n_LineNo + 1

      FETCH NEXT FROM CUR_PICK INTO @c_SKU
                                 ,  @c_ALTSKU
                                 ,  @c_PackKey
                                 ,  @c_UOM
                                 ,  @c_DropID
                                 ,  @n_QtyToReceived
                                 ,  @c_Lottable02  --NJOW03
                                 ,  @d_Lottable04  --NJOW01
                                 ,  @c_Lottable08  --NJOW01
   END
   CLOSE CUR_PICK
   DEALLOCATE CUR_PICK 
QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PICK') in (0 , 1)  
   BEGIN
      CLOSE CUR_PICK
      DEALLOCATE CUR_PICK
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPopulateTOASN_LBI3'
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