SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: ispPopulateTOASN_ADIDAS_AU                                           */
/* Creation Date: 28.Aug.2013                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Populate ASN Detail from ORDERS for ADIDAS AU               */
/*          tote consolidation                                          */
/*                                                                      */
/* Usage: Use For Warehouse transfering                                 */
/*                                                                      */
/* Called By: Backend Job                                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE   PROC [dbo].[ispPopulateTOASN_ADIDAS_AU]
   @c_MBOLKey  NVARCHAR(10),
   @b_Success  INT OUTPUT ,
   @n_Err      INT OUTPUT,
   @c_ErrMsg   NVARCHAR(255) OUTPUT
AS
BEGIN

   SET NOCOUNT ON

   DECLARE @c_SKU                   NVARCHAR(20),
           @c_PackKey               NVARCHAR(10),
           @c_UOM                   NVARCHAR(5),
           @c_StorerKey             NVARCHAR(15),
           @c_Facility              NVARCHAR(5),
           @c_OrderKey              NVARCHAR(10),
           @c_ContainerKey          NVARCHAR(20),
           @c_PrevMBOLKey           NVARCHAR(20),
           @C_MBOL                  NVARCHAR(20),
           @c_PickSlipNo            NVARCHAR(10),
           @c_VehicleNo             NVARCHAR(20),
           @c_ToStorerKey           NVARCHAR(15),
           @c_ExternOrderKey        NVARCHAR(50),
           @c_UCCNo                 NVARCHAR(20),
           @c_OrderLineNumber       NVARCHAR(5)

   DECLARE @c_Lottable01            NVARCHAR(18),
           @c_Lottable02            NVARCHAR(18),
           @c_Lottable03            NVARCHAR(18),
           @c_DefaultLottable03     NVARCHAR(18),
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
           @n_StartTCnt             INT

   DECLARE @c_NewReceiptKey         NVARCHAR(10),
           @c_ReceiptLine           NVARCHAR(5),
           @n_LineNo                int,
           @c_OrderType             NVARCHAR(10),
           @c_ToFacility            NVARCHAR(5),
           @n_ExpectedQty           int,
           @n_Qty                   int,
           @c_TOLOC                 NVARCHAR(30),
           @c_NewSKU                NVARCHAR(20),
           @c_DefaultLoc            NVARCHAR(20)  --SY01

   DECLARE @n_continue        INT

   SELECT @n_continue = 1, @b_Success = 1, @n_err = 0
   SET @n_StartTCnt = @@TRANCOUNT
   BEGIN TRAN

   IF EXISTS(
      SELECT 1 FROM Receipt WITH (NOLOCK)
      WHERE StorerKey = 'ADIDAS'
      AND ExternReceiptKey = @c_MBOLKey
   )
   BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63527
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+
               ': Orders already populated into ASN! (ispPopulateTOASN_ADIDAS_AU)' + ' ( ' +
               ' SQLSvr MESSAGE=' + RTRIM(@n_err) + ' ) '
       GOTO QUIT_SP
   END


   SET @c_PrevMBOLKey = ''

   DECLARE C_MBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   --SELECT Ctn.ContainerKey, PltDet.CaseId, Ctn.OtherReference, plt.StorerKey
   --FROM MBOL M (NOLOCK)
   --JOIN CONTAINER Ctn ON Ctn.MbolKey = M.MbolKey
   --JOIN CONTAINERDETAIL CtnDet WITH (NOLOCK) ON CtnDet.ContainerKey = Ctn.ContainerKey
   --JOIN PALLET Plt WITH (NOLOCK) ON Plt.PalletKey = CtnDet.PalletKey
   --JOIN PALLETDETAIL PltDet WITH (NOLOCK) ON PltDet.PalletKey = Plt.PalletKey
   --WHERE M.MbolKey = @c_MBOLKey
   --AND M.[Status] = '9'
   --ORDER BY Ctn.ContainerKey, PltDet.CaseId

   SELECT OrderKey, MD.MbolKey
   FROM MBOLDetail MD WITH (NOLOCK)
   JOIN MBOL M WITH (NOLOCK) ON M.MbolKey = MD.MbolKey
   WHERE M.MbolKey = @c_MBOLKey
   AND M.[Status] = '9'

   OPEN C_MBOL

   FETCH NEXT FROM C_MBOL INTO @c_OrderKey, @c_MBOLKey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_ExternOrderKey = ''
      SET @c_PickSlipNo = ''
      SET @c_StorerKey = ''
      SET @c_Facility = ''

      SELECT TOP 1
         @c_PickSlipNo = pd.PickSlipNo
      FROM PackDetail PD WITH (NOLOCK)
      JOIN PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
      WHERE OrderKey =  @c_OrderKey

      SELECT TOP 1 @c_ExternOrderKey = ExternOrderKey, @c_StorerKey = StorerKey, @c_Facility = Facility
      FROM Orders WITH (NOLOCK)
      WHERE OrderKey = @c_OrderKey

      --SY01 SET DEFAULT LOC BASED ON SALESMAN
      SET @c_DefaultLoc = ''
      SELECT @c_DefaultLoc = Long from Codelkup CL WITH (NOLOCK)
      JOIN Orders O WITH (NOLOCK) ON CL.Code = O.Salesman AND CL.Storerkey = O.Storerkey
      WHERE CL.StorerKey = 'ADIDAS' AND CL.Listname = 'ADIO2ALOC'
      AND O.Orderkey = @c_OrderKey
      --SY01 END

      IF @c_MBOLKey <> @c_PrevMBOLKey
      BEGIN
         --SET @c_TOLOC = ''
         --SELECT @c_TOLOC = Userdefine04
         --FROM FACILITY f WITH (NOLOCK)
         --WHERE f.Facility = @c_Facility

         --IF ISNULL(RTRIM(@c_TOLOC),'') = ''
         --BEGIN
         --   SELECT @n_continue = 3
         --   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526
         --   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+
         --           ': Userdefine04 [To Location] NOT Setup in Facility ' +
         --           ISNULL(RTRIM(@c_Facility),'') +
         --           ' ! (ispPopulateTOASN_ADIDAS_AU)'
         --   GOTO QUIT_SP
         --END

         --SET @c_ToFacility = ''
         --SET @c_ToStorerKey = ''
         --SELECT @c_ToFacility = S.SUSR4,
         --       @c_ToStorerKey = S.SUSR2
         --FROM STORER s (NOLOCK)
         --WHERE s.StorerKey = @c_StorerKey

         --IF ISNULL(RTRIM(@c_ToFacility),'') = '' OR ISNULL(RTRIM(@c_ToStorerKey),'') = ''
         --BEGIN
         --   SELECT @n_continue = 3
         --   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526
         --   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+
         --           ': SUSR4 [To Facility] OR SUSR2 [To Storer] Is NOT Setup in Storer ' +
         --           ISNULL(RTRIM(@c_StorerKey),'') +
         --           ' ! (ispPopulateTOASN_ADIDAS_AU)'
         --   GOTO QUIT_SP
         --END

         --SET @c_DefaultLottable03 = ''
         --SELECT @c_DefaultLottable03 = F.Userdefine03
         --FROM FACILITY f WITH (NOLOCK)
         --WHERE f.Facility = @c_ToFacility

         --IF ISNULL(RTRIM(@c_DefaultLottable03),'') = ''
         --BEGIN
         --   SELECT @n_continue = 3
         --   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526
         --   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+
         --           ': Userdefine03 [Default Lottable03] NOT Setup in Facility ' +
         --           ISNULL(RTRIM(@c_ToFacility),'') +
         --           ' ! (ispPopulateTOASN_ADIDAS_AU)'
     --   GOTO QUIT_SP
         --END
         --SELECT @c_Facility '@c_Facility', @c_ToFacility '@c_ToFacility', @c_TOLOC '@c_TOLOC', @c_OrderKey '@c_OrderKey',
         --@C_MBOL '@C_MBOL', @c_PickSlipNo '@c_PickSlipNo', @c_ContainerKey '@c_ContainerKey'

          -- get next receipt key
          SELECT @b_Success = 0
          EXECUTE nspg_GetKey
                  'RECEIPT'
                  , 10
                  , @c_NewReceiptKey OUTPUT
                  , @b_Success OUTPUT
                  , @n_Err OUTPUT
                  , @c_ErrMsg OUTPUT

          IF @b_Success = 1
          BEGIN
             INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, StorerKey,
                                  RecType, Facility, DocType, Notes)
             VALUES (@c_NewReceiptKey, @c_MBOLKey, @c_StorerKey,
                    'TVNA', @c_Facility, 'A', 'ASN for stocks pulled from WES')
          END
          ELSE
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+
                     ': Generate Receipt Key Failed! (ispPopulateTOASN_ADIDAS_AU)' + ' ( ' +
                     ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
             GOTO QUIT_SP
          END

          SET @c_PrevMBOLKey = @c_MBOLKey
          SET @n_LineNo = 1
      END

      SET @c_OrderLineNumber = ''
      SET @c_UCCNo = ''
      --SET @n_LineNo = 1

      DECLARE CUR_PACKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      --SELECT PD.SKU, LA.Lottable01, LA.Lottable02, SUM(Qty),
      --      LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10,
      --      LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15
      --FROM PICKDETAIL PD WITH (NOLOCK)
      --JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON PD.Lot = LA.Lot
      --WHERE OrderKey = @c_OrderKey
      --GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02,
      --      LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10,
      --      LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15

      SELECT CT.TrackingNo, PD.SKU, SUM(Qty)
      FROM PackDetail PD WITH (NOLOCK)
      JOIN CartonTrack CT WITH (NOLOCK) ON CT.LabelNo = PD.LabelNo AND CT.KeyName = PD.StorerKey
      WHERE PickSlipNo = @c_PickSlipNo
      GROUP BY CT.TrackingNo, PD.SKU

      OPEN CUR_PACKDETAIL

      FETCH NEXT FROM CUR_PACKDETAIL INTO @c_UCCNo, @c_SKU, @n_ExpectedQty

      WHILE @@FETCH_STATUS <> -1
      BEGIN
          SET @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)

          SET @c_UOM = ''
          SET @c_PackKey = ''
          --SET @c_NewSKU = ''
          SELECT @c_UOM = PK.PackUOM3,
                 @c_PackKey = PK.PackKey
          FROM PACK PK WITH (NOLOCK)
          JOIN SKU WITH (NOLOCK) ON SKU.PackKey = PK.PackKey
          WHERE SKU.StorerKey = @c_StorerKey
          AND   SKU.SKU = @c_SKU

         IF ISNULL(RTRIM(@c_UOM),'') = '' OR ISNULL(RTRIM(@c_PackKey),'') = ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+
                    ': SKU/Pack UOM/Pack Key not found for SKU ' +
                    ISNULL(RTRIM(@c_SKU),'') +
                    ' ! (ispPopulateTOASN_ADIDAS_AU)'
            GOTO QUIT_SP
         END



         INSERT INTO RECEIPTDETAIL (ReceiptKey,   ReceiptLineNumber,   ExternReceiptKey,
                                 ExternLineNo,  StorerKey,           SKU,
                                 QtyExpected,   QtyReceived,
                                 UOM,           PackKey,       ToLoc,         BeforeReceivedQty, UserDefine01, Lottable03)
         VALUES        (@c_NewReceiptKey, @c_ReceiptLine,   @c_ExternOrderKey,
                   '', @c_StorerKey,   @c_SKU,
                         ISNULL(@n_ExpectedQty,0),   0,
                         @c_UOM,        @c_Packkey,      CASE WHEN ISNULL(@c_DefaultLoc,'') <> '' THEN @c_DefaultLoc ELSE 'ADMSTD' END,  0, @c_UCCNo, 'NA')  --SY01

         INSERT INTO UCC (UCCNo,Storerkey, SKU, qty, Sourcekey, Sourcetype, ExternKey, ReceiptKey, ReceiptLineNumber)
         VALUES(@c_UCCNo, @c_StorerKey, @c_SKU, @n_ExpectedQty, @c_NewReceiptKey, 'Order2ASN', @c_ExternOrderKey, @c_NewReceiptKey, @c_ReceiptLine)

         SELECT @n_LineNo = @n_LineNo + 1

         FETCH NEXT FROM CUR_PACKDETAIL INTO @c_UCCNo, @c_SKU, @n_ExpectedQty
      END

      CLOSE CUR_PACKDETAIL
      DEALLOCATE CUR_PACKDETAIL

      IF NOT EXISTS(SELECT 1 FROM RECEIPTDETAIL r WITH (NOLOCK)
                    WHERE r.ReceiptKey = @c_NewReceiptKey)
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63601
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+
                  ': No Receipt Detail Generate! (ispPopulateTOASN_ADIDAS_AU)' + ' ( ' +
                  ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
          GOTO QUIT_SP
      END

      --DECLARE CUR_PackDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      --SELECT CT.TrackingNo, SKU, SUM(Qty)
      --FROM PackDetail PD WITH (NOLOCK)
      --JOIN CartonTrack CT WITH (NOLOCK) ON CT.LabelNo = PD.LabelNo AND CT.KeyName = PD.StorerKey
      --WHERE pd.StorerKey = @c_StorerKey
      --AND   pd.PickSlipNo = @c_PickSlipNo
      --GROUP BY CT.TrackingNo, SKU

      --OPEN CUR_PackDetail

      --FETCH NEXT FROM Cur_PackDetail INTO @c_UCCNo, @c_SKU, @n_Qty
      --WHILE @@FETCH_STATUS <> -1
      --BEGIN

      --   INSERT INTO UCC (UCCNo,Storerkey, SKU, qty, Sourcekey, Sourcetype, ExternKey, ReceiptKey, ReceiptLineNumber)
      --   VALUES(@c_UCCNo, @c_StorerKey, @c_SKU, @n_Qty, @c_NewReceiptKey, 'Order2ASN', @c_ExternOrderKey, @c_NewReceiptKey, @c_ReceiptLine)

      --   FETCH NEXT FROM Cur_PackDetail INTO @c_UCCNo, @c_SKU, @n_Qty
      --END
      --CLOSE CUR_PackDetail
      --DEALLOCATE CUR_PackDetail

      FETCH NEXT FROM C_MBOL INTO @c_OrderKey, @c_MBOLKey
   END
   CLOSE C_MBOL
   DEALLOCATE C_MBOL

   SELECT @c_NewReceiptKey '@c_NewReceiptKey'

QUIT_SP:
   IF @n_continue = 3 -- Error Occured - Process And Return
   BEGIN
       SET @b_Success = 0

       IF @@TRANCOUNT = 1
       AND @@TRANCOUNT >= @n_starttcnt
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
       EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_ADIDAS_AU'
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
   END
   ELSE
   BEGIN
       WHILE @@TRANCOUNT > @n_starttcnt
       BEGIN
           COMMIT TRAN
       END
       RETURN
   END
END -- if continue = 1 or 2 001

GO