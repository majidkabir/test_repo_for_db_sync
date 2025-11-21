SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1628SkuAttrib02                                 */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: PVH Show SKU attribute                                      */  
/*                                                                      */  
/* Called from: rdt_ClusterPickSkuAttribute                             */  
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */  
/* 2020-08-06  1.0  James    WMS-14525. Created                         */  
/* 2020-09-25  1.1  James    WMS-15322 Add display lot01 (james01)      */
/************************************************************************/  

CREATE PROC [RDT].[rdt_1628SkuAttrib02] (  
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,
   @nInputKey     INT,
   @cStorerKey    NVARCHAR( 15),  
   @cSKU          NVARCHAR( 20),  
   @cAltSKU       NVARCHAR( 20)  OUTPUT,
   @cDescr        NVARCHAR( 60)  OUTPUT,  
   @cStyle        NVARCHAR( 20)  OUTPUT,  
   @cColor        NVARCHAR( 10)  OUTPUT,  
   @cSize         NVARCHAR( 5)   OUTPUT,  
   @cColor_Descr  NVARCHAR( 30)  OUTPUT,  
   @cAttribute01  NVARCHAR( 20)  OUTPUT,  
   @cAttribute02  NVARCHAR( 20)  OUTPUT,  
   @cAttribute03  NVARCHAR( 20)  OUTPUT,  
   @cAttribute04  NVARCHAR( 20)  OUTPUT,  
   @cAttribute05  NVARCHAR( 20)  OUTPUT,  
   @cAttribute06  NVARCHAR( 20)  OUTPUT,  
   @cAttribute07  NVARCHAR( 20)  OUTPUT,  
   @cAttribute08  NVARCHAR( 20)  OUTPUT,  
   @cAttribute09  NVARCHAR( 20)  OUTPUT,  
   @cAttribute10  NVARCHAR( 20)  OUTPUT,  
   @nErrNo        INT            OUTPUT,  
   @cErrMsg       NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 char max  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @nSKUIsBlank    INT
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @cLottable01    NVARCHAR( 18)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cPutAwayZone   NVARCHAR( 10)
   DECLARE @cPickZone      NVARCHAR( 10)
   DECLARE @cLottable02    NVARCHAR( 18)
   DECLARE @dLottable04    DATETIME
   DECLARE @cLOC           NVARCHAR( 10)
   DECLARE @cLogicalLoc    NVARCHAR( 10)   
   
   SELECT @cAttribute01 = ''
   SELECT @cAttribute02 = ''
   SELECT @cAttribute03 = ''
   
   SELECT @cUserName = UserName,
          @cLOC = V_LOC, 
          @cLoadKey = V_LoadKey, 
          @cFacility = Facility,
          @cPutAwayZone = V_String10,
          @cPickZone = V_String11
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SET @nSKUIsBlank = 0

   IF ISNULL( @cSKU, '') = ''
   BEGIN
      SELECT @cSKU = V_SKU FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile
      SET @nSKUIsBlank = 1
   END

   IF @nStep = 7
   BEGIN
      SELECT TOP 1 @cLottable01 = LA.Lottable01
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN RDT.RDTPickLock RPL WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey)
      JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
      WHERE  RPL.Status = '1'
         AND RPL.AddWho = @cUserName
         AND PD.Status = '0'
         AND L.Facility = @cFacility
         AND PD.SKU = @cSKU
         AND PD.LOC = @cLOC
      ORDER BY 1
   END
   ELSE
   BEGIN
      SET @cLogicalLoc = ''
      SELECT @cLogicalLoc = LogicalLocation
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cLOC
      AND Facility = @cFacility

      SELECT TOP 1
         @cLottable01 = LA.Lottable01
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK)
         ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)    -- (james09)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
      WHERE O.StorerKey = @cStorerKey        -- tlting03
         AND PD.Status = '0'
         AND O.LoadKey = @cLoadKey
         AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( LOC.PutAwayZone = @cPutAwayZone))
         AND (( ISNULL( @cPickZone, '') = '') OR ( LOC.PickZone = @cPickZone))
         AND LOC.Facility = @cFacility
         AND RTRIM(LOC.LogicalLocation) + RTRIM(PD.SKU) + ISNULL(RTRIM(LA.Lottable02), '') + ISNULL(CONVERT( NVARCHAR( 10), LA.Lottable04, 120), 0) >
               RTRIM(@cLogicalLoc) + RTRIM(@cSKU) + RTRIM(@cLottable02) + ISNULL(CONVERT( NVARCHAR( 10), @dLottable04, 120), 0)--@dLottable04
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTPickLock RPL WITH (NOLOCK)
            WHERE PD.StorerKey = RPL.StorerKey AND PD.OrderKey = RPL.OrderKey AND PD.SKU = RPL.SKU AND RPL.Status = '1')
      ORDER BY 1
   END

   SET @cAttribute02 = @cLottable01
      
   IF @nStep = 8
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @nSKUIsBlank = 1
            SET @cDescr = ''-- short pick don't want show sku descr
      END

      GOTO Quit
   END

   GOTO Quit         
           
   Quit:
END  

GO