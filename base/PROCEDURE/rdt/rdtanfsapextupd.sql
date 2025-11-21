SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdtANFSAPExtUpd                                     */    
/* Purpose: Print Label via BarTender and Update DropID.LabelPrinted to */    
/*          'Y' after User closed carton at Sort and Pack module        */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date         Author    Ver.  Purposes                                */    
/* 2014-04-08   Chee      1.0   SOS#307177 Created                      */    
/* 2014-05-26   Chee      1.1   Add UserName filter if it is DCToDC     */    
/*                              order                                   */    
/*                              Error if blank labelno (Chee01)         */    
/* 2014-06-16   Chee      1.2   Add rdt.StorerConfig -                  */    
/*                              GenLabelByUserForDCToStoreOdr (Chee02)  */    
/* 2014-07-24   Chee      1.3   Change @nFunc to 547 (Chee03)           */   
/* 2020-04-21   YeeKung   1.4   WMS-12853 Add @cFunc 542 (yeekung01)    */   
/* 2021-11-18   James     1.5   WMS-17829 Reassign labelno when close   */
/*                              carton (james01)                        */
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdtANFSAPExtUpd]    
    @nMobile         INT     
   ,@nFunc           INT     
   ,@cLangCode       NVARCHAR( 3)     
   ,@nStep           INT     
   ,@cUserName       NVARCHAR( 18)    
   ,@cFacility       NVARCHAR(  5)    
   ,@cStorerKey      NVARCHAR( 15)    
   ,@cLabelPrinter   NVARCHAR( 10)    
   ,@cCloseCartonID  NVARCHAR( 20)    
   ,@cLoadKey        NVARCHAR( 10)    
   ,@cLabelNo        NVARCHAR( 20)    
   ,@nErrNo          INT           OUTPUT     
   ,@cErrMsg         NVARCHAR( 20) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE     
      @cExecStatements                NVARCHAR(4000),          
      @cExecArguments                 NVARCHAR(4000),    
      @cRDTBartenderSP                NVARCHAR(40),    
      @cOrderType                     NVARCHAR(20),  -- (Chee01)    
      @cGenLabelByUserForDCToStoreOdr NVARCHAR(20),   -- (Chee02)  
      @cShipLabelPrint                NVARCHAR(20)  

   DECLARE @nUpdPack       INT = 0
   DECLARE @nUpdNotes      INT = 0
   DECLARE @nMixCarton     INT
   DECLARE @nTempCartonNo  INT
   DECLARE @cTempLabelNo   NVARCHAR( 20)
   DECLARE @cTempLabelLine NVARCHAR( 5)
   DECLARE @cTempPickDetailKey   NVARCHAR( 10)
   DECLARE @cUserDefine02  NVARCHAR( 18)
   DECLARE @cUserDefine09  NVARCHAR( 18)
   DECLARE @cTempOrderKey  NVARCHAR( 10)
   DECLARE @cTempOrderLineNumber NVARCHAR( 5)
   DECLARE @cChildLabelNo  NVARCHAR( 20)
   DECLARE @nCartonNo      INT
   DECLARE @cNewLabelNo    NVARCHAR( 20)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nTranCount     INT
   DECLARE @nCount         INT
   DECLARE @bSuccess       INT
   DECLARE @curPack        CURSOR
   DECLARE @curPick        CURSOR
   DECLARE @tMixCarton TABLE ( UserDefine NVARCHAR( 36))
   DECLARE @cPrevUserDefine09 NVARCHAR( 18) = ''
   
   IF @nFunc  in( 542, 547) --540    
   BEGIN    
  
      -- (Chee01)    
      IF ISNULL(@cLabelNo, '') = ''    
      BEGIN    
          SET @nErrNo = 86703      
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --EmptyLabelNo             
          GOTO Quit     
      END    

      -- (james01)
      -- Handling transaction            
      SET @nTranCount = @@TRANCOUNT            
      BEGIN TRAN  -- Begin our own transaction            
      SAVE TRAN rdtANFSAPExtUpd -- For rollback or commit only our own transaction            
      
      SELECT @cPickSlipNo = PickSlipNo
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE LoadKey = @cLoadKey
      
      SELECT @nCartonNo = CartonNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND   LabelNo = @cLabelNo
      
      DELETE FROM @tMixCarton
      INSERT INTO @tMixCarton (UserDefine)
      SELECT OD.userdefine02 + OD.userdefine09
      FROM dbo.PICKDETAIL PD WITH (NOLOCK)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      WHERE PD.Storerkey = @cStorerKey
      AND   PD.CaseID = @cLabelNo
      AND   PD.[Status] = '5'
      AND   LPD.LoadKey = @cLoadKey
      GROUP BY OD.userdefine02 , OD.userdefine09
         
      SELECT @nCount = COUNT(1) FROM @tMixCarton
         
      IF @nCount = 1
         SET @nMixCarton = 0
      ELSE
         SET @nMixCarton = 1

      SELECT 
         @cUserDefine02 = MAX( OD.UserDefine02),
         @cUserDefine09 = MAX( OD.UserDefine09)
      FROM dbo.PICKDETAIL PD WITH (NOLOCK)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      WHERE PD.Storerkey = @cStorerKey
      AND   PD.CaseID = @cLabelNo
      AND   PD.[Status] = '5'
      AND   LPD.LoadKey = @cLoadKey
      GROUP BY OD.userdefine02 , OD.userdefine09

      SET @cNewLabelNo = ''
      SET @cChildLabelNo = ''
            
      IF @nMixCarton = 0
      BEGIN
         IF EXISTS ( SELECT 1 
                     FROM dbo.STORER WITH (NOLOCK)
                     WHERE StorerKey = @cUserDefine09
                     AND   SUSR1 = 'C')
         BEGIN
            SET @nErrNo = 0
            SET @cNewLabelNo = 'x' -- Pass in random value to avoid error      
            -- Generate ANF UCC Label No          
            EXEC isp_GLBL03                   
            @c_PickSlipNo  = @cPickSlipNo,                 
            @n_CartonNo    = @nCartonNo,      
            @c_LabelNo     = @cNewLabelNo    OUTPUT,      
            @cStorerKey    = @cStorerKey,      
            @cDeviceProfileLogKey = '',      
            @cConsigneeKey = @cUserDefine09,      
            @b_success     = @bSuccess   OUTPUT,                  
            @n_err         = @nErrNo     OUTPUT,                  
            @c_errmsg      = @cErrMsg    OUTPUT       
         END
         ELSE
            SET @cNewLabelNo = @cLabelNo

         SET @nUpdPack = 1
         SET @nUpdNotes = 0
      END

      IF @nMixCarton = 1
      BEGIN
         IF EXISTS ( SELECT 1 
                     FROM dbo.STORER WITH (NOLOCK)
                     WHERE StorerKey = @cUserDefine02
                     AND   SUSR1 = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cNewLabelNo = 'x' -- Pass in random value to avoid error      
            -- Generate ANF UCC Label No          
            EXEC isp_GLBL03                   
            @c_PickSlipNo  = @cPickSlipNo,                 
            @n_CartonNo    = @nCartonNo,      
            @c_LabelNo     = @cNewLabelNo    OUTPUT,      
            @cStorerKey    = @cStorerKey,      
            @cDeviceProfileLogKey = '',      
            @cConsigneeKey = @cUserDefine02,      
            @b_success     = @bSuccess   OUTPUT,                  
            @n_err         = @nErrNo     OUTPUT,                  
            @c_errmsg      = @cErrMsg    OUTPUT       

            SET @nUpdPack = 1
            SET @nUpdNotes = 0
         END
         ELSE
            SET @cNewLabelNo = @cLabelNo
                  
         IF EXISTS ( SELECT 1 
                     FROM dbo.STORER WITH (NOLOCK)
                     WHERE StorerKey = @cUserDefine09
                     AND   SUSR1 = 'C')
         BEGIN
            SET @nUpdNotes = 1
            SET @nErrNo = 0
            SET @cChildLabelNo = 'x' -- Pass in random value to avoid error      
            -- Generate ANF UCC Label No          
            EXEC isp_GLBL03                   
            @c_PickSlipNo  = @cPickSlipNo,                 
            @n_CartonNo    = @nCartonNo,      
            @c_LabelNo     = @cChildLabelNo  OUTPUT,      
            @cStorerKey    = @cStorerKey,      
            @cDeviceProfileLogKey = '',      
            @cConsigneeKey = @cUserDefine09,      
            @b_success     = @bSuccess   OUTPUT,                  
            @n_err         = @nErrNo     OUTPUT,                  
            @c_errmsg      = @cErrMsg    OUTPUT       
         END           

         SET @nUpdPack = 1
         SET @nUpdNotes = 1
      END

      IF @cNewLabelNo = '' OR @nErrNo <> 0
      BEGIN      
         SET @nErrNo = 86628  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReLabelNo Fail 
         GOTO RollBackTran   
      END 

      IF @nUpdPack = 1
      BEGIN
         DECLARE @curUpdPack  CURSOR
         SET @curUpdPack = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT CartonNo, LabelNo, LabelLine
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   LabelNo = @cLabelNo
         OPEN @curUpdPack
         FETCH NEXT FROM @curUpdPack INTO @nTempCartonNo, @cTempLabelNo, @cTempLabelLine
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PackDetail SET
               LabelNo = @cNewLabelNo, 
               EditWho = SUSER_SNAME(), 
               EditDate = GETDATE()
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nTempCartonNo
            AND   LabelNo = @cTempLabelNo
            AND   LabelLine = @cTempLabelLine
               
            IF @@ERROR <> 0
            BEGIN      
               SET @nErrNo = 86629  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReLabelNo Fail 
               GOTO RollBackTran   
            END 
               
            FETCH NEXT FROM @curUpdPack INTO @nTempCartonNo, @cTempLabelNo, @cTempLabelLine
         END
         
         DECLARE @curUpdPick  CURSOR
         SET @curUpdPick = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
         WHERE lpd.LoadKey = @cLoadKey
         AND   PD.[Status] = '5'
         AND   PD.CaseID = @cLabelNo
         ORDER BY PD.OrderKey, PD.OrderLineNumber, PD.PickDetailKey
         OPEN @curUpdPick
         FETCH NEXT FROM @curUpdPick INTO @cTempPickDetailKey, @cTempOrderKey, @cTempOrderLineNumber
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @nUpdNotes = 1
            BEGIN
               SELECT @cUserDefine09 = UserDefine09 
               FROM dbo.ORDERDETAIL WITH (NOLOCK)
               WHERE OrderKey = @cTempOrderKey
               AND   OrderLineNumber = @cTempOrderLineNumber

               IF ISNULL( @cUserDefine09, '') <> ''
               BEGIN
                  IF @cPrevUserDefine09 <> @cUserDefine09
                  BEGIN
                     IF EXISTS ( SELECT 1 
                                 FROM dbo.STORER WITH (NOLOCK)
                                 WHERE StorerKey = @cUserDefine09
                                 AND   SUSR1 = 'C')
                     BEGIN
                        SET @nErrNo = 0
                        SET @cChildLabelNo = 'x' -- Pass in random value to avoid error      
                        -- Generate ANF UCC Label No          
                        EXEC isp_GLBL03                   
                        @c_PickSlipNo  = @cPickSlipNo,                 
                        @n_CartonNo    = @nCartonNo,      
                        @c_LabelNo     = @cChildLabelNo  OUTPUT,      
                        @cStorerKey    = @cStorerKey,      
                        @cDeviceProfileLogKey = '',      
                        @cConsigneeKey = @cUserDefine09,      
                        @b_success     = @bSuccess   OUTPUT,                  
                        @n_err         = @nErrNo     OUTPUT,                  
                        @c_errmsg      = @cErrMsg    OUTPUT       
                     END
                     ELSE
                        SET @cChildLabelNo = NULL
                  END
                     
                  UPDATE dbo.PickDetail SET
                     CaseID = @cNewLabelNo,
                     Notes = @cChildLabelNo,
                     EditWho = SUSER_SNAME(), 
                     EditDate = GETDATE()
                  WHERE PickDetailKey = @cTempPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN      
                     SET @nErrNo = 86630  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReLabelNo Fail 
                     GOTO RollBackTran   
                  END 
                  
                  SET @cPrevUserDefine09 = @cUserDefine09
               END
               ELSE
               BEGIN
                  UPDATE dbo.PickDetail SET
                     CaseID = @cNewLabelNo,
                     EditWho = SUSER_SNAME(), 
                     EditDate = GETDATE()
                  WHERE PickDetailKey = @cTempPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN      
                     SET @nErrNo = 86630  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReLabelNo Fail 
                     GOTO RollBackTran   
                  END 
               END
            END
            ELSE
            BEGIN
               UPDATE dbo.PickDetail SET
                  CaseID = @cNewLabelNo,
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE()
               WHERE PickDetailKey = @cTempPickDetailKey

               IF @@ERROR <> 0
               BEGIN      
                  SET @nErrNo = 86630  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReLabelNo Fail 
                  GOTO RollBackTran   
               END             
            END
            FETCH NEXT FROM @curUpdPick INTO @cTempPickDetailKey, @cTempOrderKey, @cTempOrderLineNumber
         END
      END
      
      COMMIT TRAN rdtANFSAPExtUpd

      GOTO Commit_Tran

      RollBackTran:
         ROLLBACK TRAN rdtANFSAPExtUpd -- Only rollback change made here
      Commit_Tran:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

      
      -- Get OrderType (Chee01)    
      SELECT @cOrderType = O.[Type]    
      FROM LOADPLANDETAIL LPD WITH (NOLOCK)    
      JOIN ORDERS O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)    
      WHERE LPD.LoadKey = @cLoadKey    
    
      -- Get GenLabelByUserForDCToStoreOdr rdt.StorerConfig (Chee02)    
      SELECT @cGenLabelByUserForDCToStoreOdr = rdt.RDTGetConfig( @nFunc, 'GenLabelByUserForDCToStoreOdr', @cStorerKey)     
    
      IF EXISTS(SELECT 1 FROM dbo.DropID D WITH (NOLOCK)    
                JOIN dbo.DropIDDetail DD WITH (NOLOCK) ON (D.DropID = DD.DropID)     
                WHERE DD.ChildID = @cLabelNo     
                  AND D.DropIDType = '0'     
                  AND D.DropLoc = ''    
                  AND D.LabelPrinted = '0'     
                  AND D.Status = '0'    
                  AND DD.UserDefine02 = CASE WHEN @cOrderType = 'DCToDC'     
                                                  OR (@cOrderType = 'N' AND @cGenLabelByUserForDCToStoreOdr = '1') -- (Chee02)    
                                             THEN @cUserName ELSE DD.UserDefine02 END) -- (Chee01)    
      BEGIN    
    
         /***************************************************/        
         /* Print Label via BarTender                       */        
         /***************************************************/   
         SET @cRDTBartenderSP = ''              
         SET @cRDTBartenderSP = rdt.RDTGetConfig( @nFunc, 'RDTBartenderSP', @cStorerkey)              
                
         IF @cRDTBartenderSP <> ''          
         BEGIN                      
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRDTBartenderSP AND type = 'P')          
            BEGIN     
               SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cRDTBartenderSP) +           
                                       '   @nMobile               ' +            
                                       ' , @nFunc                 ' +                             
                                       ' , @cLangCode             ' +                
                                       ' , @cFacility             ' +                
                                       ' , @cStorerKey            ' +             
                                       ' , @cLabelPrinter         ' +             
                                       ' , @cCloseCartonID        ' +          
                                       ' , @cLoadKey              ' +         
                                       ' , @cLabelNo              ' +          
                                       ' , @cUserName             ' +           
                                       ' , @nErrNo       OUTPUT   ' +          
                                       ' , @cErrMSG      OUTPUT   '           
    
               SET @cExecArguments =     
                          N'@nMobile       int,                    ' +          
                          '@nFunc          int,                    ' +              
                          '@cLangCode      nvarchar(3),            ' +              
                          '@cFacility      nvarchar(5),            ' +              
                          '@cStorerKey     nvarchar(15),           ' +              
                          '@cLabelPrinter  nvarchar(10),           ' +             
                          '@cCloseCartonID nvarchar(20),           ' +              
                          '@cLoadKey       nvarchar(10),           ' +        
                          '@cLabelNo       nvarchar(20),           ' +                                   
                          '@cUserName      nvarchar(18),           ' +          
                          '@nErrNo         int            OUTPUT,  ' +          
                          '@cErrMsg        nvarchar(1024) OUTPUT   '           
    
               EXEC sp_executesql @cExecStatements, @cExecArguments,           
                                     @nMobile                         
                                   , @nFunc                                           
                                   , @cLangCode                              
                                   , @cFacility                 
                                   , @cStorerKey             
                                   , @cLabelPrinter                      
                                   , @cCloseCartonID          
                                   , @cLoadKey        
                                   , @cLabelNo        
                                   , @cUserName          
                                   , @nErrNo       OUTPUT             
                                   , @cErrMSG      OUTPUT             
               
                IF @nErrNo <> 0              
                BEGIN              
                   SET @nErrNo = 86701      
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCarton             
                   GOTO Quit     
                END     
            END               
         END   -- IF @cRDTBartenderSP <> ''      
    
         UPDATE D WITH (ROWLOCK)    
         SET Status = '9', LabelPrinted = 'Y'    
         FROM dbo.DropID D     
         JOIN dbo.DropIDDetail DD ON (D.DropID = DD.DropID)    
         WHERE DD.ChildID = @cLabelNo     
            AND D.DropIDType = '0'     
            AND D.DropLoc = ''    
            AND D.LabelPrinted = '0'     
            AND D.Status = '0'    
            AND DD.UserDefine02 = CASE WHEN @cOrderType = 'DCToDC'     
                                           OR (@cOrderType = 'N' AND @cGenLabelByUserForDCToStoreOdr = '1') -- (Chee02)    
                                      THEN @cUserName ELSE DD.UserDefine02 END -- (Chee01)    
    
         IF @@ERROR <> 0        
         BEGIN        
            SET @nErrNo = 86702       
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDropIDFail'        
            GOTO Quit        
         END        
      END -- IF EXISTS    
   END -- IF @nFunc = 547    
END    
    
Quit:

GO