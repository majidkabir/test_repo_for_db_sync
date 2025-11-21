SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_862ExtValid01                                   */
/* Purpose: Validate ID. If pallet picking then cannot have             */
/*          partial allocated.                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-03-27   James     1.0   WMS3621. Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_862ExtValid01]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cSuggLOC        NVARCHAR( 10)
   ,@cLOC            NVARCHAR( 10)
   ,@cID             NVARCHAR( 18)
   ,@cDropID         NVARCHAR( 20)
   ,@cSKU            NVARCHAR( 20)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME
   ,@nTaskQTY        INT
   ,@nPQTY           INT
   ,@cUCC            NVARCHAR( 20)
   ,@cOption         NVARCHAR( 1)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nMix_SerialNo     INT,
           @cZone             NVARCHAR( 10),
           @cOrderKey         NVARCHAR( 10),
           @cLoadKey          NVARCHAR( 10),
           @cErrMsg1          NVARCHAR( 20),
           @cErrMsg2          NVARCHAR( 20),
           @cErrMsg3          NVARCHAR( 20),
           @cErrMsg4          NVARCHAR( 20),
           @cErrMsg5          NVARCHAR( 20)

   SET @nMix_SerialNo = 0

   SELECT 
      @cZone = Zone, 
      @cOrderKey = OrderKey, 
      @cLoadKey = ExternOrderKey     
   FROM dbo.PickHeader WITH (NOLOCK)     
   WHERE PickHeaderKey = @cPickSlipNo   

   -- For checking in 
   -- 860 (Pick SKU/UPC)
   -- 862 (Pick Pallet)
   -- No need check for 863 (Pick Drop ID) as already checked within rdtfnc_Pick
   IF @nFunc = 862 
   BEGIN
      IF @nStep = 6 -- ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check pallet id mix lot02 (serial no)
            IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
            BEGIN
               IF EXISTS ( SELECT 1 
                           FROM RefKeyLookup WITH (NOLOCK) 
                           JOIN PickDetail PD WITH (NOLOCK) ON (RefKeyLookup.PickDetailKey = PD.PickDetailKey)
                           JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
                           WHERE RefKeyLookup.PickslipNo = @cPickSlipNo
                           AND   PD.StorerKey = @cStorerKey
                           AND   PD.ID  = @cID  
                           AND   PD.Status < '9'
                           AND   PD.QTY > 0
                           GROUP BY PD.ID
                           HAVING COUNT( DISTINCT LOTTABLE02) > 1)
               SET @nMix_SerialNo = 1
            END
            ELSE IF @cOrderKey = ''
            BEGIN
               IF EXISTS ( SELECT 1 
                           FROM dbo.PickHeader PH (NOLOCK)
                           JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
                           JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                           JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
                           WHERE PH.PickHeaderKey = @cPickSlipNo
                           AND   PD.StorerKey = @cStorerKey
                           AND   PD.ID  = @cID  
                           AND   PD.Status < '9'
                           AND   PD.QTY > 0
                           GROUP BY PD.ID
                           HAVING COUNT( DISTINCT LOTTABLE02) > 1)
                  SET @nMix_SerialNo = 1
            END
            ELSE
            BEGIN
               IF EXISTS ( SELECT 1 
                           FROM dbo.PickHeader PH (NOLOCK)
                           JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
                           JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
                           WHERE PH.PickHeaderKey = @cPickSlipNo
                           AND   PD.StorerKey = @cStorerKey
                           AND   PD.ID  = @cID  
                           AND   PD.Status < '9'
                           AND   PD.QTY > 0
                           GROUP BY PD.ID
                           HAVING COUNT( DISTINCT LOTTABLE02) > 1)
                  SET @nMix_SerialNo = 1
            END

            IF @nMix_SerialNo = 1
            BEGIN
               -- Mix serial no must fully allocated if pick using 862 (Pick Pallet)
               IF EXISTS ( SELECT 1 
                           FROM dbo.LotxLocxID WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey
                           AND   ID = @cID
                           AND   ( Qty - QtyAllocated - QtyPicked) > 0)
               BEGIN
                  SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 121851, @cLangCode, 'DSP'), 7, 14) --ID Not Fully
                  SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 121852, @cLangCode, 'DSP'), 7, 14) --Allocated And
                  SET @cErrMsg3 = SUBSTRING( rdt.rdtgetmessage( 121853, @cLangCode, 'DSP'), 7, 14) --Mix Serial No
                  SET @cErrMsg4 = SUBSTRING( rdt.rdtgetmessage( 121854, @cLangCode, 'DSP'), 7, 14) --Pls Pick By
                  SET @cErrMsg5 = SUBSTRING( rdt.rdtgetmessage( 121855, @cLangCode, 'DSP'), 7, 14) --SKU/UPC (860)

                  SET @nErrNo = 0
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                  @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5

                  IF @nErrNo = 1
                  BEGIN
                     SELECT @cErrMsg1 = '', @cErrMsg2 = '', @cErrMsg3 = '', @cErrMsg4 = '', @cErrMsg5 = ''
                  END   
                  SET @nErrNo = -1
               END
            END
         END
      END
   END
END

Quit:

GO