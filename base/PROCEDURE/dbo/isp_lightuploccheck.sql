SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_LightUpLocCheck                                 */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Light Loc Check                                             */
/*                                                                      */
/* Called from: isp_PTL_PTS_Confirm02                                   */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 09-11-2014 1.0  ChewKP   Created.                                    */
/* 15-09-2015 1.1  ChewKP   Revamp for PTL Schema                       */
/************************************************************************/

CREATE PROC [dbo].[isp_LightUpLocCheck] (
     @nPTLKey              INT
    ,@cStorerKey           NVARCHAR( 15) 
    ,@cDeviceProfileLogKey NVARCHAR(10)
    ,@cLoc                 NVARCHAR(10)  
    ,@cType                NVARCHAR(10)
    ,@nErrNo               INT          OUTPUT
    ,@cErrMsg              NVARCHAR(20) OUTPUT -- screen limitation, 20 char max
    ,@cNextLoc             NVARCHAR(10) = ''
    ,@cLockType            NVARCHAR(10) = ''
 
    
 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success           INT
       , @nTranCount            INT
       , @bDebug                INT
       , @cIPAddress            NVARCHAR(40) 
       , @cUserName             NVARCHAR(18)
       , @cDevicePosition       NVARCHAR(10) 
       , @nPTLLockLocKey        INT
      



   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN LightLocCheck
    
   
   -- If Quantity = 0 Terminate all the Light , and Go to UpdateDropID
   SELECT TOP 1 
                @cUserName       = PTL.AddWho
               ,@cIPAddress      = PTL.IPAddress
   FROM PTL.PTLTran PTL WITH (NOLOCK)   
   WHERE PTL.PTLKey = @nPTLKey
   
   
   SELECT @cDevicePosition = DevicePosition 
   FROM dbo.DeviceProfile WITH (NOLOCK)
   WHERE DeviceID = @cLoc
   AND Priority = '1' 
   

   IF @cType = 'HOLD'
   BEGIN
      
      SELECT @nPTLLockLocKey = PTLLockLocKey
      FROM dbo.PTLLockLoc WITH (NOLOCK)
      WHERE IPAddress = @cIPAddress
      AND DeviceID = @cLoc
      AND AddWho = @cUserName


      UPDATE dbo.PTLLockLoc WITH (ROWLOCK)
      SET NextLoc = @cNextLoc 
         ,LockType = 'HOLD'
      WHERE PTLLockLocKey = @nPTLLockLocKey
      
      IF @@ERROR <> 0 
      BEGIN
         --SET @nErrNo = @@ERROR
         GOTO RollBackTran
      END
      
   END
   
   IF @cType  = 'LOCK' -- Insert Into Table 
   BEGIN
        
         
--      IF NOT EXISTS ( SELECT 1 FROM dbo.PTLLockLoc WITH (NOLOCK)
--                      WHERE DeviceId = @cLoc
--                      AND AddWho = @cUserName ) 
--      BEGIN 
         INSERT INTO dbo.PTLLockLoc (IPAddress, DeviceID, DevicePosition, AddWho, AddDate, NextLoc, LockType ) 
         VALUES (@cIPAddress, @cLoc, @cDevicePosition, @cUserName, GetDate(), '', '') 
         
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0 
         BEGIN
            --SET @nErrNo = @@ERROR
            GOTO RollBackTran
         END
      
--      END
--      ELSE 
--      BEGIN
--         SET @nErrNo = 1
--      END
      
   END
   
   IF @cType = 'UNLOCK'
   BEGIN
      
      IF EXISTS ( SELECT 1 FROM dbo.PTLLockLoc WITH (NOLOCK) 
                  WHERE DeviceId = @cLoc )
                  --AND AddWho = @cUserName ) 
      BEGIN
           
           SELECT @cDeviceProfileLogKey = DeviceProfileLogKey
           FROM PTL.Lightstatus WITH (NOLOCK)
           WHERE DeviceID = @cLoc  
           AND DevicePosition = @cDevicePosition
           
           IF ISNULL(@cDeviceProfileLogKey, '' ) <> '' 
           BEGIN
            
            SELECT TOP 1 @cUserName = AddWho 
            FROM PTL.PTLTran WITH (NOLOCK) 
            WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
            
           END

--         DELETE FROM dbo.PTLLockLoc WITH (ROWLOCK) 
--         WHERE DeviceId <= @cLoc -- (ChewKP01) 
--         --AND AddWho = @cUserName 
--         
--         SET @nErrNo = @@ERROR
--         IF @nErrNo <> 0 
--         BEGIN
--            SET @nErrNo = @@ERROR
--            GOTO RollBackTran
--         END
         
         INSERT INTO TraceInfo (TraceName , TimeIn , Col1, Col2, Col3, Col4, col5 ) 
         VALUES ( 'isp_LightUpLocCheck' , GetDate() , 'UNLOCK' , @cLoc, @cDevicePosition , @cDeviceProfileLogKey, @cUserName ) 
         
         
         IF ISNULL(@cUserName , '') = '' 
         BEGIN
            
            DELETE FROM dbo.PTLLockLoc WITH (ROWLOCK) 
            WHERE DeviceId = @cLoc -- (ChewKP01) 
         END
         ELSE
         BEGIN            
            
            DELETE FROM dbo.PTLLockLoc WITH (ROWLOCK) 
            WHERE DeviceId = @cLoc -- (ChewKP01) 
            AND AddWho = @cUserName 
        END
                  
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0 
         BEGIN
            SET @nErrNo = @@ERROR
            GOTO RollBackTran
         END
         
         
 
      END
                 
   END 
   
    
   GOTO QUIT

   RollBackTran:
   ROLLBACK TRAN LightLocCheck
    
   Quit:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN LightLocCheck
END

GO