SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_805TerminateSP02                                      */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Close working batch                                               */
/*                                                                            */
/* Date       Rev Author      Purposes                                        */
/* 25-05-2018 1.0 ChewKP      WMS-3962 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_805TerminateSP02] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cStation     NVARCHAR( 10)
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
  
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT
          ,@cLightAddress  NVARCHAR(MAX) 
          ,@cDevicePosition NVARCHAR(10) 
          ,@nCounter       INT
   
   SET @cLightAddress = ''
   SET @nCounter = 0 
   
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_805TerminateSP02 -- For rollback or commit only our own transaction
   
   
   DECLARE CursorPTLTranTerminate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT  DP.DevicePosition 
   FROM dbo.DeviceProfile DP WITH (NOLOCK) 
   INNER JOIN PTL.Lightstatus L WITH (NOLOCK) ON L.DevicePosition = DP.DevicePosition 
   WHERE DP.DeviceID = @cStation 
   AND DisplayValue <> 'EnD'
   AND DP.LogicalName = 'PTL'
   AND DP.StorerKey = @cStorerKey
   
   OPEN CursorPTLTranTerminate
   FETCH NEXT FROM CursorPTLTranTerminate INTO @cDevicePosition

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      
      IF @nCounter = 0 
      BEGIN
         SET @cLightAddress = @cDevicePosition
      END
      ELSE
      BEGIN
         SET @cLightAddress = @cLightAddress + ',' + @cDevicePosition
      END

      SET @nCounter = @nCounter + 1 

      FETCH NEXT FROM CursorPTLTranTerminate INTO @cDevicePosition
   END
   CLOSE CursorPTLTranTerminate
   DEALLOCATE CursorPTLTranTerminate
   
   --PRINT @cLightAddress
   
   EXEC PTL.isp_PTL_TerminateModuleSingle
         @cStorerKey
        ,@nFunc
        ,@cStation
        ,@cLightAddress
        ,@bSuccess    OUTPUT
        ,@nErrNo       OUTPUT
        ,@cErrMsg      OUTPUT

   

   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_805TerminateSP02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_PTLStation_Confirm
END


GO