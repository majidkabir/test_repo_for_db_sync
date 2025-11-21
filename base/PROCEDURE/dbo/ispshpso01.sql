SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispSHPSO01                                         */
/* Creation Date: 15-May-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#276826 - VFCDC-Order Cancel                             */
/*                                                                      */
/* Input Parameters:  @c_ORderkey  - (ORder #)                          */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: RMC Cancel Order at Order maintenance Screen              */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 01-NOV-2013  YTWan    1.1  Fixed. (Wan01)                            */
/* 06-NOV-2013  Chee     1.2  Stamp linkage between ReceiptDetail and   */
/*                            UCC table for RDT Receiving (Chee01)      */
/* 09-JAN-2014  SPChin   1.3  SOS330239 - Bug Fixed                     */
/************************************************************************/

CREATE PROC [dbo].[ispSHPSO01]
   @c_OrderKey    NVARCHAR(10),
   @b_Success     INT OUTPUT,
   @n_err         INT OUTPUT,
   @c_errmsg      NVARCHAR(255) OUTPUT
AS
BEGIN
   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT
         , @n_StartTCnt       INT
         , @c_Status          NVARCHAR(10)
         , @c_SOStatus        NVARCHAR(10)
         , @c_ASNCreatedMsg   NVARCHAR(255)

   DECLARE @c_ReceiptKey         NVARCHAR(10)
         , @c_RecType            NVARCHAR(10)
         , @c_Facility           NVARCHAR(5)
         , @c_ExternReceiptKey   NVARCHAR(20)
         , @c_ExternLineNo       NVARCHAR(10)
         , @c_ReceiptLineNo      NVARCHAR(10)
         , @c_StorerKey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @c_PackKey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)
         , @c_ToLoc              NVARCHAR(10)
         , @c_Lottable01         NVARCHAR(18)
         , @c_Lottable02         NVARCHAR(18)
         , @c_Lottable03         NVARCHAR(18)
         , @dt_Lottable04        DATETIME
         , @dt_Lottable05        DATETIME
         , @n_QtyExpected        INT

         , @c_RealTimeShip       NVARCHAR(10)
         , @c_Loadkey            NVARCHAR(10)
         , @c_MinLoadStatus      NVARCHAR(10)

         , @c_UCCNo              NVARCHAR(20)
         , @n_Qty                INT

         , @cOrderKey            NVARCHAR(10)   -- Chee01
         , @cOrderLineNumber     NVARCHAR(5)    -- Chee01

   SET @n_StartTCnt     =  @@TRANCOUNT
   SET @n_continue      = 1
   SET @c_Status        = ''
   SET @c_SOStatus      = ''
   SET @c_ASNCreatedMsg = ''

   SET @c_ReceiptKey = ''
   SET @c_RecType    = ''
   SET @c_Facility   = ''
   SET @c_ExternReceiptKey = ''
   SET @c_ExternLineNo     = ''
   SET @c_ReceiptLineNo    = '00000'
   SET @c_StorerKey        = ''
   SET @c_Sku              = ''
   SET @c_PackKey          = ''
   SET @c_UOM              = ''
   SET @c_ToLoc            = ''
   SET @c_Lottable01       = ''
   SET @c_Lottable02       = ''
   SET @c_Lottable03       = ''
   SET @n_QtyExpected      = 0

   SET @c_RealTimeShip     = ''
   SET @c_Loadkey          = ''
   SET @c_MinLoadStatus    = ''

   SET @c_UCCNo            = ''
   SET @n_Qty              = 0

   SET @cOrderKey          = ''   -- Chee01
   SET @cOrderLineNumber   = ''   -- Chee01

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SELECT @c_Status   = ISNULL(RTRIM(Status),'')
         ,@c_SOStatus = ISNULL(RTRIM(SOStatus),'')
         ,@c_Facility        = ISNULL(RTRIM(Facility),'')
         ,@c_Storerkey       = ISNULL(RTRIM(Storerkey),'')
         ,@c_ExternReceiptKey= ISNULL(RTRIM(ExternOrderKey),'')
         ,@c_RecType         = ISNULL(RTRIM(Type),'')
         ,@c_Loadkey         = ISNULL(RTRIM(Loadkey),'')
   FROM ORDERS WITH (NOLOCK)
   WHERE Orderkey = @c_Orderkey


   IF @c_SOStatus <> 'CANC'
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65001
      SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err)
                    + ': Order#: ' + RTRIM(@c_Orderkey) + ' is not a CANCEL Order. Ship Abort. (ispSHPSO01)'
      GOTO QUIT_SP
   END

   IF @c_Status <> '5'
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65002
      SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err)
                    + ': Order#: ' + RTRIM(@c_Orderkey) + ' had not picked yet. Ship Abort. (ispSHPSO01)'
      GOTO QUIT_SP
   END

   IF @c_Status = '9'
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65003
      SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err)
                    + ': Order#: ' + RTRIM(@c_Orderkey) + ' had been shipped. (ispSHPSO01)'
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1
               FROM PREALLOCATEPICKDETAIL WITH (NOLOCK) WHERE PREALLOCATEPICKDETAIL.Orderkey = @c_Orderkey )
   BEGIN
      SET @n_continue = 3
      SET @n_err      = 65004
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Order Preallocated. Cannot Shipped. (ispSHPSO01)'
   END

   IF ISNULL(RTRIM(@c_Facility),'') = ''
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 65005
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Facility is blank. (ispSHPSO01)'
      GOTO QUIT_SP
   END

   IF NOT EXISTS (SELECT 1
                  FROM CODELKUP WITH (NOLOCK)
                  WHERE ListName = 'RECTYPE'
                  AND   Code = @c_RecType)
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63506
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),@n_err)+': ' + @c_RecType + ' Not Setup in Codelkup for ListName: ''RECTYPE'''
                     + '. (ispSHPSO01)'
      GOTO QUIT_SP
   END

   SELECT @c_RealTimeShip = ISNULL(RTRIM(SValue),'')
   FROM STORERCONFIG WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND   (Facility  = @c_facility OR ISNULL(RTRIM(Facility),'') = '')
   AND   Configkey = 'REALTIMESHIP'

   SELECT @c_ToLoc = ISNULL(RTRIM(SValue),'')
   FROM STORERCONFIG WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND   (Facility  = @c_facility OR ISNULL(RTRIM(Facility),'') = '')
   AND   Configkey = 'DEFAULTRCPTLOC'

   IF @c_Toloc = ''
   BEGIN
      SET @c_Toloc = 'SLOK'
   END

   -- get next receipt key
   SET @b_success = 0
   EXECUTE nspg_getkey
           'RECEIPT'
         , 10
         , @c_ReceiptKey      OUTPUT
         , @b_success         OUTPUT
         , @n_err             OUTPUT
         , @c_errmsg          OUTPUT

   BEGIN TRAN
   -- insert into Receipt Header
   IF @b_success = 1
   BEGIN
      INSERT INTO RECEIPT (ReceiptKey, StorerKey, ExternReceiptkey, RecType, Facility, DocType, Status)
      VALUES (@c_ReceiptKey, @c_StorerKey,@c_ExternReceiptKey, @c_RecType , @c_Facility, 'A', '0')

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err      = 63507
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On Receipt. (ispSHPSO01)'
         GOTO QUIT_SP
      END

      SET @c_ASNCreatedMsg = 'ASN #: ' + RTRIM(@c_ReceiptKey) + ' is created'
   END
   ELSE
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63508
      SET @c_errmsg  ='NSQL'+CONVERT(CHAR(5),@n_err)+': Generate Receipt Key Failed! (ispSHPSO01)'
      GOTO QUIT_SP
   END

   DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(OD.ExternOrderkey),'')
         ,RTRIM(OD.ExternLineNo)
         ,RTRIM(OD.SKU)
         ,RTRIM(OD.Packkey)
         ,ISNULL(RTRIM(PCK.PackUOM3),'')
         --,ISNULL(RTRIM(LA.Lottable01),'')
         ,ISNULL(RTRIM(LA.Lottable02),'')
         ,ISNULL(RTRIM(LA.Lottable03),'')
         --,LA.Lottable04
         --,LA.Lottable05
         ,SUM(PD.Qty)
         ,RTRIM(OD.OrderKey)        -- Chee01
         ,RTRIM(OD.OrderLineNumber) -- Chee01
   FROM ORDERDETAIL  OD WITH (NOLOCK)
   JOIN PICKDETAIL   PD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey) AND (OD.OrderLineNumber = PD.OrderLineNumber)
   JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (PD.Lot = LA.Lot)
   JOIN PACK        PCK WITH (NOLOCK) ON (OD.Packkey = PCK.Packkey)
   WHERE OD.Orderkey = @c_Orderkey
   GROUP BY ISNULL(RTRIM(OD.ExternOrderkey),'')
         ,  RTRIM(OD.ExternLineNo)
         ,  RTRIM(OD.SKU)
         ,  RTRIM(OD.Packkey)
         ,  ISNULL(RTRIM(PCK.PackUOM3),'')
         ,  ISNULL(RTRIM(LA.Lottable02),'')
         ,  ISNULL(RTRIM(LA.Lottable03),'')
         ,  RTRIM(OD.OrderKey)        -- Chee01
         ,  RTRIM(OD.OrderLineNumber) -- Chee01
   ORDER BY RTRIM(OD.ExternLineNo)

   OPEN CUR_PICK

   FETCH NEXT FROM CUR_PICK INTO @c_ExternReceiptkey
                               , @c_ExternLineNo
                               , @c_Sku
                               , @c_Packkey
                               , @c_UOM
--                               , @c_Lottable01
                               , @c_Lottable02
                               , @c_Lottable03
--                               , @dt_Lottable04
--                               , @dt_Lottable05
                               , @n_QtyExpected
                               , @cOrderKey           -- Chee01
                               , @cOrderLineNumber    -- Chee01
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      --SET @c_ReceiptLineNo = RIGHT('00000' + CONVERT(INT, @c_ReceiptLineNo) + 1,5)
      SET @c_ReceiptLineNo = RIGHT('00000' + CAST(CONVERT(INT, @c_ReceiptLineNo) + 1 AS NVARCHAR(5)),5)

      BEGIN TRAN
      INSERT INTO RECEIPTDETAIL
               (  ReceiptKey
                 ,ReceiptLineNumber
                 ,ExternReceiptKey
                 ,ExternLineNo
                 ,StorerKey
                 ,Sku
                 ,QtyExpected
                 ,ToLoc
                 ,PackKey
                 ,UOM
                 ,Lottable01
                 ,Lottable02
                 ,Lottable03
                 ,Lottable04
                 ,Lottable05
                 ,Userdefine02   -- Chee01
                 ,Userdefine03   -- Chee01
               )
      VALUES   (  @c_ReceiptKey
                 ,@c_ReceiptLineNo
                 ,@c_ExternReceiptKey
                 ,@c_ExternLineNo
                 ,@c_StorerKey
                 ,@c_Sku
                 ,@n_QtyExpected
                 ,@c_ToLoc
                 ,@c_PackKey
                 ,@c_UOM
                 ,@c_Lottable01
                 ,@c_Lottable02
                 ,@c_Lottable03
                 ,@dt_Lottable04
                 ,@dt_Lottable05
                 ,@cOrderLineNumber  -- Chee01
                 ,@cOrderKey         -- Chee01
               )

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err      = 63509
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On ReceiptDetail. (ispSHPSO01)'
         GOTO QUIT_SP
      END

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      BEGIN TRAN
      IF @c_RealTimeShip = '1'
      BEGIN
         --(Wan01) - START
         --UPDATE PICKDETAIL WITH (ROWLOCK)
         --SET Status = '9'
         --WHERE PickDetailKey = @c_ExternLineNo
         --AND Status < '9'


         UPDATE PICKDETAIL WITH (ROWLOCK)
         SET Status = '9'
         FROM PICKDETAIL   PD
         JOIN ORDERDETAIL  OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey) AND (OD.OrderLineNumber = PD.OrderLineNumber)
--         WHERE OD.Externorderkey = @c_ExternReceiptkey
--          AND  OD.ExternLineNo   = @c_ExternLineNo
--          AND  OD.Storerkey      = @c_Storerkey
--          AND  OD.Sku            = @c_Sku
         WHERE OD.OrderKey        = @cOrderKey
           AND OD.OrderLineNumber = @cOrderLineNumber  -- Chee01
           AND PD.Status < '9'
         --(Wan01) - END
      END
      ELSE
      BEGIN
         --(Wan01) - START
         --UPDATE PICKDETAIL WITH (ROWLOCK)
         --SET ShipFlag = 'Y'
         --   ,Trafficcop = NULL
         --   ,EditDate   = GETDATE()
         --   ,EditWho    = SUSER_NAME()
         --WHERE PickDetailKey = @c_ExternLineNo
         --AND Status < '9'

         UPDATE PICKDETAIL WITH (ROWLOCK)
         SET ShipFlag = 'Y'
            ,Trafficcop = NULL
            ,EditDate   = GETDATE()
            ,EditWho    = SUSER_NAME()
         FROM PICKDETAIL   PD
         JOIN ORDERDETAIL  OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey) AND (OD.OrderLineNumber = PD.OrderLineNumber)
--         WHERE OD.Externorderkey = @c_ExternReceiptkey
--          AND  OD.ExternLineNo   = @c_ExternLineNo
--          AND  OD.Storerkey      = @c_Storerkey
--          AND  OD.Sku            = @c_Sku
         WHERE OD.OrderKey        = @cOrderKey
           AND OD.OrderLineNumber = @cOrderLineNumber   -- Chee01
           AND  PD.Status < '9'
         --(Wan01) - END
      END

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err      = 63510
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On PickDetail. (ispSHPSO01)'
         GOTO QUIT_SP
      END

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      FETCH NEXT FROM CUR_PICK INTO @c_ExternReceiptkey
                                  , @c_ExternLineNo
                                  , @c_Sku
                                  , @c_Packkey
                                  , @c_UOM
--                                  , @c_Lottable01
                                  , @c_Lottable02
                                  , @c_Lottable03
--                                  , @dt_Lottable04
--                                  , @dt_Lottable05
                                  , @n_QtyExpected
                                  , @cOrderKey           -- Chee01
                                  , @cOrderLineNumber    -- Chee01
   END
   CLOSE CUR_PICK
   DEALLOCATE CUR_PICK

   -- Chee01
   SET @cOrderKey          = ''
   SET @cOrderLineNumber   = ''

   BEGIN TRAN

   DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RTRIM(PD.LabelNo)
         ,RTRIM(PD.Storerkey)
         ,RTRIM(PD.Sku)
         ,ISNULL(PD.Qty,0)
   FROM PACKHEADER   PH WITH (NOLOCK)
   JOIN PACKDETAIL   PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   WHERE PH.Orderkey = @c_Orderkey
   ORDER BY PD.CartonNo
         ,  RTRIM(PD.LabelNo)

   OPEN CUR_UCC

   FETCH NEXT FROM CUR_UCC INTO @c_UCCNo
                              , @c_Storerkey
                              , @c_Sku
                              , @n_Qty

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      -- Chee01
      SELECT TOP 1
         @cOrderKey = RTRIM(OrderKey),
         @cOrderLineNumber = RTRIM(OrderLineNumber)
      FROM PickDetail (NOLOCK)
      WHERE Dropid = @c_UCCNo
        AND Storerkey = @c_Storerkey
        AND SKU = @c_Sku

      IF NOT EXISTS ( SELECT 1
                      FROM UCC WITH (NOLOCK)
                      WHERE UCCNo = @c_UCCNo
                      AND   Storerkey = @c_Storerkey
                      AND   Sku       = @c_Sku)
      BEGIN
         INSERT INTO UCC
                  (  UCCNo
                  ,  Storerkey
                  ,  Sku
                  ,  Qty
                  ,  ExternKey
                  ,  SourceKey
                  ,  SourceType
                  ,  Status
                  ,  Userdefined03    -- Chee01
                  )
         VALUES   (  @c_UCCNo
                  ,  @c_StorerKey
                  ,  @c_Sku
                  ,  @n_Qty
                  ,  @c_ExternReceiptKey
                  ,  @c_Orderkey
                  ,  'CANCSO'
                  ,  '0'
                  ,  @cOrderKey + @cOrderLineNumber   -- Chee01
                  )

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err      = 63507
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On UCC. (ispSHPSO01)'
            GOTO QUIT_SP
         END
      END
      ELSE
      BEGIN
         UPDATE UCC WITH (ROWLOCK)
         SET Qty       = @n_Qty
            ,ExternKey = @c_ExternReceiptKey
            ,SourceKey = @c_Orderkey
            ,SourceType= 'CANCSO'
            ,Status    = '0'
            ,Lot       = ''
            ,Loc       = ''
            ,ID        = ''
            ,UserDefined05 = ''
            ,UserDefined06 = ''
            ,UserDefined03 = RTRIM(@cOrderKey) + RTRIM(@cOrderLineNumber)   -- Chee01
         WHERE UCCNo = @c_UCCNo
         AND   Storerkey = @c_Storerkey	--SOS330239
         AND   Sku       = @c_Sku			--SOS330239

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err      = 63508
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On UCC. (ispSHPSO01)'
            GOTO QUIT_SP
         END
      END

      FETCH NEXT FROM CUR_UCC INTO @c_UCCNo
                                 , @c_Storerkey
                                 , @c_Sku
                                 , @n_Qty

   END
   CLOSE CUR_UCC
   DEALLOCATE CUR_UCC

   IF EXISTS(SELECT 1 FROM ORDERDETAIL WITH (NOLOCK)
            WHERE OrderKey = @c_OrderKey
            AND   Status < '9')
   BEGIN
      UPDATE ORDERDETAIL WITH (ROWLOCK)
      SET Status = '9'
         ,TrafficCop = NULL
         ,EditDate   = GETDATE()
         ,EditWho    = SUSER_NAME()
      WHERE OrderKey = @c_OrderKey
      AND   Status < '9'

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err=63509   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table OrderDetail. (isp_ShipOrder)'
         GOTO QUIT_SP
      END
   END

   UPDATE ORDERS WITH (ROWLOCK)
   SET Status = '9'
      ,TrafficCop = NULL
      ,EditDate   = GETDATE()
      ,EditWho    = SUSER_NAME()
   WHERE OrderKey = @c_OrderKey
   AND   Status < '9'
   AND   SOStatus = 'CANC'

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err=63510   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table Orders. (isp_ShipOrder)'
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1
               FROM LOADPLANDETAIL WITH (NOLOCK)
               WHERE OrderKey = @c_OrderKey
               AND   Status < '9' )
   BEGIN
      UPDATE LOADPLANDETAIL WITH (ROWLOCK)
      SET Status = '9'
         ,TrafficCop = NULL
         ,EditDate   = GETDATE()
         ,EditWho    = SUSER_NAME()
      WHERE OrderKey = @c_OrderKey
      AND   Status < '9'

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err=63511   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table Loadplandetail. (isp_ShipOrder)'
         GOTO QUIT_SP
      END

      SELECT @c_MinLoadStatus = ISNULL(MIN(Status),'')
      FROM LOADPLANDETAIL WITH (NOLOCK)
      WHERE Loadkey = @c_Loadkey

      IF @c_MinLoadStatus = '9'
      BEGIN
         UPDATE LOADPLAN WITH (ROWLOCK)
         SET Status = '9'
         WHERE LoadKey = @c_LoadKey
         AND   Status < '9'

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err=63512   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table Loadplan. (isp_ShipOrder)'
            GOTO QUIT_SP
         END
      END
   END

   QUIT_SP:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_PICK' ) = 0
   BEGIN
      CLOSE CUR_PICK
      DEALLOCATE CUR_PICK
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   IF @n_Continue = '3'
   BEGIN
      IF @c_ASNCreatedMsg <> ''
      BEGIN
         SET @c_ErrMsg = @c_ASNCreatedMsg + ' with following Error: ' + CHAR(13) + @c_ErrMsg
      END
   END
   ELSE
   BEGIN
      SET @c_ErrMsg = 'Ship Successfully. ' + @c_ASNCreatedMsg + '.'
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'ispSHPSO01'
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- Procedure



GO