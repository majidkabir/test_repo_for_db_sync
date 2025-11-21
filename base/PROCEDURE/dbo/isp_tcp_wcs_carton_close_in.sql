SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_TCP_WCS_CARTON_CLOSE_IN                        */
/* Creation Date: 05-Jul-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: MCTang                                                   */
/*                                                                      */
/* Purpose: Carton Close                                                */
/*          RedWerks to WMS Exceed                                      */
/*                                                                      */
/* Input Parameters:  @c_MessageNum    - Unique no for Incoming data    */
/*                                                                      */
/* Output Parameters: @b_Success       - Success Flag  = 0              */
/*                    @n_Err           - Error Code    = 0              */
/*                    @c_ErrMsg        - Error Message = ''             */
/*                                                                      */
/* PVCS Version: 4.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 09-01-2012   ChewKP    1.1   Standardize ConsoOrderKey Mapping       */
/*                              (ChewKP01)                              */
/* 13-01-2012   ChewKP    1.2   Should select base on FromTote(ChewKP02)*/
/* 30-01-2012   ChewKP    1.3   Not Nessary to check PickQty (ChewKP03) */
/* 02-02-2012   ChewKP    1.4   Same LPN on SKU should be not be process*/
/*                              (ChewKP04)                              */
/* 08-02-2012   ChewKP    1.5   Revise Logic on GS1Label Generation     */
/*                              (ChewKP05)                              */
/* 09-02-2012   ChewKP    1.6   Update PackDetail.TotCube (ChewKP06)    */
/* 17-02-2012   ChewKP    1.7   Update Status = '1' before process      */
/*                              (ChewKP07)                              */
/* 29-02-2012   ChewKP    1.8   PackHeader Fix (ChewKP08)               */
/* 07-03-2012   ChewKP    1.9   Standardize WCS GS1 Socket Process      */    
/*                              (ChewKP09)                              */
/* 13-03-2012   ChewKP    2.0   Misc Fixes (ChewKP10)                   */
/* 21-03-2012   ChewKP    2.1   Prevent OverPacaked (ChewKP11)          */
/* 29-03-2012   SHONG     2.2   Allow Different Order# Line with Same   */
/*                              DropID                                  */
/* 05-04-2012   James     2.3   Remove check fromtote (james01)         */
/* 05-04-2012   Ung       2.4   PickDetail.DropID and PackDetail.DropID */
/*                              expand to 20 chars (ung01)              */
/* 07-04-2012   Ung       2.5   Stamp PickDetail.DropID = LPNNo (ung02) */
/* 07-04-2012   James     2.6   Insert DropID = LPNNo (james02)         */
/*                              Comment checking on carton type         */
/* 08-04-2012   Shong     2.7   Review Script                           */
/* 09-04-2012   Ung       2.8   Stamp cube on PackInfo (ung03)          */
/* 16-04-2012   Shong     2.9   Check Print GS1 Label Error             */
/* 18-04-2012   Shong     3.0   Handle Short Pick Qty                   */
/* 19-04-2012   Shong     3.1   Enlarge Length of Data                  */
/* 20-04-2012   Ung       3.2   Carton empty don't print GS1 (ung04)    */
/* 23-04-2012   Shong     3.3   Insert PackHeader.status with 5         */
/* 27-04-2012   Shong     3.4   Fix the Blank PickSlipNo in RefKeyLookUp*/
/* 10-05-2012   Ung       3.5   Fix QTY short split line (ung05)        */
/* 16-05-2012   Shong     3.6   Fix Issues from ung05                   */
/* 13-07-2012   ChewKP    3.7   SOS#227151 TM CycleCount Task           */
/*                              Standardization (ChewKP12)              */
/* 07-09-2012   Leong     3.8   SOS# 255550 - Insert RefKeyLookUp with  */
/*                              EditWho                                 */
/* 05-10-2012   Ung       3.9   SOS245083 change master and child carton*/
/*                              on get tracking no, print GS1 (ung06)   */
/* 24-10-2012   Leong     4.0   SOS# 259843 - Add data logging for over */
/*                              packed issues                           */
/* 10-12-2012   Shong     4.0   SOS# 264161 - Update PickDetail with    */
/*                                            Sort Sequence             */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_TCP_WCS_CARTON_CLOSE_IN]
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
         , @c_DataString            NVARCHAR(MAX)
         , @c_InMsgType             NVARCHAR(15)
         , @c_StorerKey             NVARCHAR(15)
         , @c_Facility              NVARCHAR(5)
         , @c_LPNNo                 NVARCHAR(20) -- (Ung01)
         , @c_MasterLPNNo           NVARCHAR(20)
         , @c_LastCarton            NVARCHAR(1)
         , @c_LineNo                NVARCHAR(5)
         , @c_OrderKey              NVARCHAR(10)
         , @c_OrderLineNumber       NVARCHAR(5)
         , @c_ConsoOrderKey         NVARCHAR(30) -- (ChewKP01)
         , @c_SKU                   NVARCHAR(20)
         , @n_Qty                   INT
         , @n_QtyImported           INT
         , @n_Qty_PD                INT
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
         , @c_Route                 NVARCHAR(10)
         , @c_GS1LabelNo            NVARCHAR(20)
         , @c_DischargePlace        NVARCHAR(30)
         , @c_DeliveryPlace         NVARCHAR(30)
         , @c_NewGS1Label           NVARCHAR(1)
         , @c_MessageNum_Out        NVARCHAR(10)
         , @c_Data_Out              NVARCHAR(1000)
         , @n_Status_Out            INT
         , @c_ErrMsg_Out            NVARCHAR(400)
         , @n_PrintGS1_Error        INT
         , @n_QtyShort              INT
         , @n_ExpectedQty           INT
         , @n_SortSeq               INT -- Shong 4.1         

   DECLARE @c_PrinterID             NVARCHAR(20)
         , @c_FileName              NVARCHAR(215)
         , @c_DateTime              NVARCHAR(17)
         , @c_Authority_PickCfmLog  NVARCHAR(1)
         , @c_authority_PACKCFMLOG  NVARCHAR(1)
         , @n_CntTotal              INT
         , @n_CntPrinted            INT

   DECLARE @c_TemplateID            NVARCHAR(60)
         , @c_CurrTemplateID        NVARCHAR(60)
         , @c_BatchNo               NVARCHAR(20)
         , @d_CurrDate              DATETIME
         , @c_BtwPath               NVARCHAR(215)
         , @c_TableNamePick         NVARCHAR(30)
         , @c_TableNamePack         NVARCHAR(30)
         , @c_FromTote              NVARCHAR(20) -- (ChewKP02)
         , @c_CartonType            NVARCHAR(10) -- (ChewKP06)
         , @f_Cube                  REAL -- (ChewKP06)
         , @f_TotalCtnCube          REAL -- (ChewKP06)
         , @n_TotalCarton           INT -- (ChewKP06)
         , @n_TotalPickedQty        INT -- (ChewKP11)
         , @n_TotalPackedQty        INT -- (ChewKP11)
         , @c_CCKey                 NVARCHAR(10) -- (ChewKP12)

   DECLARE @c_LogicalLocation NVARCHAR(10)
         , @c_AreaKey         NVARCHAR(10)
         , @c_TaskDetailKey   NVARCHAR(10)
         , @c_Loc             NVARCHAR(10)
         , @n_SystemQty       INT
         , @c_TraceFlag       VARCHAR(1) -- SOS# 259843

   SET @c_TraceFlag = '0' --> 1 - Turn on, 0 - Turn Off
         

   SELECT @n_Continue = 1, @b_Success = 1, @n_Err = 0
   SET @n_StartTCnt = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN WCS_BULK_PICK

   SET @c_ErrMsg           = ''
   SET @c_Status           = '9'
   SET @n_SerialNo         = 0
   SET @c_DataString       = ''
   SET @c_InMsgType        = ''
   SET @c_StorerKey        = ''
   SET @c_Facility         = ''
   SET @c_LPNNo            = ''
   SET @c_MasterLPNNo      = ''
   SET @c_LastCarton       = ''
   SET @c_LineNo           = ''
   SET @c_OrderKey         = ''
   SET @c_OrderLineNumber  = ''
   SET @c_ConsoOrderKey    = ''
   SET @c_SKU              = ''
   SET @n_Qty              = 0
   SET @n_QtyImported      = 0
   SET @n_Qty_PD           = 0
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
   SET @c_Route            = ''
   SET @c_GS1LabelNo       = ''
   SET @c_DischargePlace   = ''
   SET @c_DeliveryPlace    = ''
   SET @c_NewGS1Label      = 'N'
   SET @c_MessageNum_Out   = ''
   SET @c_Data_Out         = ''
   SET @c_TableNamePick    = 'PICKCFMLOG'
   SET @c_TableNamePack    = 'PACKCFMLOG'
   SET @c_CartonType       = '' -- (ChewKP06)
   SET @n_TotalCarton      = 0  -- (ChewKP06)
   SET @f_TotalCtnCube     = 0  -- (ChewKP06)
   SET @f_Cube             = 0  -- (ChewKP06)
   SET @n_QtyShort         = 0
   SET @n_ExpectedQty      = 0

   SELECT TOP 1
          @n_SerialNo   = SerialNo,
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

   -- (ChewKP07)
   UPDATE dbo.TCPSOCKET_INLOG WITH (ROWLOCK)
   SET Status = '1'
   WHERE SerialNo = @n_SerialNo

   IF ISNULL(RTRIM(@c_DataString),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Data String is empty. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
      GOTO QUIT_SP
   END

   DECLARE @n_Position   INT
         , @c_RecordLine NVARCHAR(512)
         , @c_Delimited  NVARCHAR(4)
         , @c_LineText   NVARCHAR(512)
         , @n_SeqNo      INT

   DECLARE @t_CartonCloseRecord TABLE (SeqNo INT IDENTITY(1,1), LineText NVARCHAR(512))

   SET @c_Delimited = master.dbo.fnc_GetCharASCII(13)

   SET @c_DataString = @c_DataString + master.dbo.fnc_GetCharASCII(13)

   SET @n_Position = CHARINDEX(master.dbo.fnc_GetCharASCII(13), @c_DataString)
   WHILE @n_Position <> 0
   BEGIN
       SET @c_RecordLine = LEFT(@c_DataString, @n_Position - 1)

       INSERT INTO @t_CartonCloseRecord
       VALUES
         (
           CAST(@c_RecordLine AS NVARCHAR(512))
         )

       SET @c_DataString = STUFF(@c_DataString, 1, @n_Position  ,'')
       SET @n_Position = CHARINDEX(master.dbo.fnc_GetCharASCII(13), @c_DataString)
   END

   IF @b_Debug = 1
   BEGIN
    PRINT '@t_CartonCloseRecord'
      SELECT * From @t_CartonCloseRecord
   END

   DECLARE CUR_LINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT SeqNo, LineText
   FROM @t_CartonCloseRecord
   ORDER BY SeqNo

   OPEN CUR_LINE

   FETCH NEXT FROM CUR_LINE INTO @n_SeqNo, @c_LineText
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @n_SeqNo = 1
      BEGIN
         SET @c_InMsgType        = RTRIM(SubString(@c_LineText,   1,  15))
         SET @c_StorerKey        = RTRIM(SubString(@c_LineText,  24,  15))
         SET @c_Facility         = RTRIM(SubString(@c_LineText,  39,   5))
         SET @c_LPNNo            = RTRIM(SubString(@c_LineText,  44,  20))   -- (Ung01)
         SET @c_MasterLPNNo      = RTRIM(SubString(@c_LineText,  64,  20))
         SET @c_TXCODE           = RTRIM(SubString(@c_LineText,  84,   5))
         SET @c_LastCarton       = RTRIM(SubString(@c_LineText,  89,   1))
         SET @c_CartonType       = RTRIM(SubString(@c_LineText,  90,  10))    -- (ChewKP06)

         IF @b_Debug = 1
         BEGIN
            SELECT 'Header >> @c_InMsgType : ' + @c_InMsgType
                 + ', @c_StorerKey : '         + @c_StorerKey
                 + ', @c_Facility : '          + @c_Facility
                 + ', @c_LPNNo : '             + @c_LPNNo
                 + ', @c_MasterLPNNo : '       + @c_MasterLPNNo
                 + ', @c_TXCODE : '            + @c_TXCODE
                 + ', @c_LastCarton : '        + @c_LastCarton
                 + ', @c_CartonType : '        + @c_CartonType
         END

         IF ISNULL(RTRIM(@c_InMsgType),'') <> 'CARTONCLOSE'
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Invalid MessageType:' + ISNULL(RTRIM(@c_InMsgType), '') + ' for process. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
            GOTO QUIT_SP
         END

         -- (ChewKP06)
         IF EXISTS ( SELECT 1 FROM dbo.Cartonization CT WITH (NOLOCK)
                     INNER JOIN dbo.Storer S WITH (NOLOCK) ON S.CartonGroup = CT.CartonizationGroup
                     WHERE CT.CartonType = @c_CartonType
                     AND S.StorerKEy = @c_StorerKey )
         BEGIN
            SELECT @f_Cube = CT.Cube
            FROM dbo.Cartonization CT WITH (NOLOCK)
            INNER JOIN dbo.Storer S WITH (NOLOCK) ON S.CartonGroup = CT.CartonizationGroup
            WHERE CT.CartonType = ISNULL(RTRIM(@c_CartonType),'')
            AND S.StorerKey = @c_StorerKey
         END
         ELSE
         BEGIN
            SELECT @f_Cube = ISNULL( CT.Cube, 0) -- (ung03)
            FROM dbo.Cartonization CT WITH (NOLOCK)
            INNER JOIN dbo.Storer S WITH (NOLOCK) ON S.CartonGroup = CT.CartonizationGroup
            WHERE CT.CartonType = 'DEFAULT'
            AND S.StorerKey = @c_StorerKey
         END
      END
      ELSE -- IF @n_SeqNo <> 1
      BEGIN
         SET @c_LineNo           = ISNULL(RTRIM(SubString(@c_LineText,   1,   5)),'')
         SET @c_OrderKey         = ISNULL(RTRIM(SubString(@c_LineText,   6,  10)),'')
         SET @c_OrderLineNumber  = ISNULL(RTRIM(SubString(@c_LineText,  16,   5)),'')
         SET @c_ConsoOrderKey    = ISNULL(RTRIM(SubString(@c_LineText,  21,  30)),'') -- (ChewKP01)
         SET @c_SKU              = ISNULL(RTRIM(SubString(@c_LineText,  51,  20)),'')
         SET @n_Qty              = ISNULL(RTRIM(SubString(@c_LineText,  71,  10)),'0')
         SET @c_FromTote         = ISNULL(RTRIM(SubString(@c_LineText,  81,  20)),'') -- (ChewKP02)

         SET @c_FromTote = ISNULL(@c_FromTote,'')

         IF LEN(@c_LineText) > 100
            SET @n_ExpectedQty      = ISNULL(RTRIM(SubString(@c_LineText, 101,  10)),'0')
         ELSE
            SET @n_ExpectedQty = 0

         IF @b_Debug = 1
         BEGIN
            SELECT @c_LineText

            SELECT 'Detail >> @c_LineNo : '  + @c_LineNo
                 + ', @c_OrderKey : '        + @c_OrderKey
                 + ', @c_OrderLineNumber : ' + @c_OrderLineNumber
                 + ', @c_ConsoOrderKey : '   + @c_ConsoOrderKey
                 + ', @c_SKU : '             + @c_SKU
                 + ', @n_Qty : '             + CONVERT(VARCHAR, @n_Qty)
         END

         IF ISNULL(RTRIM(@c_OrderKey),'') = ''
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. OrderKey is empty for LineNo: ' + RTRIM(@c_LineNo) + '. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
            GOTO QUIT_SP
         END

         IF ISNULL(RTRIM(@c_OrderLineNumber),'') = ''
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Order Line Number is empty for LineNo: ' + RTRIM(@c_LineNo) + '. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
            GOTO QUIT_SP
         END

         IF ISNULL(RTRIM(@c_SKU),'') = ''
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Sku is empty for LineNo: ' + RTRIM(@c_LineNo) + '. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
            GOTO QUIT_SP
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)
                        WHERE OrderKey       = @c_OrderKey
                        AND OrderLineNumber  = @c_OrderLineNumber
                        AND StorerKey        = @c_StorerKey
                        AND SKU              = @c_SKU
                        AND STATUS           = '5' -- (ung02)
                        AND CASEID           = '')
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. OrderKey: ' + ISNULL(RTRIM(@c_OrderKey),'')
                          + ', OrderLineNo: ' + ISNULL(RTRIM(@c_OrderLineNumber),'')
                          + ', StorerKey: ' + ISNULL(RTRIM(@c_StorerKey),'')
                          + ', SKU: ' + ISNULL(RTRIM(@c_SKU),'')
                          + '. NOT exists in PickDetail Table or Order not PICK for LineNo: ' + RTRIM(@c_LineNo) + '. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
            GOTO QUIT_SP
         END
         /***************************************************/
         /* Handle Short Pick Here                          */
         /***************************************************/
         IF @n_ExpectedQty > @n_Qty
         BEGIN
         	SET @n_QtyShort = @n_ExpectedQty - @n_Qty

         	-- Update pickdetail status to 4
            DECLARE CursorShortPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.PickDetailKey
                 , PD.QTY
                 , PD.LOT
                 , SortSeq = CASE WHEN DropID = @c_FromTote THEN 1
                                  WHEN DropID = '' THEN 2
                                  ELSE 9
                             END -- Shong 4.1                 
            FROM   dbo.PickDetail PD WITH (NOLOCK)
            WHERE  PD.OrderKey = @c_OrderKey
            AND    PD.OrderLineNumber = @c_OrderLineNumber
            AND    PD.Status = '5'  -- (ung02)
            AND    PD.CaseID = ''
            ORDER BY SortSeq, PD.PickDetailKey -- Shong 4.1

            OPEN CursorShortPickDetail
            FETCH NEXT FROM CursorShortPickDetail INTO @c_PickDetailKey, @n_Qty_PD, @c_LOT, @n_SortSeq -- Shong 4.1
            WHILE @@FETCH_STATUS<>-1
            BEGIN
               IF @b_Debug = 1
               BEGIN
                  SELECT 'Update PickDetail >> @n_QtyShort : ' + CONVERT(VARCHAR, @n_QtyShort)
                       + '@n_Qty_PD : ' + CONVERT(VARCHAR, @n_Qty_PD)
                       + '@c_LOT : ' + ISNULL(RTRIM(@c_LOT),'')
               END

               IF @n_Qty_PD = @n_QtyShort OR @n_Qty_PD < @n_QtyShort
               BEGIN
                  UPDATE dbo.PickDetail WITH (ROWLOCK)
                  SET    [STATUS] = '4'
                  WHERE  PickDetailKey = @c_PickDetailKey

                  SET @n_Err = @@ERROR

                  IF @n_Err <> 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @c_Status = '5'
                     SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20090
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Update Pickdetail Fail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                     GOTO QUIT_SP
                  END
               END
               ELSE --IF @n_Qty_PD > @n_QtyShort
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
                     SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20091
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to retrieve new PickdetailKey. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
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
                      ,DropID = @c_FromTote --DropID -- Shong 4.1
                      ,LOC                  ,ID
                      ,PackKey              ,UpdateSource      ,CartonGroup
                      ,CartonType           ,ToLoc             ,DoReplenish
                      ,ReplenishZone        ,DoCartonize       ,PickMethod
                      ,WaveKey              ,EffectiveDate     ,ArchiveCop
                      ,ShipFlag             ,PickSlipNo        ,@c_NewPickDetailKey
                      ,@n_Qty_PD - @n_QtyShort
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
                     SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20092
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to Insert new Pickdetail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                     GOTO QUIT_SP
                  END

                  -- If short pick & no split line 1st. 
                  -- Change orginal PickDetail with exact QTY (with TrafficCop)
                  UPDATE dbo.PickDetail WITH (ROWLOCK)
                  SET    QTY = @n_QtyShort
                       , TrafficCop = NULL -- (ung05)
                  WHERE  PickDetailKey = @c_PickDetailKey

                  SET @n_Err = @@ERROR

                  IF @n_Err <> 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @c_Status = '5'
                     SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20093
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to Update Pickdetail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                     GOTO QUIT_SP
                  END

                  -- Update Status to 4 without trafficCop to recalculate qtyallocate and qtypicked
                  UPDATE dbo.PickDetail WITH (ROWLOCK)
                  SET    STATUS='4'
                  WHERE  PickDetailKey = @c_PickDetailKey

                  SET @n_Err = @@ERROR

                  IF @n_Err <> 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @c_Status = '5'
                     SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20094
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to Update Pickdetail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                     GOTO QUIT_SP
                  END
                                    
                  -- Insert RefKeyLookup, if not exists
                  IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookup (NOLOCK) WHERE PickDetailKey = @c_NewPickDetailKey)
                  BEGIN
               	   SELECT TOP 1 
               	         @c_LoadKey = LOADKEY
               	   FROM ORDERS WITH (NOLOCK)
               	   WHERE OrderKey = @c_OrderKey
                  	
                     INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey, EditWho) -- SOS# 255550
                     SELECT @c_NewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, @c_LoadKey, 'TCP03a.' + sUser_sName() 
                     FROM   dbo.PickDetail WITH (NOLOCK) 
                     WHERE  PickDetailKey = @c_PickDetailKey

                     SELECT @n_Err = @@ERROR

                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_Continue = 3
                        SET @c_Status = '5'
                        SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20095
                        SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to Insert RefKeyLookup. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                        GOTO QUIT_SP
                     END
                  END
                  
               END --IF @n_Qty_PD > @n_QtyShort

               ------------ Create task for cycle count   ---------------------------
               -- Create Cycle Count Task
               SET @b_Success = 1

               EXECUTE dbo.nspg_getkey
               'TaskDetailKey'
               , 10
               , @c_TaskDetailKey OUTPUT
               , @b_Success OUTPUT
               , @n_Err     OUTPUT
               , @c_ErrMsg  OUTPUT

               IF @b_Success <> 1
               BEGIN
                  SET @n_Continue = 3
                  SET @c_Status = '5'
                  SET @c_ErrMsg = 'Get PickDetail Key Failed (isp_TCP_WCS_CARTON_CLOSE_IN).'
                  GOTO QUIT_SP
               END
               
               -- (ChewKP12)
               EXECUTE nspg_getkey
                'CCKey'
                , 10
                , @c_CCKey OUTPUT
                , @b_success OUTPUT
                , @n_Err OUTPUT
                , @c_Errmsg OUTPUT               
               
               IF NOT @b_success = 1                  
               BEGIN                  
                  SET @n_Continue = 3
                  SET @c_Status = '5'
                  SET @c_ErrMsg = 'GetKey Failed (isp_TCP_WCS_CARTON_CLOSE_IN).'
                  GOTO QUIT_SP 
               END  

               SET @c_LOC = ''
               SELECT @c_LOC = LOC
               FROM   PICKDETAIL p WITH (NOLOCK)
               WHERE  p.PickDetailKey = @c_PickDetailKey

               SET @c_LogicalLocation = ''
               SET @c_AreaKey = ''

               SELECT TOP 1
                      @c_LogicalLocation = LogicalLocation,
                      @c_AreaKey         = ISNULL(ad.AreaKey, '')
               FROM   LOC WITH (NOLOCK)
               LEFT OUTER JOIN AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = LOC.PutawayZone
               WHERE  LOC = @c_LOC

               IF ISNULL(RTRIM(@c_Loc),'') <>''
               BEGIN
                  SET @n_SystemQty = 0
                  SELECT @n_SystemQty = ISNULL(SUM(QTY - QtyPicked),0)
                  FROM   SKUxLOC sl WITH (NOLOCK)
                  WHERE  sl.StorerKey = @c_StorerKey
                  AND    sl.Sku = @c_SKU
                  AND    sl.Loc = @c_Loc
               END

               -- If not outstanding cycle count task, then insert new cycle count task
               IF NOT EXISTS(SELECT 1 FROM TaskDetail td (NOLOCK)
                             WHERE td.TaskType = 'CC'
                             AND td.FromLoc = @c_Loc
                             AND td.[Status] IN ('0','3')
                             AND td.Storerkey = @c_StorerKey
                             AND td.Sku = @c_SKU)
               BEGIN
                  INSERT INTO dbo.TaskDetail
                    (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc
                    ,FromID,ToLoc,LogicalToLoc,ToID,Caseid,PickMethod,Status,StatusMsg
                    ,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
                    ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber
                    ,ListKey,WaveKey,ReasonKey,Message01,Message02,Message03,RefTaskKey,LoadKey
                    ,AreaKey,DropID, SystemQty)
                    VALUES
                    (@c_TaskDetailKey
                     ,'CC' -- TaskType
                     ,@c_Storerkey
                     ,@c_Sku
                     ,'' -- Lot
                     ,'' -- UOM
                     ,0  -- UOMQty
                     ,0  -- Qty
                     ,@c_Loc
                     ,ISNULL(@c_LogicalLocation,'')
                     ,'' -- FromID
                     ,'' -- ToLoc
                     ,'' -- LogicalToLoc
                     ,'' -- ToID
                     ,'' -- Caseid
                     ,'SKU' -- PickMethod -- (ChewKP12)
                     ,'0' -- STATUS
                     ,''  -- StatusMsg
                     ,'5' -- Priority
                     ,''  -- SourcePriority
                     ,''  -- Holdkey
                     ,''  -- UserKey
                     ,''  -- UserPosition
                     ,''  -- UserKeyOverRide
                     ,GETDATE() -- StartTime
                     ,GETDATE() -- EndTime
                     ,'CARTONCLOSE'   -- SourceType
                     ,@c_CCKey -- SourceKey -- (ChewKP12)
                     ,'' -- PickDetailKey
                     ,'' -- OrderKey
                     ,'' -- OrderLineNumber
                     ,'' -- ListKey
                     ,'' -- WaveKey
                     ,'' -- ReasonKey
                     ,'PSHT' -- Message01
                     ,'' -- Message02
                     ,'' -- Message03
                     ,'' -- RefTaskKey
                     ,'' -- LoadKey
                     ,@c_AreaKey
                     ,'' -- DropID
                     ,@n_SystemQty)

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @c_Status = '5'
                     SET @c_ErrMsg = 'Insert TaskDetail Failed (isp_TCP_RESIDUAL_SHORT_IN).'
                     GOTO QUIT_SP
                  END
               END -- If not exists in TaskDetail
               ------------ End Cycle count task          ---------------------------
               IF @n_QtyShort > 0
               BEGIN
                  -- OffSet QtyToPick
                  SET @n_QtyShort = @n_QtyShort - @n_QTY_PD
               END

               IF @n_QtyShort = 0 OR @n_QtyShort < 0
               BEGIN
                  BREAK
               END

               FETCH NEXT FROM CursorShortPickDetail INTO @c_PickDetailKey, @n_Qty_PD, @c_LOT, @n_SortSeq -- Shong 4.1
            END -- While Loop for PickDetail Key
            CLOSE CursorShortPickDetail
            DEALLOCATE CursorShortPickDetail
         END

         /***************************************************/
         /* Insert PickHeader                               */
         /***************************************************/
         SELECT @c_LoadKey = ISNULL(RTRIM(O.LoadKey),'')
              , @c_Route = ISNULL(RTRIM(O.Route),'')
              , @c_DischargePlace = ISNULL(RTRIM(O.DischargePlace),'')
              , @c_DeliveryPlace = ISNULL(RTRIM(O.DeliveryPlace),'')
         FROM dbo.Orders O WITH (NOLOCK)
         WHERE O.Orderkey = @c_Orderkey


         SELECT TOP 1
            @c_PickSlipNo = ISNULL(RTRIM(PickHeaderKey),'')
         FROM dbo.PickHeader WITH (NOLOCK, INDEX(IX_PICKHEADER_ConsoOrderKey))
         WHERE ConsoOrderKey = @c_ConsoOrderKey --(ShongXXX)

         IF @b_Debug = 1
         BEGIN
            SELECT '@c_PickSlipNo : ' + @c_PickSlipNo
         END

         IF ISNULL(RTRIM(@c_PickSlipNo),'') = ''
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Can not find PickSlipNo for ConsoOrder : ' + RTRIM(@c_ConsoOrderKey)
                          + ' for LineNo: ' + RTRIM(@c_LineNo) + '. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
            GOTO QUIT_SP
         END -- IF ISNULL(RTRIM(@c_PickSlipNo),'') = ''


         -- (ChewKP04)
            SELECT TOP 1
                   @c_GS1LabelNo = ISNULL(LabelNo,'')
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo
              AND DropID = @c_LPNNo
              AND SKU = @c_SKU

         /***************************************************/
         /* Insert PickingInfo                              */
         /***************************************************/
         IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
         BEGIN
            INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, ScanOutDate, PickerID)
            VALUES (@c_PickSlipNo, GetDate(), GetDate(), SUSER_SNAME())

            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20096
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(Char(5),@n_Err) + ': Error Insert PickingInfo Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               GOTO QUIT_SP
            END

            IF @b_Debug = 1
            BEGIN
               SELECT 'PickingInfo created >> @c_PickSlipNo : ' + @c_PickSlipNo
            END
         END  --IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)

         IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo
                        AND ScanOutDate IS NULL)
         BEGIN
            UPDATE dbo.PickingInfo WITH (ROWLOCK)
               SET ScanOutDate = GetDate(),
                   TrafficCop  = NULL
            WHERE PickSlipNo = @c_PickSlipNo
            AND ScanOutDate IS NULL

            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20097
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(Char(5),@n_Err) + ': Error Update PickingInfo Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               GOTO QUIT_SP
            END
         END

         /***************************************************/
         /* Insert Transmitlog3 for PICKCFMLOG              */
         /***************************************************/
         SET @c_Authority_PickCfmLog = ''

         EXECUTE dbo.nspGetRight @c_Facility,
                                 @c_StorerKey,            -- Storer
                                 '',                      -- Sku
                                 @c_TableNamePick,        -- ConfigKey
                                 @b_Success               OUTPUT,
                                 @c_Authority_PickCfmLog  OUTPUT,
                                 @n_Err                   OUTPUT,
                                 @c_ErrMsg                OUTPUT

         IF @b_Success <> 1
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20098
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(Char(5),@n_Err) + ': Retrieve of Right (PICKCFMLOG) Failed. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
            GOTO QUIT_SP
         END

         IF @c_Authority_PickCfmLog = '1'
         BEGIN
            EXEC dbo.ispGenTransmitLog3 @c_TableNamePick
                                      , @c_Orderkey
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
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20099
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(Char(5),@n_Err) + ': Insert Transmitlog3 (PICKCFMLOG) Failed. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               GOTO QUIT_SP
            END
         END

         SET @n_Qty_PD = 0

         SELECT @n_Qty_PD = ISNULL(SUM(PD.QTY),0)
         FROM   dbo.PickDetail PD WITH (NOLOCK)
         WHERE  PD.OrderKey = @c_OrderKey
         AND    PD.OrderLineNumber = @c_OrderLineNumber
         AND    PD.Status = '5'  -- (ung02)
         AND    PD.CaseID = ''

         SET @n_QtyImported = @n_Qty

         /***************************************************/
         /* Generate GS1 Label                              */
         /***************************************************/
         IF ISNULL(RTRIM(@c_GS1LabelNo),'') = '' AND @n_Qty > 0 --(ung04)
         BEGIN
            EXECUTE isp_GenUCCLabelNo
                     @c_StorerKey,
                     @c_GS1LabelNo  OUTPUT,
                     @b_Success     OUTPUT,
                     @n_Err         OUTPUT,
                     @c_ErrMsg      OUTPUT

            SELECT @c_NewGS1Label = 'Y'
         END

         IF @b_Debug = 1
         BEGIN
            SELECT 'Generate GS1 >> @c_GS1LabelNo : ' + @c_GS1LabelNo
         END

         /***************************************************/
         /* Update PickDetail                               */
         /***************************************************/

         DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey
              , PD.QTY
              , PD.LOT
              , SortSeq = CASE WHEN DropID = @c_FromTote THEN 1
                               WHEN DropID = '' THEN 2
                               ELSE 9
                          END -- Shong 4.1              
         FROM   dbo.PickDetail PD WITH (NOLOCK)
         WHERE  PD.OrderKey = @c_OrderKey
         AND    PD.OrderLineNumber = @c_OrderLineNumber
         AND    PD.Status = '5'  -- (ung02)
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
                  SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20100
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Update Pickdetail Fail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
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
                  SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20101
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to retrieve new PickdetailKey. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
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
                   ,ShipFlag             ,PickSlipNo        ,@c_NewPickDetailKey
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
                  SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20102
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to Insert new Pickdetail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
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
                  SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20103
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to Update Pickdetail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                  GOTO QUIT_SP
               END
               
               -- Insert RefKeyLookup, if not exists
               IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookup (NOLOCK) WHERE PickDetailKey = @c_NewPickDetailKey)
               BEGIN
                  INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey, EditWho) -- SOS# 255550
                  VALUES (@c_NewPickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_LoadKey, 'TCP03b.' + sUser_sName())

                  SELECT @n_Err = @@ERROR

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @c_Status = '5'
                     SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20104
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Unable to Insert RefKeyLookup. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
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

                  SELECT @n_Err = @@ERROR

                  IF @n_Err <> 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @c_Status = '5'
                     SET @n_Err = 20105
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5), @n_Err) + ': Update RefKeyLookup Fail. Seq#: ' + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
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
         /* Insert PackHeader                               */
         /***************************************************/
         IF NOT EXISTS(SELECT 1 FROM dbo.PACKHEADER WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
         BEGIN
            INSERT INTO dbo.PACKHEADER
            (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, ConsoOrderKey, [STATUS]) -- (ChewKP01)
            VALUES
            (@c_PickSlipNo, @c_StorerKey, '', @c_LoadKey, @c_Route, '', '', 0, @c_ConsoOrderKey, '5') -- (ChewKP08)

            SELECT @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20106
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert PACKHEADER Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
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


         -- Prevent OverPacked -- Start (ChewKP11)
         SET @n_TotalPickedQty = 0
         SET @n_TotalPackedQty = 0

         SELECT @n_TotalPickedQty = ISNULL(SUM(QTY),0)
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE PickslipNo = @c_PickSlipNo
           AND SKU        = @c_Sku
           AND StorerKey  = @c_StorerKey
           AND DropID     = @c_LPNNo
           AND STATUS     = '5'

         SELECT @n_TotalPackedQty  = ISNULL(SUM(QTY),0)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickslipNo = @c_PickSlipNo
           AND SKU        = @c_Sku
           AND StorerKey  = @c_StorerKey
           AND DropID = @c_LPNNo

         IF @c_TraceFlag = '1' -- SOS# 259843
         BEGIN
            INSERT dbo.TraceInfo ( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5
                                 , Col1, Col2, Col3, Col4, Col5)
            VALUES ( 'isp_TCP_WCS_CARTON_CLOSE_IN', GetDate(), @n_SerialNo, @c_PickSlipNo, @c_Sku, @c_StorerKey, @c_LPNNo
                   , @n_TotalPickedQty, @n_TotalPackedQty, @n_QtyImported, '', '*1*' )
         END

         IF (ISNULL(@n_TotalPackedQty,0) + ISNULL(@n_QtyImported,0)) > ISNULL(@n_TotalPickedQty,0)
         BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20107
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error: Over Packed. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. SKU = ' + @c_SKU + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               GOTO QUIT_SP
         END
         -- Prevent OverPacked -- End (ChewKP11)

         IF EXISTS(SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                   WHERE PickSlipNo = @c_PickSlipNo
                     AND DropID = @c_LPNNo
                     AND SKU = @c_SKU)
         BEGIN
            UPDATE PACKDETAIL
               SET Qty = Qty + @n_QtyImported
            WHERE PickSlipNo = @c_PickSlipNo
              AND DropID = @c_LPNNo
              AND SKU = @c_SKU

            SELECT @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20108
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Update PACKDETAIL Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               GOTO QUIT_SP
            END
         END
         ELSE
         BEGIN
            INSERT INTO dbo.PACKDETAIL
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, Sku, Qty, DropID, RefNo)
            VALUES
            (@c_PickSlipNo, @n_CartonNo, @c_GS1LabelNo, @c_LabelLine, @c_StorerKey, @c_Sku,
             @n_QtyImported, @c_LPNNo, @c_MasterLPNNo)

            SELECT @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20109
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert PACKDETAIL Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               GOTO QUIT_SP
            END
         END

         IF @b_Debug = 1
         BEGIN
            SELECT 'PACKDETAIL created >> @c_PickSlipNo : ' + @c_PickSlipNo
         END

         /***************************************************/
         /* Insert PackInfo                                 */
         /***************************************************/
         SET @n_CartonNo = 0
         SELECT @n_CartonNo = MAX(CartonNo)
         FROM dbo.PACKDETAIL WITH (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo
         AND DropID = @c_LPNNo -- (ChewKP10)

         IF ISNULL(@n_CartonNo,0) <> 0
         BEGIN
            IF NOT EXISTS(SELECT 1 FROM dbo.PACKINFO WITH (NOLOCK)
                          WHERE PickSlipNo = @c_PickSlipNo
                            AND CartonNo = @n_CartonNo)
            BEGIN
               INSERT INTO dbo.PACKINFO
               (PickSlipNo, CartonNo, CartonType)
               VALUES
               (@c_PickSlipNo, @n_CartonNo, @c_CartonType) -- (ChewKP06)

               SELECT @n_Err = @@ERROR

               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_Status = '5'
                  SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20110
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert PACKINFO Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
                  GOTO QUIT_SP
               END

               IF @b_Debug = 1
               BEGIN
                  SELECT 'PACKINFO created >> @c_PickSlipNo : ' + @c_PickSlipNo
                       + ', CartonNo : ' + CONVERT(VARCHAR, @n_CartonNo)
               END
            END -- Not Exists in PackInfo
         END

         -- Insert Dropid  (james02)
         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @c_LPNNo)
         BEGIN
            INSERT INTO dbo.DropID (DropID, LabelPrinted, [Status], PickSlipNo, LoadKey)
               VALUES (@c_LPNNo, '1', '9', @c_PickSlipNo, @c_LoadKey)

            SELECT @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20111
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert DropID Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               GOTO QUIT_SP
            END
         END

      END -- IF @n_SeqNo <> 1
      FETCH NEXT FROM CUR_LINE INTO @n_SeqNo, @c_LineText
   END
   CLOSE CUR_LINE
   DEALLOCATE CUR_LINE

   /***************************************************/
   /* Insert Transmitlog3 for PACKCFMLOG              */
   /* Update PackHeader                               */
   /***************************************************/
   SET @n_CntTotal = 0
   SET @n_CntPrinted = 0

--   SELECT @n_CntTotal = SUM(PD.QTY)
--   FROM   dbo.OrderDetail OD WITH (NOLOCK)
--   INNER  JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( OD.ORDERKEY = PD.ORDERKEY AND
--                                                    OD.OrderLineNumber = PD.OrderLinenUmber )
--   WHERE OD.StorerKey = @c_StorerKey
--   AND   OD.ConsoOrderKey = @c_ConsoOrderKey

   SELECT @n_CntTotal = SUM(PD.QTY)
   FROM   dbo.OrderDetail OD WITH (NOLOCK, INDEX(IX_ORDERDETAIL_ConsoOrderKey))
   INNER  JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( OD.ORDERKEY = PD.ORDERKEY AND
                                                    OD.OrderLineNumber = PD.OrderLinenUmber )
   WHERE OD.ConsoOrderKey = @c_ConsoOrderKey
   AND OD.StorerKey = @c_StorerKey

   SELECT @n_CntPrinted = SUM(PCD.QTY),
          @n_TotalCarton = COUNT(DISTINCT LabelNo)
   FROM   dbo.PACKDETAIL PCD WITH (NOLOCK)
   WHERE  PCD.PickSlipNo = @c_PickSlipNo

   -- (ChewKP06)
--   SELECT @n_TotalCarton = COUNT(DISTINCT LabelNo)
--   FROM   dbo.PACKDETAIL WITH (NOLOCK)
--   WHERE  PickSlipNo = @c_PickSlipNo


   SET @f_TotalCtnCube = @f_Cube * @n_TotalCarton

   UPDATE dbo.PackHeader WITH (ROWLOCK)
      SET TotCtnCube = @f_TotalCtnCube,
          ArchiveCop = NULL
   WHERE PICKSLIPNO = @c_PickSlipNo

   SET @n_Err = @@ERROR

   IF @n_Err <> 0
   BEGIN
         SET @n_Continue = 3
         SET @c_Status = '5'
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20112
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Update PackHeader Fail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
         GOTO QUIT_SP
   END

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
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 20113
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(char(5),@n_Err) + ': Update PackHeader Fail. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_CARTON_CLOSE_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
         GOTO QUIT_SP
      END

   END -- IF @n_CntTotal = @n_CntPrinted
   /***************************************************/
   /* Print GS1 Label                                 */
   /***************************************************/
   IF @c_NewGS1Label = 'Y'
   BEGIN

      CREATE TABLE #TMP_GSICartonLabel_XML (SeqNo int,                -- Temp table's PrimaryKey
                                            LineText NVARCHAR(1500))   -- XML column
                                            CREATE INDEX Seq_ind ON #TMP_GSICartonLabel_XML (SeqNo)

      --SET @c_TemplateID = @c_DischargePlace -- (ChewKP05)
      SET @c_PrinterID = 'WCS'

      SELECT @c_BtwPath = NSQLDescrip
      FROM RDT.NSQLCONFIG WITH (NOLOCK)
      WHERE ConfigKey = 'GS1TemplatePath'

      SET @c_CurrTemplateID = @c_BtwPath

      SET @n_PrintGS1_Error = 0

      DECLARE @c_Type char(10) -- (ung06)
      IF @c_MasterLPNNo <> ''
         SET @c_Type = 'CHILD'
      ELSE
         SET @c_Type = 'NORMAL'

      EXEC dbo.isp_PrintGS1Label
          @c_PrinterID = @c_PrinterID,
          @c_BtwPath   = @c_CurrTemplateID,
          @b_Success   = @b_success OUTPUT,
          @n_Err       = @n_PrintGS1_Error  OUTPUT,
          @c_Errmsg    = @c_ErrMsg  OUTPUT,
          @c_LabelNo   = @c_GS1LabelNo,
          @c_BatchNo   = @c_BatchNo OUTPUT,
          @c_WCSProcess = 'Y',
          @c_CartonType = @c_Type

      IF @n_PrintGS1_Error = 0
      BEGIN
         UPDATE XML_MESSAGE
            SET STATUS = '0'
         WHERE BATCHNO = @c_BatchNo
      END

      IF @b_Debug = 1
      BEGIN
         SELECT 'XML_Message Insert Successful. BatchNo : ' + @c_BatchNo
      END

   END --IF @c_NewGS1Label = 'Y'

   QUIT_SP:

   IF CURSOR_STATUS('LOCAL' , 'CUR_LINE') in (0 , 1)
   BEGIN
      CLOSE CUR_LINE
      DEALLOCATE CUR_LINE
   END

   IF @b_Debug = 1
   BEGIN
      SELECT 'Update TCPSocket_INLog >> @c_Status : ' + @c_Status
           + ', @c_ErrMsg : ' + @c_ErrMsg
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      ROLLBACK TRAN WCS_BULK_PICK
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_TCP_WCS_CARTON_CLOSE_IN'
   END

   UPDATE dbo.TCPSocket_INLog WITH (ROWLOCK)
    SET STATUS   = @c_Status
     , ErrMsg   = @c_ErrMsg
     , Editdate = GETDATE()
     , EditWho  = SUSER_SNAME()
   WHERE SerialNo = @n_SerialNo

   WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started
      COMMIT TRAN WCS_BULK_PICK

   /***************************************************/
   /* Output GS1 WCS 7                                */
   /***************************************************/
   IF @n_Continue <> 3
   BEGIN
      IF @c_NewGS1Label = 'Y'
      BEGIN
         IF @n_PrintGS1_Error= 0
         BEGIN
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
         END
      END --IF @c_NewGS1Label = 'Y'
   END --IF @n_Continue <> 3

   RETURN
END

GO