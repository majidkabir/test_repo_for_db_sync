SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdtfnc_Receive_Pallet_Putaway                             */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2020-08-03 1.0  Chermaine WMS-14430 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_Receive_Pallet_Putaway](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

-- Misc variable
DECLARE
   @b_success           INT,
   @cParamLabel1        NVARCHAR( 20),
   @cParamLabel2        NVARCHAR( 20),
   @cParamLabel3        NVARCHAR( 20),
   @cParamLabel4        NVARCHAR( 20),
   @cParamLabel5        NVARCHAR( 20)
   
DECLARE @cPA_StorerKey  NVARCHAR( 15)  
DECLARE @cPA_SKU        NVARCHAR( 20)  
DECLARE @cPA_LOT        NVARCHAR( 10)  
DECLARE @nPA_QTY        INT  
DECLARE @nPA_UCC        NVARCHAR( 20)

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),
   @cPrinter            NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cDropID             NVARCHAR(18),
   @cPalletID           NVARCHAR(18),
   @cUCCNo              NVARCHAR(20),
   @cOrderkey           NVARCHAR(10),
   @cDropLOC            NVARCHAR(10),
   @cSuggestedLOC       NVARCHAR(10),
   @cFromLOC            NVARCHAR(10),
   @cFromID             NVARCHAR(18),
   @cSKU                NVARCHAR(20),
   @nQTY                INT,
   
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),

   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cPrinter         = Printer,
   @cUserName        = UserName,

   @cOrderkey        = V_Orderkey,
   @cPalletID        = V_String1,
   @cSuggestedLOC    = V_string2,
   @cDropLOC         = V_String3,
   @cFromLOC         = V_String4,
   @cSKU             = V_String5,
   @cFromID          = V_String6,
   
   @nQty             = V_Integer1,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,

   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM   RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1845
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1845
   IF @nStep = 1 GOTO Step_1   -- Scn = 5810 Pallet ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 5811 LOC
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1641)
********************************************************************************/
Step_0:
BEGIN
   -- Prep next screen var
   SET @cOutField01 = ''

   -- Go to DropID screen
   SET @nScn  = 5810
   SET @nStep = 1
   
   -- EventLog - Sign Out Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey
END
GOTO Quit


/********************************************************************************
Step 1. screen = 5810
   PALLET ID (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPalletID = @cInField01

      --When PalletID is blank
      IF @cPalletID = ''
      BEGIN
         SET @nErrNo = 156501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletID Req
         GOTO Step_1_Fail
      END

      --DROP ID Exists
      IF NOT EXISTS ( SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DropID = @cPalletID )
      BEGIN
      	SET @nErrNo = 156502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPallet# 
         GOTO Step_1_Fail
      END
            
      IF NOT EXISTS ( SELECT 1
      FROM DropIDDetail DD (NOLOCK)
      JOIN UCC U (NOLOCK) ON (U.uccNo = (CASE WHEN LEN(DD.ChildID)=18 THEN '00'+DD.ChildID ELSE DD.ChildID END))
      JOIN dbo.LOTxLOCxID LLI (NOLOCK)  ON (LLI.storerKey = U.Storerkey AND u.loc = LLI.Loc AND U.ID = LLI.ID AND U.SKU = LLI.SKU)
      WHERE DD.DropID = @cPalletID
      AND LLI.QTY -  LLI.QTYAllocated  -  LLI.QTYPicked  -  (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)  > 0 )
      BEGIN
      	SET @nErrNo = 156503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoQtyToMove 
         GOTO Step_1_Fail
      END

      -- Check suggest Loc
      IF @cPalletID <> ''
      BEGIN        
         SELECT TOP 1  @cSuggestedLOC = LOC.LOC                                
         FROM LOC LOC WITH (NOLOCK)       
         LEFT OUTER JOIN LotxLocxID WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_LOC) ON (LotxLocxID.Storerkey = @cStorerKey AND LotxLocxID.Loc = Loc.Loc)       
         WHERE LOC.LocationCategory = 'BULK'  
         AND   LOC.Facility = @cFacility    
         GROUP BY LOC.LogicalLocation, LOC.LOC     
         HAVING SUM( ISNULL(LotxLocxID.Qty,0)) = 0   
            AND SUM( ISNULL(LotxLocxID.PendingMoveIn,0)) = 0  
         ORDER BY LOC.LogicalLocation, LOC.LOC 
                  
         IF @@ROWCOUNT =0
         BEGIN
         	SET @nErrNo = 156504
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Empty Loc 
            GOTO Step_1_Fail
         END
      END

      --prepare next screen variable
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cSuggestedLOC
      SET @cOutField02 = @cSuggestedLOC

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey

      SET @cOutField01 = ''

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cPalletID = ''

      SET @cOutField01 = ''
    END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 5811
   PalletID    (Field01)
   SuggestLoc  (Field02)
   LOC         (Field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDropLOC = @cInField03

      --When Pallet LOC is blank
      IF ISNULL(RTRIM(@cDropLOC), '') = ''
      BEGIN
         SET @nErrNo = 156505
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC req
         GOTO Step_2_Fail
      END

      IF @cDropLOC <> @cSuggestedLOC
      BEGIN         
         SELECT TOP 1 1                                
         FROM LOC LOC WITH (NOLOCK)       
         LEFT OUTER JOIN LotxLocxID WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_LOC) ON (LotxLocxID.Storerkey = @cStorerKey AND LotxLocxID.Loc = Loc.Loc)       
         WHERE LOC.LOC = @cDropLOC    
         AND   LOC.LocationCategory = 'BULK'  
         AND   LOC.Facility = @cFacility    
         GROUP BY LOC.LogicalLocation, LOC.LOC     
         HAVING SUM( ISNULL(LotxLocxID.Qty,0)) = 0   
            AND SUM( ISNULL(LotxLocxID.PendingMoveIn,0)) = 0  
         ORDER BY LOC.LogicalLocation, LOC.LOC 
         
         IF @@ROWCOUNT = 0
         BEGIN
         	SET @nErrNo = 156506
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not Bulk Loc
            GOTO Step_2_Fail
         END
      END
         
      SELECT TOP 1 @cFromLOC = U.Loc , @cSKU = U.SKU, @nQTY = U.Qty, @cUCCNo = U.UCCNo, @cFromID = ID
      FROM DropIDDetail DD (NOLOCK)
      JOIN UCC U (NOLOCK) ON (U.uccNo = (CASE WHEN LEN(DD.ChildID)=18 THEN '00'+DD.ChildID ELSE DD.ChildID END))
      WHERE DD.DropID = @cPalletID
            
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 156507
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Ucc No
         GOTO Step_2_Fail
      END
          
      DECLARE @nTranCount  INT
              
      SET @nTranCount = @@TRANCOUNT  
      BEGIN TRAN  
      SAVE TRAN rdtfnc_Receive_Pallet_Putaway 
         
      -- Lock bulkEmpty Loc 
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cFromLOC 
         ,@cFromID--@cID 
         ,@cDropLOC--@cSuggestedLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU 
         ,@nQTY--@nPutawayQTY
         ,''--@cFromLOT
         ,@cUCCNo
               
      IF @nErrNo <> 0  
         GOTO RollBackTran  
               
      DECLARE @curPutaway CURSOR   
      SET @curPutaway = CURSOR FOR   
         SELECT u.storerKey,U.SKU, U.Lot,U.Qty, U.UccNo,U.Loc , ID
         FROM DropIDDetail DD (NOLOCK)
         JOIN UCC U (NOLOCK) ON (U.uccNo = (CASE WHEN LEN(DD.ChildID)=18 THEN '00'+DD.ChildID ELSE DD.ChildID END))
         WHERE DD.DropID = @cPalletID
         ORDER BY LOT  
  
      OPEN @curPutaway  
      FETCH NEXT FROM @curPutaway INTO @cPA_StorerKey, @cPA_SKU, @cPA_LOT, @nPA_QTY, @nPA_UCC,@cFromLOC,@cFromID
  
      --SET @nQTY = @nPutawayQTY  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         
      --loop n move to booking loc
      EXEC rdt.rdt_Move  
         @nMobile     = @nMobile,  
         @cLangCode   = @cLangCode,   
         @nErrNo      = @nErrNo  OUTPUT,  
         @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max  
         @cSourceType = 'rdt_Putaway',   
         @cStorerKey  = @cStorerKey,  
         @cFacility   = @cFacility,   
         @cFromLOC    = @cFromLOC,   
         @cToLOC      = @cDropLOC,   
         @cFromID     = @cFromID,      -- NULL means not filter by ID. Blank is a valid ID  
         @cToID       = NULL,          -- NULL means not changing ID. Blank consider a valid ID  
         @cSKU        = @cPA_SKU,   
         @cUCC        = NULL,--@nPA_UCC,
         @nQTY        = @nPA_QTY,   
         @cFromLOT    = @cPA_LOT  
  
      IF @nErrNo <> 0  
         GOTO RollBackTran  
          --GOTO QUIT
               
      FETCH NEXT FROM @curPutaway INTO @cPA_StorerKey, @cPA_SKU, @cPA_LOT, @nPA_QTY, @nPA_UCC,@cFromLOC,@cFromID
      END  
      CLOSE @curPutaway  
      DEALLOCATE @curPutaway 
         

      -- Unlock SuggestedLOC
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'UNLOCK'
         ,@cFromLOC 
         ,@cFromID--@cID 
         ,@cDropLOC--@cSuggestedLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU 
         ,@nQTY--@nPutawayQTY
         ,''--@cFromLOT
         ,@cUCCNo
            
      IF @nErrNo <> 0  
         GOTO RollBackTran 
        
         	
         	
      --update loc to dbo.DropID
      IF EXISTS (SELECT TOP 1 1 FROM DropID WITH (NOLOCK) WHERE DropID = @cPalletID)
      BEGIN
         UPDATE DropID WITH (ROWLOCK) SET Droploc = @cDropLOC WHERE DropID = @cPalletID
      END
      ELSE
      BEGIN
         INSERT INTO dbo.DROPID (Dropid, Droploc, DropIDType, Status)
         VALUES (@cDropID, @cDropLOC, 'B', '0')
      END         
       
      SET @cOutField01 = ''
      SET @cDropLOC = ''
      SET @cPalletID = ''
      SET @cSuggestedLOC = ''

      GOTO CommitTran 
         
  
      RollBackTran:  
         ROLLBACK TRAN rdtfnc_Receive_Pallet_Putaway -- Only rollback change made here  
        
  
      CommitTran:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  
         
         SET @cPalletID = ''
         SET @cSuggestedLOC = ''
            
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      

   END
   

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''

      SET @cDropLOC = ''
      SET @cPalletID = ''
      SET @cSuggestedLOC = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      
      --SET @cPalletID = ''
      --SET @cSuggestedLOC = ''
      SET @cDropLOC = ''

      SET @cOutField03 = ''
   END
   
   
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate      = GETDATE(),
      ErrMsg        = @cErrMsg,
      Func          = @nFunc,
      Step          = @nStep,
      Scn           = @nScn,

      StorerKey     = @cStorerKey,
      Facility      = @cFacility,
      Printer       = @cPrinter,

      V_Orderkey    = @cOrderkey,
      V_String1     = @cPalletID,
      V_String2     = @cSuggestedLOC,
      V_String3     = @cDropLOC,
      V_String4     = @cFromLOC,
      V_String5     = @cSKU,
      
      V_Integer1    = @nQTY,
      
      I_Field01 = @cInField01,  O_Field01 = @cOutField01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,

      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile

END


GO