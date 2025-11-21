SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1650ExtUpd02                                    */
/* Purpose: Insert pallet id into RDT.RDTScanToTruck                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-06-01 1.0  James      WMS-22733. Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1650ExtUpd02] (
   @nMobile          INT, 
   @nFunc            INT, 
   @nStep            INT, 
   @cLangCode        NVARCHAR( 3),  
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cPalletID        NVARCHAR( 20), 
   @cMbolKey         NVARCHAR( 10), 
   @cDoor            NVARCHAR( 20), 
   @cOption          NVARCHAR( 1),  
   @nAfterStep       INT, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT  
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT, 
           @cLoadkey          NVARCHAR( 10),
           @cOrderkey         NVARCHAR( 10), 
           @cMBOL4PltID       NVARCHAR( 10), 
           @nRowRef           INT
           
   DECLARE @curUpd            CURSOR

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_1650ExtUpd02  
   

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 2 
      BEGIN
         IF ISNULL( @cPalletID, '') = ''
         BEGIN
            SET @nErrNo = 201951   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PALLET ID REQ
            GOTO RollBackTran
         END

         SELECT TOP 1 @cOrderKey = OrderKey 
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ID = @cPalletID
         AND  [Status] < '9'
         ORDER BY 1
         
         -- Get the mbolkey for this particular pallet id
         SELECT @cMBOL4PltID = MbolKey, @cLoadKey = LoadKey  
         FROM dbo.MBOLDetail WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey

         -- Add record into RDTScanToTruck (james01)
         IF NOT EXISTS ( SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK) 
                         WHERE MBOLKey = @cMBOL4PltID
                         AND   RefNo = @cPalletID
                         AND  [Status] = '9')
         BEGIN
            INSERT INTO RDT.RDTScanToTruck
                   (MBOLKey, LoadKey, CartonType, RefNo, URNNo, Status, AddWho, AddDate, EditWho, EditDate, Door)
            VALUES (@cMBOLKey, @cLoadKey, 'SCNPT2DOOR', @cPalletID, '', '1', sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), @cDoor) 

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 201952
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsScn2TrkFail
               GOTO RollBackTran
            END
         END

         GOTO Quit
      END
      
      IF @nStep = 3
      BEGIN
         IF NOT EXISTS ( SELECT 1 
                         FROM dbo.PickDetail PD WITH (NOLOCK) 
                         JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON ( PD.OrderKey = MD.OrderKey)
                         WHERE PD.StorerKey = @cStorerKey
                         AND   ISNULL( PD.ID, '') <> ''
                         AND   MD.MBOLKey = @cMbolKey
                         AND   NOT EXISTS ( SELECT 1 FROM rdt.rdtScanToTruck ST WITH (NOLOCK) 
                                            WHERE MD.MBOLKey = ST.MBOLKey 
                                            AND   PD.ID = ST.RefNo
                                            AND   ST.CartonType = 'SCNPT2DOOR')) AND @cOption = '1'
         BEGIN
         	SET @curUpd = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         	SELECT RowRef
         	FROM rdt.rdtScanToTruck WITH (NOLOCK)
         	WHERE MBOLKey = @cMbolKey
         	AND   CartonType = 'SCNPT2DOOR'
         	AND   [Status] = '1'
         	OPEN @curUpd
         	FETCH NEXT FROM @curUpd INTO @nRowRef
         	WHILE @@FETCH_STATUS = 0
         	BEGIN
         		UPDATE rdt.rdtScanToTruck SET 
         		   [Status] = '9', 
         		   EditWho = SUSER_SNAME(), 
         		   EditDate = GETDATE()
         		WHERE RowRef = @nRowRef
         		
         		IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 201953
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CloseScn2TrkEr
                  GOTO RollBackTran
               END
            
         		FETCH NEXT FROM @curUpd INTO @nRowRef
         	END
         END
         
      END
   END
   
   COMMIT TRAN rdt_1650ExtUpd02

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1650ExtUpd02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN


GO