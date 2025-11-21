SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1628ExtUpd04                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Reset pickdetail.caseid for short pick. Delete packheader   */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 2021-04-08   1.0  James       WMS-16756 - Created                    */  
/************************************************************************/

CREATE PROC [RDT].[rdt_1628ExtUpd04] (
   @nMobile                   INT,
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15),
   @cWaveKey                  NVARCHAR( 10),
   @cLoadKey                  NVARCHAR( 10),
   @cOrderKey                 NVARCHAR( 10),
   @cLoc                      NVARCHAR( 10),
   @cDropID                   NVARCHAR( 20),
   @cSKU                      NVARCHAR( 20),
   @nQty                      INT,
   @nErrNo                    INT               OUTPUT,
   @cErrMsg                   NVARCHAR( 20)     OUTPUT   -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @cLot             NVARCHAR( 10), 
            @cOption          NVARCHAR( 20), 
            @cPickDetailKey   NVARCHAR( 10), 
            @cLottable02      NVARCHAR( 18),
            @dLottable04      DATETIME,
            @nTranCount       INT,  
            @cDocType         NVARCHAR( 10),
            @cTempPickSlipNo  NVARCHAR( 10),
            @cTempOrderKey    NVARCHAR( 10)

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1628ExtUpd04

   SELECT @cOption = I_Field01,  
          @cLot = V_LOT,
          @cLoadKey = V_LoadKey  
   FROM rdt.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
   

   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 9  
      BEGIN  
         IF @cOption = '1'  
         BEGIN  
            SELECT @cLottable02 = Lottable02,   
                   @dLottable04 = @dLottable04  
            FROM dbo.LOTAttribute WITH (NOLOCK)  
            WHERE LOT = @cLot  
  
            -- Update pickdetail to short pick status for same sku + loc after screen perform short pick  
            DECLARE CUR_SP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
            SELECT PickDetailKey FROM dbo.PickDetail PD WITH (NOLOCK)  
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)  
            JOIN LOTAttribute LA WITH (NOLOCK) ON ( PD.LOT = LA.LOT)  
            WHERE LPD.LoadKey = @cLoadKey  
            AND   PD.SKU = @cSKU  
            AND   PD.LOC = @cLOC  
            AND   PD.Status = '0'  
            AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))  
            AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))  
            OPEN CUR_SP  
            FETCH NEXT FROM CUR_SP INTO @cPickDetailKey  
            WHILE @@FETCH_STATUS <> -1  
            BEGIN  
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
                  [Status] = '4'  
               WHERE PickDetailKey = @cPickDetailKey  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 166451  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ShortPICK Fail'  
                  CLOSE CUR_SP  
                  DEALLOCATE CUR_SP  
                  GOTO RollBackTran  
               END    
  
               FETCH NEXT FROM CUR_SP INTO @cPickDetailKey  
            END  
            CLOSE CUR_SP  
            DEALLOCATE CUR_SP  
  
            -- Clear case id for those short pick pickdetail line  
            DECLARE CUR_SP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
            SELECT PickDetailKey FROM dbo.PickDetail PD WITH (NOLOCK)  
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)  
            JOIN LOTAttribute LA WITH (NOLOCK) ON ( PD.LOT = LA.LOT)  
            WHERE LPD.LoadKey = @cLoadKey  
            AND   PD.SKU = @cSKU  
            AND   PD.LOC = @cLOC  
            AND   PD.Status = '4'  
            AND   PD.CaseID <> ''  
            AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))  
            AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))  
            OPEN CUR_SP  
            FETCH NEXT FROM CUR_SP INTO @cPickDetailKey  
            WHILE @@FETCH_STATUS <> -1  
            BEGIN  
               INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2) VALUES ('1628UPD', GETDATE(), @cPickDetailKey, @cLot)  
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
                  CaseID = '',  
                  TrafficCop = NULL  
               WHERE PickDetailKey = @cPickDetailKey  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 166452  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ShortPICK Fail'  
                  CLOSE CUR_SP  
                  DEALLOCATE CUR_SP  
                  GOTO RollBackTran  
               END    
  
               FETCH NEXT FROM CUR_SP INTO @cPickDetailKey  
            END  
            CLOSE CUR_SP  
            DEALLOCATE CUR_SP  
         END  
      END  
   END  
   
   IF @nStep = 10
   BEGIN
      IF @nInputKey IN (0, 1)
      BEGIN
         SELECT TOP 1 @cDocType = DocType
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey
         ORDER BY 1
   
         IF @cDocType = 'E'
         BEGIN
            DECLARE @curLoop CURSOR
            SET @curLoop = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT OrderKey FROM dbo.ORDERS WITH (NOLOCK)
            WHERE LoadKey = @cLoadKey
            OPEN @curLoop
            FETCH NEXT FROM @curLoop INTO @cTempOrderKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SELECT @cTempPickSlipNo = PickHeaderKey
               FROM dbo.PICKHEADER WITH (NOLOCK)
               WHERE OrderKey = @cTempOrderKey
         
               IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                           WHERE PickSlipNo = @cTempPickSlipNo
                           AND   [Status] = '9')
               BEGIN
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 166453
                     SET @cErrMsg = rdt.rdtgetmessage( 69348, @cLangCode, 'DSP') --'Ecom Pack Cfm'
                     GOTO RollBackTran
                  END
               END
               ELSE
               BEGIN
                  DELETE FROM dbo.PackHeader WHERE PickSlipNo = @cTempPickSlipNo
            
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 166454
                     SET @cErrMsg = rdt.rdtgetmessage( 69348, @cLangCode, 'DSP') --'Del PackH Fail'
                     GOTO RollBackTran
                  END
               END
         
               IF EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
                           WHERE PickSlipNo = @cTempPickSlipNo 
                           AND   ISNULL( ScanOutDate, '') <> '')
               BEGIN
                  UPDATE dbo.PickingInfo SET 
                     ScanOutDate = NULL
                  WHERE PickSlipNo = @cTempPickSlipNo

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 166455
                     SET @cErrMsg = rdt.rdtgetmessage( 69348, @cLangCode, 'DSP') --'Del Pickf Fail'
                     GOTO RollBackTran
                  END
               END
         
               FETCH NEXT FROM @curLoop INTO @cTempOrderKey
            END
         END
      END
   END

   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_1628ExtUpd04  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

   Quit_WithoutTran:
END

GO