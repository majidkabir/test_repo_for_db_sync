SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_EGL_DropID01                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Eagles custom drop id stored proc (no update PENDPACK)      */
/*                                                                      */
/* Called from: rdt_Cluster_Pick_DropID                                 */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 09-Sep-2014 1.0  James      SOS352521 - Created                      */
/* 30-May-2018 1.2  CheeMun    INC0225019 - Prevent DropID status 9     */
/*                                          update back to 5            */
/* 26-Sep-2019 1.3  LZG        INC0869832 - Return blank DropID if blank*/
/*                             OrderKey is passed in (ZG01)             */
/************************************************************************/

CREATE PROC [RDT].[rdt_EGL_DropID01] (
   @nMobile                   INT,           
   @nFunc                     INT,           
   @cLangCode                 NVARCHAR( 3),  
   @cStorerkey                NVARCHAR( 15), 
   @cUserName                 NVARCHAR( 15), 
   @cFacility                 NVARCHAR( 5),  
   @cLoadKey                  NVARCHAR( 10), 
   @cPickSlipNo               NVARCHAR( 10), 
   @cOrderKey                 NVARCHAR( 10), 
   @cDropID                   NVARCHAR( 20) OUTPUT, 
   @cSKU                      NVARCHAR( 20), 
   @cActionFlag               NVARCHAR( 1), 
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT   
         
)
AS
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @nTranCount        INT, 
           @nUpdate           INT, 
           @cDropIDType       NVARCHAR( 10), 
           @cLoadPickMethod   NVARCHAR( 10), 
           @cPD_OrderKey      NVARCHAR( 10), 
           @cPD_DropID        NVARCHAR( 20) 

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_EGL_DropID01

   IF ISNULL(@cLoadKey, '') = ''
      SELECT @cLoadKey = LoadKey 
      FROM dbo.LoadPlanDetail WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey

   IF ISNULL(@cLoadKey, '') <> ''
      SELECT @cLoadPickMethod = LoadPickMethod 
      FROM dbo.LoadPlan WITH (NOLOCK) 
      WHERE LoadKey = @cLoadKey

   IF @cActionFlag = 'R'
   BEGIN
      SET @cDropID = ''
      
      IF ISNULL(@cOrderKey, '') <> ''           -- ZG01
         SELECT TOP 1 @cDropID = D.DropID 
         FROM dbo.DropIDDetail DD WITH (NOLOCK) 
         JOIN dbo.DropID D WITH (NOLOCK) ON DD.DropID = D.DropID
         WHERE DD.ChildID = @cOrderKey
         AND   D.Status IN ( '0' , '5' ) 
      
      GOTO RollBackTran
   END
   
   IF @cActionFlag = 'I'
   BEGIN
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                 WHERE DropID = @cDropID 
                 AND   [Status] = '0')
      BEGIN
         SET @nErrNo = 56501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROPID'
         GOTO RollBackTran
      END

      IF ISNULL( @cOrderKey, '') <> ''
      BEGIN
         SELECT @cDropIDType = 
                CASE WHEN ISNULL( SUM( Qty), 0) = 1 THEN 'SINGLES' 
                     WHEN ISNULL( SUM( Qty), 0) > 1 THEN 'MULTIS' 
                     ELSE '' END
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerkey
         AND OrderKey = @cOrderKey
      END

      IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                  WHERE DropID = @cDropID 
                  And   [STATUS] = '9' )  
      BEGIN
         DELETE FROM dbo.DropIDDetail  
         WHERE DropID = @cDropID 

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 56502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DDTL FAIL'
            GOTO RollBackTran
         END

         DELETE FROM dbo.DropID 
         WHERE DropID = @cDropID 

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 56503
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DID FAIL'
            GOTO RollBackTran
         END      
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)   
                      WHERE DropID = @cDropID ) 
      BEGIN
         INSERT INTO dbo.DropID 
         (DropID, DropIDType, LabelPrinted, ManifestPrinted, [Status], PickSlipNo, LoadKey)
         VALUES 
         (@cDropID, @cDropIDType, '0', '0', '5', @cPickSlipNo, @cLoadKey)
   
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 56504
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DID FAIL'
            GOTO RollBackTran
         END
      END
      -- Insert DropidDetail here
      IF @cLoadPickMethod = 'C'
      BEGIN
         DECLARE CUR_INSDROPID CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT DISTINCT PD.OrderKey, PD.DropID 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
         WHERE  PD.StorerKey = @cStorerKey
         AND    LPD.LoadKey = @cLoadKey
         AND    PD.Status < '9'
         ORDER BY PD.DropID, PD.OrderKey
         OPEN CUR_INSDROPID
         FETCH NEXT FROM CUR_INSDROPID INTO @cPD_OrderKey, @cPD_DropID
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) 
                            WHERE DropID = @cPD_DropID
                            AND   ChildID = @cPD_OrderKey)
            BEGIN
               INSERT INTO dbo.DropIDDetail 
               (DropID, ChildID) VALUES 
               (@cPD_DropID, @cPD_OrderKey)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 56505
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DDTL FAIL'
                  CLOSE CUR_INSDROPID
                  DEALLOCATE CUR_INSDROPID
                  GOTO RollBackTran
               END
            END

            FETCH NEXT FROM CUR_INSDROPID INTO @cPD_OrderKey, @cPD_DropID
         END
         CLOSE CUR_INSDROPID
         DEALLOCATE CUR_INSDROPID
      END
      ELSE
      BEGIN
         
         IF NOT  EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK)
                    WHERE DropID = @cDropID
                    AND ChildID = @cOrderkey ) 
         BEGIN                     
            INSERT INTO dbo.DropIDDetail 
            (DropID, ChildID)
            VALUES 
            (@cDropID, @cOrderKey)
   
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 56506
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DDTL FAIL'
               GOTO RollBackTran
            END
         END
      END
   END

   IF @cActionFlag = 'U'
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                     WHERE DropID = @cDropID)
      BEGIN
         SET @nErrNo = 56507
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROPID'
         GOTO RollBackTran
      END
      
      SET @nUpdate = 0
      
      -- Conso pick need check every orders that is finish picking then can update dropid.status = '5'
      IF ISNULL( @cLoadKey, '') <> '' AND @cLoadPickMethod = 'C'
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
                         WHERE PD.StorerKey = @cStorerkey
                         AND   PD.Status = '0'
                         AND   LPD.LoadKey = @cLoadKey) 
            SET @nUpdate = 1
      END
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                         WHERE StorerKey = @cStorerkey
                         AND   [Status] = '0'
                         AND   OrderKey = @cOrderKey)
            SET @nUpdate = 1
      END

      IF @nUpdate = 1
      BEGIN
         IF @cLoadPickMethod = 'C'
         BEGIN
            UPDATE dbo.DropID WITH (ROWLOCK) SET 
               [Status] = '5' 
            WHERE LoadKey = @cLoadKey
            --AND   [Status] <> '5'
            AND   [Status] <> '9'  --INC0225019 

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 56508
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD DID FAIL'
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            UPDATE dbo.DropID WITH (ROWLOCK) SET 
               [Status] = '5' 
            WHERE DropID = @cDropID
            AND   [Status] <> '5'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 56509
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD DID FAIL'
               GOTO RollBackTran
            END
         END
      END
   END

   IF @cActionFlag = 'D'
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                     WHERE DropID = @cDropID)
      BEGIN
         SET @nErrNo = 56510
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROPID'
         GOTO RollBackTran
      END
      
      DELETE FROM dbo.DropIDDetail  
      WHERE DropID = @cDropID 

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 56511
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DDTL FAIL'
         GOTO RollBackTran
      END

      DELETE FROM dbo.DropID 
      WHERE DropID = @cDropID 

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 56512
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DID FAIL'
         GOTO RollBackTran
      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_EGL_DropID01

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_EGL_DropID01

END

GO