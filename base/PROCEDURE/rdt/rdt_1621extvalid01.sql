SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1621ExtValid01                                  */
/* Purpose: Cluster Pick Extended Validate SP                           */
/*          If both carton & ea field enter with value, prompt error    */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 10-Oct-2015 1.0  James      SOS342407 - Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_1621ExtValid01] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerkey       NVARCHAR( 15), 
   @cWaveKey         NVARCHAR( 10), 
   @cLoadKey         NVARCHAR( 10), 
   @cOrderKey        NVARCHAR( 10), 
   @cLoc             NVARCHAR( 10), 
   @cDropID          NVARCHAR( 20), 
   @cSKU             NVARCHAR( 20), 
   @nQty             INT, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cFieldAttr13 NVARCHAR( 1), 
           @cFieldAttr15 NVARCHAR( 1),
           @cEAQty       NVARCHAR( 5), 
           @cCtnQty      NVARCHAR( 5), 
           @cPickSlipNo  NVARCHAR( 10), 
           @cUserName    NVARCHAR( 18), 
           @cDropID_SKU  NVARCHAR( 20), 
           @cCaseCount   NVARCHAR( 10), 
           @nSKUCnt      INT, 
           @nSum_DropID  INT, 
           @nTtlQty      INT,
           @nEAQty       INT, 
           @nCtnQty      INT, 
           @nCaseCount   INT,            
           @fCaseCount   FLOAT
   
   SET @nErrNo = 0

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 8
      BEGIN
         SELECT @cFieldAttr13 = FieldAttr13, 
                @cFieldAttr15 = FieldAttr15, 
                @cEAQty       = I_Field13, 
                @cCtnQty      = I_Field15, 
                @cUserName    = UserName 
         FROM rdt.rdtMobRec WITH (NOLOCK) 
         WHERE Mobile = @nMobile

         IF @cFieldAttr13 = '' AND @cFieldAttr15 = ''
         BEGIN
            IF @cEAQty <> '' AND @cCtnQty <> ''
            BEGIN
               SELECT @nErrNo = 94901
               SELECT @cErrMsg = 'ONLY EA OR CTN'
            END
         END

         SET @nEAQty = @cEAQty
         SET @nCtnQty = @cCtnQty
         
         SELECT @fCaseCount = PACK.CaseCnt
         FROM dbo.PACK PACK WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
         WHERE SKU.Storerkey = @cStorerKey
         AND   SKU.SKU = @cSKU

         SET @cCaseCount = rdt.rdtFormatFloat( @fCaseCount)
         SET @nCaseCount = @cCaseCount

         SET @nTtlQty = ( @nCtnQty * @nCaseCount) + @nEAQty
         
         SELECT @nSKUCnt = COUNT( DISTINCT SKU)
         FROM RDT.RDTPICKLOCK WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         AND   StorerKey = @cStorerKey
         AND   DropID = @cDropID
         AND   AddWho = @cUserName
         AND   Status In ('1', '5')

         -- If current case already is mix sku carton, cannot put full carton in
         IF @nSKUCnt > 1 AND ( @nTtlQty % @nCaseCount = 0)
         BEGIN
            SELECT @nErrNo = 94902
            SELECT @cErrMsg = 'ONLY EA OR CTN'
         END
                     
         SELECT @cDropID_SKU = SKU, 
                @nSum_DropID = ISNULL( SUM( PICKQTY), 0)
         FROM RDT.RDTPICKLOCK WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         AND   StorerKey = @cStorerKey
         AND   DropID = @cDropID
         AND   AddWho = @cUserName
         AND   Status In ('1', '5')
         GROUP BY SKU

         SELECT @fCaseCount = PACK.CaseCnt
         FROM dbo.PACK PACK WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
         WHERE SKU.Storerkey = @cStorerKey
         AND   SKU.SKU = @cDropID_SKU

         IF @nSum_DropID > 0
         BEGIN
            -- Current dropid already is a full carton, cannot use same dropid
            IF ( @nSum_DropID % @nCaseCount = 0) AND @nEAQty > 0
            BEGIN
               SELECT @nErrNo = 94903
               SELECT @cErrMsg = 'DropID In Use'
            END                                
         END

         IF @nSum_DropID % @nCaseCount <> 0 AND @nCtnQty > 0
         BEGIN
            SELECT @nErrNo = 94904
            SELECT @cErrMsg = 'DropID In Use'
         END                                
         
      END   -- IF @nStep = 8
   END   -- IF @nInputKey = 1

QUIT:

GO