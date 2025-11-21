SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_HnMPTLGetTask01                                       */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: Get next SKU to Pick                                              */
/*                                                                            */
/* Called from: rdtfnc_PTL_OrderPicking                                       */
/*                                                                            */
/* Exceed version: 5.4                                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author    Purposes                                        */
/* 23-Jun-2014 1.0  James     Created                                         */
/* 03-Oct-2014 1.1  Ung       SOS318953 Chg BypassTCPSocketClient to DeviceID */
/* 12-Dec-2014 1.2  James     Revamp error msg (james01)                      */
/******************************************************************************/

CREATE PROC [RDT].[rdt_HnMPTLGetTask01] (
     @nMobile          INT
    ,@nFunc            INT
    ,@cFacility        NVARCHAR(5)
    ,@cStorerKey       NVARCHAR( 15)  
    ,@cCartID          NVARCHAR( 10)  
    ,@cUserName        NVARCHAR( 18)  
    ,@cLangCode        NVARCHAR( 3)
    ,@cPickZone        NVARCHAR( 10)
    ,@nErrNo           INT          OUTPUT
    ,@cErrMsg          NVARCHAR(250) OUTPUT -- screen limitation, 20 char max
    ,@cSKU             NVARCHAR(20) = ''   OUTPUT
    ,@cSKUDescr        NVARCHAR(60) = ''   OUTPUT 
    ,@cLoc             NVARCHAR(10) = ''   OUTPUT
    ,@cLot             NVARCHAR(10) = ''   OUTPUT
    ,@cLottable01      NVARCHAR(18) = ''   OUTPUT 
    ,@cLottable02      NVARCHAR(18) = ''   OUTPUT 
    ,@cLottable03      NVARCHAR(18) = ''   OUTPUT 
    ,@dLottable04      DATETIME     = NULL OUTPUT 
    ,@dLottable05      DATETIME     = NULL OUTPUT 
    ,@nTotalOrder      INT          = 0    OUTPUT
    ,@nTotalQty        INT          = 0    OUTPUT
    ,@cPDDropID        NVARCHAR(20) = ''   OUTPUT
    ,@cPDLoc           NVARCHAR(20) = ''   OUTPUT
    ,@cPDToLoc         NVARCHAR(20) = ''   OUTPUT
    ,@cPDID            NVARCHAR(20) = ''   OUTPUT 
    ,@cWaveKey         NVARCHAR(10) = ''   OUTPUT 
    
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   Declare @b_success             INT
          ,@cDeviceProfileLogKey  NVARCHAR(10)
          ,@cDeviceID             NVARCHAR(10) 
          ,@cPTLPKZoneReq         NVARCHAR( 1) 

   CREATE TABLE #t_orders2pick(
      DeviceID       NVARCHAR(20), 
      OrderKey       NVARCHAR(10))

   INSERT INTO #t_orders2pick( DeviceID, OrderKey) 
   SELECT @cCartID AS DeviceID, OrderKey 
   FROM dbo.DEVICEPROFILELOG WITH (NOLOCK) 
   WHERE DEVICEPROFILEKEY IN ( 
         SELECT DEVICEPROFILEKEY FROM dbo.DEVICEPROFILE WITH (NOLOCK) 
         WHERE DEVICEID = @cCartID) 
   AND   [STATUS] IN ('1', '3')

   SET @cPTLPKZoneReq = rdt.rdtGetConfig( @nFunc, 'PTLPicKZoneReq', @cStorerKey)
   IF @cPTLPKZoneReq = '0'
      SET @cPTLPKZoneReq = ''

   -- Get login info
   SELECT @cDeviceID = DeviceID FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
   
   -- GET Task
   SELECT TOP 1
      @cLOC = PTL.Loc,
      @cSKU = PTL.SKU,
      @cSKUDescr = SKU.Descr,
      @cLottable01 = LA.Lottable01,
      @cLottable02 = LA.Lottable02,
      @cLottable03 = LA.Lottable03,
      @dLottable04 = LA.Lottable04,
      @dLottable05 = LA.Lottable05,
      @cLot        = PTL.Lot,
      @cPDDropID   = PD.DropID,
      @cPDLoc      = PD.Loc,
      @cPDToLoc    = PD.ToLoc,
      @cPDID       = PD.ID, 
      @cWaveKey    = O.UserDefine09 
   FROM PTLTran PTL WITH (NOLOCK)
   INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = PTL.SKU AND SKU.StorerKey = PTL.StorerKey
   INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PTL.Loc
   INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = PTL.Lot
   INNER JOIN dbo.PutawayZone P WITH (NOLOCK) ON Loc.PutawayZone = P.PutawayZone
   INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.StorerKey = PTl.StorerKey AND PD.OrderKey = PTL.OrderKey AND PD.SKU = PTL.SKU AND PD.Lot = PTL.Lot 
                                                   AND CASE WHEN ISNULL(PD.ToLoc,'') = '' THEN PD.Loc ELSE PD.ToLoc END = PTL.Loc)
   INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey 
   INNER JOIN #t_orders2pick t ON PD.OrderKey = t.OrderKey
   WHERE PTL.StorerKey  = @cStorerKey
      AND PTL.Status    = '0'
      AND PTL.DeviceID  = @cCartID
      AND LOC.PickZone = CASE WHEN @cPTLPKZoneReq = '1' THEN @cPickZone ELSE LOC.PickZone END  
      AND PTL.LOC > @cLOC
   ORDER BY Loc.LogicalLocation, PTL.LOC, PTL.SKU, PTL.OrderKey
   
   IF @@ROWCOUNT = 0  
   BEGIN
      -- Get Task From Next SKU,  Same Loc
      SELECT TOP 1
         @cLOC = PTL.Loc,
         @cSKU = PTL.SKU,
         @cSKUDescr = SKU.Descr,
         @cLottable01 = LA.Lottable01,
         @cLottable02 = LA.Lottable02,
         @cLottable03 = LA.Lottable03,
         @dLottable04 = LA.Lottable04,
         @dLottable05 = LA.Lottable05,
         @cLot        = PTL.Lot,
         @cPDDropID   = PD.DropID,
         @cPDLoc      = PD.Loc,
         @cPDToLoc    = PD.ToLoc,
         @cPDID       = PD.ID, -- (ChewKP01)
         @cWaveKey    = O.UserDefine09 -- (ChewKP01)
      FROM PTLTran PTL WITH (NOLOCK)
      INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = PTL.SKU AND SKU.StorerKey = PTL.StorerKey
      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PTL.Loc
      INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = PTL.Lot
      INNER JOIN dbo.PutawayZone P WITH (NOLOCK) ON Loc.PutawayZone = P.PutawayZone
      INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.StorerKey = PTl.StorerKey AND PD.OrderKey = PTL.OrderKey AND PD.SKU = PTL.SKU AND PD.Lot = PTL.Lot 
                                                   AND CASE WHEN ISNULL(PD.ToLoc,'') = '' THEN PD.Loc ELSE PD.ToLoc END = PTL.Loc)
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey 
      INNER JOIN #t_orders2pick t ON PD.OrderKey = t.OrderKey
      WHERE PTL.StorerKey = @cStorerKey
      AND PTL.Status   = '0'
      AND PTL.DeviceID = @cCartID
      AND PTL.Loc      = @cLoc
      AND LOC.PickZone = CASE WHEN @cPTLPKZoneReq = '1' THEN @cPickZone ELSE LOC.PickZone END  -- (james02)
      ORDER BY Loc.LogicalLocation, PTL.LOC, PTL.SKU, PTL.OrderKey    
   
      IF @@ROWCOUNT = 0 
      BEGIN
         IF @cDeviceID <> ''
         BEGIN
            -- Initialize LightModules
            EXEC [dbo].[isp_DPC_TerminateAllLight] 
                  @cStorerKey
                 ,@cCartID  
                 ,@b_Success    OUTPUT  
                 ,@nErrNo       OUTPUT
                 ,@cErrMsg      OUTPUT
         
         END
            
         SET @nErrNo = 51001
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NoTask!'
         GOTO Quit  
      END
   END

   IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)
               WHERE DeviceID = @cCartID 
               AND Status = '3') 
   BEGIN            
      UPDATE dbo.DeviceProfile WITH (ROWLOCK) SET 
         [Status] = '3' 
      WHERE DeviceID = @cCartID
      AND   Status = '1'
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 51002
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDPFail'
         GOTO Quit  
      END   
   
      UPDATE DL WITH (ROWLOCK) SET 
         [Status] = '3'
      FROM dbo.DeviceProfileLog DL 
      INNER JOIN  dbo.DeviceProfile D ON D.DeviceProfileKey = DL.DeviceProfileKey
      WHERE D.DeviceID = @cCartID
      AND   DL.Status = '1'
      
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 51003
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDPLogFail'
         GOTO Quit  
      END   
   END
   
   SELECT @nTotalOrder = Count(Distinct PTL.OrderKey) 
   FROM dbo.PTLTran PTL WITH (NOLOCK) 
   INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.OrderKey = PTL.OrderKey
	INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
	INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.StorerKey = PTl.StorerKey AND PD.OrderKey = PTL.OrderKey AND PD.SKU = PTL.SKU AND PD.Lot = PTL.Lot 
                                                   AND CASE WHEN ISNULL(PD.ToLoc,'') = '' THEN PD.Loc ELSE PD.ToLoc END = PTL.Loc)
	INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey 
	INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = PTL.Lot  
	INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
	WHERE PTL.DeviceID = @cCartID
	  AND PTL.SKU      = @cSKU
	  AND DL.Status    = '3'
	  AND PD.SKU       = @cSKU
	  AND PD.DropID    = @cPDDropID
	  AND PD.ToLoc     = @cPDToLoc
	  AND PD.Loc       = @cPDLoc
	  AND LA.Lottable01 = @cLottable01 
	  AND LA.Lottable02 = @cLottable02 
	  AND LA.Lottable03 = @cLottable03 
	  AND LA.Lottable04 = @dLottable04 
	  AND LA.Lottable05 = @dLottable05 
	  AND PD.Lot        = @cLot        
	  AND PD.ID         = @cPDID       
	  AND PTL.Status   = '0'
	  AND O.UserDefine09 = CASE WHEN ISNULL(PD.ToLoc,'') <> '' THEN @cWaveKey ELSE O.UserDefine09 END    
     AND LOC.PickZone = CASE WHEN @cPTLPKZoneReq = '1' THEN @cPickZone ELSE LOC.PickZone END  
	
	SELECT @nTotalQty = SUM(PTL.ExpectedQty) 
	FROM dbo.PTLTran PTL WITH (NOLOCK) 
	INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.OrderKey = PTL.OrderKey
	INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
	INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = PTL.Lot  
	INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON PTL.LOC = LOC.LOC
	WHERE PTL.DeviceID = @cCartID
	  AND D.DeviceID = @cCartID
	  AND PTL.SKU      = @cSKU
	  AND DL.Status    = '3'
	  AND LA.Lottable01 = @cLottable01 
	  AND LA.Lottable02 = @cLottable02 
	  AND LA.Lottable03 = @cLottable03 
	  AND LA.Lottable04 = @dLottable04 
	  AND LA.Lottable05 = @dLottable05 
	  AND PTL.Status   = '0'
     AND LOC.PickZone = CASE WHEN @cPTLPKZoneReq = '1' THEN @cPickZone ELSE LOC.PickZone END  
     AND EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
                  WHERE PD.StorerKey = PTl.StorerKey 
                  AND   PD.OrderKey = PTL.OrderKey 
                  AND   PD.SKU = PTL.SKU 
                  AND   PD.Lot = PTL.Lot 
                  AND   CASE WHEN ISNULL(PD.ToLoc,'') = '' THEN PD.Loc ELSE PD.ToLoc END = PTL.Loc
	               AND   PD.SKU       = @cSKU
	               AND   PD.DropID    = @cPDDropID
	               AND   PD.ToLoc     = @cPDToLoc
	               AND   PD.Loc       = @cPDLoc
	               AND   PD.Lot       = @cLot        
	               AND   PD.ID        = @cPDID
	               AND   O.UserDefine09 = CASE WHEN ISNULL(PD.ToLoc,'') <> '' THEN @cWaveKey ELSE O.UserDefine09 END)

   IF @cDeviceID <> ''
   BEGIN
      -- Initialize LightModules
      EXEC [dbo].[isp_DPC_TerminateAllLight] 
            @cStorerKey
           ,@cCartID  
           ,@b_Success    OUTPUT  
           ,@nErrNo       OUTPUT
           ,@cErrMsg      OUTPUT
      
      IF @nErrNo <> 0 
      BEGIN
          GOTO Quit
      END
   END

Quit:
END

GO