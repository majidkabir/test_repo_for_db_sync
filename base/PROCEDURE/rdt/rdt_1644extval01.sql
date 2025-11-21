SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1644ExtVal01                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check if Case ID or Serial No duplicate                           */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 18-Mar-2019  James     1.0   WMS7505 Created                               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1644ExtVal01]
   @nMobile      INT,
   @nFunc        INT,
   @nStep        INT,
   @nInputKey    INT,
   @cLangCode    NVARCHAR( 3),
   @cStorerkey   NVARCHAR( 15),
   @cPickSlipNo  NVARCHAR( 10),
   @cDropID      NVARCHAR( 20),
   @cSKU         NVARCHAR( 20),
   @cCaseID      NVARCHAR( 20),
   @cSerialNo    NVARCHAR( MAX),
   @cErrType     NVARCHAR( 20) OUTPUT,
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cZone          NVARCHAR( 10),
           @cPH_OrderKey   NVARCHAR( 10),
           @cPH_LoadKey    NVARCHAR( 10),
           @nIsDuplicateCaseID   INT,
           @nIsDuplicateSerial   INT,
           @nIsAnyMore2Scan      INT,
           @nIsSKUExists         INT,
           @nPD_Qty              INT,
           @cPickConfirmStatus   NVARCHAR( 1),
           @cDataCapture         NVARCHAR(1),
           @cSerialNoCapture     NVARCHAR(1),
           @nSrDelimiter         INT,
           @nSrLength            INT


   SET @nIsDuplicateCaseID = 0
   SET @nIsDuplicateSerial = 0
   SET @nIsSKUExists = 1
   SET @nIsAnyMore2Scan = 1
   SET @nPD_Qty = 0

   --If configkey is on,   Check Pickdetail.status = @rdt.storerconfig.svalue 
   --If configkey is not exist, Check Pickdetail.status = æ5Æ
   --If configkey is off,  no checking
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   SELECT @cZone = Zone, @cPH_OrderKey = OrderKey, @cPH_LoadKey = ExternOrderKey     
   FROM dbo.PickHeader WITH (NOLOCK)     
   WHERE PickHeaderKey = @cPickSlipNo  

   IF @nStep = 1 --  PickSlipNo
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' OR ISNULL(@cZone, '') = '7'    
         BEGIN    
            IF NOT EXISTS ( SELECT 1
               FROM dbo.PickDetail PD (NOLOCK) 
               JOIN RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
               WHERE RPL.PickslipNo = @cPickSlipNo    
               AND   PD.Status < @cPickConfirmStatus
               AND   PD.QTY > 0
               AND   PD.StorerKey  = @cStorerKey
               AND   ISNULL( PD.Notes, '') = '')
               SET @nIsAnyMore2Scan = 0
         END
         ELSE
         IF ISNULL(@cPH_OrderKey, '') <> ''
         BEGIN      
            IF NOT EXISTS ( SELECT 1
               FROM dbo.PickHeader PH (NOLOCK)     
               JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)    
               WHERE PH.PickHeaderKey = @cPickSlipNo    
               AND   PD.Status < @cPickConfirmStatus
               AND   PD.QTY > 0
               AND   PD.StorerKey  = @cStorerKey
               AND   ISNULL( PD.Notes, '') = '')
               SET @nIsAnyMore2Scan = 0
         END
         ELSE
         BEGIN
            IF NOT EXISTS ( SELECT 1
               FROM dbo.PickHeader PH (NOLOCK)     
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
               JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
               WHERE PH.PickHeaderKey = @cPickSlipNo    
               AND   PD.Status < @cPickConfirmStatus
               AND   PD.QTY > 0
               AND   PD.StorerKey  = @cStorerKey
               AND   ISNULL( PD.Notes, '') = '')
               SET @nIsAnyMore2Scan = 0
         END

         IF @nIsAnyMore2Scan = 0
         BEGIN
            SET @nErrNo = 136001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Nothing 2 Scan'
            GOTO Quit
         END
      END
   END

   IF @nStep = 3 --  SKU/Case ID/Serial No
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- 1st check duplicate caseid. if found error straighaway exit. else check duplicate serial no
         If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' OR ISNULL(@cZone, '') = '7'    
         BEGIN    
            SELECT @nPD_Qty = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickDetail PD (NOLOCK) 
            JOIN RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
            WHERE RPL.PickslipNo = @cPickSlipNo    
            AND   PD.StorerKey  = @cStorerKey
            AND   PD.Status < @cPickConfirmStatus

            IF NOT EXISTS ( SELECT 1 
               FROM dbo.PickDetail PD (NOLOCK) 
               JOIN RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
               WHERE RPL.PickslipNo = @cPickSlipNo    
               AND   PD.QTY > 0
               AND   PD.StorerKey  = @cStorerKey
               AND   PD.Status < @cPickConfirmStatus
               AND   PD.SKU = @cSKU)
            BEGIN
               SET @nIsSKUExists = 0
            END

            IF @nIsSKUExists = 1
            BEGIN
               IF EXISTS ( SELECT 1 
                  FROM dbo.PickDetail PD (NOLOCK) 
                  JOIN RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
                  WHERE RPL.PickslipNo = @cPickSlipNo    
                  AND   PD.QTY > 0
                  AND   PD.StorerKey  = @cStorerKey
                  AND   PD.CaseID = @cCaseID)
               BEGIN
                  SET @nIsDuplicateCaseID = 1
               END

               IF @nIsDuplicateCaseID = 0
               BEGIN
                  IF EXISTS ( SELECT 1 
                     FROM dbo.PickDetail PD (NOLOCK) 
                     JOIN RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
                     WHERE RPL.PickslipNo = @cPickSlipNo    
                     AND   PD.QTY > 0
                     AND   PD.StorerKey  = @cStorerKey
                     AND   PD.Notes = @cSerialNo)
                  BEGIN
                     SET @nIsDuplicateSerial = 1
                  END
               END
            END
         END
         ELSE
         IF ISNULL(@cPH_OrderKey, '') <> ''
         BEGIN      
            SELECT @nPD_Qty = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickHeader PH (NOLOCK)     
            JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)    
            WHERE PH.PickHeaderKey = @cPickSlipNo    
            AND   PD.StorerKey  = @cStorerKey
            AND   PD.Status < @cPickConfirmStatus

            IF NOT EXISTS ( SELECT 1
               FROM dbo.PickHeader PH (NOLOCK)     
               JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)    
               WHERE PH.PickHeaderKey = @cPickSlipNo    
               AND   PD.QTY > 0
               AND   PD.StorerKey  = @cStorerKey
               AND   PD.Status < @cPickConfirmStatus
               AND   PD.Sku = @cSKU)
            BEGIN
               SET @nIsSKUExists = 0
            END

            IF @nIsSKUExists = 1
            BEGIN
               IF EXISTS ( SELECT 1
                  FROM dbo.PickHeader PH (NOLOCK)     
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)    
                  WHERE PH.PickHeaderKey = @cPickSlipNo    
                  AND   PD.QTY > 0
                  AND   PD.StorerKey  = @cStorerKey
                  AND   PD.CaseID = @cCaseID)
               BEGIN
                  SET @nIsDuplicateCaseID = 1
               END

               IF @nIsDuplicateCaseID = 0
               BEGIN
                  IF EXISTS ( SELECT 1
                     FROM dbo.PickHeader PH (NOLOCK)     
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)    
                     WHERE PH.PickHeaderKey = @cPickSlipNo    
                     AND   PD.QTY > 0
                     AND   PD.StorerKey  = @cStorerKey
                     AND   PD.Notes = @cSerialNo)
                  BEGIN
                     SET @nIsDuplicateSerial = 1
                  END
               END
            END
         END
         ELSE
         BEGIN
            SELECT @nPD_Qty = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickHeader PH (NOLOCK)     
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
            JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
            WHERE PH.PickHeaderKey = @cPickSlipNo    
            AND   PD.StorerKey  = @cStorerKey
            AND   PD.Status < @cPickConfirmStatus

            IF NOT EXISTS ( SELECT 1
                  FROM dbo.PickHeader PH (NOLOCK)     
                  JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
                  JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
                  WHERE PH.PickHeaderKey = @cPickSlipNo    
                  AND   PD.QTY > 0
                  AND   PD.StorerKey  = @cStorerKey
                  AND   PD.Status < @cPickConfirmStatus
                  AND   PD.Sku = @cSKU)
            BEGIN
               SET @nIsSKUExists = 0
            END

            IF @nIsSKUExists = 1
            BEGIN
               IF EXISTS ( SELECT 1
                  FROM dbo.PickHeader PH (NOLOCK)     
                  JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
                  JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
                  WHERE PH.PickHeaderKey = @cPickSlipNo    
                  AND   PD.QTY > 0
                  AND   PD.StorerKey  = @cStorerKey
                  AND   PD.CaseID = @cCaseID)
               BEGIN
                  SET @nIsDuplicateCaseID = 1
               END

               IF @nIsDuplicateCaseID = 0
               BEGIN
                  IF EXISTS ( SELECT 1
                     FROM dbo.PickHeader PH (NOLOCK)     
                     JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
                     JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
                     WHERE PH.PickHeaderKey = @cPickSlipNo    
                     AND   PD.QTY > 0
                     AND   PD.StorerKey  = @cStorerKey
                     AND   PD.Notes = @cSerialNo)
                  BEGIN
                     SET @nIsDuplicateSerial = 1
                  END
               END
            END
         END

        -- Get SKU info  
         SELECT @cDataCapture = DataCapture, 
                @cSerialNoCapture = SerialNoCapture
         FROM SKU WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey   
         AND   SKU = @cSKU  

         IF @nIsSKUExists = 0
         BEGIN
            SET @cErrType = 'SKU'
            SET @nErrNo = 136006
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU NotExists'
            GOTO Quit
         END

         IF @nIsDuplicateCaseID = 1
         BEGIN
            SET @cErrType = 'CASEID'
            SET @nErrNo = 136002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Duplicate CaseID'
            GOTO Quit
         END

         IF @cDataCapture IN ('1', '3') OR @cSerialNoCapture IN ('1', '3')
         BEGIN
            IF @nIsDuplicateSerial = 1
            BEGIN
               SET @cErrType = 'SERIALNO'
               SET @nErrNo = 136003
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Duplicate Serial'
               GOTO Quit
            END
         END

         DECLARE @nSerialNo_Cnt  INT
         DECLARE @nSerialNo_Len  INT
         DECLARE @fCaseCount     FLOAT

         SET @nSerialNo_Cnt = 0
         SET @fCaseCount = 0

         --Get # of serial no within the string
         SET @nSerialNo_Cnt = SUM( LEN( RTRIM( @cSerialNo)) - LEN( REPLACE( RTRIM( @cSerialNo), ',', '')) + 1) 

         --Get sku case cnt
         SELECT @fCaseCount = PACK.CaseCnt
         FROM dbo.PACK PACK WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
         WHERE SKU.Storerkey = @cStorerKey
         AND   SKU.SKU = @cSKU

         IF @cDataCapture IN ('1', '3') OR @cSerialNoCapture IN ('1', '3')
         BEGIN
            IF @nSerialNo_Cnt <> @fCaseCount
            BEGIN
               SET @cErrType = 'SERIALNO'
               SET @nErrNo = 136004
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SrCntNotMatch'
               GOTO Quit
            END

            SET @nSrDelimiter = CHARINDEX(',', @cSerialNo)
            SET @nSrLength = LEN( SUBSTRING( @cSerialNo, 1, @nSrDelimiter - 1))

            -- Check len of serial no (only check total length)
            -- 12345678, 12345679, 123456790....1 serial no = 8 digits
            -- (8 x 48) + 47 ','(comma)
            IF LEN( RTRIM( @cSerialNo)) <> ( ( @nSrLength * @fCaseCount) + (@fCaseCount - 1))
            BEGIN
               SET @cErrType = 'SERIALNO'
               SET @nErrNo = 136005
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SrLenNotMatch'
               GOTO Quit
            END
         END

         IF @nSerialNo_Cnt > @nPD_Qty
         BEGIN
            SET @cErrType = 'SERIALNO'
            SET @nErrNo = 136007
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over Scanned'
            GOTO Quit
         END
      END
   END

Quit:

END

SET QUOTED_IDENTIFIER OFF

GO