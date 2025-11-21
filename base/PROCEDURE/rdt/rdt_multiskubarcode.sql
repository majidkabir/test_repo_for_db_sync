SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_MultiSKUBarcode                                 */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Prompt multi SKU that share same barcode for selection      */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 30-04-2013  1.0  Ung         SOS276703. Created                      */
/* 09-04-2014  1.1  Ung         SOS307644. Add auto match SKU in Doc    */
/* 28-09-2015  1.2  Ung         SOS350418. Fix use TOP 1 and @@ROWCOUNT */
/* 13-04-2018  1.3  James       WMS4107. Add pickslip doctype (james01) */
/* 03-08-2018  1.4  LZG         INC0285935 - Added logic to prompt error*/
/*                              if SKU is invalid in PickDetail (ZG01)  */
/* 19-09-2018  1.5  James       WMS6203. Add LotxLocxid doctype(james02)*/
/* 15-10-2018  1.6  James       Expand DocType. Change LLL to fullname  */
/* 16-11-2018  1.7  Ung         WMS-6932 Fix SKU param pass in UPC      */
/* 03-01-2019  1.8  James       Filter ID with qty only show (james03)  */
/* 17-10-2019  1.9  YeeKung     INC0868161 Put SKU checking by ASN,     */
/*                              ID,picklsipno (yeekung01)               */
/* 20-01-2020  2.0  YeeKung     WMS-11791 Add LotxLocxid.loc doctype    */
/*                                 (yeekung02)                          */
/* 13-02-2020  2.1  YeeKung     INC1039880 Added logic to prompt error  */
/*                            if sku is invalid in lotxlocxid(yeekung03)*/
/* 05-03-2020  2.2  YeeKung     Fix Bug (yeekung04)                     */
/* 10-02-2020  2.3  James       WMS-11909 Add PTLTran doctype (james04) */
/* 23-09-2020  2.4  YeeKung     WMS-11540 Fix close cursor (yeekung04)  */
/* 12-03-2020  2.5  YeeKung     WMS12309 Added logic to prompt error    */
/*                              if sku is invalid in ASN(yeekung05)     */
/* 23-09-2020  2.6  YeeKung     WMS-15415 Add Second doctype(yeekung06) */
/* 23-06-2021  2.7  James       WMS-17264 Add container receive(james05)*/
/* 25-07-2019  2.8  James       WMS9920-Add TaskDetail doctype (james06)*/
/* 29-03-2022  2.9  Ung         WMS-19254 Add cursor for dynamic scope  */
/* 12-05-2023  3.0  Ung         WMS-22366 Fix duplicate SKU             */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_MultiSKUBarcode]
   @nMobile    INT,
   @nFunc      INT,
   @cLangCode  NVARCHAR( 3),
   @cInField01 NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,
   @cInField02 NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,
   @cInField03 NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,
   @cInField04 NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,
   @cInField05 NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,
   @cInField06 NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,
   @cInField07 NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,
   @cInField08 NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,
   @cInField09 NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,
   @cInField10 NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,
   @cInField11 NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,
   @cInField12 NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,
   @cInField13 NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,
   @cInField14 NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,
   @cInField15 NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,
   @cType      NVARCHAR( 10),
   @cMultiSKUBarcode NVARCHAR( 1),
   @cStorerKey NVARCHAR( 15) OUTPUT,
   @cSKU       NVARCHAR( 30) OUTPUT,
   @nErrNo  INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT,
   @cDocType   NVARCHAR( 30) = '',
   @cDocNo     NVARCHAR( 20) = '',
   @cSecondDocType   NVARCHAR( 30) = '',
   @cSecondDocNo     NVARCHAR( 20) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @curSKU CURSOR
   DECLARE @cCurrentStorer NVARCHAR(15)
   DECLARE @cCurrentSKU NVARCHAR(20)

   SET @cCurrentStorer = ''
   SET @cCurrentSKU = ''

   /*-------------------------------------------------------------------------------

                                  Validate option

   -------------------------------------------------------------------------------*/
   IF @cType = 'CHECK'
   BEGIN
      DECLARE @cStorer1 NVARCHAR(15)
      DECLARE @cStorer2 NVARCHAR(15)
      DECLARE @cStorer3 NVARCHAR(15)
      DECLARE @cSKU1    NVARCHAR(20)
      DECLARE @cSKU2    NVARCHAR(20)
      DECLARE @cSKU3    NVARCHAR(20)
      DECLARE @cOption  NVARCHAR(1)

      -- Screen mapping
      SET @cStorer1 = @cOutField01
      SET @cSKU1    = @cOutField02
      SET @cStorer2 = @cOutField05
      SET @cSKU2    = @cOutField06
      SET @cStorer3 = @cOutField09
      SET @cSKU3    = @cOutField10
      SET @cOption  = @cInField13

      -- Check invalid option
      IF @cOption NOT IN ('1', '2', '3', '')
      BEGIN
         SET @nErrNo = 81151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Fail
      END

      -- Check option 1
      IF @cOption = '1'
      BEGIN
         IF @cSKU1 = ''
         BEGIN
            SET @nErrNo = 81152
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU1 blank
            GOTO Fail
         END
         SET @cStorerKey = @cStorer1
         SET @cSKU = @cSKU1
         GOTO Quit
      END

      -- Check option 2
      IF @cOption = '2'
      BEGIN
         IF @cSKU2 = ''
         BEGIN
            SET @nErrNo = 81153
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU2 blank
            GOTO Fail
         END
         SET @cStorerKey = @cStorer2
         SET @cSKU = @cSKU2
         GOTO Quit
      END

      -- Check option 3
      IF @cOption = '3'
      BEGIN
         IF @cSKU3 = ''
         BEGIN
            SET @nErrNo = 81154
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU3 blank
            GOTO Fail
         END
         SET @cStorerKey = @cStorer3
         SET @cSKU = @cSKU3
         GOTO Quit
      END

      -- Check option ENTER
      IF @cOption = ''
      BEGIN
         -- Check no more record
         IF @cSKU2 = '' OR @cSKU3 = ''
         BEGIN
            SET @nErrNo = 81155
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more SKU
            GOTO Fail
         END

         -- Get last SKU on screen
         SET @cCurrentSKU = LEFT( @cSKU3 + SPACE(20), 20)
         SET @cCurrentStorer = LEFT( @cStorer3 + SPACE(15), 20)

         SET @nErrNo = -1 -- Stay in MultiSKU screen
      END
   END


   /*-------------------------------------------------------------------------------

                                  Populate screen

   -------------------------------------------------------------------------------*/
   DECLARE @cStorerCode NVARCHAR(15)
   DECLARE @cSKUCode    NVARCHAR(20)
   DECLARE @cSKUDesc1   NVARCHAR(20)
   DECLARE @cSKUDesc2   NVARCHAR(20)
   DECLARE @nCount      INT
   DECLARE @cStorerKeyInDoc NVARCHAR(20)
   DECLARE @cSKUInDoc   NVARCHAR(20)
   DECLARE @cZone       NVARCHAR(18)
   DECLARE @cStatus     NVARCHAR(1)

   DECLARE @cPH_OrderKey   NVARCHAR( 10)
   DECLARE @cPH_LoadKey    NVARCHAR( 10)
   DECLARE @nRowCount   INT
   DECLARE @cPTLType    NVARCHAR( 20)
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)

   SET @nCount = 1

   IF @cDocType <> '' AND @cDocNo <> ''
   BEGIN
      IF @cDocType = 'ASN'
      BEGIN
         SET @cStorerKeyInDoc = ''
         SET @cSKUInDoc = ''

         SELECT -- TOP 1
            @cStorerKeyInDoc = A.StorerKey,
            @cSKUInDoc = A.SKU
         FROM
         (
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
         ) A
         JOIN ReceiptDetail RD WITH (NOLOCK) ON (RD.StorerKey = A.StorerKey AND RD.SKU = A.SKU)
         WHERE RD.ReceiptKey = @cDocNo
         GROUP BY A.StorerKey, A.SKU

         SET @nRowCount = @@ROWCOUNT

         -- Found 1 matched SKU in doc
         IF @nRowCount = 1
         BEGIN
            SET @cStorerKey = @cStorerKeyInDoc
            SET @cSKU = @cSKUInDoc
            SET @nErrNo = -1 -- Found and Exit
            GOTO Quit
         END
         ELSE IF @nRowCount = 0 --(yeekung05)
         BEGIN
            --SET @cStorerKey = @cStorerKeyInDoc
            --SET @cSKU = @cSKUInDoc
            SET @cSKU = @cSKU  -- Return empty SKU to parent script to prompt error
            SET @nErrNo = 2 -- Set to invalid ErrNo
            GOTO Quit
         END
         ELSE  --(yeekung01)
         BEGIN
            IF @cMultiSKUBarcode = '1' -- Multi SKU
            BEGIN
               SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT A.StorerKey, A.SKU
               FROM
               (
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
               ) A
               JOIN ReceiptDetail RD WITH (NOLOCK) ON (RD.StorerKey = A.StorerKey AND RD.SKU = A.SKU)
               WHERE A.SKU > @cCurrentSKU
               AND RD.ReceiptKey = @cDocNo
               GROUP BY A.StorerKey, A.SKU
               ORDER BY A.SKU
            END

         END
      END

      IF @cDocType = 'PickSlipNo'
      BEGIN
         SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
         IF @cPickConfirmStatus = '0'
            SET @cPickConfirmStatus = '5'

         SELECT @cZone = Zone, @cPH_OrderKey = OrderKey, @cPH_LoadKey = ExternOrderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cDocNo

         SET @cStorerKeyInDoc = ''
         SET @cSKUInDoc = ''

         IF @cSecondDocType= 'LOC'
         BEGIN
            IF ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' OR ISNULL(@cZone, '') = '7'        -- Cross Dock PickSlip
            BEGIN
               SELECT -- TOP 1
               @cStorerKeyInDoc = A.StorerKey,
               @cSKUInDoc = A.SKU
               FROM
               (
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
               ) A
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.StorerKey = A.StorerKey AND PD.SKU = A.SKU)
               JOIN dbo.RefKeyLookup RPL WITH (NOLOCK) ON (RPL.PickDetailKey = PD.PickDetailKey)
               WHERE RPL.PickslipNo = @cDocNo
               AND PD.QTY > 0
               AND PD.Loc=@cSecondDocNo
               AND PD.Status < @cPickConfirmStatus
               GROUP BY A.StorerKey, A.SKU
            END
            ELSE
            BEGIN
               IF ISNULL(@cPH_OrderKey, '') <> ''                 -- Discrete PickSlip
               BEGIN
                  SELECT -- TOP 1
                     @cStorerKeyInDoc = A.StorerKey,
                     @cSKUInDoc = A.SKU
                  FROM                  (
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
                  ) A
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.StorerKey = A.StorerKey AND PD.SKU = A.SKU)
                  JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
                  WHERE PH.PickHeaderKey = @cDocNo
                  AND PD.QTY > 0
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.Loc=@cSecondDocNo
                  GROUP BY A.StorerKey, A.SKU
               END
               ELSE IF ISNULL(@cPH_LoadKey, '') <> ''             -- Conso PickSlip
               BEGIN
                  SELECT -- TOP 1
                     @cStorerKeyInDoc = A.StorerKey,
                     @cSKUInDoc = A.SKU
                  FROM
                  (
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
                  ) A
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.StorerKey = A.StorerKey AND PD.SKU = A.SKU)
                  JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                  JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
                  WHERE PH.PickHeaderKey = @cDocNo
                  AND PD.QTY > 0
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.Loc=@cSecondDocNo
                  GROUP BY A.StorerKey, A.SKU
               END
               ELSE                                               -- Custom PickSlip
               BEGIN
                  SELECT
                     @cStorerKeyInDoc = A.StorerKey,
                     @cSKUInDoc = A.SKU
                  FROM
                  (
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
                  ) A
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.StorerKey = A.StorerKey AND PD.SKU = A.SKU)
                  WHERE PD.PickSlipNo = @cDocNo
                  AND PD.QTY > 0
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.Loc=@cSecondDocNo
                  GROUP BY A.StorerKey, A.SKU
               END
            END
         END
         ELSE
         BEGIN
            IF ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' OR ISNULL(@cZone, '') = '7'        -- Cross Dock PickSlip
            BEGIN
               SELECT -- TOP 1
                  @cStorerKeyInDoc = A.StorerKey,
                  @cSKUInDoc = A.SKU
               FROM
               (
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
               ) A
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.StorerKey = A.StorerKey AND PD.SKU = A.SKU)
               JOIN dbo.RefKeyLookup RPL WITH (NOLOCK) ON (RPL.PickDetailKey = PD.PickDetailKey)
               WHERE RPL.PickslipNo = @cDocNo
               AND PD.QTY > 0
               AND PD.Status < @cPickConfirmStatus
               GROUP BY A.StorerKey, A.SKU
            END
            ELSE
            BEGIN
               IF ISNULL(@cPH_OrderKey, '') <> ''                 -- Discrete PickSlip
               BEGIN
                  SELECT -- TOP 1
                     @cStorerKeyInDoc = A.StorerKey,
                     @cSKUInDoc = A.SKU
                  FROM
                  (
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
                  ) A
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.StorerKey = A.StorerKey AND PD.SKU = A.SKU)
                  JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
                  WHERE PH.PickHeaderKey = @cDocNo
                  AND PD.QTY > 0
                  AND PD.Status < @cPickConfirmStatus
                  GROUP BY A.StorerKey, A.SKU
               END
               ELSE IF ISNULL(@cPH_LoadKey, '') <> ''             -- Conso PickSlip
               BEGIN
                  SELECT -- TOP 1
                     @cStorerKeyInDoc = A.StorerKey,
                     @cSKUInDoc = A.SKU
                  FROM
                  (
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
                  ) A
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.StorerKey = A.StorerKey AND PD.SKU = A.SKU)
                  JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                  JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
                  WHERE PH.PickHeaderKey = @cDocNo
                  AND PD.QTY > 0
                  AND PD.Status < @cPickConfirmStatus
                  GROUP BY A.StorerKey, A.SKU
               END
               ELSE                                               -- Custom PickSlip
               BEGIN
                  SELECT
                     @cStorerKeyInDoc = A.StorerKey,
                     @cSKUInDoc = A.SKU
                  FROM
                  (
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
                  ) A
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.StorerKey = A.StorerKey AND PD.SKU = A.SKU)
                  WHERE PD.PickSlipNo = @cDocNo
                  AND PD.QTY > 0
                  AND PD.Status < @cPickConfirmStatus
                  GROUP BY A.StorerKey, A.SKU
               END
            END
         END
         SET @nRowCount = @@ROWCOUNT

         -- Found 1 matched SKU in doc
         IF @nRowCount = 1
         BEGIN
            SET @cStorerKey = @cStorerKeyInDoc
            SET @cSKU = @cSKUInDoc
            SET @nErrNo = -1 -- Found and Exit
            GOTO Quit
         END
         ELSE IF @nRowCount = 0                                    -- ZG01
         BEGIN
            --SET @cStorerKey = @cStorerKeyInDoc
            --SET @cSKU = @cSKUInDoc
            SET @cSKU = ''  -- Return empty SKU to parent script to prompt error
            SET @nErrNo = 2 -- Set to invalid ErrNo
            GOTO Quit
         END
         ELSE IF @nRowCount >1  -- (yeekung01)
         BEGIN

            IF ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' OR ISNULL(@cZone, '') = '7'        -- Cross Dock PickSlip
            BEGIN

               SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT -- TOP 1
                  A.StorerKey,
                  A.SKU
               FROM
               (
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
               ) A
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.StorerKey = A.StorerKey AND PD.SKU = A.SKU)
               JOIN dbo.RefKeyLookup RPL WITH (NOLOCK) ON (RPL.PickDetailKey = PD.PickDetailKey)
               WHERE RPL.PickslipNo = @cDocNo
               AND PD.QTY > 0
               AND PD.Status < @cPickConfirmStatus
               AND A.SKU > @cCurrentSKU
               GROUP BY A.StorerKey, A.SKU
               ORDER BY A.SKU
            END
            ELSE
            BEGIN
               IF ISNULL(@cPH_OrderKey, '') <> ''                 -- Discrete PickSlip
               BEGIN
                  SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT -- TOP 1
                     A.StorerKey,
                     A.SKU
                  FROM
                  (
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
                  ) A
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.StorerKey = A.StorerKey AND PD.SKU = A.SKU)
                  JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
                  WHERE PH.PickHeaderKey = @cDocNo
                  AND PD.QTY > 0
                  AND PD.Status < @cPickConfirmStatus
                  AND A.SKU > @cCurrentSKU
                GROUP BY A.StorerKey, A.SKU
                  ORDER BY A.SKU
               END
               ELSE IF ISNULL(@cPH_LoadKey, '') <> ''             -- Conso PickSlip
               BEGIN
                  SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT -- TOP 1
                     A.StorerKey,
                     A.SKU
                  FROM
                  (
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
                  ) A
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.StorerKey = A.StorerKey AND PD.SKU = A.SKU)
                  JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                  JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
                  WHERE PH.PickHeaderKey = @cDocNo
                  AND PD.QTY > 0
                  AND A.SKU > @cCurrentSKU
                  AND PD.Status < @cPickConfirmStatus
                  GROUP BY A.StorerKey, A.SKU
                  ORDER BY A.SKU
               END
               ELSE                                               -- Custom PickSlip
               BEGIN
                  SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT
                     A.StorerKey,
                     A.SKU
                  FROM
                  (
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
                  ) A
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.StorerKey = A.StorerKey AND PD.SKU = A.SKU)
                  WHERE PD.PickSlipNo = @cDocNo
                  AND PD.QTY > 0
                  AND A.SKU > @cCurrentSKU
                  AND PD.Status < @cPickConfirmStatus
                  GROUP BY A.StorerKey, A.SKU
                  ORDER BY A.SKU
               END
            END

         END
      END

      IF @cDocType = 'LOTXLOCXID.ID'
      BEGIN
         SET @cStorerKeyInDoc = ''
         SET @cSKUInDoc = ''

         SELECT -- TOP 1
            @cStorerKeyInDoc = A.StorerKey,
            @cSKUInDoc = A.SKU
         FROM
         (
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
         ) A
         JOIN LOTXLOCXID LLI WITH (NOLOCK) ON (LLI.StorerKey = A.StorerKey AND LLI.SKU = A.SKU)
         WHERE LLI.ID = @cDocNo
         AND   Qty > 0  -- (james03)
         GROUP BY A.StorerKey, A.SKU

         SET @nRowCount = @@ROWCOUNT --(yeekung04)

         -- Found 1 matched SKU in doc
         IF @nRowCount = 1  --(yeekung04)
         BEGIN
            SET @cStorerKey = @cStorerKeyInDoc
            SET @cSKU = @cSKUInDoc
            SET @nErrNo = -1 -- Found and Exit
            GOTO Quit
         END
         ELSE IF @nRowCount = 0 --(yeekung03)  --(yeekung04)
         BEGIN
            SET @nErrNo = 2 --invalid and prompt error
            SET @cSKU =''--@cStorerKeyInDoc
            GOTO FAIL
         END
         ELSE  --yeekung01
         BEGIN

            SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT -- TOP 1
               A.StorerKey,
               A.SKU
            FROM
            (
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
            ) A
            JOIN LOTXLOCXID LLI WITH (NOLOCK) ON (LLI.StorerKey = A.StorerKey AND LLI.SKU = A.SKU)
            WHERE LLI.ID = @cDocNo
            AND   Qty > 0  -- (james03)
            AND   A.SKU > @cCurrentSKU
            GROUP BY A.StorerKey, A.SKU
            ORDER BY A.SKU
         END
      END

      IF @cDocType = 'LOTXLOCXID.LOC'  --(yeekung02)
      BEGIN
         SET @cStorerKeyInDoc = ''
         SET @cSKUInDoc = ''

         SELECT -- TOP 1
            @cStorerKeyInDoc = A.StorerKey,
            @cSKUInDoc = A.SKU
         FROM
         (
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
         ) A
         JOIN LOTXLOCXID LLI WITH (NOLOCK) ON (LLI.StorerKey = A.StorerKey AND LLI.SKU = A.SKU)
         WHERE LLI.Loc = @cDocNo
         AND   Qty > 0  -- (james03)
         GROUP BY A.StorerKey, A.SKU

         -- Found 1 matched SKU in doc
         IF @@ROWCOUNT = 1
         BEGIN
            SET @cStorerKey = @cStorerKeyInDoc
            SET @cSKU = @cSKUInDoc
            SET @nErrNo = -1 -- Found and Exit
            GOTO Quit
         END
         ELSE  --yeekung01
         BEGIN

            SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT -- TOP 1
               A.StorerKey,
               A.SKU
            FROM
            (
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
            ) A
            JOIN LOTXLOCXID LLI WITH (NOLOCK) ON (LLI.StorerKey = A.StorerKey AND LLI.SKU = A.SKU)
            WHERE LLI.Loc = @cDocNo
            AND   Qty > 0  -- (james03)
            AND   A.SKU > @cCurrentSKU
            GROUP BY A.StorerKey, A.SKU
            ORDER BY A.SKU
         END
      END

      -- (james04)
      IF @cDocType LIKE 'PTLTRAN.%'  -- PTLTRAN.CART/PTLTRAN.STATION
      BEGIN
         SET @cStorerKeyInDoc = ''
         SET @cSKUInDoc = ''
         SET @cPTLType = SUBSTRING( @cDocType, CHARINDEX( '.', @cDocType) + 1, 20)

         SELECT -- TOP 1
            @cStorerKeyInDoc = A.StorerKey,
            @cSKUInDoc = A.SKU
         FROM
         (
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
         ) A
     JOIN PTL.PTLTRAN PTL WITH (NOLOCK) ON (PTL.StorerKey = A.StorerKey AND PTL.SKU = A.SKU)
         WHERE PTL.DeviceID = @cDocNo
         AND   PTL.PTLType = @cPTLType
         AND   PTL.[Status] = '0'
         GROUP BY A.StorerKey, A.SKU

         -- Found 1 matched SKU in doc
         IF @@ROWCOUNT = 1
         BEGIN
            SET @cStorerKey = @cStorerKeyInDoc
            SET @cSKU = @cSKUInDoc
            SET @nErrNo = -1 -- Found and Exit
            GOTO Quit
         END
         ELSE
         BEGIN
            IF @cMultiSKUBarcode = '1' -- Multi SKU      (yeekung04)
            BEGIN
               SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT A.StorerKey, A.SKU
                  FROM
                  (
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
                  ) A
                  JOIN PTL.PTLTRAN PTL WITH (NOLOCK) ON (PTL.StorerKey = A.StorerKey AND PTL.SKU = A.SKU)
                  WHERE PTL.DeviceID = @cDocNo
                  AND   PTL.PTLType = @cPTLType
                  AND   PTL.[Status] = '0'
                  AND   A.SKU > @cCurrentSKU
                  ORDER BY A.SKU
            END
            ELSE IF @cMultiSKUBarcode = '2' -- Multi storer
            BEGIN
               SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT A.StorerKey, A.SKU
           FROM
                  (
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE SKU.SKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE SKU.AltSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE SKU.RetailSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE SKU.ManufacturerSKU = @cSKU
                     UNION
                     SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE UPC.UPC = @cSKU
                  ) A
                  JOIN PTL.PTLTRAN PTL WITH (NOLOCK) ON (PTL.StorerKey = A.StorerKey AND PTL.SKU = A.SKU)
                  WHERE PTL.DeviceID = @cDocNo
                  AND   PTL.PTLType = @cPTLType
                  AND   PTL.[Status] = '0'
                  AND   A.StorerKey +A.SKU > @cCurrentStorer +@cCurrentSKU
                  ORDER BY A.StorerKey, A.SKU
            END
         END
      END

      -- (james05)
      IF @cDocType = 'CONTAINER'
      BEGIN
         SET @cStorerKeyInDoc = ''
         SET @cSKUInDoc = ''

         SELECT -- TOP 1
            @cStorerKeyInDoc = A.StorerKey,
            @cSKUInDoc = A.SKU
         FROM
         (
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
         ) A
         JOIN ReceiptDetail RD WITH (NOLOCK) ON (RD.StorerKey = A.StorerKey AND RD.SKU = A.SKU)
         JOIN rdt.rdtConReceiveLog CL WITH (NOLOCK) ON ( RD.ReceiptKey = CL.ReceiptKey)
         WHERE CL.Mobile = @nMobile
         GROUP BY A.StorerKey, A.SKU

         SET @nRowCount = @@ROWCOUNT

         -- Found 1 matched SKU in doc
         IF @nRowCount = 1
         BEGIN
            SET @cStorerKey = @cStorerKeyInDoc
            SET @cSKU = @cSKUInDoc
            SET @nErrNo = -1 -- Found and Exit
            GOTO Quit
         END
         ELSE IF @nRowCount = 0 --(yeekung05)
         BEGIN
            --SET @cStorerKey = @cStorerKeyInDoc
            --SET @cSKU = @cSKUInDoc
            SET @cSKU = @cSKU  -- Return empty SKU to parent script to prompt error
            SET @nErrNo = 2 -- Set to invalid ErrNo
            GOTO Quit
         END
         ELSE  --(yeekung01)
         BEGIN

            IF @cMultiSKUBarcode = '1' -- Multi SKU
            BEGIN
               SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT A.StorerKey, A.SKU
               FROM
               (
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
                  UNION
                  SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
               ) A
               JOIN ReceiptDetail RD WITH (NOLOCK) ON (RD.StorerKey = A.StorerKey AND RD.SKU = A.SKU)
               WHERE A.SKU > @cCurrentSKU
               AND RD.ReceiptKey = @cDocNo
               GROUP BY A.StorerKey, A.SKU
               ORDER BY A.SKU
            END

         END
      END

      -- (james05)
      IF @cDocType = 'TASKDETAIL'
      BEGIN
         SET @cStorerKeyInDoc = ''
         SET @cSKUInDoc = ''

         SELECT -- TOP 1
            @cStorerKeyInDoc = A.StorerKey,
            @cSKUInDoc = A.SKU
         FROM
         (
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
            UNION
            SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
         ) A
         JOIN TaskDetail TD WITH (NOLOCK) ON (TD.StorerKey = A.StorerKey AND TD.SKU = A.SKU)
         WHERE TD.TaskDetailKey = @cDocNo
         GROUP BY A.StorerKey, A.SKU

         -- Found 1 matched SKU in doc
         IF @@ROWCOUNT = 1
         BEGIN
            SET @cStorerKey = @cStorerKeyInDoc
            SET @cSKU = @cSKUInDoc
            SET @nErrNo = -1 -- Found and Exit
            GOTO Quit
         END
      END

      IF @cDocType = 'CURSOR'
      BEGIN
         SET @cStorerKeyInDoc = ''
         SET @cSKUInDoc = ''
         SET @nRowCount = 0

         OPEN Cursor_MultiSKUBarcode --Note: global cursor

         IF @cType = 'POPULATE'
         BEGIN
            FETCH NEXT FROM Cursor_MultiSKUBarcode INTO @cStorerKeyInDoc, @cSKUInDoc
            WHILE @@FETCH_STATUS = 0 AND @nRowCount <= 2
            BEGIN
               SET @nRowCount = @nRowCount + 1
               FETCH NEXT FROM Cursor_MultiSKUBarcode INTO @cStorerKeyInDoc, @cSKUInDoc
            END

            -- Found 1 matched SKU in doc
            IF @nRowCount = 1
            BEGIN
               SET @cStorerKey = @cStorerKeyInDoc
               SET @cSKU = @cSKUInDoc
               SET @nErrNo = -1 -- Found and Exit
               GOTO Quit
            END

            ELSE IF @nRowCount = 0
            BEGIN
               SET @nErrNo = 2 -- Set to invalid ErrNo
               GOTO Quit
            END

            -- At 1st page, but had pointed to 2nd record. So close and reopen cursor, to pointing back 1st record
            ELSE
            BEGIN
               CLOSE Cursor_MultiSKUBarcode
               OPEN Cursor_MultiSKUBarcode
            END
         END
         ELSE
         BEGIN
            IF @cMultiSKUBarcode = '1' -- Multi SKU
            BEGIN
               -- At existing page, need point to 3rd record of page, so populate next page from 4 record onwards
               FETCH NEXT FROM Cursor_MultiSKUBarcode INTO @cStorerKeyInDoc, @cSKUInDoc
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  IF @cSKUInDoc = @cCurrentSKU
                     BREAK
                  FETCH NEXT FROM Cursor_MultiSKUBarcode INTO @cStorerKeyInDoc, @cSKUInDoc
               END
            END
         END
      END
   END
   ELSE
   BEGIN
      IF @cMultiSKUBarcode = '1' -- Multi SKU
         SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT A.StorerKey, A.SKU
            FROM
            (
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
            ) A
            WHERE A.SKU > @cCurrentSKU
            ORDER BY A.SKU

      IF @cMultiSKUBarcode = '2' -- Multi storer
         SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT A.StorerKey, A.SKU
            FROM
            (
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE SKU.SKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE SKU.AltSKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE SKU.RetailSKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE SKU.ManufacturerSKU = @cSKU
               UNION
               SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE UPC.UPC = @cSKU
            ) A
            WHERE A.StorerKey + A.SKU > @cCurrentStorer + @cCurrentSKU
            ORDER BY A.StorerKey, A.SKU
   END

   -- Open cursor and fetch
   IF @cDocType = 'CURSOR'
      FETCH NEXT FROM Cursor_MultiSKUBarcode INTO @cStorerCode, @cSKUCode
   ELSE
   BEGIN
      OPEN @curSKU
      FETCH NEXT FROM @curSKU INTO @cStorerCode, @cSKUCode
   END

   -- Check no more record
   IF @@FETCH_STATUS <> 0
   BEGIN
      SET @nErrNo = 81156
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more record
      GOTO Fail
   END

   WHILE @nCount < 4
   BEGIN
      -- Get SKU info
      IF @@FETCH_STATUS = 0
         SELECT
            @cSKUDesc1 = SUBSTRING( Descr , 1, 20),
            @cSKUDesc2 = SUBSTRING( Descr , 21, 20)
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerCode
            AND SKU = @cSKUCode

      IF @nCount = 1
      BEGIN
         SET @cOutField01 = CASE WHEN @@FETCH_STATUS = 0 THEN @cStorerCode ELSE '' END
         SET @cOutField02 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUCode    ELSE '' END
         SET @cOutField03 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUDesc1   ELSE '' END
         SET @cOutField04 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUDesc2   ELSE '' END
      END
      IF @nCount = 2
      BEGIN
         SET @cOutField05 = CASE WHEN @@FETCH_STATUS = 0 THEN @cStorerCode ELSE '' END
         SET @cOutField06 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUCode    ELSE '' END
         SET @cOutField07 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUDesc1   ELSE '' END
         SET @cOutField08 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUDesc2   ELSE '' END
      END
      IF @nCount = 3
      BEGIN
         SET @cOutField09 = CASE WHEN @@FETCH_STATUS = 0 THEN @cStorerCode ELSE '' END
         SET @cOutField10 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUCode    ELSE '' END
         SET @cOutField11 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUDesc1   ELSE '' END
         SET @cOutField12 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUDesc2   ELSE '' END
      END

      SET @nCount = @nCount + 1

      IF @cDocType = 'CURSOR'
         FETCH NEXT FROM Cursor_MultiSKUBarcode INTO @cStorerCode, @cSKUCode
      ELSE
         FETCH NEXT FROM @curSKU INTO @cStorerCode, @cSKUCode
   END

Fail:
Quit:

END

GO