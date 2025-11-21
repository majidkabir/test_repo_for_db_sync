SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_819ExtUpd01                                     */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: WCSRouting necessary actions                                */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 24-08-2016  1.0  James       SOS370883 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_819ExtUpd01]
   @nMobile    INT, 
   @nFunc      INT, 
   @cLangCode  NVARCHAR( 3), 
   @nStep      INT, 
   @nInputKey  INT, 
   @cFacility  NVARCHAR( 5),  
   @cStorerKey NVARCHAR( 15), 
   @cLight     NVARCHAR( 1),  
   @cDPLKey    NVARCHAR( 10), 
   @cCartID    NVARCHAR( 10), 
   @cPickZone  NVARCHAR( 10), 
   @cMethod    NVARCHAR( 10), 
   @cPickSeq   NVARCHAR( 1),  
   @cLOC       NVARCHAR( 10), 
   @cSKU       NVARCHAR( 20), 
   @cToteID    NVARCHAR( 20), 
   @nQTY       INT,           
   @cNewToteID NVARCHAR( 20), 
   @nErrNo     INT            OUTPUT, 
   @cErrMsg    NVARCHAR( 20)  OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT,
           @bSuccess   INT

   DECLARE @curDPL CURSOR
            
   DECLARE @nPicked_Qty    INT,
           @cLoadKey       NVARCHAR( 10),
           @cPickSlipNo    NVARCHAR( 10),
           @cConsigneeKey  NVARCHAR( 15),
           @cToLoc         NVARCHAR( 10),
           @cItemClass     NVARCHAR( 10),
           @cPTSStoreGroup NVARCHAR( 20),
           @cOrderkey      NVARCHAR( 10),
           @cOrderType     NVARCHAR( 10),
           @cUserName      NVARCHAR( 18),
           @cPicked_ToteID NVARCHAR( 20),
           @cFinalWCSZone  NVARCHAR( 10),
           @cDropIDType    NVARCHAR( 10),
           @cWCSKey        NVARCHAR( 10),
           @cInit_Final_Zone     NVARCHAR( 10),
           @cFinalPutawayzone    NVARCHAR( 10),
           @cTaskDetailKey       NVARCHAR( 10)

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  
   SAVE TRAN rdt_819ExtUpd01 

   SELECT @cUserName = UserName
   FROM rdt.rdtMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 6 -- Tote
      BEGIN
         -- Insert Drop Id
         IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DROPID  = @cToteID )  
         BEGIN  
            -- Stamp loadkey & pickslip inside dropid table 
            SELECT TOP 1 @cLoadKey = O.LoadKey, 
                         @cOrderkey = O.Orderkey,
                         @cDropIDType = CASE WHEN ISNULL( O.UserDefine01, '') = '' THEN 'PIECE' ELSE O.UserDefine01 END
            FROM dbo.PTLTran PTL WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON ( PTL.OrderKey = O.OrderKey)
            WHERE PTL.DeviceProfileLogKey = @cDPLKey
            AND   PTL.LOC = @cLOC
            AND   PTL.SKU = @cSKU
            AND   PTL.Status = '9'
            AND   PTL.PTL_TYPE = 'CART'
            AND   PTL.DropID = @cToteID
            AND   PTL.Qty > 0
            ORDER BY PTL.EditDate DESC

            SELECT @cPickSlipNo = PickHeaderKey 
            FROM dbo.PickHeader WITH (NOLOCK) 
            WHERE ExternOrderKey = @cLoadkey
            AND   OrderKey = CASE WHEN ISNULL( OrderKey, '') = '' THEN OrderKey ELSE @cOrderkey END

            INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey, PickSlipNo, UDF01, UDF02)  
            VALUES (@cToteID , '' , @cDropIDType, '0' , @cLoadkey, @cPickSlipNo, @cOrderKey, 'CARTPICK')  

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 104301  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'  
               GOTO RollBackTran
            END  
         END  

         IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) 
                        WHERE DROPID = @cToteID 
                        AND   ChildID = @cSKU)  
         BEGIN  
            INSERT INTO DROPIDDETAIL ( DropID, ChildID)  
            VALUES (@cToteID, @cSKU )  

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 104302  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'  
               GOTO RollBackTran
            END  
         END 
      END      -- Tote

      IF @nStep = 8 -- Tote full, change tote
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DROPID  = @cToteID )  
         BEGIN  
            -- Stamp loadkey & pickslip inside dropid table 
            SELECT TOP 1 @cLoadKey = O.LoadKey, 
                         @cOrderkey = O.Orderkey, 
                         @cDropIDType = CASE WHEN ISNULL( O.UserDefine01, '') = '' THEN 'PIECE' ELSE O.UserDefine01 END
            FROM dbo.PTLTran PTL WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON ( PTL.OrderKey = O.OrderKey)
            WHERE PTL.DeviceProfileLogKey = @cDPLKey
            AND   PTL.LOC = @cLOC
            AND   PTL.SKU = @cSKU
            AND   PTL.Status = '9'
            AND   PTL.PTL_TYPE = 'CART'
            AND   PTL.DropID = @cToteID
            AND   PTL.Qty > 0
            ORDER BY PTL.EditDate DESC

            SELECT @cPickSlipNo = PickHeaderKey 
            FROM dbo.PickHeader WITH (NOLOCK) 
            WHERE ExternOrderKey = @cLoadkey
            AND   OrderKey = CASE WHEN ISNULL( OrderKey, '') = '' THEN OrderKey ELSE @cOrderkey END

            INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey, PickSlipNo, UDF01, UDF02 )  
            VALUES (@cToteID , '' , @cDropIDType, '0' , @cLoadkey, @cPickSlipNo, @cOrderKey, 'CARTPICK')  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 104303  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'  
               GOTO RollBackTran  
            END  
         END  
  
         IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DROPID = @cToteID AND ChildID = @cSKU)  
         BEGIN  
            INSERT INTO DROPIDDETAIL ( DropID, ChildID)  
            VALUES (@cToteID, @cSKU )  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 104304  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'  
               GOTO RollBackTran  
            END  
         END  
      END

      IF @nStep = 9 -- Unassign tote from cart
      BEGIN
         SET @curDPL = CURSOR FOR
         SELECT ToteID
         FROM rdt.rdtPTLCartLog WITH (NOLOCK) 
         WHERE DeviceProfileLogKey = @cDPLKey  
         AND   CartID = @cCartID 
         AND   StorerKey = @cStorerKey 
         OPEN @curDPL
         FETCH NEXT FROM @curDPL INTO @cPicked_ToteID
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Clear WCS route
            UPDATE dbo.DropID WITH (ROWLOCK) SET  
               Status = '9'  
            WHERE DropID = @cPicked_ToteID  
               AND Status < '9'  

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 104305  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ResetToteFail'  
               GOTO RollBackTran  
            END  

            FETCH NEXT FROM @curDPL INTO @cPicked_ToteID
         END
         
         -- if orders is unpick then need to activate the task as well
         -- if previously cancelled by cart picking
         SET @curDPL = CURSOR FOR
         SELECT PD.TaskDetailKey
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN rdt.rdtPTLCartLog CART WITH (NOLOCK) ON ( PD.OrderKey = CART.OrderKey)
         WHERE CART.DeviceProfileLogKey = @cDPLKey  
         AND   CART.CartID = @cCartID 
         AND   CART.StorerKey = @cStorerKey 
         AND   PD.Status = '0'
         AND   ISNULL( PD.TaskDetailKey, '') <> ''
         AND   EXISTS (
                  SELECT 1 FROM dbo.PTLTran PTL WITH (NOLOCK)
                  WHERE CART.DeviceProfileLogKey = PTL.DeviceProfileLogKey
                  AND   CART.CartID = PTL.DeviceID
                  GROUP BY OrderKey
                  HAVING ISNULL( SUM( Qty), 0) = 0 -- Nothing picked
                     )
         OPEN @curDPL
         FETCH NEXT FROM @curDPL INTO @cTaskDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                        WHERE TaskDetailKey = @cTaskDetailKey
                        AND   Status = '9'
                        AND   StatusMsg = 'Cancelled by cart picking')
            BEGIN
               UPDATE TaskDetail WITH (ROWLOCK) SET 
                  Status = '0', 
                  StatusMsg = '', 
                  TrafficCop = NULL
               WHERE TaskDetailKey = @cTaskDetailKey

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 104306  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ResetToteFail'  
                  GOTO RollBackTran  
               END  
            END

            FETCH NEXT FROM @curDPL INTO @cTaskDetailKey
         END

      END
   END         -- Inputkey = 1
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_819ExtUpd01
   Fail:
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

END

GO