SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_PTL_OrderPicking_GetNextTask                          */
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
/* 26-Feb-2013 1.0  ChewKP    Created                                         */
/* 11-Jun-2013 1.1  ChewKP    SOS#280749 PTL Enhancement (ChewKP01)           */
/* 04-Jun-2014 1.2  James     Add bypass exec dpc directly (james01)          */
/*                            SOS303322 - Filter by pickzone (james02)        */
/* 03-Oct-2014 1.3  Ung       SOS318953 Chg BypassTCPSocketClient to DeviceID */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTL_OrderPicking_GetNextTask] (
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
    ,@cPDID            NVARCHAR(20) = ''   OUTPUT -- (ChewKP01)
    ,@cWaveKey         NVARCHAR(10) = ''   OUTPUT -- (ChewKP01)
    
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
          ,@cPTLPKZoneReq         NVARCHAR( 1) -- (james02)

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
   
   IF @cSKU = ''
   BEGIN
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
         @cPDID       = PD.ID, -- (ChewKP01)
         @cWaveKey    = O.UserDefine09 -- (ChewKP01)
      FROM PTLTran PTL WITH (NOLOCK)
      --JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PTL.StorerKey = PD.StorerKey AND PTL.OrderKey = PD.OrderKey)
      INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = PTL.SKU AND SKU.StorerKey = PTL.StorerKey
      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PTL.Loc
      INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = PTL.Lot
      INNER JOIN dbo.PutawayZone P WITH (NOLOCK) ON Loc.PutawayZone = P.PutawayZone
      INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.StorerKey = PTl.StorerKey AND PD.OrderKey = PTL.OrderKey AND PD.SKU = PTL.SKU AND PD.Lot = PTL.Lot 
                                                      AND CASE WHEN ISNULL(PD.ToLoc,'') = '' THEN PD.Loc ELSE PD.ToLoc END = PTL.Loc)
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey -- (ChewKP01)
      INNER JOIN #t_orders2pick t ON PD.OrderKey = t.OrderKey
      WHERE PTL.StorerKey  = @cStorerKey
         AND PTL.Status    = '0'
         AND PTL.DeviceID  = @cCartID
         AND LOC.PickZone = CASE WHEN @cPTLPKZoneReq = '1' THEN @cPickZone ELSE LOC.PickZone END  -- (james02)
      ORDER BY P.Descr, Loc.LogicalLocation, PTL.LOC, PD.ID, PD.DropID, PTL.SKU, PTL.OrderKey
   END
   ELSE
   BEGIN
      -- GET Task, Same SKU , Same Loc Diff Lottables
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
      --JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PTL.StorerKey = PD.StorerKey AND PTL.OrderKey = PD.OrderKey)
      INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = PTL.SKU AND SKU.StorerKey = PTL.StorerKey
      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PTL.Loc
      INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = PTL.Lot
      INNER JOIN dbo.PutawayZone P WITH (NOLOCK) ON Loc.PutawayZone = P.PutawayZone
      INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.StorerKey = PTl.StorerKey AND PD.OrderKey = PTL.OrderKey AND PD.SKU = PTL.SKU AND PD.Lot = PTL.Lot 
                                                      AND CASE WHEN ISNULL(PD.ToLoc,'') = '' THEN PD.Loc ELSE PD.ToLoc END = PTL.Loc)
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey -- (ChewKP01)
      INNER JOIN #t_orders2pick t ON PD.OrderKey = t.OrderKey
      WHERE PTL.StorerKey  = @cStorerKey
         AND PTL.Status    = '0'
         AND PTL.DeviceID  = @cCartID
         AND PTL.SKU       = @cSKU 
         AND PTL.Loc       = @cLoc
         AND LOC.PickZone = CASE WHEN @cPTLPKZoneReq = '1' THEN @cPickZone ELSE LOC.PickZone END  -- (james02)
      ORDER BY P.Descr, Loc.LogicalLocation, PTL.LOC, PD.ID, PD.DropID, PTL.SKU, PTL.OrderKey    
   END
   
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
      --JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PTL.StorerKey = PD.StorerKey AND PTL.OrderKey = PD.OrderKey)
      INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = PTL.SKU AND SKU.StorerKey = PTL.StorerKey
      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PTL.Loc
      INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = PTL.Lot
      INNER JOIN dbo.PutawayZone P WITH (NOLOCK) ON Loc.PutawayZone = P.PutawayZone
      INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.StorerKey = PTl.StorerKey AND PD.OrderKey = PTL.OrderKey AND PD.SKU = PTL.SKU AND PD.Lot = PTL.Lot 
                                                      AND CASE WHEN ISNULL(PD.ToLoc,'') = '' THEN PD.Loc ELSE PD.ToLoc END = PTL.Loc)
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey -- (ChewKP01)
      INNER JOIN #t_orders2pick t ON PD.OrderKey = t.OrderKey
      WHERE PTL.StorerKey = @cStorerKey
         AND PTL.Status   = '0'
         AND PTL.DeviceID = @cCartID
         AND PTL.Loc      = @cLoc
         AND LOC.PickZone = CASE WHEN @cPTLPKZoneReq = '1' THEN @cPickZone ELSE LOC.PickZone END  -- (james02)
      ORDER BY P.Descr, Loc.LogicalLocation, PTL.LOC, PD.ID, PD.DropID, PTL.SKU, PTL.OrderKey    
       
      
      IF @@ROWCOUNT = 0
      BEGIN
          -- Get Task From Same SKU Next Loc
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
         --JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PTL.StorerKey = PD.StorerKey AND PTL.OrderKey = PD.OrderKey)
         INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = PTL.SKU AND SKU.StorerKey = PTL.StorerKey
         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PTL.Loc
         INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = PTL.Lot
         INNER JOIN dbo.PutawayZone P WITH (NOLOCK) ON Loc.PutawayZone = P.PutawayZone
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.StorerKey = PTl.StorerKey AND PD.OrderKey = PTL.OrderKey AND PD.SKU = PTL.SKU AND PD.Lot = PTL.Lot 
                                                         AND CASE WHEN ISNULL(PD.ToLoc,'') = '' THEN PD.Loc ELSE PD.ToLoc END = PTL.Loc)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey -- (ChewKP01)
         INNER JOIN #t_orders2pick t ON PD.OrderKey = t.OrderKey
         WHERE PTL.StorerKey = @cStorerKey
            AND PTL.Status   = '0'
            AND PTL.DeviceID = @cCartID
            AND PTL.SKU      = @cSKU
            AND LOC.PickZone = CASE WHEN @cPTLPKZoneReq = '1' THEN @cPickZone ELSE LOC.PickZone END  -- (james02)
         ORDER BY P.Descr, Loc.LogicalLocation, PTL.LOC, PD.ID, PD.DropID, PTL.SKU, PTL.OrderKey    
         
         
         IF @@ROWCOUNT = 0
         BEGIN
            -- Get Task From Next SKU Next Loc
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
            --JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PTL.StorerKey = PD.StorerKey AND PTL.OrderKey = PD.OrderKey)
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = PTL.SKU AND SKU.StorerKey = PTL.StorerKey
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PTL.Loc
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = PTL.Lot
            INNER JOIN dbo.PutawayZone P WITH (NOLOCK) ON Loc.PutawayZone = P.PutawayZone
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.StorerKey = PTl.StorerKey AND PD.OrderKey = PTL.OrderKey AND PD.SKU = PTL.SKU AND PD.Lot = PTL.Lot 
                                                            AND CASE WHEN ISNULL(PD.ToLoc,'') = '' THEN PD.Loc ELSE PD.ToLoc END = PTL.Loc)
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey -- (ChewKP01)
            INNER JOIN #t_orders2pick t ON PD.OrderKey = t.OrderKey
            WHERE PTL.StorerKey = @cStorerKey
               AND PTL.Status   = '0'
               AND PTL.DeviceID = @cCartID
               AND LOC.PickZone = CASE WHEN @cPTLPKZoneReq = '1' THEN @cPickZone ELSE LOC.PickZone END  -- (james02)
            ORDER BY P.Descr, Loc.LogicalLocation, PTL.LOC, PD.ID, PD.DropID, PTL.SKU, PTL.OrderKey    
            
            IF @@ROWCOUNT = 0 
            BEGIN
               -- (james01)
               IF @cDeviceID <> ''
               BEGIN
                  -- Initialize LightModules
                  EXEC [dbo].[isp_DPC_TerminateAllLight] 
                        @cStorerKey
                       ,@cCartID  
                       ,@b_Success    OUTPUT  
                       ,@nErrNo       OUTPUT
                       ,@cErrMsg      OUTPUT
               
      --            IF @nErrNo <> 0 
      --            BEGIN
      --                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') 
      --                GOTO Quit
      --            END
               END
                  
               SET @nErrNo = 79801
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NoTask!'
               GOTO Quit  
            END
         END
         
             
      END
      
   END  
   
   
   
   -- Update PTLTran, DeviceProfile, DeviceProfileLog to Status = '3' Indicate Pick in Progress
   
--   UPDATE dbo.PTLTran
--   SET Status = '3'
--   WHERE StorerKey = @cStorerKey
--      AND Status = '0'
--      AND DeviceID = @cCartID
--      AND SKU      = @cSKU
--      AND Loc      = @cLoc
--      AND Lot      = @cLot
--   
--   IF @@ERROR <> 0
--   BEGIN
--       SET @nErrNo = 79802
--       SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPTLTranFail'
--       GOTO Quit  
--   END
   
   -- (ChewKP01)
   IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)
               WHERE DeviceID = @cCartID 
               AND Status = '3') 
   BEGIN            
      UPDATE dbo.DeviceProfile
      SET Status = '3' --, DeviceProfileLogKey = @cDeviceProfileLogKey (ChewKP01)
      WHERE DeviceID = @cCartID
      AND Status = '1'
      
      IF @@ERROR <> 0
      BEGIN
          SET @nErrNo = 79803
          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDPFail'
          GOTO Quit  
      END   
   
      UPDATE dbo.DeviceProfileLog 
         SET Status = '3'
      FROM dbo.DeviceProfileLog DL WITH (NOLOCK)
      INNER JOIN  dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
      WHERE D.DeviceID = @cCartID
      AND DL.Status = '1'
      
      
      IF @@ERROR <> 0
      BEGIN
          SET @nErrNo = 79804
          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDPLogFail'
          GOTO Quit  
      END   
   END

   
   SELECT @nTotalOrder = Count(Distinct PTL.OrderKey) 
   FROM dbo.PTLTran PTL WITH (NOLOCK) 
   INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.OrderKey = PTL.OrderKey
	INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
	--INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = PTL.OrderKey
	INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.StorerKey = PTl.StorerKey AND PD.OrderKey = PTL.OrderKey AND PD.SKU = PTL.SKU AND PD.Lot = PTL.Lot 
                                                   AND CASE WHEN ISNULL(PD.ToLoc,'') = '' THEN PD.Loc ELSE PD.ToLoc END = PTL.Loc)
	INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey -- (ChewKP01)
	INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = PTL.Lot  -- (ChewKP01)
	INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
	WHERE PTL.DeviceID = @cCartID
	  AND PTL.SKU      = @cSKU
	  AND DL.Status    = '3'
	  AND PD.SKU       = @cSKU
	  AND PD.DropID    = @cPDDropID
	  AND PD.ToLoc     = @cPDToLoc
	  AND PD.Loc       = @cPDLoc
	  AND LA.Lottable01 = @cLottable01 -- (ChewKP01)
	  AND LA.Lottable02 = @cLottable02 -- (ChewKP01)
	  AND LA.Lottable03 = @cLottable03 -- (ChewKP01)
	  AND LA.Lottable04 = @dLottable04 -- (ChewKP01)
	  AND LA.Lottable05 = @dLottable05 -- (ChewKP01)
	  AND PD.Lot        = @cLot        -- (ChewKP01)
	  AND PD.ID         = @cPDID       -- (ChewKP01)
	  AND PTL.Status   = '0'
	  AND O.UserDefine09 = CASE WHEN ISNULL(PD.ToLoc,'') <> '' THEN @cWaveKey ELSE O.UserDefine09 END    -- (ChewKP01)
     AND LOC.PickZone = CASE WHEN @cPTLPKZoneReq = '1' THEN @cPickZone ELSE LOC.PickZone END  -- (james02)
	
	SELECT @nTotalQty = SUM(PTL.ExpectedQty) 
	FROM dbo.PTLTran PTL WITH (NOLOCK) 
	INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.OrderKey = PTL.OrderKey
	INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
	INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = PTL.Lot  -- (ChewKP01)
	INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON PTL.LOC = LOC.LOC
	WHERE PTL.DeviceID = @cCartID
	  AND D.DeviceID = @cCartID
	  AND PTL.SKU      = @cSKU
	  AND DL.Status    = '3'
	  AND LA.Lottable01 = @cLottable01 -- (ChewKP01)
	  AND LA.Lottable02 = @cLottable02 -- (ChewKP01)
	  AND LA.Lottable03 = @cLottable03 -- (ChewKP01)
	  AND LA.Lottable04 = @dLottable04 -- (ChewKP01)
	  AND LA.Lottable05 = @dLottable05 -- (ChewKP01)
	  AND PTL.Status   = '0'
     AND LOC.PickZone = CASE WHEN @cPTLPKZoneReq = '1' THEN @cPickZone ELSE LOC.PickZone END  -- (james02)
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

   
   -- (james01)
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
          --SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') 
          GOTO Quit
      END
   END

Quit:
END

GO