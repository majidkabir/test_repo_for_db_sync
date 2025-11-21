SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_851ExtRefNo01                                   */
/* Purpose: Check if user login with printer                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 2022-02-16 1.0  yeekung   WMS-21563 Created                          */
/************************************************************************/

CREATE   PROC [RDT].[rdt_851ExtRefNo01] (
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

   IF @nFunc = 851 -- PPA by Refno
   BEGIN
      IF @cType='CHECK'
      BEGIN
         -- Validate load plan status
         IF NOT EXISTS( SELECT 1
            FROM dbo.orders WITH (NOLOCK)
            WHERE trackingno = @cRefNo
               AND storerkey = @cStorer) -- 9=Closed
         BEGIN
            SET @nErrNo = 197051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Ref#
            GOTO QUIT
         END
      END
      IF @cType='GetStat'
      BEGIN
         IF @nCSKU IS NOT NULL
            SELECT
               @nCSKU = COUNT( DISTINCT SKU)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND RefKey = @cRefNo

         IF @nCQTY IS NOT NULL
            SELECT
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND RefKey = @cRefNo

         IF @nVariance IS NOT NULL
            INSERT INTO @tP (StorerKey, SKU, QTY)
            SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
            FROM dbo.orders OD WITH (NOLOCK) 
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey 
            WHERE OD.trackingno = @cRefNo
            GROUP BY PD.StorerKey, PD.SKU

         IF @nVariance IS NOT NULL
            INSERT INTO @tC (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND RefKey = @cRefNo
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
            AND RefKey = @cRefNo

          -- Get pick QTY from load
         IF @nRowRef IS NULL
            SELECT @nQTY_PPA = SUM( PD.QTY)
            FROM dbo.orders O WITH (NOLOCK)
               JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey=O.orderkey
            WHERE O.trackingno = @cRefNo
               AND O.storerkey = @cStorer
               AND PD.SKU  = @cSKU
               AND PD.Status >= @cPickConfirmStatus

      END
   END

Quit:

END
 

GO