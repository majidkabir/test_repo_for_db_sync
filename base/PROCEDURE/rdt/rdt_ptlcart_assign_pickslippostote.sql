SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_PTLCart_Assign_PickslipPosTote                        */  
/* Copyright      : LFLogistics                                               */  
/*                                                                            */  
/* Date       Rev  Author   Purposes                                          */  
/* 06-05-2015 1.0  Ung      SOS333663 Created                                 */  
/* 26-01-2018 1.1  Ung      Change to PTL.Schema                              */  
/* 19-11-2018 1.2  James    WMS-6854 Check custom pickcfm status (james01)    */
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_PTLCart_Assign_PickslipPosTote] (  
   @nMobile          INT,   
   @nFunc            INT,   
   @cLangCode        NVARCHAR( 3),   
   @nStep            INT,   
   @nInputKey        INT,   
   @cFacility        NVARCHAR( 5),   
   @cStorerKey       NVARCHAR( 15),    
   @cCartID          NVARCHAR( 10),  
   @cPickZone        NVARCHAR( 10),  
   @cMethod          NVARCHAR( 1),  
   @cPickSeq         NVARCHAR( 1),  
   @cDPLKey          NVARCHAR( 10),  
   @cType            NVARCHAR( 15), --POPULATE-IN/POPULATE-OUT/CHECK  
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,     
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,     
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,     
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,     
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,     
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,    
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,    
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,    
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,    
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,    
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,   
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,   
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,   
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,   
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,   
   @nScn             INT           OUTPUT,  
   @nErrNo           INT           OUTPUT,   
   @cErrMsg          NVARCHAR( 20) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount  INT  
   DECLARE @nTotalTote  INT  
  
   DECLARE @cPickSlipNo NVARCHAR(10)  
   DECLARE @cPosition   NVARCHAR(10)  
   DECLARE @cToteID     NVARCHAR(20)  
  
   DECLARE @cPSType     NVARCHAR(10)  
   DECLARE @cZone       NVARCHAR(18)  
   DECLARE @cOrderKey   NVARCHAR(10)  
   DECLARE @cLoadKey    NVARCHAR(10)  
   DECLARE @cPickConfirmStatus NVARCHAR(1)  
  
   SET @nTranCount = @@TRANCOUNT  
        
   /***********************************************************************************************  
                                                POPULATE  
   ***********************************************************************************************/  
   IF @cType = 'POPULATE-IN'  
   BEGIN  
      -- Get total  
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID  
  
     -- Prepare next screen var  
     SET @cOutField01 = @cCartID  
     SET @cOutField02 = @cPickZone  
     SET @cOutField03 = '' -- PickSlipNo  
     SET @cOutField04 = '' -- Position  
     SET @cOutField05 = '' -- ToteID  
     SET @cOutField06 = CAST( @nTotalTote AS NVARCHAR(5)) --TotalTote  
  
    EXEC rdt.rdtSetFocusField @nMobile, 3 -- PickSlipNo  
  
     -- Go to pickslipno, pos, tote screen  
     SET @nScn = 4185  
   END        
  
   /*     
   IF @cType = 'POPULATE-OUT'  
   BEGIN  
  -- Go to cart screen  
   END  
   */  
  
   /***********************************************************************************************  
                                                 CHECK  
   ***********************************************************************************************/  
   IF @cType = 'CHECK'  
   BEGIN  
      -- Screen mapping  
      SET @cPickSlipNo = @cInField03  
      SET @cPosition = @cInField04  
      SET @cToteID = @cInField05  
  
      -- Get total  
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID  
  
      -- Check finish assign  
      IF @nTotalTote > 0 AND @cPickSlipNo = '' AND @cPosition = '' AND @cToteID = ''  
      BEGIN  
         GOTO Quit  
      END  
        
      -- Check blank  
  IF @cPickSlipNo = ''   
      BEGIN  
         SET @nErrNo = 54351  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedPickSlipNo  
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- PickSlipNo  
         GOTO Quit  
      END  
        
      -- Check pickslip assigned  
      IF @cPickZone = ''  
         SELECT @nErrNo = 1  
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)  
         WHERE PickSlipNo = @cPickSlipNo  
      ELSE  
         SELECT @nErrNo = 1  
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)  
         WHERE PickSlipNo = @cPickSlipNo  
            AND (PickZone = @cPickZone OR PickZone = '')  
      IF @nErrNo <> 0  
      BEGIN  
         SET @nErrNo = 54361  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS Assigned  
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- PickSlipNo  
         SET @cOutField03 = ''  
         GOTO Quit  
      END  
  
      -- Get PickHeader info  
      SELECT   
         @cZone = Zone,   
         @cOrderKey = ISNULL( OrderKey, ''),   
         @cLoadKey = ExternOrderKey  
      FROM PickHeader WITH (NOLOCK)   
      WHERE PickHeaderKey = @cPickSlipNo  
  
      -- Check PickSlipNo valid  
      IF @@ROWCOUNT = 0  
      BEGIN  
         SET @nErrNo = 54360  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad PickSlipNo  
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- PickSlipNo  
         GOTO Quit  
      END  

      -- (james01)
      -- If setup custom pick status then check pd.status based on setup.
      -- If not setup then follow original checking
      SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
      IF @cPickConfirmStatus = '0'
         SET @cPickConfirmStatus = ''

      -- Get PickSlip type  
      IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'  
         SET @cPSType = 'XD'  
      ELSE IF @cOrderKey = ''  
         SET @cPSType = 'CONSO'  
      ELSE  
         SET @cPSType = 'DISCRETE'  
        
      -- Check PickSlip in Zone  
      SET @nErrNo = 1  
      IF @cPickZone = ''   
      BEGIN  
         IF @cPSType = 'DISCRETE'  
            SELECT TOP 1 @nErrNo = 0  
            FROM Orders O WITH (NOLOCK)   
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
            WHERE O.OrderKey = @cOrderKey  
               AND ( ( @cPickConfirmStatus <> '' AND PD.Status < @cPickConfirmStatus) OR 
                     ( @cPickConfirmStatus = '' AND PD.Status < '4'))
               AND PD.QTY > 0  
               AND O.Status <> 'CANC'   
               AND O.SOStatus <> 'CANC'  
           
         IF @cPSType = 'CONSO'  
            SELECT TOP 1 @nErrNo = 0  
            FROM LoadPlanDetail LPD WITH (NOLOCK)   
               JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)  
               JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
            WHERE LPD.Loadkey = @cLoadKey  
               AND ( ( @cPickConfirmStatus <> '' AND PD.Status < @cPickConfirmStatus) OR 
                     ( @cPickConfirmStatus = '' AND PD.Status < '4'))
               AND PD.QTY > 0  
               AND O.Status <> 'CANC'   
               AND O.SOStatus <> 'CANC'  
  
         IF @cPSType = 'XD'  
            SELECT TOP 1 @nErrNo = 0  
            FROM Orders O WITH (NOLOCK)  
               JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
               JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)  
            WHERE RKL.PickslipNo = @cPickSlipNo  
               AND ( ( @cPickConfirmStatus <> '' AND PD.Status < @cPickConfirmStatus) OR 
                     ( @cPickConfirmStatus = '' AND PD.Status < '4'))
               AND PD.QTY > 0  
               AND O.Status <> 'CANC'   
               AND O.SOStatus <> 'CANC'  
      END  
      ELSE  
      BEGIN  
         IF @cPSType = 'DISCRETE'  
            SELECT TOP 1 @nErrNo = 0  
            FROM Orders O WITH (NOLOCK)   
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
               JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)  
            WHERE O.OrderKey = @cOrderKey  
               AND ( ( @cPickConfirmStatus <> '' AND PD.Status < @cPickConfirmStatus) OR 
                     ( @cPickConfirmStatus = '' AND PD.Status < '4'))
               AND PD.QTY > 0  
               AND O.Status <> 'CANC'   
               AND O.SOStatus <> 'CANC'  
               AND LOC.PickZone = @cPickZone  
           
         IF @cPSType = 'CONSO'  
            SELECT TOP 1 @nErrNo = 0  
            FROM LoadPlanDetail LPD WITH (NOLOCK)   
               JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)  
               JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
               JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)  
            WHERE LPD.Loadkey = @cLoadKey  
               AND ( ( @cPickConfirmStatus <> '' AND PD.Status < @cPickConfirmStatus) OR 
                     ( @cPickConfirmStatus = '' AND PD.Status < '4'))
               AND PD.QTY > 0  
               AND O.Status <> 'CANC'   
               AND O.SOStatus <> 'CANC'  
               AND LOC.PickZone = @cPickZone  
  
         IF @cPSType = 'XD'  
            SELECT TOP 1 @nErrNo = 0  
            FROM Orders O WITH (NOLOCK)  
               JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
               JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)  
               JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)  
            WHERE RKL.PickslipNo = @cPickSlipNo  
               AND ( ( @cPickConfirmStatus <> '' AND PD.Status < @cPickConfirmStatus) OR 
                     ( @cPickConfirmStatus = '' AND PD.Status < '4'))
               AND PD.QTY > 0  
               AND O.Status <> 'CANC'   
               AND O.SOStatus <> 'CANC'  
               AND LOC.PickZone = @cPickZone  
      END  
        
      IF @nErrNo <> 0  
      BEGIN  
         SET @nErrNo = 54352  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS NoPickTask  
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- PickSlipNo  
         SET @cOutField03 = ''  
         GOTO Quit  
      END  
      SET @cOutField03 = @cPickSlipNo  
        
      -- Check position blank  
      IF @cPosition = ''  
      BEGIN  
         SET @nErrNo = 54353  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Position  
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Position  
         SET @cOutField04 = ''  
         GOTO Quit  
      END  
  
      -- Check position valid  
      IF NOT EXISTS( SELECT 1  
         FROM dbo.DeviceProfile WITH (NOLOCK)  
         WHERE DeviceType = 'CART'  
            AND DeviceID = @cCartID  
            AND DevicePosition = @cPosition)  
      BEGIN  
         SET @nErrNo = 54354  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Position  
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Position  
         SET @cOutField04 = ''  
         GOTO Quit  
      END  
  
      -- Check position assigned  
      IF EXISTS( SELECT 1  
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)  
         WHERE CartID = @cCartID  
            AND Position = @cPosition)  
      BEGIN  
         SET @nErrNo = 54355  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pos assigned  
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Position  
         SET @cOutField04 = ''  
         GOTO Quit  
      END  
      SET @cOutField04 = @cPosition  
  
      -- Check blank tote  
      IF @cToteID = ''  
      BEGIN  
         SET @nErrNo = 54356  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToteID  
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID  
         SET @cOutField05 = ''  
         GOTO Quit  
      END  
  
      -- Check tote assigned  
    IF EXISTS( SELECT 1  
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)  
         WHERE CartID = @cCartID  
            AND ToteID = @cToteID)  
      BEGIN  
         SET @nErrNo = 54357  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned  
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID  
         SET @cOutField05 = ''  
         GOTO Quit  
      END  
      SET @cOutField05 = @cToteID  
        
      DECLARE @cIPAddress NVARCHAR(40)  
      DECLARE @cLOC NVARCHAR(10)  
      DECLARE @cSKU NVARCHAR(20)  
      DECLARE @nQTY INT  
        
      -- Get position info  
      SELECT @cIPAddress = IPAddress  
      FROM DeviceProfile WITH (NOLOCK)  
      WHERE DeviceType = 'CART'  
         AND DeviceID = @cCartID  
         AND DevicePosition = @cPosition  
  
      BEGIN TRAN  
      SAVE TRAN rdt_PTLCart_Assign_PSNoPosTote  
        
      -- Save assign  
      INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, PickSlipNo, StorerKey)  
      VALUES (@cCartID, @cPosition, @cToteID, @cDPLKey, @cMethod, @cPickZone, @cPickSeq, @cPickSlipNo, @cStorerKey)  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 54358  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail  
         GOTO RollBackTran  
      END  
  
      -- Insert PTLTran  
      DECLARE @curPD CURSOR  
      IF @cPickZone = ''  
      BEGIN  
         IF @cPSType = 'DISCRETE'  
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT PD.LOC, PD.SKU, SUM( PD.QTY)  
               FROM Orders O WITH (NOLOCK)   
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
               WHERE O.OrderKey = @cOrderKey  
                  AND ( ( @cPickConfirmStatus <> '' AND PD.Status < @cPickConfirmStatus) OR 
                        ( @cPickConfirmStatus = '' AND PD.Status < '4'))
                  AND PD.QTY > 0  
                  AND O.Status <> 'CANC'   
                  AND O.SOStatus <> 'CANC'  
               GROUP BY PD.LOC, PD.SKU  
           
         IF @cPSType = 'CONSO'  
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT PD.LOC, PD.SKU, SUM( PD.QTY)  
               FROM LoadPlanDetail LPD WITH (NOLOCK)   
                  JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)  
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
               WHERE LPD.Loadkey = @cLoadKey  
                  AND ( ( @cPickConfirmStatus <> '' AND PD.Status < @cPickConfirmStatus) OR 
                        ( @cPickConfirmStatus = '' AND PD.Status < '4'))
                  AND PD.QTY > 0  
                  AND O.Status <> 'CANC'   
                  AND O.SOStatus <> 'CANC'  
               GROUP BY PD.LOC, PD.SKU  
  
         IF @cPSType = 'XD'  
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT PD.LOC, PD.SKU, SUM( PD.QTY)  
               FROM Orders O WITH (NOLOCK)  
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
                  JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)  
               WHERE RKL.PickslipNo = @cPickSlipNo  
                  AND ( ( @cPickConfirmStatus <> '' AND PD.Status < @cPickConfirmStatus) OR 
                        ( @cPickConfirmStatus = '' AND PD.Status < '4'))
                  AND PD.QTY > 0  
                  AND O.Status <> 'CANC'   
                  AND O.SOStatus <> 'CANC'  
               GROUP BY PD.LOC, PD.SKU  
      END  
      ELSE  
      BEGIN  
         IF @cPSType = 'DISCRETE'  
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT LOC.LOC, PD.SKU, SUM( PD.QTY)  
               FROM Orders O WITH (NOLOCK)   
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
                  JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)  
               WHERE O.OrderKey = @cOrderKey  
                  AND ( ( @cPickConfirmStatus <> '' AND PD.Status < @cPickConfirmStatus) OR 
                        ( @cPickConfirmStatus = '' AND PD.Status < '4'))
                  AND PD.QTY > 0  
                  AND O.Status <> 'CANC'   
                  AND O.SOStatus <> 'CANC'  
                  AND LOC.PickZone = @cPickZone  
               GROUP BY LOC.LOC, PD.SKU  
           
         IF @cPSType = 'CONSO'  
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT LOC.LOC, PD.SKU, SUM( PD.QTY)  
               FROM LoadPlanDetail LPD WITH (NOLOCK)   
                  JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)  
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
                  JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)  
               WHERE LPD.Loadkey = @cLoadKey  
                  AND ( ( @cPickConfirmStatus <> '' AND PD.Status < @cPickConfirmStatus) OR 
                        ( @cPickConfirmStatus = '' AND PD.Status < '4'))
                  AND PD.QTY > 0  
                  AND O.Status <> 'CANC'   
                  AND O.SOStatus <> 'CANC'  
                  AND LOC.PickZone = @cPickZone  
               GROUP BY LOC.LOC, PD.SKU  
                 
         IF @cPSType = 'XD'  
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT LOC.LOC, PD.SKU, SUM( PD.QTY)  
               FROM Orders O WITH (NOLOCK)  
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
                  JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)  
                  JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)  
               WHERE RKL.PickslipNo = @cPickSlipNo  
                  AND ( ( @cPickConfirmStatus <> '' AND PD.Status < @cPickConfirmStatus) OR 
                        ( @cPickConfirmStatus = '' AND PD.Status < '4'))
                  AND PD.QTY > 0  
                  AND O.Status <> 'CANC'   
                  AND O.SOStatus <> 'CANC'  
                  AND LOC.PickZone = @cPickZone  
               GROUP BY LOC.LOC, PD.SKU   
      END  
        
      OPEN @curPD  
      FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         INSERT INTO PTL.PTLTran (  
            IPAddress, DeviceID, DevicePosition, Status, PTLType,   
            DeviceProfileLogKey, DropID, SourceKey, Storerkey, SKU, LOC, ExpectedQTY, QTY)  
         VALUES (  
            @cIPAddress, @cCartID, @cPosition, '0', 'CART',  
            @cDPLKey, '', @cPickSlipNo, @cStorerKey, @cSKU, @cLOC, @nQTY, 0)  
     
         IF @@ERROR <> ''  
         BEGIN  
            SET @nErrNo = 54359  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail  
            GOTO RollBackTran  
         END  
         FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY  
      END  
  
      COMMIT TRAN rdt_PTLCart_Assign_PSNoPosTote  
  
      SET @nTotalTote = @nTotalTote + 1  
  
      -- Prepare current screen var  
      SET @cOutField03 = '' -- PickSlipNo  
      SET @cOutField04 = '' -- Position  
      SET @cOutField05 = '' -- ToteID  
      SET @cOutField06 = CAST( @nTotalTote AS NVARCHAR(5)) --TotalTote  
        
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- PickSlipNo  
        
      -- Stay in current page  
      SET @nErrNo = -1   
   END  
  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_PTLCart_Assign_PSNoPosTote  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO