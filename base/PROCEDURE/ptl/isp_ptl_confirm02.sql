SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_PTL_Confirm02                                   */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Insert PTLTran                                              */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 25-09-2015 1.0  ChewKP   Created. Rewrite for PTL Schema             */
/* 26-04-2016 1.1  Leong    IN00028515 - Include HOLD check.            */
/* 18-07-2016 1.2  Ung      Add error handling for deadlock             */
/* 28-11-2017 1.3  ChewKP   WMS-3491, extend SKU to 8 char (ChewKP01)   */
/************************************************************************/

CREATE PROC [PTL].[isp_PTL_Confirm02] (
  @cDeviceIPAddress NVARCHAR(30),
  @cDevicePosition  NVARCHAR(20),
  @cFuncKey         NVARCHAR(2),
  @nSerialNo        INT,
  @cInputValue      NVARCHAR(20),
  @nErrNo           INT OUTPUT,
  @cErrMsg          NVARCHAR(125) OUTPUT
 )
AS
BEGIN TRY
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success             INT
       , @nTranCount            INT
       , @bDebug                INT
       , @cOrderKey             NVARCHAR(10)
       --, @cSKU                  NVARCHAR(20)
       , @cLoc                  NVARCHAR(10)
       , @cLightSequence        NVARCHAR(10)
       --, @cDevicePosition       NVARCHAR(10)
       , @cModuleAddress        NVARCHAR(10)
       , @cPriority             NVARCHAR(10)
       , @cPickSlipNo           NVARCHAR(10)
       , @cSuggLoc              NVARCHAR(10)
       , @cSuggSKU              NVARCHAR(10)
       , @cModuleName           NVARCHAR(30)
       , @cAlertMessage         NVARCHAR( 255)
       , @cUOM                  NVARCHAR(10)
       , @cPTSLoc               NVARCHAR(10)
       , @cPTLSKU               NVARCHAR(20)
       , @nExpectedQty          INT
       , @cPackKey              NVARCHAR(10)
       , @cLightMode            NVARCHAR(10)
       , @cDisplayValue         NVARCHAR(5)
       , @nCartonNo             INT
       , @cLabelLine            NVARCHAR(5)
       , @cCaseID               NVARCHAR(20)
       , @nTotalPickedQty       INT
       , @nTotalPackedQty       INT
       , @cLabelNo              NVARCHAR(20)
       , @cConsigneeKey         NVARCHAR(15)
       , @cGenLabelNoSP         NVARCHAR(30)
       , @cExecStatements       NVARCHAR(4000)
       , @cExecArguments        NVARCHAR(4000)
       , @cPickDetailKey        NVARCHAR(10)
       , @nPDQty                INT
       , @cNewPickDetailKey     NVARCHAR(10)
       , @nNewPTLTranKey        INT

       , @cUserName             NVARCHAR(18)
       , @cLightModeStatic      NVARCHAR(10)
       , @cSuggUOM              NVARCHAR(10)
       , @cPrefUOM              NVARCHAR(10)
       , @cWaveKey              NVARCHAR(10)
       , @cDeviceProfileKey     NVARCHAR(10)
       , @cDeviceID             NVARCHAR(10)
       , @cLightModeFULL        NVARCHAR(10)
       , @cVarLightMode         NVARCHAR(10)
       , @cLightPriority        NVARCHAR(1)

       , @cHoldUserID           NVARCHAR(18)
       , @cHoldDeviceProfileLogKey NVARCHAR(20)
       , @cHoldSuggSKU          NVARCHAR(20)
       , @cHoldUOM              NVARCHAR(10)
       , @cPrevDevicePosition   NVARCHAR(10)
       , @cLightModeHOLD        NVARCHAR(10)
       , @cHoldConsigneeKey     NVARCHAR(15)
       , @nHoldPTLKey           INT
       , @nVarPTLKey            INT
       , @cFullCosngineeKey     NVARCHAR(15)
       , @cHoldCondition        NVARCHAR(1)
       , @cSuggDevicePosition   NVARCHAR(10)
       , @cEndCondition         NVARCHAR(1)
       , @cLoadKey              NVARCHAR(10)
       , @cPTLConsigneeKey      NVARCHAR(15)
       , @nActualQty            INT
       , @nUOMQty               INT
       , @cPDOrderKey           NVARCHAR(10)
       , @nPackQty              INT
       , @cSuggDropID           NVARCHAR(20)
       , @nTranCount01          INT
       , @nNewExpectedQty       INT
       , @nPTLTranKey           INT
       , @nFunc                 INT
       , @cStorerKey            NVARCHAR(15)
       , @cDeviceProfileLogKey  NVARCHAR(10)
       , @cDropID               NVARCHAR(20)
       , @nQty                  INT
       , @nPTLKey               INT
       , @bSuccess              INT
       , @cStatus               NVARCHAR(5)
       , @cHoldDeviceID         NVARCHAR(10)
       , @cSecondaryPosition    NVARCHAR(10)
       , @cOrgDisplayValue      NVARCHAR(5)
       
   SET @cLoc                 = ''
   SET @cPTSLoc              = ''
   --SET @cDevicePosition      = ''
   SET @cPriority            = ''
   SET @cPickSlipNo          = ''
   SET @cUOM                 = ''
   SET @cPTSLoc              = ''
   SET @cAlertMessage        = ''
   SET @cModuleName          = ''
   SET @cPTLSKU              = ''
   SET @cUOM                 = ''
   SET @cLightMode           = ''
   SET @cDisplayValue        = ''
   SET @cCaseID              = ''
   SET @cLabelNo             = ''

   SET @cGenLabelNoSP        = ''
   SET @cExecStatements      = ''
   SET @cExecArguments       = ''
   SET @cPickDetailKey       = ''
   SET @nPDQty               = 0
   SET @cNewPickDetailKey    = ''
   SET @nNewPTLTranKey       = 0

   SET @cUserName            = ''
   SET @cLightModeStatic     = ''
   SET @cSuggUOM             = ''
   SET @cPrefUOM             = ''
   SET @cWaveKey             = ''
   SET @cDeviceProfileKey    = ''
   SET @cDeviceID            = ''
   SET @cDeviceProfileLogKey = ''
   SET @cLightModeFULL       = ''
   SET @cVarLightMode        = ''
   SET @cLightPriority       = ''
   SET @cHoldUserID          = ''
   SET @cHoldDeviceProfileLogKey = ''
   SET @cHoldSuggSKU         = ''
   SET @cHoldUOM             = ''
   SET @cPrevDevicePosition  = ''
   SET @cLightModeHOLD       = ''
   SET @cHoldConsigneeKey    = ''
   SET @nHoldPTLKey          = 0
   SET @cModuleAddress       = ''
   SET @nVarPTLKey           = 0
   SET @cFullCosngineeKey    = ''
   SET @cHoldCondition       = ''
   SET @cSuggDevicePosition  = ''
   SET @cEndCondition        = ''
   SET @cLoadKey             = ''
   SET @cPTLConsigneeKey     = ''
   SET @nActualQty           = 0
   SET @nUOMQty              = 0
   SET @cPDOrderKey          = ''
   SET @nPackQty             = 0
   SET @cOrgDisplayValue     = ''

   -- Get display value
   SELECT 
      @cDeviceID = DeviceID, 
      @cOrgDisplayValue = LEFT( DisplayValue, 5), 
      @nFunc = Func
   FROM PTL.LightStatus WITH (NOLOCK)
   WHERE IPAddress = @cDeviceIPAddress
      AND DevicePosition = @cDevicePosition

   SELECT @cLightModeStatic = Short
   FROM dbo.CodelKup WITH (NOLOCK)
   WHERE ListName = 'LightMode'
   AND Code = 'White'

   SELECT @cLightModeFULL = Short
   FROM dbo.CodelKup WITH (NOLOCK)
   WHERE ListName = 'LightMode'
   AND Code = 'Red'

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN PackInsert

   IF @cInputValue = 'END'
   BEGIN
      GOTO PROCESS_FULL_LOC
   END
   ELSE IF @cInputValue = 'FULL'
   BEGIN
      GOTO QUIT
   END
   ELSE IF LEFT(@cInputValue,1) = 'P'
   BEGIN
      SET @cLightSequence = 3
      GOTO LightSequence3
   END
   ELSE IF @cInputValue = 'HOLD' -- IN00028515
   BEGIN
      GOTO QUIT
   END
   ELSE
   BEGIN
      SET @nQty = RIGHT(@cInputValue , 3)     --CAST(@cInputValue AS INT)
   END

   -- If Quantity = 0 Terminate all the Light , and Go to UpdateDropID
   SELECT TOP 1 @cPTSLoc = PTL.DeviceID
               ,@cPTLSKU = PTL.SKU
               ,@nExpectedQty = PTL.ExpectedQty
               ,@cLightSequence = PTL.LightSequence
               ,@cOrderKey      = PTL.OrderKey
               ,@cDropID        = PTL.DropID
               --,@cDevicePosition = PTL.DevicePosition
               ,@cLightMode      = PTL.LightMode
               ,@cUOM            = PTL.UOM
               ,@cWaveKey        = PTL.SourceKey
               ,@cDeviceProfileLogKey = PTL.DeviceProfileLogKey
               ,@cConsigneeKey   = PTL.ConsigneeKey
               ,@cUserName       = PTL.AddWho
               ,@cLoc            = PTL.Loc
               ,@nPTLKey         = PTL.PTLKey
               ,@cStorerKey      = PTL.StorerKey
   FROM PTL.PTLTran PTL WITH (NOLOCK)
   WHERE IPAddress = @cDeviceIPAddress
   AND DevicePosition = @cDevicePosition
   AND Status = '1'
   Order By PTLKey DESC

   SELECT @nFunc = Func
   FROM PTL.LightStatus WITH (NOLOCK)
   WHERE IPAddress = @cDeviceIPAddress
   AND DevicePosition = @cDevicePosition

   IF @@ROWCOUNT = 0
   BEGIN
      GOTO RollBackTran
   END

   IF @cLightSequence = '1' -- Display UOM & Qty
   BEGIN
      -- ReLight For Quantity
      SET @cStatus = '1'

      SELECT TOP 1 --@cUOM = PD.UOM
           @cPackkey = SKU.PackKey
      FROM dbo.PickDetail PD WITH (NOLOCK)
      INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey
      WHERE PD.StorerKey = @cStorerKey
        AND PD.OrderKey  = @cOrderKey
        AND PD.DropID    = @cDropID
        AND PD.Status    = '5'

      SELECT @cPrefUOM = Short
      FROM dbo.CodeLkup WITH (NOLOCK)
      WHERE ListName = 'LightUOM'
      AND Code = @cUOM

      -- Update Secondary Light to PTL.Status = '9'
      DECLARE CUR_UPDATE_PTLTRAN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PTLKey
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
         AND DeviceID = @cPTSLoc
         AND DevicePosition <> @cDevicePosition
         AND Status = '1'
         AND UOM = @cUOM
         AND StorerKey = @cStorerKey

      OPEN CUR_UPDATE_PTLTRAN
      FETCH NEXT FROM CUR_UPDATE_PTLTRAN INTO @nPTLTranKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
            Status = '9', 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE PTLKey = @nPTLTranKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 91502
            SET @cErrMsg = 'Update PTLTran Fail'
            GOTO RollBackTran
         END
         FETCH NEXT FROM CUR_UPDATE_PTLTRAN INTO @nPTLTranKey
      END
      CLOSE CUR_UPDATE_PTLTRAN
      DEALLOCATE CUR_UPDATE_PTLTRAN

      EXEC PTL.isp_PTL_TerminateModule
             @cStorerKey
            ,@nFunc
            ,@cPTSLoc
            ,'1' -- Terminate by DeviceID
            ,@bSuccess    OUTPUT
            ,@nErrNo      OUTPUT
            ,@cErrMsg     OUTPUT
      IF @nErrNo <> 0
      BEGIN
          SET @nErrNo = 91532
          SET @cErrMsg = 'Terminate Light Fail'
          GOTO RollBackTran
      END

      SET @cDisplayValue = RIGHT(RTRIM(@cPrefUOM),2) + RIGHT('   ' + CAST(@nExpectedQty AS NVARCHAR(3)), 3)

      EXEC [ptl].[isp_PTL_LightUpLoc]
               @n_Func         = @nFunc
              ,@n_PTLKey       = @nPTLKey
              ,@c_DisplayValue = @cDisplayValue
              ,@b_Success      = @bSuccess    OUTPUT
              ,@n_Err          = @nErrNo      OUTPUT
              ,@c_ErrMsg       = @cErrMsg     OUTPUT
              ,@c_ForceColor   = '' --@c_ForceColor
,@c_DeviceProLogKey = @cDeviceProfileLogKey
      IF @nErrNo <> 0
      BEGIN
          SET @nErrNo = 91533
          SET @cErrMsg = 'LightUp Fail'
          GOTO RollBackTran
      END

      UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
         LightSequence = LightSequence + 1, 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME()
      WHERE PTLKey = @nPTLKey
      IF @@ERROR <> 0
      BEGIN
          SET @nErrNo = 91503
          SET @cErrMsg = 'Update PTLTran Fail'
          GOTO RollBackTran
      END
   END -- IF @cLightSequence = '1'

   IF @cLightSequence = '2' -- Confirm Qty , Light Up Next Location / "HOLD"
   BEGIN
      IF ISNULL(@nPTLKey,0 ) = 0
      BEGIN
         SET @nErrNo = 91544
         SET @cErrMsg = 'PTLKeyNotFound'
         GOTO RollBackTran
      END

      IF @nQty > @nExpectedQty
      BEGIN
         SET @nQty = @nExpectedQty
         --SET @nPTLQty = @nExpectedQty
      END

      /***************************************************/
      /* Insert PackDetail                               */
      /***************************************************/
      SET @nCartonNo = 0
      SET @cLabelLine = '00000'

      -- Get Actual Qty --
      SET @cPackKey = ''
      SELECT @cPackKey = PackKey
      FROM SKU (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cPTLSKU

      SELECT
        @nUOMQty = CASE @cUOM
                   WHEN '1' THEN Pallet
                   WHEN '2' THEN CaseCnt
                   WHEN '3' THEN InnerPack
                   WHEN '4' THEN CONVERT(INT,OtherUnit1)
                   WHEN '5' THEN CONVERT(INT,OtherUnit2)
                   WHEN '6' THEN 1
                   WHEN '7' THEN 1
                   ELSE 0
                   END
      FROM PACK (NOLOCK)
      WHERE PackKey = @cPackKey

      SET @nActualQty = @nQty * @nUOMQty

      SELECT @cCaseID = PTL.CaseID,
             @cPTLConsigneeKey = PTL.ConsigneeKey
      FROM PTL.PTLTran PTL WITH (NOLOCK)
      WHERE PTL.PTLKey = @nPTLKey
      AND   PTL.Status = '1'

     -- Update PickDetail.CaseID = LabelNo, Split Line if there is Short Pick and Create PackDetail
     DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
     SELECT  PD.PickDetailKey, PD.Qty, PD.OrderKey, PD.CaseID
     FROM dbo.Pickdetail PD WITH (NOLOCK)
     INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
     INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
     WHERE PD.DropID = @cDropID
     AND PD.Status = '5'
     AND PD.SKU    = @cPTLSKU
     --AND ISNULL(PD.CaseID,'')  = ''
     AND PD.UOM = @cUOM
     AND PD.Qty > 0
     AND O.ConsigneeKey = @cPTLConsigneeKey
     ORDER BY PD.SKU

     OPEN  CursorPickDetail
     FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty, @cPDOrderKey, @cLabelNo

     WHILE @@FETCH_STATUS <> -1
     BEGIN
        /***************************************************/
        /* Insert PackHeader                               */
        /***************************************************/
        SET @cPickSlipNo = ''
        IF NOT EXISTS(SELECT 1 FROM dbo.PACKHEADER WITH (NOLOCK) WHERE OrderKey = ISNULL(RTRIM(@cPDOrderKey),''))
        BEGIN
           EXECUTE nspg_GetKey
             'PICKSLIP'
           ,  9
           ,  @cPickslipno       OUTPUT
           ,  @b_success         OUTPUT
           ,  @nErrNo            OUTPUT
           ,  @cErrMsg           OUTPUT

           SET @cPickslipno = 'P' + @cPickslipno

           INSERT INTO dbo.PACKHEADER
           (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, ConsoOrderKey, [STATUS])
           VALUES
           (@cPickSlipNo, @cStorerKey, @cPDOrderKey, '', '', '', '', 0, '', '0')

           IF @@ERROR <> 0
           BEGIN
              SET @nErrNo = 91504
              SET @cErrMsg = 'Error Update PackDetail table.'
              GOTO RollBackTran
           END

           INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate )
           VALUES (@cPickSlipNo, GetDate(), suser_sname(), '')

           IF @@ERROR <> 0
           BEGIN
              SET @nErrNo = 91530
              SET @cErrMsg = 'Error Ins PickingInfo table.'
              GOTO RollBackTran
           END

        END
        ELSE
        BEGIN
           SELECT @cPickSlipNo = PickslipNo
           FROM dbo.PackHeader WITH (NOLOCK)
           WHERE OrderKey = @cPDOrderKey
        END

        SET @nPackQty = 0

        IF ISNULL(@cLabelNo,'' )  = ''
        BEGIN
           IF @nPDQty=@nActualQty
           BEGIN
              -- Confirm PickDetail
              UPDATE dbo.PickDetail WITH (ROWLOCK)
                 SET CaseID = CASE WHEN ISNULL(CaseID,'') = '' THEN @cCaseID ELSE CaseID END
                   , EditDate = GetDate()
                   , EditWho  = suser_sname()
                   --, UOMQty   = @nQty
                   , Trafficcop = NULL
              WHERE  PickDetailKey = @cPickDetailKey
              AND Status = '5'

              SET @nErrNo = @@ERROR
              IF @nErrNo <> 0
              BEGIN
                 SET @nErrNo = 91510
                 SET @cErrMsg = 'Update PickDetail Fail'
                 GOTO RollBackTran
              END

              SET @nPackQty = @nPDQty
           END
           ELSE
           IF @nActualQty > @nPDQty
           BEGIN
              -- Confirm PickDetail
              UPDATE dbo.PickDetail WITH (ROWLOCK)
              SET   CaseID = CASE WHEN ISNULL(CaseID,'') = '' THEN @cCaseID ELSE CaseID END
                  , EditDate = GetDate()
                  , EditWho  = suser_sname()
                  --, UOMQty   = @nQty
                  , Trafficcop = NULL
              WHERE  PickDetailKey = @cPickDetailKey
              AND Status = '5'

              SET @nErrNo = @@ERROR
              IF @nErrNo <> 0
              BEGIN
                 SET @nErrNo = 91511
                 SET @cErrMsg = 'Update PickDetail Fail'
                 GOTO RollBackTran
              END

              SET @nPackQty = @nPDQty
           END
           ELSE
           IF @nActualQty < @nPDQty AND @nActualQty > 0
           BEGIN
              IF @nActualQty > 0
              BEGIN
                 EXECUTE dbo.nspg_GetKey
                        'PICKDETAILKEY',
                        10 ,
                        @cNewPickDetailKey OUTPUT,
                        @b_success         OUTPUT,
                        @nErrNo            OUTPUT,
                        @cErrMsg           OUTPUT

                 IF @b_success<>1
                 BEGIN
                    SET @nErrNo = 91512
                    SET @cErrMsg = 'Get PickDetailKey Fail'
                    GOTO RollBackTran
                 END

                 -- Create a new PickDetail to hold the balance
                 INSERT INTO dbo.PICKDETAIL (
                      CaseID                  ,PickHeaderKey   ,OrderKey
                     ,OrderLineNumber         ,LOT             ,StorerKey
                     ,SKU                     ,AltSKU          ,UOM
                     ,UOMQTY                  ,QTYMoved        ,STATUS
                     ,DropID                  ,LOC             ,ID
                     ,PackKey                 ,UpdateSource    ,CartonGroup
                     ,CartonType              ,ToLoc           ,DoReplenish
                     ,ReplenishZone           ,DoCartonize     ,PickMethod
                     ,WaveKey                 ,EffectiveDate   ,ArchiveCop
                     ,ShipFlag                ,PickSlipNo      ,PickDetailKey
                     ,QTY                     ,TrafficCop      ,OptimizeCop
                     ,TaskDetailkey
                    )
      SELECT  CaseID               ,PickHeaderKey   ,OrderKey
                        ,OrderLineNumber      ,Lot             ,StorerKey
                        ,SKU                  ,AltSku          ,UOM
                        ,UOMQTY               ,QTYMoved        ,Status
                        ,DropID               ,LOC             ,ID
                        ,PackKey              ,UpdateSource    ,CartonGroup
                        ,CartonType           ,ToLoc           ,DoReplenish
                        ,ReplenishZone        ,DoCartonize     ,PickMethod
                        ,WaveKey              ,EffectiveDate   ,ArchiveCop
                        ,ShipFlag             ,PickSlipNo      ,@cNewPickDetailKey
                        ,@nPDQty - @nActualQty,NULL            ,'1'  --OptimizeCop,
                        ,TaskDetailKey
                 FROM   dbo.PickDetail WITH (NOLOCK)
                 WHERE  PickDetailKey = @cPickDetailKey

                 IF @@ERROR <> 0
                 BEGIN
                    SET @nErrNo = 91513
                    SET @cErrMsg = 'Insert PickDetail Fail'
                    GOTO RollBackTran
                 END

                 -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
                 -- Change orginal PickDetail with exact QTY (with TrafficCop)
                 UPDATE dbo.PickDetail WITH (ROWLOCK)
                 SET    QTY = @nActualQty
                       , CaseID = CASE WHEN ISNULL(CaseID,'') = '' THEN @cCaseID ELSE CaseID END
                       , EditDate = GetDate()
                       , EditWho  = suser_sname()
                      --, UOMQty   = @nQty
                       , Trafficcop = NULL
                 WHERE  PickDetailKey = @cPickDetailKey
                 AND Status = '5'

                 IF @@ERROR <> 0
                 BEGIN
                    SET @nErrNo = 91514
                    SET @cErrMsg = 'Update PickDetail Fail'
                    GOTO RollBackTran
                 END

                 -- Confirm orginal PickDetail with exact QTY
                   UPDATE dbo.PickDetail WITH (ROWLOCK)
                   SET    CaseID = CASE WHEN ISNULL(CaseID,'') = '' THEN @cCaseID ELSE CaseID END
                         , EditDate = GetDate()
                         , EditWho  = suser_sname()
                         , UOMQty   = @nQty
                         , Trafficcop = NULL
                   WHERE  PickDetailKey = @cPickDetailKey
                   AND Status = '5'

                   SET @nErrNo = @@ERROR
                   IF @nErrNo <> 0
                   BEGIN
                      SET @nErrNo = 91515
                      SET @cErrMsg = 'Update PickDetail Fail'
                      GOTO RollBackTran
                   END

                 SET @nPackQty = @nActualQty

              END
           END -- @nActualQty < @nPDQty
           ELSE IF @nActualQty = 0
           BEGIN
              UPDATE dbo.PickDetail WITH (ROWLOCK)
              SET    Status = '4'
                    , EditDate = GetDate()
                    , EditWho  = suser_sname()
                    --, Trafficcop = NULL (ChewKP02)
              WHERE  PickDetailKey = @cPickDetailKey
              AND Status = '5'

              IF @@ERROR <> 0
              BEGIN
                  SET @nErrNo = 91516
                  SET @cErrMsg = 'Update PickDetail Fail'
                  GOTO RollBackTran
              END
              SET @nPackQty = 0
           END -- IF @nActualQty = 0
        END
        ELSE
        BEGIN
            IF CHARINDEX( 'T' , ISNULL(@cLabelNo,'')   ) = 0
            BEGIN
               SET @nPackQty = @nPDQty
            END
        END

        IF @nPackQty > 0  AND CHARINDEX( 'T' , @cLabelNo  ) = 0
        BEGIN
          IF ISNULL(@cLabelNo , '' ) <> ''
          BEGIN
            SET @cCaseID = @cLabelNo
        END

          -- Prevent OverPacked by ConsigneeKey --
          -- Want to Check OverPack Here How To Handle ? --
          SET @nTotalPickedQty = 0
          SET @nTotalPackedQty = 0

          SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)
          FROM dbo.PickDetail PD WITH (NOLOCK)
          INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
          WHERE PD.StorerKey = @cStorerKey
            AND PD.Status    IN ('0', '5' )
            AND PD.Qty > 0
            AND O.ConsigneeKey = @cPTLConsigneeKey
            AND PD.WaveKey = @cWaveKey
            AND PD.SKU  = @cPTLSKU

          SELECT @nTotalPackedQty = ISNULL(SUM(PD.QTY),0) FROM dbo.PackDetail PD WITH (NOLOCK)
          WHERE PD.PickSlipNo = @cPickSlipNo
          AND PD.SKU = @cPTLSKU

          INSERT INTO TraceInfo (TraceName , TimeIn , Col1, Col2, Col3, Col4, col5, step1, Step2, step3, step4, step5 )
          VALUES ( 'isp_PTL_Confirm02' , GetDate() , 'PackConfirm' , @cPTLConsigneeKey, @cWaveKey , @cPTLSKU, @cPickSlipNo, @nTotalPickedQty, @nTotalPackedQty,@nActualQty ,@cCaseID,'' )

          IF (ISNULL(@nTotalPackedQty,0) + ISNULL(@nActualQty,0)) <= ISNULL(@nTotalPickedQty,0)
          BEGIN

             IF EXISTS(SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                       WHERE PickSlipNo = @cPickSlipNo
                         AND LabelNo = @cCaseID
                         AND SKU     = @cPTLSKU )
             BEGIN
                UPDATE PACKDETAIL WITH (ROWLOCK)
                  SET Qty = Qty + @nPackQty, EditDate = GETDATE(), EditWho = SUSER_SNAME()
                WHERE PickSlipNo = @cPickSlipNo
                 AND DropID = @cCaseID
                 AND SKU = @cPTLSKU
                IF @@ERROR <> 0
                BEGIN
                   SET @nErrNo = 91506
                   SET @cErrMsg = 'Update PackDetail Table Fail'
                   GOTO RollBackTran
                END
             END
             ELSE
             BEGIN
                INSERT INTO dbo.PACKDETAIL
                (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, Sku, Qty, DropID, RefNo)
                VALUES
                (@cPickSlipNo, @nCartonNo, @cCaseID, @cLabelLine, @cStorerKey, @cPTLSKU,
                 @nPackQty, @cCaseID,@cDropID)
                IF @@ERROR <> 0
                BEGIN
                    SET @nErrNo = 91507
                    SET @cErrMsg = 'Insert PackDetail Table failed'
                    GOTO RollBackTran
                END
             END
          END

          -- Pack Confirm --
          SET @nTotalPickedQty = 0
          SET @nTotalPackedQty = 0

          SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)
          FROM dbo.PickDetail PD WITH (NOLOCK)
          WHERE PD.OrderKey = @cPDOrderKey
            AND PD.StorerKey = @cStorerKey
            AND PD.Status    IN ('0', '5')

          SELECT @nTotalPackedQty = ISNULL(SUM(PD.QTY),0)
          FROM dbo.PackDetail PD WITH (NOLOCK)
          WHERE PD.PickSlipNo = @cPickSlipNo


          IF @nTotalPickedQty = @nTotalPackedQty
          BEGIN
             UPDATE PackHeader WITH (ROWLOCK)
             SET Status = '9'
             WHERE PickSlipNo = @cPickSlipNo

             IF @@ERROR <> 0
             BEGIN
                SET @nErrNo = 91522
                --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackHdrFail'
                SET @cErrMsg = 'Update PackHeader'
                GOTO RollBackTran
             END
          END

          SET @nActualQty = @nActualQty - @nPackQty -- OffSet PickQty

          -- (ChewKP01)
          IF @nActualQty < 0
          BEGIN
              SET @nActualQty = 0
          END

        END  -- IF @nActualQty > 0

        IF @nActualQty = 0
          BREAK

        FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty, @cPDOrderKey, @cLabelNo
     END -- While Loop
     CLOSE CursorPickDetail
     DEALLOCATE CursorPickDetail


      UPDATE PTL.PTLTRAN WITH (ROWLOCK)
         SET STATUS  = '9',
             Qty = @nQty, EditDate = GETDATE(), EditWho = SUSER_SNAME()
      WHERE PTLKey = @nPTLKey
      IF @@ERROR <> 0
      BEGIN
           SET @nErrNo = 91531
           SET @cErrMsg = 'Update PTLTRAN Failed'
           GOTO RollBackTran

      END

      EXEC PTL.isp_PTL_TerminateModule
             @cStorerKey
            ,@nFunc
            ,@cPTSLoc
            ,'1' -- Terminate by DeviceID
            ,@bSuccess    OUTPUT
            ,@nErrNo      OUTPUT
            ,@cErrMsg     OUTPUT
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 91534
         SET @cErrMsg = 'Terminate Light Fail'
         GOTO RollBackTran
      END

      IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                      WHERE DropID = @cCaseID
                      AND Status <> '9' )
      BEGIN
         UPDATE dbo.DropID WITH (ROWLOCK)
         SET Status = '5', EditDate = GETDATE(), EditWho = SUSER_SNAME()
         WHERE DropID = @cCaseID

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 91520
            SET @cErrMsg = 'Update DropID Fail'
            GOTO RollBackTran
         END
      END

    -- Relight when Qty <> 0 -- (ChewKP01)
    SET @nNewExpectedQty = @nExpectedQty - @nQty

    IF @nNewExpectedQty > 0 AND @nQty <> 0
    BEGIN
        -- INSERT Remaining Qty --
        INSERT INTO PTL.PTLTran
            (
               -- PTLKey -- this column value is auto-generated
               IPAddress,  DeviceID,     DevicePosition,
               [Status],   PTLType,     DropID,
               OrderKey,   Storerkey,    SKU,
               LOC,        ExpectedQty,  Qty,
               Remarks,    Lot,
               DeviceProfileLogKey, RefPTLKey, ConsigneeKey,
               CaseID, LightMode, LightSequence, AddWho, SourceKey, UOM
            )
        SELECT  IPAddress,  DeviceID,     DevicePosition,
               '0',   PTLType,     DropID,
               OrderKey,   Storerkey,    SKU,
               LOC,        @nExpectedQty - @nQty, 0,
               Remarks,    Lot,
               DeviceProfileLogKey, @nPTLKey, ConsigneeKey,
               CaseID, LightMode, '2', AddWho, SourceKey, UOM
        FROM PTL.PTLTran WITH (NOLOCK)
        WHERE PTLKEy = @nPTLKey


        SELECT @nNewPTLTranKey  = PTLKey
        FROM PTL.PTLTran WITH (NOLOCK)
        WHERE RefPTLKey = CAST(@nPTLKey AS NVARCHAR(10))
        AND Status = '0'
        AND SKU = @cPTLSKU
        AND DeviceID = @cPTSLoc
        AND LightSequence = '2'


        SELECT @cPrefUOM = Short
        FROM dbo.CodeLkup WITH (NOLOCK)
        WHERE ListName = 'LightUOM'
        AND Code = @cUOM

        SET @cDisplayValue = ''
        SET @cDisplayValue = RIGHT(RTRIM(@cPrefUOM),2) + RIGHT('   ' + CAST(@nNewExpectedQty AS NVARCHAR(3)), 3)

        EXEC [ptl].[isp_PTL_LightUpLoc]
                 @n_Func         = @nFunc
                ,@n_PTLKey       = @nNewPTLTranKey
                ,@c_DisplayValue = @cDisplayValue
                ,@b_Success      = @bSuccess    OUTPUT
                ,@n_Err          = @nErrNo      OUTPUT
                ,@c_ErrMsg       = @cErrMsg     OUTPUT
                ,@c_ForceColor   = '' --@c_ForceColor
                ,@c_DeviceProLogKey = @cDeviceProfileLogKey
        IF @nErrNo <> 0
        BEGIN
            SET @nErrNo = 91535
            SET @cErrMsg = 'LightUp Fail'
            GOTO RollBackTran
        END

        SET @nNewPTLTranKey = 0
        GOTO QUIT
    END

    IF NOT EXISTS ( SELECT 1 FROM PTL.PTLTRAN WITH (NOLOCK)
                    WHERE SourceKey = @cWaveKey
                    AND Status IN ('0', '1' )
                    AND PTLKey <> @nPTLKey
                    AND AddWho = @cUserName
          AND DeviceProfileLogKey = @cDeviceProfileLogKey  )
    BEGIN
   EXEC [ptl].[isp_PTL_LightUpLoc]
                 @n_Func         = @nFunc
                ,@n_PTLKey       = 0
                ,@c_DisplayValue = 'END'
                ,@b_Success      = @bSuccess    OUTPUT
                ,@n_Err          = @nErrNo      OUTPUT
                ,@c_ErrMsg       = @cErrMsg     OUTPUT
                ,@c_ForceColor   = '' --@c_ForceColor
                ,@c_DeviceID     = @cPTSLoc
                ,@c_DevicePos    = @cDevicePosition
                ,@c_DeviceIP     = @cDeviceIPAddress
                ,@c_LModMode     = @cLightMode
                ,@c_DeviceProLogKey = @cDeviceProfileLogKey
        IF @nErrNo <> 0
        BEGIN
            SET @nErrNo = 91536
            SET @cErrMsg = 'LightUp Fail'
            GOTO RollBackTran
        END

        GOTO QUIT
    END -- records not exisys in PTLTran

     -- If Same Location have more SKU to be PTS
     IF EXISTS ( SELECT 1 FROM PTL.PTLTran PTL WITH (NOLOCK)
                 WHERE PTL.DeviceProfileLogKey =  @cDeviceProfileLogKey
                 AND PTL.Status = '0'
                 AND PTL.DeviceID = @cPTSLoc
                 AND PTL.StorerKey  = @cStorerKey  )
     BEGIN
        SELECT TOP 1 --@cSuggLoc       = D.DeviceID
                     @cSuggSKU       = PTL.SKU
                    ,@cSuggUOM       = PTL.UOM
        FROM PTL.PTLTran PTL WITH (NOLOCK)
        INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON PTL.DeviceID = D.DeviceID AND PTL.StorerKey = D.StorerKey
        WHERE PTL.DeviceProfileLogKey =  @cDeviceProfileLogKey
        AND D.Priority = '1'
        AND PTL.Status = '0'
        AND PTL.DeviceID = @cPTSLoc
        AND D.StorerKey  = @cStorerKey
        Order by D.DeviceID, PTL.SKU

        SELECT @cSuggDevicePosition = DevicePosition
        FROM dbo.DeviceProfile WITH (NOLOCK)
        WHERE DeviceID = @cSuggLoc
        AND Priority = '1'
        AND StorerKey = @cStorerKey

        DECLARE CursorLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT PTLKey, DevicePosition, LightMode
           FROM PTL.PTLTran PTL WITH (NOLOCK)
           WHERE Status             = '0'
             AND AddWho             = @cUserName
             AND DeviceID           = @cPTSLoc
             AND SKU                = @cSuggSKU
             AND UOM                = @cSuggUOM
             AND DeviceProfileLogKey = @cDeviceProfileLogKey
           ORDER BY DeviceID, PTLKey

        OPEN CursorLightUp
        FETCH NEXT FROM CursorLightUp INTO @nVarPTLKey, @cModuleAddress, @cLightMode
        WHILE @@FETCH_STATUS <> -1
        BEGIN
           IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)
                       WHERE DeviceID = @cPTSLoc
                       AND DevicePosition = @cModuleAddress
                       AND Priority = '0'
                       AND StorerKey = @cStorerKey )
           BEGIN
              --SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 1 , 2 ) ) -- (ChewKP01) 
              SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 1 , 3 ) )
           END
           ELSE
           BEGIN
              --SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 3 , 5 ) ) -- (ChewKP01) 
              SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 4 , 5 ) )
           END

           EXEC [ptl].[isp_PTL_LightUpLoc]
                    @n_Func         = @nFunc
                   ,@n_PTLKey       = @nVarPTLKey
                   ,@c_DisplayValue = @cDisplayValue
                   ,@b_Success      = @bSuccess    OUTPUT
                   ,@n_Err          = @nErrNo      OUTPUT
                   ,@c_ErrMsg       = @cErrMsg     OUTPUT
                   ,@c_ForceColor   = '' --@c_ForceColor
                   ,@c_DeviceProLogKey = @cDeviceProfileLogKey
           IF @nErrNo <> 0
           BEGIN
               SET @nErrNo = 91538
               SET @cErrMsg = 'LightUp Fail'
               GOTO RollBackTran
           END

           FETCH NEXT FROM CursorLightUp INTO @nVarPTLKey, @cModuleAddress, @cLightMode
        END
        CLOSE CursorLightUp
        DEALLOCATE CursorLightUp

        GOTO QUIT
     END
     ELSE -- Task for Next Location
     BEGIN
        SELECT TOP 1            @cSuggLoc       = D.DeviceID
                               ,@cSuggSKU       = PTL.SKU
                               ,@cSuggUOM       = PTL.UOM
                               --,@nNewPTLTranKey = PTL.PTLKey
                               ,@cSuggDropID    = PTL.DropID
                               --,@cSuggDevicePosition = PTL.DevicePosition
        FROM PTL.PTLTran PTL WITH (NOLOCK)
        INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON PTL.DeviceID = D.DeviceID AND PTL.StorerKey = D.StorerKey
        WHERE PTL.DeviceProfileLogKey =  @cDeviceProfileLogKey
        AND D.Priority = '1'
        AND PTL.Status = '0'
        AND PTL.StorerKey = @cStorerKey
        Order by D.DeviceID, PTL.SKU

        SELECT @cSuggDevicePosition = DevicePosition
        FROM dbo.DeviceProfile WITH (NOLOCK)
        WHERE DeviceID = @cSuggLoc
        AND Priority = '1'
        AND StorerKey = @cStorerKey

        EXEC [dbo].[isp_LightUpLocCheck]
               @nPTLKey                = @nPTLKey
              ,@cStorerKey             = @cStorerKey
              ,@cDeviceProfileLogKey   = @cDeviceProfileLogKey
              ,@cLoc                   = @cSuggLoc
              ,@cType                  = 'LOCK'
              ,@nErrNo                 = @nErrNo               OUTPUT
              ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max
        IF @nErrNo <> 0
        BEGIN
           EXEC [dbo].[isp_LightUpLocCheck]
               @nPTLKey                = @nPTLKey
              ,@cStorerKey             = @cStorerKey
              ,@cDeviceProfileLogKey   = @cDeviceProfileLogKey
              ,@cLoc                   = @cPTSLOC
              ,@cType                  = 'HOLD'
              ,@nErrNo                 = @nErrNo               OUTPUT
              ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max
              ,@cNextLoc               = @cSuggLoc
              ,@cLockType              = 'HOLD'

            -- Display HOLD --
            EXEC [ptl].[isp_PTL_LightUpLoc]
                 @n_Func         = @nFunc
                ,@n_PTLKey       = 0
                ,@c_DisplayValue = 'HOLD'
                ,@b_Success      = @bSuccess    OUTPUT
                ,@n_Err          = @nErrNo      OUTPUT
                ,@c_ErrMsg       = @cErrMsg     OUTPUT
                ,@c_ForceColor   = '' --@c_ForceColor
                ,@c_DeviceID     = @cPTSLoc
                ,@c_DevicePos    = @cDevicePosition
                ,@c_DeviceIP     = @cDeviceIPAddress
                ,@c_LModMode     = @cLightModeStatic
                ,@c_DeviceProLogKey = @cDeviceProfileLogKey
           IF @nErrNo <> 0
           BEGIN
               SET @nErrNo = 91539
               SET @cErrMsg = 'LightUp Fail'
               GOTO RollBackTran
           END

           SELECT @cSecondaryPosition = DevicePosition
           FROM dbo.DeviceProfile WITH (NOLOCK)
           WHERE DeviceID = @cPTSLoc
           AND StorerKey = @cStorerKey
           AND Priority = '0'

           -- Display Next Loc --
           EXEC [ptl].[isp_PTL_LightUpLoc]
                 @n_Func         = @nFunc
                ,@n_PTLKey       = 0
                ,@c_DisplayValue = @cSuggLoc
                ,@b_Success      = @bSuccess    OUTPUT
                ,@n_Err          = @nErrNo      OUTPUT
                ,@c_ErrMsg       = @cErrMsg     OUTPUT
                ,@c_ForceColor   = '' --@c_ForceColor
                ,@c_DeviceID     = @cPTSLoc
                ,@c_DevicePos    = @cSecondaryPosition
                ,@c_DeviceIP     = @cDeviceIPAddress
                ,@c_LModMode     = @cLightModeStatic
                ,@c_DeviceProLogKey = @cDeviceProfileLogKey
           IF @nErrNo <> 0
           BEGIN
       SET @nErrNo = 91541
               SET @cErrMsg = 'LightUp Fail'
               GOTO RollBackTran
           END

        END
        ELSE
        --IF ISNULL(RTRIM(@cPTSLoc),'' )  <> ISNULL(RTRIM(@cSuggLoc),'')  AND ISNULL(RTRIM(@cSuggLoc),'')  <> ''
        BEGIN

           SELECT @cModuleAddress = DevicePosition
           FROM dbo.DeviceProfile WITH (NOLOCK)
           WHERE DeviceID           = @cPTSLoc
             AND StorerKey          = @cStorerKey
             AND Priority           = '1'
           ORDER BY DeviceID


           SET @cDisplayValue = RTRIM(@cSuggLoc)
           --SET @cVarLightMode = @cLightMode
           SET @cLightPriority = '1'

           -- Display Next Location  --
           EXEC [ptl].[isp_PTL_LightUpLoc]
                 @n_Func         = @nFunc
                ,@n_PTLKey       = 0
                ,@c_DisplayValue = @cDisplayValue
                ,@b_Success      = @bSuccess    OUTPUT
                ,@n_Err          = @nErrNo      OUTPUT
                ,@c_ErrMsg       = @cErrMsg     OUTPUT
                ,@c_ForceColor   = '' --@c_ForceColor
                ,@c_DeviceID     = @cPTSLoc
                ,@c_DevicePos    = @cDevicePosition
                ,@c_DeviceIP     = @cDeviceIPAddress
                ,@c_LModMode     = @cLightMode
                ,@c_DeviceProLogKey = @cDeviceProfileLogKey
           IF @nErrNo <> 0
           BEGIN
               SET @nErrNo = 91545
               SET @cErrMsg = 'LightUp Fail'
               GOTO RollBackTran
           END
        END

     END -- Not Exists in PTLTran


   END -- @cLightSequence = '2'

   LightSequence3:
   IF @cLightSequence = '3'
   BEGIN
      --STEP_3:
      SELECT @cPTSLoc = DeviceID
      FROM dbo.DeviceProfile (NOLOCK)
      WHERE DevicePosition = @cDevicePosition

      SET @cSuggLoc = @cInputValue

      SELECT @cDeviceProfileLogKey = DeviceProfileLogKey
            ,@cStorerKey = StorerKey
            ,@cUserName = UserName
            ,@nFunc     = Func
      FROM PTL.LightStatus WITH (NOLOCK)
      WHERE DevicePosition = @cDevicePosition
      AND IPAddress = @cDeviceIPAddress


      EXEC PTL.isp_PTL_TerminateModule
             @cStorerKey
            ,@nFunc
            ,@cPTSLoc
            ,'1' -- Terminate by DeviceID
            ,@bSuccess    OUTPUT
            ,@nErrNo      OUTPUT
            ,@cErrMsg     OUTPUT
      IF @nErrNo <> 0
      BEGIN
          SET @nErrNo = 91540
          SET @cErrMsg = 'Terminate Light Fail'
          GOTO RollBackTran
      END


      -- Light Up SKU After Confirm on Next Loc --
      SELECT TOP 1 --@cSuggLoc       = D.DeviceID
                     @cSuggSKU       = PTL.SKU
                    ,@cSuggUOM       = PTL.UOM
      FROM PTL.PTLTran PTL WITH (NOLOCK)
      INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON PTL.DeviceID = D.DeviceID AND PTL.StorerKey = D.StorerKey
      WHERE PTL.DeviceProfileLogKey =  @cDeviceProfileLogKey
      AND D.Priority = '1'
      AND PTL.Status = '0'
      AND PTL.DeviceID = @cSuggLoc
      AND D.StorerKey  = @cStorerKey
      Order by D.DeviceID, PTL.SKU

      INSERT INTO TraceInfo (TraceName , TimeIN, Col1, Col2, Col3, Col4, Col5 )
      VALUES ( 'isp_PTL_Confirm02' , GetDate() , @cDeviceProfileLogKey, @cSuggLoc, @cStorerKey, @cSuggSKU , @cSuggUOM  )


      DECLARE CursorLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PTLKey, DevicePosition, LightMode
      FROM PTL.PTLTran PTL WITH (NOLOCK)
      WHERE Status             = '0'
        --AND AddWho             = @cUserName
        AND DeviceID           = @cSuggLoc
        AND SKU                = @cSuggSKU
        AND UOM                = @cSuggUOM
        AND DeviceProfileLogKey = @cDeviceProfileLogKey
      ORDER BY DeviceID, PTLKey

      OPEN CursorLightUp
      FETCH NEXT FROM CursorLightUp INTO @nVarPTLKey, @cModuleAddress, @cLightMode
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)
                       WHERE DeviceID = @cSuggLoc
                       AND DevicePosition = @cModuleAddress
                       AND Priority = '0'
                       AND StorerKey = @cStorerKey )
           BEGIN
              --SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 1 , 2 ) ) -- (ChewKP01)
              SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 1 , 3 ) ) 
           END
           ELSE
           BEGIN
              --SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 3 , 5 ) ) -- (ChewKP01) 
              SET @cDisplayValue = RTRIM(SUBSTRING ( RTRIM(@cSuggSKU) , 4 , 5 ) ) 
           END

           EXEC [ptl].[isp_PTL_LightUpLoc]
                    @n_Func         = @nFunc
                   ,@n_PTLKey       = @nVarPTLKey
                   ,@c_DisplayValue = @cDisplayValue
                   ,@b_Success      = @bSuccess    OUTPUT
                   ,@n_Err          = @nErrNo      OUTPUT
                   ,@c_ErrMsg       = @cErrMsg     OUTPUT
                   ,@c_ForceColor   = '' --@c_ForceColor
                   ,@c_DeviceProLogKey = @cDeviceProfileLogKey
           IF @nErrNo <> 0
           BEGIN
               SET @nErrNo = 91543
               SET @cErrMsg = 'LightUp Fail'
               GOTO RollBackTran
           END

           FETCH NEXT FROM CursorLightUp INTO @nVarPTLKey, @cModuleAddress, @cLightMode
      END
      CLOSE CursorLightUp
      DEALLOCATE CursorLightUp

      -- Unlock Current User --
      EXEC [dbo].[isp_LightUpLocCheck]
         @nPTLKey                = 0
        ,@cStorerKey             = @cStorerKey
        ,@cDeviceProfileLogKey   = ''
        ,@cLoc                   = @cPTSLoc
        ,@cType                  = 'UNLOCK'
        ,@nErrNo                 = @nErrNo               OUTPUT
        ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max
      IF @nErrNo <> 0
         GOTO RollBackTran

      SELECT @cConsigneeKey = ConsigneeKey
      FROM dbo.StoreToLocDetail WITH (NOLOCK)
      WHERE Loc = @cPTSLoc

      SELECT Top 1 @cWaveKey = SourceKey
      FROM PTL.PTLTRAN WITH (NOLOCK)
      WHERE DeviceProfileLogKey = @cDeviceProfileLogKey

      GOTO PROCESS_FULL_LOC

   END -- @cLightSequence = '3'

   GOTO QUIT

   PROCESS_FULL_LOC:
   BEGIN
      -- Pack Confirm --
      SET @nTotalPickedQty = 0
      SET @nTotalPackedQty = 0
   
      SELECT @cPTSLoc = DeviceID
      FROM dbo.DeviceProfile (NOLOCK)
      WHERE DevicePosition = @cDevicePosition
   
      SELECT @cDeviceProfileLogKey = DeviceProfileLogKey
            ,@cStorerKey = StorerKey
            ,@cUserName = UserName
            ,@nFunc     = Func
      FROM PTL.LightStatus WITH (NOLOCK)
      WHERE DevicePosition = @cDevicePosition
      AND IPAddress = @cDeviceIPAddress
   
      SELECT @cConsigneeKey = ConsigneeKey
      FROM dbo.StoreToLocDetail WITH (NOLOCK)
      WHERE Loc = @cPTSLoc
   
      SELECT Top 1 @cWaveKey = SourceKey
      FROM PTL.PTLTRAN WITH (NOLOCK)
      WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
   
      SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
      WHERE PD.StorerKey = @cStorerKey
        AND PD.Status    IN ('0', '5' )
        AND PD.Qty > 0
        AND O.ConsigneeKey = @cConsigneeKey
        AND PD.WaveKey = @cWaveKey
   
      SELECT @nTotalPackedQty = ISNULL(SUM(PackD.QTY),0)
      FROM dbo.PackDetail PackD WITH (NOLOCK)
      INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PackD.PickSlipNo
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey
      WHERE O.ConsigneeKey = @cConsigneeKey
      AND O.UserDefine09 = @cWaveKey
   
      INSERT INTO TraceInfo (TraceName , TimeIn , Col1, Col2, Col3, Col4, col5, step1, Step2, step3, step4, step5 )
      VALUES ( 'isp_PTL_Confirm02' , GetDate() , 'FULLLOC' , @cConsigneeKey, @cWaveKey , @nTotalPickedQty, @nTotalPackedQty, '', '','' ,'' ,'' )
   
      IF @nTotalPickedQty = @nTotalPackedQty
      BEGIN
           EXEC [ptl].[isp_PTL_LightUpLoc]
                 @n_Func         = @nFunc
                ,@n_PTLKey       = 0
                ,@c_DisplayValue = 'FULL'
                ,@b_Success      = @bSuccess    OUTPUT
                ,@n_Err          = @nErrNo      OUTPUT
                ,@c_ErrMsg       = @cErrMsg     OUTPUT
                ,@c_ForceColor   = '' --@c_ForceColor
                ,@c_DeviceID     = @cPTSLoc
                ,@c_DevicePos    = @cDevicePosition
                ,@c_DeviceIP     = @cDeviceIPAddress
                ,@c_LModMode     = @cLightModeFULL
                ,@c_DeviceProLogKey = @cDeviceProfileLogKey
           IF @nErrNo <> 0
           BEGIN
               SET @nErrNo = 91537
               SET @cErrMsg = 'LightUp Fail'
               GOTO RollBackTran
           END
           GOTO QUIT
      END
   END

   PROCESS_HOLD_LOC:
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.PTLLockLoc WITH (NOLOCK)
                  WHERE LockType = 'HOLD'
                  AND NextLoc = @cPTSLoc )
      BEGIN
         SELECT TOP 1 @cHoldUserID = AddWho
               ,@cPrevDevicePosition = DevicePosition
               ,@cHoldDeviceID = DeviceID
         FROM dbo.PTLLockLoc WITH (NOLOCK)
         WHERE LockType = 'HOLD'
         AND NextLoc = @cPTSLoc
         ORDER BY PTLLockLocKey

         SELECT TOP 1  --@cHoldUserID = AddWho
                       @cHoldDeviceProfileLogKey = PTL.DeviceProfileLogKey
                     --, @cHoldSuggSKU = SKU
                     --, @cHoldUOM     = UOM
                     --, @cPrevDevicePosition = PTL.DevicePosition
                     --, @cHoldConsigneeKey = PTL.ConsigneeKey
                     , @nHoldPTLKey  = PTLKey
         FROM PTL.PTLTran PTL WITH (NOLOCK)
         INNER JOIN dbo.DeviceProfile DP ON DP.DeviceID = PTL.DeviceID
         WHERE PTL.DeviceID = @cPTSLoc
         AND PTL.LightSequence = '1'
         AND PTL.AddWho = @cHoldUserID -- PTLLockLOC.AddWho could be diff from PTLTran.AddHo
         AND PTL.Status = '0'
         AND DP.Priority = '1'
         Order By PTL.DeviceProfileLogKey

         IF ISNULL(@cHoldDeviceProfileLogKey,'')  <> ''
         BEGIN
            SELECT @cLightModeHOLD = DefaultLightColor
            FROM rdt.rdtUser WITH (NOLOCK)
            WHERE UserName = ISNULL(RTRIM(@cHoldUserID),'')

            -- Unlock Current User --
            EXEC [dbo].[isp_LightUpLocCheck]
               @nPTLKey                = 0
              ,@cStorerKey             = @cStorerKey
              ,@cDeviceProfileLogKey   = ''
              ,@cLoc                   = @cPTSLoc
              ,@cType                  = 'UNLOCK'
              ,@nErrNo                 = @nErrNo               OUTPUT
              ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max
            IF @nErrNo <> 0
               GOTO RollBackTran

            -- Lock Next User --
            EXEC [dbo].[isp_LightUpLocCheck]
               @nPTLKey                = @nHoldPTLKey
              ,@cStorerKey             = @cStorerKey
              ,@cDeviceProfileLogKey   = ''
              ,@cLoc                   = @cPTSLoc
              ,@cType                  = 'LOCK'
              ,@nErrNo                 = @nErrNo               OUTPUT
              ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max
            IF @nErrNo <> 0
               GOTO RollBackTran

            EXEC PTL.isp_PTL_TerminateModule
                   @cStorerKey
                  ,@nFunc
                  ,@cHoldDeviceID
                  ,'1' -- Terminate by DeviceID
                  ,@bSuccess    OUTPUT
                  ,@nErrNo      OUTPUT
                  ,@cErrMsg     OUTPUT
            IF @nErrNo <> 0
            BEGIN
         SET @nErrNo = 91542
                SET @cErrMsg = 'Terminate Light Fail'
                GOTO RollBackTran
            END

            -- Display Next Location  --
            EXEC [ptl].[isp_PTL_LightUpLoc]
                 @n_Func         = @nFunc
                ,@n_PTLKey       = 0
                ,@c_DisplayValue = @cPTSLoc
                ,@b_Success      = @bSuccess    OUTPUT
                ,@n_Err          = @nErrNo      OUTPUT
                ,@c_ErrMsg       = @cErrMsg     OUTPUT
                ,@c_ForceColor   = '' --@c_ForceColor
                ,@c_DeviceID     = @cHoldDeviceID
                ,@c_DevicePos    = @cPrevDevicePosition
                ,@c_DeviceIP     = @cDeviceIPAddress
                ,@c_LModMode     = @cLightModeHold
                ,@c_DeviceProLogKey = @cHoldDeviceProfileLogKey
            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 91546
               SET @cErrMsg = 'LightUp Fail'
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            -- Unlock Current User --
            EXEC [dbo].[isp_LightUpLocCheck]
               @nPTLKey                = 0
              ,@cStorerKey             = @cStorerKey
              ,@cDeviceProfileLogKey   = ''
              ,@cLoc                   = @cPTSLoc
              ,@cType                  = 'UNLOCK'
              ,@nErrNo                 = @nErrNo               OUTPUT
              ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max
            IF @nErrNo <> 0
               GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         -- Unlock Current User --
         EXEC [dbo].[isp_LightUpLocCheck]
            @nPTLKey                = 0
           ,@cStorerKey             = @cStorerKey
           ,@cDeviceProfileLogKey   = ''
           ,@cLoc                   = @cPTSLoc
           ,@cType                  = 'UNLOCK'
           ,@nErrNo                 = @nErrNo               OUTPUT
           ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
   END

   COMMIT TRAN PackInsert
   GOTO QUIT

   RollBackTran:
   ROLLBACK TRAN PackInsert

   -- Raise error to go to catch block
   RAISERROR ('', 16, 1) WITH SETERROR

END TRY
BEGIN CATCH
   -- Check error that cause trans become uncommitable, that need to rollback
   IF XACT_STATE() = -1
      ROLLBACK TRAN
    
      
   -- Update Error Message Back to PTL.LightInput
   --UPDATE PTL.LightInput WITH (ROWLOCK) SET 
   --   ErrorMessage = CAST(@nErrNo AS NVARCHAR(5))  + '-' +  @cErrMsg
   --WHERE DevicePosition = @cDeviceIPAddress
   --AND IPAddress = @cDevicePosition
   
   

   INSERT INTO TraceInfo (TraceName, TimeIn, step1, Step2, step3, step4, step5, Col1, Col2, Col3, Col4, col5)
   VALUES 
   ( 
      'isp_PTL_Confirm02 CATCH',                            -- TraceName
      GETDATE(),                                            -- TimeIn
      CAST( @nErrNo AS NVARCHAR( 5)),                       -- Step1
      SUBSTRING( @cErrMsg, 1, 20),                          -- Step2
      CAST( ISNULL( ERROR_NUMBER(), '') AS NVARCHAR(10)),   -- Step3
      SUBSTRING( ISNULL( ERROR_PROCEDURE(), ''), 1, 20),    -- Step4
      SUBSTRING( ISNULL( ERROR_PROCEDURE(), ''), 21, 20),   -- Step5
      CAST( ISNULL( ERROR_LINE(), '') AS NVARCHAR(10)),     -- Col1
      LTRIM( SUBSTRING( ERROR_MESSAGE(), 1, 20)),           -- Col2
      LTRIM( SUBSTRING( ERROR_MESSAGE(), 21, 20)),          -- Col3
      LTRIM( SUBSTRING( ERROR_MESSAGE(), 41, 20)),          -- Col4
      LTRIM( SUBSTRING( ERROR_MESSAGE(), 61, 20))           -- Col5
   )
   
   

   
   
   
   -- RelightUp 
   EXEC PTL.isp_PTL_LightUpLoc
      @n_Func           = @nFunc
     ,@n_PTLKey         = 0
     ,@c_DisplayValue   = @cOrgDisplayValue
     ,@b_Success        = @bSuccess    OUTPUT    
     ,@n_Err = @nErrNo      OUTPUT  
     ,@c_ErrMsg         = @cErrMsg     OUTPUT
     ,@c_DeviceID       = @cDeviceID
     ,@c_DevicePos      = @cDevicePosition
     ,@c_DeviceIP       = @cDeviceIPAddress  
     ,@c_LModMode       = '99'

   INSERT INTO TraceInfo (TraceName, TimeIn, step1, Step2, step3, step4, step5, Col1, Col2, Col3, Col4, col5)
   VALUES 
   ( 
      'isp_PTL_Confirm02 CATCH2',                           -- TraceName
      GETDATE(),                                            -- TimeIn
      ISNULL(@cDeviceIPAddress,'') ,                        -- Step1
      ISNULL(@cDevicePosition,''),                          -- Step2
      CAST( ISNULL( @nHoldPTLKey, '') AS NVARCHAR(10)),     -- Step3
      ISNULL(@cPTSLoc,''),                                  -- Step4
      CAST( ISNULL( @nPTLKey   , '') AS NVARCHAR(10)),      -- Step5
      CAST( ISNULL( @nFunc   , '') AS NVARCHAR(10)),        -- Col1
      ISNULL(@cSuggLoc,''),                                 -- Col2
      ISNULL(@cOrgDisplayValue,'') ,                        -- Col3
      ISNULL(@cDeviceID,'') ,                              -- Col4
      CAST( ISNULL( @nErrNo, '') AS NVARCHAR(10))           -- Col5
   )
END CATCH

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN




GO