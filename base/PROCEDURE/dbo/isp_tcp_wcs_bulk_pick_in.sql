SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_TCP_WCS_BULK_PICK_IN                           */
/* Creation Date: 05-Jul-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: MCTang                                                   */
/*                                                                      */
/* Purpose: Picking from Bulk to Induction                              */
/*          RedWerks to WMS Exceed                                      */
/*                                                                      */
/* Input Parameters:  @c_MessageNum    - Unique no for Incoming data    */
/*                                                                      */
/* Output Parameters: @b_Success       - Success Flag  = 0              */
/*                    @n_Err           - Error Code    = 0              */
/*                    @c_ErrMsg        - Error Message = ''             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 09-01-2012   ChewKP    1.1   Standardize ConsoOrderKey Mapping       */
/*                              (ChewKP01)                              */
/* 18-01-2012   ChewKP    1.2   Fixes to RollBack Transaction when error*/
/*                              (ChewKP02)                              */
/* 22-01-2012   ChewKP    1.3   Fixes:Should not consider               */
/*                              Pickdetail.Status=4 when updating       */
/*                              (ChewKP03)                              */
/* 22-01-2012   ChewKP    1.4   Offset of Qty should consider UCC.Qty   */
/*                              (ChewKP04)                              */
/* 25-01-2012   ChewKP    1.5   QtyToMove shall consider other          */
/*                              Allocated Qty on the same SKU same Loc  */
/*                              (ChewKP05)                              */
/* 25-01-2012   ChewKP    1.6   FROMLoc  = Shelving No need to perform  */
/*                              Move and UCC validation (ChewKP06)      */
/* 13-03-2012   ChewKP    1.7   Remove Creation of PickHeader (ChewKP07)*/
/* 29-03-2012   Ung       1.8   Fixed to move QTY residual instead of   */
/*                              move QTY alloc to induction LOC         */
/* 05-04-2012   Shong     1.9   Allow Non UCC with LPN# Start with "C"  */
/* 05-04-2012   James     2.0   Change dropid field length (james01)    */
/* 10-04-2012   Ung       2.1   Support GOH LOCCat without UCC (ung01)  */
/* 16-04-2012   Shong     2.2   Transfer Residual Move to Release Wave  */
/* 02-05-2012   James     2.3   Remove UCC validation (james02)         */
/* 02-05-2012   Shong     2.4   Insert RefKeyLookUp Records if Not Exts */
/* 03-05-2012   Ung       2.5   Update UCC.Status                       */
/* 03-09-2012   Leong     2.6   SOS# 254851 - Standardize in progress   */
/*                              update for table TCPSOCKET_INLOG        */
/* 07-09-2012   Leong     2.7   SOS# 255550 - Insert RefKeyLookUp with  */
/*                                            EditWho                   */
/* 21-09-2012   Leong     2.7   SOS# 256937 - Insert PickDetail with    */
/*                              @c_PickSlipNo                           */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_TCP_WCS_BULK_PICK_IN]
                @c_MessageNum NVARCHAR(10)
              , @b_Debug      INT
              , @b_Success    INT        OUTPUT
              , @n_Err        INT        OUTPUT
              , @c_ErrMsg     NVARCHAR(250)  OUTPUT

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExecStatements     NVARCHAR(4000)
         , @c_ExecArguments      NVARCHAR(4000)
         , @n_Continue           INT
         , @n_StartTCnt          INT

   DECLARE @n_SerialNo           INT
         , @c_Status             NVARCHAR(1)
         , @c_ListName           NVARCHAR(10)
         , @c_CodelkupCode       NVARCHAR(30)

         , @c_DataString            NVARCHAR(4000)
         , @c_InMsgType             NVARCHAR(15)
         , @c_StorerKey             NVARCHAR(15)
         , @c_Facility              NVARCHAR(5)
         , @c_LPNNo                 NVARCHAR(20)       -- (james01)
         , @c_OrderKey              NVARCHAR(10)
         , @c_OrderLineNumber       NVARCHAR(5)
         , @c_ConsoOrderKey         NVARCHAR(30) --(ChewKP01)
         , @c_SKU                   NVARCHAR(20)
         , @n_Qty_Actual            INT
         , @n_Qty_Expected          INT
         , @n_Qty                   INT
         , @n_Qty_PD                INT
         , @n_Qty_MV                INT
         , @n_Qty_TOPICK            INT
         , @n_FromQtyToTake         INT
         , @n_AvailableQty          INT
         , @c_FROMLOC               NVARCHAR(10)
         , @c_TOLOC                 NVARCHAR(10)
         , @c_TXCODE                NVARCHAR(5)
         , @c_PickSlipNo            NVARCHAR(10)
         , @c_LoadKey               NVARCHAR(10)
         , @c_PickDetailKey         NVARCHAR(18)
         , @c_NewPickDetailKey      NVARCHAR(18)
         , @c_LOT                   NVARCHAR(10)
         , @c_FromLot               NVARCHAR(10)
         , @c_FromID                NVARCHAR(18)
         , @n_FromQty               INT
         , @c_PackKey               NVARCHAR(10)
         , @c_UOM                   NVARCHAR(10)
         , @c_authority_PICKCFMLOG  NVARCHAR(1)
         , @c_TableNamePick         NVARCHAR(30)
         , @n_UCCQty                INT         --(ChewKP04)
         , @n_AllocatedQty          INT         --(ChewKP05)
         --, @c_UCCLot                NVARCHAR(10) --(ChewKP05)
         , @c_LocationCategory1     NVARCHAR(10) --(ChewKP06)
         , @c_LocationCategory2     NVARCHAR(10) --(ung01)
         --, @c_BUSR7Code             NVARCHAR(30) --(ChewKP06)
         ,@c_AlertMessage           NVARCHAR(255)

   SELECT @n_Continue = 1, @b_Success = 1, @n_Err = 0
   SET @n_StartTCnt = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN WCS_BULK_PICK

   SET @c_ListName         = 'WCSROUTE'
   SET @c_CodelkupCode     = 'CASE'
   SET @c_ErrMsg           = ''
   SET @c_Status           = '9'

   SET @n_SerialNo         = 0
   SET @c_DataString       = ''
   SET @c_InMsgType        = ''
   SET @c_StorerKey        = ''
   SET @c_Facility         = ''
   SET @c_LPNNo            = ''
   SET @c_OrderKey         = ''
   SET @c_OrderLineNumber  = ''
   SET @c_ConsoOrderKey    = ''
   SET @c_SKU              = ''
   SET @n_Qty_Actual       = 0
   SET @n_Qty_Expected     = 0
   SET @n_Qty              = 0
   SET @n_Qty_PD           = 0
   SET @n_Qty_MV           = 0
   SET @n_Qty_TOPICK       = 0
   SET @n_FromQtyToTake    = 0
   SET @n_AvailableQty     = 0
   SET @c_FROMLOC          = ''
   SET @c_ToLoc            = ''
   SET @c_TXCODE           = ''
   SET @c_PickSlipNo       = ''
   SET @c_LoadKey          = ''
   SET @c_PickDetailKey    = ''
   SET @c_NewPickDetailKey = ''
   SET @c_LOT              = ''
   SET @c_FromLot          = ''
   SET @c_FromID           = ''
   SET @n_FromQty          = 0
   SET @c_TableNamePick    = 'PICKCFMLOG'
   SET @n_UCCQty           = 0  --(ChewKP04)
   SET @n_AllocatedQty     = 0  --(ChewKP05)
   --SET @c_UCCLot           = '' --(ChewKP05)
   SET @c_LocationCategory1= 'SHELVING' --(ChewKP06)
   SET @c_LocationCategory2= 'GOH' --(ung01)
   --SET @c_BUSR7Code        = 'JEWELRY' -- (ChewKP06)

   SELECT @n_SerialNo   = SerialNo
        , @c_DataString = ISNULL(RTRIM(DATA), '')
   FROM   dbo.TCPSocket_INLog WITH (NOLOCK)
   WHERE  MessageNum    = @c_MessageNum
   AND    MessageType   = 'RECEIVE'
   AND    Status        = '0'

   IF ISNULL(RTRIM(@n_SerialNo),'') = ''
   BEGIN
      IF @b_Debug = 1
      BEGIN
         SELECT 'Nothing to process. MessageNo = ' + @c_MessageNum
      END

      RETURN
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '@n_SerialNo : ' + CONVERT(VARCHAR, @n_SerialNo)
         + ', @c_Status : ' + @c_Status
           + ', @c_DataString : ' + @c_DataString
   END

   UPDATE dbo.TCPSOCKET_INLOG WITH (ROWLOCK) -- SOS# 254851
   SET Status = '1'
   WHERE SerialNo = @n_SerialNo

   IF ISNULL(RTRIM(@c_DataString),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Data String is empty. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
      GOTO QUIT_SP
   END

   SELECT @c_InMsgType        = MessageType
        , @c_StorerKey        = StorerKey
        , @c_Facility         = Facility
        , @c_LPNNo            = LPNNo
        , @c_OrderKey         = OrderKey
        , @c_OrderLineNumber  = OrderLineNumber
        , @c_ConsoOrderKey    = ConsoOrderKey
        , @c_SKU              = SKU
        , @n_Qty_Expected     = Qty_Expected
        , @n_Qty_Actual       = Qty_Actual
        , @c_FROMLOC          = FROMLOC
        , @c_TOLOC            = TOLOC
        , @c_TXCODE           = TransCode
   FROM fnc_GetTCPBULKPICK( @n_SerialNo )

   IF @b_Debug = 1
   BEGIN
      SELECT '@c_InMsgType : '         + @c_InMsgType
           + ', @c_StorerKey : '       + @c_StorerKey
           + ', @c_Facility : '        + @c_Facility
           + ', @c_LPNNo : '           + @c_LPNNo
           + ', @c_OrderKey : '        + @c_OrderKey
           + ', @c_OrderLineNumber : ' + @c_OrderLineNumber

      SELECT '@c_ConsoOrderKey : '  + @c_ConsoOrderKey
           + ', @c_SKU : '          + @c_SKU
           + ', @n_Qty_Actual : '   + CONVERT(VARCHAR, @n_Qty_Actual)
           + ', @n_Qty_Expected : ' + CONVERT(VARCHAR, @n_Qty_Expected)
           + ', @c_TOLOC : '        + @c_TOLOC
           + ', @c_TXCODE : '       + @c_TXCODE
   END

   IF ISNULL(RTRIM(@c_InMsgType),'') <> 'ALLOCMOVE'
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Invalid MessageType:' + ISNULL(RTRIM(@c_InMsgType), '') + ' for process. Seq#: '
                    + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
      GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_StorerKey),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. StorerKey is empty. Seq#: '
                    + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
      GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_OrderKey),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. OrderKey is empty. Seq#: '
                    + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
      GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_OrderLineNumber),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Order Line Number is empty. Seq#: '
                    + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
      GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_SKU),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Sku is empty. Seq#: '
                    + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
      GOTO QUIT_SP
   END

   -- (ChewKP06)
--   SELECT @c_BUSR7 = ISNULL(BUSR7,'')
--   FROM SKU WITH (NOLOCK)
--   WHERE StorerKey = @c_StorerKey
--   AND   SKU       = @c_SKU



   -- (ChewKP06)
   --IF @c_BUSR7 <> @c_BUSR7Code
-- james02
--   IF NOT EXISTS (SELECT 1 FROM dbo.Loc WITH (NOLOCK)
--                  WHERE Loc = @c_FROMLOC
--                  AND LocationCategory IN (@c_LocationCategory1, @c_LocationCategory2)) --(ung01)
--   BEGIN
--      -- (ChewKP04)
--      IF NOT EXISTS (SELECT 1 FROM UCC WITH (NOLOCK)
--                     WHERE UCCNo = @c_LPNNo
--                     AND SKU = @c_SKU
--                     AND StorerKey = @c_StorerKey)
--      BEGIN
--         IF LEFT(@c_LPNNo,1) <> 'C' OR LEN(@c_LPNNo) <> 10
--         BEGIN
--            SET @n_Continue = 3
--            SET @c_Status = '5'
--            SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. OrderKey: ' + ISNULL(RTRIM(@c_OrderKey),'')
--                          + ', LPNNo: ' + ISNULL(RTRIM(@c_LPNNo),'')
--                          + ' NOT exists in UCC Table. Seq#: '
--                          + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
--            GOTO QUIT_SP
--         END
--         ELSE
--         BEGIN
--            SET @c_AlertMessage = 'NON UCC# ' + @c_LPNNo + ' Scanned in WCS ALLOCMOVE. From Loc: ' +
--                              @c_FROMLOC + ' SKU: ' + @c_SKU
--            EXEC nspLogAlert
--            @c_modulename = 'isp_TCP_WCS_BULK_PICK_IN',
--            @c_AlertMessage =  @c_AlertMessage,
--            @n_Severity = '0',
--            @b_success = 1,
--            @n_err = 0,
--            @c_errmsg = ''
--         END
--      END
--   END

   IF NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)
                  WHERE OrderKey       = @c_OrderKey
                  AND OrderLineNumber  = @c_OrderLineNumber
                  AND StorerKey        = @c_StorerKey
                  AND SKU              = @c_SKU
                  AND LOC              = @c_FROMLOC)
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. OrderKey: ' + ISNULL(RTRIM(@c_OrderKey),'')
                    + ', OrderLineNumber: ' + ISNULL(RTRIM(@c_OrderLineNumber),'') + ', Loc: ' + ISNULL(RTRIM(@c_FROMLOC),'')
                    + ' NOT exists in PickDetail Table. Seq#: '
                    + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
      GOTO QUIT_SP
   END

   /***************************************************/
   /* Insert PickingInfo                              */
   /***************************************************/

   -- (ChewKP07)
   -- Get LoadKey
   SELECT @c_LoadKey = ISNULL(RTRIM(O.LoadKey),'')
   FROM dbo.Orders O WITH (NOLOCK)
   WHERE O.Orderkey = @c_Orderkey

   -- Get PickSlipNo
   SELECT @c_PickSlipNo = PickHeaderKey
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE ConsoOrderKey = @c_ConsoOrderKey

   IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
   BEGIN
      INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID)
      VALUES (@c_PickSlipNo, GetDate(), SUSER_SNAME())

      SET @n_Err = @@ERROR

      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_Status = '5'
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20030
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert PickIngInfo Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
         GOTO QUIT_SP
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT >0
            COMMIT TRAN
      END

      IF @b_Debug = 1
      BEGIN
         SELECT 'PickingInfo created. @c_PickSlipNo : ' + @c_PickSlipNo
      END
   END  --IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)

   BEGIN TRAN

   /***************************************************/
   /* Insert Transmitlog3 for PICKCFMLOG              */
   /***************************************************/
   SET @c_authority_PICKCFMLOG = ''

   EXECUTE dbo.nspGetRight @c_Facility,
                           @c_StorerKey,            -- Storer
                           '',                      -- Sku
                           @c_TableNamePick,        -- ConfigKey
                           @b_Success               OUTPUT,
                           @c_authority_PICKCFMLOG  OUTPUT,
                           @n_Err                   OUTPUT,
                           @c_ErrMsg                OUTPUT

   IF @b_Success <> 1
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20031
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(Char(5),@n_Err) + ': Retrieve of Right (PICKCFMLOG) Failed. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
                       + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
      GOTO QUIT_SP
   END

   IF @c_authority_PICKCFMLOG = '1'
   BEGIN
      EXEC dbo.ispGenTransmitLog3 @c_TableNamePick
                                , @c_OrderKey
                                , ''
                                , @c_StorerKey
                                , ''
                                , @b_Success   OUTPUT
                                , @n_Err       OUTPUT
                        , @c_ErrMsg    OUTPUT

      IF @b_Success <> 1
      BEGIN
         SELECT @n_continue = 3
         SET @c_Status = '5'
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20032
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(Char(5),@n_Err) + ': Insert Transmitlog3 (PICKCFMLOG) Failed. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
         GOTO QUIT_SP
      END
      ELSE
    BEGIN
         WHILE @@TRANCOUNT >0
            COMMIT TRAN
    END

   END

   BEGIN TRAN

   /***************************************************/
   /* Update PickDetail                               */
   /***************************************************/
   SET @n_Qty = @n_Qty_Actual

   SET @n_Qty_PD = 0
   SET @n_Qty_MV = 0
   SET @n_Qty_TOPICK = 0

   SELECT @n_Qty_PD = ISNULL(SUM(PD.QTY), 0)
   FROM   dbo.PickDetail PD WITH (NOLOCK)
   WHERE  PD.OrderKey = @c_OrderKey
   AND    PD.OrderLineNumber = @c_OrderLineNumber
   AND    PD.LOC = @c_FROMLOC
   AND    PD.Status < '5'

   -- (ChewKP04)
   --IF @n_Qty > @n_Qty_PD
   --BEGIN
   --   SET @n_Qty_TOPICK = @n_Qty_PD
   --   SET @n_Qty_MV = @n_Qty - @n_Qty_PD
   --END
   --ELSE -- @n_Qty =< @n_Qty_PD
   --BEGIN
      SET @n_Qty_TOPICK = @n_Qty
   --END

   IF @b_Debug = 1
   BEGIN
      SELECT '@n_Qty_TOPICK : ' + CONVERT(VARCHAR, @n_Qty_TOPICK)
           + ', @n_Qty_MV : ' + CONVERT(VARCHAR, @n_Qty_MV)
   END

   DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PD.PickDetailKey
        , PD.QTY
        , PD.LOT
   FROM   dbo.PickDetail PD WITH (NOLOCK)
   WHERE  PD.OrderKey = @c_OrderKey
   AND    PD.OrderLineNumber = @c_OrderLineNumber
   AND    PD.LOC = @c_FROMLOC
   AND    PD.Status < '4' -- (ChewKP03)
   ORDER BY PD.PickDetailKey

   OPEN CursorPickDetail
   FETCH NEXT FROM CursorPickDetail INTO @c_PickDetailKey, @n_Qty_PD, @c_LOT
   WHILE @@FETCH_STATUS<>-1
   BEGIN
      IF @b_Debug = 1
      BEGIN
         SELECT '@c_PickDetailKey : ' + ISNULL(RTRIM(@c_PickDetailKey),'')
              + ', @n_Qty_TOPICK : ' + CONVERT(VARCHAR, @n_Qty_TOPICK)
              + ', @n_Qty_PD : ' + CONVERT(VARCHAR, @n_Qty_PD)
              + ', @c_LOT : ' + ISNULL(RTRIM(@c_LOT),'')
      END

      IF @n_Qty_PD = @n_Qty_TOPICK OR @n_Qty_PD < @n_Qty_TOPICK
      BEGIN
         UPDATE dbo.PickDetail WITH (ROWLOCK)
         SET    DropID = @c_LPNNo
              , PickSlipNo = @c_PickSlipNo
              , Trafficcop = NULL
         WHERE  PickDetailKey = @c_PickDetailKey

         SET @n_Err = @@ERROR

         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20033
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Update Pickdetail Fail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
            GOTO QUIT_SP
         END

         UPDATE dbo.PickDetail WITH (ROWLOCK)
         SET    STATUS = '5'
         WHERE  PickDetailKey = @c_PickDetailKey
         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20034
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Update Pickdetail Fail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
            GOTO QUIT_SP
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookup (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)
         BEGIN
            INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey, EditWho) -- SOS# 255550
            VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_LoadKey, 'TCP02a.' + sUser_sName())

            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20035
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert RefKeyLookup Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               GOTO QUIT_SP
            END
         END
         IF EXISTS (SELECT 1 FROM dbo.RefKeyLookup (NOLOCK) WHERE OrderKey = @c_OrderKey
                    AND OrderLineNumber = @c_OrderLineNumber AND ISNULL(RTRIM(PickSlipNo),'') = '') -- SOS# 255550
         BEGIN
            UPDATE dbo.RefKeyLookup WITH (ROWLOCK)
            SET    PickSlipNo = @c_PickSlipNo
            WHERE  OrderKey = @c_OrderKey
            AND    OrderLineNumber = @c_OrderLineNumber
            AND    ISNULL(RTRIM(PickSlipNo),'') = ''

            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SET @n_Err = 20044
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5), @n_Err) + ': Update RefKeyLookup Fail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' )'
               GOTO QUIT_SP
            END
         END         
      END
      ELSE --IF @n_Qty_PD > @n_Qty_TOPICK
      BEGIN

         EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10,
               @c_NewPickDetailKey OUTPUT,
               @b_Success          OUTPUT,
               @n_Err              OUTPUT,
               @c_ErrMsg           OUTPUT

         IF @b_Success<>1
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20036
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to retrieve new PickdetailKey. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
            GOTO QUIT_SP
         END

         -- Create a new PickDetail to hold the balance
         INSERT INTO dbo.PICKDETAIL
            (
              CaseID               ,PickHeaderKey     ,OrderKey
             ,OrderLineNumber      ,LOT               ,StorerKey
             ,SKU                  ,AltSKU            ,UOM
             ,UOMQTY               ,QTYMoved          ,STATUS
             ,DropID               ,LOC               ,ID
             ,PackKey              ,UpdateSource      ,CartonGroup
             ,CartonType           ,ToLoc             ,DoReplenish
             ,ReplenishZone        ,DoCartonize       ,PickMethod
             ,WaveKey              ,EffectiveDate     ,ArchiveCop
             ,ShipFlag             ,PickSlipNo        ,PickDetailKey
             ,QTY
             ,TrafficCop
             ,OptimizeCop
             ,TaskDetailkey
            )
         SELECT CaseID             ,PickHeaderKey     ,OrderKey
             ,OrderLineNumber      ,Lot               ,StorerKey
             ,SKU                  ,AltSku            ,UOM
             ,UOMQTY               ,QTYMoved          ,STATUS
             ,''                   ,LOC               ,ID
             ,PackKey              ,UpdateSource      ,CartonGroup
             ,CartonType           ,ToLoc             ,DoReplenish
             ,ReplenishZone        ,DoCartonize       ,PickMethod
             ,WaveKey              ,EffectiveDate     ,ArchiveCop
             ,ShipFlag             ,@c_PickSlipNo     ,@c_NewPickDetailKey -- SOS# 256937
             ,@n_Qty_PD-@n_Qty_TOPICK
             ,NULL
             ,'1'
             ,TaskDetailkey
         FROM   dbo.PickDetail WITH (NOLOCK)
         WHERE  PickDetailKey = @c_PickDetailKey

         SET @n_Err = @@ERROR

         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20037
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to Insert new Pickdetail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
            GOTO QUIT_SP
         END

         -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
         -- Change orginal PickDetail with exact QTY (with TrafficCop)
         UPDATE dbo.PickDetail WITH (ROWLOCK)
         SET    QTY = @n_Qty_TOPICK
              , DropID = @c_LPNNo
              , PickSlipNo = @c_PickSlipNo
              , Trafficcop = NULL
         WHERE  PickDetailKey = @c_PickDetailKey

         SET @n_Err = @@ERROR

         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20038
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to Update Pickdetail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
            GOTO QUIT_SP
         END

         -- Confirm orginal PickDetail with exact QTY
         UPDATE dbo.PickDetail WITH (ROWLOCK)
         SET    STATUS = '5'
         WHERE  PickDetailKey = @c_PickDetailKey

         SET @n_Err = @@ERROR

         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20039
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to Update Pickdetail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
            GOTO QUIT_SP
         END
         -- Insert RefKeyLookup, if not exists
         IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookup (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)
         BEGIN
            INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey, EditWho) -- SOS# 255550
            VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_LoadKey, 'TCP02b.' + sUser_sName())

            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20040
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert RefKeyLookup Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               GOTO QUIT_SP
            END

         END
         IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookup (NOLOCK) WHERE PickDetailKey = @c_NewPickDetailKey)
         BEGIN
            INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey, EditWho) -- SOS# 255550
            VALUES (@c_NewPickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_LoadKey, 'TCP02c.' + sUser_sName())

            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20040
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert RefKeyLookup Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               GOTO QUIT_SP
            END
         END
         
         IF EXISTS (SELECT 1 FROM dbo.RefKeyLookup (NOLOCK) WHERE OrderKey = @c_OrderKey
                    AND OrderLineNumber = @c_OrderLineNumber AND ISNULL(RTRIM(PickSlipNo),'') = '') -- SOS# 255550
         BEGIN
            UPDATE dbo.RefKeyLookup WITH (ROWLOCK)
            SET    PickSlipNo = @c_PickSlipNo
            WHERE  OrderKey = @c_OrderKey
            AND    OrderLineNumber = @c_OrderLineNumber
            AND    ISNULL(RTRIM(PickSlipNo),'') = ''

            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SET @n_Err = 20045
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5), @n_Err) + ': Update RefKeyLookup Fail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' )'
               GOTO QUIT_SP
            END
         END
      END --IF @n_Qty_PD > @n_Qty_TOPICK


      IF @n_Qty_TOPICK > 0
      BEGIN
         -- OffSet QtyToPick
         SET @n_Qty_TOPICK = @n_Qty_TOPICK - @n_QTY_PD
      END

      IF @n_Qty_TOPICK = 0 OR @n_Qty_TOPICK < 0
      BEGIN
         BREAK
      END

      FETCH NEXT FROM CursorPickDetail INTO @c_PickDetailKey, @n_Qty_PD, @c_LOT
   END -- While Loop for PickDetail Key
   CLOSE CursorPickDetail
   DEALLOCATE CursorPickDetail

   IF @n_Continue = 1 OR @n_Continue = 2
 BEGIN
      WHILE @@TRANCOUNT >0
         COMMIT TRAN
 END

   SELECT @c_ToLoc   = Short
   FROM   dbo.CodeLkUp WITH (NOLOCK)
   WHERE  ListName   = @c_ListName
   AND    Code       = @c_CodelkupCode

   IF ISNULL(RTRIM(@c_ToLoc),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. To Loc not found. Seq#: '
              + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
      GOTO QUIT_SP
   END

   /*  
   IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc)    
   BEGIN   
      SET @n_Continue = 3  
      SET @c_Status = '5'        
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Invalid TOLOC : ' + ISNULL(RTRIM(@c_ToLoc), '') + '. Seq#: '   
                    + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'  
      GOTO QUIT_SP        
   END  
   */  
     
   /***************************************************/   
   /* Update UCC                                      */   
   /***************************************************/  
   -- Added By SHONG on 5-Apr-2012    
   IF EXISTS(SELECT 1 FROM UCC WITH (NOLOCK)    
             WHERE UCCNo      = @c_LPNNo  
             AND   StorerKey  = @c_StorerKey    
             AND   SKU        = @c_SKU)  
   BEGIN  
      UPDATE dbo.UCC WITH (ROWLOCK) SET
         Loc    = @c_ToLoc, 
         Status = '6'
      WHERE UCCNo      = @c_LPNNo  
      AND   StorerKey  = @c_StorerKey    
      AND   SKU        = @c_SKU    

      SET @n_Err = @@ERROR

      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_Status = '5'
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20041
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert UCC Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
         GOTO QUIT_SP
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT >0
            COMMIT TRAN
      END
   END

--   /***************************************************/
--   /* Perform MOVE                                    */
--   /***************************************************/
--   SET @n_FromQtyToTake = 0
--
--   -- (ChewKP06)
--   --IF @c_BUSR7 <> @c_BUSR7Code
--   IF NOT EXISTS (SELECT 1 FROM dbo.Loc WITH (NOLOCK)
--                  WHERE Loc = @c_FROMLOC
--                  AND LocationCategory in (@c_LocationCategory1, @c_LocationCategory2)) --(ung01)
--   BEGIN
--      -- (ChewKP04)
--      SET @n_UCCQty = 0
--
--      SELECT @n_UCCQty = Qty
--            --,@c_UCCLot = Lot -- (ChewKP05)
--      FROM UCC WITH (NOLOCK)
--      WHERE UCCNo       = @c_LPNNo
--      AND   SKU         = @c_SKU
--      AND   StorerKey   = @c_StorerKey
--      AND   Loc         = @c_ToLoc
--      IF @n_UCCQty = 0
--      BEGIN
--         SELECT @n_UCCQty = dbo.fnc_GetLocUccPackSize(@c_StorerKey, @c_SKU, @c_FromLoc)
--
--         IF @n_UCCQty IS NULL
--            SET @n_UCCQty = 0
--      END
--
--      -- (ChewKP05)
--      SELECT @n_AllocatedQty = SUM(QTY - QTYALLOCATED - QTYPICKED -
--                        (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
--      FROM LotxLocxID WITH (NOLOCK)
--      WHERE StorerKey = @c_StorerKey
--      AND   SKU       = @c_SKU
--      AND   LOC       = @c_FROMLOC
--      -- AND   Lot       = @c_UCCLot
--      AND   QTY - QtyPicked - QtyAllocated - QtyReplen > 0
--
--      -- Check Pick QTY > UCC QTY
--      IF @n_Qty_Actual > @n_UCCQty
--      BEGIN
--         SET @n_Continue = 3
--         SET @c_Status = '5'
--         SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Pick QTY > UCC QTY. Seq#: '
--                 + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
--         GOTO QUIT_SP
--      END
--
--      -- (ChewKP05)
--      IF @n_AllocatedQty >= (@n_UCCQty - @n_Qty_Actual) --> residual
--      BEGIN
--         --SET @n_Qty_MV = @n_AllocatedQty - @n_UCCQty
--         SET @n_Qty_MV = (@n_UCCQty - @n_Qty_Actual)
--      END
--      ELSE
--      BEGIN
--         --SET @n_Qty_MV = @n_AllocatedQty
--         SET @n_Continue = 3
--         SET @c_Status = '5'
--         SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Insufficient FromQty to move. Seq#: '
--                 + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
--         GOTO QUIT_SP
--      END
--
--      IF @b_Debug = 1
--      BEGIN
--         SELECT '  @n_UCCQty : '       + CAST(@n_UCCQty AS NVARCHAR(5))
--              --+ ', @c_UCCLot : '       + @c_UCCLot
--              + ', @n_AllocatedQty : ' + CAST(@n_AllocatedQty AS NVARCHAR(5))
--              + ', @n_Qty_MV : '       + CAST(@n_Qty_MV AS NVARCHAR(5))
--
--      END
--
----------------------------------------------
---- Temporary Do this until we found out the solution
---- From Shong
--SET @n_Qty_MV = 0
----------------------------------------------
--      IF @n_Qty_MV > 0
--      BEGIN
--
--         SELECT @c_PackKey = SKU.PackKey
--              , @c_UOM     = PACK.PACKUOM3
--         FROM   dbo.SKU WITH (NOLOCK)
--         JOIN   dbo.PACK WITH (NOLOCK) ON SKU.PACKKEY = PACK.PackKey
--         WHERE  StorerKey = @c_StorerKey
--         AND    SKU = @c_SKU
--
--         IF @b_Debug = 1
--         BEGIN
--            SELECT '@c_PackKey : ' + ISNULL(RTRIM(@c_PackKey),'')
--                 + ', @c_UOM : ' + ISNULL(RTRIM(@c_UOM),'')
--         END
--
--     IF ISNULL(RTRIM(@c_PackKey),'') = ''
--         BEGIN
--            SET @n_Continue = 3
--            SET @c_Status = '5'
--            SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Packkey not found. Seq#: '
--                    + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
--            GOTO QUIT_SP
--         END
--
--         SET @n_AvailableQty = 0
--
--         SELECT @n_AvailableQty = SUM(LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
--         FROM   dbo.LOTxLOCxID LLI WITH (NOLOCK)
--         WHERE  LLI.StorerKey = @c_StorerKey
--         AND    LLI.SKU       = @c_SKU
--         AND    LLI.LOC       = @c_FromLoc
--         AND    QTY - QtyPicked - QtyAllocated - QtyReplen > 0
--
--         IF @n_AvailableQty < @n_Qty_MV
--         BEGIN
--            SET @n_Continue = 3
--            SET @c_Status = '5'
--            SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Insufficient FromQty to move. Seq#: '
--                    + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
--            GOTO QUIT_SP
--         END
--
--         -- rdt_TMDynamicPick_MoveCase
--         DECLARE CUR_LOTxLOCxID_MOVE CURSOR FAST_FORWARD READ_ONLY FOR
--         SELECT LOT,
--                ID,
--                LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)
--         FROM   dbo.LOTxLOCxID LLI WITH (NOLOCK)
--         WHERE  LLI.StorerKey = @c_StorerKey
--         AND    LLI.SKU       = @c_SKU
--         AND    LLI.LOC       = @c_FromLoc
--         AND    QTY - QtyPicked - QtyAllocated - QtyReplen > 0
--         ORDER BY LLI.Lot
--
--         OPEN CUR_LOTxLOCxID_MOVE
--
--         FETCH NEXT FROM CUR_LOTxLOCxID_MOVE INTO @c_FromLot, @c_FromID, @n_FromQty
--         WHILE @@FETCH_STATUS <> -1
--         BEGIN
--
--            IF @b_Debug = 1
--            BEGIN
--               SELECT '@n_Qty_MV : ' + CONVERT(VARCHAR,@n_Qty_MV)
--                    + ', @c_FromLot : ' + ISNULL(RTRIM(@c_FromLot),'')
--                    + ', @c_FromID : ' + ISNULL(RTRIM(@c_FromID),'')
--                    + ', @n_FromQty : ' + CONVERT(VARCHAR, @n_FromQty)
--            END
--
--            SET @n_FromQtyToTake = 0
--
--            IF @n_FromQty < 0
--            BEGIN
--               SET @n_Continue = 3
--               SET @c_Status = '5'
--               SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. FromQty < 0. Seq#: '
--                             + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_BULK_PICK_IN)'
--               GOTO QUIT_SP
--            END
--            ELSE
--            BEGIN
--               IF @n_FromQty >= @n_Qty_MV
--               BEGIN
--                  SET @n_FromQtyToTake = @n_Qty_MV
--               END
--               ELSE --IF @n_FromQty < @n_Qty_MV
--               BEGIN
--                  SET @n_FromQtyToTake = @n_FromQty
--               END
--            END
--
--            IF @b_Debug = 1
--            BEGIN
--               SELECT '@n_FromQtyToTake : ' + CONVERT(VARCHAR,@n_FromQtyToTake)
--            END
--
--            IF @n_FromQtyToTake > 0
--            BEGIN
--
--               EXECUTE nspItrnAddMove
--                  @n_ItrnSysId      = NULL,
--                  @c_itrnkey        = NULL,
--                  @c_Storerkey      = @c_StorerKey,
--                  @c_SKU            = @c_SKU,
--                  @c_Lot            = @c_FromLot,
--                  @c_FromLoc        = @c_FromLoc,
--                  @c_FromID         = @c_FromID,
--                  @c_ToLoc          = @c_ToLoc,
--                  @c_ToID           = '',
--                  @c_Status         = '',
--                  @c_Lottable01     = '',
--                  @c_Lottable02     = '',
--                  @c_Lottable03     = '',
--                  @d_Lottable04     = NULL,
--                  @d_Lottable05     = NULL,
--                  @n_casecnt        = 0,
--                  @n_innerpack      = 0,
--                  @n_Qty            = @n_FromQtyToTake,
--                  @n_Pallet         = 0,
--                  @f_Cube           = 0,
--                  @f_GrossWgt       = 0,
--                  @f_NetWgt         = 0,
--                  @f_OtherUnit1     = 0,
--                  @f_OtherUnit2     = 0,
--                  @c_SourceKey      = @c_MessageNum,
--                  @c_SourceType     = 'isp_TCP_WCS_BULK_PICK_IN',
--                  @c_PackKey        = @c_PackKey,
--                  @c_UOM            = @c_UOM,
--                  @b_UOMCalc        = 1,
--                  @d_EffectiveDate  = NULL,
--                  @b_Success        = @b_Success   OUTPUT,
--                  @n_err            = @n_Err       OUTPUT,
--                  @c_errmsg         = @c_Errmsg    OUTPUT
--
--               IF ISNULL(RTRIM(@c_ErrMsg),'') <> ''
--               BEGIN
--                  SET @n_Continue = 3   -- (ChewKP02)
--                  SET @n_Err     = @n_Err
--                  SET @c_ErrMsg  = @c_ErrMsg
--                  GOTO QUIT_SP
--               END
--
--               SET @n_Qty_MV = @n_Qty_MV - @n_FromQtyToTake
--
--               IF @n_Qty_MV = 0
--               BEGIN
--                  BREAK
--               END
--            END -- IF @n_FromQtyToTake > 0
--
--            FETCH NEXT FROM CUR_LOTxLOCxID_MOVE INTO @c_FromLot, @c_FromID, @n_FromQty
--         END
--         CLOSE CUR_LOTxLOCxID_MOVE
--         DEALLOCATE CUR_LOTxLOCxID_MOVE
--      END --IF @n_Qty_MV > 0
--   END -- IF @c_BUSR7 <> @c_BUSR7Code
--   /***************************************************/
--   /* Perform MOVE End                                */
--   /***************************************************/

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      WHILE @@TRANCOUNT >0
         COMMIT TRAN
   END

   QUIT_SP:


   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN

   IF @b_Debug = 1
   BEGIN
      SELECT 'Update TCPSocket_INLog >> @c_Status : ' + @c_Status
           + ', @c_ErrMsg : ' + @c_ErrMsg
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      ROLLBACK TRAN WCS_BULK_PICK
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_TCP_WCS_BULK_PICK_IN'
   END

   UPDATE dbo.TCPSocket_INLog WITH (ROWLOCK)
   SET STATUS   = @c_Status
     , ErrMsg   = @c_ErrMsg
     , Editdate = GETDATE()
     , EditWho  = SUSER_SNAME()
   WHERE SerialNo = @n_SerialNo

   WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started
      COMMIT TRAN WCS_BULK_PICK

   RETURN
END

GO