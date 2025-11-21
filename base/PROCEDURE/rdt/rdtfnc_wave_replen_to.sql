SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Copyright: IDS                                                       */    
/* Purpose: Wave Replenishment To SOS141253                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2009-08-10 1.0  James      Created                                   */    
/* 2010-02-23 1.1  Shong      Update Replenishment DropID - SOS#162281  */  
/* 2016-09-30 1.2  Ung        Performance tuning                        */
/* 2018-11-21 1.3  TungGH     Performance                               */
/************************************************************************/    
    
CREATE PROC [RDT].[rdtfnc_Wave_Replen_To] (    
   @nMobile    int,    
   @nErrNo     int  OUTPUT,    
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max    
)    
AS    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
-- Misc variable    
DECLARE     
   @cOption     NVARCHAR( 1),    
   @nCount      INT,    
   @nRowCount   INT    
    
-- RDT.RDTMobRec variable    
DECLARE     
   @nFunc      INT,    
   @nScn       INT,    
   @nCurScn    INT,  -- Current screen variable    
   @nStep      INT,    
   @nCurStep   INT,    
   @cLangCode  NVARCHAR( 3),    
   @nInputKey  INT,    
   @nMenu      INT,    
    
   @cStorerKey NVARCHAR( 15),    
   @cFacility  NVARCHAR( 5),     
   @cPrinter   NVARCHAR( 10),    
   @cUserName  NVARCHAR( 18),    
    
   @cErrMsg1            NVARCHAR( 20),    
   @cErrMsg2            NVARCHAR( 20),    
   @cErrMsg3            NVARCHAR( 20),    
   @cErrMsg4            NVARCHAR( 20),    
   @cErrMsg5            NVARCHAR( 20),    
    
   @cWaveKey            NVARCHAR( 10),    
   @cSKU                NVARCHAR( 20),    
   @cDropID             NVARCHAR( 18),    
   @cLOT                NVARCHAR( 10),    
   @cFROMLOC            NVARCHAR( 10),    
   @cID                 NVARCHAR( 18),    
   @cReplenishmentKey   NVARCHAR( 10),    
    
   @nQTY                INT,    
   @cToLoc              NVARCHAR(10),  
    
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
       
-- Load RDT.RDTMobRec    
SELECT     
   @nFunc      = Func,    
   @nScn       = Scn,    
   @nStep      = Step,    
   @nInputKey  = InputKey,    
   @nMenu      = Menu,    
   @cLangCode  = Lang_code,    
    
   @cStorerKey = StorerKey,    
   @cFacility  = Facility,    
   @cPrinter   = Printer,     
   @cUserName  = UserName,    
       
   @cWaveKey    = V_String1,    
    
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
    
FROM RDTMOBREC (NOLOCK)    
WHERE Mobile = @nMobile    
    
IF @nFunc = 943  -- Wave Replenishment From    
BEGIN    
   -- Redirect to respective screen    
   IF @nStep = 0 GOTO Step_0   -- Wave Replenishment To    
   IF @nStep = 1 GOTO Step_1   -- Scn = 2080. Wave    
   IF @nStep = 2 GOTO Step_2   -- Scn = 2081. Wave, Scan Drop ID    
END    
    
--RETURN -- Do nothing if incorrect step    
    
/********************************************************************************    
Step 0. func = 942. Menu    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Set the entry point    
   SET @nScn = 2080    
   SET @nStep = 1    
    
   -- Initiate var    
   SET @cWaveKey = ''    
    
   -- Init screen    
   SET @cOutField01 = '' -- Wave    
    
END    
GOTO Quit    
    
/********************************************************************************    
Step 1. Scn = 2080.     
   Wave     (field01, input)    
********************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 --ENTER    
   BEGIN    
         --screen mapping    
      SET @cWaveKey = @cInField01    
    
      -- Validate blank    
      IF ISNULL(@cWaveKey, '') = ''    
      BEGIN    
         SET @nErrNo = 67491    
         SET @cErrMsg = rdt.rdtgetmessage( 67491, @cLangCode,'DSP') --Wave Needed    
         GOTO Step_1_Fail             
      END    
    
      -- Check if wavekey exists    
      IF NOT EXISTS (SELECT 1 FROM dbo.WAVE WITH (NOLOCK) WHERE WaveKey = @cWaveKey)    
      BEGIN    
         SET @nErrNo = 67492    
         SET @cErrMsg = rdt.rdtgetmessage( 67492, @cLangCode,'DSP') --Invalid Wave    
         GOTO Step_1_Fail             
      END    
    
      -- Check if Storer same as RDT login storer    
      IF EXISTS (SELECT 1 FROM dbo.WAVEDETAIL WD WITH (NOLOCK)     
         JOIN dbo.ORDERS O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)    
         WHERE WD.WaveKey = @cWaveKey    
            AND O.StorerKey <> @cStorerKey)    
      BEGIN    
         SET @nErrNo = 67493    
         SET @cErrMsg = rdt.rdtgetmessage( 67493, @cLangCode,'DSP') --Diff Storer    
         GOTO Step_1_Fail             
      END    
    
      -- Check if Facility same as RDT login facility    
     IF EXISTS (SELECT 1 FROM dbo.WAVEDETAIL WD WITH (NOLOCK)     
         JOIN dbo.ORDERS O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)    
         WHERE WD.WaveKey = @cWaveKey    
            AND O.Facility <> @cFacility)    
      BEGIN    
         SET @nErrNo = 67494    
         SET @cErrMsg = rdt.rdtgetmessage( 67494, @cLangCode,'DSP') --Diff Facility    
         GOTO Step_1_Fail             
      END    
    
      -- Check if Facility same as RDT login facility    
      IF NOT EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)     
         WHERE WaveKey = @cWaveKey    
            AND StorerKey = @cStorerKey    
            AND Confirmed = 'S')    
      BEGIN    
         SET @nErrNo = 67495    
         SET @cErrMsg = rdt.rdtgetmessage( 67495, @cLangCode,'DSP') --No Task     
         GOTO Step_1_Fail             
      END    
    
      SET @cOutField01 = @cWaveKey    
      SET @cOutField02 = ''    
    
    --goto next screen    
      SET @nScn  = @nScn + 1    
      SET @nStep = @nStep + 1    
    
      GOTO Quit    
   END    
    
   IF @nInputKey = 0 --ESC    
   BEGIN    
      --go to main menu    
      SET @nFunc = @nMenu    
      SET @nScn  = @nMenu    
      SET @nStep = 0    
      SET @cOutField01 = ''    
    
      GOTO Quit    
   END    
    
   Step_1_Fail:    
   BEGIN    
      SET @cWaveKey = ''    
      SET @cOutField01 = ''    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 2. Scn = 2081.     
   Wave     (field01)    
   DROP ID  (field02, input)    
********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 --ENTER    
   BEGIN    
         --screen mapping    
      SET @cDropID = @cInField02    
    
      -- Validate blank    
      IF ISNULL(@cDropID, '') = ''    
      BEGIN    
         SET @nErrNo = 67496    
         SET @cErrMsg = rdt.rdtgetmessage( 67496, @cLangCode,'DSP') --DROP ID Needed    
         GOTO Step_2_Fail             
      END    
    
      -- Check if dropid exists    
      IF NOT EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)     
         WHERE WaveKey = @cWaveKey    
            AND DropID = @cDropID)    
      BEGIN    
         SET @nErrNo = 67496    
         SET @cErrMsg = rdt.rdtgetmessage( 67496, @cLangCode,'DSP') --Invalid DROPID    
         GOTO Step_2_Fail             
      END    
    
      -- Check if any open task for this dropid    
      IF EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)     
         WHERE WaveKey = @cWaveKey    
            AND DropID = @cDropID    
            AND Confirmed = 'N')    
      BEGIN    
         SET @nErrNo = 0    
         SET @cErrMsg1 = '67497 There Exists'    
         SET @cErrMsg2 = 'Open Task In This'    
         SET @cErrMsg3 = 'Drop ID'    
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,     
            @cErrMsg1, @cErrMsg2, @cErrMsg3    
         IF @nErrNo = 1    
         BEGIN    
            SET @cErrMsg1 = ''    
            SET @cErrMsg2 = ''    
            SET @cErrMsg3 = ''    
         END    
         GOTO Step_2_Fail             
      END    
    
      --confirm replenishment process    
      BEGIN TRAN    
    
      DECLARE CUR_UPDRPL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR     
      SELECT ReplenishmentKey, LOT, FromLOC, ID, SKU, QTY, ToLoc     
      FROM dbo.Replenishment WITH (NOLOCK)    
      Where StorerKey = @cStorerKey    
         AND DropID = @cDropID    
         AND Confirmed = 'S'    
         AND WaveKey = @cWaveKey   
      ORDER BY ReplenishmentKey    
      OPEN CUR_UPDRPL     
      FETCH NEXT FROM CUR_UPDRPL INTO @cReplenishmentKey, @cLOT, @cFromLOC, @cID, @cSKU, @nQTY, @cToLoc     
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         UPDATE dbo.LOTxLOCxID WITH (ROWLOCK)   
            SET QTYReplen = CASE WHEN QTYReplen > @nQTY   
                                 THEN QTYReplen - @nQTY  
                                 ELSE 0  
                            END     
         WHERE  LOT = @cLOT    
            AND LOC = @cFromLOC    
            AND ID = @cID    
    
         IF @@ERROR <> 0     
         BEGIN    
            ROLLBACK TRAN    
            SET @nErrNo = 67498    
            SET @cErrMsg = rdt.rdtgetmessage( 67498, @cLangCode, 'DSP') --Conf RPL Fail    
    
            CLOSE CUR_UPDRPL    
            DEALLOCATE CUR_UPDRPL    
            GOTO Step_2_Fail             
         END    
    
         UPDATE dbo.Replenishment WITH (ROWLOCK) 
            SET DropId = @cDropID, 
                Confirmed = 'Y'    
         WHERE ReplenishmentKey = @cReplenishmentKey    
    
         IF @@ERROR <> 0     
         BEGIN    
            ROLLBACK TRAN    
            SET @nErrNo = 67499    
            SET @cErrMsg = rdt.rdtgetmessage( 67499, @cLangCode, 'DSP') --Conf RPL Fail    
    
            CLOSE CUR_UPDRPL    
            DEALLOCATE CUR_UPDRPL    
            GOTO Step_2_Fail             
         END    
           
         -- SOS#162281  
         UPDATE PICKDETAIL  
         SET ID = @cDropID    
         FROM dbo.PickDetail P   
         JOIN dbo.ORDERS o WITH (NOLOCK) ON o.OrderKey = P.OrderKey   
         JOIN dbo.WAVEDETAIL w WITH (NOLOCK) ON w.OrderKey = o.OrderKey   
         WHERE W.WaveKey = @cWaveKey   
         AND   P.Lot = @cLOT   
         AND   P.Loc = @cToLoc   
         AND   P.ID  = @cID   
         AND   P.[Status] < '3'   
         IF @@ERROR <> 0     
         BEGIN    
            ROLLBACK TRAN    
            SET @nErrNo = 67500    
            SET @cErrMsg = rdt.rdtgetmessage( 67500, @cLangCode, 'DSP') --Conf RPL Fail    
    
            CLOSE CUR_UPDRPL    
            DEALLOCATE CUR_UPDRPL    
            GOTO Step_2_Fail             
         END    
               
         FETCH NEXT FROM CUR_UPDRPL INTO @cReplenishmentKey, @cLOT, @cFromLOC, @cID, @cSKU, @nQTY, @cToLoc     
      END    
      CLOSE CUR_UPDRPL    
      DEALLOCATE CUR_UPDRPL    
    
      SET @cWaveKey = ''    
      SET @cOutField01 = ''    
    
      --goto next screen    
      SET @nScn  = @nScn - 1    
      SET @nStep = @nStep - 1    
    
      GOTO Quit    
   END    
    
   IF @nInputKey = 0 --ESC    
   BEGIN    
      --go to screen 1    
      SET @cWaveKey = ''    
      SET @cOutField01 = ''    
    
      GOTO Quit    
   END    
    
   Step_2_Fail:    
   BEGIN    
      SET @cDropID = ''    
      SET @cOutField02 = ''    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Quit. Update back to I/O table, ready to be pick up by JBOSS    
********************************************************************************/    
Quit:    
BEGIN    
   UPDATE RDTMOBREC WITH (ROWLOCK) SET     
      EditDate     = GETDATE(), 
      ErrMsg       = @cErrMsg,     
      Func         = @nFunc,    
      Step         = @nStep,    
      Scn          = @nScn,    
    
      StorerKey    = @cStorerKey,    
      Facility     = @cFacility,     
      Printer      = @cPrinter,        
      -- UserName     = @cUserName,    
    
      V_String1  = @cWaveKey,    
    
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