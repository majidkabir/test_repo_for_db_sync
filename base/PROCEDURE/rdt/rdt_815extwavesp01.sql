SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_815ExtWaveSP01                                  */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Unity Insert WAve to Rdt.rdtAssignLoc                       */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2014-08-29  1.0  ChewKP   Created                                    */  
/* 2014-12-10  1.1  ChewKP   Delete PTLlockloc when Assignment (ChewKP01)*/
/* 2015-03-09  1.2  ChewKP   Update DeviceProfile when start Wave       */
/*                           (ChewKP02)                                 */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_815ExtWaveSP01] (  
   @nMobile     INT,  
   @nFunc       INT,  
   @cLangCode   NVARCHAR( 3),  
   @cUserName   NVARCHAR( 15),  
   @cFacility   NVARCHAR( 5),  
   @cStorerKey  NVARCHAR( 15),  
   @nStep       INT,
   @cWaveKey    NVARCHAR( 10),  
   @cPTSZone    NVARCHAR( 10), 
   @nErrNo      INT          OUTPUT,  
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE  @nCountTask INT
           ,@nTranCount INT
           ,@cIPAddress NVARCHAR(40)
           ,@cDeviceProfileKey NVARCHAR(10)
           
   SET @nErrNo   = 0  
   SET @cErrMsg  = '' 
   SET @cIPAddress = ''

   
   
   SET @nTranCount = @@TRANCOUNT
    
   BEGIN TRAN
   SAVE TRAN RDTAssignLoc
   
   
   IF @nFunc = 815
   BEGIN   
      
            INSERT INTO Rdt.rdtAssignLoc ( WaveKey, PTSZone, PTSLoc, PTSPosition, Status )   
            SELECT  DISTINCT @cWaveKey, Loc.PutawayZone, STL.Loc, D.DevicePosition, '0' 
            FROM dbo.WaveDetail WD WITH (NOLOCK)   
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = WD.OrderKey  
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey  
            INNER JOIN dbo.StoreToLocDetail STL WITH (NOLOCK) ON STL.ConsigneeKey = O.ConsigneeKey
            INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.Loc = STL.Loc  
            INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceID = Loc.Loc  
            WHERE WD.WaveKey = @cWaveKey  
            AND Loc.PutawayZone = @cPTSZone  
            AND D.DeviceType = 'LOC'  
            AND D.Priority = '1'
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 1
            END
            
            -- (ChewKP01) 
            SELECT Top 1 @cIPAddress = D.IPAddress
            FROM dbo.WaveDetail WD WITH (NOLOCK)   
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = WD.OrderKey  
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey  
            INNER JOIN dbo.StoreToLocDetail STL WITH (NOLOCK) ON STL.ConsigneeKey = O.ConsigneeKey
            INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.Loc = STL.Loc  
            INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceID = Loc.Loc  
            WHERE WD.WaveKey = @cWaveKey  
            AND Loc.PutawayZone = @cPTSZone  
            AND D.DeviceType = 'LOC'  
            AND D.Priority = '1'
            
            DELETE FROM dbo.PTLlockloc
            WHERE IPAddress = @cIPAddress
            
            -- Update DeviceProfile when start of Assignment -- (ChewKP02) 
            DECLARE CursorPTLStatus CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
            
            SELECT DISTINCT DP.DeviceProfileKey   
            FROM dbo.DeviceProfile DP WITH (NOLOCK)  
            INNER JOIN Rdt.rdtAssignLoc RA WITH (NOLOCK) ON RA.PTSLoc = DP.DeviceID 
            WHERE RA.WaveKey = @cWaveKey  
            AND DP.DeviceType = 'LOC'     
            AND DP.Priority   = '1'
            
            OPEN CursorPTLStatus                  
            FETCH NEXT FROM CursorPTLStatus INTO @cDeviceProfileKey  
              
            WHILE @@FETCH_STATUS <> -1              
            BEGIN      
               UPDATE dbo.DeviceProfile WITH (ROWLOCK)  
                  SET   Status = '0'   
                      , DeviceProfileLogKey = ''  
               WHERE DeviceProfileKey = @cDeviceProfileKey  
               
               FETCH NEXT FROM CursorPTLStatus INTO @cDeviceProfileKey                
            END
            CLOSE CursorPTLStatus              
            DEALLOCATE CursorPTLStatus    

            
            
   END

   GOTO QUIT
    

   RollBackTran:
   ROLLBACK TRAN RDTAssignLoc
    
   Quit:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN RDTAssignLoc
   
  
Fail:  
END  

GO