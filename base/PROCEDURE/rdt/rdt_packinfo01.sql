SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Copyright: IDS                                                       */  
/* Purpose: Customize Update SP for rdtfnc_PackInfo                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2012-11-21 1.0  ChewKP     SOS#260734                                */  
/* 2013-10-28 1.1  Shong      Performance Tuning                        */  
/* 2016-12-06 1.2  Ung        WMS-459 Change parameters                 */  
/* 2020-10-01 1.3  LZG        INC1234549 - Exclude NULL CartonType(ZG01)*/
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_PackInfo01] (  
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nInputKey      INT,  
   @cStorerKey     NVARCHAR( 15),  
   @cFacility      NVARCHAR( 5),  
   @cDropID        NVARCHAR( 20),  
   @cLabelNo       NVARCHAR( 20),  
   @cOrderKey      NVARCHAR( 10),  
   @cCartonNo      NVARCHAR( 5),  
   @cPickSlipNo    NVARCHAR( 10),  
   @cCartonType    NVARCHAR( 10),  
   @cCube          NVARCHAR( 10),  
   @cWeight        NVARCHAR( 10),  
   @cLength        NVARCHAR( 10),  
   @cWidth         NVARCHAR( 10),  
   @cHeight        NVARCHAR( 10),  
   @cRefNo         NVARCHAR( 20),  
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   -- Misc variable  
   DECLARE  
       @nCartonCount            int  
     , @nSumPackInfoCartonNo    int  
     , @nSumPackDetailCartonNo  int  
     , @nSumTotalCube           Float  
     , @nCount                  int  
     , @nSumTotalWeight         Float  
  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
  
   IF @nFunc = 921 -- PackInfo  
   BEGIN  
      IF @nStep = 2 -- Info  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            SET @nSumPackInfoCartonNo = 0  
            SET @nSumPackDetailCartonNo = 0  
  
            SELECT @nSumPackInfoCartonNo = ISNULL(COUNT(DISTINCT CartonNo) ,0)  
            FROM dbo.PackInfo WITH (NOLOCK)  
            WHERE PickSlipNo = @cPickSlipNo  
  
            SELECT @nSumPackDetailCartonNo = ISNULL(COUNT(DISTINCT CartonNo),0)  
            FROM dbo.PackDetail WITH (NOLOCK)  
            WHERE PickSlipNo = @cPickSlipNo  
            AND StorerKey = @cStorerKey  
  
            IF @nSumPackInfoCartonNo <> 0 AND  @nSumPackDetailCartonNo <> 0  
            BEGIN  
               -- Check if All Carton Scanned  
               IF @nSumPackInfoCartonNo = @nSumPackDetailCartonNo  
               BEGIN  
                  SELECT  
                       @nSumTotalCube   = ISNULL(SUM([Cube]),0)  
                     , @nSumTotalWeight = ISNULL(SUM(Weight),0)  
                  FROM dbo.PackINFO WITH (NOLOCK)  
                  WHERE PickSlipNo = @cPickSlipNo  
  
                  BEGIN TRAN  
                  SAVE TRAN PackInfo_Tran  
  
                  UPDATE dbo.PackHeader  
                  SET   TotCtnCube   = @nSumTotalCube  
                      , TotCtnWeight = @nSumTotalWeight  
                      , EditDate = GETDATE()  
                      , EditWho = SUSER_SNAME()  
                  WHERE PickSlipNo = @cPickSlipNo  
                  AND StorerKey = @cStorerKey  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                      SET @nErrNo = 78051  
                      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackDetailFail'  
                      GOTO RollBackTran  
                  END  
  
                  SET @nCount = 1  
  
                  DECLARE CursorPHUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                     SELECT CartonType, Count(CartonNo)  
                     FROM dbo.PackInfo  
                     WHERE PickSlipNo = @cPickSlipNo  
                     AND ISNULL(CartonType, '') <> ''          -- ZG01
                     Group By CartonType  
                  OPEN CursorPHUpdate  
                  FETCH NEXT FROM CursorPHUpdate INTO @cCartonType , @nCartonCount  
                  WHILE @@FETCH_STATUS <> -1  
                  BEGIN  
                     IF @nCount = 1  
                     BEGIN  
                        Update dbo.PackHeader WITH (ROWLOCK)  
                        SET CtnTyp1 = @cCartonType  
                          , CtnCnt1 = @nCartonCount  
                          , EditDate = GETDATE()  
                          , EditWho = SUSER_SNAME()  
                        WHERE PickSlipNo = @cPickSlipNo  
                        AND StorerKey = @cStorerKey  
  
                        IF @@ERROR <> 0  
                        BEGIN  
                         SET @nErrNo = 78052  
                         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackHeaderFail'  
                         GOTO RollBackTran  
                        END  
                     END  
  
                     IF @nCount = 2  
                     BEGIN  
                        Update dbo.PackHeader WITH (ROWLOCK)  
                        SET CtnTyp2 = @cCartonType  
                          , CtnCnt2 = @nCartonCount  
                          , EditDate = GETDATE()  
                          , EditWho = SUSER_SNAME()  
                        WHERE PickSlipNo = @cPickSlipNo  
                        AND StorerKey = @cStorerKey  
  
                        IF @@ERROR <> 0  
                        BEGIN  
                         SET @nErrNo = 78053  
                         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackHeaderFail'  
                         GOTO RollBackTran  
                        END  
                     END  
  
                     IF @nCount = 3  
                     BEGIN  
                        Update dbo.PackHeader WITH (ROWLOCK)  
                        SET CtnTyp3 = @cCartonType  
                          , CtnCnt3 = @nCartonCount  
                          , EditDate = GETDATE()  
                          , EditWho = SUSER_SNAME()  
                        WHERE PickSlipNo = @cPickSlipNo  
                        AND StorerKey = @cStorerKey  
  
                        IF @@ERROR <> 0  
                        BEGIN  
                         SET @nErrNo = 78054  
                         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackHeaderFail'  
                         GOTO RollBackTran  
                        END  
                     END  
  
                     IF @nCount = 4  
                     BEGIN  
                        Update dbo.PackHeader WITH (ROWLOCK)  
                        SET CtnTyp4 = @cCartonType  
                          , CtnCnt4 = @nCartonCount  
                          , EditDate = GETDATE()  
                          , EditWho = SUSER_SNAME()  
                        WHERE PickSlipNo = @cPickSlipNo  
                        AND StorerKey = @cStorerKey  
  
                        IF @@ERROR <> 0  
                        BEGIN  
                         SET @nErrNo = 78055  
                         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackHeaderFail'  
                         GOTO RollBackTran  
                        END  
                     END  
  
                     IF @nCount = 5  
                     BEGIN  
                        Update dbo.PackHeader WITH (ROWLOCK)  
                        SET CtnTyp5 = @cCartonType  
                          , CtnCnt5 = @nCartonCount  
                          , EditDate = GETDATE()  
                          , EditWho = SUSER_SNAME()  
                        WHERE PickSlipNo = @cPickSlipNo  
                        AND StorerKey = @cStorerKey  
  
                        IF @@ERROR <> 0  
                        BEGIN  
                         SET @nErrNo = 78056  
                         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPackHeaderFail'  
                         GOTO RollBackTran  
                        END  
                     END  
  
                     SET @nCount = @nCount + 1  
  
                     FETCH NEXT FROM CursorPHUpdate INTO @cCartonType , @nCartonCount  
                  END  
                  CLOSE CursorPHUpdate  
                  DEALLOCATE CursorPHUpdate  
  
                  SELECT  @cOrderKey = OrderKey  
                  FROM dbo.PickHeader WITH (NOLOCK)  
                  where PickHeaderKey = @cPickSlipNo  
  
                  UPDATE dbo.ORDERS WITH (ROWLOCK)  
                     SET Stop = 'Y'  
                       , EditDate = GETDATE()  
                       , EditWho = SUSER_SNAME()  
                       , TrafficCop = NULL  
                  WHERE OrderKey = @cOrderKey  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 78057  
                     SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdOrderFail'  
                     GOTO RollBackTran  
                  END  
                    
                  COMMIT TRAN PackInfo_Tran  
                  GOTO Quit  
               END  
            END  
         END  
      END  
   END  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN PackInfo_Tran  
Quit:  
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
      COMMIT TRAN PackInfo_Tran  
END  


GO