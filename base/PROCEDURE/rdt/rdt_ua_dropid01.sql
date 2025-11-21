SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_UA_DropID01                                     */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: ANF custom create drop id stored proc                       */  
/*                                                                      */  
/* Called from: rdt_Cluster_Pick_DropID                                 */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 11-nOV-2015 1.0  James      Modify from rdt_ANF_DropID01             */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_UA_DropID01] (  
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
           @cPD_DropID        NVARCHAR( 20), 
           @cChildID          NVARCHAR( 20), 
           @nDropIDQty        INT 

   -- TraceInfo 
   DECLARE    @d_StartTime    datetime,
              @d_StepTime     datetime,
              @d_Step6Time    datetime,           
              @d_EndTime      datetime,
              @d_step1        datetime,
              @d_step2        datetime,
              @d_step3        datetime,
              @d_step4        datetime,
              @d_step5        datetime,
              @c_Col1         NVARCHAR(20),
              @c_Col2         NVARCHAR(20),
              @c_Col3         NVARCHAR(20),
              @c_Col4         NVARCHAR(20),
              @c_Col5         NVARCHAR(20),
              @c_TraceName    NVARCHAR(80), 
              @c_UPDPEN       NVARCHAR(20) 
           
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN rdt_UA_DropID01  

   SET @c_TraceName = 'rdt_UA_DropID01'  
   SET @d_StartTime = getdate()  -- (james_tune)  
   SET @d_step1 = GETDATE()      -- (james_tune)  
  
   IF ISNULL(@cLoadKey, '') = ''  
      SELECT @cLoadKey = LoadKey   
      FROM dbo.LoadPlanDetail WITH (NOLOCK)   
      WHERE OrderKey = @cOrderKey  
  
   IF ISNULL(@cLoadKey, '') <> ''  
      SELECT @cLoadPickMethod = LoadPickMethod   
      FROM dbo.LoadPlan WITH (NOLOCK)   
      WHERE LoadKey = @cLoadKey  

   SET @d_step1 = GETDATE() - @d_step1 -- (james_tune)  
   SET @d_step2 = GETDATE()  

   IF @cActionFlag = 'R'  
   BEGIN  
      SET @cDropID = ''  
      SELECT TOP 1 @cDropID = D.DropID   
      FROM dbo.DropIDDetail DD WITH (NOLOCK)   
      JOIN dbo.DropID D WITH (NOLOCK) ON DD.DropID = D.DropID  
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON DD.ChildId = PD.OrderKey
      WHERE PD.OrderKey = @cOrderKey  
      AND   D.Status IN ( '0' , '5' )   
        
      GOTO RollBackTran  
   END  

   SET @d_step2 = GETDATE() - @d_step2 -- (james_tune)  
   SET @d_step3 = GETDATE()  
      
   IF @cActionFlag = 'I'  
   BEGIN  
      SET @c_TraceName = 'rdt_ANF_DropID01_I'  
      SET @d_StartTime = getdate()  -- (james_tune)  
      SET @d_step1 = GETDATE()      -- (james_tune)  
   
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)   
                 WHERE DropID = @cDropID   
                 AND   [Status] = '0')  
      BEGIN  
         SET @nErrNo = 90401  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROPID'  
         GOTO RollBackTran  
      END  
  
      IF ISNULL( @cOrderKey, '') <> ''  
      BEGIN  
         SELECT @nDropIDQty = ISNULL( SUM( Qty), 0)
         FROM dbo.PickDetail WITH (NOLOCK)   
         WHERE StorerKey = @cStorerkey  
         AND OrderKey = @cOrderKey  

         IF @nDropIDQty = 1
            SET @cDropIDType = 'SINGLES'
         ELSE 
            SET @cDropIDType = 'MULTIS'
      END  

      SET @d_step1 = GETDATE() - @d_step1 -- (james_tune)  
      SET @d_step2 = GETDATE()  

      IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)   
                  WHERE DropID = @cDropID   
                  And   [STATUS] = '9' )    
      BEGIN  
         DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT ChildId 
         FROM dbo.DropIDDetail WITH (NOLOCK) 
         WHERE DropID = @cDropID   
         OPEN CUR_DEL
         FETCH NEXT FROM CUR_DEL INTO @cChildID
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            DELETE FROM dbo.DropIDDetail    
            WHERE DropID = @cDropID   
            AND   ChildID = @cChildID

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 90402  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DDTL FAIL'  
               CLOSE CUR_DEL
               DEALLOCATE CUR_DEL
               GOTO RollBackTran  
            END  

            FETCH NEXT FROM CUR_DEL INTO @cChildID
         END
         CLOSE CUR_DEL
         DEALLOCATE CUR_DEL
  
         DELETE FROM dbo.DropID   
         WHERE DropID = @cDropID   

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 90403  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DID FAIL'  
            GOTO RollBackTran  
         END        
      END  

      SET @d_step2 = GETDATE() - @d_step2 -- (james_tune)  
      SET @d_step3 = GETDATE()  

      IF NOT EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)     
                      WHERE DropID = @cDropID )   
      BEGIN  
         INSERT INTO dbo.DropID   
         (DropID, DropIDType, LabelPrinted, ManifestPrinted, [Status], PickSlipNo, LoadKey)  
         VALUES   
         (@cDropID, @cDropIDType, '0', '0', '5', @cPickSlipNo, @cLoadKey)  
     
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 90404  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DID FAIL'  
            GOTO RollBackTran  
         END  
      END  

      SET @d_step3 = GETDATE() - @d_step3 -- (james_tune)  
      SET @d_step4 = GETDATE()  

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
                  SET @nErrNo = 90405  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DID FAIL'  
                  CLOSE CUR_INSDROPID  
                  DEALLOCATE CUR_INSDROPID  
                  GOTO RollBackTran  
               END  
            END  
  
            -- (james02)  
            IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)   
                               WHERE StorerKey = @cStorerkey  
                               AND   [Status] = '0'  
                               AND   OrderKey = @cPD_OrderKey)  
            BEGIN        
               UPDATE dbo.Orders WITH (ROWLOCK) SET   
                  SOStatus = 'PENDPACK',   
                  Trafficcop = NULL,      -- (james01)  
                  EditDate = GETDATE(),   -- (james01)  
                  EditWho = sUSER_sNAME() -- (james01)  
               WHERE StorerKey = @cStorerkey  
               AND   OrderKey = @cPD_OrderKey  
               AND   SOStatus <> '5'   -- sostatus become 5 after interface come back  
               AND   [Status] = '5'  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 90406  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PPACK FAIL'  
                  GOTO RollBackTran  
               END  
               
               SET @c_UPDPEN = 'UPD PENPACK'
            END  
  
            FETCH NEXT FROM CUR_INSDROPID INTO @cPD_OrderKey, @cPD_DropID  
         END  
         CLOSE CUR_INSDROPID  
         DEALLOCATE CUR_INSDROPID  

         SET @d_step4 = GETDATE() - @d_step4 -- (james_tune)  
         SET @d_step5 = NULL  
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
               SET @nErrNo = 90407  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DDTL FAIL'  
               GOTO RollBackTran  
            END  
         END  
         -- Check if this orders already complete picking  
         -- If yes then update orders.sostatus = penpack  
         IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)   
                            WHERE StorerKey = @cStorerkey  
                            AND   [Status] = '0'  
                            AND   OrderKey = @cOrderKey)  
         BEGIN        
            UPDATE dbo.Orders WITH (ROWLOCK) SET   
               SOStatus = 'PENDPACK',   
               Trafficcop = NULL,      -- (james01)  
               EditDate = GETDATE(),   -- (james01)  
               EditWho = sUSER_sNAME() -- (james01)  
            WHERE StorerKey = @cStorerkey  
            AND   OrderKey = @cOrderKey  
            AND   SOStatus <> '5'   -- sostatus become 5 after interface come back  
            AND   [Status] = '5'  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 90408  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PPACK FAIL'  
               GOTO RollBackTran  
            END  

            SET @c_UPDPEN = 'UPD PENPACK'            
         END  

         SET @d_step4 = GETDATE() - @d_step4 -- (james_tune)  
         SET @d_step5 = NULL  

         SET @c_Col1 = @cPickSlipNo  
         SET @c_Col2 = @cDropID  
         SET @c_Col3 = @cSKU  
         SET @c_Col4 = @cActionFlag  
         SET @c_Col5 = @cUserName     
         SET @d_endtime = GETDATE()  
--         INSERT INTO TraceInfo VALUES  
--               (RTRIM(@c_TraceName), @d_starttime, @d_endtime  
--               ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)  
--               ,CONVERT(CHAR(12),@d_step1,114)  
--               ,CONVERT(CHAR(12),@d_step2,114)  
--               ,CONVERT(CHAR(12),@d_step3,114)  
--               ,CONVERT(CHAR(12),@d_step4,114)  
--               ,CONVERT(CHAR(12),@d_step5,114)  
--                   ,@c_Col1,@c_Col2,@c_Col3,@c_UPDPEN,@c_Col5)  

         SET @d_step1 = NULL  
         SET @d_step2 = NULL  
         SET @d_step3 = NULL  
         SET @d_step4 = NULL  
         SET @d_step5 = NULL  
         SET @c_Col1  = ''  
         SET @c_Col2  = ''  
         SET @c_Col3  = ''  
         SET @c_Col4  = ''  
         SET @c_Col5  = ''           
      END  
   END  

   SET @d_step3 = GETDATE() - @d_step3 -- (james_tune)  
   SET @d_step4 = GETDATE()  

   IF @cActionFlag = 'U'  
   BEGIN  
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)   
                     WHERE DropID = @cDropID)  
      BEGIN  
         SET @nErrNo = 90409  
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
            AND   [Status] <> '5'  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 90410  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD DID FAIL'  
               GOTO RollBackTran  
            END  
  
            UPDATE dbo.Orders WITH (ROWLOCK) SET   
               SOStatus = 'PENDPACK',   
               Trafficcop = NULL,      -- (james01)  
               EditDate = GETDATE(),   -- (james01)  
               EditWho = sUSER_sNAME() -- (james01)  
            WHERE StorerKey = @cStorerkey  
            AND   LoadKey = @cLoadKey  
            AND   SOStatus <> '5'   -- sostatus become 5 after interface come back  
            AND   [Status] = '5'  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 90411  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PPACK FAIL'  
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
               SET @nErrNo = 90412  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD DID FAIL'  
               GOTO RollBackTran  
            END  
           
            UPDATE dbo.Orders WITH (ROWLOCK) SET   
               SOStatus = 'PENDPACK',   
               Trafficcop = NULL,      -- (james01)  
               EditDate = GETDATE(),   -- (james01)  
               EditWho = sUSER_sNAME() -- (james01)  
            WHERE StorerKey = @cStorerkey  
            AND   OrderKey = @cOrderKey  
            AND   SOStatus <> '5'   -- sostatus become 5 after interface come back  
            AND   [Status] = '5'  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 90413  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PPACK FAIL'  
               GOTO RollBackTran  
            END  
         END  
      END  
   END  

   SET @d_step4 = GETDATE() - @d_step4 -- (james_tune)  
   SET @d_step5 = GETDATE()  

   IF @cActionFlag = 'D'  
   BEGIN  
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)   
                     WHERE DropID = @cDropID)  
      BEGIN  
         SET @nErrNo = 90414  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROPID'  
         GOTO RollBackTran  
      END  
        
      DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT ChildId 
      FROM dbo.DropIDDetail WITH (NOLOCK) 
      WHERE DropID = @cDropID   
      OPEN CUR_DEL
      FETCH NEXT FROM CUR_DEL INTO @cChildID
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE FROM dbo.DropIDDetail    
         WHERE DropID = @cDropID   
         AND   ChildID = @cChildID

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 90402  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DDTL FAIL'  
            CLOSE CUR_DEL
            DEALLOCATE CUR_DEL
            GOTO RollBackTran  
         END  

         FETCH NEXT FROM CUR_DEL INTO @cChildID
      END
      CLOSE CUR_DEL
      DEALLOCATE CUR_DEL
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 90415  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DDTL FAIL'  
         GOTO RollBackTran  
      END  
  
      DELETE FROM dbo.DropID   
      WHERE DropID = @cDropID   
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 90416  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DID FAIL'  
         GOTO RollBackTran  
      END  
   END  

   SET @d_step5 = GETDATE() - @d_step5 -- (james_tune)  

   SET @c_Col1 = @cPickSlipNo  
   SET @c_Col2 = @cDropID  
   SET @c_Col3 = @cSKU  
   SET @c_Col4 = @cActionFlag  
   SET @c_Col5 = @cUserName     
   SET @d_endtime = GETDATE()  
--   INSERT INTO TraceInfo VALUES  
--         (RTRIM(@c_TraceName), @d_starttime, @d_endtime  
--         ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)  
--         ,CONVERT(CHAR(12),@d_step1,114)  
--         ,CONVERT(CHAR(12),@d_step2,114)  
--         ,CONVERT(CHAR(12),@d_step3,114)  
--         ,CONVERT(CHAR(12),@d_step4,114)  
--         ,CONVERT(CHAR(12),@d_step5,114)  
--             ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)  

   SET @d_step1 = NULL  
   SET @d_step2 = NULL  
   SET @d_step3 = NULL  
   SET @d_step4 = NULL  
   SET @d_step5 = NULL  
   SET @c_Col1  = ''  
   SET @c_Col2  = ''  
   SET @c_Col3  = ''  
   SET @c_Col4  = ''  
   SET @c_Col5  = ''  
      
   GOTO Quit  
  
   RollBackTran:  
      ROLLBACK TRAN rdt_UA_DropID01  
  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN rdt_UA_DropID01  
  
END

GO