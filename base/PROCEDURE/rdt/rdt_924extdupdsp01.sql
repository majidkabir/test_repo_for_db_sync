SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_924ExtdUpdSP01                                  */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Scan To Truck POD Customize Update SP                       */  
/*                                                                      */  
/* Called from: 3                                                       */  
/*    1. From PowerBuilder                                              */  
/*    2. From scheduler                                                 */  
/*    3. From others stored procedures or triggers                      */  
/*    4. From interface program. DX, DTS                                */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author   Purposes                                   */  
/* 13-09-2013  1.0  ChewKP   SOS#2859003 Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_924ExtdUpdSP01] (  
     @nMobile      INT,           
     @nFunc        INT,           
     @cLangCode    NVARCHAR( 3),  
     @nStep        INT,           
     @cStorerKey   NVARCHAR( 15), 
     @cType        NVARCHAR( 1),  
     @cMBOLKey     NVARCHAR( 10), 
     @cLoadKey     NVARCHAR( 10), 
     @cOrderKey    NVARCHAR( 10), 
     @cDoor        NVARCHAR( 10), 
     @cTruckNo     NVARCHAR( 18), 
     @cTransporter NVARCHAR( 20), 
     @nErrNo       INT OUTPUT,    
     @cErrMsg      NVARCHAR( 20) OUTPUT
)                              
AS                             
BEGIN                          
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount            INT
   
   SET @nErrNo     = 0 
   SET @cERRMSG    = ''
   
   SET @nTranCount = @@TRANCOUNT
   
   BEGIN TRAN
   SAVE TRAN ScanToTruckUpdate
   

   UPDATE rdt.rdtScanToTruck 
   SET Status = '9'
      ,Editdate = GetDate()
   WHERE MbolKey = CASE WHEN @cMBolKey <> '' THEN @cMBOLKey ELSE MBOLKey END
     AND LoadKey = CASE WHEN @cLoadKey <> '' THEN @cLoadKey ELSE LoadKey END
     AND OrderKey = CASE WHEN @cOrderKey <> '' THEN @cOrderKey ELSE OrderKey END
   
   IF @@ERROR <> 0 
   BEGIN
      SET @nErrNo = 82751
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdScanToTruckFail
      GOTO ROLLBACKTRAN
   END
   
   UPDATE dbo.POD
   SET Notes2          = @cDoor
      ,Notes           = @cTruckNo
      ,PODDef06        = @cTransporter
      ,InvDespatchDate = GetDate()
      ,Status          = '01'
   WHERE MbolKey = CASE WHEN @cMBolKey <> '' THEN @cMBOLKey ELSE MBOLKey END
     AND LoadKey = CASE WHEN @cLoadKey <> '' THEN @cLoadKey ELSE LoadKey END
     AND OrderKey = CASE WHEN @cOrderKey <> '' THEN @cOrderKey ELSE OrderKey END
   
   IF @@ERROR <> 0 
   BEGIN
      SET @nErrNo = 82752
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPODFail
      GOTO ROLLBACKTRAN
   END
   
   
   GOTO QUIT
   
   
   RollBackTran:
   ROLLBACK TRAN ScanToTruckUpdate
   
    
   Quit:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
         COMMIT TRAN ScanToTruckUpdate
   
  
END

GO