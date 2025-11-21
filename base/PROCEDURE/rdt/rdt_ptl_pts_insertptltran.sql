SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PTL_PTS_InsertPTLTran                           */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert PTLTran                                              */
/*                                                                      */
/* Called from: rdtfnc_PTL_PTS                                          */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 26-11-2013 1.0  ChewKP   Created                                     */
/* 05-06-2014 1.1  ChewKP   Fixed Re-use ToteID issues (ChewKP01)       */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTL_PTS_InsertPTLTran] (
     @nMobile          INT
    ,@nFunc            INT
    ,@cFacility        NVARCHAR(5)
    ,@cStorerKey       NVARCHAR( 15)
    ,@cPTSZone         NVARCHAR( 10)
    ,@cDropID          NVARCHAR( 20)
    ,@cDropIDType      NVARCHAR( 10)
    ,@cUserName        NVARCHAR( 18)
    ,@cLangCode        NVARCHAR( 3)
    ,@nErrNo           INT         OUTPUT
    ,@cErrMsg          NVARCHAR(20) OUTPUT -- screen limitation, 20 char max
    ,@cDeviceProfileLogKey NVARCHAR(10) OUTPUT
 )
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @b_success             INT
          , @n_err                 INT
          , @c_errmsg              NVARCHAR(250)
          , @nTranCount            INT
          , @bDebug                INT
          , @cPTLType              NVARCHAR(20)
          , @cIPAddress            NVARCHAR(40)
          , @cDevicePosition       NVARCHAR(10)
          , @cOrderKey             NVARCHAR(10)
          , @cSKU                  NVARCHAR(20)
          , @cLoc                  NVARCHAR(10)
          , @nExpectedQty          INT
          , @cLot                  NVARCHAR(10)
          , @cPickDetailKey        NVARCHAR(10)
          , @cConsigneeKey         NVARCHAR(15)
          , @cDeviceProfileKey     NVARCHAR(10)
          , @cDeviceID             NVARCHAR(20)
          , @cToteID               NVARCHAR(20)
          , @cCaseID               NVARCHAR(20)
          , @cLoadKey              NVARCHAR(10)
          , @cPickSlipNo           NVARCHAR(10)
          , @cWaveKey              NVARCHAR(10)
          , @nPTLCount             INT
          , @nPDCount              INT


    SET @cPTLType          = 'Pick2PTS'
    SET @cIPAddress        = ''
    SET @cDevicePosition   = ''
    SET @cOrderKey         = ''
    SET @cSKU              = ''
    SET @cLoc              = ''
    SET @nExpectedQty      = 0
    SET @cDeviceProfileLogKey = ''
    SET @cDeviceProfileKey = ''
    SET @CDeviceID         = ''
    SET @cConsigneeKey     = ''
    SET @cToteID           = ''
    SET @cCaseID           = ''
    SET @cLoadKey          = ''
    SET @cPickSlipNo       = ''
    SET @nErrNo            = 0
    SET @cWaveKey          = ''



    SET @nTranCount = @@TRANCOUNT

    BEGIN TRAN
    SAVE TRAN PTLTran_Insert

    -- Get PickSlip & LoadKey from FromTote --
    IF @cDropIDType = 'UCC'
    BEGIN

      IF EXISTS ( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK)
                       WHERE ChildID = @cDropID
                       AND UserDefine02 <> '1' )
       BEGIN
                    SELECT Top 1 @cPickSlipNo = PD.PickSlipNo
         FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE PD.DropID = @cDropID
         AND   PD.Status = '3' -- (ChewKP01)

         SELECT @cLoadKey = LoadKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo

       END
--       SELECT
--                @cPickSlipNo = PickSlipNo
--              , @cLoadKey    = LoadKey
--       FROM dbo.DropID D WITH (NOLOCK)
--       INNER JOIN dbo.DropIDDetail DD WITH (NOLOCK) ON DD.DropID = D.DropID
--       WHERE DD.ChildID = @cDropID
--       AND DD.UserDefine02 <> '1'


    END
    ELSE IF @cDropIDType = 'TOTE'
    BEGIN
       SELECT
                @cPickSlipNo = PickSlipNo
              , @cLoadKey    = LoadKey
       FROM dbo.DropID WITH (NOLOCK)
       WHERE DropID = @cDropID
       AND Status = '5'

    END


    IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfile D WITH (NOLOCK)
                    INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = D.DeviceID
                    INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
                    --AND D.Status IN ( '1', '3')
                    AND Loc.PutawayZone = @cPTSZone
                    AND DL.UserDefine02 = @cLoadKey
                    AND D.DeviceType = 'LOC' )
    BEGIN


       EXECUTE nspg_getkey
           'DeviceProfileLogKey'
           , 10
           , @cDeviceProfileLogKey OUTPUT
           , @b_success OUTPUT
           , @nErrNo OUTPUT
           , @cErrMsg OUTPUT


      UPDATE  D
      SET   DeviceProfileLogKey = @cDeviceProfileLogKey
           , Status = '3'
      FROM dbo.DeviceProfile D WITH (NOLOCK)
      INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON Loc.Loc = D.DeviceID
      WHERE  D.Status = '1'
      AND Loc.PutawayZone = @cPTSZone
      AND DeviceType = 'Loc'

      IF @@ERROR <> ''
       BEGIN
            SET @nErrNo = 83901
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDeviceProfileFail'
            GOTO RollBackTran
       END



--      UPDATE  DL
--      SET    DeviceProfileLogKey = @cDeviceProfileLogKey
--      FROM dbo.DeviceProfileLog DL WITH (NOLOCK)
--      INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
--      INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON Loc.Loc = D.DeviceID
--      WHERE  D.Status = '1'
--       AND DL.Status = '1'
--      AND Loc.PutawayZone = @cPTSZone
--
--      IF @@ERROR <> ''
--       BEGIN
--            SET @nErrNo = 83902
--            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDeviceProfileLogFail'
--            GOTO RollBackTran
--       END
--
      -- Update DeviceProfileLog Base on StoreToLocDetail Setup --
       DECLARE CursorConsignee CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

       SELECT STL.ConsigneeKey , STL.Loc, D.DeviceProfileKey
       FROM dbo.StoreToLocDetail STL WITH (NOLOCK)
       INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = STL.Loc
       INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceID = STL.Loc
       WHERE Loc.PutawayZone = @cPTSZone
       ORDER BY STL.Loc

       OPEN CursorConsignee

       FETCH NEXT FROM CursorConsignee INTO @cConsigneeKey, @cLoc, @cDeviceProfileKey


       WHILE @@FETCH_STATUS <> -1
       BEGIN

            UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)
               SET   ConsigneeKey = @cConsigneeKey
                   , DeviceProfileLogKey = @cDeviceProfileLogKey
                   , Status = '3'
                   , UserDefine02 = @cLoadKey
            WHERE DeviceProfileKey = @cDeviceProfileKey
            AND Status = '1'


            IF @@ERROR <> ''
        BEGIN
                 SET @nErrNo = 83903
                 SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDeviceProfileLogFail'
                 GOTO RollBackTran
            END

         FETCH NEXT FROM CursorConsignee INTO @cConsigneeKey, @cLoc, @cDeviceProfileKey
       END
       CLOSE CursorConsignee
       DEALLOCATE CursorConsignee

    END
    ELSE
    BEGIN

       SELECT TOP 1 @cDeviceProfileLogKey = DL.DeviceProfileLogKey
       FROM dbo.DeviceProfileLog DL WITH (NOLOCK)
       INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
       INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = D.DeviceID
       WHERE --DL.Status IN ('3', '9')
           DL.UserDefine02 = @cLoadKey
       AND Loc.PutawayZone = @cPTSZone
       AND  D.DeviceType = 'LOC'
       ORDER BY DL.DeviceProfileLogKey

    END



    IF @cDropIDType = 'UCC'
    BEGIN
       DECLARE CursorPTLTran CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

       SELECT    D.IPAddress
            , D.DevicePosition
            , D.DeviceID
            , PD.DropID
            , ''--O.OrderKey
            , PD.StorerKey
            , PD.SKU
            , SUM(PD.Qty)
            , OD.UserDefine02
            , DL.DropID
            , O.UserDefine09 -- WaveKey
      FROM dbo.PickDetail PD WITH (NOLOCK)
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
      INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderlineNumber
      INNER JOIN dbo.StoreToLocDetail STL WITH (NOLOCK) ON STL.ConsigneeKEy = OD.UserDefine02 AND STL.StoreGroup = CASE WHEN O.Type = 'N' THEN RTRIM(O.OrderGroup) + RTRIM(O.SectionKey) ELSE 'OTHERS' END
      INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceID = STL.Loc
      INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK ) ON DL.DeviceProfileKey = D.DeviceProfileKey
      WHERE PD.StorerKey            = @cStorerKey
         AND PD.DropID              = @cDropID
         AND DL.Status              = '3'
         AND DL.DeviceProfileLogKey = @cDeviceProfileLogKey
         AND PD.Status              = '3'
         AND O.LoadKey              = @cLoadKey
         AND PD.CaseID              = '' -- (ChewKP01)
         GROUP BY D.IPAddress, D.DevicePosition, D.DeviceID, PD.DropID, PD.StorerKey, PD.SKU,
                OD.UserDefine02, DL.DeviceProfileLogKey, DL.DropID, O.UserDefine09
         ORDER BY PD.SKU

--       SELECT
--              D.IPAddress
--            , D.DevicePosition
--            , D.DeviceID
--            , PD.DropID
--            , ''--O.OrderKey
--            , PD.StorerKey
--            , PD.SKU
--            , SUM(PD.Qty)
--            , OD.UserDefine02
--            , DL.DropID
--            , O.UserDefine09 -- WaveKey
--       FROM dbo.PickDetail PD WITH (NOLOCK)
--       INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
--       INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderlineNumber
--       INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.ConsigneeKey = OD.UserDefine02
--       INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
--       WHERE PD.StorerKey           = @cStorerKey
--         AND PD.DropID              = @cDropID
--         AND DL.Status              = '3'
--         AND DL.DeviceProfileLogKey = @cDeviceProfileLogKey
--         AND PD.Status              = '3'
--         AND O.LoadKey              = @cLoadKey
--       GROUP BY D.IPAddress, D.DevicePosition, D.DeviceID, PD.DropID, PD.StorerKey, PD.SKU,
--                OD.UserDefine02, DL.DeviceProfileLogKey, DL.DropID, O.UserDefine09
--       ORDER BY PD.SKU
    END
    ELSE  IF @cDropIDType = 'TOTE'
    BEGIN
      DECLARE CursorPTLTran CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

       SELECT TOP 1
              D.IPAddress
            , D.DevicePosition
            , D.DeviceID
            , PD.DropID
            , '' -- O.OrderKey
            , PD.StorerKey
            , 'FTOTE' -- PD.SKU
            , 0 --SUM(PD.Qty)
            , OD.UserDefine02
            , DL.DropID
            , O.UserDefine09 -- WaveKey
      FROM dbo.PickDetail PD WITH (NOLOCK)
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
      INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderlineNumber
      INNER JOIN dbo.StoreToLocDetail STL WITH (NOLOCK) ON STL.ConsigneeKEy = OD.UserDefine02 AND STL.StoreGroup = CASE WHEN O.Type = 'N' THEN RTRIM(O.OrderGroup) + RTRIM(O.SectionKey) ELSE 'OTHERS' END
      INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceID = STL.Loc
      INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK ) ON DL.DeviceProfileKey = D.DeviceProfileKey
      WHERE PD.StorerKey            = @cStorerKey
         AND PD.DropID              = @cDropID
         AND DL.Status              = '3'
         AND DL.DeviceProfileLogKey = @cDeviceProfileLogKey
         AND PD.Status              = '5'
         AND O.LoadKey              = @cLoadKey
         AND PD.CaseID              = '' -- (ChewKP01)
         GROUP BY D.IPAddress, D.DevicePosition, D.DeviceID, PD.DropID, PD.StorerKey, PD.SKU,
                OD.UserDefine02, DL.DeviceProfileLogKey, DL.DropID, O.UserDefine09
         ORDER BY PD.SKU

--       SELECT TOP 1
--              D.IPAddress
--            , D.DevicePosition
--            , D.DeviceID
--            , PD.DropID
--            , '' -- O.OrderKey
--            , PD.StorerKey
--            , 'FTOTE' -- PD.SKU
--            , 0 --SUM(PD.Qty)
--            , OD.UserDefine02
--            , DL.DropID
--            , O.UserDefine09 -- WaveKey
--       FROM dbo.PickDetail PD WITH (NOLOCK)
--       INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
--       INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderlineNumber
--       INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.ConsigneeKey = OD.UserDefine02
--       INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
--       WHERE PD.StorerKey           = @cStorerKey
--         AND PD.DropID              = @cDropID
--         AND DL.Status              = '3'
--         AND DL.DeviceProfileLogKey = @cDeviceProfileLogKey
--         AND PD.Status              = '5'
--       GROUP BY D.IPAddress, D.DevicePosition, D.DeviceID, PD.DropID, PD.StorerKey, PD.SKU,
--                OD.UserDefine02, DL.DeviceProfileLogKey, DL.DropID, O.UserDefine09
--       ORDER BY D.DeviceID

    END

    OPEN CursorPTLTran

    FETCH NEXT FROM CursorPTLTran INTO @cIPAddress, @cDevicePosition, @cDeviceID, @cToteID, @cOrderKey, @cStorerKey, @cSKU,
                                       @nExpectedQty, @cConsigneeKey, @cCaseID, @cWaveKey


    WHILE @@FETCH_STATUS <> -1
    BEGIN

   -- UPDATE PTS TOTE DROPID to Status = '3' - PTS in Progress --
            IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                        WHERE DropID = @cCaseID
                        AND Status   = '1'
                        AND DropIDType = 'PTS')
                        --AND DropLoc  = @cDeviceID )
            BEGIN

               UPDATE dbo.DropID WITH (ROWLOCK)
               SET Status     = '3'
                  ,LoadKey    = @cLoadKey
                  ,PickSlipNo = @cPickSlipNo
                  ,DropLoc    = @cDeviceID
               WHERE DropID = @cCaseID
               AND Status   = '1'
               --AND DropLoc  = @cDeviceID
               AND DropIDType = 'PTS'

   IF @@ERROR <> 0
               BEGIN
                     SET @nErrNo = 83904
                     SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDropIDFail'
                     GOTO RollBackTran
               END

            END


            IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)
                            WHERE IPAddress     = @cIPAddress
                            AND DeviceID        = @cDeviceID
                            AND DevicePosition  = @cDevicePosition
                            AND OrderKey        = @cOrderKey
                            AND SKU             = @cSKU
                            AND DeviceProfileLogKey = @cDeviceProfileLogKey
                            AND Status          IN ( '0','1')
                            AND DropID          = @cDropID )
            BEGIN
                  INSERT INTO PTLTran
                  (
                     -- PTLKey -- this column value is auto-generated
                     IPAddress,  DeviceID,     DevicePosition,
                     [Status],   PTL_Type,     DropID,
                     OrderKey,   Storerkey,    SKU,
                     LOC,        ExpectedQty,  Qty,
                     Remarks,    MessageNum,   Lot,
                     DeviceProfileLogKey, SourceKey, ConsigneeKey,
                     CaseID

                  )
                  VALUES
                  (
                     @cIPAddress  ,
                     @cDeviceID   ,
                     @cDevicePosition  ,
                     '0'          ,
                     @cPTLType    ,
                     @cToteID     ,
                     @cOrderKey   ,
                     @cStorerKey ,
                     @cSKU       ,
                     ''       ,
                     @nExpectedQty ,
                     0           ,
                     ''          ,
                     ''          ,
                     ''       ,
                     @cDeviceProfileLogKey,
                     @cWaveKey,
                     @cConsigneeKey,
                     @cCaseID

                  )

                  IF @@ERROR <> ''
                  BEGIN
                     SET @nErrNo = 83900
                     SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPTLTranFail'
                     GOTO RollBackTran
                  END
            END

          FETCH NEXT FROM CursorPTLTran INTO @cIPAddress, @cDevicePosition, @cDeviceID, @cToteID, @cOrderKey, @cStorerKey, @cSKU,
                                             @nExpectedQty, @cConsigneeKey, @cCaseID, @cWaveKey

    END
    CLOSE CursorPTLTran
    DEALLOCATE CursorPTLTran

    -- Verify is anything insert into PTLTran
    IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)
                    WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
                    AND Status = '0'
                    AND DropID = @cDropID)
    BEGIN
         SET @nErrNo = 83905
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NoPackTask'
         GOTO RollBackTran
    END

    IF @cDropIDType = 'UCC'
    BEGIN
       SET @nPTLCount = 0
       SET @nPDCount  = 0

       SELECT @nPTLCount = SUM(ExpectedQty)
       FROM dbo.PTLTran WITH (NOLOCK)
       WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
         AND Status = '0'
         AND DropID = @cDropID

       SELECT @nPDCount = SUM(Qty)
       FROM dbo.PickDetail WITH (NOLOCK)
       WHERE DropID = @cDropID
       AND StorerKey = @cStorerKey
       AND Status IN ('3')

       IF ISNULL(@nPTLCount,0)  <> ISNULL(@nPDCount,0)
       BEGIN
         SET @nErrNo = 83906
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'PackLightNotMatch'
         GOTO RollBackTran
       END
    END





    GOTO QUIT


    RollBackTran:
    ROLLBACK TRAN PTLTran_Insert

   --IF @cStorerKey = 'ANF'
   --BEGIN
   --   INSERT TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
   --   VALUES ('rdt_PTL_PTS_InsertPTLTran', GETDATE(), @nMobile, @nFunc, @cFacility, @cStorerKey, @cPTSZone, @cDropID, @cDropIDType, @cDeviceProfileLogKey, '', '')
   --END

    Quit:
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN PTLTran_Insert
END

GO