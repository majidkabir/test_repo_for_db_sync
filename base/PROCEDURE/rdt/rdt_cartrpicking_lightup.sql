SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_CartrPicking_LightUp                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert PTLTran                                              */
/*                                                                      */
/* Called from: rdtfnc_TM_CartPicking                                   */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 05-02-2014 1.0  James    SOS296464 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_CartrPicking_LightUp] (
     @nMobile          INT
    ,@nFunc            INT
    ,@cFacility        NVARCHAR(5)
    ,@cStorerKey       NVARCHAR( 15)  
    ,@cCartID          NVARCHAR( 10)  
    ,@cLoc             NVARCHAR( 10)
    ,@cSKU             NVARCHAR( 20)
    ,@cWaveKey         NVARCHAR(10) 
    ,@cLangCode        NVARCHAR( 3)
    ,@nErrNo           INT          OUTPUT
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
       , @cOrderKey             NVARCHAR(10)
       , @nExpectedQty          INT
       , @cIPAddress            NVARCHAR(40)      
       , @cLightMode            NVARCHAR(4)
       , @nPTLTranKey           INT
       , @cDevicePosition       NVARCHAR(10)
       , @nCounter              INT
       , @nDebug                INT
       , @nDevicePosition       INT
       , @cQty                  NVARCHAR(5)
          

   SET @nPTLTranKey       = 0 
   SET @cOrderKey         = ''
   SET @nExpectedQty      = 0
   SET @cIPAddress        = ''
   SET @cDevicePosition   = ''
   SET @nCounter          = 1
    
   SET @cLightMode = ''
   --SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)

   SELECT @cLightMode = Short 
   FROM dbo.CodeLKUp WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   ListName = 'LIGHTMODE'
   AND   Code = 'TOTE'

   SET @nDebug = 0
    
   IF @nDebug = 1
   BEGIN
      SELECT @cStorerKey '@cStorerKey'
             ,@cCartID '@cCartID'
             ,@cSKU '@cSKU'           
             ,@cLoc '@cLoc'          
   END
    
--   INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3, COL4) VALUES 
--   ('LIGHT', GETDATE(), @cCartID, @cSKU, @cLoc, @cWaveKey)
   DECLARE CursorPTLTranLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
   SELECT PTL.PTLKey, PTL.IPAddress, PTL.DevicePosition, PTL.ExpectedQty
   FROM dbo.PTLTran PTL WITH (NOLOCK)
   INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.StorerKey = PTl.StorerKey AND PD.SKU = PTL.SKU AND PD.LOC = PTL.LOC)
   INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
   INNER JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey) 
   WHERE PTL.DeviceID = @cCartID
   AND   PTL.Status     = '0'
   AND   PTL.SKU        = @cSKU
   AND   PD.SKU         = @cSKU
   AND   PD.Loc         = @cLoc
   AND   O.UserDefine09 = @cWaveKey 
   GROUP BY PTL.PTLKey, PTL.IPAddress, PTL.DevicePosition, PTL.ExpectedQty
   ORDER BY DevicePosition
   OPEN CursorPTLTranLightUp            
   FETCH NEXT FROM CursorPTLTranLightUp INTO @nPTLTranKey, @cIPAddress, @cDevicePosition, @nExpectedQty
   WHILE @@FETCH_STATUS <> -1     
   BEGIN
      IF @nDebug = 1
      BEGIN
         SELECT @nPTLTranKey '@nPTLTranKey'
         ,@cIPAddress '@cIPAddress'
         ,@cDevicePosition '@cDevicePosition'           
         ,CAST(@nExpectedQty AS NVARCHAR(5)) '@nExpectedQty'          
      END
         
      EXEC [dbo].[isp_DPC_LightUpLoc] 
         @c_StorerKey = @cStorerKey 
        ,@n_PTLKey    = @nPTLTranKey    
        ,@c_DeviceID  = @cCartID  
        ,@c_DevicePos = @cDevicePosition 
        ,@n_LModMode  = @cLightMode  
        ,@n_Qty       = @nExpectedQty       
        ,@b_Success   = @b_Success   OUTPUT  
        ,@n_Err       = @nErrNo      OUTPUT
        ,@c_ErrMsg    = @cErrMsg     OUTPUT
         
      IF @nErrNo <> 0
         GOTO Quit  

     FETCH NEXT FROM CursorPTLTranLightUp INTO @nPTLTranKey, @cIPAddress, @cDevicePosition, @nExpectedQty
   END
   CLOSE CursorPTLTranLightUp            
   DEALLOCATE CursorPTLTranLightUp  
    
   Quit:
END

GO