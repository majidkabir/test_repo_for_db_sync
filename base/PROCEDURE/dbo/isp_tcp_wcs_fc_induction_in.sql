SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_TCP_WCS_FC_INDUCTION_IN                        */
/* Creation Date: 05-Jul-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: MCTang                                                   */
/*                                                                      */
/* Purpose: Picking FULL CASE to Induction                              */
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
/* 08-02-2012   ChewKP    1.2   Add FullCase indicator to PackInfo.RefNo*/
/*                              (ChewKP02)                              */
/* 08-02-2012   ChewKP    1.3   Revise Logic on GS1Label Generation     */
/*                              (ChewKP03)                              */
/* 08-02-2012   James     1.4   Change FullCase indicator from Y to FC  */
/*                              (james01)                               */
/* 16-02-2012   ChewKP    1.5   Avoid same LPN being packed again       */
/*                              (ChewKP04)                              */
/* 29-02-2012   ChewKP    1.6   PackHeader Fix (ChewKP08)               */
/* 07-03-2012   ChewKP    1.7   Standardize WCS GS1 Socket Process      */
/*                              (ChewKP09)                              */
/* 13-03-2012   ChewKP    1.8   Remove Creation of PickHeader & MISC    */
/*                              Fixes (ChewKP10)                        */
/* 31-03-2012   James     1.8   Remove pickdetail offset (james01)      */
/* 17-04-2012   Ung       1.9   Insert DropID record                    */
/* 25-04-2012   Ung       2.0   Fix full case QTY checking (ung01)      */
/* 02-05-2012   Ung       2.1   Remove save transaction (ung02)         */
/* 03-05-2012   Ung       2.2   Stamp UCC.Status (ung03)                */
/* 10-05-2012   Ung       2.3   SOS244076 Align FC same as CLOSECARTON  */
/*                              on offset PickDetail (ung04)            */
/* 03-09-2012   Leong     2.4   SOS# 254851 - Standardize in progress   */
/*                              update for table TCPSOCKET_INLOG        */
/* 07-09-2012   Leong     2.5   SOS# 255550 - Insert RefKeyLookUp with  */
/*                                            EditWho                   */
/* 21-09-2012   Leong     2.5   SOS# 256937 - Insert PickDetail with    */
/*                                            @c_PickSlipNo             */
/* 10-12-2012   Shong     2.5   SOS# 264161 - Update PickDetail with    */
/*                                            Sort Sequence             */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_TCP_WCS_FC_INDUCTION_IN]
     @c_MessageNum NVARCHAR(10)
   , @b_Debug      INT
   , @b_Success    INT            OUTPUT
   , @n_Err        INT            OUTPUT
   , @c_ErrMsg     NVARCHAR(250)      OUTPUT
   , @c_DeleteGS1  NVARCHAR(1) = 'Y'
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExecStatements        NVARCHAR(4000)
         , @c_ExecArguments         NVARCHAR(4000)
         , @n_Continue              INT
         , @n_StartTCnt             INT

   DECLARE @n_SerialNo              INT
         , @n_SerialNo_Out          INT
         , @c_Status                NVARCHAR(1)
         , @c_DataString            NVARCHAR(4000)
         , @c_InMsgType             NVARCHAR(15)
         , @c_StorerKey             NVARCHAR(15)
         , @c_Facility              NVARCHAR(5)
         , @c_LPNNo                 NVARCHAR(20)
         , @c_OrderKey              NVARCHAR(10)
         , @c_OrderLineNumber       NVARCHAR(5)
         , @c_ConsoOrderKey         NVARCHAR(30) -- (ChewKP01)
         , @c_SKU                   NVARCHAR(20)
         , @n_Qty                   INT
         , @n_Qty_PD                INT
         , @c_FROMLOC               NVARCHAR(10)
         , @c_TOLOC                 NVARCHAR(10)
         , @c_TXCODE                NVARCHAR(5)
         , @c_PickSlipNo            NVARCHAR(10)
         , @c_LoadKey               NVARCHAR(10)
         , @n_CartonNo              INT
         , @n_LabelLine             INT
         , @c_LabelLine             NVARCHAR(20)
         , @c_LabelNo               NVARCHAR(5)
         , @c_PickDetailKey         NVARCHAR(18)
         , @c_NewPickDetailKey      NVARCHAR(18)
         , @c_LOT                   NVARCHAR(10)
         , @c_FromLot               NVARCHAR(10)
         , @c_FromID                NVARCHAR(18)
         , @n_FromQty               INT
         , @c_PackKey               NVARCHAR(10)
         , @c_UOM                   NVARCHAR(10)
         , @c_Route                 NVARCHAR(10)
         , @c_GS1LabelNo            NVARCHAR(20)
         , @c_DischargePlace        NVARCHAR(30)
         , @c_DeliveryPlace         NVARCHAR(30)
         , @c_NewGS1Label           NVARCHAR(1)
         , @c_MessageNum_Out        NVARCHAR(10)
         , @c_Data_Out              NVARCHAR(1000)
         , @n_Status_Out            INT
         , @c_ErrMsg_Out            NVARCHAR(400)

   DECLARE @d_TempDateTime          DATETIME
         , @c_GenTemplateID         NVARCHAR(20)
         , @c_GS1TemplatePath_Gen   NVARCHAR(120)
         , @c_GS1TemplatePath_Final NVARCHAR(120)
         , @c_PrinterID             NVARCHAR(20)
         , @c_FileName              NVARCHAR(215)
         , @c_FilePath              NVARCHAR(30)
         , @c_WorkFilePath          NVARCHAR(120)
         , @c_MoveFilePath          NVARCHAR(120)
         , @c_DateTime              NVARCHAR(17)
         , @c_YYYY                  NVARCHAR(4)
         , @c_MM                    NVARCHAR(2)
         , @c_DD                    NVARCHAR(2)
         , @c_HH                    NVARCHAR(2)
         , @c_MI                    NVARCHAR(2)
         , @c_SS                    NVARCHAR(2)
         , @c_MS                    NVARCHAR(3)
         , @c_authority_PICKCFMLOG  NVARCHAR(1)
         , @c_authority_PACKCFMLOG  NVARCHAR(1)
         , @n_CntTotal              INT
         , @n_CntPrinted            INT
         , @c_TableNamePick         NVARCHAR(30)
         , @c_TableNamePack         NVARCHAR(30)
         , @n_SortSeq               INT

   SELECT @n_Continue = 1, @b_Success = 1, @n_Err = 0
   SET @n_StartTCnt = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN WCS_BULK_PICK --(ung02)

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
   SET @n_Qty              = 0
   SET @n_Qty_PD           = 0
   SET @c_FROMLOC          = ''
   SET @c_ToLoc            = ''
   SET @c_TXCODE           = ''
   SET @c_PickSlipNo       = ''
   SET @c_LoadKey          = ''
   SET @n_CartonNo  = 0
   SET @n_LabelLine        = 0
   SET @c_LabelLine        = ''
   SET @c_LabelNo          = ''
   SET @c_PickDetailKey    = ''
   SET @c_NewPickDetailKey = ''
   SET @c_LOT              = ''
   SET @c_FromLot          = ''
   SET @c_FromID           = ''
   SET @n_FromQty          = 0
   SET @c_Route            = ''
   SET @c_GS1LabelNo       = ''
   SET @c_DischargePlace   = ''
   SET @c_DeliveryPlace    = ''
   SET @c_NewGS1Label      = 'N'
   SET @c_MessageNum_Out   = ''
   SET @c_Data_Out         = ''
   SET @c_TableNamePick    = 'PICKCFMLOG'
   SET @c_TableNamePack    = 'PACKCFMLOG'

   SELECT @n_SerialNo   = SerialNo,
          @c_DataString = [Data]
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
      SET @c_ErrMsg = 'Data String is empty. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
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
        , @n_Qty              = Qty_Actual
        , @c_FROMLOC          = FROMLOC
        , @c_TOLOC            = TOLOC
        , @c_TXCODE           = TransCode
   FROM fnc_GetTCPFCInduction( @n_SerialNo )

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
           + ', @n_Qty : '          + CONVERT(VARCHAR, @n_Qty)
           + ', @c_TOLOC : '        + @c_TOLOC
           + ', @c_TXCODE : '       + @c_TXCODE
   END

   IF ISNULL(RTRIM(@c_InMsgType),'') <> 'FULLCASE'
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Invalid MessageType:' + ISNULL(RTRIM(@c_InMsgType), '') + ' for process. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
      GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_OrderKey),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. OrderKey is empty. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
      GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_OrderLineNumber),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Order Line Number is empty. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
      GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_SKU),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Sku is empty. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
      GOTO QUIT_SP
   END

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
                    + ', OrderLineNo: ' + ISNULL(RTRIM(@c_OrderLineNumber),'')
                    + ', StorerKey: ' + ISNULL(RTRIM(@c_StorerKey),'')
                    + ', SKU: ' + ISNULL(RTRIM(@c_SKU),'')
                    + ', Loc: ' + ISNULL(RTRIM(@c_FROMLOC),'')
                    + '. NOT exists in PickDetail Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
      GOTO QUIT_SP
   END


-- (ChewKP10)
   /***************************************************/
   /* Insert PickHeader                               */
   /***************************************************/
--   SELECT @c_LoadKey = ISNULL(RTRIM(O.LoadKey),'')
--        , @c_Route = ISNULL(RTRIM(O.Route),'')
--        , @c_DischargePlace = ISNULL(RTRIM(O.DischargePlace),'')
--        , @c_DeliveryPlace = ISNULL(RTRIM(O.DeliveryPlace),'')
--   FROM dbo.Orders O WITH (NOLOCK)
--   WHERE O.Orderkey = @c_Orderkey
--
--   SELECT @c_PickSlipNo = ISNULL(RTRIM(PickHeaderKey),'')
--   FROM dbo.PickHeader WITH (NOLOCK)
--   WHERE ConsoOrderKey = @c_ConsoOrderKey -- (ChewKP01)
--
--   IF @b_Debug = 1
--   BEGIN
--      SELECT '@c_PickSlipNo : ' + @c_PickSlipNo
--   END
--
--   IF ISNULL(RTRIM(@c_PickSlipNo),'') = ''
--   BEGIN
--      SET @b_Success = 0
--
--      EXECUTE nspg_GetKey
--         'PICKSLIP',
--         9,
--         @c_PickSlipNo     OUTPUT,
--         @b_Success        OUTPUT,
--         @n_Err            OUTPUT,
--         @c_ErrMsg         OUTPUT
--
--      IF @b_Success <> 1
--      BEGIN
--         SET @n_Continue = 3
--         SET @c_Status = '5'
--         SELECT @c_ErrMsg = CONVERT(char(250),@n_Err), @n_Err = 20070
--         SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err)+': Unable to retrieve PICKSLIP Number. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
--                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
--         GOTO QUIT_SP
--      END
--
--      IF @n_Continue = 1 OR @n_Continue = 2
--      BEGIN
--         SET @c_PickSlipNo = 'P' + @c_PickSlipNo
--
--         INSERT INTO dbo.PickHeader (PickHeaderKey,  ExternOrderKey, Orderkey, Zone, ConsigneeKey, ConsoOrderKey) --(ChewKP01)
--         VALUES (@c_PickSlipNo, '', '', 'LP', '',@c_ConsoOrderKey)  -- (ChewKP01)
--
--         SET @n_Err = @@ERROR
--
--         IF @n_Err <> 0
--         BEGIN
--            SET @n_Continue = 3
--            SET @c_Status = '5'
--            SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20080
--            SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert PICKHEADER Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
--                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
--            GOTO QUIT_SP
--         END
--
--         IF @b_Debug = 1
--         BEGIN
--            SELECT 'PICKHEADER created >> @c_PickSlipNo : ' + @c_PickSlipNo
--         END
--      END -- @n_Continue = 1 or @n_Continue = 2
--   END -- IF ISNULL(RTRIM(@c_PickSlipNo),'') = ''

   /***************************************************/
   /* Insert PickingInfo                              */
   /***************************************************/

   -- (ChewKP10)
   SELECT @c_LoadKey = ISNULL(RTRIM(O.LoadKey),'')
        , @c_Route = ISNULL(RTRIM(O.Route),'')
   --     , @c_DischargePlace = ISNULL(RTRIM(O.DischargePlace),'')
   --     , @c_DeliveryPlace = ISNULL(RTRIM(O.DeliveryPlace),'')
   FROM dbo.Orders O WITH (NOLOCK)
   WHERE O.Orderkey = @c_Orderkey

   SELECT @c_PickSlipNo = ISNULL(RTRIM(PickHeaderKey),'')
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE ConsoOrderKey = @c_ConsoOrderKey -- (ChewKP01)

   IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
   BEGIN

      INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, ScanOutDate, PickerID)
      VALUES (@c_PickSlipNo, GetDate(), GetDate(), SUSER_SNAME())

      SET @n_Err = @@ERROR

      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_Status = '5'
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20090
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(Char(5),@n_Err) + ': Error Insert PickingInfo Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
         GOTO QUIT_SP
      END

      IF @b_Debug = 1
      BEGIN
         SELECT 'PickingInfo created >> @c_PickSlipNo : ' + @c_PickSlipNo
      END
   END  --IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)


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
      SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20091
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(Char(5),@n_Err) + ': Retrieve of Right (PICKCFMLOG) Failed. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
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
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20092
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(Char(5),@n_Err) + ': Insert Transmitlog3 (PICKCFMLOG) Failed. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
         GOTO QUIT_SP
      END
   END

   SET @n_Qty_PD = 0

   ---- (ung04)
   SELECT @n_Qty_PD = ISNULL(SUM(PD.QTY),0)
   FROM   dbo.PickDetail PD WITH (NOLOCK)
   WHERE  PD.OrderKey = @c_OrderKey
   AND    PD.OrderLineNumber = @c_OrderLineNumber
   AND    PD.Status = '5'     -- (james01)
   AND    PD.SKU = @c_SKU
   AND    PD.CaseID = ''

   IF @n_Qty > @n_Qty_PD
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Imported Qty > PickDetail Qty. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
      GOTO QUIT_SP
   END

   /***************************************************/
   /* Generate GS1 Label                              */
   /***************************************************/
   IF ISNULL(RTRIM(@c_GS1LabelNo),'') = ''
   BEGIN
      EXECUTE isp_GenUCCLabelNo
               @c_StorerKey,
               @c_GS1LabelNo  OUTPUT,
               @b_Success     OUTPUT,
               @n_Err         OUTPUT,
               @c_ErrMsg      OUTPUT

      IF @b_Success<>1
      BEGIN
         SET @n_Continue = 3
         SET @c_Status = '5'
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20093
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to retrieve UCCLabelNo. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
         GOTO QUIT_SP
      END

      SELECT @c_NewGS1Label = 'Y'
   END

   IF @b_Debug = 1
   BEGIN
      SELECT 'Generate GS1 >> @c_GS1LabelNo : ' + @c_GS1LabelNo
   END

   --(james010
   /***************************************************/
   /* Update Pickdetail Case ID (GS1 Label)           */
   /***************************************************/
/* -- (ung04)
   UPDATE dbo.PickDetail WITH (ROWLOCK) SET
      CaseID = @c_GS1LabelNo,
      TrafficCop = NULL
   WHERE  OrderKey = @c_OrderKey
   AND    OrderLineNumber = @c_OrderLineNumber
   AND    LOC = @c_FROMLOC
   AND    Status = '5'
   AND    DropID = @c_LPNNo

   SELECT @n_Err = @@ERROR

   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20090
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Failed to Update PickDetail.CaseID. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
      GOTO QUIT_SP
   END
*/

-- (ung04)
         /***************************************************/
         /* Update PickDetail                               */
         /***************************************************/

         DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey
              , PD.QTY
              , PD.LOT
              , SortSeq = CASE
                            WHEN PD.LOC = @c_FROMLOC AND DropID = @c_LPNNo THEN 1
                            WHEN DropID = @c_LPNNo THEN 2
                            WHEN PD.LOC = @c_FROMLOC THEN 3
                            ELSE 9
                          END
         FROM   dbo.PickDetail PD WITH (NOLOCK)
         WHERE  PD.OrderKey = @c_OrderKey
         AND    PD.OrderLineNumber = @c_OrderLineNumber
         AND    PD.Status = '5'
         AND    PD.CaseID = ''
         ORDER BY SortSeq, PD.PickDetailKey

         OPEN CursorPickDetail
         FETCH NEXT FROM CursorPickDetail INTO @c_PickDetailKey, @n_Qty_PD, @c_LOT, @n_SortSeq
         WHILE @@FETCH_STATUS<>-1
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT 'Update PickDetail >> @n_Qty : ' + CONVERT(VARCHAR, @n_Qty)
                    + '@n_Qty_PD : ' + CONVERT(VARCHAR, @n_Qty_PD)
                    + '@c_LOT : ' + ISNULL(RTRIM(@c_LOT),'')
            END

            IF @n_Qty_PD = @n_Qty OR @n_Qty_PD < @n_Qty
            BEGIN

               UPDATE dbo.PickDetail WITH (ROWLOCK)
               SET    CaseID = @c_GS1LabelNo
                    , DropID = @c_LPNNo -- (ung02)
                    , Trafficcop = NULL
               WHERE  PickDetailKey = @c_PickDetailKey

               SET @n_Err = @@ERROR

               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_Status = '5'
                  SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20094
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Update Pickdetail Fail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                       + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                  GOTO QUIT_SP
               END
            END
            ELSE --IF @n_Qty_PD > @n_Qty
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
                  SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20095
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to retrieve new PickdetailKey. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
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
                   ,DropID               ,LOC               ,ID
                   ,PackKey              ,UpdateSource      ,CartonGroup
                   ,CartonType           ,ToLoc             ,DoReplenish
                   ,ReplenishZone        ,DoCartonize       ,PickMethod
                   ,WaveKey              ,EffectiveDate     ,ArchiveCop
                   ,ShipFlag             ,@c_PickSlipNo     ,@c_NewPickDetailKey -- SOS# 256937
                   ,@n_Qty_PD-@n_Qty
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
                  SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20096
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to Insert new Pickdetail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                  GOTO QUIT_SP
               END

               -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK)
               SET    QTY = @n_Qty
                    , CaseID = @c_GS1LabelNo
                    , DropID = @c_LPNNo -- (ung02)
                    , Trafficcop = NULL
               WHERE  PickDetailKey = @c_PickDetailKey

               SET @n_Err = @@ERROR

               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_Status = '5'
                  SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20097
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to Update Pickdetail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                  GOTO QUIT_SP
               END

               -- Insert RefKeyLookup, if not exists
               IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookup (NOLOCK) WHERE PickDetailKey = @c_NewPickDetailKey)
               BEGIN
                  INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey, EditWho) --SOS# 255550
                  VALUES (@c_NewPickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_LoadKey, 'TCP04a.' + sUser_sName())

                  SELECT @n_Err = @@ERROR

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @c_Status = '5'
                     SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20098
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to Insert RefKeyLookup. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
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
                     SET @n_Err = 20099
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5), @n_Err) + ': Update RefKeyLookup Fail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' )'
                     GOTO QUIT_SP
                  END
               END

            END --IF @n_Qty_PD > @n_Qty

            IF @n_Qty > 0
            BEGIN
               -- OffSet QtyToPick
               SET @n_Qty = @n_Qty - @n_QTY_PD
            END

            IF @n_Qty = 0 OR @n_Qty < 0
            BEGIN
               BREAK
            END

            FETCH NEXT FROM CursorPickDetail INTO @c_PickDetailKey, @n_Qty_PD, @c_LOT, @n_SortSeq
         END -- While Loop for PickDetail Key
         CLOSE CursorPickDetail
         DEALLOCATE CursorPickDetail


   /***************************************************/
   /* Update UCC                                      */
   /***************************************************/
   IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc)
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Invalid TOLOC : ' + ISNULL(RTRIM(@c_ToLoc), '') + '. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
      GOTO QUIT_SP
   END

   -- Update UCC
   UPDATE dbo.UCC WITH (ROWLOCK) SET
      Loc        = @c_ToLoc,
      Status     = '6'  --(ung03)
   WHERE UCCNo      = @c_LPNNo
   AND   StorerKey  = @c_StorerKey
   AND   SKU        = @c_SKU

   SELECT @n_Err = @@ERROR

   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20090
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to Update UCC. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
      GOTO QUIT_SP
   END

   /***************************************************/
   /* Insert PackHeader                               */
   /***************************************************/
   IF (SELECT COUNT(1) FROM dbo.PACKHEADER WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo) = 0
   BEGIN
      INSERT INTO dbo.PACKHEADER
      (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, ConsoOrderKey) -- (ChewKP01)
      VALUES
      (@c_PickSlipNo, @c_StorerKey, '', @c_LoadKey, @c_Route, '', '', 0, @c_ConsoOrderKey) -- (ChewKP08)
      --(@c_PickSlipNo, @c_StorerKey, '', @c_LoadKey, @c_Route, '', '', 1, @c_ConsoOrderKey) -- (ChewKP01)

      SELECT @n_Err = @@ERROR

      IF @n_Err <> 0
      BEGIN
     SET @n_Continue = 3
         SET @c_Status = '5'
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20104
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert PACKHEADER Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
         GOTO QUIT_SP
      END

      SET @n_CartonNo = 1
      SET @n_LabelLine = 1

      IF @b_Debug = 1
      BEGIN
         SELECT 'PACKHEADER created >> @c_PickSlipNo : ' + @c_PickSlipNo
      END
   END -- END COUNT(1) FROM PACKHEADER

   /***************************************************/
   /* Insert PackDetail                               */
   /***************************************************/
   IF @b_Debug = 1
   BEGIN
      SELECT *
      FROM  dbo.PICKDETAIL PK WITH (NOLOCK)
      WHERE PK.Orderkey = @c_Orderkey
      AND   PK.OrderLineNumber = @c_OrderLineNumber
      AND   PK.LOC = @c_FROMLOC
      AND   PK.Status BETWEEN '5' AND '8'
      AND   PK.DROPID = @c_LPNNo
      AND   PK.CASEID = @c_GS1LabelNo
   END

   SELECT @n_Qty = ISNULL(SUM(PK.Qty),0)
   FROM  dbo.PICKDETAIL PK WITH (NOLOCK)
   WHERE PK.Orderkey = @c_Orderkey
   AND   PK.OrderLineNumber = @c_OrderLineNumber
   -- AND   PK.LOC = @c_FROMLOC  --(ung04)
   AND   PK.Status = '5' -- AND '8' (ung04)
   AND   PK.DROPID = @c_LPNNo
   AND   PK.CASEID = @c_GS1LabelNo

   SET @n_CartonNo = 0
   SET @n_LabelLine = '00000'

   IF @b_Debug = 1
   BEGIN
      SELECT '@c_SKU : ' + @c_SKU
           + ', @n_Qty : ' + CONVERT(VARCHAR, @n_Qty)
           + ', @c_LabelLine : ' + @c_LabelLine
           + ', @n_CartonNo : ' + CONVERT(VARCHAR, @n_CartonNo)
           + ', @c_GS1LabelNo : ' + @c_GS1LabelNo
   END

   -- (ChewKP04)
   IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                   WHERE PickSlipNO = @c_PickSlipNo
                   AND SKU = @c_Sku
                   AND DropID = @c_LPNNo)
   BEGIN
      INSERT INTO dbo.PACKDETAIL
      (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, Sku, Qty, DropID)
      VALUES
      (@c_PickSlipNo, @n_CartonNo, @c_GS1LabelNo, @c_LabelLine, @c_StorerKey, @c_Sku, @n_Qty, @c_LPNNo)

      SELECT @n_Err = @@ERROR

      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_Status = '5'
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20105
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert PACKDETAIL Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
         GOTO QUIT_SP
      END
END

   IF @b_Debug = 1
   BEGIN
      SELECT 'PACKDETAIL created >> @c_PickSlipNo : ' + @c_PickSlipNo
           + ', CartonNo : ' + CONVERT(VARCHAR, @n_CartonNo)
           + ', LabelNo : ' + @c_GS1LabelNo
   END

   /***************************************************/
   /* Insert PackInfo                                 */
   /***************************************************/

   SELECT @n_CartonNo = MAX(CartonNo)
   FROM dbo.PACKDETAIL WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
   AND DropID = @c_LPNNo -- (ChewKP10)

   IF (SELECT COUNT(1) FROM dbo.PACKINFO (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @n_CartonNo) = 0
   BEGIN
      INSERT INTO dbo.PACKINFO
      (PickSlipNo, CartonNo, CartonType, RefNo)  -- (ChewKP02)
      VALUES
      (@c_PickSlipNo, @n_CartonNo, 'STD', 'FC')   -- (ChewKP02)/(james01)

      SELECT @n_Err = @@ERROR

      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_Status = '5'
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20106
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert PACKINFO Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
         GOTO QUIT_SP
      END

      IF @b_Debug = 1
      BEGIN
         SELECT 'PACKINFO created >> @c_PickSlipNo : ' + @c_PickSlipNo
              + ', CartonNo : ' + CONVERT(VARCHAR, @n_CartonNo)
      END
   END

   /***************************************************/
   /* Insert Transmitlog3 for PACKCFMLOG              */
   /* Update PackHeader                               */
   /***************************************************/
   SET @n_CntTotal = 0
   SET @n_CntPrinted = 0

   SELECT @n_CntTotal = SUM(PD.QTY)
   FROM   dbo.OrderDetail OD WITH (NOLOCK)
   INNER  JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( OD.ORDERKEY = PD.ORDERKEY AND
                                                    OD.OrderLineNumber = PD.OrderLinenUmber )
   WHERE OD.StorerKey = @c_StorerKey
   AND   OD.ConsoOrderKey = @c_ConsoOrderKey

   SELECT @n_CntPrinted = SUM(PCD.QTY)
   FROM   dbo.PACKDETAIL PCD WITH (NOLOCK)
   WHERE  PCD.PickSlipNo = @c_PickSlipNo

   IF @n_CntTotal = @n_CntPrinted
   BEGIN

      UPDATE dbo.PackHeader WITH (ROWLOCK)
      SET STATUS = '9'
      WHERE PICKSLIPNO = @c_PickSlipNo

      SET @n_Err = @@ERROR

      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_Status = '5'
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20107
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Update PackHeader Fail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
         GOTO QUIT_SP
      END

      /*  -- Handle by ntrPackHeaderUpdate
      SET @c_authority_PACKCFMLOG = ''

      EXECUTE dbo.nspGetRight @c_Facility,
                              @c_StorerKey,            -- Storer
                              '',                      -- Sku
                              @c_TableNamePack,        -- ConfigKey
                              @b_Success               OUTPUT,
                              @c_authority_PACKCFMLOG  OUTPUT,
                              @n_Err                   OUTPUT,
                              @c_ErrMsg                OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
         SET @c_Status = '5'
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20090
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(Char(5),@n_Err) + ': Retrieve of Right (PACKCFMLOG) Failed. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
         GOTO QUIT_SP
      END

      IF @c_authority_PACKCFMLOG = '1'
      BEGIN
         EXEC dbo.ispGenTransmitLog3 @c_TableNamePack
                                   , @c_PickSlipNo
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
            SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20090
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(Char(5),@n_Err) + ': Insert Transmitlog3 (PACKCFMLOG) Failed. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
            GOTO QUIT_SP
         END
      END
      */
   END -- IF @n_CntTotal = @n_CntPrinted

   -- Insert Dropid
   IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @c_LPNNo)
   BEGIN
      INSERT INTO dbo.DropID (DropID, LabelPrinted, [Status], PickSlipNo, LoadKey)
         VALUES (@c_LPNNo, '1', '9', @c_PickSlipNo, @c_LoadKey)

      SELECT @n_Err = @@ERROR

      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_Status = '5'
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20108
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert DropID Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
         GOTO QUIT_SP
      END
   END

   /***************************************************/
   /* Print GS1 Label                                 */
   /***************************************************/
   IF @c_NewGS1Label = 'Y'
   BEGIN

      DECLARE @c_TemplateID     NVARCHAR(60)
            , @c_TemplateID2    NVARCHAR(60)
            , @c_CurrTemplateID NVARCHAR(60)
            , @c_PrinterFolder  NVARCHAR(50)
            , @c_BatchNo        NVARCHAR(20)
            , @d_CurrDate       DATETIME
            , @c_BtwPath        NVARCHAR(215)

      CREATE TABLE #TMP_GSICartonLabel_XML (SeqNo int,                -- Temp table's PrimaryKey
                                            LineText NVARCHAR(1500))   -- XML column
                                            CREATE INDEX Seq_ind ON #TMP_GSICartonLabel_XML (SeqNo)

      -- (ChewKP03)
      --SET @c_TemplateID = @c_DischargePlace
      --SET @c_TemplateID2 = @c_DeliveryPlace
      SET @c_PrinterID = 'WCS'

      SELECT @c_BtwPath = NSQLDescrip
      FROM RDT.NSQLCONFIG WITH (NOLOCK)
      WHERE ConfigKey = 'GS1TemplatePath'

      -- (ChewKP03)
      --IF ISNULL(RTRIM(@c_TemplateID),'') = ''
      --   SET @c_TemplateID = 'Generic.btw'

      --IF SUBSTRING(@c_BTWPath, LEN(@c_BTWPath), 1) <> '\'
      --   SET @c_BTWPath = @c_BTWPath + '\'

      --SET @c_TemplateID =  RTRIM(@c_BTWPath) + RTRIM(@c_TemplateID)

      -- (ChewKP03)
      SET @c_CurrTemplateID = @c_BtwPath

--(ChewKP03)
--      SET @d_CurrDate = GETDATE()
--      SET @c_datetime = CONVERT(char(8),getdate(),112)+
--                        RIGHT('0'+RTRIM(datepart(hh,@d_CurrDate)),2)+
--                        RIGHT('0'+RTRIM(datepart(mi,@d_CurrDate)),2)+
--                        RIGHT('0'+RTRIM(datepart(ss,@d_CurrDate)),2)+
--                        RIGHT('00'+RTRIM(datepart(ms,@d_CurrDate)),3)
--
--      SET @c_Filename = RTRIM(@c_PrinterID)+'_'+RTRIM(@c_DateTime)+'_'+RTRIM(@c_GS1LabelNo) + '.XML'
--
--      SET @c_BatchNo = ABS(CAST(CAST(NEWID() AS VARBINARY(5)) AS Bigint))
--
--    TRUNCATE TABLE #TMP_GSICartonLabel_XML
--
--      --EXEC isp_GSICartonLabel @c_mbolkey, @c_orderkey, @c_CurrTemplateID, @c_PrinterID, 'TEMPDB', @c_cartonno, '', @c_labelno, @c_ConsoOrderKey
--      EXEC isp_GSICartonLabel '', @c_orderkey, @c_CurrTemplateID, @c_PrinterID, 'TEMPDB', '', '',  @c_GS1LabelNo, @c_ConsoOrderKey
--
--      IF @b_Debug = 1
--      BEGIN
--         SELECT 'isp_GSICartonLabel DONE. '
--      END
--
--      INSERT INTO XML_Message( BatchNo, Server_IP, Server_Port, XML_Message, RefNo )
--      SELECT @c_BatchNo, '', '', LineText, ''
--      FROM #TMP_GSICartonLabel_XML
--      ORDER BY SeqNo
--
--      DROP TABLE #TMP_GSICartonLabel_XML

        EXEC dbo.isp_PrintGS1Label
            @c_PrinterID = @c_PrinterID,
            @c_BtwPath   = @c_CurrTemplateID,
            @b_Success   = @b_success OUTPUT,
            @n_Err       = @n_Err     OUTPUT,
            @c_Errmsg    = @c_ErrMsg  OUTPUT,
            @c_LabelNo   = @c_GS1LabelNo,
            @c_BatchNo   = @c_BatchNo OUTPUT,
            @c_WCSProcess = 'Y'


        UPDATE XML_MESSAGE
        SET STATUS = '0'
        WHERE BATCHNO = @c_BatchNo

      IF @b_Debug = 1
      BEGIN
         SELECT 'XML_Message Insert Successful. BatchNo : ' + @c_BatchNo
      END

      /***************************************************/
      /* Insert TCPSocket_OUTLog                         */
      /***************************************************/
-- (ChewKP09)
--      SET @b_Success = 0
--
--      EXECUTE nspg_GetKey
--         'TCPOUTLog',
--         10,
--         @c_MessageNum_Out OUTPUT,
--         @b_Success        OUTPUT,
--         @n_Err            OUTPUT,
--         @c_ErrMsg         OUTPUT
--
--      IF @b_Success <> 1
--      BEGIN
--         SET @n_Continue = 3
--         SET @c_Status = '5'
--         SELECT @c_ErrMsg = CONVERT(char(250),@n_Err), @n_Err = 20070
--         SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err)+': Unable to retrieve TCPOUTLog Number. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
--                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
--         GOTO QUIT_SP
--      END
--
--      IF @b_Debug = 1
--      BEGIN
--         SELECT 'TCPSocket_OUTLog MessageNum : ' + @c_MessageNum_Out
--      END
--
--      --SELECT @c_Data_Out = '<STX>GS1LABEL|' + @c_MessageNum_Out + '|' + @c_StorerKey + '|' + @c_Facility + '|' + @c_LPNNo + '|' + @c_GS1LabelNo + '|'
--      SELECT @c_Data_Out = 'GS1LABEL|' + @c_MessageNum_Out + '|' + @c_StorerKey + '|' + @c_Facility + '|' + @c_LPNNo + '|' + @c_GS1LabelNo + '|'
--
--      INSERT INTO TCPSocket_OUTLog
--      (MessageNum, MessageType, Data, Status,StorerKey, BatchNo, LabelNo)
--      VALUES
--      (@c_MessageNum_Out, 'SEND', @c_Data_Out, '0', @c_StorerKey, @c_BatchNo, @c_GS1LabelNo)
--
--      SELECT @n_Err = @@ERROR
--
--      IF @n_Err <> 0
--      BEGIN
--         SET @n_Continue = 3
--         SET @c_Status = '5'
--         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 70458
--         SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert TCPSocket_OUTLog Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
--                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
--         GOTO QUIT_SP
--      END
--
--      IF @b_Debug = 1
--      BEGIN
--         SELECT 'TCPSocket_OUTLog created.'
--      END
   END --IF @c_NewGS1Label = 'Y'

   QUIT_SP:

   IF @b_Debug = 1
   BEGIN
      SELECT 'Update TCPSocket_INLog >> @c_Status : ' + @c_Status
           + ', @c_ErrMsg : ' + @c_ErrMsg
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      ROLLBACK TRAN WCS_BULK_PICK  --(ung02)
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_TCP_WCS_FC_INDUCTION_IN'
   END

   UPDATE dbo.TCPSocket_INLog WITH (ROWLOCK)
   SET STATUS   = @c_Status
     , ErrMsg   = @c_ErrMsg
     , Editdate = GETDATE()
     , EditWho  = SUSER_SNAME()
   WHERE SerialNo = @n_SerialNo

   WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started
      COMMIT TRAN WCS_BULK_PICK  --(ung02)

   /***************************************************/
   /* Output GS1 WCS 7                                */
   /***************************************************/
   IF @n_Continue <> 3
   BEGIN
      IF @c_NewGS1Label = 'Y'
      BEGIN

-- (ChewKP09)
--         EXECUTE dbo.isp_TCP_WCS_GS1_Label_OUT
--            @c_MessageNum_Out = @c_MessageNum_Out
--          , @c_BatchNo        = @c_BatchNo
--          , @b_Debug          = @b_Debug
--          , @b_Success        = @b_Success  OUTPUT
--          , @n_Err            = @n_Err      OUTPUT
--          , @c_ErrMsg         = @c_ErrMsg   OUTPUT
--          , @c_DeleteGS1      = @c_DeleteGS1

         EXECUTE dbo.isp_TCP_WCS_GS1_Label_OUT
            @c_BatchNo        = @c_BatchNo
          , @b_Debug          = @b_Debug
          , @b_Success        = @b_Success  OUTPUT
          , @n_Err            = @n_Err     OUTPUT
          , @c_Errmsg         = @c_ErrMsg    OUTPUT
          , @c_DeleteGS1      = 'N'
          , @c_StorerKey      = @c_StorerKey
          , @c_Facility       = @c_Facility
          , @c_LabelNo        = @c_GS1LabelNo
          , @c_DropID         = @c_LPNNo
         /*
         BEGIN TRAN

         SET @n_SerialNo_Out = 0
         SET @n_Status_Out = 0

         EXEC [master].[dbo].[isp_TCPSocket_GS1LabelClientSocket]
              @c_MessageNum_Out
            , @c_BatchNo
            , @n_Status_Out OUTPUT
            , @c_ErrMsg_Out OUTPUT

         SELECT @n_SerialNo_Out = SerialNo
         FROM   dbo.TCPSocket_OUTLog WITH (NOLOCK)
         WHERE  MessageNum    = @c_MessageNum_Out
         AND    MessageType   = 'SEND'
         AND    Status        = '0'

         UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)
         SET    STATUS = CONVERT(VARCHAR(1), @n_Status_Out)
              , ErrMsg = CASE ISNULL(@c_ErrMsg_Out, '') WHEN '' THEN ''
                         ELSE @c_ErrMsg_Out + ' <Xml_Message.BatchNo = ' + @c_BatchNo + '>'  END
         WHERE  SerialNo = @n_SerialNo_Out

         SELECT @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 70458
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Update TCPSocket_OUTLog Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
            GOTO QUIT_GS1
         END

         IF @b_Debug = 1
         BEGIN
            SELECT 'TCPSocket_OUTLog Update Successful. SerialNo : ' + CONVERT(VARCHAR, @n_SerialNo_Out)
         END

         IF @c_DeleteGS1 = 'Y' AND @n_Status_Out = '9'
         BEGIN
      DELETE FROM XML_Message WHERE BatchNo = @c_BatchNo

            SELECT @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 70458
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Delete XML_Message Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               GOTO QUIT_GS1
            END

            IF @b_Debug = 1
            BEGIN
               SELECT 'Delete XML_Message Successful. BatchNo : ' + @c_BatchNo
            END
         END

         IF @n_Status_Out <> '9'
         BEGIN
            UPDATE dbo.XML_Message  WITH (ROWLOCK)
            SET Status = '5'
           --   , RefNo = 'WCSLog:' + @c_MessageNum_Out
            WHERE BatchNo = @c_BatchNo

            SELECT @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 70458
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Update XML_Message Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_FC_INDUCTION_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               GOTO QUIT_GS1
            END
         END

         QUIT_GS1:
         IF @n_Continue=3  -- Error Occured - Process And Return
         BEGIN
            ROLLBACK TRAN
            EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_TCP_WCS_FC_INDUCTION_IN'
         END

         WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started
            COMMIT TRAN
         */
      END --IF @c_NewGS1Label = 'Y'
   END --IF @n_Continue <> 3

   RETURN
END

GO