SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1642ExtUpd02_VLT                                */  
/* Purpose To activiate Scanned Flag in Fn1642 with ScanToDoor Rpt      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 24-05-2024 1.0  WSE016     Created to change Fn1642 Scanned Flag     */ 
/* 04-06-2024 1.1  PPA374     Update to check pack details and to show  */
/*                            message that everything is loaded.        */
/* 05/02/2025 1.2  PPA374     Updating serial number status to 6        */
/*                            to allow mbol shipment                    */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_1642ExtUpd02_VLT] (  
@nMobile          INT,   
@nFunc            INT,   
@nStep            INT,   
@nInputKey        INT,   
@cLangCode        NVARCHAR( 3),    
@cDropID          NVARCHAR( 20),   
@cMbolKey         NVARCHAR( 10),   
@cDoor            NVARCHAR( 20),   
@cOption          NVARCHAR( 1),    
@cRSNCode         NVARCHAR( 10),   
@nAfterStep       INT,   
@nErrNo           INT           OUTPUT,   
@cErrMsg          NVARCHAR( 20) OUTPUT    
)  
AS

BEGIN    
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE  
   @nStartTCnt        INT,   
   @cLoadkey          NVARCHAR( 10),  
   @cExternOrderKey   NVARCHAR( 20),   
   @cConsigneeKey     NVARCHAR( 15),    
   @cLP_LaneNumber    NVARCHAR( 5),   
   @cOrderkey         NVARCHAR( 10),   
   @cFacility         NVARCHAR( 5),   
   @cStorerKey        NVARCHAR( 15),   
   @cSku              NVARCHAR( 20),   
   @cLot              NVARCHAR( 10),   
   @cFromLoc          NVARCHAR( 10),   
   @cMoveRefKey       NVARCHAR( 10),   
   @cID               NVARCHAR( 18),   
   @cMBOL4DropID      NVARCHAR( 10),   
   @nQty              INT,   
   @bSuccess          INT,
   @PickSLipNo        NVARCHAR(20)
  
   SELECT @cFacility = Facility, @cStorerKey = StorerKey FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile  
  
   SET @nStartTCnt = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_1642ExtUpd02_VLT    
  
   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 2   
      BEGIN  
         IF ISNULL( @cDropID, '') = ''  
         BEGIN  
            SET @nErrNo = 53801     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DROPID REQ  
            GOTO RollbackTran
         END  
 
         SELECT TOP 1 @PickSLipNo = PickSlipNo FROM dbo.PackDetail WITH(NOLOCK)
         WHERE DropID = @cDropID
            AND StorerKey = @cStorerKey

         SELECT TOP 1 @cOrderKey = OrderKey FROM dbo.PICKHEADER WITH(NOLOCK) WHERE PickHeaderKey = @PickSLipNo

         -- Get the mbolkey for this particular dropid  
         SELECT @cMBOL4DropID = MbolKey, @cLoadKey = LoadKey    
         FROM dbo.MBOLDetail WITH (NOLOCK)   
         WHERE OrderKey = @cOrderKey  
    
         -- Add record into RDTScanToTruck (borrowed from james01 - rdt_1642ExtUpd01 )  
         IF NOT EXISTS (SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK)
         WHERE MBOLKey = @cMBOL4DropID  
            AND RefNo = @cDropID
            AND [Status] = '9')
            AND NOT EXISTS
            (SELECT 1 FROM dbo.Dropid WITH (NOLOCK)
               WHERE Dropid = @cDropID
                  AND DropIDType = 'B')
         BEGIN
            INSERT INTO RDT.RDTScanToTruck  
            (MBOLKey, LoadKey, CartonType, RefNo, URNNo, Status, AddWho, AddDate, EditWho, EditDate)  
            VALUES (@cMBOLKey, @cLoadKey, '', @cDropID, '', '9', sUser_sName(), GETDATE(), sUser_sName(), GETDATE())   
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 53806  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins Scn2Truck Fail
               GOTO RollbackTran 
            END  
         END  -- not exists
         ELSE
            INSERT INTO RDT.RDTScanToTruck
            (MBOLKey, LoadKey, CartonType, RefNo, URNNo, Status, AddWho, AddDate, EditWho, EditDate)
            SELECT O.MBOLKey, D.Loadkey, '', Dropid, '', '9', sUser_sName(), GETDATE(), sUser_sName(), GETDATE()
            FROM dbo.ORDERS O WITH(NOLOCK)
               INNER JOIN dbo.PICKHEADER PH WITH(NOLOCK)
               ON O.OrderKey = PH.OrderKey
               INNER JOIN dbo.Dropid D WITH(NOLOCK)
               ON D.PickSlipNo = PH.PickHeaderKey
               WHERE EXISTS
               (SELECT ChildId FROM dbo.DropidDetail DD WITH(NOLOCK)
                  WHERE Dropid = @cDropID AND D.Dropid = DD.ChildId)
                  AND NOT EXISTS (SELECT 1 FROM RDT.RDTScanToTruck RSTT WITH(NOLOCK) WHERE RSTT.RefNo = D.Dropid AND RSTT.Status = '9' AND RSTT.MBOLKey = O.MBOLKey)
      
         --Process updating for non-child DropIDs
         IF @nStep = 2 AND
            NOT EXISTS 
            (SELECT 1 FROM dbo.Dropid D WITH(NOLOCK) WHERE EXISTS (SELECT 1 FROM dbo.PackDetail PD WITH(NOLOCK) WHERE D.dropid = PD.Dropid
               AND PickSlipNo = @PickSLipNo) AND Status < '9')
               AND (SELECT TOP 1 DropIDType FROM dbo.Dropid WITH(NOLOCK) WHERE Dropid = @cDropID) <> 'B'
         BEGIN
            --Updating order status to loaded
            UPDATE dbo.ORDERS WITH(ROWLOCK)
            SET STATUS = '8'
            WHERE OrderKey = @cOrderkey
            AND StorerKey = @cStorerKey
               SET @nErrNo = 217969
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Order is Loaded' 
               SET @nErrNo = 0 --Setting to 0, as only message is required, there is no actual error
            
            --Updating non-processed serial numbers, as not all of them need to be packed, but if loaded, that means, those ar ok to go (no parent pallet).
            UPDATE SerialNo WITH(ROWLOCK)
            SET Status = '6'
            WHERE Status < '6' AND OrderKey =
            (SELECT TOP 1 S.OrderKey
            FROM dbo.SerialNo S WITH(NOLOCK)
            JOIN dbo.ORDERS O WITH(NOLOCK) ON S.OrderKey = O.OrderKey AND S.StorerKey = O.StorerKey
            JOIN dbo.PICKDETAIL PD WITH(NOLOCK) ON O.OrderKey = PD.OrderKey AND O.StorerKey = PD.StorerKey
            JOIN dbo.PackDetail P WITH(NOLOCK) ON PD.PickSlipNo = P.PickSlipNo AND PD.StorerKey = P.StorerKey
            WHERE S.StorerKey = @cStorerKey
            AND P.DropID = @cDropID);

            GOTO Quit
         END

         --Process updating for child DropIDs      
         ELSE IF @nStep = 2 AND EXISTS (SELECT 1 FROM dbo.Dropid WITH(NOLOCK) WHERE dropid = @cDropID and DropIDType = 'B')
         BEGIN
            --Update child DropID based on parent DropID
            UPDATE D WITH(ROWLOCK)
            SET D.STATUS = '9', D.Droploc = @cDoor, D.AdditionalLoc = @cDoor
            FROM dbo.Dropid D
            JOIN dbo.PackDetail PD WITH(NOLOCK) ON D.Dropid = PD.DropID AND PD.StorerKey = @cStorerKey
            JOIN dbo.DropidDetail DD WITH(NOLOCK) ON PD.Dropid = DD.ChildId AND DD.Dropid = @cDropID
            WHERE StorerKey = @cStorerKey;

            --Update order status to loaded
            UPDATE O WITH(ROWLOCK)
            SET O.Status = '8'
            FROM dbo.ORDERS O
            JOIN dbo.PICKHEADER PH WITH(NOLOCK) ON O.OrderKey = PH.OrderKey
            JOIN dbo.PackDetail PD WITH(NOLOCK) ON PH.PickHeaderKey = PD.PickSlipNo
            JOIN dbo.Dropid D WITH(NOLOCK) ON PD.DropID = D.Dropid
            JOIN dbo.DropidDetail DD WITH(NOLOCK) ON D.Dropid = DD.ChildId AND DD.Dropid = @cDropID
            LEFT JOIN dbo.Dropid D2 WITH(NOLOCK) ON PD.PickSlipNo = D2.PickSlipNo AND D2.Status < '9'
            WHERE D2.Dropid IS NULL;
            
            SET @nErrNo = 217969
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Order is Loaded' 
            SET @nErrNo = 0 --Setting to 0, as only message is required, there is no actual error

            --Updating non-processed serial numbers, as not all of them need to be packed, but if loaded, that means, those ar ok to go (with parent pallet).
            UPDATE S WITH(ROWLOCK)
            SET S.Status = '6'
            FROM dbo.SerialNo S
            JOIN dbo.PICKDETAIL PID WITH(NOLOCK) ON S.OrderKey = PID.OrderKey AND PID.StorerKey = @cStorerKey
            JOIN dbo.PackDetail PD WITH(NOLOCK) ON PID.PickSlipNo = PD.PickSlipNo AND PD.StorerKey = @cStorerKey
            JOIN dbo.DropidDetail DD WITH(NOLOCK) ON PD.DropID = DD.ChildId AND DD.Dropid = @cDropID
            WHERE S.Status < '6';
            
            GOTO Quit
         END
         
         GOTO Quit
      END -- step2
   END--Inputkey =1 

   RollbackTran:
   IF ISNULL( @nErrNo, 0) <> 0  -- Error Occured - Process And Return    
      ROLLBACK TRAN rdt_1642ExtUpd02_VLT    

   Quit:  
   WHILE @@TRANCOUNT > @nStartTCnt -- Commit until the level we started    
      COMMIT TRAN rdt_1642ExtUpd02_VLT
END -- sp

GO