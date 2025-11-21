SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_PTL_PTS_Confirm                                 */
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
/* 12-12-2013 1.0  ChewKP   Created                                     */
/* 28-04-2014 1.1  Chee     Set Qty as expectedQty if user key in qty > */
/*                          expectedQty (Chee01)                        */
/* 07-05-2014 1.2  ChewKP   Check by All PickDetail UCC QTY (ChewKP01)  */
/* 16-05-2014 1.3  Chee     Bug Fix - Add Consignee Filter (Chee02)     */ 
/* 18-05-2014 1.4  ChewKP   WCSRouting Fixes (ChewKP02)                 */
/* 20-05-2014 1.5  Chee     Add @bDebug for all TraceInfo script to     */
/*                          improve performance (Chee03)                */
/* 23-05-2014 1.6  ChewKP   Lock PA Location by PendingMoveIn (ChewKP03)*/
/* 27-05-2014 1.7  ChewKP   Delete Route Before Insert (ChewKP04)       */
/* 28-05-2014 1.8  Chee     Add empty CaseID filter because same dropid */ 
/*                          from cart picking could be used (Chee04)    */ 
/* 10-06-2014 1.9  ChewKP   Fix Label Generation Issues                 */
/*                          When PickDetail.Qty = 0, do not generate    */
/*                          LabelNo (ChewKP05)                          */
/* 17-07-2014 2.0  ChewKP   Update WCSRouting (ChewKP06)                */
/* 25-11-2014      Leong    SOS# 325919 - Add TraceInfo (Temp Only)     */  
/* 28-11-2014 2.1  ChewKP   SOS# 325919 - Add Retry of nspRDTPASTD      */  
/*                          (ChewKP07)                                  */  
/* 26-02-2015 2.2  Leong    SOS# 333573 - Set Status 0 when goto QC loc.*/  
/* 11-06-2015 2.3  Ung      SOS337296 DPP PendingMoveIn booking by ID   */     
/* 21-07-2016 2.4  ChewKP   SOS#373755-ANF WholeSale Project (ChewKP08) */  
/* 24-02-2017 2.5  TLTING   Performance tune - Editwho, Editdate        */                            
/* 30-07-2018 2.6  James    WMS-5814 Add eventlog (james01)             */ 
/* 26-02-2019 2.7  ChewKP   WMS-8056 - LF Light Link Migration          */     
/* 23-04-2021 2.8  Chermain WMS-16846 Add Channel_ID (cc01)             */
/************************************************************************/

CREATE PROC [dbo].[isp_PTL_PTS_Confirm] (
     @nPTLKey              INT
    ,@cStorerKey           NVARCHAR( 15) 
    ,@cDeviceProfileLogKey NVARCHAR(10)
    ,@cDropID              NVARCHAR( 20)  
    ,@nQty                 INT
    ,@nErrNo               INT          OUTPUT
    ,@cErrMsg              NVARCHAR(20) OUTPUT -- screen limitation, 20 char max
    
 )
AS
BEGIN
   
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @b_success             INT
          , @nTranCount            INT
          , @bDebug                INT
          , @cOrderKey             NVARCHAR(10)
          , @cSKU                  NVARCHAR(20) 
          , @cLoc                  NVARCHAR(10) 
          , @cConsigneeKey         NVARCHAR(15)
          , @cPickSlipNo           NVARCHAR(10)
          , @cToteNo               NVARCHAR(20)
          , @cPrevDeviceProfileLogKey NVARCHAR(10)
          , @nCartonNo             INT
          , @cLabelLine            NVARCHAR(5)
          , @cCaseID               NVARCHAR(20)
          , @nTotalPickedQty       INT
          , @nTotalPackedQty       INT
          , @cLabelNo  NVARCHAR(20)
          , @cDropIDType           NVARCHAR( 10)
          , @cLangCode             NVARCHAR( 3)
          , @cLoadKey              NVARCHAR(10)
          , @cModuleName           NVARCHAR(30)
          , @cAlertMessage         NVARCHAR( 255)
          , @cToDropID             NVARCHAR(20)
          , @nUCCQty               INT
          , @nPAQty                INT
          , @cPackkey              NVARCHAR(10)
          , @cUOM                  NVARCHAR(10)
          , @cLot                  NVARCHAR(10)
          , @cFromLoc              NVARCHAR(10)
          , @cToLoc                NVARCHAR(10)
          , @cAreaKey              NVARCHAR(10)
          , @cLogicalFromLoc       NVARCHAR(18)
          , @cID                   NVARCHAR(18)
          , @cTaskDetailkey        NVARCHAR(10)
          , @cLogicalToLoc         NVARCHAR(18)
          , @cSourceType           NVARCHAR(30)  
          , @cWavekey              NVARCHAR(10)
          , @cuserid               NVARCHAR(18)
          , @nPutawayCapacity      INT
          , @cPickAndDropLoc       NVARCHAR(10)
          , @cGenLabelNoSP         NVARCHAR(30)
          , @cExecStatements       NVARCHAR(4000)   
          , @cExecArguments        NVARCHAR(4000)
          , @cPTSLoc               NVARCHAR(10)
          , @cPickDetailKey        NVARCHAR(10)
          , @cPTLSKU               NVARCHAR(20)
          , @nExpectedQty          INT
          , @cLightMode            NVARCHAR(4)
          , @nNewPTLTranKey        INT
          , @cDevicePosition       NVARCHAR(10)
          , @cDeviceID             NVARCHAR(20)
          , @cDisplayValue         NVARCHAR(5)
          , @cNewPickDetailKey     NVARCHAR(10)
          , @nPDQty                INT
          , @nPTLQty               INT
          , @n_ErrNo               INT
          , @c_ErrMsg              NVARCHAR(20)
          , @cWCS                  NVARCHAR(1) 
          , @cPutawayZone          NVARCHAR(10) 
          , @cFacility             NVARCHAR(5)
          , @cUserName             NVARCHAR(18)
          , @cShortPick            NVARCHAR(1)
          , @nSumTotalExpectedQty  INT
          , @nSumTotalPickedQty    INT
          , @nCountTask            INT
          , @cQCStation            NVARCHAR(10) 
          , @cCurrentStation       NVARCHAR(10)
          , @nRetryPA              INT  
          , @cNoToLocFlag          NVARCHAR(1)  
          , @cDelayLength          NVARCHAR(12)  
          , @nRandomInt            INT        
          , @cOrderType            NVARCHAR(10) 
          , @cPALoc                NVARCHAR(10) 
          , @cTempCounter          NVARCHAR(10)
          , @cTempUCC              NVARCHAR(20) 
          , @cLabelPrinter         NVARCHAR(10)
          , @cLabelType            NVARCHAR(30)
          , @cANFUserName          NVARCHAR(18) 
          , @nFunc                 INT
          , @bSuccess              INT
          , @cIPAddress            NVARCHAR(40)

    DECLARE @c_NewLineChar NVARCHAR(2)
    SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10) 

    SET @cSKU                 = ''
    SET @cLoc                 = ''
    SET @cConsigneeKey        = ''
    SET @cPickSlipNo          = ''
    SET @nErrNo               = 0
    --SET @cLoadKey           = ''
    SET @cToteNo              = ''
    SET @cPrevDeviceProfileLogKey = ''
    SET @cCaseID              = ''
    SET @cLabelNo             = ''
    SET @cToDropID            = ''
    SET @cPackkey             = ''
    SET @nUCCQty              = 0 
    SET @nPAQty               = 0
    SET @cUOM                 = ''
    SET @cLot                 = ''
    SET @cFromLoc             = ''
    SET @cToLoc               = ''
    SET @cAreaKey             = ''
    SET @cLogicalFromLoc      = ''
    SET @cTaskDetailKey       = ''
    SET @cLogicalToLoc        = ''
    SET @cSourceType          = 'PTS'
    SET @cWavekey             = ''
    SET @cuserid              = suser_sname()
    SET @nPutawayCapacity     = 0
    SET @cPickAndDropLoc      = ''
    SET @cGenLabelNoSP        = ''
    SET @cExecArguments       = ''
    SET @cExecStatements      = ''
    SET @cPickDetailKey       = ''
    SET @cPTLSKU              = ''
    SET @nExpectedQty         = 0
    SET @cLightMode           = ''
    SET @nNewPTLTranKey       = 0
    SET @cDevicePosition      = ''
    SET @cDeviceID            = ''
    SET @cDisplayValue        = ''
    SET @cNewPickDetailKey    = ''
    SET @nPDQty               = 0
    SET @nPTLQty              = @nQty
    SET @n_ErrNo              = 0
    SET @c_ErrMsg             = ''
    SET @cWCS                 = ''
    SET @cPutawayZone         = ''
    SET @cFacility            = ''
    SET @cUserName            = '' --suser_sname()
    SET @cShortPick           = ''
    SET @nCountTask           = 0 
    SET @cQCStation           = ''
    SET @cCurrentStation      = ''
    SET @bDebug               = 0 -- Chee03
    SET @nRetryPA             = 0  -- (ChewKP07)  
    SET @cNoToLocFlag         = '' -- (ChewKP07)  

    
    DECLARE @nMobile    INT
    DECLARE @nPD_Qty    INT
    DECLARE @nSUMPD_Qty INT
    DECLARE @cSourceKey NVARCHAR( 20)

    SELECT @cQCStation = ISNULL(RTRIM(Short),'') 
    FROM dbo.CodeLkup WITH (NOLOCK)
    WHERE Listname = 'WCSSation' 
    AND Code = 'QC01'
    
    SELECT @cWCS = SValue 
    FROM dbo.StorerConfig WITH (NOLOCK)
    WHERE ConfigKey = 'WCS' 
    AND StorerKey = @cStorerKey
    
    IF @bDebug = 1 -- (Chee03)
    BEGIN
       INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
       VALUES ( 'PTS', GETDATE(), '1-2', 'MAIN SP', @cDropID, '', '' )
    END

    SET @nTranCount = @@TRANCOUNT
    
    BEGIN TRAN
    SAVE TRAN PackInsert
    
      

    -- If Quantity = 0 Terminate all the Light , and Go to UpdateDropID
    SET @cPTSLoc = ''  
    SELECT TOP 1 @cPTSLoc = PTL.DeviceID  
                  ,@cPTLSKU = PTL.SKU 
                  ,@nExpectedQty = PTL.ExpectedQty
                  ,@cSourceKey = SourceKey
                  ,@cUserName = EditWho
                  ,@cIPAddress = IPAddress
    FROM dbo.PTLTran PTL WITH (NOLOCK)   
    WHERE PTL.PTLKey = @nPTLKey

    SELECT @nMobile = Mobile
    FROM RDT.RDTMOBREC WITH (NOLOCK)
    WHERE UserName = @cUserName


    -- (Chee01) 
    IF @nQty > @nExpectedQty
    BEGIN
       SET @nQty = @nExpectedQty
       SET @nPTLQty = @nExpectedQty
    END
    
    SELECT @cFacility = Facility 
    FROM dbo.Loc WITH (NOLOCK) 
    WHERE Loc = @cPTSLoc
          
    SELECT @cPutawayZone = PutawayZone
    FROM dbo.Loc WITH (NOLOCK)
    WHERE Loc = @cPTSLoc 
    AND Facility = @cFacility
    

    SELECT @cCurrentStation = ISNULL(RTRIM(SHORT), '')                  
    FROM CODELKUP WITH (NOLOCK)                  
    WHERE Listname = 'WCSSTATION'                  
    AND   Code = @cPutawayZone 

   
   
--    IF @nQty = 0 AND ISNULL(RTRIM(@cPTLSKU),'') <> 'FTOTE'
--    BEGIN
--
--   
--      EXEC [dbo].[isp_DPC_TerminateModule]   
--            @cStorerKey  
--           ,@cPTSLoc    
--           ,@b_Success    OUTPUT    
--           ,@nErrNo       OUTPUT  
--           ,@cErrMsg      OUTPUT  
--        
--      IF @nErrNo <> 0   
--      BEGIN  
--          SET @cErrMsg = LEFT(@cErrMsg,1024)   
--          GOTO RollBackTran
--      END   
--
--      GOTO UpdateDropID
--    END
    
 


    SELECT @cGenLabelNoSP = SValue
    FROM dbo.StorerConfig WITH (NOLOCK)
    WHERE StorerKey = @cStorerKey
    AND ConfigKey = 'GenLabelNo_SP'

         
    IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = ISNULL(RTRIM(@cGenLabelNoSP),'') AND type = 'P')  
    BEGIN
            
          SET @nErrNo = 84062
          --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackHFail'
          SET @cErrMsg = 'GenLblSPNotFound'
          GOTO RollBackTran
    END

   
 
    
    IF EXISTS ( SELECT 1 FROM dbo.UCC (NOLOCK) WHERE UccNo = ISNULL(RTRIM(@cDropID),'') ) 
    BEGIN
      SET @cDropIDType = 'UCC'
    END
    ELSE
    BEGIN
      
      SELECT @cLoadKey = LoadKey
      FROM dbo.DropID WITH (NOLOCK) 
      WHERE DropID = @cDropID
      AND Status = '5'

      SELECT @cToDropID = CaseID
      FROM PTL.PTLTran WITH (NOLOCK)
      WHERE PTLKey = @nPTLKey

    SET @cDropIDType = 'TOTE'
    END


    
--    SELECT @nQty = Qty 
--    FROM PTL.PTLTran WITH (NOLOCK)
--    WHERE PTLKey = @nPTLKey
    
    IF @cDropIDType = 'UCC'
    BEGIN
       SELECT TOP 1 @cPickSlipNo = PD.PickSlipNo 
                    , @cConsigneeKey = PTL.ConsigneeKey
                    , @cLoadKey = O.LoadKey
                    , @cOrderType = O.Type -- (ChewKP08)
       FROM PTL.PTLTran PTL WITH (NOLOCK)
       INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON  PD.DropID = PTL.DropID AND PD.SKU = PTL.SKU AND PTL.StorerKey = PD.StorerKey
       INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
       WHERE PTL.DeviceProfileLogKey = @cDeviceProfileLogKey
       AND PTL.StorerKey = @cStorerKey
       AND PTL.DropID   = @cDropID
       AND PD.Status    = '3'
       AND PTL.Status   = '1'
       AND PTL.PTLKey   = @nPTLKey

       

       

    END
    ELSE IF @cDropIDType = 'TOTE'
    BEGIN
       SELECT @cConsigneeKey = PTL.ConsigneeKey
       FROM PTL.PTLTran PTL WITH (NOLOCK)
       INNER JOIN dbo.DeviceProfileLog DP WITH (NOLOCK) ON DP.DeviceProfileLogKey = PTL.DeviceProfileLogKey
       WHERE PTL.DeviceProfileLogKey = @cDeviceProfileLogKey
       AND PTL.StorerKey = @cStorerKey
       AND PTL.CaseID    = @cToDropID
       AND PTL.Status    = '1'
       AND PTL.PTLKey   = @nPTLKey
       
       SELECT @cPickSlipNo = PickHeaderKey 
       FROM dbo.PickHeader WITH (NOLOCK)
       WHERE LoadKey = @cLoadKey
       

--       IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)
--                       WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
--                       AND DropID = @cToDropID
--                       AND Status = '3'
--                       AND UserDefine02 = @cLoadKey
--                       AND ConsigneeKey = @cConsigneeKey ) 
--       BEGIN
--          SET @nErrNo = 84079
--          --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NoOpenCarton'
--          SET @cErrMsg = 'Error No Open Carton for PTS. DropID:' + @cToDropID + ', DeviceProfileLogKey :  '  + @cDeviceProfileLogKey + ', LoadKey: ' + @cLoadKey  + ', ConsigneeKey: ' + @cConsigneeKey
--          
--          GOTO RollBackTran
--       END
    END
    
    /***************************************************/
    /* Insert PackHeader                               */
    /***************************************************/
    IF NOT EXISTS(SELECT 1 FROM dbo.PACKHEADER WITH (NOLOCK) WHERE PickSlipNo = ISNULL(RTRIM(@cPickSlipNo),''))
    BEGIN
       INSERT INTO dbo.PACKHEADER
       (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, ConsoOrderKey, [STATUS]) 
       VALUES
       (@cPickSlipNo, @cStorerKey, '', @cLoadKey, '', '', '', 0, '', '0') 
       
       IF @@ERROR <> 0
       BEGIN
          SET @nErrNo = 84051
          --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackHFail'
          SET @cErrMsg = 'Error Update PackDetail table.'
          GOTO RollBackTran
       END
    END 
    
    /***************************************************/
    /* Insert PackDetail                               */
    /***************************************************/
    SET @nCartonNo = 0
    SET @cLabelLine = '00000'
    
    IF @bDebug = 1 -- (Chee03)
    BEGIN
       INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
       VALUES ( 'PTS', GETDATE(), '1-1', @cDropIDType, @cDropID, '', '')
    END         
    
    IF @cDropIDType = 'UCC'
    BEGIN     
       DECLARE CursorPackDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
                      
--       SELECT 
--              PTL.SKU
--            , PTL.CaseID
--       FROM PTL.PTLTran PTL WITH (NOLOCK)
--       INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.DeviceProfileLogKey = PTL.DeviceProfileLogKey AND DL.DropID = PTL.CaseID
-- WHERE PTL.StorerKey           = @cStorerKey
--         AND PTL.DropID              = @cDropID
--         AND PTL.Status              = '1'
--         AND PTL.DeviceProfileLogKey = @cDeviceProfileLogKey
--         AND PTL.ConsigneeKey        = @cConsigneeKey
--         AND DL.Status               = '3'
--         AND PTL.PTLKey              = @nPTLKey
--       ORDER BY PTL.PTLKey

       SELECT 
              PTL.SKU
            , PTL.CaseID
       FROM PTL.PTLTran PTL WITH (NOLOCK)
       WHERE 
         PTL.Status                  = '1'
         AND PTL.DeviceProfileLogKey = @cDeviceProfileLogKey
         AND PTL.PTLKey              = @nPTLKey
       ORDER BY PTL.PTLKey
       
       OPEN CursorPackDetail            
      
       FETCH NEXT FROM CursorPackDetail INTO @cSKU, @cCaseID
       
      
       WHILE @@FETCH_STATUS <> -1     
       BEGIN
             SET @nSUMPD_Qty = 0

             -- Prevent OverPacked by ConsigneeKey -- 
             -- Want to Check OverPack Here How To Handle ? --
             SET @nTotalPickedQty = 0
             SET @nTotalPackedQty = 0
             
             SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)
             FROM dbo.PickDetail PD WITH (NOLOCK) 
             INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
             INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey 
             INNER JOIN dbo.LoadPlanDetail LP WITH (NOLOCK) ON LP.OrderKey = PD.OrderKey
             WHERE PD.PickslipNo  = @cPickSlipNo
             AND   LP.LoadKey     = @cLoadKey
             AND   PD.StorerKey   = @cStorerKey
             AND   PD.SKU         = @cSKU
             AND   PD.Status      IN ('3','5')
             AND   OD.UserDefine02 = @cConsigneeKey
   
             
             
--             SELECT @nTotalPackedQty = ISNULL(SUM(PTL.QTY),0)
--             FROM   dbo.PACKDETAIL PCD WITH (NOLOCK)
--             INNER JOIN PTL.PTLTran PTL WITH (NOLOCK) ON PTL.CaseID = PCD.DropID
--             --INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
--             WHERE  PCD.PickSlipNo          = @cPickSlipNo
--             AND    PCD.StorerKey           = @cStorerKey 
--             AND    PCD.SKU                 = @cSKU
--             AND    PTL.DeviceProfileLogKey = @cDeviceProfileLogKey
--             AND    PTL.ConsigneeKey         = @cConsigneeKey
--             AND    PTL.Status              = '9'

             SELECT @nTotalPackedQty = ISNULL(SUM(PD.QTY),0) FROM dbo.PackDetail PD WITH (NOLOCK) 
             INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.DropID = PD.DropID
             where PD.PickSlipNo = @cPickSlipNo 
             and PD.SKU = @cSKU
             and DL.DeviceProfileLogKey = @cDeviceProfileLogKey
             and DL.ConsigneeKey = @cConsigneeKey

             

             IF @bDebug = 1 -- (Chee03)
             BEGIN
                INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
                VALUES ( 'PTS', GETDATE(), '2-1', @cPickSlipNo, @cStorerKey, @cDropID, @cDeviceProfileLogKey)
             
                INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
                VALUES ( 'PTS', GETDATE(), '2-2', @cSKU,  @cConsigneeKey, @cDropID, @nTotalPackedQty )
          
                INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
                VALUES ( 'PTS', GETDATE(), '2-3', @nQty, @cDropID, @nTotalPickedQty, @cCaseID )
             END

             IF (ISNULL(@nTotalPackedQty,0) + ISNULL(@nQty,0)) > ISNULL(@nTotalPickedQty,0)
             BEGIN
                
                SET @nErrNo = 84054
                --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OverPacked'
                SET @cErrMsg = 'PackDetail OverPacked'
                GOTO RollBackTran
             END 
             
             IF EXISTS(SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE PickSlipNo = @cPickSlipNo
                        AND DropID = @cCaseID
                        AND SKU = @cSKU )
             BEGIN
                SELECT @cLabelNo = LabelNo 
                FROM dbo.PackDetail WITH (NOLOCK)
                WHERE PickSlipNo = @cPickSlipNo
                 AND DropID = @cCaseID
                 AND SKU = @cSKU
                       

                UPDATE PACKDETAIL WITH (ROWLOCK)
                  SET Qty = Qty + @nQty
                WHERE PickSlipNo = @cPickSlipNo
                 AND DropID = @cCaseID
                 AND SKU = @cSKU
                
                IF @@ERROR <> 0 
                BEGIN
                   SET @nErrNo = 84052
                   --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackDetFail'
                   SET @cErrMsg = 'Update PackDetail Table Fail'
                   GOTO RollBackTran
                END 
             END
             ELSE
             BEGIN
                IF @bDebug = 1 -- (Chee03)
                BEGIN
                   INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
                   VALUES ( 'PTS', GETDATE(), '2-3', 'ELSE', @cDropID, '', '' )
                END

                IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)       
                                WHERE PickSlipNo = @cPickSlipNo 
                                AND DropID = @cCaseID ) 
                BEGIN
                   SET @cLabelNo = @cCaseID
                   SET @cExecStatements = N'EXEC dbo.' + RTRIM( @cGenLabelNoSP) +  
                                           '   @cPickslipNo           ' +                     
                                           ' , @nCartonNo             ' + 
                                           ' , @cLabelNo     OUTPUT   ' +
                                           ' , @cStorerKey            ' + 
                                           ' , @cDeviceProfileLogKey  ' +   
                                           ' , @cConsigneeKey         ' +   
                                           ' , @b_success             ' +     
                                           ' , @nErrNo       OUTPUT   ' +  
                                           ' , @cErrMSG      OUTPUT   '   
                     
                   SET @cExecArguments =   
                             N'@cPickslipNo  nvarchar(10),       ' +  
                              '@nCartonNo    int,                ' +      
                              '@cLabelNo     nvarchar(20) OUTPUT, ' +      
                              '@cStorerKey   nvarchar(15),        ' +  
                              '@cDeviceProfileLogKey     nvarchar(10),' +  
                              '@cConsigneeKey     nvarchar(15),' +   
                              '@b_success   int,                 ' +      
                              '@nErrNo      int OUTPUT,          ' +     
                              '@cErrMSG     nvarchar(225) OUTPUT '   
                          
                    
                   EXEC sp_executesql @cExecStatements, @cExecArguments,   
                                        @cPickslipNo                 
                                      , @nCartonNo
                                      , @cLabelNo      OUTPUT
                                      , @cStorerKey                                 
                                      , '' --@cDeviceProfileLogKey -- (ChewKP05)
                                      , @cConsigneeKey                 
                                      , @b_success     
                                      , @nErrNo        OUTPUT  
                                      , @cErrMSG       OUTPUT
                               
                   IF @bDebug = 1 -- (Chee03)
                   BEGIN                 
                      INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
                      VALUES ( 'PTS', GETDATE(), '2-4', @cLabelNo, @cDropID, @nErrNo, '' )
                   END
    
                   IF @nErrNo <> 0 
                   BEGIN
                      SET @nErrNo = 84061
                      SET @cErrMsg = 'Error Generating Carton Label'
                      GOTO RollBackTran         
                   END
                END
                ELSE 
                BEGIN    
                   SELECT @cLabelNo = LabelNo 
                   FROM dbo.PackDetail WITH (NOLOCK)
                   WHERE PickSlipNo = @cPickSlipNo
                   AND DropID = @cCaseID 
   
                   IF @bDebug = 1 -- (Chee03)
                   BEGIN 
                      INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
                      VALUES ( 'PTS', GETDATE(), '2-5', @cLabelNo, @cDropID, @cCaseID, @cPickSlipNo )
                   END
                END

                IF @bDebug = 1 -- (Chee03)
                BEGIN 
                   INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
                   VALUES ( 'PTS', GETDATE(), '2-6', @cLabelNo, @cDropID, @cCaseID, @cPickSlipNo )
                END

                INSERT INTO dbo.PACKDETAIL
                (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, Sku, Qty, DropID, RefNo)
                VALUES
                (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku,
                 @nQty, @cCaseID,'')
                
                
                IF @@ERROR <> 0
                BEGIN
                   IF @bDebug = 1 -- (Chee03)
                   BEGIN 
                      INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
                      VALUES ( 'PTS', GETDATE(), '2-7', @nErrNo, @cDropID, '', '' )
                   END

                   SET @nErrNo = 84053
                   --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsPackDetFail'
                   SET @cErrMsg = 'Insert PackDetail Table failed'
                   
                   GOTO RollBackTran
                END
             END

             -- Update PickDetail.CaseID = LabelNo, Split Line if there is Short Pick
             DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
             
             SELECT  PD.PickDetailKey, PD.Qty
             FROM dbo.Pickdetail PD WITH (NOLOCK)
             INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
             INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
             WHERE PD.DropID = @cDropID
             AND PD.Status = '3'
             AND O.LoadKey = @cLoadKey
             AND PD.SKU    = @cSKU
             AND ISNULL(PD.CaseID,'')  = ''
             AND OD.UserDefine02 = @cConsigneeKey
             ORDER BY PD.SKU
             
             OPEN  CursorPickDetail
             
             FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty
             
             WHILE @@FETCH_STATUS <> -1     
             BEGIN
                
                 
                IF @bDebug = 1 -- (Chee03)
                BEGIN 
                   INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
                   VALUES ( 'PTS', GETDATE(), '2-8', @cPickDetailKey, @cDropID, '', '' )
                END
 
                IF @nPDQty=@nQTY  
                BEGIN  
                   -- Confirm PickDetail  
                   UPDATE dbo.PickDetail WITH (ROWLOCK)  
                   SET  EditWho = SUSER_SNAME(),
                        EditDate = GETDATE(),
                        CaseID = @cLabelNo,  
                        STATUS = '5'  
                   WHERE  PickDetailKey = @cPickDetailKey  
                   AND Status = '3'

                   SET @nErrNo = @@ERROR  
                   IF @nErrNo <> 0  
                   BEGIN  
                      SET @nErrNo = 84069
                      SET @cErrMsg = 'Update PickDetail Fail'
                      GOTO RollBackTran  
                   END  
                   SET @nSUMPD_Qty = @nSUMPD_Qty + @nPDQty

                   IF @bDebug = 1 -- (Chee03)
                   BEGIN                       
                      INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
                      VALUES ( 'PTS', GETDATE(), '2-9', @cPickDetailKey, @cDropID, @nPDQty, @nQTY )
                   END
                END  
                ELSE  
                  IF @nQTY > @nPDQty  
                  BEGIN  
                     -- Confirm PickDetail  
                     UPDATE dbo.PickDetail WITH (ROWLOCK)  
                     SET   EditWho = SUSER_SNAME(),
                           EditDate = GETDATE(),
                           CaseID = @cLabelNo, 
                           STATUS = '5'  
                     WHERE  PickDetailKey = @cPickDetailKey
                     AND Status = '3'  

                     SET @nErrNo = @@ERROR  
                     IF @nErrNo <> 0  
                     BEGIN  
                        SET @nErrNo = 84070
                        SET @cErrMsg = 'Update PickDetail Fail'
                        GOTO RollBackTran  
                     END  
                     
                     SET @nSUMPD_Qty = @nSUMPD_Qty + @nPDQty
                     
                     IF @bDebug = 1 -- (Chee03)
                     BEGIN                       
                        INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
                        VALUES ( 'PTS', GETDATE(), '2-10', @cPickDetailKey, @cDropID, @nPDQty, @nQTY)
                     END
                  END  
                  ELSE  
                  IF @nQTY < @nPDQty AND @nQTY > 0  
                  BEGIN  
                     IF @nQty > 0 
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
                           SET @nErrNo = 84071  
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
                            ,Channel_ID )      --(cc01)    
                        SELECT CaseID               ,PickHeaderKey   ,OrderKey  
                               ,OrderLineNumber      ,Lot             ,StorerKey  
                               ,SKU                  ,AltSku          ,UOM  
                               ,UOMQTY     ,QTYMoved        ,Status
                               ,DropID               ,LOC             ,ID  
                               ,PackKey              ,UpdateSource    ,CartonGroup  
                               ,CartonType           ,ToLoc           ,DoReplenish  
                               ,ReplenishZone        ,DoCartonize     ,PickMethod  
                               ,WaveKey              ,EffectiveDate   ,ArchiveCop  
                                ,ShipFlag            ,PickSlipNo      ,@cNewPickDetailKey  
                               ,@nPDQty - @nQTY      ,NULL            ,'1'  --OptimizeCop,  
                               ,TaskDetailKey  
                               ,Channel_ID --(cc01)  
                        FROM   dbo.PickDetail WITH (NOLOCK)  
                        WHERE  PickDetailKey = @cPickDetailKey  
             
                        IF @@ERROR <> 0  
                        BEGIN  
                           SET @nErrNo = 84072  
                           SET @cErrMsg = 'Insert PickDetail Fail'
                           GOTO RollBackTran  
                        END  
              
                        -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop  
                        -- Change orginal PickDetail with exact QTY (with TrafficCop)  
                        UPDATE dbo.PickDetail WITH (ROWLOCK)  
                        SET   EditWho = SUSER_SNAME(),
                              EditDate = GETDATE(),
                              QTY = @nQty,
                              Trafficcop = NULL  
                        WHERE  PickDetailKey = @cPickDetailKey
                        AND Status = '3'  
                 
                        IF @@ERROR <> 0  
                        BEGIN  
                           SET @nErrNo = 84073  
                           SET @cErrMsg = 'Update PickDetail Fail'
                           GOTO RollBackTran  
                        END  
                 
                        -- Confirm orginal PickDetail with exact QTY  
                        UPDATE dbo.PickDetail WITH (ROWLOCK)  
                        SET   EditWho = SUSER_SNAME(),
                              EditDate = GETDATE(),
                              CaseID = @cLabelNo,      
                              STATUS = '5'  
                        WHERE  PickDetailKey = @cPickDetailKey  
                        AND Status = '3'
                           
                        SET @nErrNo = @@ERROR  
                        IF @nErrNo <> 0  
                        BEGIN  
                           SET @nErrNo = 84074
                           SET @cErrMsg = 'Update PickDetail Fail'
                           GOTO RollBackTran  
                        END  
                        
                        SET @nSUMPD_Qty = @nSUMPD_Qty + @nQty
                        
                        IF @bDebug = 1 -- (Chee03)
                        BEGIN                       
                           INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
                           VALUES ( 'PTS', GETDATE(), '2-11', @cPickDetailKey, @cDropID, @nPDQty, @nQTY )
                        END        
                     END
                  END  
                  ELSE IF @nQty = 0 
                  BEGIN
                     UPDATE dbo.PickDetail WITH (ROWLOCK)  
                     SET   EditWho = SUSER_SNAME(),
                           EditDate = GETDATE(),
                           Status = '4'
                     WHERE  PickDetailKey = @cPickDetailKey
                     AND Status = '3'  
                 
                     IF @@ERROR <> 0  
                     BEGIN  
                         SET @nErrNo = 84075  
                         SET @cErrMsg = 'Update PickDetail Fail'
                         GOTO RollBackTran  
                     END  
                     
                     SET @cShortPick = '1'
                  END
     
                  IF @nQty > 0  
                  BEGIN  
                     SET @nQty = @nQty- @nPDQty -- OffSet PickQty  
                  END  
                    
                  IF @nQty = 0 
                     BREAK
          
--               UPDATE PickDetail WITH (ROWLOCK)
--               SET CaseID = @cLabelNo, 
--                   Status = '5' --Trafficcop = NULL
--               WHERE PickDetailKey = @cPickDetailKey
--               AND Status = '3'
--               
--               IF @@ERROR <> 0 
--               BEGIN
--                  SET @nErrNo = 84067
--                   --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsDropIDDetFail'
--                   SET @cErrMsg = 'Update PickDetail Failed'
--                   GOTO RollBackTran
--               END
          
               FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty
          END
          CLOSE CursorPickDetail         
          DEALLOCATE CursorPickDetail
            
          IF NOT EXISTS ( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK)
                            WHERE DropID = @cCaseID
                            AND ChildID = @cLabelNo ) 
          BEGIN                
             INSERT INTO dbo.DropIDDetail (DropID, ChildID, UserDefine01 ) 
             VALUES ( @cCaseID , @cLabelNo, @cConsigneeKey ) 
           
             IF @@ERROR <> 0
             BEGIN
                SET @nErrNo = 84055
                --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsDropIDDetFail'
                SET @cErrMsg = 'Insert DropIDDetail Fail' 
                GOTO RollBackTran
             END      
          END

         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '8', -- Packing
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = 816,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cSKU          = @cSKU,
            @nQTY          = @nSUMPD_Qty,
            @cRefNo1       = @nPTLKey,
            @cRefNo2       = @cDropID,
            @cRefNo3       = @cSourceKey,
            @cRefNo4       = @cDropIDType,
            @cRefNo5       = @cCaseID

          FETCH NEXT FROM CursorPackDetail INTO @cSKU, @cCaseID         
       END
       CLOSE CursorPackDetail            
       DEALLOCATE CursorPackDetail   
       
       -- Create Residual Putaway For UCC
       
       IF @cWCS = '1' 
       BEGIN
             
             IF @cOrderType <> 'AFWHSALE' -- (ChewKP08)
             BEGIN 
                

                IF NOT EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                                WHERE TaskType = 'PA'
                                AND CaseID = @cDropID 
                                AND Status = '0' ) 
                BEGIN                            
                     SET @nTotalPickedQty = 0 
            
                     SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)
                     FROM dbo.PickDetail PD WITH (NOLOCK) 
                      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
                      INNER JOIN dbo.LoadPlanDetail LP WITH (NOLOCK) ON LP.OrderKey = PD.OrderKey
                      WHERE PD.PickslipNo  = @cPickSlipNo
                      AND   LP.LoadKey     = @cLoadKey
                      AND   PD.StorerKey   = @cStorerKey
                      --AND   PD.Status      IN ('3', '5', '4') -- (ChewKP01) 
                      AND   PD.DropID      = @cDropID
                     
                     SET @nUCCQty = 0 
                     SELECT @nUCCQty = UCC.Qty 
                     FROM dbo.UCC UCC WITH (NOLOCK)
                     WHERE UCC.UCCNo = @cDropID
             
                     IF @nUCCQty = @nExpectedQty 
                     BEGIN
                        GOTO CONTINUE_PROCESS
                     END
                     ELSE
                     BEGIN
                        IF @nUCCQty > @nTotalPickedQty 
                        BEGIN
                           SET @nPAQty = @nUCCQty - @nTotalPickedQty
                        END
                        ELSE
                        BEGIN
                           GOTO CONTINUE_PROCESS
                        END
                     END
                     
                     DECLARE CUR_PA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
                     SELECT TOP 1
                          PD.SKU 
                        , P.Packkey
                        , PD.UOM
                        , PD.Lot
                        , PD.Loc
                        , Loc.LogicalLocation
                        , PD.ID
                        , O.UserDefine09
                     FROM dbo.PickDetail PD WITH (NOLOCK) 
                      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
                      INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey 
                      INNER JOIN dbo.LoadPlanDetail LP WITH (NOLOCK) ON LP.OrderKey = PD.OrderKey
                      INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey
                      INNER JOIN dbo.PACK P WITH (NOLOCK) ON P.Packkey = SKU.Packkey
                      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PD.Loc
                      WHERE PD.PickslipNo  = @cPickSlipNo
                      AND   LP.LoadKey     = @cLoadKey
                      AND   PD.StorerKey   = @cStorerKey
                      AND   PD.Status      = '5'
                      AND   PD.DropID      = @cDropID
                       
                
                     OPEN CUR_PA    
              
                     FETCH NEXT FROM CUR_PA INTO --@c_Storerkey  
                                                 @cSku  
                                                ,@cPackkey  
                                                ,@cUOM  
                                                ,@cLot  
                                                ,@cFromLoc  
                                                ,@cLogicalFromLoc              
                                                ,@cID  
                                                ,@cWaveKey
                                                 
                 
                     WHILE @@FETCH_STATUS <> -1    
                     BEGIN  
                        SET @cUOM   = '6'    
                        SET @cToLoc = ''  
                 
                        SELECT TOP 1 @cAreaKey = AreaKey  
                        FROM LOC        LOC WITH (NOLOCK)  
                        JOIN AREADETAIL ARD WITH (NOLOCK) ON (LOC.PutawayZone = ARD.PutawayZone)  
                        WHERE LOC.Loc = @cFromLoc   
      
                        -- (ChewKP07)  
                        WHILE @nRetryPA < 3  
                        BEGIN  
                           SET @nRandomInt = ABS(Checksum(NewID()) % 900)  
                           SET @cDelayLength = '00:00:00.' + RIGHT('000' + CAST(@nRandomInt AS VARCHAR(3)), 3)  
                           WAITFOR DELAY @cDelayLength  
                 
                           EXEC nspRDTPASTD  
                                @cuserid             
                              , @cStorerKey          
                              , @cLot               
                              , @cSku                
                              , @cID                 
                              , @cFromLoc            
                              , @nPAQty              
                              , @cUOM               
                              , @cPackKey            
                              , @nPutawayCapacity    
                              , @cToLoc           OUTPUT  
                              , @cPickAndDropLoc  OUTPUT  
                    
                           SET @nErrNo = @@ERROR   
                           IF @nErrNo <> 0    
                           BEGIN  
                              SET @nErrNo = 84056
                              --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'RDTPASTDFailed'
                              SET @cErrMsg = 'Insert DropIDDetail Fail' 
                              GOTO RollBackTran
                           END    
         
                           IF ISNULL(RTRIM(@cStorerKey),'') = 'ANF' -- SOS# 325919  
                           BEGIN  
                              INSERT dbo.TraceInfo (TraceName, TimeIn, TotalTime, Step1, Step2, Step3, Step4, Step5  
                                                  , Col1, Col2, Col3, Col4, Col5)  
                              VALUES ('isp_PTL_PTS_Confirm - nspRDTPASTD', GETDATE(), @cuserid, @cStorerKey, @cSku, @cLot, @cFromLoc, @cID  
                                     , @nPAQty, @cUOM, @cPackKey, @nPutawayCapacity, @cToLoc)  
                           END  
                                                
                           -- (ChewKP03)
                           IF @cToLoc <> ''  
                           BEGIN  
                              DECLARE @cToID NVARCHAR(18)
                              SET @cToID = RIGHT( RTRIM( @cDropID), 18)
                              
                              EXEC rdt.rdt_Putaway_PendingMoveIn @cuserid, 'LOCK'  
                                 ,@cFromLoc  
                                 ,@cID  
                                 ,@cToLoc  
                                 ,@cStorerKey  
                                 ,@nErrNo  OUTPUT  
                                 ,@cErrMsg OUTPUT  
                                 ,@cSKU        = @cSKU  
                                 ,@nPutawayQTY = @nPAQty  
                                 ,@cFromLOT    = @cLot  
                                 ,@cUCCNo      = @cDropID
                                 ,@cToID       = @cToID
         
                              IF @nErrNo = 0  
                              BEGIN  
                                 BREAK  
                              END  
                              ELSE  
                              BEGIN  
                                 SET @cToLoc = ''  
                              END  
                           END 
      
                           SET @nRetryPA = @nRetryPA + 1  
                        END 
                        
                        
                        IF @cToLoc = '' OR @cToLoc = 'SEESUP'
                        BEGIN
                           --if ToLoc Blank set ToLoc = QC Location
                           SELECT @cToLoc = Short     
                           FROM dbo.CodeLkup WITH (NOLOCK)    
                           WHERE Listname = 'WCSROUTE'    
                           AND Code = 'QC'   
      
                           SET @cNoToLocFlag = '1'  
                        END
                        
         
                        SET @b_success = 1    
                        EXECUTE   nspg_getkey    
                                 'TaskDetailKey'    
                                , 10    
                                , @ctaskdetailkey OUTPUT    
                                , @b_success       OUTPUT    
                                , @nErrNo           OUTPUT    
                                , @cErrMsg        OUTPUT  
                      
                        IF NOT @b_success = 1    
                        BEGIN    
                                SET @nErrNo = 84057
                               --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'GetKeyFailed'
                               SET @cErrMsg = 'Insert DropIDDetail Fail' 
                               GOTO RollBackTran  
                        END    
                 
                        IF @b_success = 1    
                        BEGIN    
                           SELECT @cLogicalToLoc = ISNULL(RTRIM(LogicalLocation),'')  
                           FROM LOC WITH (NOLOCK)  
                           WHERE Loc = @cToLoc  
                    
                      
                           INSERT TASKDETAIL    
                           (    
                            TaskDetailKey    
                           ,TaskType    
                           ,Storerkey    
                           ,Sku    
                           ,UOM    
                           ,UOMQty    
                           ,Qty   
                           ,SystemQty  
                           ,Lot    
                           ,FromLoc 
                           ,FromID    
                           ,ToLoc    
                           ,ToID    
                           ,SourceType    
                           ,SourceKey    
                           ,Priority    
                           ,SourcePriority    
                           ,Status    
                           ,LogicalFromLoc    
                           ,LogicalToLoc    
                           ,PickMethod  
                           ,Wavekey  
                           ,Listkey    
                           ,Areakey
                           ,CaseID  
                           )    
                           VALUES    
                           (    
                            @ctaskdetailkey    
                           ,'PA'   
                           ,@cStorerkey    
                           ,@cSku    
                           ,@cUOM     -- UOM,    
                           ,@nPAQty   -- UOMQty,    
                           ,@nPAQty    
                           ,@nPAQty   --systemqty  
                           ,@cLot     
                           ,@cfromloc     
                           ,'' -- from id    
                           ,@cToLoc 
                           ,'' -- to id    
                           ,@cSourceType --Sourcetype    
                           ,@cDeviceProfileLogKey --Sourcekey    
                           ,'9' -- Priority    
                           ,'' -- Sourcepriority    
                           --,CASE WHEN @cNoToLocFlag = '1' THEN 'X' ELSE '0' END -- Status  
                           ,'0' -- SOS# 333573  
                           ,@cLogicalFromLoc   --Logical from loc    
                           ,@cLogicalToLoc     --Logical to loc    
                           ,''  
                           ,@cWavekey  
                           ,''  
                           ,''  
                           ,@cDropID
                           )  
                    
                           SET @nErrNo = @@ERROR   
                    
                           IF @nErrNo <> 0    
                           BEGIN  
                    
                                SET @nErrNo = 84058
                               --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsTaskDetFailed'
                               SET @cErrMsg = 'Insert DropIDDetail Fail' 
                               GOTO RollBackTran  
                           END
                        END    
                        
                        
             
                        FETCH NEXT FROM CUR_PA INTO 
                                                    @cSku  
                                                   ,@cPackkey  
                                                   ,@cUOM  
                                                   ,@cLot  
                                                   ,@cFromLoc  
                                                   ,@cLogicalFromLoc      
                                                   ,@cID  
                                                   ,@cWaveKey
                                                    
                     END  
                     CLOSE CUR_PA  
                     DEALLOCATE CUR_PA  
                END
                
                   -- (ChewKP02)
                   -- WCSROUTE Creation 
                   -- INSERT WCS ROUTE  --
                   
                   -- DELETE EXISTING ROUTE BEFORE INSERTING -- -- (ChewKP04)
                             
                   EXEC [dbo].[ispWCSRO01]            
                                @c_StorerKey     =  @cStorerKey
                              , @c_Facility      =  @cFacility 
                              , @c_ToteNo        =  @cDropID          
                              , @c_TaskType      =  'PTS'          
                              , @c_ActionFlag    =  'D' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual       
                              , @c_TaskDetailKey =  ''
                              , @c_Username      =  @cUserName
                              , @c_RefNo01       =  ''       
                              , @c_RefNo02       =  ''
                              , @c_RefNo03       =  ''
                              , @c_RefNo04       =  ''
                              , @c_RefNo05       =  ''
                              , @b_debug         =  '0'
                              , @c_LangCode      =  'ENG' 
                              , @n_Func          =  0
                              , @b_Success       = @b_success OUTPUT            
                              , @n_ErrNo         = @nErrNo    OUTPUT          
                              , @c_ErrMsg        = @cErrMSG   OUTPUT  
       
       
    
                
             IF @cShortPick = '1'
             BEGIN
                -- Insert WCSRoute to QC and PTS Again
                IF NOT EXISTS ( SELECT 1 FROM dbo.WCSROUTING WITH (NOLOCK) 
                                WHERE ToteNo = @cDropID 
                                AND Final_Zone = @cQCStation
                                AND Status = '0'  ) 
                BEGIN                             
                   EXEC [dbo].[ispWCSRO01]            
                           @c_StorerKey     =  @cStorerKey
                         , @c_Facility      =  @cFacility         
                         , @c_ToteNo        =  @cDropID          
                         , @c_TaskType      =  'PTS'          
                         , @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual       
                         , @c_TaskDetailKey =  ''
                         , @c_Username      =  @cUserName
                         , @c_RefNo01       =  @cQCStation       
                         , @c_RefNo02       =  ''
                         , @c_RefNo03       =  ''
                         , @c_RefNo04       =  ''
                         , @c_RefNo05       =  ''
                         , @b_debug         =  '0'
                         , @c_LangCode      =  'ENG' 
                         , @n_Func          =  0        
                         , @b_Success       = @b_success OUTPUT            
                         , @n_ErrNo         = @nErrNo    OUTPUT          
                         , @c_ErrMsg        = @cErrMSG   OUTPUT  
                   
                   EXEC [dbo].[ispWCSRO01]            
                           @c_StorerKey     =  @cStorerKey
                         , @c_Facility      =  @cFacility         
                         , @c_ToteNo        =  @cDropID          
                         , @c_TaskType      =  'PTS'          
                         , @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual       
                         , @c_TaskDetailKey =  ''
                         , @c_Username      =  @cUserName
                         , @c_RefNo01       =  @cCurrentStation       
                         , @c_RefNo02       =  ''
                         , @c_RefNo03       =  ''
                         , @c_RefNo04       =  ''
                         , @c_RefNo05       =  ''
                         , @b_debug         =  '0'
                         , @c_LangCode      =  'ENG' 
                         , @n_Func          =  0        
                         , @b_Success       = @b_success OUTPUT            
                         , @n_ErrNo         = @nErrNo    OUTPUT          
                         , @c_ErrMsg        = @cErrMSG   OUTPUT  
                         
      END
             END
             
             
             
     
             SET @nCountTask = 0 
             
             SELECT @nCountTask = Count(WCSKey)
             FROM dbo.WCSRouting WITH (NOLOCK) 
             WHERE ToteNo = @cDropID 
             AND Final_Zone <> @cQCStation
             AND Status = '0'
             AND TaskType = 'PTS' -- (ChewKP06)
             
             IF ISNULL(@nCountTask,0 )  = 0 
             BEGIN
                -- (ChewKP06)
                -- Update WCSRouting , WCSRoutingDetail
                UPDATE dbo.WCSRoutingDetail
                SET Status = '9'
                WHERE ToteNo = @cDropID
                AND Status = '0'
                --AND TaskType = 'RPF'
               
                IF @@ERROR <> 0
                BEGIN
                            
                   SET @nErrNo = 84077  
                   --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRODetFail'   
                   SET @cErrMsg = 'UpdWCSRODetFail'   
                   GOTO RollBackTran  
                END
                
                UPDATE dbo.WCSRouting
                SET Status = '9'
                WHERE ToteNo = @cDropID
                AND Status = '0'
                AND TaskType = 'RPF'
               
                IF @@ERROR <> 0
                BEGIN
                   SET @nErrNo = 84078  
                   --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSROFail'   
                   SET @cErrMsg = 'UpdWCSROFail'  
                   GOTO RollBackTran  
                END
               
                -- Get TaskDetailKey 
                SELECT @ctaskdetailkey = TaskDetailKey 
                FROM dbo.TaskDetail WITH (NOLOCK)
                WHERE CaseID = @cDropID
                         
                EXEC [dbo].[ispWCSRO01]            
                        @c_StorerKey     =  @cStorerKey
                      , @c_Facility      =  @cFacility         
                      , @c_ToteNo        =  @cDropID          
                      , @c_TaskType      =  'PA'          
                      , @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual       
                      , @c_TaskDetailKey =  @ctaskdetailkey
                      , @c_Username      =  @cUserName
                      , @c_RefNo01       =  ''            
                      , @c_RefNo02       =  ''
                      , @c_RefNo03       =  ''
                      , @c_RefNo04       =  ''
                      , @c_RefNo05       =  ''
                      , @b_debug         =  '0'
                      , @c_LangCode      =  'ENG' 
                      , @n_Func          =  0        
                      , @b_Success       = @b_success OUTPUT            
                      , @n_ErrNo         = @nErrNo    OUTPUT          
                      , @c_ErrMsg        = @cErrMSG   OUTPUT  
              END
              
                               
             
                                       
   --          IF @nErrNo <> 0            
   --          BEGIN
   --                 GOTO RollBackTran  
   --          END
             END

       END
    END
    
    
    IF @cDropIDType = 'TOTE'
    BEGIN
      SET @nQty = 0 

     
      DECLARE CursorPackDetailTote CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      
      SELECT DISTINCT PTL.DropID 
      FROM PTL.PTLTran PTL WITH (NOLOCK)
      WHERE PTL.DeviceProfileLogKey = @cDeviceProfileLogKey
      AND PTL.ConsigneeKey = @cConsigneeKey
      AND CaseID = @cToDropID
      AND PTL.Status = '1'
      AND PTL.PTLKey = @nPTLKey
      AND PTL.StorerKey = @cStorerKey
      ORDER BY PTL.DropID
      
      
      OPEN  CursorPackDetailTote
      
      FETCH NEXT FROM CursorPackDetailTote INTO @cToteNo
      
      WHILE @@FETCH_STATUS <> -1     
      BEGIN   
           
       
         DECLARE CursorPackDetailPrev CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
         
--         SELECT PTL.SKU
--         FROM dbo.DeviceProfileLog DL WITH (NOLOCK) 
--         INNER JOIN PTL.PTLTran PTL WITH (NOLOCK) ON PTL.DeviceProfileLogKey = DL.DeviceProfileLogKey AND PTL.ConsigneeKey = DL.ConsigneeKey
--         WHERE DL.UserDefine02 = @cLoadKey
--         AND DL.DropID = @cToDropID 
--         AND PTL.DropID = @cDropID
--         AND PTL.ConsigneeKey = @cConsigneeKey 
--         AND DL.ConsigneeKey  = @cConsigneeKey
--         AND PTL.StorerKey    = @cStorerKey
--         AND PTL.Status       = '1'
--         ORDER BY PTL.PTLKey
           SELECT  PD.SKU 
                  ,SUM(PD.Qty)
           FROM dbo.Pickdetail PD WITH (NOLOCK)
           INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
           JOIN dbo.OrderDetail OD (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
           WHERE PD.DropID = @cDropID
           AND PD.Status = '5'
           AND O.LoadKey = @cLoadKey
           AND OD.UserDefine02 = @cConsigneeKey -- (Chee02)
           AND ISNULL(PD.CaseID, '') = '' -- (Chee04) 
           GROUP BY PD.SKU
           HAVING SUM(PD.Qty) > 0 -- (ChewKP05)
           ORDER BY PD.SKU
         
         OPEN CursorPackDetailPrev            
         
         FETCH NEXT FROM CursorPackDetailPrev INTO @cSKU, @nQty
          
         
         WHILE @@FETCH_STATUS <> -1     
         BEGIN   


            -- Prevent OverPacked by ConsigneeKey -- 
             -- Want to Check OverPack Here How To Handle ? --
             SET @nTotalPickedQty = 0
             SET @nTotalPackedQty = 0
             
             SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)
             FROM dbo.PickDetail PD WITH (NOLOCK) 
             INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
             INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey 
             INNER JOIN dbo.LoadPlanDetail LP WITH (NOLOCK) ON LP.OrderKey = PD.OrderKey
             WHERE PD.PickslipNo  = @cPickSlipNo
             AND   LP.LoadKey     = @cLoadKey
             AND   PD.StorerKey   = @cStorerKey
             AND   PD.SKU         = @cSKU
             AND   PD.Status      = '5'
             AND   OD.UserDefine02 = @cConsigneeKey
   
             
             
--             SELECT @nTotalPackedQty = ISNULL(SUM(PCD.QTY),0)
--             FROM   dbo.PACKDETAIL PCD WITH (NOLOCK)
--             INNER JOIN PTL.PTLTran PTL WITH (NOLOCK) ON PTL.CaseID = PCD.DropID
--             INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
--             WHERE  PCD.PickSlipNo          = @cPickSlipNo
--             AND    PCD.StorerKey           = @cStorerKey 
--             AND    PCD.SKU                 = @cSKU
--             AND    PTL.DeviceProfileLogKey = @cDeviceProfileLogKey
--             AND    DL.UserDefine02         = @cConsigneeKey

             SELECT @nTotalPackedQty = ISNULL(SUM(PD.QTY),0) FROM dbo.PackDetail PD WITH (NOLOCK) 
             INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.DropID = PD.DropID
             where PD.PickSlipNo = @cPickSlipNo
             and PD.SKU = @cSKU
             and DL.DeviceProfileLogKey =  @cDeviceProfileLogKey
             and DL.ConsigneeKey = @cConsigneeKey
             
             
             IF (ISNULL(@nTotalPackedQty,0) + ISNULL(@nQty,0)) > ISNULL(@nTotalPickedQty,0)
             BEGIN
                SET @nErrNo = 84076
                --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OverPacked'
                SET @cErrMsg = 'PackDetail OverPacked'
                GOTO RollBackTran
             END 
             

             
             IF EXISTS(SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE PickSlipNo = @cPickSlipNo
                        AND DropID = @cToDropID
                        AND SKU = @cSKU )
             BEGIN
                SELECT @cLabelNo = LabelNo 
                FROM dbo.PackDetail WITH (NOLOCK)
                WHERE PickSlipNo = @cPickSlipNo
                 AND DropID = @cToDropID
                 AND SKU = @cSKU
                
                UPDATE PACKDETAIL WITH (ROWLOCK)
                  SET Qty = Qty + @nQty
                WHERE PickSlipNo = @cPickSlipNo
                 AND DropID = @cToDropID
                 AND SKU = @cSKU
                
                IF @@ERROR <> 0 
                BEGIN
                   SET @nErrNo = 84057
                   --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackDetFail'
                   SET @cErrMsg = 'Update PackDetail Failed'
                   GOTO RollBackTran
                END 
             END
             ELSE
             BEGIN


                IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)       
                                WHERE PickSlipNo = @cPickSlipNo 
                                AND DropID = @cToDropID ) 
                BEGIN
                  
                  SET @cLabelNo = @cToDropID

                  
                  SET @cExecStatements = N'EXEC dbo.' + RTRIM( @cGenLabelNoSP) +  
                                          '   @cPickslipNo           ' +                     
                                          ' , @nCartonNo             ' + 
                                          ' , @cLabelNo     OUTPUT   ' +
                                          ' , @cStorerKey            ' + 
                                          ' , @cDeviceProfileLogKey  ' +   
                                          ' , @cConsigneeKey         ' +  
                                          ' , @b_success             ' +     
                                          ' , @nErrNo       OUTPUT   ' +  
                                          ' , @cErrMSG      OUTPUT   '   
        
                     
                  SET @cExecArguments =   
                            N'@cPickslipNo  nvarchar(10),       ' +  
                             '@nCartonNo    int,                ' +      
                             '@cLabelNo     nvarchar(20) OUTPUT, ' +      
                             '@cStorerKey   nvarchar(15),        ' +  
                             '@cDeviceProfileLogKey     nvarchar(10), ' +  
                             '@cConsigneeKey     nvarchar(15), ' +  
                             '@b_success   int,                 ' +      
                             '@nErrNo      int OUTPUT,          ' +     
                             '@cErrMSG     nvarchar(225) OUTPUT '   
                          
                    
                  EXEC sp_executesql @cExecStatements, @cExecArguments,   
                                        @cPickslipNo                 
                                      , @nCartonNo
                                      , @cLabelNo      OUTPUT
                                      , @cStorerKey                                 
                                      , '' -- @cDeviceProfileLogKey -- (ChewKP05)
                                      , @cConsigneeKey                 
                                      , @b_success     
                                      , @nErrNo        OUTPUT  
                                      , @cErrMSG       OUTPUT

    
                  IF @nErrNo <> 0 
                  BEGIN
                    SET @nErrNo = 84063
                    SET @cErrMsg = 'Error Generating Carton Label'
                    GOTO RollBackTran
                     
                  END
                END
                ELSE 
                BEGIN   
                    SELECT @cLabelNo = LabelNo 
                    FROM dbo.PackDetail WITH (NOLOCK)
                    WHERE PickSlipNo = @cPickSlipNo
                    AND DropID = @cToDropID 
   
                END
       
                

                INSERT INTO dbo.PACKDETAIL
                (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, Sku, Qty, DropID, RefNo)
                VALUES
                (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku,
                 @nQty, @cToDropID,'')
                
                IF @@ERROR <> 0
                BEGIN
                   SET @nErrNo = 84058
                   --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsPackDetFail'
                   SET @cErrMsg = 'Insert PackDetail Failed'
                   GOTO RollBackTran
                END
                
                
                IF NOT EXISTS ( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK)
                                WHERE DropID = @cToDropID
                                AND ChildID = @cLabelNo ) 
                BEGIN                
                   INSERT INTO dbo.DropIDDetail (DropID, ChildID ) 
                   VALUES ( @cToDropID , @cLabelNo ) 
                  
                   IF @@ERROR <> 0
                   BEGIN
                      SET @nErrNo = 84059
                      --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsDropIDDetFail'
                      SET @cErrMsg = 'Insert DropIDDetail Failed'
                      GOTO RollBackTran
                   END
                   
                END
             END
             
             SET @nPD_Qty = 0
             SET @nSUMPD_Qty = 0

             -- Update PickDetail.CaseID = LabelNo
             DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
             
             SELECT  PD.PickDetailKey, PD.Qty
             FROM dbo.Pickdetail PD WITH (NOLOCK)
             INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
             WHERE PD.DropID = @cDropID
             AND PD.Status = '5'
             AND O.LoadKey = @cLoadKey
             AND PD.SKU    = @cSKU
             AND ISNULL(PD.CaseID,'')  = ''
             ORDER BY PD.SKU
             
             OPEN  CursorPickDetail
             
             FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPD_Qty
             
             WHILE @@FETCH_STATUS <> -1     
             BEGIN
               UPDATE PickDetail WITH (ROWLOCK)
               SET   EditWho = SUSER_SNAME(),
                     EditDate = GETDATE(),
                     CaseID = @cLabelNo, 
                     Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               AND Status = '5'
               
               IF @@ERROR <> 0 
               BEGIN
                  SET @nErrNo = 84066
                   --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsDropIDDetFail'
                   SET @cErrMsg = 'Update PickDetail Failed'
                   GOTO RollBackTran
               END

               SET @nSUMPD_Qty = @nSUMPD_Qty + @nPD_Qty
                              
               FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPD_Qty
             END
             CLOSE CursorPickDetail         
             DEALLOCATE CursorPickDetail
             
            EXEC RDT.rdt_STD_EventLog
            @cActionType   = '8', -- Packing
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = 816,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cSKU          = @cSKU,
            @nQTY          = @nSUMPD_Qty,
            @cRefNo1       = @nPTLKey,
            @cRefNo2       = @cDropID,
            @cRefNo3       = @cSourceKey,
            @cRefNo4       = @cDropIDType,
            @cRefNo5       = @cToDropID

             FETCH NEXT FROM CursorPackDetailPrev INTO @cSKU, @nQty
         END     
         CLOSE CursorPackDetailPrev         
         DEALLOCATE CursorPackDetailPrev

         FETCH NEXT FROM CursorPackDetailTote INTO @cToteNo
      END 
      CLOSE CursorPackDetailTote            
      DEALLOCATE CursorPackDetailTote   
    END
    
    CONTINUE_PROCESS:
    /***************************************************/
    /* Insert PackInfo                                 */
    /***************************************************/
    SET @nCartonNo = 0
    
    SELECT @nCartonNo = MAX(CartonNo)
    FROM dbo.PACKDETAIL WITH (NOLOCK)
    WHERE PickSlipNo = @cPickSlipNo
    AND DropID = CASE WHEN @cDropIDType = 'UCC' THEN @cCaseID ELSE @cToDropID END
    
    IF ISNULL(@nCartonNo,0) <> 0
    BEGIN
       IF NOT EXISTS(SELECT 1 FROM dbo.PACKINFO WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo
                       AND CartonNo = @nCartonNo)
       BEGIN
          INSERT INTO dbo.PACKINFO
          (PickSlipNo, CartonNo, CartonType, RefNo)
          VALUES
          (@cPickSlipNo, @nCartonNo, 'GOH', @cLabelNo) 
    
          IF @@ERROR <> 0
          BEGIN
              SET @nErrNo = 84068
              --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsDropIDDetFail'
              SET @cErrMsg = 'Insert PackInfo Failed'
              GOTO RollBackTran
          END
    
       END -- Not Exists in PackInfo
    END
      

         

--            GOTO ROLLBACKTRAN


      -- Split PTLTran when Qty > 0
      IF @cPTLSKU <> 'FULLTOTE' AND @nPTLQty > 0 
      BEGIN
            IF @nExpectedQty > @nPTLQty 
            BEGIN
                INSERT INTO PTL.PTLTran
                     (
                        -- PTLKey -- this column value is auto-generated
                        IPAddress,  DeviceID,     DevicePosition,
                        [Status],   PTLType,     DropID,
                        OrderKey,   Storerkey,    SKU,
                        LOC,        ExpectedQty,  Qty,
                        Remarks,    Lot,
                        DeviceProfileLogKey, SourceKey, ConsigneeKey,
                        CaseID
                     )
                SELECT  IPAddress,  DeviceID,     DevicePosition,
                        '0',   PTLType,     DropID,
                        OrderKey,   Storerkey,    SKU,
                        LOC,        (@nExpectedQty - @nPTLQty),  0,
                        @nPTLKey,   Lot,
                        DeviceProfileLogKey, SourceKey, ConsigneeKey,
                        CaseID
                FROM PTL.PTLTran WITH (NOLOCK)
                WHERE PTLKEy = @nPTLKey

                          
                
                SELECT @cLightMode = Short 
                FROM dbo.CodeLkup WITH (NOLOCK)
                WHERE ListName = 'LIGHTMODE'
                AND Code = 'UCC'
                AND StorerKEy = @cStorerKey
                
             
                SELECT @nNewPTLTranKey  = PTLKey
                      ,@cDeviceID       = DeviceID
                      ,@cDevicePosition = DevicePosition
                      ,@cDisplayValue   = ExpectedQty
                FROM PTL.PTLTran WITH (NOLOCK)
                WHERE Remarks = CAST(@nPTLKey AS NVARCHAR(10))


                IF @bDebug = 1 -- (Chee03)
                BEGIN                     
                   INSERT INTO TRACEINFO ( TraceName , TimeIn, Step1, Step2, Step3, Step4, Step5, Col1 ,Col2 , Col3, Col4)     
                   VALUES ( 'PTS', GETDATE(), @nExpectedQty, @nPTLQty, @cDisplayValue, @nPTLKey, @nNewPTLTranKey, '2-111', @cDropID, @cDevicePosition, @cDeviceID)    
                END

              -- RELIGHT Remaining Qty
--                EXEC [dbo].[isp_DPC_LightUpLoc] 
--                  @c_StorerKey = @cStorerKey 
--                 ,@n_PTLKey    = @nNewPTLTranKey    
--                 ,@c_DeviceID  = @cDeviceID  
--                 ,@c_DevicePos = @cDevicePosition 
--                 ,@n_LModMode  = @cLightMode  
--                 ,@n_Qty       = @cDisplayValue       
--                 ,@b_Success   = @b_Success   OUTPUT  
--                 ,@n_Err       = @nErrNo      OUTPUT
--                 ,@c_ErrMsg    = @cErrMsg     OUTPUT   

              EXEC PTL.isp_PTL_LightUpLoc  
                        @n_Func           = 816  
                       ,@n_PTLKey         = @nNewPTLTranKey  
                       ,@c_DisplayValue   = @cDisplayValue   
                       ,@b_Success        = @bSuccess    OUTPUT      
                       ,@n_Err            = @nErrNo      OUTPUT    
                       ,@c_ErrMsg         = @cErrMsg     OUTPUT  
                       ,@c_DeviceID       = @cDeviceID  
                       ,@c_DevicePos      = @cDevicePosition  
                       ,@c_DeviceIP       = @cIPAddress    
                       ,@c_LModMode       = @cLightMode  
                   
            END  
            ELSE
            BEGIN
               

               IF @cOrderType = 'AFWHSALE' -- (ChewKP08)
               BEGIN 
                  
                  SET @nTotalPickedQty = 0 
                         
                  SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)
                       , @cFromLoc = PD.Loc
                       , @cSKU     = PD.SKU 
                  FROM dbo.PickDetail PD WITH (NOLOCK) 
                  INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
                  INNER JOIN dbo.LoadPlanDetail LP WITH (NOLOCK) ON LP.OrderKey = PD.OrderKey
                  WHERE PD.PickslipNo  = @cPickSlipNo
                  AND   LP.LoadKey     = @cLoadKey
                  AND   PD.StorerKey   = @cStorerKey
                  AND   PD.Status      IN ( '0', '3' , '5' )  -- (ChewKP01) 
                  AND   PD.DropID      = @cDropID
                  GROUP BY PD.Loc, PD.SKU
                  
                  SET @nUCCQty = 0 
                  SELECT @nUCCQty = UCC.Qty 
                  FROM dbo.UCC UCC WITH (NOLOCK)
                  WHERE UCC.UCCNo = @cDropID
                  
                  IF @nUCCQty > @nTotalPickedQty 
                  BEGIN
                     SET @nPAQty = @nUCCQty - @nTotalPickedQty
                  END
                  
                  -- PRINT @nTotalPickedQty
                  -- PRINT @nUCCQty
          
      
                  IF @nPAQty > 0 
                  BEGIN 
                     
                     IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                                     WHERE StorerKey = @cStorerKey
                                     AND SourceKey = @cDropID ) 
                     BEGIN
                        
                        -- Perform Move -- 
                        SELECT @cPALoc = Short 
                        FROM dbo.CodeLKup WITH (NOLOCK) 
                        WHERE ListName = 'PTSStage'
                        AND StorerKey = @cStorerKey
                        AND Code = 'PTS'
         
                        
         
                        --PRINT @nPAQty
                        EXECUTE rdt.rdt_Move    
                        @nMobile     = 0,    
                        @cLangCode   = @cLangCode,    
                        @nErrNo      = @nErrNo  OUTPUT,    
                        @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max    
                        @cSourceType = 'isp_PTL_PTS_Confirm',    
                        @cStorerKey  = @cStorerKey,    
                        @cFacility   = @cFacility,    
                        @cFromLOC    = @cFromLOC,    
                        @cToLOC      = @cPALoc,    
                        @cFromID     = '',           -- NULL means not filter by ID. Blank is a valid ID    
                        @cToID       = '',       -- NULL means not changing ID. Blank consider a valid ID    
                        @cSKU        = @cSKU,    
                        @nQTY        = @nPAQty,   
                        @nFunc       = 816,
                        @nQTYPick    = 0,   
                        @cDropID     = ''
                        --@cFromLOT    = @cLot
                     
                        IF @nErrNo <> 0 
                        BEGIN
                           
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
                           GOTO RollBackTran
                        END
                        
                        -- Generate Temp UCC No -- 
                        SET @b_success = 1    
                        EXECUTE   nspg_getkey    
                                 'ANFTempUCC'    
                                , 8    
                                , @cTempCounter  OUTPUT    
                                , @b_success     OUTPUT    
                                , @nErrNo        OUTPUT    
                                , @cErrMsg       OUTPUT  
                        
                        IF NOT @b_success = 1    
                        BEGIN    
                               SET @nErrNo = 84080
                               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'GetKeyFailed'
                               --SET @cErrMsg = 'GetKeyFailed' 
                               GOTO RollBackTran  
                        END    
                        
                        SET @cTempUCC = @cTempCounter + RIGHT(@cDropID,8 ) 
                        
                        INSERT INTO UCC ( UCCNo, StorerKey, ExternKey, SKU, Qty, SourceKey, SourceType, 
                                          Status, Lot, Loc, ID, Userdefined01, Userdefined02, Userdefined03)
                        SELECT @cTempUCC, StorerKey, ExternKey, SKU, @nPAQty, @cDropID, 'PTS',
                               '0' , Lot, @cPALoc, '', Userdefined01, Userdefined02, Userdefined03
                        FROM dbo.UCC WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND UCCNo = @cDropID
         
                        SELECT @cLabelPrinter = Printer
                              ,@cANFUserName  = UserName 
                        FROM rdt.rdtMobrec WITH (NOLOCK)
                        WHERE Func = 816
                        AND V_String3 = @cDropID
                        
                        -- Print Label -- 
                        -- Call Bartender standard SP
                        EXECUTE dbo.isp_BT_GenBartenderCommand 
                           @cLabelPrinter,     -- printer id
                           'UCCLBLANF',    -- label type
                           @cANFUserName,    -- user id
                           @cTempUCC,     -- parm01
                           '',            -- parm02
                           '',            -- parm03
                           '',            -- parm04
                           '',            -- parm05
                           '',            -- parm06
                           '',            -- parm07
                           '',            -- parm08
                           '',            -- parm09
                           '',            -- parm10
                           @cStorerKey,   -- StorerKey
                           '1',           -- no of copy
                           0,             -- debug
                           'N',            -- return result
                           @nErrNo        OUTPUT,
                           @cErrMsg       OUTPUT 
                       
                        IF @nErrNo <> 0     
                        BEGIN
                             --SET @nErrNo = 84080
                             --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'GetKeyFailed'
                             --SET @cErrMsg = 'GetKeyFailed' 
                             GOTO RollBackTran
                        END               
                     END
                  END
               END 
                  
            END 
      
      END
      
  
      -- Update DropIDDetail.ChildID UserDefine02 = '1' Once Passed Validation -- 
      UpdateDropID:
      
      IF @bDebug = 1 -- (Chee03)
      BEGIN  
         INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
         VALUES ( 'PTS', GETDATE(), '2-12', @cDropIDType, @cDropID, @cShortPick, @nPTLKey )
      END

      IF @cDropIDType = 'UCC'
      BEGIN
         IF @bDebug = 1 -- (Chee03)
         BEGIN  
            INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
            VALUES ( 'PTS', GETDATE(), '2-13', @cDropIDType, @cDropID, @cShortPick, @nPTLKey )
         END

         SELECT @nSumTotalExpectedQty = SUM(ExpectedQty) 
               ,@nSumTotalPickedQty = SUM(Qty) 
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DropID = @cDropID
                    
         IF  ISNULL(@nSumTotalExpectedQty,0) = ISNULL(@nSumTotalPickedQty,0) 
         BEGIN
            IF @bDebug = 1 -- (Chee03)
            BEGIN  
               INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
               VALUES ( 'PTS', GETDATE(), '2-14', @cDropIDType, @cDropID, @nSumTotalExpectedQty, @nSumTotalPickedQty )
            END

            UPDATE  DD 
          	SET   UserDefine02 = '1'
          	FROM dbo.DropIDDetail DD WITH (NOLOCK)
          	INNER JOIN dbo.DropID D WITH (NOLOCK) ON D.DropID = DD.DropID
          	WHERE  DD.ChildID = @cDropID
          	AND DD.UserDefine02 = ''
            
            IF @@ERROR <> 0 
            BEGIN   
               SET @nErrNo = 84064
               --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsDropIDDetFail'
               SET @cErrMsg = 'UpdDropIDDetFail'
               GOTO RollBackTran
            END  
         END
         
               
                
      END
      ELSE IF @cDropIDType = 'TOTE'
      BEGIN
         UPDATE dbo.DropID WITH (ROWLOCK) 
         SET Status = '9'
         WHERE DropID = @cDropID
         AND LoadKey = @cLoadKey
         AND Status = '5'
         
         IF @@ERROR <> 0 
         BEGIN    
            SET @nErrNo = 84065
            --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsDropIDDetFail'
            SET @cErrMsg = 'UpdDropIDFail'
            GOTO RollBackTran
         END  
      END
       
    GOTO QUIT

    RollBackTran:
    ROLLBACK TRAN PackInsert
    
    SELECT @cModuleName = 'PTS'
    
    SET @cAlertMessage = 'DropID : ' + @cDropID + @c_NewLineChar
                         + 'PTLKey : ' + CAST(@nPTLKey AS NVARCHAR(10))  + @c_NewLineChar
                         + 'Error Code: ' + CAST(@nErrNo AS VARCHAR) + @c_NewLineChar 
                         + ' Error Message: ' + @cErrMsg 
    
    
    
    EXEC nspLogAlert
            @c_modulename       = @cModuleName
          , @c_AlertMessage     = @cAlertMessage
          , @n_Severity         = '5'
          , @b_success          = @b_success      OUTPUT
          , @n_err              = @n_ErrNo        OUTPUT
          , @c_errmsg           = @c_ErrMsg       OUTPUT
          , @c_Activity	        = 'PTS'
          , @c_Storerkey	     = @cStorerKey
          , @c_SKU	           = ''
          , @c_UOM	           = ''
          , @c_UOMQty	        = ''
          , @c_Qty	           = @nQty
          , @c_Lot	       = ''
          , @c_Loc	           = ''
          , @c_ID	              = ''
          , @c_TaskDetailKey	  = ''
          , @c_UCCNo	           = ''
    
    Quit:
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN PackInsert
END

GO