SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PTL_PTS_LightUp                                 */
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
/* 10-12-2013 1.0  ChewKP   Created                                     */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTL_PTS_LightUp] (
     @nMobile          INT
    ,@nFunc            INT
    ,@cFacility        NVARCHAR(5)
    ,@cStorerKey       NVARCHAR( 15) 
    ,@cPTSZone         NVARCHAR( 10) 
    ,@cDropID          NVARCHAR( 20)  
    ,@cDropIDType      NVARCHAR( 10)
    ,@cDeviceProfileLogKey NVARCHAR(10)
    ,@cUserName        NVARCHAR( 18)  
    ,@cLangCode        NVARCHAR( 3)
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
          , @nExpectedQty          INT
          , @cIPAddress            NVARCHAR(40)      
          , @cLightMode            NVARCHAR(4)
          , @nPTLTranKey           INT
          , @cDevicePosition       NVARCHAR(10)
          , @nDebug                INT
          , @nDevicePosition       INT
          , @cQty                  NVARCHAR(5)
          , @cDeviceID             NVARCHAR(20)
          , @cDisplayValue         NVARCHAR(5)

    SET @nPTLTranKey       = 0 
    SET @nExpectedQty      = 0
    SET @cIPAddress        = ''
    --SET @cLightMode        = 13 --CAST(@nFunc AS NVARCHAR(4)) -- LightMode According to RDT Function ID
    SET @cDevicePosition   = ''
    SET @cDeviceID         = ''
    SET @cDisplayValue     = ''
    SET @nErrNo            = 0

      
    SET @cLightMode = ''
    
    IF @cDropIDType = 'UCC'
    BEGIN
        SELECT @cLightMode = Short 
        FROM dbo.CodeLkup WITH (NOLOCK)
        WHERE ListName = 'LIGHTMODE'
        AND Code = 'UCC'
        AND StorerKEy = @cStorerKey
    END
    ELSE If @cDropIDType = 'TOTE'
    BEGIN
        SELECT @cLightMode = Short 
        FROM dbo.CodeLkup WITH (NOLOCK)
        WHERE ListName = 'LIGHTMODE'
        AND Code = 'TOTE'
        AND StorerKEy = @cStorerKey
    END
    
     
    SET @nDebug            = 0
    
    IF @nDebug = 1
    BEGIN
         SELECT  @cStorerKey '@cStorerKey'
                ,@cPTSZone '@cPTSZone'
                ,@cDropID '@cDropID'         
           
    END
    
    
--    SET @nTranCount = @@TRANCOUNT
--    
--    BEGIN TRAN
--    SAVE TRAN PTLTran_LightUp
    
    
    
    DECLARE CursorPTLTranLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
       
    SELECT PTL.PTLKey, PTL.IPAddress, PTL.DevicePosition, PTL.ExpectedQty, PTL.DeviceID
    FROM dbo.PTLTran PTL WITH (NOLOCK)
    WHERE PTL.DeviceProfileLogKey = @cDeviceProfileLogKey
    AND PTL.DropID = @cDropID
    AND PTL.Status = '0'
    ORDER BY PTL.PTLKey
    
    OPEN CursorPTLTranLightUp            
   
    FETCH NEXT FROM CursorPTLTranLightUp INTO @nPTLTranKey, @cIPAddress, @cDevicePosition, @nExpectedQty, @cDeviceID
   
    WHILE @@FETCH_STATUS <> -1     
    BEGIN
         IF @nDebug = 1
         BEGIN
               SELECT @nPTLTranKey '@nPTLTranKey'
                      ,@cIPAddress '@cIPAddress'
                      ,@cDevicePosition '@cDevicePosition'           
                      ,CAST(@nExpectedQty AS NVARCHAR(5)) '@nExpectedQty'          
         END
         
         SET @cDisplayValue = ''
         IF @cDropIDType = 'TOTE'
         BEGIN
            SET @cDisplayValue = 'FTOTE'
         END
         ELSE IF @cDropIDType = 'UCC'
         BEGIN
            SET @cDisplayValue = @nExpectedQty
         END
         

         EXEC [dbo].[isp_DPC_LightUpLoc] 
               @c_StorerKey = @cStorerKey 
              ,@n_PTLKey    = @nPTLTranKey    
              ,@c_DeviceID  = @cDeviceID  
              ,@c_DevicePos = @cDevicePosition 
              ,@n_LModMode  = @cLightMode  
              ,@n_Qty       = @cDisplayValue       
              ,@b_Success   = @b_Success   OUTPUT  
              ,@n_Err       = @nErrNo      OUTPUT
              ,@c_ErrMsg    = @cErrMsg     OUTPUT
        
         
        IF @nErrNo <> 0
        BEGIN
          --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') 
          
          GOTO Quit  
        END
            
        FETCH NEXT FROM CursorPTLTranLightUp INTO @nPTLTranKey, @cIPAddress, @cDevicePosition, @nExpectedQty, @cDeviceID
      
    END
    CLOSE CursorPTLTranLightUp            
    DEALLOCATE CursorPTLTranLightUp  
    
    
    Quit:
    
    
    

--    RollBackTran:
--    ROLLBACK TRAN PTLTran_LightUp
--    CLOSE CursorPTLTranLightUp            
--    DEALLOCATE CursorPTLTranLightUp   
--    
--    Quit:
--    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
--          COMMIT TRAN PTLTran_LightUp
END

GO