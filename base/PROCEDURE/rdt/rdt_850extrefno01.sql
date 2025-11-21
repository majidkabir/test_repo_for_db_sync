SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_850ExtRefNo01                                   */
/* Purpose: Check if user login with printer                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 2022-02-16 1.0  yeekung   WMS-21562 Created                           */
/************************************************************************/

CREATE   PROC [RDT].[rdt_850ExtRefNo01] (
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,           
   @cStorer        NVARCHAR( 15), 
   @cFacility      NVARCHAR( 5),  
   @cRefNo         NVARCHAR( 20), 
   @cOrderKey      NVARCHAR( 10), 
   @cDropID        NVARCHAR( 20), 
   @cLoadKey       NVARCHAR( 10), 
   @cPickSlipNo    NVARCHAR( 10), 
   @cID            NVARCHAR( 18),
   @cTaskDetailKey NVARCHAR( 10),
   @cSKU           NVARCHAR( 20),
   @cType          NVARCHAR( 20),
   @nCSKU          INT =0 OUTPUT ,
   @nCQTY          INT =0 OUTPUT ,
   @nPSKU          INT =0 OUTPUT, 
   @nPQTY          INT =0 OUTPUT, 
   @nVariance      INT =0 OUTPUT,
   @nQTY_PPA       INT =0 OUTPUT,
   @nQTY_CHK       INT =0 OUTPUT,
   @nRowRef        INT = 0 OUTPUT,
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
) 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nInputKey INT

   DECLARE @cSkipChkPSlipMustScanOut        NVARCHAR( 1)
   DECLARE @cPickConfirmStatus              NVARCHAR(1)
   
   IF @nVariance IS NOT NULL
   BEGIN
      DECLARE @tP TABLE (StorerKey NVARCHAR( 15), SKU NVARCHAR(20), QTY INT)
      DECLARE @tC TABLE (StorerKey NVARCHAR( 15), SKU NVARCHAR(20), QTY INT)
   END


   SET @cSkipChkPSlipMustScanOut = rdt.rdtGetConfig( @nFunc, 'SkipChkPSlipMustScanOut', @cStorer)
   SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorer)
   IF @cPickConfirmStatus =''
      SET @cPickConfirmStatus ='5'

   -- Get session info
   SELECT @nInputKey = InputKey FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   IF @nFunc = 850 -- PPA by ALL
   BEGIN
      IF @cType='CHECK'
      BEGIN
         -- Validate load plan status
         IF NOT EXISTS( SELECT 1
            FROM dbo.LoadPlan WITH (NOLOCK)
            WHERE LoadKey = @cLoadKey
               AND Status <= '9') -- 9=Closed
         BEGIN
            SET @nErrNo = 197001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid LoadKey
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO QUIT
         END

          -- Validate all pickslip already scan in
         IF EXISTS( SELECT 1
            FROM dbo.LoadPlan LP WITH (NOLOCK)
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
            WHERE LP.LoadKey = @cLoadKey
               AND [PI].ScanInDate IS NULL)
         BEGIN
            SET @nErrNo = 197002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Not Scan-in
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO QUIT
         END

         IF @cSkipChkPSlipMustScanOut <> '1'
         BEGIN
            -- Validate all pickslip already scan out
            IF EXISTS( SELECT 1
               FROM dbo.LoadPlan LP WITH (NOLOCK)
                  INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
                  LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
               WHERE LP.LoadKey = @cLoadKey
                  AND [PI].ScanOutDate IS NULL)
            BEGIN
               SET @nErrNo = 197003
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Not Scan-out
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO QUIT
            END
         END

      END

      IF @cType='GetStat'
      BEGIN
         IF @nPSKU IS NOT NULL
            SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
            FROM dbo.LoadPlanDetail AS LPD WITH (NOLOCK)
               INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            WHERE LPD.LoadKey = @cLoadKey
               --AND PD.Status >= '5'

         IF @nPQTY IS NOT NULL
            SELECT @nPQTY = SUM( PD.QTY)
            FROM dbo.LoadPlanDetail AS LPD WITH (NOLOCK)
               INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            WHERE LPD.LoadKey = @cLoadKey
               --AND PD.Status >= '5'

         IF @nVariance IS NOT NULL
            INSERT INTO @tP (StorerKey, SKU, QTY)
            SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
            FROM dbo.LoadPlanDetail AS LPD WITH (NOLOCK)
               INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            WHERE LPD.LoadKey = @cLoadKey
            GROUP BY PD.StorerKey, PD.SKU

         IF @nCSKU IS NOT NULL
            SELECT
               @nCSKU = COUNT( DISTINCT SKU)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND LoadKey = @cLoadKey

         IF @nCQTY IS NOT NULL
            SELECT
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND LoadKey = @cLoadKey

         IF @nVariance IS NOT NULL
            INSERT INTO @tC (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND LoadKey = @cLoadKey
            GROUP BY StorerKey, SKU

         -- SUM() might return NULL when no record
         SET @nCQTY = IsNULL( @nCQTY, 0)
         SET @nPQTY = IsNULL( @nPQTY, 0)

         -- Get variance
         IF @nVariance IS NOT NULL
         BEGIN
            IF EXISTS( SELECT TOP 1 1
               FROM @tP P
                  FULL OUTER JOIN @tC C ON (P.SKU = C.SKU)
               WHERE P.SKU IS NULL
                  OR C.SKU IS NULL
                  OR P.QTY <> C.QTY)
               SET @nVariance = 1
            ELSE
               SET @nVariance = 0
         END

      END
      IF @cType='QTY'
      BEGIN
         -- Get PPA details
         SELECT TOP 1
            @nQTY_PPA = PQTY,
            @nQTY_CHK = CQTY,
            @nRowRef = RowRef
         FROM rdt.rdtPPA WITH (NOLOCK)
         WHERE SKU = @cSKU
            AND StorerKey = @cStorer
            AND LoadKey = @cLoadKey

         -- Get pick QTY of the SKU
         IF @nRowRef IS NULL
            SELECT @nQTY_PPA = SUM( PD.QTY)
            FROM dbo.OrderDetail AS OD WITH (NOLOCK)
               INNER JOIN dbo.PickDetail AS PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
               INNER JOIN dbo.LoadPlan AS LP WITH (NOLOCK) ON OD.LoadKey = LP.LoadKey
            WHERE LP.LoadKey = @cLoadKey
               AND OD.StorerKey = @cStorer
               AND OD.SKU = @cSKU
               AND PD.Status >= @cPickConfirmStatus

      END

   END

Quit:

END
 

GO