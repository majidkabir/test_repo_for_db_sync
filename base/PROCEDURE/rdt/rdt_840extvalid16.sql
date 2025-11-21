SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_840ExtValid16                                   */  
/* Copyright      : Maersk                                              */
/*                                                                      */  
/* Purpose: Check whether carton allow to mix sku                       */  
/*                                                                      */  
/* Called By: RDT Pack By Track No                                      */   
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2023-03-31 1.0  James      WMS-22084 Created                         */  
/* 2023-09-13 1.1  James      WMS-23401 Add no mix style check (james01)*/
/* 2024-06-04 1.2  James      WMS-24295 Add printer exists chk (james02)*/  
/* 2024-11-08 1.3  PXL009     FCR-1118 Merged 1.2 from v0 branch        */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_840ExtValid16] (  
   @nMobile                   INT,  
   @nFunc                     INT,  
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT,  
   @nInputKey                 INT,   
   @cStorerkey                NVARCHAR( 15),  
   @cOrderKey                 NVARCHAR( 10),  
   @cPickSlipNo               NVARCHAR( 10),  
   @cTrackNo                  NVARCHAR( 20),  
   @cSKU                      NVARCHAR( 20),  
   @nCartonNo                 INT,  
   @cCtnType                  NVARCHAR( 10),  
   @cCtnWeight                NVARCHAR( 10),  
   @cSerialNo                 NVARCHAR( 30),   
   @nSerialQTY                INT,             
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT   
)  
AS  
  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @cFacility            NVARCHAR( 5)  
   DECLARE @cBillToKey           NVARCHAR( 15)  
   DECLARE @nIsAllowMixSKU       INT = 1  
   DECLARE @cData1               NVARCHAR( 60)  
   DECLARE @nPickQty             INT = 0  
   DECLARE @nPackQty             INT = 0  
   DECLARE @cOrdType             NVARCHAR( 10)
   DECLARE @nIsAllowMixStyle     INT = 1
   DECLARE @cPackStyle           NVARCHAR( 20)
   DECLARE @cStyle               NVARCHAR( 20)
  
   DECLARE @cDropIDCheck         NVARCHAR( 1)   --TSY01  
   DECLARE @cDropID              NVARCHAR( 50)  --TSY01  
   DECLARE @nTTLPickedDropID     INT = 0        --TSY01  
   DECLARE @nTTLPackedDropID     INT = 0        --TSY01  
   DECLARE @nCHKCartonNo         INT = 0        --TSY01  
   DECLARE @cUserName            NVARCHAR( 50)  --TSY01  
   DECLARE @cTempDropID          NVARCHAR( 20)
   DECLARE @cTempOrderKey        NVARCHAR( 10)
   DECLARE @cErrMsg1             NVARCHAR( 20)
   DECLARE @cErrMsg2             NVARCHAR( 20)
   DECLARE @cErrMsg3             NVARCHAR( 20)
   DECLARE @cErrMsg4             NVARCHAR( 20)
   DECLARE @cTempUserName        NVARCHAR( 18)
   DECLARE @cLottable01          NVARCHAR( 18)
   DECLARE @nRowCount            INT

   SET @nErrNo = 0  

   SELECT @cFacility = Facility  
         ,@cDropID = V_CaseID   --TSY01  
         ,@cUserName = UserName --TSY01  
         ,@cTempDropID = I_Field02
   FROM rdt.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   IF @nStep = 1  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         IF EXISTS( SELECT 1
                    FROM RDT.RDTMOBREC WITH (NOLOCK)
                    WHERE Mobile = @nMobile
                    AND   ( Printer = '' OR Printer_Paper = ''))
         BEGIN
            SET @nErrNo = 198708  
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --PrinterNeeded  
            GOTO Quit 
         END

         IF ISNULL( @cTempDropID, '') <> '' -- User key in drop id
         BEGIN
            SELECT TOP 1 @cDropID = PD.RefNo2
            FROM dbo.PackDetail PD WITH (NOLOCK)
            WHERE PD.StorerKey = @cStorerKey
            AND   PD.UPC = @cUserName
            AND   NOT EXISTS( SELECT 1
                              FROM dbo.PackInfo PIF WITH (NOLOCK)
                              WHERE PD.PickSlipNo = PIF.PickSlipNo
                              AND   PD.CartonNo = PIF.CartonNo
                              AND   ISNULL( CartonType, '') <> '')
            ORDER BY 1

            -- This user has previous tote not yet confirm carton
            IF ISNULL( @cDropID, '') <> ''
            BEGIN
               -- Check if the 2 tote belong to same orders
               SELECT TOP 1 @cTempOrderKey = OrderKey
               FROM dbo.PICKDETAIL WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   DropID = @cDropID
               AND   [STATUS] = '5'
               ORDER BY 1

               -- Not allow user scan tote from different orders if previous tote not yet confirm
               IF @cTempOrderKey <> @cOrderKey
               BEGIN
                  SET @nErrNo = 0  
                  SET @cErrMsg1 = rdt.rdtgetmessage(198709, @cLangCode,'DSP') -- Pls Close Drop Id
                  SET @cErrMsg2 = @cDropID  
                  SET @cErrMsg3 = rdt.rdtgetmessage(198710, @cLangCode,'DSP') -- Before Continue
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3  
                  IF @nErrNo = 1  
                  BEGIN  
                     SET @cErrMsg1 = ''  
                     SET @cErrMsg2 = ''  
                     SET @cErrMsg3 = ''  
                  END  

                  SET @nErrNo = 198709  
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Pls Close Drop Id  
                  GOTO Quit 
               END
            END

            SELECT @cTempUserName = UserName
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE I_Field02 = @cTempDropID
            AND   Func = @nFunc
            AND   Step > 0

            IF ISNULL( @cTempUserName, '') <> @cUserName
            BEGIN
               SET @nErrNo = 0  
               SET @cErrMsg1 = rdt.rdtgetmessage(198713, @cLangCode,'DSP') -- Drop Id
               SET @cErrMsg2 = @cDropID  
               SET @cErrMsg3 = rdt.rdtgetmessage(198714, @cLangCode,'DSP') -- In Use By Other User
               SET @cErrMsg4 = @cTempUserName  
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4  
               IF @nErrNo = 1  
               BEGIN  
                  SET @cErrMsg1 = ''  
                  SET @cErrMsg2 = ''  
                  SET @cErrMsg3 = ''  
                  SET @cErrMsg4 = ''  
               END  

               SET @nErrNo = 198715  
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --DropID In Use  
               GOTO Quit 
            END
         END
      END

      IF @nInputKey = 0
      BEGIN
         SELECT TOP 1 @cDropID = PD.RefNo2
         FROM dbo.PackDetail PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @cPickSlipNo
         AND   PD.UPC = @cUserName
         AND   NOT EXISTS( SELECT 1
                           FROM dbo.PackInfo PIF WITH (NOLOCK)
                           WHERE PD.PickSlipNo = PIF.PickSlipNo
                           AND   PD.CartonNo = PIF.CartonNo
                           AND   ISNULL( CartonType, '') <> '')
         ORDER BY 1

         IF ISNULL( @cDropID, '') <> ''
         BEGIN
            SET @nErrNo = 0  
            SET @cErrMsg1 = rdt.rdtgetmessage(198711, @cLangCode,'DSP') -- Pls Close Drop Id
            SET @cErrMsg2 = @cDropID  
            SET @cErrMsg3 = rdt.rdtgetmessage(198712, @cLangCode,'DSP') -- Before Exit
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3  
            IF @nErrNo = 1  
            BEGIN  
               SET @cErrMsg1 = ''  
               SET @cErrMsg2 = ''  
               SET @cErrMsg3 = ''  
            END  

            SET @nErrNo = 198711  
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Pls Close Drop Id  
            GOTO Quit 
         END
      END
   END

   IF @nStep = 3  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         --TSY01 START DROPID CHK  
         SET @cDropIDCheck = rdt.RDTGetConfig( @nFunc, 'CHKDropIDSKUQTY', @cStorerKey)  
         IF @cDropIDCheck = 1  
         BEGIN  
            --TSY01 START CHECK SKU IN PICKDETAIL DROPID  
            IF NOT EXISTS ( SELECT 1  
                            FROM dbo.PICKDETAIL WITH (NOLOCK)  
                       WHERE OrderKey = @cOrderKey  
                       AND   DROPID = @cDropID  
                       AND   SKU = @cSKU)  
            BEGIN  
                SET @nErrNo = 198705  
                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Invalid SKU  
                GOTO Quit  
            END  
            --TSY01 END CHECK SKU IN PICKDETAIL DROPID  
  
            --TSY01 START CHECK ttlpick = ttlpack for the DROPID  
            SET @nTTLPickedDropID = 0  
            SET @nTTLPackedDropID = 0  
  
            SELECT @nTTLPickedDropID = SUM(QTY)  
            FROM dbo.PICKDETAIL WITH (NOLOCK)  
            WHERE OrderKey = @cOrderKey  
            AND   DROPID = @cDropID  
  
            SELECT @nTTLPackedDropID = SUM(QTY)  
            FROM dbo.PACKDETAIL WITH (NOLOCK)  
            WHERE PickSlipNo = @cPickSlipNo  
            AND   RefNo2 = @cDropID  
  
            IF @nTTLPickedDropID = @nTTLPackedDropID  
            BEGIN  
                SET @nErrNo = 198706  
                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --DROPID FINISH  
                GOTO Quit  
            END  
            --TSY01 END CHECK ttlpick = ttlpack for the DROPID  
  
            --TSY01 START CHECK SKU Fully Packed for DROPID  
            SET @nTTLPickedDropID = 0  
            SET @nTTLPackedDropID = 0  
  
            SELECT @nTTLPickedDropID = SUM(QTY)  
            FROM dbo.PICKDETAIL WITH (NOLOCK)  
            WHERE OrderKey = @cOrderKey  
            AND   DROPID = @cDropID  
            AND   SKU = @cSKU  
  
            SELECT @nTTLPackedDropID = SUM(QTY)  
            FROM dbo.PACKDETAIL WITH (NOLOCK)  
            WHERE PickSlipNo = @cPickSlipNo  
            AND   RefNo2 = @cDropID  
            AND   SKU = @cSKU  
  
            IF @nTTLPickedDropID = @nTTLPackedDropID  
            BEGIN  
                SET @nErrNo = 198707  
                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --SKU FINISH  
                GOTO Quit  
            END  
            --TSY01 END CHECK SKU Fully Packed for DROPID  
  
         END  
         --TSY01 END DROPID CHK  
  
         --TSY01 START GET CORRECT CARTONNO CHECK  
         SET @nCHKCartonNo = 0  
         SELECT @nCHKCartonNo = MAX(PD.CARTONNO)  
         FROM dbo.PackDetail PD WITH (NOLOCK)  
         LEFT JOIN dbo.PackInfo PIF WITH (NOLOCK)  
              ON PD.PickSlipNo = PIF.PickSlipNo and PD.CARTONNO = PIF.CARTONNO  
         WHERE PD.PickSlipNo = @cPickSlipNo  
         AND PD.Storerkey = @cStorerkey  
         AND PD.AddWho = 'rdt.' + @cUserName  
         AND ISNULL(PIF.PickSlipNo,'') = ''  
  
         --If Latest Carton <> current carton, 0 for trigger to create new carton  
         IF ISNULL(@nCHKCartonNo,0) <> @nCartonNo  
            SET @nCartonNo = ISNULL(@nCHKCartonNo,0)  
         --TSY01 END GET CORRECT CARTONNO CHECK  
  
         SELECT  
            @cBillToKey = BillToKey,
            @cOrdType = Type  
         FROM dbo.ORDERS WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
           
         IF EXISTS ( SELECT 1  
                     FROM dbo.STORER WITH (NOLOCK)  
                     WHERE StorerKey = @cBillToKey  
                     AND   [type] = '2'  
                     AND   Facility = @cFacility  
                     AND   SUSR3 = 'N')  
            SET @nIsAllowMixSKU = 0  
  
         IF EXISTS( SELECT 1
                    FROM dbo.CODELKUP WITH (NOLOCK)
                    WHERE LISTNAME = 'ICSKUSTYLE'
                    AND   Code = @cOrdType
                    AND   Storerkey = @cStorerkey)
            SET @nIsAllowMixStyle = 0
            
         IF EXISTS ( SELECT 1  
                     FROM dbo.PackDetail WITH (NOLOCK)  
                     WHERE PickSlipNo = @cPickSlipNo  
                     AND   CartonNo = @nCartonNo)  
         BEGIN  
            IF NOT EXISTS( SELECT 1   
                           FROM dbo.PackDetail WITH (NOLOCK)  
                           WHERE PickSlipNo = @cPickSlipNo  
                           AND   CartonNo = @nCartonNo  
                           AND   SKU = @cSKU) AND @nIsAllowMixSKU = 0  
            BEGIN  
               SET @nErrNo = 198701  
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Ctn Mix SKU  
               GOTO Quit    
            END  
            
            IF @nIsAllowMixStyle = 0
            BEGIN
               SELECT @cStyle = Style
               FROM dbo.SKU WITH (NOLOCK)
               WHERE StorerKey = @cStorerkey
               AND   Sku = @cSKU
            
               SELECT TOP 1 @cPackStyle = SKU.Style
               FROM dbo.PackDetail PD WITH (NOLOCK)
               JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.Sku)
               WHERE PD.PickSlipNo = @cPickSlipNo
               AND   PD.StorerKey = @cStorerkey
               AND   PD.CartonNo = @nCartonNo
               ORDER BY 1
               
               IF @cStyle <> @cPackStyle
               BEGIN  
               	INSERT INTO traceinfo(tracename, timein, Col1, Col2) VALUES ('840', GETDATE(), @cStyle, @cPackStyle)
                  SET @nErrNo = 198704  
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Ctn Mix SKU  
                  GOTO Quit    
               END  
            END
         END  
      END  
   END  
     
   IF @nStep = 4  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         IF EXISTS ( SELECT 1   
                     FROM dbo.ORDERS O WITH (NOLOCK)  
                     WHERE O.OrderKey = @cOrderKey  
                     AND   EXISTS ( SELECT 1  
                                    FROM dbo.CODELKUP CLK WITH (NOLOCK)  
                                    WHERE CLK.LISTNAME = 'STFCART'  
                                    AND   CLK.Code = O.ShipperKey  
                                    AND   CLK.Storerkey = O.StorerKey))  
         BEGIN  
          SELECT @nPickQty = ISNULL( SUM( Qty), 0)  
          FROM dbo.PICKDETAIL WITH (NOLOCK)  
          WHERE OrderKey = @cOrderKey  
            
          SELECT @nPackQty = ISNULL( SUM( Qty), 0)  
          FROM dbo.PackDetail WITH (NOLOCK)  
          WHERE PickSlipNo = @cPickSlipNo  
            
          IF @nPickQty <> @nPackQty  
            BEGIN  
               SET @nErrNo = 198703  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Max Carton = 1  
               GOTO Quit  
            END  
         END  
      END   
   END  
     
   IF @nStep = 9  
   BEGIN  
    IF @nInputKey = 1  
    BEGIN  
         SELECT DISTINCT @cLottable01 = LOTTABLE01   
         FROM dbo.LOTATTRIBUTE LA WITH (NOLOCK)   
         JOIN dbo.LOTXLOCXID LLI WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)   
         WHERE LLI.StorerKey = @cStorerKey  
         AND   LLI.SKU = @cSKU   
         AND   LLI.QTY > 0   
         SET @nRowCount = @@ROWCOUNT  
                    
         IF @nRowCount = 1 AND  
            ISNULL( @cLottable01, '') <> '' AND   
            EXISTS( SELECT 1   
                     FROM dbo.CODELKUP WITH (NOLOCK)   
                     WHERE LISTNAME = 'LVSCOO'  
                     AND   Code = @cLottable01  
                     AND   Storerkey = @cStorerKey   
                     AND   LEN( Code) = 2)  
            GOTO Quit

         SELECT @cData1 = I_Field02  
         FROM rdt.RDTMOBREC WITH (NOLOCK)  
         WHERE Mobile = @nMobile  
  
         IF NOT EXISTS ( SELECT 1  
                           FROM dbo.CODELKUP WITH (NOLOCK)  
                           WHERE LISTNAME = 'LVSCOO'  
                           AND   Code = @cData1  
                           AND   Storerkey = @cStorerKey) AND ISNULL( @cData1, '') <> ''  
         BEGIN  
            SET @nErrNo = 198702  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid COO  
            GOTO Quit  
         END  
    END  
   END  
   Quit:  
     
     
  

GO