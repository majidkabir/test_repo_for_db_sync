SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_Cluster_Pick_DropID                             */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Comfirm Pick                                                */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 15-Jul-2013 1.0  James       Created                                 */
/* 19-Jun-2014 1.1  James       SOS313608 - Add Custom SP to create     */
/*                              Dropid (james01)                        */
/* 01-Sep-2014 1.3  James       Allow reuse DropID if exists (james02)  */
/************************************************************************/

CREATE PROC [RDT].[rdt_Cluster_Pick_DropID] (
   @nMobile          INT, 
   @nFunc            INT, 
   @cStorerKey       NVARCHAR( 15),
   @cUserName        NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cLoadKey         NVARCHAR( 10),
   @cPickSlipNo      NVARCHAR( 10),
   @cOrderKey        NVARCHAR( 10),
   @cDropID          NVARCHAR( 20)  OUTPUT,
   @cSKU             NVARCHAR( 20),
   @cActionFlag      NVARCHAR( 1),
   @cLangCode        NVARCHAR( 3),
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount INT  

   DECLARE @cCustomDropID_SP  NVARCHAR( 20), -- (james01)  
           @cSQLStatement     NVARCHAR(2000),
           @cSQLParms         NVARCHAR(2000) 

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN Cluster_Pick_InsDropID

   IF ISNULL(@cLoadKey, '') = ''
      SELECT @cLoadKey = LoadKey 
      FROM dbo.LoadPlanDetail WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey

   -- (james01)
   SET @cCustomDropID_SP = rdt.RDTGetConfig( @nFunc, 'CustomDropID_SP', @cStorerkey)
   IF @cCustomDropID_SP NOT IN ('0', '') AND 
      EXISTS ( SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[rdt].[' + @cCustomDropID_SP + ']') AND type in (N'P', N'PC'))  
   BEGIN
      SET @nErrNo = 0
      SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cCustomDropID_SP) +     
         ' @nMobile, @nFunc, @cLangCode, @cStorerkey, @cUserName, @cFacility, @cLoadKey, @cPickSlipNo, @cOrderKey, @cDropID OUTPUT, @cSKU, @cActionFlag,' + 
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    

      SET @cSQLParms =    
         '@nMobile                   INT,           ' +
         '@nFunc                     INT,           ' +
         '@cLangCode                 NVARCHAR( 3),  ' +
         '@cStorerkey                NVARCHAR( 15), ' +
         '@cUserName                 NVARCHAR( 15), ' +
         '@cFacility                 NVARCHAR( 5),  ' + 
         '@cLoadKey                  NVARCHAR( 10), ' +
         '@cPickSlipNo               NVARCHAR( 10), ' +
         '@cOrderKey                 NVARCHAR( 10), ' +
         '@cDropID                   NVARCHAR( 20) OUTPUT, ' +
         '@cSKU                      NVARCHAR( 20), ' +
         '@cActionFlag               NVARCHAR( 1), ' +
         '@nErrNo                    INT           OUTPUT,  ' +
         '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
         
      EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
           @nMobile, @nFunc, @cLangCode, @cStorerkey, @cUserName, @cFacility, @cLoadKey, @cPickSlipNo, @cOrderKey, @cDropID OUTPUT, @cSKU, @cActionFlag,  
           @nErrNo OUTPUT, @cErrMsg OUTPUT     
           
      IF @nErrNo <> 0
         GOTO RollBackTran  
   END
   ELSE
   BEGIN
      IF @cActionFlag = 'R'
      BEGIN
         SET @cDropID = ''
         SELECT TOP 1 @cDropID = D.DropID 
         FROM dbo.DropIDDetail DD WITH (NOLOCK) 
         JOIN dbo.DropID D WITH (NOLOCK) ON DD.DropID = D.DropID
         WHERE DD.ChildID = @cOrderKey
         AND   D.Status = '0'
         
         GOTO RollBackTran
      END
      
      IF @cActionFlag = 'I'
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                    WHERE DropID = @cDropID 
                    AND   [Status] = '0')
         BEGIN
            IF rdt.RDTGetConfig( @nFunc, 'ClusterPickAllowReuseDropID', @cStorerKey) = '1'
            BEGIN
               -- Delete existing dropiddetail
               DELETE FROM dbo.DropIDDetail  
               WHERE DropID = @cDropID 

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 81709
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DDTL FAIL'
                  GOTO RollBackTran
               END

               -- Delete existing dropid
               DELETE FROM dbo.DropID 
               WHERE DropID = @cDropID 

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 81710
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DID FAIL'
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 81701
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROPID'
               GOTO RollBackTran
            END
         END
         
         INSERT INTO dbo.DropID 
         (DropID, LabelPrinted, [Status], PickSlipNo, LoadKey)
         VALUES 
         (@cDropID, '0', '0', @cPickSlipNo, @cLoadKey)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 81702
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DID FAIL'
            GOTO RollBackTran
         END

         INSERT INTO dbo.DropIDDetail 
         (DropID, ChildID)
         VALUES 
         (@cDropID, @cOrderKey)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 81703
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DDTL FAIL'
            GOTO RollBackTran
         END
      END

      IF @cActionFlag = 'U'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                        WHERE DropID = @cDropID)
         BEGIN
            SET @nErrNo = 81704
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROPID'
            GOTO RollBackTran
         END
         
         UPDATE dbo.DropID WITH (ROWLOCK) SET 
            [Status] = '9'
         WHERE DropID = @cDropID 
         AND   [Status] = '0'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 81705
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD DID FAIL'
            GOTO RollBackTran
         END
      END

      IF @cActionFlag = 'D'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                        WHERE DropID = @cDropID)
         BEGIN
            SET @nErrNo = 81706
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROPID'
            GOTO RollBackTran
         END
         
         DELETE FROM dbo.DropIDDetail  
         WHERE DropID = @cDropID 

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 81707
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DDTL FAIL'
            GOTO RollBackTran
         END

         DELETE FROM dbo.DropID 
         WHERE DropID = @cDropID 

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 81708
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DID FAIL'
            GOTO RollBackTran
         END
      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN Cluster_Pick_InsDropID

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN Cluster_Pick_InsDropID
END

GO