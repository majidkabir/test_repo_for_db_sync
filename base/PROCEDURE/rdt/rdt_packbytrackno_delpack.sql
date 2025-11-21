SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PackByTrackNo_DelPack                           */
/*                                                                      */
/* Called from: rdtfnc_PackByTrackNo                                    */
/*                                                                      */
/* Purpose: When user choose to abort the packing of the carton, delete */
/*          packheadr, packdetail, packinfo & rdtTrackLog               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-07-13 1.0  James      SOS347381. Created                        */
/* 2016-01-19 1.1  James      SOS353558. Add ExtendedDelPack sp(james01)*/
/* 2018-01-26 1.2  James      Bug fix on QtyMoved (james02)             */
/* 2019-01-16 1.3  James      WMS7499-Del rdtTrackLog by orders(james03)*/
/* 2019-11-20 1.4  James      WMS-11171 Display all error msg           */
/*                            in msgqueue (james01)                     */
/************************************************************************/

CREATE PROC [RDT].[rdt_PackByTrackNo_DelPack] (
   @nMobile       INT,
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT, 
   @nInputKey     INT, 
   @cStorerkey    NVARCHAR( 15), 
   @cOrderKey     NVARCHAR( 10), 
   @cPickSlipNo   NVARCHAR( 10), 
   @cTrackNo      NVARCHAR( 20), 
   @cSKU          NVARCHAR( 20), 
   @nCartonNo     INT,
   @cOption       NVARCHAR( 1), 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount           INT, 
           @nTCartonNo           INT, 
           @nRowRef              INT, 
           @cTLabelNo            NVARCHAR( 20), 
           @cTLabelLine          NVARCHAR( 5), 
           @cUserName            NVARCHAR( 18), 
           @cPickDetailKey       NVARCHAR( 10), 
           @cPackSwapLot_SP      NVARCHAR( 20),
           @cExtendedDelPackSP   NVARCHAR( 20),        -- (james01)
           @cSQL                 NVARCHAR( 1000),      -- (james01)
           @cSQLParam            NVARCHAR( 1000)       -- (james01)

   DECLARE @cErrMsg1       NVARCHAR( 20), 
           @cErrMsg2       NVARCHAR( 20), 
           @cErrMsg3       NVARCHAR( 20), 
           @cErrMsg4       NVARCHAR( 20), 
           @cErrMsg5       NVARCHAR( 20) 
   
   DECLARE @nMsgQErrNo     INT
   DECLARE @nMsgQErrMsg    NVARCHAR( 20)

   SET @nErrNo = 0
   SELECT @cUserName = UserName FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_PackByTrackNo_DelPack

   IF ISNULL( @cPickSlipNo, '') = ''
      SELECT @cPickSlipno = ISNULL(PickheaderKey,'')
      FROM   dbo.PickHeader WITH (NOLOCK)
      WHERE  OrderKey = @cOrderKey            

   IF ISNULL( @cPickSlipNo, '') = ''
   BEGIN
      SET @nErrNo = 55451
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No PickSlipNo
      GOTO Quit
   END
            
   -- 1. Delete from packdetail
   DECLARE CUR_DEL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT CartonNo, LabelNo, LabelLine 
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
   OPEN CUR_DEL
   FETCH NEXT FROM CUR_DEL INTO @nTCartonNo, @cTLabelNo, @cTLabelLine
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DELETE FROM dbo.PackDetail WITH (ROWLOCK) 
      WHERE PickSlipNo = @cPickSlipNo
      AND   CartonNo = @nTCartonNo
      AND   LabelNo = @cTLabelNo
      AND   LabelLine = @cTLabelLine

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 55452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Del PKDtl Fail
         CLOSE CUR_DEL
         DEALLOCATE CUR_DEL                           
         GOTO RollBackTran                  
      END
      
      FETCH NEXT FROM CUR_DEL INTO @nTCartonNo, @cTLabelNo, @cTLabelLine
   END
   CLOSE CUR_DEL
   DEALLOCATE CUR_DEL   

   -- 2. Delete from packheader
   IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
   BEGIN
      DELETE FROM dbo.PackHeader WITH (ROWLOCK) WHERE PickSlipNo = @cPickSlipNo
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 55453
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Del PKHdr Fail               
         GOTO RollBackTran
      END
   END

   -- 3. Delete from packinfo
   IF EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
   BEGIN
      DELETE FROM dbo.PackInfo WITH (ROWLOCK) WHERE PickSlipNo = @cPickSlipNo
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 55454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Del PKInf Fail               
         GOTO RollBackTran
      END
   END

   -- 4. Clear PickDetail.QtyMoved if config turn on
   SET @cPackSwapLot_SP = rdt.RDTGetConfig( @nFunc, 'PackSwapLot_SP', @cStorerkey)

   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPackSwapLot_SP AND type = 'P')
   BEGIN
      DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT PD.PickDetailKey FROM PickDetail PD WITH (NOLOCK) 
      WHERE PD.OrderKey = @cOrderKey
      AND   PD.QtyMoved > 0   -- (james02)
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE PickDetail WITH (ROWLOCK) SET 
            QtyMoved = 0, 
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 55455
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Del PKInf Fail               
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD                           
            GOTO RollBackTran                  
         END
         
         FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD      
   END
   
   -- 5. Delete from temp table
   DECLARE CUR_DEL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT RowRef FROM RDT.rdtTrackLog WITH (NOLOCK) 
   WHERE OrderKey = @cOrderKey   -- (james03)
   OPEN CUR_DEL
   FETCH NEXT FROM CUR_DEL INTO @nRowRef
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DELETE FROM RDT.rdtTrackLog WITH (ROWLOCK) 
      WHERE RowRef = @nRowRef

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 55456
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Del PKInf Fail               
         CLOSE CUR_DEL
         DEALLOCATE CUR_DEL                           
         GOTO RollBackTran                  
      END
      
      FETCH NEXT FROM CUR_DEL INTO @nRowRef
   END
   CLOSE CUR_DEL
   DEALLOCATE CUR_DEL   

   -- (james01)
   -- Misc clean up
   SET @nErrNo = 0
   SET @cExtendedDelPackSP = rdt.RDTGetConfig( @nFunc, 'ExtendedDelPackSP', @cStorerKey)
   IF @cExtendedDelPackSP NOT IN ('0', '')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedDelPackSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo, @cOption,' +
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

      SET @cSQLParam =
         '@nMobile                   INT,           ' +
         '@nFunc                     INT,           ' +
         '@cLangCode                 NVARCHAR( 3),  ' +
         '@nStep                     INT,           ' +
         '@nInputKey                 INT,           ' +
         '@cStorerkey                NVARCHAR( 15), ' +
         '@cOrderKey                 NVARCHAR( 10), ' +
         '@cPickSlipNo               NVARCHAR( 10), ' +
         '@cTrackNo                  NVARCHAR( 20), ' +
         '@cSKU                      NVARCHAR( 20), ' +
         '@nCartonNo                 INT,           ' +
         '@cOption                   NVARCHAR( 1),  ' +
         '@nErrNo                    INT           OUTPUT,  ' +
         '@cErrMsg                   NVARCHAR( 20) OUTPUT   '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo, @cOption,
            @nErrNo OUTPUT, @cErrMsg OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
         GOTO RollBackTran                  
      END
   END
   
   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_PackByTrackNo_DelPack  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN rdt_PackByTrackNo_DelPack

   Fail:
   IF rdt.RDTGetConfig( @nFunc, 'ShowErrMsgInNewScn', @cStorerkey) = '1'
   BEGIN
      IF @nErrNo > 0 AND @nErrNo <> 1  -- Not from prev msgqueue
      BEGIN
         SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nMsgQErrNo OUTPUT, @nMsgQErrMsg OUTPUT, @cErrMsg1
         IF @nMsgQErrNo = 1
            SET @cErrMsg1 = ''
      END
   END

GO