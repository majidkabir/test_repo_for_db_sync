SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PTL_OrderPicking_InsertPTLTran                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert PTLTran                                              */
/*                                                                      */
/* Called from: rdtfnc_PTL_OrderPicking                                 */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 26-02-2013 1.0  ChewKP   Created                                     */
/* 11-06-2013 1.1  ChewKP   SOS#280749 PTL Enhancement (ChewKP01)       */
/* 03-07-2014 1.2  James    SOS303322 Filter by pickzone if rdt config  */
/*                          PTLPicKZoneReq turn on (james01)            */
/* 09-10-2014 1.3  Ung      Fix regen some PkDtl not insert into PTL    */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTL_OrderPicking_InsertPTLTran] (
     @nMobile          INT
    ,@nFunc            INT
    ,@cFacility        NVARCHAR(5)
    ,@cStorerKey       NVARCHAR( 15)  
    ,@cCartID          NVARCHAR( 10)  
    ,@cUserName        NVARCHAR( 18)  
    ,@cLangCode        NVARCHAR( 3)
    ,@cPickZone        NVARCHAR( 10)   -- (james01)
    ,@nErrNo           INT         OUTPUT
    ,@cErrMsg          NVARCHAR(20) OUTPUT -- screen limitation, 20 char max
    
    
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
          , @cDropId               NVARCHAR(20)
          , @cOrderKey             NVARCHAR(10)
          , @cSKU                  NVARCHAR(20) 
          , @cLoc                  NVARCHAR(10) 
          , @nExpectedQty          INT
          , @cLot                  NVARCHAR(10)
          , @cDeviceProfileLogKey  NVARCHAR(10)
          , @cPickDetailKey        NVARCHAR(10)
          , @cPTLPKZoneReq         NVARCHAR(1) 
          
   SET @cPTLPKZoneReq = rdt.rdtGetConfig( @nFunc, 'PTLPicKZoneReq', @cStorerKey)
   IF @cPTLPKZoneReq = '0'
      SET @cPTLPKZoneReq = ''

    SET @cPTLType          = 'Pick2Cart'
    SET @cIPAddress        = ''
    SET @cDevicePosition   = ''
    SET @cDropId           = ''
    SET @cOrderKey         = ''
    SET @cStorerKey        = ''
    SET @cSKU              = ''
    SET @cLoc              = ''
    SET @nExpectedQty      = 0
    SET @cDeviceProfileLogKey = ''
    
    
    SET @nTranCount = @@TRANCOUNT
    
    BEGIN TRAN
    SAVE TRAN PTLTran_Insert

    DECLARE CursorPTLTran CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
       
    SELECT D.IPAddress, D.DevicePosition, DL.DropID, DL.OrderKey, PD.StorerKey, PD.SKU, 
           CASE WHEN ISNULL(PD.ToLoc,'')  = '' THEN PD.Loc ELSE PD.ToLoc END, 
           SUM(PD.Qty), PD.Lot, DL.DeviceProfileLogKey, MIN(PD.PickDetailKey)
    FROM dbo.DeviceProfile D WITH (NOLOCK)
    INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
    INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = DL.OrderKey
    INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey  = O.OrderKey
    INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
    WHERE D.DeviceID = @cCartID
    AND DL.Status       = '1'
    AND LOC.PickZone = CASE WHEN @cPTLPKZoneReq = '1' THEN @cPickZone ELSE LOC.PickZone END  -- (james01)
    GROUP BY D.IPAddress, D.DevicePosition, DL.DropID, DL.OrderKey, PD.StorerKey, PD.SKU, 
             CASE WHEN ISNULL(PD.ToLoc,'')  = '' THEN PD.Loc ELSE PD.ToLoc END,
             PD.Lot, DL.DeviceProfileLogKey--, PD.PickDetailKey
    ORDER BY DL.OrderKey

    
    OPEN CursorPTLTran            
   
    FETCH NEXT FROM CursorPTLTran INTO @cIPAddress, @cDevicePosition, @cDropId, @cOrderKey, @cStorerKey, @cSKU, @cLoc, @nExpectedQty, @cLot, @cDeviceProfileLogKey, @cPickDetailKey
   
    WHILE @@FETCH_STATUS <> -1     
    BEGIN
      
            IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)
                            WHERE IPAddress     = @cIPAddress 
                            AND DeviceID        = @cCartID
                            AND DevicePosition  = @cDevicePosition
                            AND OrderKey        = @cOrderKey
                            AND SKU             = @cSKU
                            AND Loc             = @cLoc
                            AND Lot             = @cLot
                            AND DeviceProfileLogKey = @cDeviceProfileLogKey ) 
            BEGIN                            
                  INSERT INTO PTLTran
                  (
                     -- PTLKey -- this column value is auto-generated
                     IPAddress,  DeviceID,     DevicePosition,
                     [Status],   PTL_Type,     DropID,
                     OrderKey,   Storerkey,    SKU,
                     LOC,        ExpectedQty,  Qty,
                     Remarks,    MessageNum,   Lot,
                     DeviceProfileLogKey, SourceKey
                  )
                  VALUES
                  (
                     @cIPAddress  ,
                     @cCartID     ,   
                     @cDevicePosition  ,   
                     '0'          ,
                     @cPTLType    ,   
                     @cDropId     ,   
                     @cOrderKey   ,
                     @cStorerKey ,   
                     @cSKU       ,  
                     @cLoc       ,
                     @nExpectedQty ,   
                     0           ,   
                     ''          ,
                     ''          ,
                     @cLot       ,
                     @cDeviceProfileLogKey,
                     @cPickDetailKey
                  )
                  
                  IF @@ERROR <> ''
                  BEGIN
                     SET @nErrNo = 79751
                     SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPTLTranFail'
                     GOTO RollBackTran
                  END
            END
            
      FETCH NEXT FROM CursorPTLTran INTO @cIPAddress, @cDevicePosition, @cDropId, @cOrderKey, @cStorerKey, @cSKU, @cLoc, @nExpectedQty, @cLot, @cDeviceProfileLogKey, @cPickDetailKey
      
    END
      
   
    GOTO QUIT
    
    
    
    

    RollBackTran:
    ROLLBACK TRAN PTLTran_Insert
    CLOSE CursorPTLTran            
    DEALLOCATE CursorPTLTran   
    
    Quit:
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN PTLTran_Insert
END

GO