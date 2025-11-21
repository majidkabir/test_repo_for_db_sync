SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_HnMExtendedUpd01                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: HnM print dummy pickslip                                    */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 09-05-2014  1.0  James       SOS304353 - Created                     */
/************************************************************************/

CREATE PROC [RDT].[rdt_HnMExtendedUpd01] (
   @nMobile                   INT,
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15),
   @cWaveKey                  NVARCHAR( 10),
   @cLoadKey                  NVARCHAR( 10),
   @cOrderKey                 NVARCHAR( 10),
   @bSuccess                  INT               OUTPUT, 
   @nErrNo                    INT               OUTPUT,
   @cErrMsg                   NVARCHAR( 20)     OUTPUT   -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @cPickSlipNo      NVARCHAR( 10), 
            @cPSNO            NVARCHAR( 10), 
            @nTranCount       INT  

   SET @bSuccess = 1

   IF @nFunc NOT IN (1620, 1621)
      GOTO Quit_WithoutTran

   IF ISNULL( @cOrderKey, '') = ''
   BEGIN
      SET @bSuccess = 0
      SET @cErrMsg = 'INVALID ORDERKEY'
      GOTO Quit_WithoutTran
   END

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_HnMExtendedUpd01

   -- 1. Check if pickslip printed
   -- 2. if printed then check if same pickslip created for packheader
   -- 3. if exists go to quit
   -- 4. if not exists then check if packheader created for this orders
   -- 5. if created then get pickslipno from packheader
   -- 6. if not created then gen new pickslipno
   
   -- Get PickSlipNo (PickHeader)  
   SET @cPickSlipNo = ''  
   SELECT @cPickSlipNo = PickHeaderKey  
   FROM dbo.PickHeader WITH (NOLOCK)  
   WHERE OrderKey = @cOrderKey  

   -- PackHeader  
   IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)  
   BEGIN  
      -- Get PickSlipNo (PackHeader)  
      SET @cPSNO = ''  
      SELECT @cPSNO = PickSlipNo  
      FROM dbo.PackHeader WITH (NOLOCK)  
      WHERE LoadKey = @cLoadKey  
         AND OrderKey = @cOrderKey  

      IF @cPSNO <> ''  
         SET @cPickSlipNo = @cPSNO  
      ELSE  
      BEGIN  
         -- New PickSlipNo  
         IF @cPickSlipNo = ''  
         BEGIN  
            EXECUTE nspg_GetKey  
               'PICKSLIP',  
               9,  
               @cPickSlipNo OUTPUT,  
               @bsuccess    OUTPUT,  
               @nErrNo      OUTPUT,  
               @cErrMsg     OUTPUT  
            IF @@ERROR <> 0  
            BEGIN  
               SET @bSuccess = 0
               SET @cErrMsg = 'GET KEY Fail'
               GOTO RollBackTran  
            END  

            SET @cPickSlipNo = 'P' + RTRIM( @cPickSlipNo)  

            INSERT INTO dbo.PICKHEADER    
               (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone)    
            VALUES    
               (@cPickslipno, '', @cOrderKey, '0', 'D')    
       
            IF @@ERROR <> 0    
            BEGIN    
               SET @bSuccess = 0
               SET @cErrMsg = 'PRINT PS Fail'
               GOTO RollBackTran  
            END    
         END  
      END
   END

   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_HnMExtendedUpd01  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

   Quit_WithoutTran:
END

GO