SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: Customize Validate SP for rdt_DPRPL01                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2012-11-21 1.0  ChewKP     SOS#281897                                */
/************************************************************************/

CREATE PROC [RDT].[rdt_DPRPL01] (
   @nMobile     int,
   @nFunc       int,
   @cLangCode   nvarchar(3),
   @cFacility   nvarchar(5),
   @cStorerKey  nvarchar(15),
   @cUCCNo      nvarchar(20),
   @cToLoc      nvarchar(10),
   @nErrNo      int  OUTPUT,
   @cErrMsg     nvarchar(1024) OUTPUT -- screen limitation, 20 char max
   
   
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
      @cLottable01 AS NVARCHAR(18) 
   ,  @cVFCOO      AS NVARCHAR(10)
   ,  @cToLocVFCOO AS NVARCHAR(10)
   ,  @cSKU        AS NVARCHAR(20)
   ,  @cWaveKey    AS NVARCHAR(10)
   ,  @cOrderKey   AS NVARCHAR(10)
   ,  @cLot        AS NVARCHAR(10)

   SET @cLottable01 = ''
   SET @cVFCOO      = ''
   SET @cToLocVFCOO = ''
   SET @nErrNo      = 0 
   SET @cERRMSG     = ''
   SET @cSKU        = ''
   SET @cWaveKey    = ''
   SET @cOrderKey   = ''
   SET @cLot        = ''

   SELECT @cWaveKey = ReplenNo 
         ,@cSKU     = SKU
         ,@cLot     = Lot
   FROM dbo.Replenishment WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND RefNo  = @cUCCNo
   
   
   SELECT @cOrderKey = OrderKey 
   FROM dbo.WaveDetail WITH (NOLOCK)
   WHERE WaveKey = @cWaveKey
   
   SELECT TOP 1 @cLottable01 = Lottable01  
   FROM dbo.LotAttribute WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND SKU = @cSKU
   AND Lot = @cLot
   
   
--   SELECT TOP 1 @cLottable01 = OD.Lottable01  
--   FROM dbo.PickDetail PD WITH (NOLOCK)
--   INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON OD.ORderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber 
--   WHERE PD.OrderKey = @cOrderKey
--   AND PD.SKU = @cSKU
--   AND PD.StorerKey = @cStorerKey
   
--   IF ISNULL(@cLottable01,'')  <> ''
--   BEGIN
      SELECT @cVFCOO = Short 
      FROM dbo.Codelkup WITH (NOLOCK) 
      WHERE LISTNAME = 'VFCOO' AND CODE = @cLottable01
      
      
      
      IF EXISTS ( SELECT 1 FROM dbo.LotxLocxID LLI
                  INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot AND LA.StorerKey = LLI.StorerKey 
                  INNER JOIN dbo.CODELKUP CD WITH (NOLOCK) ON CD.Code = LA.Lottable01 AND CD.LISTNAME = 'VFCOO'
                  WHERE LLI.StorerKey = @cStorerKey
                  AND LLI.SKU = @cSKU
                  AND (LLI.QTY - LLI.QTYPICKED) > 0 
                  AND CD.SHORT <> @cVFCOO
                  AND Loc = @cToLoc ) 
      BEGIN
          
          SET @nErrNo = 81601
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidVFCOO
            
      END                  
--   END
   
   
END

GO