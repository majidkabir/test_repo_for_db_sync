SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/            
/* Store procedure: rdtfnc_TM_DynamicPick                                    */            
/* Copyright      : IDS                                                      */            
/*                                                                           */            
/* Purpose: SOS#175740 - Republic TM Dynamic Picking                         */            
/*                     - Called By rdtfnc_TaskManager                        */            
/*                                                                           */            
/* Modifications log:                                                        */            
/*                                                                           */            
/* Date       Rev  Author   Purposes                                         */            
/* 2010-06-30 1.0  AQSKC    Created                                          */            
/* 2010-07-12 1.0  AQSKC    Change PA taskdetail status to '0' instead of 'Q'*/            
/*                          (KC01)                                           */            
/* 2010-07-12 1.0  AQSKC    Add parameter to sp rdt_TMDynamicPick_LogPick    */            
/*                          (KC02)                                           */            
/* 2010-07-13 1.0  AQSKC    Request to add new QTY screen for non-BOM sku    */            
/*                          (KC03)                                           */            
/* 2010-07-13 1.0  AQSKC    Remove checking against Pickdetail.ID and        */             
/*                          reasoncode checking (KC04)                       */            
/* 2010-07-21 1.0  AQSKC    Reset DropID to fix issue of ReasonCode screen   */            
/*                          directing to Screen 6 if no DropID pending(Kc05) */            
/* 2010-07-22 1.0  AQSKC    Set userposition to proper value (Kc06)          */            
/* 2010-07-22 1.0  AQSKC    Check for BOM with multi component sku (Kc07)    */            
/* 2010-07-23 1.0  AQSKC    Do not update Taskdetail status = 0 when ESC     */            
/*                          (Kc08)                                           */            
/* 2010-07-23 1.0  AQSKC    Update Taskdetail Starttime, EndTime, Editdate   */            
/*                          and EditWho (Kc09)                               */            
/* 2010-07-24 1.1  Vicky    Insert PA Task with Status = W (Vicky01)         */            
/* 2010-07-27 1.2  AQSKC    Perform WCSRouting Verification when user scan   */            
/*                          CaseID (Kc10)                                    */            
/* 2010-07-27 1.3  Vicky    Use GetDate() (Vicky02)                          */              
/* 2010-07-28 1.4  AQSKC    Check Free Tote and rdtgetmessage stadardize     */            
/*                          (KC11)                                           */            
/* 2010-07-28 1.5  Vicky    Exit To Area screen when TotalPick = 0 (Vicky03) */              
/* 2010-07-29 1.6  AQSKC    Delete DropID where status = '9' and add         */            
/*                          eventlog  (Kc12)                                 */            
/* 2010-07-30 1.7  Vicky    Should insert PA task with status = 0 if         */            
/*                          PickType = 'DRP' (Vicky04)                       */            
/* 2010-08-05 1.8  AQSKC    ShortPick with 0 qty or not should be handled    */            
/*                          same way according to TaskManagerReason setup    */            
/*                          (Kc13)                                           */            
/* 2010-08-12 1.9  ChewKP   Residual PA Task CS ActionFlag will be           */            
/*                          'R' (ChewKP01)                                   */            
/* 2010-08-10 2.0  Vicky    Bug Fix (Vicky05)                                */        
/* 2010-08-15 2.1  Shong    Bug Fix & Delete rdtDPKLog by UserKey (Shong01)  */            
/* 2010-08-16 2.2  Shong    Bug Fix. Reassign @c_LOT (Shong02)               */            
/* 2010-08-18 2.3  AQSKC    Do not allow duplicate caseid for same task      */            
/*                          (Kc14)                                           */            
/* 2010-08-23 2.4  James    Allow ESC back from Reason Screen (james01)      */            
/* 2010-08-23 2.5  Shong    Do not allow Mix SKU per CaseID for DRP (Shong03)*/          
/* 2010-08-30 2.6  Shong    Should allow to Pick To same pallet if pallet not*/          
/*                          close yet (shong04)                              */          
/* 2010-09-01 2.7  Shong    Check Tote In Use From TaskDetail (Shong05)      */          
/* 2010-09-02 2.8  James    Update starttime when task started (james02)     */          
/* 2010-09-04 2.9  ChewKP   Fixes (ChewKP02)                                 */        
/* 2010-09-04 2.10 James    Use replenishmentpriority from skuxloc when      */      
/*                          creating PA Task (james03)                       */      
/* 2010-09-07 2.11 James    Bug fix on QtyReplen (james04)                   */      
/* 2010-09-22 2.12 James    Update Qty moved to TaskDetail.Qty (james05)     */      
/* 2010-09-27 2.13 Shong    Check Bad Reason Code from Codelkup (Shong06)    */      
/* 2010-09-30 2.14 James    When short pick, update task status with reason  */      
/*                          code status (james06)                            */     
/* 2010-10-02 2.15 Shong    Default Qty Field in Non Bom Screen to BLANK     */    
/* 2010-10-02 2.16 James    Close pallet when complete or short pick for DRP */    
/*                          task (james07)                                   */    
/* 2010-10-02 2.17 Shong    Check SKU with Suggest SKU for Non BOM SKU       */    
/*                          (Shong07)                                        */    
/* 2010-10-02 2.18 Shong    Check Qty Available for Non BOM SKU (Shong08)    */    
/* 2010-10-03 2.19 Shong    Reason Code Screen for Short Pick should go back */    
/*                          to Get Next Task instead of Task Mgr Scn         */    
/*                          (Shong09)                                        */    
/* 2010-10-03 2.20 Shong    DRP ToLoc for PA task should get from taskdetail */    
/*                          instead of Getting from SKUxLOC (Shong10)        */    
/* 2010-10-04 2.21 Shong    DELETE RDT.rdtDPKLOG after PA Task Generated     */    
/*                          (Shong10)                                        */    
/* 2010-10-11 2.22 Shong    Swap V_String1 and 5 to follow TaskManager Std   */    
/*                          (Shong11)                                        */    
/* 2010-10-19 2.23 James    Clear Pallet ID field (james08)                  */    
/* 2010-10-27 2.24 Shong    Short Pick only When Continue Process = 1        */    
/*                          (Shong11)                                        */    
/* 2011-04-19 2.25 James    SOS212200 - Extra checking on Case ID (james09)  */    
/* 2011-06-07 2.26 James    SOS217543 - Check duplicate Case ID (james10)    */    
/* 2011-09-19 2.27 James    SOS225733 - Add Traceinfo (james11)              */  
/* 2011-05-12 2.28 ChewKP   Begin Tran and Commit Tran issues (ChewKP03)     */
/* 2013-06-05 2.29 ChewKP   SOS#279681 TranCount issues (ChewKP04)           */
/* 2014-07-11 2.30 James    SOS315989 - Add extended update                  */
/*                          Add close tote ability                           */
/*                          Add config to skip scan case id (james12)        */
/* 2014-09-25 2.31 James    Release tote if it is free to use (james13)      */
/* 2014-10-03 2.32 James    Add extended validate sp (james14)               */
/* 2014-12-02 2.33 James    SOS326850 - Bug fix (james15)                    */
/* 2014-12-18 2.34 James    SOS323699 - Fix -ve Qty in taskdetail (james16)  */
/* 2015-03-27 2.35 James    SOS336544 - Fix tote not close issue (james17)   */
/* 2015-07-15 2.36 James    SOS332896 - Add config to allow overpick(james18)*/
/*                                      Add DecodeLabelNo                    */
/* 2016-10-05 2.37 James    Perf tuning                                      */
/* 2018-11-15 2.38 TungGH   Performance                                      */
/*****************************************************************************/              
CREATE PROC [RDT].[rdtfnc_TM_DynamicPick](                
   @nMobile    INT,                
   @nErrNo     INT  OUTPUT,                
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max                
) AS                
SET NOCOUNT ON          
                
-- Misc variable                
DECLARE                
   @b_success           INT                
                        
-- Define a variable                
DECLARE                  
   @nFunc               INT,                
   @nScn                INT,                
   @nStep INT,     
   @cLangCode           NVARCHAR(3),                
   @nMenu               INT,                
   @nInputKey           NVARCHAR(3),                
   @cPrinter            NVARCHAR(10),                
   @cUserName           NVARCHAR(18),                
                
   @cStorerKey          NVARCHAR(15),                
   @cFacility           NVARCHAR(5),                
                
   @cSku                NVARCHAR(20),                
   @cAltSKU             NVARCHAR(20),                
   @cDescr              NVARCHAR(60),                
   @cSuggFromLoc        NVARCHAR(10),                
   @cSuggLot            NVARCHAR(10),                
   @cSuggToLoc          NVARCHAR(10),                
   @cFromLoc            NVARCHAR(10),                
   @cDefaultToLoc       NVARCHAR(10),                
   @cToloc              NVARCHAR(10),                
   @cSuggID             NVARCHAR(18),                
   @cID                 NVARCHAR(18),                
   @cMUOM_Desc          NVARCHAR( 5),                
   @cTaskdetailkey      NVARCHAR(10),                
   @cPickType           NVARCHAR(10),                
   @cUserPosition       NVARCHAR(1),                
   @cDropID             NVARCHAR(18),                
   @cTaskStorer         NVARCHAR(15),                
   @cLoadkey            NVARCHAR(10),                
   @nTaskQty            INT,                
   @nPAQty              INT,                
   @nTotPickQty         INT,                
   @nCaseQty            INT,                
   @nCaseRemainQty      INT,                
   @nSum_PalletQty      INT,                
   @nQtyExtra           INT,                
   @cAreaKey            NVARCHAR(10),                
   @cStrategykey        NVARCHAR(10),                 
   @cTTMStrategykey     NVARCHAR(10),                 
   @cTTMTasktype        NVARCHAR(10),                
   @nFromStep           INT,                
   @nFromScn            INT,                
   @cRefKey01           NVARCHAR(20),                
   @cRefKey02           NVARCHAR(20),                
   @cRefKey03           NVARCHAR(20),                
   @cRefKey04           NVARCHAR(20),                
   @cRefKey05           NVARCHAR(20),                
   @cPrepackByBOM       NVARCHAR( 1),                
   @cBOMSku             NVARCHAR(20),                
   @nBomCnt             INT,                
   @cComponentSku       NVARCHAR(20),                
   @cUom                NVARCHAR(5),                
   @cCaseID             NVARCHAR(10),                
   @cPickdetailkey NVARCHAR(10),                
   @nPKQty              INT,                
   @nPickRemainQty      INT,                
   @nAvailQty           INT,                
   @nMoveQty            INT,                
   @cNewPickdetailkey   NVARCHAR(10),                
   @c_outstring         NVARCHAR(255),                
   @cOption             NVARCHAR(1),                
   @cNextTaskdetailkey  NVARCHAR(10),                
   @cNewLoc             NVARCHAR(10),                
   @cNewID              NVARCHAR(18),                
   @cLogSku             NVARCHAR(20),                
   @cLot                NVARCHAR(10),                
   @cLogLoc             NVARCHAR(10),                
   @cLogID              NVARCHAR(10),                
   @cLogLot             NVARCHAR(10),                
   @nLogQty             INT,                
   @cLogCaseID          NVARCHAR(10),                
   @cLogBOMSku          NVARCHAR(20),                
   @cPrevCaseID         NVARCHAR(10),                
   @cLogTaskdetailkey   NVARCHAR(10),                
   @cPALoc              NVARCHAR(10),                
   @cPATaskdetailkey    NVARCHAR(10),                
   @nToFunc             INT,                
   @nToScn              INT,                
   @cReasonCode         NVARCHAR(10),                
   @cPickToZone         NVARCHAR(10),                
   @cTitle              NVARCHAR(20),                
   @cSuggSKU            NVARCHAR(20),                
   @cPackKey            NVARCHAR(10),                
   @bProcessStart       INT,                
   @cLogicalFromLoc     NVARCHAR(18),                
   @cLogicalToLoc       NVARCHAR(18),                
   @cPAStatus           NVARCHAR(1),         
   @nSumQtyShort        INT,                
   @cShortLot           NVARCHAR(10),                
   @cBoxQty             NVARCHAR(5),                
   @nBoxQty             INT,                
   @cContinueProcess    NVARCHAR(10),                
   @nCompSKU            INT,        --(Kc07)                
   @bSuccess            INT,        --(KC10)                
   @cActionFlag         NVARCHAR(1),    --(Shong01)             
   @nQtyPicked          INT,        --(james01)            
   @nTD_Qty             INT,          
   @nPD_Qty             INT,          
   @cTTMTaskTypeLog     NVARCHAR(10),   -- (ChewKP02)        
   @cReplenPriority     NVARCHAR(5),    -- (james03)      
   @nReplenQty          INT,        -- (james04)      
   @nQtyMoved           INT,        -- (james05)      
   @cReasonStatus       NVARCHAR(10),   -- (james06)      
   @nQtyToMoved         INT,        -- (jamesxx)    
   @nRowRef             INT,        -- (Shong10)    
   @nQtyAvail           INT,     
   @nQtyReplen          INT,    
   @nCurrentTranCount   INT,    
   @nShortQty           INT,    
   @cDefaultCaseLength  NVARCHAR( 1),   -- (james09)  
   @cSkipScanCaseId     NVARCHAR( 1),   -- (james12)  
   @cExtendedUpdateSP   NVARCHAR( 20),  -- (james12)  
   @cSQL                NVARCHAR(MAX),  -- (james12)  
   @cSQLParam           NVARCHAR(MAX),  -- (james12)  
   @cOldTote            NVARCHAR( 20),  -- (james12)  
   @cNewTote            NVARCHAR( 20),  -- (james12)  
   @cSuggQty            NVARCHAR( 10),  -- (james12)  
   @cToToteNo           NVARCHAR( 20),  -- (james12)  
   @cNewTaskDetailKey   NVARCHAR( 10),  -- (james12)  
   @nTotPrevPickQty     INT,            -- (james12)  
   @nValid              INT,            -- (james12)  
   @cSourceType         NVARCHAR( 20),  -- (james12)  
   @cExtendedValidateSP NVARCHAR( 20),  -- (james14)
   @cPrev_ToTote        NVARCHAR( 20),  -- (james14)
   @nNextToToteNoSeqNo  INT,            -- (james14)
   @cToToteNo_New       NVARCHAR( 20),  -- (james14)
   @cSuggLOC            NVARCHAR( 10),  -- (james15)
   @cAltLOC             NVARCHAR( 10),  -- (james15)
   @cAvail_Qty          NVARCHAR( 5),   -- (james15)
   @cQty2Pick           NVARCHAR( 5),   -- (james15)
   @cQtyAvail           NVARCHAR( 5),   -- (james16)
   @nSuggQty            INT,            -- (james16)


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

-- (james18)
DECLARE
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
   @c_oFieled15 NVARCHAR(20),
   @cDecodeLabelNo       NVARCHAR( 20)
   
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
                
   @cSKU             = V_SKU,                
   @cDescr           = V_SKUDescr,                
   @cFromLoc         = V_LOC,                
   @cID              = V_ID,                
   @cUOM             = V_UOM,                                
   @cLoadKey         = V_LoadKey,           
   
   @nTotPickQty      = V_QTY,     
                
   -- (SHONG11)    
   @nFromStep        = V_FromStep,   
   @nTaskQty         = V_TaskQty,
   --@nFromStep        = V_FromStep,
   @nFromScn         = V_FromScn,
   
   @nCaseQty         = V_Integer1,                
   @nBoxQty          = V_Integer2,
                           
   --@cTaskdetailkey   = V_String1,                
   @cTaskStorer      = V_String2,                         
   @cDropID          = V_String4,                    
   @cTaskdetailkey   = V_String5,                                
   @cPickToZone      = V_String7,                
   @cPickType        = V_String8,                
   @cTitle           = V_String9,                
   @cSuggID          = V_String10,                
   @cSuggFromLoc     = V_String11,                
   @cSuggToloc       = V_String12,                
   @cSuggSKU         = V_String13,                
   @cPackKey         = V_String14,                
   @cUOM             = V_String15,                
   @cSuggLot         = V_String16,                             
   @cUserPosition    = V_String19,           --(Kc06)                
   @cPrev_ToTote     = V_String20, 

   @cAreakey         = V_String32,                 
   @cTTMStrategykey  = V_String33,                 
   @cTTMTasktype     = V_String34,                 
   @cRefKey01        = V_String37,                 
   @cRefKey02        = V_String38,                 
   @cRefKey03        = V_String37,                 
   @cRefKey04        = V_String38,                 
   @cRefKey05        = V_String39,                 
            
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
                
FROM   RDT.RDTMOBREC (NOLOCK)                
WHERE  Mobile = @nMobile                
                
-- Redirect to respective screen                
IF @nFunc = 1761                
BEGIN                
   IF @nStep = 1 GOTO Step_1   -- Menu. Func = 1761, Scn = 2440 -- DROPID (SCN1)             
   IF @nStep = 2 GOTO Step_2   -- Scn = 2441   FROM LOC (SCN2)                
   IF @nStep = 3 GOTO Step_3   -- Scn = 2442   PALLET ID(SCN3)                
   IF @nStep = 4 GOTO Step_4   -- Scn = 2443   SKU (SCN4)                
   IF @nStep = 5 GOTO Step_5   -- Scn = 2444   CASEID (SCN5)                
   IF @nStep = 6 GOTO Step_6   -- Scn = 2445   NEXT TASK/CLOSE PALLET (SCN6)                
   IF @nStep = 7 GOTO Step_7   -- Scn = 2446   SHORT PICK/CLOSE PALLET (SCN7)                
   IF @nStep = 8 GOTO Step_8   -- Scn = 2447   TOLOC (SCN8)                
   IF @nStep = 9 GOTO Step_9   -- Scn = 2448   Pallet Closed Msg (SCN9)                
   IF @nStep = 10 GOTO Step_10   -- Scn = 2109   Reason Code screen (SCN10)                
   IF @nStep = 11 GOTO Step_11   -- Scn = 2449   Non-BOM sku QTY (SCN11)                
END                
                
RETURN -- Do nothing if incorrect step                
                
/********************************************************************************                
Step 1. Called from Task Manager Main Screen (func = 1761)                
    Screen = 2440                 
    Title (Field01, display)                
    PICKTYPE(Field04, display)                
    DROP ID (Field05, input)                
********************************************************************************/                
Step_1:                
BEGIN                
   -- Set all variable for 1st record - records are from rdtfnc_TaskManager                
   IF @nFromStep = 0       --(Kc05)                
   BEGIN                
      SET @cTitle          = @cOutField05                
      SET @cTaskdetailkey  = @cOutField06                
      SET @cAreaKey        = @cOutField07                
      SET @cTTMStrategykey = @cOutField08                
      SET @cPickType       = @cOutField04                 
      SET @cDropID         = ''              --(Kc05)       
      SET @cOutField09     = ''  -- (james08) make sure we clear the pallet id     
                                 --           field before we proceed    
            
      --used to keep count of overpicking                
      DELETE FROM rdt.rdtDPKLog              
      WHERE  UserKey = @cUserName            
                  
   END                
                
   SET @cUserPosition = '1'                 --(Kc06)                
   IF @nInputKey = 1 -- ENTER                
   BEGIN                
      -- Screen mapping                
      SET @nTotPickQty = 0                
      SET @cDropID   = @cInField09                

      SELECT @cTaskStorer  = Storerkey FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskdetailkey            
      
      /****************************                
       VALIDATION                 
      ****************************/                
      --When DropID is blank                
      IF @cDropID = ''                
      BEGIN                
         SET @nErrNo = 70116                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Drop ID req                
         GOTO Step_1_Fail                  
      END                 

      -- (james14)
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cTaskStorer)
      IF @cExtendedValidateSP = '0'  
         SET @cExtendedValidateSP = ''

      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskStorer, @cTaskDetailKey, @cToID, @cFromLoc, @cFromID, @cToLoc, @cSKU, 
              @cCaseID, @nQty, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cTaskStorer     NVARCHAR( 15), ' +
               '@cTaskDetailKey  NVARCHAR( 10), ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cFromLoc        NVARCHAR( 10), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cToLoc          NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@cCaseID         NVARCHAR( 20), ' +
               '@nQty            INT, ' +
               '@nErrNo          INT           OUTPUT, ' + 
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskStorer, @cTaskDetailKey, @cDropID, @cFromLoc, @cID, @cToLoc, @cSKU, 
               @cCaseID, @nBoxQty, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            
            IF @nErrNo <> 0 OR ISNULL( @cErrMsg, '') <> ''
               GOTO Step_1_Fail
         END  
      END

      --(Kc11)                
      IF EXISTS ( SELECT 1 From dbo.DropID DI WITH (NOLOCK) Where DropID = @cDropID And Status < '9')                
      BEGIN                
         -- (shong04)          
         IF NOT EXISTS(SELECT 1 FROM RDT.RDTDPKLOG WITH (NOLOCK) WHERE USERKEY = @cUserName AND DropID=@cDropID)          
         BEGIN          
            SET @nErrNo = 60316                 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --60316^ID in used                
            GOTO Step_1_Fail                                
         END          
      END                  
      ELSE          
      BEGIN          
         -- (shong04)          
         IF EXISTS(SELECT 1 FROM RDT.RDTDPKLOG WITH (NOLOCK) WHERE USERKEY = @cUserName AND DropID<>@cDropID)          
         BEGIN          
            SET @nErrNo = 70152                 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --70152^ClosePalletReq          
            GOTO Step_1_Fail                                
         END                            
      END          
            
      -- (Shong05)           
      IF EXISTS ( SELECT 1 From dbo.TASKDETAIL WITH (NOLOCK) Where DropID = @cDropID And Status NOT IN ('9','X') )              
      BEGIN          
         SET @nErrNo = 60316                 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --60316^ID in used                
         GOTO Step_1_Fail                                    
      END          
          
      --(Kc12) - start            
      IF EXISTS ( SELECT 1 From dbo.DropID WITH (NOLOCK) Where DropID = @cDropID And Status = '9' )              
      BEGIN              
         BEGIN TRAN            
         DELETE FROM dbo.DROPIDDETAIL            
         WHERE DropID = @cDropID            
            
         IF @@ERROR <> 0            
         BEGIN            
            ROLLBACK TRAN            
            SET @nErrNo = 70184               
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelDIDDetFail              
            GOTO Step_1_Fail                  
         END            
            
         DELETE FROM dbo.DROPID            
         WHERE DropID = @cDropID            
         AND   Status = '9'            
            
         IF @@ERROR <> 0            
         BEGIN            
            ROLLBACK TRAN            
            SET @nErrNo = 70185               
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelDropIDFail              
            GOTO Step_1_Fail                  
         END            
         ELSE            
         BEGIN            
            COMMIT TRAN            
         END            
      END                
      --(Kc12) -end            
              
      SELECT @cTaskStorer  = Storerkey,                 
             @cSuggID      = FromID,                
             @cSuggLot     = Lot,                
             @cSuggFromLoc = FromLOC,                
             @cSuggToloc   = ToLoc,                
             @cSuggSKU     = SKU,                
             @cLoadKey     = LoadKey,                 
             @nTaskQty     = Qty                
      FROM dbo.TaskDetail WITH (NOLOCK)                
      WHERE TaskDetailKey = @cTaskdetailkey                
          
      -- (james02) When Get the first Task Update EditDate          
      BEGIN TRAN          
      UPDATE dbo.TaskDetail With (ROWLOCK)          
      SET StartTime = GETDATE(),           
          EditDate = GETDATE(),          
          EditWho = @cUserName,          
          Trafficcop = NULL           
      WHERE TaskDetailkey = @cTaskdetailkey          
                
      IF @@ERROR <> 0          
      BEGIN          
         SET @nErrNo = 70192           
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'          
         ROLLBACK TRAN          
         GOTO Step_1_Fail           
      END          
      ELSE          
      BEGIN          
         COMMIT TRAN          
      END          
          
      EXEC RDT.rdt_STD_EventLog                
         @cActionType = '1', -- Sign in function                
         @cUserID     = @cUserName,                
         @nMobileNo   = @nMobile,                
         @nFunctionID = @nFunc,                
         @cFacility   = @cFacility,                
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep                
                
      /****************************                
       prepare next screen variable                
      ****************************/                
      SET @cOutField01 = @cTitle                
      SET @cOutField02 = @cPickType                
      SET @cOutField03 = @cDropID                
      SET @cOutField04 = @cSuggFromLoc                
      SET @cOutField05 = ''                
                
      SET @nScn = @nScn + 1                
      SET @nStep = @nStep + 1                
   END                
                
   IF @nInputKey = 0 -- ESC                
   BEGIN                
      SET @nTotPickQty = 0                
      -- Go to Reason Code Screen           
      SET @cOutField01 = ''                
      SET @cOutField02 = ''                
      SET @cOutField03 = ''                
      SET @cOutfield04 = ''                
      SET @cOutField05 = ''                
      SET @cOutField09 = ''                
      SET @nFromScn = @nScn                
      SET @nFromStep = @nStep                
      SET @nScn  = 2109                
      SET @nStep = @nStep + 9 -- Step 10                
   END                
   GOTO Quit       
                
   Step_1_Fail:                
   BEGIN                
-- Reset this screen var                
      SET @cOutField09 = ''                
   END                
END                
GOTO Quit          
           
/********************************************************************************                
Step 2. screen = 2441          
    Title   (Field01, display)                
    PICKTYPE(Field02, display)                
    DROP ID (Field03, display)                
    FROM LOC(Field04, display)                
    FROM LOC(Field05, input)                
********************************************************************************/                
Step_2:                
BEGIN                
   SET @cUserPosition = '1'                 --(Kc06)                
   IF @nInputKey = 1 -- ENTER                
   BEGIN           
      -- Screen mapping                
      SET @cFromLoc    = @cInField05                
      SET @nTotPickQty = 0 --(shongxx)          
      /****************************                
       VALIDATION                 
      ****************************/                
      --blank FromLoc                
      IF @cFromLoc = ''                
      BEGIN                
         SET @nErrNo = 70117                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromLoc req                
         GOTO Step_2_Fail                  
      END                 
                
      IF ISNULL(RTRIM(@cFromLoc),'') <> ISNULL(RTRIM(@cSuggFromLoc),'')                
      BEGIN                
         SET @nErrNo = 70118                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid FromLOC                
         GOTO Step_2_Fail                    
      END                      
      /****************************                
       Prepare Next Screen                 
      ****************************/                
      SET @cOutField01 = @cTitle                
      SET @cOutField02 = @cPickType                
      SET @cOutField03 = @cDropID                
      SET @cOutField04 = @cFromLoc                
      SET @cOutField05 = @cSuggID                
      SET @cOutField06 = ''                
                
      SET @nScn = @nScn + 1                
      SET @nStep = @nStep + 1                
   END                
                
   IF @nInputKey = 0 -- ESC                
   BEGIN                
      SET @cOutField05 = @cTitle                
      SET @cOutField02 = ''                 
      SET @cOutField03 = ''                 
      SET @cOutField04 = @cPickType                
      SET @cOutfield09 = '' --@cDropID (james08) make sure we clear pallet id field    
      SET @nFromScn = @nScn                
      SET @nFromStep = @nStep                
      SET @nScn = @nScn -1                   
      SET @nStep = @nStep - 1                
   END                
   GOTO Quit                
                
   Step_2_Fail:                
   BEGIN                
   SET @cOutfield09 = ''                
   END                
END                
GOTO Quit                
                
/********************************************************************************                
Step 3. screen = 2442                
    TITLE   (Field01, display)                
    PICKTYPE(Field02, display)                
    DROP ID (Field03, display)                
    FROM LOC(Field04, display)                
    PALLET ID (Field05, display)                
    PALLET ID (Field06, input)             
********************************************************************************/                
Step_3:                
BEGIN                
   SET @cUserPosition = '1'                 --(Kc06)                
   IF @nInputKey = 1 -- ENTER                
   BEGIN                
      SET @nTotPickQty = 0 --reset qty for new loc/id combination                
      -- Screen mapping                
      SET @cID  = @cInField06                
                
      /****************************                
       VALIDATION                 
      ****************************/                
      --blank FromID                
      IF @cSuggID <> '' AND @cID = ''                
      BEGIN                
         SET @nErrNo = 70119                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet ID req                
         GOTO Step_3_Fail                  
      END                 
         
      IF @cID <> @cSuggID                
      BEGIN         
         SET @nErrNo = 70120                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Pallet ID                
         GOTO Step_3_Fail                    
      END                
                
      -- Check LoadKey got something to pick for the given LOC & ID                
      IF @cTTMTaskType = 'DPK'                
      BEGIN                
         IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)                 
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)                
            WHERE PD.StorerKey   = @cTaskStorer                
               AND PD.TOLOC      = @cFromLoc                
               --AND PD.ID         = @cID       --(Kc04)                
               AND PD.Status     = '0'                
               AND O.LoadKey     = @cLoadKey)                
         BEGIN                
            -- SOS225733 (james11)  
            INSERT INTO TraceInfo( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5  
                                 , Col1, Col2, Col3, Col4, Col5 )  
            VALUES ( 'rdtfnc_TM_DynamicPicking', GetDate(), '70121', @cTaskdetailkey, @cTaskStorer, @cFromLoc, @cLoadKey  
          , '' ,'', '', @cUserName, @nMobile)  
  
            INSERT INTO TraceInfo( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5  
                                 , Col1, Col2, Col3, Col4, Col5 )  
            SELECT 'rdtfnc_TM_DynamicPicking_2', GETDATE(), Pickdetailkey, PD.OrderKey, PD.SKU, PD.Status, PD.TaskDetailKey, PD.TOLOC,  
                                   O.LoadKey, O.StorerKey, @cUserName, @nMobile   
            FROM dbo.PickDetail PD WITH (NOLOCK)                 
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)                
            WHERE PD.StorerKey   = @cTaskStorer                
               AND PD.TOLOC      = @cFromLoc                
               AND O.LoadKey     = @cLoadKey  
  
            SET @nErrNo = 70121                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PKTask                
            GOTO Step_3_Fail                   
         END                
      END                
                
      -- Get SKU/Pack info                
      SELECT                
         @cDescr = SKU.Descr,                
         @cMUOM_Desc = Pack.PackUOM3,                
         @cPackKey   = Pack.PackKey                
      FROM dbo.SKU SKU WITH (NOLOCK)                
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)                
      WHERE SKU.StorerKey = @cTaskStorer                
         AND SKU.SKU = @cSuggSKU                
                
      SET @cUOM = @cMUOM_Desc          
          
      SET @nQtyAvail = 0     
      SELECT @nQtyAvail = ISNULL((SL.QTY - SL.QTYPicked), 0)     
      FROM dbo.SKUxLOC SL WITH (NOLOCK)      
      WHERE SL.StorerKey = @cTaskStorer     
        AND SL.Sku = @cSuggSKU      
        AND SL.LOC = @cFromLoc     
          
                 
      /****************************                
       Prepare Next Screen                
      ****************************/                
      SET @cOutField01 = @cTitle                
      SET @cOutField02 = @cID                
      SET @cOutField03 = @cSuggSKU                
      SET @cOutField04 = SUBSTRING(@cDescr,1,20)                
      SET @cOutField05 = SUBSTRING(@cDescr,21,20)                
      SET @cOutField06 = ''            
      SET @cInField06  = ''                
      SET @cOutField07 = @cMUOM_Desc                
      SET @cOutField08 = '0'             
      SET @cOutField09 = CAST(@nTaskQty AS NVARCHAR( 5))        
      SET @cOutField10 = CAST(@nQtyAvail AS NVARCHAR( 5))           
                
      SET @nScn = @nScn + 1                
      SET @nStep = @nStep + 1                
                
   END                
                
   IF @nInputKey = 0 -- ESC                
   BEGIN                
      SET @cOutField01 = @cTitle                
      SET @cOutField02 = @cPickType                 
      SET @cOutField03 = @cDropID                 
      SET @cOutField04 = @cFromLoc                
      SET @cOutField05 = ''                 
      SET @cOutField06 = ''                 
      SET @cOutField07 = ''                 
      SET @cOutField08 = ''                 
      SET @cOutField09 = ''       
      SET @cOutField10 = ''            
      SET @nTotPickQty=0 --(shongxx)      
                
      SET @nScn = @nScn - 1                   
      SET @nStep = @nStep - 1                
   END                
   GOTO Quit                
                
   Step_3_Fail:              
   BEGIN                
      SET @cOutField06 = ''                 
   END                
END                
GOTO Quit                
                
/********************************************************************************                
Step 4. screen = 2443                
    TITLE   (Field01, display)                
    PALLETID(Field02, display)                
    SKU     (Field03, display)                
    SKUDESCR(Field04, display)                
    SKUDESCR(Field05, display)                
    BOMSKU  (Field06, input)                
    UOM     (Field07, display)                
    QTY     (Field08/Field09 display)                
********************************************************************************/                
Step_4:                
BEGIN                
   SET @cUserPosition = '1'                 --(Kc06)                
   IF @nInputKey = 1 -- ENTER                
   BEGIN                
      -- Screen mapping                
      SET @cBOMSku    = @cInField06                
             
      /****************************              
       VALIDATION                 
      ****************************/                
      --blank SKU                
      IF @cBOMSku = ''                
      BEGIN          
         SET @nErrNo = 70122                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU req        
         GOTO Step_4_Fail                  
      END                 
                  
      SELECT @cAltSKU = ''                
--      IF @cTTMTaskType = 'DPK'                
--      BEGIN                
--         SELECT TOP 1 @cAltSKU = LA.Lottable03                 
--         FROM dbo.PickDetail PD WITH (NOLOCK)                
--         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT                
--         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)                
--         WHERE PD.StorerKey   = @cTaskStorer                
--            AND PD.TOLOC      = @cFromLoc                
--            AND PD.Taskdetailkey = @cTaskdetailkey    --(KC04)                
--            AND PD.Status     = '0'                
--            AND O.LoadKey     = @cLoadKey     
--      END                
--      ELSE                
--      BEGIN                
--         SELECT TOP 1 @cAltSku = LA.Lottable03                
--         FROM  dbo.Lotattribute LA WITH (NOLOCK)                 
--         WHERE LA.Lot = @cSuggLot                
--      END                
    
      IF EXISTS (SELECT 1 FROM dbo.BillOfMaterial WITH (NOLOCK)     
                 WHERE StorerKey = @cTaskStorer AND SKU = @cBOMSKU)                
      BEGIN                
         -- (KC07) start                
         SET @nCompSKU = 0                
         SELECT @nCompSKU = Count(ComponentSKU)                
         FROM   dbo.BillOfMaterial WITH (NOLOCK)                
         WHERE  Storerkey = @cTaskStorer                
         AND    SKU = @cBOMSku                
                      
         IF @nCompSKU > 1                
         BEGIN                
            SET @nErrNo = 70158                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiCompntBOM                
            GOTO Step_4_Fail                  
         END                 
         -- (Kc07) - End                
             
         SELECT @cComponentSKu = ComponentSKU                
         FROM   dbo.BillOfMaterial WITH (NOLOCK)                
         WHERE  Storerkey = @cTaskStorer                
         AND    SKU = @cBOMSku                
             
         IF ISNULL(RTRIM(@cComponentSKu),'') <> @cSuggSKU                
         BEGIN                
            SET @nErrNo = 70124                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU/UPC                
            GOTO Step_4_Fail                  
         END               
             
         SELECT @cDescr = SKU.Descr                
         FROM dbo.SKU SKU WITH (NOLOCK)    
         WHERE SKU.StorerKey = @cTaskStorer     
         AND   SKU.SKU = @cComponentSKu    
             
         SET @cAltSKU = @cBOMSKU    
      END    
      ELSE                
      IF ISNULL(RTRIM(@cBOMSku),'') <> @cSuggSKU                
      BEGIN                
         SET @nErrNo = 70124                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU/UPC                
         GOTO Step_4_Fail                  
      END                 
    
      SET @cSKU = @cSuggSKU    
                         
      SELECT @cPrepackByBOM = ISNULL(RTRIM(sValue), '0')                
      FROM dbo.StorerConfig WITH (NOLOCK)                
      WHERE Configkey = 'PrePackByBOM'                
      AND   Storerkey = @cTaskStorer                
                
      IF @cPrepackByBOM = ''                
      BEGIN                
         SET @cPrepackByBOM = '0'                
      END                
                
      SELECT @cDescr = '', @cMUOM_Desc = ''                
      IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1'                 
      BEGIN                
         SELECT                
            @nCaseQty =  (ISNULL(BOM.Qty, 0)  * ISNULL(Pack.CaseCnt,0)),                
            --@cDescr = SKU.Descr,                
            @cMUOM_Desc = Pack.PackUOM3                
         FROM dbo.SKU SKU WITH (NOLOCK)                
         INNER JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (BOM.SKU = SKU.SKU AND BOM.STORERKEY = SKU.STORERKEY)                
         INNER JOIN dbo.UPC UPC WITH (NOLOCK) ON (UPC.Sku = BOM.Sku AND UPC.Storerkey = BOM.Storerkey AND UPC.UOM = 'CS')                
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (UPC.PackKey = Pack.PackKey)                
         WHERE SKU.StorerKey = @cTaskStorer                
         AND   SKU.SKU = @cBOMSku                
      END                
      ELSE                
      BEGIN                
         -- Get SKU/Pack info                
         SELECT                
            @nCaseQty = ISNULL(Pack.CaseCnt,0),                
            @cDescr = SKU.Descr,                
            @cMUOM_Desc = Pack.PackUOM3                
         FROM dbo.SKU SKU WITH (NOLOCK)                
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)                
         WHERE SKU.StorerKey = @cTaskStorer                
            AND SKU.SKU = @cSKU                
                
         SET @cUOM = @cMUOM_Desc                
      END                
           
      SET @nTotPickQty=0                
      SET @nTotPrevPickQty = 0

      SELECT @nSuggQty = SystemQty
      FROM dbo.TaskDetail WITH (NOLOCK) 
      WHERE TaskDetailKey = @cTaskdetailkey
         
      IF @cTTMTaskType = 'DPK'
      BEGIN
         SELECT @nTotPickQty = ISNULL(SUM(QtyMove), 0)     
         FROM RDT.RDTDPKLOG WITH (NOLOCK)            
         WHERE DropID = @cDropID          
           AND TaskDetailKey = @cTaskdetailkey     
           AND UserKey=@cUserName         

--         IF ISNULL( @nTotPickQty, 0) = 0
--            SELECT @nTotPickQty = ISNULL(SUM(Qty), 0)
--            FROM dbo.PickDetail WITH (NOLOCK) 
--            WHERE StorerKey = @cTaskStorer
--            AND   DropID = @cDropID
--            AND   [Status] = '3'
--            AND   SKU = @cSuggSKU     
      END 
      ELSE
      BEGIN
         SELECT @nTotPickQty = ISNULL(SUM(QtyMove), 0)     
         FROM RDT.RDTDPKLOG WITH (NOLOCK)            
         WHERE DropID = @cDropID          
           AND TaskDetailKey = @cTaskdetailkey     
           AND UserKey=@cUserName         

         SELECT @nTotPrevPickQty = ISNULL(SUM(Qty), 0) 
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE DropID = @cDropID
         AND   LoadKey = @cLoadkey
         AND   StorerKey = @cTaskStorer
         AND   SKU = @cSuggSKU
         AND   FROMLOC = @cFromLoc

         SET @nTotPickQty = @nTotPickQty + @nTotPrevPickQty
      END
      
      -- (jamesxx) Display system qty available    
      SET @nQtyAvail = 0     
      SELECT @nQtyAvail = ISNULL((SL.QTY - SL.QTYPicked), 0)     
      FROM dbo.SKUxLOC SL WITH (NOLOCK)      
      WHERE SL.StorerKey = @cTaskStorer     
        AND SL.Sku = @cSuggSKU      
        AND SL.LOC = @cFromLoc     
                
      /****************************                
       Prepare Next Screen                 
      ****************************/                
      SET @cOutField01 = @cTitle                
      SET @cOutField02 = @cID                
      SET @cOutField04 = SUBSTRING(@cDescr,1,20)                
      SET @cOutField05 = SUBSTRING(@cDescr,21,20)                
      SET @cOutField06 = @cMUOM_Desc                
      --(Kc03) -start                
    
      IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1'                 
      BEGIN                
         --bom sku goes to screen 5 to enter caseid     
    
         IF @nQtyAvail < @nTotPickQty + @nCaseQty    
         BEGIN    
            SET @nErrNo = 70209             
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --70209^QTYAVL<QTYMove                
            GOTO Step_4_Fail                  
         END     
             
         SET @nQtyAvail = @nQtyAvail - @nTotPickQty    
    
         SET @cOutField03 = @cBOMSKU                
         SET @cOutField07 = CAST((@nTotPickQty + @nCaseQty) AS NVARCHAR( 5))                
         SET @cOutField08 = CAST(@nTaskQty AS NVARCHAR( 5))                
         SET @cOutField09 = ''        
         SET @cOutField10 = @nQtyAvail -- @nQtyReplen            
    
         SET @nScn = @nScn + 1                
         SET @nStep = @nStep + 1                
         SET @nFromScn = 4                
         SET @nFromStep = 4                
      END                
      ELSE                
      BEGIN                
         --non-bom sku goes to screen 11 to enter qty                
         SET @cOutField03 = @cSku                
         SET @cOutField07 = @nSuggQty --CAST((@nTaskQty - @nTotPickQty) AS NVARCHAR( 5))                
         SET @cOutField08=''  
         SET @nQtyAvail = @nQtyAvail - @nTotPickQty     
         SET @cOutField09 = @nQtyAvail -- @nQtyReplen    
         SET @cOutField10=''  -- (james12)

         SET @cPrev_ToTote = ''

         SET @nScn = @nScn + 6                
         SET @nStep = @nStep + 7                
         
         EXEC rdt.rdtSetFocusField @nMobile, 10
      END                
      --(Kc03) end                
   END                
                
   IF @nInputKey = 0 -- ESC                
   BEGIN                
      SET @cOutField01 = @cTitle                
      SET @cOutField02 = ''                
      SET @cOutField03 = ''                
      SET @cOutfield04 = ''                
      SET @cOutField05 = ''                
      SET @cOutField06 = ''                
      SET @cOutField07 = ''                
      SET @cOutField08 = ''                
      SET @cOutField09 = ''                
      SET @cOutField10 = ''    
          
      SET @nFromScn = @nScn            
      SET @nFromStep = @nStep            
              
      SET @nScn = @nScn + 3                
      SET @nStep = @nStep + 3                
   END                
   GOTO Quit                
                
   Step_4_Fail:                
   BEGIN                
      SET @cOutField06 = ''                 
   END                
END                
GOTO Quit                
          
          
/********************************************************************************                
Step 5. screen = 2444                
    TITLE      (Field01, display)                
    PALLETID   (Field02, display)               
    BOMSKU     (Field03, display)                
    BOMSKUDESCR(Field04, display)                
    BOMSKUDESCR(Field05, display)                
    BOMUOM     (Field06, display)                
    QTY        (Field07/Field08 display)                
    CASEID     (Field09, input)                
********************************************************************************/                
Step_5:               
BEGIN        
   SET @cUserPosition = '1'                 --(Kc06)                
   IF @nInputKey = 1 -- ENTER                
   BEGIN                
      -- Screen mapping                
      SET @cCaseID    = @cInField09                
      SET @cBOMSku    = @cOutField03                
                
      /****************************                
       VALIDATION                 
      ****************************/                
      --blank CaseID                
      IF ISNULL(@cCaseID,'') = ''                
      BEGIN                
         SET @nErrNo = 70125                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CASE ID req                
         GOTO Step_5_Fail                  
      END                 
  
      SET @cDefaultCaseLength  = ''  
      SET @cDefaultCaseLength  = rdt.RDTGetConfig( @nFunc, 'DefaultCaseLength', @cStorerKey)    
      IF ISNULL(@cDefaultCaseLength, '') = ''  
      BEGIN    
         SET @cDefaultCaseLength = '8'  -- make it default to 8 digit if not setup  
      END    
  
      -- Check the length of tote no; 0 = no check (james09)  
      IF @cDefaultCaseLength <> '0'  
      BEGIN  
         IF LEN(RTRIM(@cCaseID)) <> @cDefaultCaseLength  
         BEGIN              
            SET @nErrNo = 70211                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV CASEID LEN                  
            GOTO Step_5_Fail                  
         END              
      END  
  
      -- Make sure the Case ID scanned is not a BOM SKU  
      IF EXISTS (SELECT 1 FROM dbo.BillOfMaterial WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey AND SKU = @cCaseID)  
      BEGIN              
         SET @nErrNo = 70212                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SCAN CASE ID                  
         GOTO Step_5_Fail                  
      END       
  
      -- Check for duplicate case id against rdt.rdtdpklog_bak    (james10)  
      IF EXISTS (SELECT 1 FROM rdt.rdtdpklog_bak WITH (NOLOCK) WHERE CaseID = @cCaseID)  
      BEGIN              
         SET @nErrNo = 70214                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Dup CASEID                  
         GOTO Step_5_Fail                  
      END       
  
      --(Kc03)                
      IF (@nFromStep = 11  AND  ISNULL(@nBoxQty,0) = 0)     --from non-BOMsku screen                
         OR (@nFromStep = 4 AND ISNULL(@nCaseQty,0) = 0 )   --from BOMSku screen                
      BEGIN                
         SET @nErrNo = 70126                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv CaseQty                
         GOTO Step_5_Fail                  
      END                 
                
      --(Kc10) - start                
      IF ISNUMERIC(@cCaseID) = 0                  
      BEGIN                  
         SET @nErrNo = 70162                   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCaseID                 
         GOTO Step_5_Fail                
      END                  
                
      SET @nErrNo = 0                
      SET @cErrMsg = ''                
      SET @bSuccess = 0                
                
      EXEC dbo.isp_WMS2WCSRoutingValidation                   
           @cCaseID,                   
           @cTaskStorer,                  
           @bSuccess OUTPUT,                  
           @nErrno  OUTPUT,                   
           @cErrMsg OUTPUT                  
                  
      IF @nErrNo <> 0                   
      BEGIN                  
         SET @nErrNo = @nErrNo                
         SET @cErrMsg = @cErrMsg                   
         GOTO Step_5_Fail                 
      END                  
      --(Kc10) - end                
                
      --(Kc14) - start            
                
      IF EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK)     
                 Where UCCNo = @cCaseID     
                 AND SKU = @cSuggSKU     
                 AND Sourcekey = @cTaskdetailkey)                
      BEGIN                
         SET @nErrNo = 70188        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Dup CASEID             
         GOTO Step_5_Fail                  
      END                 
      --(Kc14) - end            
            
      --(Shong03)          
      --IF @cTTMTasktype = 'DRP'          
      BEGIN          
--         IF EXISTS( SELECT 1 FROM rdt.rdtDPKLog WITH (NOLOCK)     
--                    WHERE CaseID = @cCaseID     
--                    AND SKU <> @cSuggSKU     
--                    AND UserKey=@cUserName)                                  
         IF EXISTS( SELECT 1 FROM UCC WITH (NOLOCK)     
                    WHERE UCCNo = @cCaseID     
                    AND   Storerkey = @cTaskStorer     
                    AND SKU <> @cSuggSKU )          
         BEGIN                
            SET @nErrNo = 70191                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --70191^DO NOT MIX SKU             
            GOTO Step_5_Fail                  
         END                          
      END          
                
      --(Kc03)                
      IF @nFromStep = 4                
      BEGIN                
         SET @nBoxQty = @nCaseQty                
      END                
                
      SET @bProcessStart = 1                
      /****************************                
       PROCESSNG CASEID                 
      ****************************/                
      BEGIN TRAN                
                
      --DropID                
      IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) Where DropID = @cDropID)                
      BEGIN                
         INSERT INTO dbo.DROPID                
         (DropID, DropLoc, DropIDType, Status,  Loadkey)                
         Values                
         (@cDropID, '', 'C', '0', @cLoadkey)                
         IF @@ERROR <> 0                
         BEGIN                
            ROLLBACK TRAN                
            SET @nErrNo = 70130           
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsDropIDFail           
            GOTO Step_5_Fail                   
         END                
      END                
                      
      --DropIDDetail                
      IF NOT EXISTS (SELECT 1 FROM dbo.DROPIDDETAIL WITH (NOLOCK) Where DropID = @cDropID And ChildID = @cCaseID)                
      BEGIN                
         INSERT INTO dbo.DROPIDDETAIL (DropID, ChildID)                
         VALUES (@cDropID, @cCaseID)                
                
         IF @@ERROR <> 0                
         BEGIN                
            ROLLBACK TRAN                
            SET @nErrNo = 70131                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsDpIDDetFail                
            GOTO Step_5_Fail                   
         END                
      END                
                
      SET @nErrno = 0            
      IF @cTTMTasktype = 'DRP'                
      BEGIN                
         EXEC rdt.rdt_TMDynamicPick_LogReplen            
         @cDropID        = @cDropID,                
         @cLoadkey       = @cLoadkey,                
         @cCaseID        = @cCaseID,                         
         @cStorer        = @cTaskStorer,                
         @cSku           = @cSuggSKU,                
         @cFromLoc       = @cFromLoc,                
         @cID            = @cID,                
         @cLot           = @cSuggLot,                
         @cBOMSku        = @cBOMSku,                
         @cTaskdetailkey = @cTaskdetailkey,                
         @nPrevTotQty    = @nTotPickQty,                
         @nCaseQty       = @nBoxQty,      --(Kc03)                
         @nTaskQty       = @nTaskQty,                
         @cLangCode      = @cLangCode,                
         @nTotPickQty    = @nTotPickQty   OUTPUT,                
         @nErrNo         = @nErrno        OUTPUT,                
         @cErrMsg        = @cErrMsg       OUTPUT,                 
         @nMobile        = @nMobile,               --(Kc12)            
         @nFunc          = @nFunc,             --(Kc12)                 
         @cFacility      = @cFacility,             --(Kc12)            
         @cUserName      = @cUserName              --(Kc12)               
            
         IF @nErrno <> 0                 
         BEGIN                
            ROLLBACK TRAN                
            SET @nErrNo = @nErrNo         
            SET @cErrMsg = @cErrMsg                
            GOTO Step_5_Fail                
         END                
      END                
      ELSE                
      BEGIN -- DPK Task                
         EXEC rdt.rdt_TMDynamicPick_LogPick                
         @cDropID        = @cDropID,                
         @cLoadkey       = @cLoadkey,                
         @cCaseID        = @cCaseID,                
         @cStorer        = @cTaskStorer,                
         @cSku           = @cSuggSKU,                
         @cFromLoc       = @cFromLoc,                
         @cID            = @cID,                
         @cLot           = @cSuggLot,                
         @cBOMSku        = @cBOMSku,                
         @cTaskdetailkey = @cTaskdetailkey,                
         @nPrevTotQty    = @nTotPickQty,                
         @nCaseQty       = @nBoxQty,               --(Kc03)                
         @nTaskQty       = @nTaskQty,                
         @cLangCode      = @cLangCode,                
         @cUserName      = @cUserName,             --(Kc02)                
         @nTotPickQty    = @nTotPickQty   OUTPUT,                
         @nErrNo         = @nErrno        OUTPUT,                
         @cErrMsg        = @cErrMsg       OUTPUT,            
         @nMobile        = @nMobile,               --(Kc12)            
         @nFunc          = @nFunc,                 --(Kc12)                 
         @cFacility      = @cFacility              --(Kc12)            
                
         IF @nErrno <> 0                 
         BEGIN                
            ROLLBACK TRAN                
            SET @nErrNo = @nErrNo                
            SET @cErrMsg = @cErrMsg                
            GOTO Step_5_Fail             
         END                
      END   -- @cTTMTasktype = DPK                
                
--      COMMIT TRAN         
      /****************************                
       Prepare Next Screen                 
      ****************************/                
      IF @nTotPickQty >= @nTaskQty                
      BEGIN                
         SELECT TOP 1 @cDefaultToLoc = ISNULL(RTRIM(CL.Short),''),   -- (Vicky05)              
                      @cPickToZone = ISNULL(RTRIM(CL.Short),'')                
         FROM  dbo.Codelkup CL WITH (NOLOCK)                
         WHERE CL.Listname = 'WCSROUTE'                
         AND   CL.Code     = @cPickType                
    
         SET @nCurrentTranCount = @@TRANCOUNT    
    
         EXEC rdt.rdt_TMDynamicPick_MoveCase     
            @cDropID    =@cDropID,      
            @cTaskdetailkey      =@cTaskdetailkey,    
            @cUserName           =@cUserName,            
            @cToLoc              =@cDefaultToLoc,    
            @nErrNo              =@nErrNo  OUTPUT,    
            @cErrMsg             =@cErrMsg OUTPUT    
         IF @nErrno <> 0                 
         BEGIN                
            --IF @@TRANCOUNT > @nCurrentTranCount -- (ChewKP04)   
               ROLLBACK TRAN                
            SET @nErrNo = @nErrNo         
            SET @cErrMsg = @cErrMsg                
            GOTO Step_5_Fail                
         END                
             
         UPDATE dbo.Taskdetail With (rowlock)            
         SET   Status = '9',                 
               UserPosition = @cUserPosition,      --(Kc09)                
               EndTime = GETDATE(),--CURRENT_TIMESTAMP,        --(Kc09) -- (Vicky02)                
               EditDate = GETDATE(),--CURRENT_TIMESTAMP,       --(Kc09) -- (Vicky02)                
               EditWho  = @cUserName               --(Kc09)                
         WHERE Taskdetailkey = @cTaskdetailkey                
                
         IF @@ERROR <> 0       
         BEGIN                
            --IF @@TRANCOUNT > @nCurrentTranCount    
               ROLLBACK TRAN                
            SET @nErrNo = 70139                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail                
            GOTO Step_5_Fail                   
         END                
      
         -- (james05)      
         SET @nQtyMoved = 0       
         SELECT @nQtyMoved = ISNULL(SUM(QTY), 0)       
         FROM dbo.UCC WITH (NOLOCK)       
         WHERE StorerKey = @cStorerKey      
            AND SourceKey = @cTaskdetailkey      
      
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET       
            Qty = @nQtyMoved,       
            Trafficcop = NULL       
         WHERE TaskDetailKey = @cTaskDetailKey      
      
         IF @@ERROR <> 0                
         BEGIN                
            --IF @@TRANCOUNT > @nCurrentTranCount    
               ROLLBACK TRAN                
            SET @nErrNo = 70206                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail                
            GOTO Step_5_Fail                   
         END                
      
         SET @nTotPickQty = 0    
    
         COMMIT TRAN    
         -- close pallet                
         SET @cOutField01 = @cTitle                
         SET @cOutField02 = ''                
                
         SET @nScn = @nScn + 1                
         SET @nStep = @nStep + 1                
      END                
      ELSE                
      BEGIN             
         COMMIT TRAN    
       
         SET @cOutField01 = @cTitle                
         SET @cOutField02 = @cID                
         SET @cOutField03 = @cSuggSku                
         SET @cOutField04 = SUBSTRING(@cDescr,1,20)                
         SET @cOutField05 = SUBSTRING(@cDescr,21,20)                
         --(Kc03) - start                
         IF @nFromStep = 4                
         BEGIN                
            --loop back to bomsku screen (SCN 4)                
--            SET @cOutField06 = @cInField06                
            SET @cOutField06 = ''            
            SET @cOutField07 = @cUOM                
            SET @cOutField08 = CAST(@nTotPickQty AS NVARCHAR( 5))                
            SET @cOutField09 = CAST(@nTaskQty AS NVARCHAR( 5))                
            SET @nScn = @nScn - 1                
            SET @nStep = @nStep - 1                
         END                
         ELSE                
         BEGIN    
            SET @nQtyAvail = 0     
            SELECT @nQtyAvail = ISNULL((SL.QTY - SL.QTYPicked), 0)     
            FROM dbo.SKUxLOC SL WITH (NOLOCK)      
            WHERE SL.StorerKey = @cTaskStorer     
              AND SL.Sku = @cSuggSKU      
              AND SL.LOC = @cFromLoc     
    
            SET @nTotPickQty=0                
            SELECT @nTotPickQty = ISNULL(SUM(QtyMove), 0)     
            FROM RDT.RDTDPKLOG WITH (NOLOCK)            
            WHERE DropID = @cDropID          
              AND TaskDetailKey = @cTaskdetailkey     
              AND UserKey=@cUserName            
    
            SET @nQtyAvail = @nQtyAvail - @nTotPickQty     
                                                
            --loop back to non-bomsku screen (SCN 11)                
            SET @cOutField06 = @cUOM                
            --SET @cOutField07 = CAST(@nTaskQty AS NVARCHAR( 5)) (Shong03)          
            SET @cOutField07 = CAST((@nTaskQty - @nTotPickQty) AS NVARCHAR( 5))          
            --SET @cOutField08 = CAST(@nCaseQty AS NVARCHAR( 5))                
            SET @cOutField08 = ''    
            SET @cOutField09 = CAST(@nQtyAvail AS NVARCHAR( 5))                
            SET @nScn = @nScn + 5                
            SET @nStep = @nStep + 6           
         END                
         --(Kc03) end                
      END                
   END                
                
   IF @nInputKey = 0 -- ESC                
   BEGIN                
      SET @cOutField01 = @cTitle                
      SET @cOutField02 = @cID                
      SET @cOutField03 = @cSuggSku                
      SET @cOutField04 = SUBSTRING(@cDescr,1,20)                
      SET @cOutField05 = SUBSTRING(@cDescr,21,20)                
      --(Kc03) - start                
      IF @nFromStep = 4                
      BEGIN                
         SET @cOutField06 = ''                
         SET @cOutField07 = @cUOM                
         SET @cOutField08 = CAST(@nTotPickQty AS NVARCHAR( 5))                
         SET @cOutField09 = CAST(@nTaskQty AS NVARCHAR( 5))                
                
         SET @nScn = @nScn - 1                
         SET @nStep = @nStep - 1                
      END                
      ELSE                
      BEGIN                
         SET @nQtyAvail = 0     
         SELECT @nQtyAvail = ISNULL((SL.QTY - SL.QTYPicked), 0)     
         FROM dbo.SKUxLOC SL WITH (NOLOCK)      
         WHERE SL.StorerKey = @cTaskStorer     
           AND SL.Sku = @cSuggSKU      
           AND SL.LOC = @cFromLoc     
    
         SET @nTotPickQty=0                
         SELECT @nTotPickQty = ISNULL(SUM(QtyMove), 0)     
         FROM RDT.RDTDPKLOG WITH (NOLOCK)            
         WHERE DropID = @cDropID          
           AND TaskDetailKey = @cTaskdetailkey     
           AND UserKey=@cUserName         
    
         SET @nQtyAvail = @nQtyAvail - @nTotPickQty    
                      
         SET @cOutField06 = @cUOM                
         SET @cOutField07 = CAST((@nTaskQty - @nTotPickQty) AS NVARCHAR( 5))                
         --SET @cOutField08 = CAST(@nCaseQty AS NVARCHAR( 5))    
         SET @cOutField09 = CAST(@nQtyAvail AS NVARCHAR( 5))    
                         
         SET @cOutField08 = ''                
         SET @nScn = @nScn + 5                
         SET @nStep = @nStep + 6                
      END            
      --(Kc03) end                
   END                
   GOTO Quit                
                
   Step_5_Fail:               
   BEGIN    
      SET @nTotPickQty=0                
      SELECT @nTotPickQty = ISNULL(SUM(QtyMove), 0)     
      FROM RDT.RDTDPKLOG WITH (NOLOCK)            
      WHERE DropID = @cDropID          
        AND TaskDetailKey = @cTaskdetailkey     
        AND UserKey=@cUserName            
                       
--      IF @bProcessStart = 1                
--      BEGIN                
--         SET @nTotPickQty = @nTotPickQty - @nCaseQty                
--      END                
      SET @cOutField09 = ''                 
   END                
END                
GOTO Quit                
                
/********************************************************************************                
Step 6. screen = 2445 (Cont Next Task/Close Pallet)                
    Title      (Field01, display)                
    Option     (Field02, input)                
********************************************************************************/                
Step_6:                
BEGIN                
   SET @cUserPosition = '1'                 --(Kc06)                
   IF @nInputKey = 1 -- ENTER                
   BEGIN                
      SET @cOption = @cInField02                
                
      /****************************                
       VALIDATION                 
      ****************************/                
      --blank Option                
      IF @cOption = ''                
      BEGIN                
         SET @nErrNo = 70132                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req                
         GOTO Step_6_Fail                  
      END                 
                  
      --valid option                
      IF @cOption <> '1' AND @cOption <> '9'                
      BEGIN                
         SET @nErrNo = 70133                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option                
         GOTO Step_6_Fail                  
      END                 
                
      /***************************                
        PROCESSING                
      ***************************/           
      IF @cOption = '1'                
      BEGIN -- cont next task                
         -- Search for next task and redirect screen   
         -- Only can retrieve DPK & DRP task as other task
         -- will have different type screen             
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK) 
                     JOIN dbo.LOC LOC (NOLOCK) ON TD.FromLoc = LOC.Loc  
                     JOIN dbo.AREADETAIL AD (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                     WHERE TD.TaskType IN ( 'DPK', 'DRP')
                     AND   TD.Status = '0'
                     AND   AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END  )
         BEGIN
            EXEC dbo.nspTMTM01                
                @c_sendDelimiter = null                
             ,  @c_ptcid         = 'RDT'                
             ,  @c_userid        = @cUserName                
             ,  @c_taskId        = 'RDT'                
             ,  @c_databasename  = NULL                
             ,  @c_appflag       = NULL                
             ,  @c_recordType    = NULL                
             ,  @c_server        = NULL                
             ,  @c_ttm           = NULL                
             ,  @c_areakey01     = @cAreaKey                
             ,  @c_areakey02     = ''                
             ,  @c_areakey03     = ''                
             ,  @c_areakey04     = ''                
             ,  @c_areakey05     = ''                
             ,  @c_lastloc       = @cFromLoc                
             ,  @c_lasttasktype  = @cTTMTasktype                
             ,  @c_outstring     = @c_outstring    OUTPUT                
             ,  @b_Success       = @b_Success      OUTPUT                
             ,  @n_err           = @nErrNo         OUTPUT                
             ,  @c_errmsg        = @cErrMsg        OUTPUT              
             ,  @c_taskdetailkey = @cNextTaskdetailkey OUTPUT                
             ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT                
             ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func                
             ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func                
             ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func                
             ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func                
             ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func                
         END
         ELSE
            SET @cNextTaskdetailkey = ''

         IF ISNULL(RTRIM(@cNextTaskdetailkey), '') = '' --@nErrNo = 70134 -- Nothing to do!                
         BEGIN                
            SET @nErrNo = 70134                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoMoreTask                
            GOTO Step_6_Fail                   
         END        
            
         SET @cTaskdetailkey = @cNextTaskdetailkey                
         SELECT @cTaskStorer  = Storerkey,                 
                @cSuggID      = FromID,            
                @cSuggLot     = Lot,  -- (shong02)            
                @cSuggFromLoc = FromLOC,                
                @cSuggToloc   = ToLoc,                
                @cSuggSKU     = SKU,                
                @cLoadKey     = LoadKey,                 
                @nTaskQty     = Qty                
         FROM dbo.TaskDetail WITH (NOLOCK)                
         WHERE TaskDetailKey = @cTaskdetailkey                
                
         /****************************                
          Prepare Next Screen                 
         ****************************/                
                
         -- (james02) When Get the first Task Update EditDate          
         BEGIN TRAN          
         UPDATE dbo.TaskDetail With (ROWLOCK)          
         SET StartTime = GETDATE(),           
             EditDate = GETDATE(),          
             EditWho = @cUserName,          
             Trafficcop = NULL           
         WHERE TaskDetailkey = @cTaskdetailkey          
                   
         IF @@ERROR <> 0          
         BEGIN          
            SET @nErrNo = 70193          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'          
            ROLLBACK TRAN          
            GOTO Step_6_Fail           
         END          
         ELSE          
         BEGIN          
            COMMIT TRAN          
         END          

         IF @cSuggFromLoc <> @cFromLoc                
         BEGIN                
          -- back to Loc screen                
            SET @cOutField01 = @cTitle                
            SET @cOutField02 = @cPickType                
            SET @cOutField03 = @cDropID                
            SET @cOutField04 = @cSuggFromLoc                
            SET @cOutField05 = ''                
                
            SET @nFromStep = 6                
            SET @nFromScn  = 6                
            SET @nScn = @nScn - 4                
            SET @nStep = @nStep - 4                
         END                
         ELSE                
         BEGIN                
            --back to ID screen                
            SET @cOutField01 = @cTitle                
            SET @cOutField02 = @cPickType                
            SET @cOutField03 = @cDropID                
            SET @cOutField04 = @cFromLoc                
            SET @cOutField05 = @cSuggID                
            SET @cOutField06 = ''                
                
            SET @nFromStep = 6                
            SET @nFromScn  = 6                
            SET @nScn = @nScn - 3                
            SET @nStep = @nStep - 3                
         END                
      END                
      ELSE --close pallet                
      BEGIN          
         --IF @nTotPickQty = 0                
         --(Shong09)    
/*    
         IF NOT EXISTS(SELECT 1 FROM rdt.rdtDPKLOG (NOLOCK) WHERE UserKey = @cUserName)    
         BEGIN                
            SET @nErrNo = 70135                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Nothing Picked                
            GOTO Step_6_Fail                  
         END                
*/    
                
         BEGIN TRAN                
         --update dropid                
         IF @cTTMTaskType = 'DPK'    
         BEGIN    
            UPDATE dbo.DROPID WITH (ROWLOCK)                
            SET   Status = '5', EditWho = 'rdt.' + sUser_sName(), EditDate = GetDate()                 
            WHERE Dropid = @cDropID                
         END    
         ELSE -- (james07)    
         BEGIN    
            UPDATE dbo.DROPID WITH (ROWLOCK)                
            SET   Status = '9', EditWho = 'rdt.' + sUser_sName(), EditDate = GetDate()                
            WHERE Dropid = @cDropID                
         END    
    
         IF @@ERROR <> 0                   
         BEGIN                
            ROLLBACK TRAN                
            SET @nErrNo = 70136                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdDropIDFail                
            GOTO Step_6_Fail                   
         END                

         IF @cTTMTaskType = 'DPK'    
         BEGIN    
            UPDATE dbo.UCC WITH (ROWLOCK) SET 
               [Status] = '4'
            WHERE UCCNo IN 
               (SELECT ChildID FROM dbo.DropIDDetail DD 
                JOIN dbo.DropID D ON DD.DropID = D.DropID 
               WHERE D.Dropid = @cDropID AND [Status] = '5' AND DropIDType = 'C')
            AND [Status] = '0'

            IF @@ERROR <> 0                   
            BEGIN                
               ROLLBACK TRAN                
               SET @nErrNo = 50155                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UCC FAIL                
               GOTO Step_6_Fail                   
            END            
         END

         IF @cTTMTaskType = 'DRP'    
         BEGIN    
            UPDATE dbo.UCC WITH (ROWLOCK) SET 
               [Status] = '6'
            WHERE UserDefined04 = @cDropID
            AND   SourceType = 'RDTDynamicReplen'
            AND   [Status] < '6'
            AND   EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) 
                           WHERE UCC.UCCNo = TaskDetail.CaseID 
                           AND TaskDetail.Status in ('0', '3', 'W') 
                           AND TaskDetail.TaskType = 'PA')

            IF @@ERROR <> 0                   
            BEGIN                
               ROLLBACK TRAN                
               SET @nErrNo = 50159                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UCC FAIL                
               GOTO Step_6_Fail                   
            END            
         END

-- (SHONGxx)                   
--         IF @cTTMTaskType = 'DPK'                
--         BEGIN                
--            DECLARE C_WCSROUTE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
--            SELECT DROPIDDETAIL.ChildID                
--            FROM   dbo.DROPIDDETAIL DROPIDDETAIL WITH (NOLOCK)                
--            JOIN   dbo.DROPID DROPID WITH (NOLOCK) ON (DROPID.DROPID = DROPIDDETAIL.DROPID)                
--            WHERE  DROPID.DropID = @cDropID                
--            AND    DROPID.Status = '5'                
--            ORDER BY DROPIDDETAIL.ChildID                
--                
--            OPEN C_WCSROUTE                
--            FETCH NEXT FROM C_WCSROUTE INTO  @cCaseID                
--            WHILE (@@FETCH_STATUS <> -1)                
--            BEGIN                
--               SET @cErrMsg = ''                
--               EXEC dbo.nspInsertWCSRouting                
--                @c_Storerkey     = @cTaskStorer                
--               ,@c_Facility      = @cFacility                
--               ,@c_ToteNo        = @cCaseID                
--               ,@c_TaskType      = 'PK'                
--               ,@c_ActionFlag    = 'N'                
--               ,@c_TaskDetailKey = @cTaskdetailkey                
--               ,@c_Username      = @cUsername                
--               ,@b_debug         = 0                
--               ,@b_Success       = @b_Success   OUTPUT                
--               ,@n_ErrNo         = @nErrNo      OUTPUT                
--               ,@c_ErrMsg        = @cErrMsg     OUTPUT                
--                
--               IF ISNULL(RTRIM(@cErrMsg),'') <> ''                
--               BEGIN                
--                  ROLLBACK TRAN                
--                  SET @nErrNo = @nErrNo                
--                  SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'                
--                  GOTO Step_6_Fail                   
--               END                
--               ELSE                
--               BEGIN                
--                  COMMIT TRAN                
--               END                
--                
--               FETCH NEXT FROM C_WCSROUTE INTO  @cCaseID                
--            END                
--            CLOSE C_WCSROUTE                
--            DEALLOCATE C_WCSROUTE                
--         END -- @cTTMTaskType = 'DPK'                
                         
         -- goto TOLOC screen                
         SELECT TOP 1 @cDefaultToLoc = ISNULL(RTRIM(CL.Short),''),  -- (Vicky05)              
                      @cPickToZone = ISNULL(RTRIM(CL.Short),'')                
         FROM  dbo.Codelkup CL WITH (NOLOCK)                
        -- JOIN  dbo.Loc LOC WITH (NOLOCK) ON (LOC.Putawayzone = CL.Short)                
         WHERE CL.Listname = 'WCSROUTE'                
         AND   CL.Code     = @cPickType                
         
         SET @cOutField01 = @cTitle                
         SET @cOutField02 = @cFromLoc                
         SET @cOutField03 = @cDropID                
         SET @cOutField04 = @cDefaultToLoc                
                
         SET @nScn = @nScn + 2                
         SET @nStep = @nStep + 2           
         
         COMMIT TRAN -- (ChewKP03)
         
              
      END   --option = 9                
   END                
                
--   IF @nInputKey = 0 -- ESC                
--   BEGIN                
--      SET @nScn = @nScn - 1                
--      SET @nStep = @nStep - 1                
--   END                   
   Goto Quit                
                
   Step_6_Fail:                
   BEGIN                
      SET @cOutField02 = ''                 
   END                
                
END                
GOTO Quit                
                
                
/********************************************************************************                
Step 7. screen = 2446 (ShortPick/Close Pallet)                
    Title      (Field01, display)                
    Option     (Field02, input)                
********************************************************************************/                
Step_7:                
BEGIN                
   SET @cUserPosition = '1'                 --(Kc06)                
   IF @nInputKey = 1 -- ENTER                
   BEGIN                
      SET @cOption = @cInField02                
                
      /****************************                
       VALIDATION                 
      ****************************/                
      --blank Option                
      IF @cOption = ''                
      BEGIN                
         SET @nErrNo = 70166                   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req                
         GOTO Step_7_Fail                  
      END                 
          
      SET @nTotPickQty=0     
      SET @nShortQty=0    
                      
      SELECT @nTotPickQty = ISNULL(SUM(QtyMove), 0)     
      FROM RDT.RDTDPKLOG WITH (NOLOCK)            
      WHERE TaskDetailKey = @cTaskdetailkey     
        AND UserKey=@cUserName            
    
      SELECT @nShortQty = Qty - @nTotPickQty     
      FROM dbo.TaskDetail WITH (NOLOCK)                 
      WHERE TaskDetailKey = @cTaskdetailkey    
            
      --valid option                
      IF @cOption <> '1' AND @cOption <> '9'                
      BEGIN                
         SET @nErrNo = 70167                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option                
         GOTO Step_7_Fail                  
      END                 
                
      IF @cOption = 1                
      BEGIN                
         -- goto reasoncode screen                
         SET @nFromScn = @nScn                
         SET @nFromStep = @nStep                
                
         SET @cOutField01 = ''                
         SET @nScn  = 2109                
         SET @nStep = @nStep + 3 -- Step 10                
      END                
      ELSE--@cOption = 9                
      BEGIN                
         IF @nTotPickQty = 0                
         BEGIN                
            SET @nErrNo = 70168                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Nothing Picked                
            GOTO Step_7_Fail                  
         END                
             
         IF @nShortQty > 0                
         BEGIN                
            SET @nErrNo = 71443                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --71443^ShortPickFound                
            GOTO Step_7_Fail                  
         END    
                
         BEGIN TRAN                
                
         --update dropid                
         IF @cTTMTaskType = 'DPK'    
         BEGIN    
            UPDATE dbo.DROPID WITH (ROWLOCK)                
            SET   Status = '5', EditWho = 'rdt.' + sUser_sName(), EditDate = GetDate()                
            WHERE Dropid = @cDropID                
         END    
         ELSE -- (james07)    
         BEGIN    
            UPDATE dbo.DROPID WITH (ROWLOCK)                
            SET   Status = '9', EditWho = 'rdt.' + sUser_sName(), EditDate = GetDate()                 
            WHERE Dropid = @cDropID                
         END    
     
         IF @@ERROR <> 0                
         BEGIN                
            ROLLBACK TRAN                
            SET @nErrNo = 70169                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdDropIDFail                
            GOTO Step_7_Fail                   
         END                
                
--         IF @cTTMTaskType = 'DPK'                
--         BEGIN                
--            DECLARE C_WCSROUTE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
--            SELECT DROPIDDETAIL.ChildID                
--            FROM   dbo.DROPIDDETAIL DROPIDDETAIL WITH (NOLOCK)                
--           JOIN   dbo.DROPID DROPID WITH (NOLOCK) ON (DROPID.DROPID = DROPIDDETAIL.DROPID)                
--            WHERE  DROPID.DropID = @cDropID                
--            AND    DROPID.Status = '5'                
--            ORDER BY DROPIDDETAIL.ChildID                        
--            OPEN C_WCSROUTE                
--            FETCH NEXT FROM C_WCSROUTE INTO  @cCaseID                
--            WHILE (@@FETCH_STATUS <> -1)                
--            BEGIN                
--               SET @cErrMsg = ''                
--               EXEC dbo.nspInsertWCSRouting                
--                @c_Storerkey     = @cTaskStorer                
--               ,@c_Facility      = @cFacility                
--               ,@c_ToteNo        = @cCaseID                
--               ,@c_TaskType      = 'PK'                
--               ,@c_ActionFlag    = 'N'                
--               ,@c_TaskDetailKey = @cTaskdetailkey                
--               ,@c_Username      = @cUsername                
--               ,@b_debug         = 0                
--               ,@b_Success       = @b_Success   OUTPUT                
--               ,@n_ErrNo         = @nErrNo      OUTPUT                
--               ,@c_ErrMsg        = @cErrMsg     OUTPUT                
--                
--             IF ISNULL(RTRIM(@cErrMsg),'') <> ''                         BEGIN                
--                  ROLLBACK TRAN                
--                  SET @nErrNo = @nErrNo                
--                  SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'                
--                  GOTO Step_7_Fail                   
--               END                
--               ELSE                
--               BEGIN                
--                  COMMIT TRAN                
--               END                
--                
--               FETCH NEXT FROM C_WCSROUTE INTO  @cCaseID                
--            END                
--            CLOSE C_WCSROUTE                
--            DEALLOCATE C_WCSROUTE                
--         END --@cTTMTasktype = 'DPK'    
                
         IF @nTotPickQty > 0                
         BEGIN                
            SELECT TOP 1 @cDefaultToLoc = ISNULL(RTRIM(CL.Short),''),   -- (Vicky05)              
                         @cPickToZone = ISNULL(RTRIM(CL.Short),'')                
            FROM  dbo.Codelkup CL WITH (NOLOCK)                
            WHERE CL.Listname = 'WCSROUTE'                
            AND   CL.Code     = @cPickType                
    
            SET @nCurrentTranCount = @@TRANCOUNT    
    
            EXEC rdt.rdt_TMDynamicPick_MoveCase     
               @cDropID             =@cDropID,      
               @cTaskdetailkey      =@cTaskdetailkey,    
               @cUserName           =@cUserName,            
               @cToLoc              =@cDefaultToLoc,    
               @nErrNo              =@nErrNo  OUTPUT,    
               @cErrMsg             =@cErrMsg OUTPUT    
            IF @nErrno <> 0                 
            BEGIN                
               IF @@TRANCOUNT > @nCurrentTranCount    
                  ROLLBACK TRAN                
               SET @nErrNo = @nErrNo         
               SET @cErrMsg = @cErrMsg                
               GOTO Step_5_Fail                
            END                
                
            UPDATE dbo.Taskdetail With (rowlock)                
            SET   Status = '9',                 
                  UserPosition = @cUserPosition,      --(Kc09)                
                  EndTime = GETDATE(),--CURRENT_TIMESTAMP,        --(Kc09) -- (Vicky02)                
                  EditDate = GETDATE(),--CURRENT_TIMESTAMP,       --(Kc09) -- (Vicky02)                
                  EditWho  = @cUserName               --(Kc09)                
            WHERE Taskdetailkey = @cTaskdetailkey                
  
            IF @@ERROR <> 0                
            BEGIN                
               --IF @@TRANCOUNT > @nCurrentTranCount    
                  ROLLBACK TRAN                
               SET @nErrNo = 70139                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail                
               GOTO Step_5_Fail                   
            END                
         
            -- (james05)      
            SET @nQtyMoved = 0       
            SELECT @nQtyMoved = ISNULL(SUM(QTY), 0)       
            FROM dbo.UCC WITH (NOLOCK)       
            WHERE StorerKey = @cStorerKey      
               AND SourceKey = @cTaskdetailkey      
         
            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET       
               Qty = @nQtyMoved,       
               Trafficcop = NULL       
            WHERE TaskDetailKey = @cTaskDetailKey      
         
            IF @@ERROR <> 0                
            BEGIN                
               --IF @@TRANCOUNT > @nCurrentTranCount    
                  ROLLBACK TRAN                
               SET @nErrNo = 70206                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail                
               GOTO Step_5_Fail                   
            END                
         
            SET @nTotPickQty = 0    
    
            COMMIT TRAN    
         END      
                                     
         -- goto TOLOC screen                
         SELECT TOP 1 @cDefaultToLoc = ISNULL(RTRIM(CL.Short),''),   -- (Vicky05)              
          @cPickToZone = ISNULL(RTRIM(CL.Short),'')                
         FROM  dbo.Codelkup CL WITH (NOLOCK)                
        -- JOIN  dbo.Loc LOC WITH (NOLOCK) ON (LOC.Putawayzone = CL.Short)                
         WHERE CL.Listname = 'WCSROUTE'                
         AND   CL.Code     = @cPickType                
                
         SET @cOutField01 = @cTitle                
         SET @cOutField02 = @cFromLoc                
         SET @cOutField03 = @cDropID                
         SET @cOutField04 = @cDefaultToLoc                
                
         SET @nScn = @nScn + 1                
         SET @nStep = @nStep + 1                
      END                
   END                
                
   IF @nInputKey = 0 -- ESC                
   BEGIN                
      -- (james01)            
      SELECT @nQtyPicked = ISNULL(SUM(QtyMove), 0)     
      FROM RDT.RDTDPKLOG WITH (NOLOCK)            
      WHERE DropID = @cDropID          
        AND TaskDetailKey = @cTaskdetailkey            
            
      SELECT                
         @cDescr = SKU.Descr,                
         @cMUOM_Desc = Pack.PackUOM3,                
         @cPackKey   = Pack.PackKey                
      FROM dbo.SKU SKU WITH (NOLOCK)                
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)                
      WHERE SKU.StorerKey = @cTaskStorer                
         AND SKU.SKU = @cSuggSKU            
            
      SET @cOutField01 = @cTitle                
      SET @cOutField02 = @cID                
      SET @cOutField03 = @cSuggSKU                
      SET @cOutField04 = SUBSTRING(@cDescr,1,20)                
      SET @cOutField05 = SUBSTRING(@cDescr,21,20)                      SET @cOutField06 = ''            
      SET @cInField06  = ''                
      SET @cOutField07 = @cMUOM_Desc                
      SET @cOutField08 = @nQtyPicked                
      SET @cOutField09 = CAST(@nTaskQty AS NVARCHAR( 5))                
            
      SET @nScn = @nFromScn                 
      SET @nStep = @nFromStep                 
   END                   
   Goto Quit                
                
   Step_7_Fail:                
   BEGIN                
      SET @cOutField02 = ''                 
   END                
                
END                
GOTO Quit                
                
/********************************************************************************                
Step 8. screen = 2447                 
    Title       (Field01, display)                
    FromLoc     (Field02, display)                
    DropID      (Field03, display)                
    ToLoc       (Field04, input)                
********************************************************************************/                
Step_8:        BEGIN                
   SET @cUserPosition = '2'                 --(Kc06)                
   IF @nInputKey = 1 -- ENTER                
   BEGIN                
      SET @cToLoc = @cInField04                
      SET @cDefaultToLoc = @cOutField04                
                      
      /****************************                
       VALIDATION                 
      ****************************/                
      --blank Option                
      IF @cToLoc = ''                
      BEGIN                
         SET @nErrNo = 70137                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Toloc req                
         GOTO Step_8_Fail                  
      END                 

      -- (james14)
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cTaskStorer)
      IF @cExtendedValidateSP = '0'  
         SET @cExtendedValidateSP = ''

      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskStorer, @cTaskDetailKey, @cToID, @cFromLoc, @cFromID, @cToLOC, @cSKU, 
              @cCaseID, @nQty, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cTaskStorer     NVARCHAR( 15), ' +
               '@cTaskDetailKey  NVARCHAR( 10), ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cFromLoc        NVARCHAR( 10), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@cCaseID         NVARCHAR( 20), ' +
               '@nQty            INT, ' +
               '@nErrNo          INT           OUTPUT, ' + 
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskStorer, @cTaskDetailKey, @cDropID, @cFromLoc, @cID, @cToLoc, @cSKU, 
               @cCaseID, @nBoxQty, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            
            IF @nErrNo <> 0 OR ISNULL( @cErrMsg, '') <> ''
               GOTO Step_1_Fail
         END  
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOlOCK) WHERE Loc = @cToLoc and Facility = @cFacility)                
      BEGIN                
         SET @nErrNo = 70138                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Facility                
         GOTO Step_8_Fail                  
      END                 

      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE Loc = @cToLoc and PutawayZone = @cPickToZone)                
      BEGIN                
         SET @nErrNo = 70149                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvToLoc                
         GOTO Step_8_Fail                  
      END                
                
      SET @cLogicalFromLoc = ''            
      SELECT @cLogicalFromLoc = ISNULL(RTRIM(LogicalLocation),'')                
      FROM  dbo.LOC WITH (NOLOCK)                
      WHERE LOC = @cToLoc                
                
      /****************************                
       PROCESSING                
      ****************************/                
      BEGIN TRAN                
      UPDATE dbo.DROPID WITH (ROWLOCK)                
      SET   DropLoc = @cToLoc, EditWho = 'rdt.' + sUser_sName(), EditDate = GetDate()                
      WHERE Dropid  = @cDropID                
                
      IF @@ERROR <> 0                
      BEGIN                
         ROLLBACK TRAN                
         SET @nErrNo = 70170                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdDropIDFail                
         GOTO Step_8_Fail                   
      END                
    
      /**************************            
      * CHANG PALLET ID TO RELEASE            
      * PREVIOUS PALLET ID                
      **************************/            
      DECLARE @cDropID_New   NVARCHAR(18)            
             ,@nNextDropIdSeqNo INT            
                          
      SET @cDropID_New = ''            
      SELECT TOP 1             
         @cDropID_New = DROPID             
      FROM DROPID WITH (NOLOCK)            
      WHERE Dropid LIKE RTRIM(@cDropID) + '[0-9][0-9][0-9][0-9]'            
      ORDER BY DropID DESC               
                  
      IF ISNULL(RTRIM(@cDropID_New),'') = ''             
         SET @cDropID_New = RTRIM(@cDropID) + '0001'            
      ELSE            
      BEGIN            
         SET @nNextDropIdSeqNo = CAST( RIGHT(RTRIM(@cDropID_New),4) AS INT ) + 1             
         SET @cDropID_New = RTRIM(@cDropID) + RIGHT('0000' + CONVERT(VARCHAR(4), @nNextDropIdSeqNo), 4)             
      END               
                 
      -- (Vicky01) - Start                
      -- Delete DropID from DropID table because the Drop ID will be reuse                
      BEGIN TRAN                
                
      UPDATE dbo.DROPIDDETAIL                
        SET DropID = @cDropID_New, EditWho = 'rdt.' + sUser_sName(), EditDate = GetDate()                
      WHERE DropID = @cDropID                
                
      IF @@ERROR <> 0                
      BEGIN                
         ROLLBACK TRAN                
         SET @nErrNo = 70159                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdDropIDDetFail                
         GOTO Step_8_Fail                   
      END                
      ELSE                
      BEGIN                
         COMMIT TRAN                
      END                
                
      IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DropID = @cDropID_New)                
      BEGIN                
         BEGIN TRAN                
                
         UPDATE dbo.DROPID                
           SET DropID = @cDropID_New, EditWho = 'rdt.' + sUser_sName(), EditDate = GetDate()                
         WHERE DropID = @cDropID                
                
         IF @@ERROR <> 0                
         BEGIN                
            ROLLBACK TRAN                
            SET @nErrNo = 70160                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdlDropIDFail                
            GOTO Step_8_Fail                   
         END                
         ELSE                
         BEGIN                
            COMMIT TRAN   
         END                
      END                
      -- (Vicky01) - End                
            
      -- Set the completed dropid to new dropid (james01)            
      UPDATE RDT.RDTDPKLOG             
         SET DropID = @cDropID_New             
      WHERE DropID = @cDropID            
      AND UserKey = @cUserName         
      IF @@ERROR <> 0                
      BEGIN                
         ROLLBACK TRAN                
         SET @nErrNo = 70189                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Updl DPKLogFail                
         GOTO Step_8_Fail              
      END                
      ELSE                
      BEGIN                
         COMMIT TRAN                
      END                
            
      /**************************                
        PREPARE NEXT SCREEN                
      **************************/                
      SET @cOutField01 = @cTitle                
                
      SET @nScn = @nScn + 1                
      SET @nStep = @nStep + 1                
                
   END                
   Goto Quit                
                
   Step_8_Fail:                
   BEGIN                
 SET @cOutField04 = @cDefaultToLoc                 
   END                
             
END                
GOTO Quit               
             
/********************************************************************************                
Step 9. screen = 2448                 
   Pallet Close Confirmation                
********************************************************************************/                
Step_9:                
BEGIN                
   IF @nInputKey = 1 -- ENTER                
   BEGIN                
            
                
      -- Search for next task and redirect screen                
      SELECT @cErrMsg = '', @cNextTaskdetailkey = ''                
                
      EXEC dbo.nspTMTM01                
       @c_sendDelimiter = null                
      ,  @c_ptcid         = 'RDT'                
      ,  @c_userid        = @cUserName                
      ,  @c_taskId        = 'RDT'                
      ,  @c_databasename  = NULL                
      ,  @c_appflag       = NULL                
      ,  @c_recordType    = NULL                
      ,  @c_server        = NULL                
      ,  @c_ttm           = NULL                
      ,  @c_areakey01     = @cAreaKey                
      ,  @c_areakey02     = ''                
      ,  @c_areakey03  = ''                
      ,  @c_areakey04     = ''                
      ,  @c_areakey05     = ''                
      ,  @c_lastloc       = @cSuggFromLoc                
      ,  @c_lasttasktype  = ''                
      ,  @c_outstring     = @c_outstring    OUTPUT                
      ,  @b_Success       = @b_Success      OUTPUT                
      ,  @n_err           = @nErrNo         OUTPUT                
      ,  @c_errmsg        = @cErrMsg        OUTPUT                
      ,  @c_taskdetailkey = @cNextTaskdetailkey OUTPUT                
      ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT                
      ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func                
      ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func                
      ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func                
      ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func                
      ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func                
                
      IF ISNULL(RTRIM(@cNextTaskdetailkey), '') = ''--@nErrNo = 67804 -- Nothing to do!                
      BEGIN                
         -- EventLog - Sign In Function  (james01)                
         EXEC RDT.rdt_STD_EventLog                
          @cActionType = '9', -- Sign out function                
             @cUserID     = @cUserName,                
             @nMobileNo   = @nMobile,                
             @nFunctionID = @nFunc,                
             @cFacility   = @cFacility,                
             @cStorerKey  = @cStorerKey,
             @nStep       = @nStep                
                
         -- Go back to Task Manager Main Screen                
         SET @nFunc = 1756                
         SET @nScn = 2100                
         SET @nStep = 1                
                
         SET @cErrMsg = 'No More Task'                
         SET @cAreaKey = ''                
                
         SET @cOutField01 = ''  -- Area                
         SET @cOutField02 = ''                
         SET @cOutField03 = ''                
         SET @cOutField04 = ''                
         SET @cOutField05 = ''                
         SET @cOutField06 = ''                
         SET @cOutField07 = ''                
         SET @cOutField08 = ''                
         GOTO QUIT                
      END                     
                
      IF ISNULL(@cErrMsg, '') <> ''                  
      BEGIN                
         SET @cErrMsg = @cErrMsg                
         GOTO Step_9_Fail                
      END                   
                
      IF ISNULL(@cNextTaskdetailkey, '') <> ''                
      BEGIN                
         SELECT @cRefKey03 = CaseID , @cRefkey04 = PickMethod,                
                @cRefKey05  = CASE TaskType WHEN  'DPK' THEN 'Dynamic Picking  DPK' WHEN 'DRP' THEN 'Dynamic Replen   DRP' ELSE '' END                
         From dbo.TaskDetail (NOLOCK)                 
         WHERE TaskDetailkey = @cNextTaskdetailkey                
                    
         SET @cTaskdetailkey = @cNextTaskdetailkey                
         SET @cOutField01 = @cRefKey01                
         SET @cOutField02 = @cRefKey02                
         SET @cOutField03 = @cRefKey03                
         SET @cOutField04 = @cRefKey04                
         SET @cOutField05 = @cRefKey05                
         SET @cOutField06 = @cTaskdetailkey                
         SET @cOutField07 = @cAreaKey                
         SET @cOutField08 = @cTTMStrategykey                
         SET @nFromStep = '0'                
                         
         SET @cOutField09 = ''                
      END                
                
      SET @nToFunc = 0                
      SET @nToScn = 0                
                
      SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)                
      FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)                
      WHERE TaskType = RTRIM(@cTTMTasktype)                
                
      IF @nFunc = 0                
      BEGIN                
         SET @nErrNo = 70140                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr                
         GOTO Step_9_Fail                  
      END                
                   
      SELECT TOP 1 @nToScn = Scn                 
      FROM RDT.RDTScn WITH (NOLOCK)                
      WHERE Func = @nToFunc                
      ORDER BY Scn                
                
      IF @nToScn = 0              
      BEGIN                
         SET @nErrNo = 70141                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr                
         GOTO Step_9_Fail                  
      END                
          
      -- (james02) When Get the first Task Update EditDate          
      BEGIN TRAN          
      UPDATE dbo.TaskDetail With (ROWLOCK)          
      SET StartTime = GETDATE(),           
          EditDate = GETDATE(),          
          EditWho = @cUserName,          
          Trafficcop = NULL           
      WHERE TaskDetailkey = @cTaskdetailkey          
                
      IF @@ERROR <> 0          
      BEGIN          
         SET @nErrNo = 70194          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'          
         ROLLBACK TRAN          
         GOTO Step_9_Fail           
      END          
      ELSE          
      BEGIN          
         COMMIT TRAN          
      END          
          
      EXEC RDT.rdt_STD_EventLog                
       @cActionType = '9', -- Sign Out function                
       @cUserID     = @cUserName,                
       @nMobileNo   = @nMobile,                
       @nFunctionID = @nFunc,                
       @cFacility   = @cFacility,                
       @cStorerKey  = @cStorerKey,
       @nStep       = @nStep              
            
      SET @nFunc = @nToFunc                
      SET @nScn = @nToScn                
      SET @nStep = 1                
   END                
                
   IF @nInputKey = 0 -- ESC                
   BEGIN                
      EXEC RDT.rdt_STD_EventLog                
       @cActionType = '9', -- Sign Out function                
       @cUserID     = @cUserName,                
       @nMobileNo   = @nMobile,                
       @nFunctionID = @nFunc,                
       @cFacility   = @cFacility,                
       @cStorerKey  = @cStorerKey,
       @nStep       = @nStep                
                
   -- Go back to Task Manager Main Screen                
     SET @nFunc = 1756                
     SET @nScn = 2100                
     SET @nStep = 1                
                
     SET @cAreaKey = ''                
--   SET @nPrevStep = '0'                
                
     SET @cOutField01 = ''  -- Area                
     SET @cOutField02 = ''                
     SET @cOutField03 = ''                
     SET @cOutField04 = ''                
     SET @cOutField05 = ''                
     SET @cOutField06 = ''                
     SET @cOutField07 = ''                
     SET @cOutField08 = ''                
   END                   
   Goto Quit                
                
Step_9_Fail:        
END                
GOTO Quit                
          
/********************************************************************************          
Step 10. screen = 2109                
     REASON CODE  (Field01, input)                
********************************************************************************/                
Step_10:                
BEGIN                
   IF @nInputKey = 1 -- ENTER                
   BEGIN                
                      
      SET @nShortQty = 0                
                
      -- Screen mapping                
      SET @cReasonCode = @cInField01                
      IF @cReasonCode = ''                
      BEGIN                
        SET @nErrNo = 70142                
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason Req                
        GOTO Step_10_Fail                  
      END                
      
      -- (Shong06)      
      IF @cTTMTaskType = 'DPK'       
      BEGIN       
         IF EXISTS(SELECT 1 FROM CODELKUP c WITH (NOLOCK)      
                   WHERE c.LISTNAME = 'DPKINVRSN'      
                   AND   C.Code = @cReasonCode)      
         BEGIN       
           SET @nErrNo = 69865                
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --69865^BAD REASON                
           GOTO Step_10_Fail                           
         END      
      END      
                                
      SELECT @cFromLoc = FROMLOC,     
         @cID = FROMID,     
         @cSuggToloc = TOLOC,                 
         @nShortQty = CASE WHEN @nFromStep = 7 THEN (Qty - @nTotPickQty)                
                           ELSE Qty     
                      END,                
         @cLot = Lot                
      FROM dbo.TaskDetail WITH (NOLOCK)                 
      WHERE TaskDetailKey = @cTaskdetailkey                
                
      -- Update ReasonCode                
      EXEC dbo.nspRFRSN01                
              @c_sendDelimiter = NULL                
           ,  @c_ptcid = 'RDT'                
           ,  @c_userid        = @cUserName                
           ,  @c_taskId        = 'RDT'                
           ,  @c_databasename  = NULL                
           ,  @c_appflag       = NULL                
           ,  @c_recordType    = NULL                
           ,  @c_server        = NULL                
           ,  @c_ttm           = NULL                
           ,  @c_taskdetailkey = @cTaskdetailkey                
           ,  @c_fromloc       = @cFromLoc                
           ,  @c_fromid        = @cID                
           ,  @c_toloc         = @cSuggToloc         
           ,  @c_toid          = @cDropID              
           ,  @n_qty           = @nShortQty                
           ,  @c_PackKey       = ''                
           ,  @c_uom           = ''                
           ,  @c_reasoncode    = @cReasonCode                
           ,  @c_outstring     = @c_outstring    OUTPUT                
           ,  @b_Success       = @b_Success      OUTPUT                
           ,  @n_err           = @nErrNo         OUTPUT                
           ,  @c_errmsg        = @cErrMsg        OUTPUT                
           ,  @c_userposition  = @cUserPosition                
                
      IF ISNULL(@cErrMsg, '') <> ''                  
      BEGIN                
        SET @cErrMsg = @cErrMsg                
        GOTO Step_10_Fail                
      END                 
                
      SET @cContinueProcess = ''                  
      SELECT @cContinueProcess = ContinueProcessing,     
             @cReasonStatus = TaskStatus     
      FROM dbo.TASKMANAGERREASON WITH (NOLOCK)                  
      WHERE TaskManagerReasonKey = @cReasonCode                  
          
          
      SET @nTotPickQty = 0     
      SELECT @nTotPickQty = SUM(QtyMove)    
      FROM   rdt.rdtDPKLog WITH (NOLOCK)                
      WHERE  UserKey = @cUserName     
      AND    Taskdetailkey = @cTaskdetailkey     
      AND    DropID = @cDropID       
          
      IF @nTotPickQty > 0       --(Kc13)    
      BEGIN    
         SELECT TOP 1 @cDefaultToLoc = ISNULL(RTRIM(CL.Short),''),   -- (Vicky05)              
                      @cPickToZone = ISNULL(RTRIM(CL.Short),'')                
         FROM  dbo.Codelkup CL WITH (NOLOCK)                
         WHERE CL.Listname = 'WCSROUTE'                
         AND   CL.Code     = @cPickType                
    
         SET @nCurrentTranCount = @@TRANCOUNT    
          
         EXEC rdt.rdt_TMDynamicPick_MoveCase     
            @cDropID             =@cDropID,      
            @cTaskdetailkey      =@cTaskdetailkey,    
            @cUserName           =@cUserName,            
            @cToLoc              =@cDefaultToLoc,    
            @nErrNo              =@nErrNo  OUTPUT,    
            @cErrMsg             =@cErrMsg OUTPUT    
         IF @nErrno <> 0                 
         BEGIN                
            IF @@TRANCOUNT > @nCurrentTranCount    
               ROLLBACK TRAN                
                
            SET @nErrNo = @nErrNo         
            SET @cErrMsg = @cErrMsg                
            GOTO Step_10_Fail                
         END                         
               
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET       
            Qty = Qty - @nTotPickQty,       
            Trafficcop = NULL       
         WHERE TaskDetailKey = @cTaskDetailKey      
      
         IF @@ERROR <> 0                
         BEGIN                
            ROLLBACK TRAN      
            SET @nErrNo = 70207                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail                
            GOTO Step_10_Fail                   
         END                
      
         SET @nTotPickQty=0    
             
         -- (Shong11)    
         IF @cTTMTaskType = 'DPK' AND @cContinueProcess = '1'               
         BEGIN              
            UPDATE dbo.PICKDETAIL WITH (ROWLOCK)                
            SET   Status = '4', TrafficCop = NULL          
            WHERE Storerkey  = @cTaskStorer                
            AND   Status     = '0'                
            AND   SKU        = @cSuggSKU                
            AND   CASEID     = ''                
            AND   TOLOC      = @cFromLoc                
            AND   Taskdetailkey = @cTaskdetailkey        --(Kc04)                
                
            --(KC03) - start                
            -- offset back the qtyreplen                
            DECLARE C_ShortPick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR             
            SELECT SUM(QTY),  LOT                
            FROM  dbo.PICKDETAIL WITH (NOLOCK)                
            WHERE Storerkey  = @cTaskStorer                   
            AND   Status     = '4'                
            AND   SKU        = @cSuggSKU                
            AND   CASEID     = ''                
            AND   TOLOC      = @cFromLoc                
            AND   Taskdetailkey = @cTaskdetailkey        --(Kc04)                
            GROUP BY LOT                
                
            OPEN C_ShortPick                
            FETCH NEXT FROM C_ShortPick INTO  @nSumQtyShort, @cShortLot                
            WHILE (@@FETCH_STATUS <> -1)                
            BEGIN                
               UPDATE dbo.LOTxLOCxID WITH (ROWLOCK)                
               SET QTYREPLEN = CASE WHEN ISNULL(QTYREPLEN - @nSumQtyShort, 0) < 0 THEN 0 ELSE QTYREPLEN - @nSumQtyShort END       
               WHERE SKU = @cSuggSKU                
               AND LOT  = @cShortLot                
               AND LOC  = @cFromLoc                 
               AND ID   = @cID                
                
               IF @@ERROR <> 0                
               BEGIN                
                  ROLLBACK TRAN                
                  SET @nErrNo = 70171                
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdLotLOCIDFail                
                  GOTO Step_10_Fail                   
               END                
               FETCH NEXT FROM C_ShortPick INTO  @nSumQtyShort, @cShortLot                
            END --while                
            CLOSE C_ShortPick                
            DEALLOCATE C_ShortPick                
            --(Kc03) - end                
         END -- DPK     
         -- (Shong11)    
         IF @cTTMTaskType = 'DRP'      
         BEGIN     
            UPDATE dbo.LOTxLOCxID WITH (ROWLOCK)                
            SET QTYREPLEN = 0     
            WHERE LOT  = @cLot                
            AND LOC  = @cFromLoc                 
            AND ID   = @cID                            
            IF @@ERROR <> 0                
            BEGIN                
               ROLLBACK TRAN                
               SET @nErrNo = 70172                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdLotLOCIDFail                
               GOTO Step_10_Fail                   
            END                
         END   --@cTTMTaskType = 'DRP'          */      
      END    
                      
      IF ISNULL(@cContinueProcess, '') = '1'     
      BEGIN                 
         UPDATE dbo.TaskDetail WITH (ROWLOCK)                
         SET Reasonkey = @cReasonCode ,                 
             Status = '9' ,        
             EndTime = GETDATE(),--CURRENT_TIMESTAMP,      --(Kc09) -- (Vicky02)                
             EditDate = GETDATE(), --CURRENT_TIMESTAMP,    --(Kc09) -- (Vicky02)                
             EditWho = @cUserName      --(Kc09)                
             --TrafficCop = NULL                
         WHERE Taskdetailkey = @cTaskdetailkey                
                
         IF @@ERROR <> 0                
         BEGIN                
            ROLLBACK TRAN                
            SET @nErrNo = 70165            
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail                
            GOTO Step_10_Fail                   
         END                
      END  --ISNULL(@cContinueProcess, '') = '1' AND @nTotPickQty > 0                 
      ELSE --(Kc08) - start                           
      BEGIN                
         UPDATE dbo.TaskDetail WITH (ROWLOCK)                
         SET Status = @cReasonStatus ,     
             UserKey = '', TrafficCOP = NULL      -- (james06)          
         WHERE Taskdetailkey = @cTaskdetailkey                
                
         IF @@ERROR <> 0                
         BEGIN                
            ROLLBACK TRAN                
            SET @nErrNo = 70139                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail                
            GOTO Step_10_Fail                   
         END                
      END                
      --(Kc08) end                
      
--      IF NOT EXISTS (SELECT 1 FROM rdt.rdtDPKLog WITH (NOLOCK) WHERE UserKey = @cUserName) --(Shong09)                
--         AND @nTotPickQty = 0 -- (Vicky03)              
--      BEGIN          
--    
--         UPDATE dbo.DROPID WITH (ROWLOCK)                
--         SET   Status = '9'                
--         WHERE Dropid = @cDropID                
--    
--         IF @@ERROR <> 0                
--         BEGIN                
--            ROLLBACK TRAN                
--            SET @nErrNo = 70208                
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail                
--            GOTO Step_10_Fail                   
--         END                
--          
--         EXEC RDT.rdt_STD_EventLog                
--          @cActionType = '9', -- Sign Out function                
--          @cUserID     = @cUserName,                
--          @nMobileNo   = @nMobile,                
--          @nFunctionID = @nFunc,                
--          @cFacility   = @cFacility,                
--          @cStorerKey  = @cStorerKey,
--          @nStep       = @nStep                
--                
--    
--         -- Go back to Task Manager Screen                         
--         SET @nFunc = 1756                
--         SET @nScn = 2100                
--         SET @nStep = 1                
--             
--    
--         -- (Shong09)                
--         SET @cAreaKey = ''                
--         --SET @nPrevStep = '0'                
--         SET @cOutField01 = '' -- Area    
--         SET @cOutField02 = ''    
--                         
--         SET @cOutField03 = ''                
--         SET @cOutField04 = ''                
--         SET @cOutField05 = ''                
--         SET @cOutField06 = ''                
--         SET @cOutField07 = ''                
--         SET @cOutField08 = ''                
--      END -- esc from other screens except shortpick screen                
--      ELSE                
      BEGIN                
         -- Go to screen 6                
         SET @cOutField02 = ''                
         SET @cOutField01 = @cTitle                
         SET @nScn = 2445                
         SET @nStep = 6    
         GOTO QUIT                
      END                
   END                
                
   IF @nInputKey = 0 -- ESC                
   BEGIN                
       -- go to previous screen                
       IF @nFromStep = 1                
       BEGIN                
          SET @cOutField05 = @cTitle                
          SET @cOutField04 = @cPickType                
          SET @cOutField09 = ''                
       END                
       ELSE                
       BEGIN                
         SET @cOutField01 = @cTitle                
         SET @cOutField02 = ''                
       END                
       SET @nScn = @nFromScn                
       SET @nStep = @nFromStep                
   END                
   Goto Quit                
                
   Step_10_Fail:                
   BEGIN                
      SET @cReasonCode = ''                
                  
      -- Reset this screen var                
      SET @cOutField01 = ''                
   END                
END                
Goto Quit                
                
/********************************************************************************                
Step 11. screen = 2449                
    TITLE      (Field01, display)                
    PALLETID   (Field02, display)                
    SKU        (Field03, display)                
    SKUDESCR   (Field04, display)                
    SKUDESCR   (Field05, display)                
    UOM        (Field06, display)                
    SUGGQTY    (Field07 display)                
    QTY        (Field08, input)                
********************************************************************************/                
Step_11:                
BEGIN                
   IF @nInputKey = 1 -- ENTER                
   BEGIN                
      -- Screen mapping                
      SET @cBoxQty = CASE WHEN rdt.rdtIsValidQTY( LEFT( @cInField08, 5), 0) = 1 THEN LEFT( @cInField08, 5) ELSE 0 END                
      SET @nBoxQty = CAST(@cBoxQty as INT)                
      SET @cToToteNo = @cInField10    -- (james12)
      SET @cSuggQty = @cOutField07  -- (james12)
      
      SET @cQtyAvail = @cOutField09 -- (james16)

      -- (james18)
      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
      IF @cDecodeLabelNo = '0'
         SET @cDecodeLabelNo = ''

      IF ISNULL(@cDecodeLabelNo, '') <> ''
      BEGIN
         EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cInField10
            ,@c_Storerkey  = @cStorerKey
            ,@c_ReceiptKey = ''
            ,@c_POKey      = ''
            ,@c_LangCode   = @cLangCode
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   
            ,@c_oFieled02  = @c_oFieled02 OUTPUT   
            ,@c_oFieled03  = @c_oFieled03 OUTPUT   
            ,@c_oFieled04  = @c_oFieled04 OUTPUT   
            ,@c_oFieled05  = @c_oFieled05 OUTPUT   
            ,@c_oFieled06  = @c_oFieled06 OUTPUT   
            ,@c_oFieled07  = @c_oFieled07 OUTPUT
            ,@c_oFieled08  = @c_oFieled08 OUTPUT
            ,@c_oFieled09  = @c_oFieled09 OUTPUT
            ,@c_oFieled10  = @c_oFieled10 OUTPUT
            ,@b_Success    = @b_Success   OUTPUT
            ,@n_ErrNo      = @nErrNo      OUTPUT
            ,@c_ErrMsg     = @cErrMsg     OUTPUT

         IF ISNULL( @cErrMsg, '') <> '' 
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO Step_11_Fail
         END
            
         SET @cToToteNo = @c_oFieled01
         SET @cBoxQty = @c_oFieled02
         SET @nBoxQty = CAST( @cBoxQty AS INT)
      END

      IF rdt.RDTGetConfig( @nFunc, 'DynamicPickAllowOverPick', @cStorerKey) <> '1'
      BEGIN     
         IF @nBoxQty > CAST( @cSuggQty AS INT)
         BEGIN                
            SET @nErrNo = 70215             
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pick>SuggQty                
            GOTO Step_11_Fail                  
         END     
      END
      
      -- (james12)
      IF ISNULL( @cToToteNo, '') = ''
      BEGIN                
         SET @nErrNo = 50151             
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TO TOTENO REQ                
         GOTO Step_11_Fail                  
      END     

      -- Check if user scan SKU as tote no
      IF @cToToteNo = SUBSTRING( @cSKU, 1, 10) 
      BEGIN                
         SET @nErrNo = 50154             
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOTE NO = SKU                
         GOTO Step_11_Fail                  
      END 

      SET @cDefaultCaseLength  = ''  
      SET @cDefaultCaseLength  = rdt.RDTGetConfig( @nFunc, 'DefaultCaseLength', @cStorerKey)    
      IF ISNULL(@cDefaultCaseLength, '') = ''  
         SET @cDefaultCaseLength = '8'  -- make it default to 8 digit if not setup  
  
      -- Check the length of tote no; 0 = no check (james09)  
      IF @cDefaultCaseLength <> '0'  
      BEGIN  
         IF LEN(RTRIM(@cToToteNo)) < @cDefaultCaseLength  
         BEGIN              
            SET @nErrNo = 50156                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV CASEID LEN                  
            GOTO Step_11_Fail                  
         END              
      END  
      
      IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cToToteNo AND Status = '4')
      BEGIN                
         SELECT TOP 1 @cSourceType = SourceType 
         FROM dbo.ucc WITH (NOLOCK) 
         WHERE Status = '4' 
         AND   UCCNo = @cToToteNo
         AND   Storerkey = @cTaskStorer

         SET @nValid = 0
         IF @cSourceType = 'RDTDynamicReplen'
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.TaskDetail (NOLOCK) 
                           WHERE CASEID = @cToToteNo 
                           AND   Storerkey = @cTaskStorer
                           AND   STATUS IN ('0', '3', 'W'))
            BEGIN
               SET @cToToteNo_New = ''            
               SELECT TOP 1             
                  @cToToteNo_New = UCCNo             
               FROM UCC WITH (NOLOCK)            
               WHERE UCCNo LIKE RTRIM(@cToToteNo) + '[0-9][0-9][0-9][0-9]'            
               ORDER BY UCCNo DESC            

               IF ISNULL(RTRIM(@cToToteNo_New),'') = ''             
                  SET @cToToteNo_New = RTRIM(@cToToteNo) + '0001'            
               ELSE            
               BEGIN            
                  SET @nNextToToteNoSeqNo = CAST( RIGHT(RTRIM(@cToToteNo_New),4) AS INT ) + 1             
                  SET @cToToteNo_New = RTRIM(@cToToteNo) + RIGHT('0000' + CONVERT(VARCHAR(4), @nNextToToteNoSeqNo), 4)             
               END   

               UPDATE dbo.UCC WITH (ROWLOCK) SET 
                  UCCNo = @cToToteNo_New, 
                  [Status]  = '6'
               WHERE UCCNo = @cToToteNo
               AND   [Status] <= '6'
               AND   StorerKey = @cTaskStorer
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 50157             
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC FAIL                
                  GOTO Step_11_Fail                  
               END
               ELSE
                  SET @nValid = 1
            END
         END

         IF @cSourceType = 'RDTDynamicPick'
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail (NOLOCK) 
                           WHERE CASEID = @cToToteNo 
                           AND   Storerkey = @cTaskStorer
                           AND   STATUS IN ('0', '3', '5'))
            BEGIN
               SET @cToToteNo_New = ''            
               SELECT TOP 1             
                  @cToToteNo_New = UCCNo             
               FROM UCC WITH (NOLOCK)            
               WHERE UCCNo LIKE RTRIM(@cToToteNo) + '[0-9][0-9][0-9][0-9]'            
               ORDER BY UCCNo DESC            

               IF ISNULL(RTRIM(@cToToteNo_New),'') = ''             
                  SET @cToToteNo_New = RTRIM(@cToToteNo) + '0001'            
               ELSE            
               BEGIN            
                  SET @nNextToToteNoSeqNo = CAST( RIGHT(RTRIM(@cToToteNo_New),4) AS INT ) + 1             
                  SET @cToToteNo_New = RTRIM(@cToToteNo) + RIGHT('0000' + CONVERT(VARCHAR(4), @nNextToToteNoSeqNo), 4)             
               END   

               UPDATE dbo.UCC WITH (ROWLOCK) SET 
                  UCCNo = @cToToteNo_New, 
                  [Status]  = '6'
               WHERE UCCNo = @cToToteNo
               AND   [Status] <= '6'
               AND   StorerKey = @cTaskStorer
            

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 50158             
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC FAIL                
                  GOTO Step_11_Fail                  
               END
               ELSE
                  SET @nValid = 1
            END
         END

         IF @nValid = 0
         BEGIN
            SET @nErrNo = 50152             
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TO TOTE CLOSED                
            GOTO Step_11_Fail                  
         END
      END 

      -- If config turn on then only allow 1 sku per tote
      IF rdt.RDTGetConfig( @nFunc, 'DPKONESKUPERTOTE', @cStorerKey) = 1
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cToToteNo AND Status = '0' AND SKU <> @cSuggSKU)
         BEGIN                
            SET @nErrNo = 50153             
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOTE DIFF SKU                
            GOTO Step_11_Fail                  
         END 
      END

      SET @bSuccess = 0
      EXEC dbo.isp_WMS2WCSRoutingValidation             
         @cToToteNo,             
         @cStorerKey,            
         @bSuccess   OUTPUT,            
         @nErrNo     OUTPUT,             
         @cErrMsg    OUTPUT            

      IF @bSuccess <> 1
      BEGIN                
         SET @cErrMsg = CONVERT( NVARCHAR( 5),ISNULL( @nErrNo,0)) + ' ' + ISNULL( RTRIM( @cErrMsg), '') 
         GOTO Step_11_Fail                  
      END 
         
      --(Kc12) - start            
      IF EXISTS ( SELECT 1 From dbo.DropID WITH (NOLOCK) Where DropID = @cToToteNo And Status = '9' )              
      BEGIN              
         BEGIN TRAN            
         DELETE FROM dbo.DROPIDDETAIL            
         WHERE DropID = @cToToteNo            
            
         IF @@ERROR <> 0            
         BEGIN            
            ROLLBACK TRAN            
            SET @nErrNo = 70184               
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelDIDDetFail              
            GOTO Step_11_Fail                  
         END            
            
         DELETE FROM dbo.DROPID            
         WHERE DropID = @cToToteNo            
         AND   Status = '9'            
            
         IF @@ERROR <> 0            
         BEGIN            
            ROLLBACK TRAN            
            SET @nErrNo = 70185               
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelDropIDFail              
            GOTO Step_11_Fail                  
         END            
         ELSE            
         BEGIN            
            COMMIT TRAN            
         END            
      END                
      --(Kc12) -end    

      IF @cPrev_ToTote <> @cToToteno 
         AND ISNULL( @cPrev_ToTote, '') <> ''   -- Not the 1st time scanning the tote  (james15)
      BEGIN
         -- Perform close tote
         EXEC [RDT].[rdt_TM_DynamicPickCloseTote] 
            @nMobile             = @nMobile, 
            @nFunc               = @nFunc, 
            @cLangCode           = @cLangCode, 
            @nStep               = @nStep, 
            @nInputKey           = @nInputKey, 
            @cDropID             = @cDropID,
            @cToToteNo           = @cToToteNo, 
            @cLoadkey            = @cLoadkey, 
            @cTaskStorer         = @cTaskStorer, 
            @cSKU                = @cSKU, 
            @cFromLoc            = @cFromLoc, 
            @cID                 = @cID, 
            @cLot                = @cLot, 
            @cTaskdetailkey      = @cTaskdetailkey, 
            @nPrevTotQty         = @nTotPickQty, 
            @nBoxQty             = @nBoxQty, 
            @nTaskQty            = @nTaskQty, 
            @cPickType           = @cPickType, 
            @cNewTaskDetailKey   = @cNewTaskDetailKey OUTPUT, 
            @nTotPickQty         = @nTotPickQty       OUTPUT, 
            @nErrNo              = @nErrNo            OUTPUT, 
            @cErrMsg             = @cErrMsg           OUTPUT 

         IF @nErrno <> 0                 
         BEGIN                
            SET @nErrNo = @nErrNo         
            SET @cErrMsg = @cErrMsg                
            GOTO Step_11_Fail                
         END                
         
         SET @cTaskDetailKey = @cNewTaskDetailKey
      END


      /****************************                
       VALIDATION                 
      ****************************/                
      IF ISNULL(@nBoxQty,0) = 0                
      BEGIN                
         SET @nErrNo = 70156             
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvBoxQty                
         GOTO Step_11_Fail                  
      END                 
    
      -- (Shong08)    
      -- Check qty entered not more than qty on hand    
      -- (SHONGxx)  
      SET @nAvailQty=0  
      SELECT @nAvailQty = ISNULL((SL.QTY - SL.QTYPicked), 0)     
      FROM dbo.SKUxLOC SL WITH (NOLOCK)      
      WHERE SL.StorerKey = @cTaskStorer     
        AND SL.Sku = @cSuggSKU      
        AND SL.LOC = @cFromLoc     
 

      SELECT @nQtyToMoved = ISNULL(SUM(DPK.QtyMove), 0)    
      FROM RDT.RDTDPKLog DPK WITH (NOLOCK)     
      WHERE DPK.UserKey = @cUserName     
      AND   dpk.SKU     = @cSku     
      AND   DPK.FromLoc = @cFromLoc     
 
      IF (@nBoxQty + @nQtyToMoved) > @nAvailQty    
      BEGIN    
         SET @nErrNo = 70209             
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --70209^QTYAVL<QTYMove                
         GOTO Step_11_Fail                  
      END    
             
      SET @nQtyAvail = 0     
      SELECT @nQtyAvail = ISNULL((SL.QTY - SL.QTYPicked), 0)     
      FROM dbo.SKUxLOC SL WITH (NOLOCK)      
      WHERE SL.StorerKey = @cTaskStorer     
        AND SL.Sku = @cSuggSKU      
        AND SL.LOC = @cFromLoc     
    
      SET @nTotPickQty=0                
      SET @nTotPrevPickQty = 0

      IF @cTTMTaskType = 'DPK'
         SELECT @nTotPickQty = ISNULL(SUM(Qty), 0)
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cTaskStorer
         AND   DropID = @cDropID
         AND   [Status] = '3'
         AND   SKU = @cSuggSKU      
      ELSE
      BEGIN
         SELECT @nTotPickQty = ISNULL(SUM(QtyMove), 0)     
         FROM RDT.RDTDPKLOG WITH (NOLOCK)            
         WHERE DropID = @cDropID          
           AND TaskDetailKey = @cTaskdetailkey     
           AND UserKey=@cUserName         

         SELECT @nTotPrevPickQty = ISNULL(SUM(Qty), 0) 
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE DropID = @cDropID
         AND   LoadKey = @cLoadkey
         AND   StorerKey = @cTaskStorer
         AND   SKU = @cSuggSKU
         AND   FROMLOC = @cFromLoc

         SET @nTotPickQty = @nTotPickQty + @nTotPrevPickQty
      END
               
      SET @nQtyAvail = @nQtyAvail - @nTotPickQty    

      IF rdt.RDTGetConfig( @nFunc, 'SkipScanCaseId', @cTaskStorer) = 1
      BEGIN
         SET @nErrno = 0            
         SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cTaskStorer)
         IF @cExtendedUpdateSP = '0'
            SET @cExtendedUpdateSP = ''

         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cDropID, @cToToteno, @cLoadkey, @cTaskStorer, @cSKU, @cFromLoc, @cID, 
                    @cLot, @cTaskdetailkey, @nPrevTotQty, @nBoxQty, @nTaskQty, @nTotPickQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT, '            +
                  '@nFunc           INT, '            +
                  '@cLangCode       NVARCHAR( 3), '   +
                  '@nStep           INT, '            + 
                  '@nInputKey       INT, '            +
                  '@cDropID         NVARCHAR( 20), '  +
                  '@cToToteno       NVARCHAR( 20), '  +
                  '@cLoadkey        NVARCHAR( 10), '  +
                  '@cTaskStorer     NVARCHAR( 15), '  +
                  '@cSKU            NVARCHAR( 20), '  +
                  '@cFromLoc        NVARCHAR( 10), '  +
                  '@cID             NVARCHAR( 18), '  + 
                  '@cLot            NVARCHAR( 10), '  +
                  '@cTaskdetailkey  NVARCHAR( 10), '  +
                  '@nPrevTotQty     INT, '            +
                  '@nBoxQty         INT, '            + 
                  '@nTaskQty        INT, '            +
                  '@nTotPickQty     INT   OUTPUT, '   +
                  '@nErrNo          INT   OUTPUT, '   +
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT'  

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cDropID, @cToToteno, @cLoadkey, @cTaskStorer, @cSuggSKU, @cFromLoc, @cID, 
                  @cSuggLot, @cTaskdetailkey, @nTotPickQty, @nBoxQty, @nTaskQty, @nTotPickQty OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT


               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = @nErrNo                
                  SET @cErrMsg = @cErrMsg                
                  GOTO Step_11_Fail             
               END
               
               SET @cPrev_ToTote = @cToToteno
            END
         END

         /****************************                
          Prepare Next Screen                 
         ****************************/                
         IF @nTotPickQty >= @nTaskQty                
         BEGIN                
            SELECT TOP 1 @cDefaultToLoc = ISNULL(RTRIM(CL.Short),''),   -- (Vicky05)              
                         @cPickToZone = ISNULL(RTRIM(CL.Short),'')                
            FROM  dbo.Codelkup CL WITH (NOLOCK)                
            WHERE CL.Listname = 'WCSROUTE'                
            AND   CL.Code     = @cPickType                
       
            EXEC rdt.rdt_TMDynamicPick_MoveCase     
               @cDropID    =@cDropID,      
               @cTaskdetailkey      =@cTaskdetailkey,    
               @cUserName           =@cUserName,            
               @cToLoc              =@cDefaultToLoc,    
               @nErrNo              =@nErrNo  OUTPUT,    
               @cErrMsg             =@cErrMsg OUTPUT    

            IF @nErrno <> 0                 
            BEGIN                
               SET @nErrNo = @nErrNo         
               SET @cErrMsg = @cErrMsg                
               GOTO Step_11_Fail                
            END                

            SET @nCurrentTranCount = @@TRANCOUNT    
            BEGIN TRAN
            SAVE TRAN STEP_11_UPD
            
            UPDATE dbo.Taskdetail With (rowlock)            
            SET   Status = '9',                 
                  UserPosition = @cUserPosition,      --(Kc09)                
                  EndTime = GETDATE(),--CURRENT_TIMESTAMP,        --(Kc09) -- (Vicky02)                
                  EditDate = GETDATE(),--CURRENT_TIMESTAMP,       --(Kc09) -- (Vicky02)                
                  EditWho  = @cUserName               --(Kc09)                
            WHERE Taskdetailkey = @cTaskdetailkey                
                   
            IF @@ERROR <> 0       
            BEGIN                
               ROLLBACK TRAN STEP_11_UPD
               WHILE @@TRANCOUNT > @nCurrentTranCount -- Commit until the level we started  
                  COMMIT TRAN STEP_11_UPD
                 
               SET @nErrNo = 70139                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail                
               GOTO Step_11_Fail                   
            END                
         
            -- (james05)      
            SET @nQtyMoved = 0       
            SELECT @nQtyMoved = ISNULL(SUM(QTY), 0)       
            FROM dbo.UCC WITH (NOLOCK)       
            WHERE StorerKey = @cStorerKey      
               AND SourceKey = @cTaskdetailkey      
         
            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET       
               Qty = @nQtyMoved,       
               Trafficcop = NULL       
            WHERE TaskDetailKey = @cTaskDetailKey      
         
            IF @@ERROR <> 0                
            BEGIN                
               ROLLBACK TRAN STEP_11_UPD
               WHILE @@TRANCOUNT > @nCurrentTranCount -- Commit until the level we started  
                  COMMIT TRAN STEP_11_UPD

               SET @nErrNo = 70206                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail                
               GOTO Step_11_Fail                   
            END                

            SET @nTotPickQty = 0    
       
            WHILE @@TRANCOUNT > @nCurrentTranCount -- Commit until the level we started  
               COMMIT TRAN STEP_11_UPD  
            
            -- close pallet                
            SET @cOutField01 = @cTitle                
            SET @cOutField02 = ''                
                   
               SET @nScn = @nScn - 4                
               SET @nStep = @nStep - 5                
         END                
         ELSE                
         BEGIN             
            SET @cOutField01 = @cTitle                
            SET @cOutField02 = @cID                
            SET @cOutField03 = @cSuggSku                
            SET @cOutField04 = SUBSTRING(@cDescr,1,20)                
            SET @cOutField05 = SUBSTRING(@cDescr,21,20)                
            IF @nFromStep = 4                
            BEGIN                
               --loop back to bomsku screen (SCN 4)                

               SET @cOutField06 = ''            
               SET @cOutField07 = @cUOM                
               SET @cOutField08 = CAST(@nTotPickQty AS NVARCHAR( 5))                
               SET @cOutField09 = CAST(@nTaskQty AS NVARCHAR( 5))                
               SET @nScn = @nScn - 6                
               SET @nStep = @nStep - 7                
            END                
            ELSE                
            BEGIN    
               SET @nQtyAvail = 0     
               SELECT @nQtyAvail = ISNULL((SL.QTY - SL.QTYPicked), 0)     
               FROM dbo.SKUxLOC SL WITH (NOLOCK)      
               WHERE SL.StorerKey = @cTaskStorer     
                 AND SL.Sku = @cSuggSKU      
                 AND SL.LOC = @cFromLoc     
       
               SET @nTotPickQty=0  
               SET @nTotPrevPickQty = 0

               IF @cTTMTaskType = 'DPK'
               BEGIN
                  SELECT @nTotPickQty = ISNULL(SUM(QtyMove), 0)     
                  FROM RDT.RDTDPKLOG WITH (NOLOCK)            
                  WHERE DropID = @cDropID          
                    AND TaskDetailKey = @cTaskdetailkey     
                    AND UserKey=@cUserName         

                  IF ISNULL( @nTotPickQty, 0) = 0
                     SELECT @nTotPickQty = ISNULL(SUM(Qty), 0)
                     FROM dbo.PickDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cTaskStorer
                     AND   DropID = @cDropID
                     AND   [Status] = '3'
                     AND   SKU = @cSuggSKU      
               END
               ELSE
               BEGIN
                  SELECT @nTotPickQty = ISNULL(SUM(QtyMove), 0)     
                  FROM RDT.RDTDPKLOG WITH (NOLOCK)            
                  WHERE DropID = @cDropID          
                    AND TaskDetailKey = @cTaskdetailkey     
                    AND UserKey=@cUserName         

                  SELECT @nTotPrevPickQty = ISNULL(SUM(Qty), 0) 
                  FROM dbo.TaskDetail WITH (NOLOCK) 
                  WHERE DropID = @cDropID
                  AND   LoadKey = @cLoadkey
                  AND   StorerKey = @cTaskStorer
                  AND   SKU = @cSuggSKU
                  AND   FROMLOC = @cFromLoc

                  SET @nTotPickQty = @nTotPickQty + @nTotPrevPickQty
               END

               SET @nQtyAvail = @nQtyAvail - @nTotPickQty     
                                                   
               --loop back to non-bomsku screen (SCN 11)                
               SET @cOutField06 = @cUOM                
               SET @cOutField07 = CAST( CAST( @cSuggQty AS INT) - CAST( @cBoxQty AS INT) AS NVARCHAR( 5))--CAST((@nTaskQty - @nTotPickQty) AS NVARCHAR( 5))          
               SET @cOutField08 = ''    
               SET @cOutField09 = CAST( CAST( @cQtyAvail AS INT) - CAST( @cBoxQty AS INT) AS NVARCHAR( 5)) --CAST(@nQtyAvail AS NVARCHAR( 5))                
               SET @nScn = @nScn                 
               SET @nStep = @nStep 
               EXEC rdt.rdtSetFocusField @nMobile, 10 
            END                
            --(Kc03) end                
         END                
      END
      ELSE
      BEGIN
         /****************************                
          Prepare Next Screen                 
         ****************************/                
         -- goto CASEID screen                
         SET @cOutField01 = @cTitle                
         SET @cOutField02 = @cID                
         SET @cOutField03 = @cSKU                
         SET @cOutField04 = SUBSTRING(@cDescr,1,20)                
         SET @cOutField05 = SUBSTRING(@cDescr,21,20)                
         SET @cOutField06 = @cUOM                
         SET @cOutField07 = CAST((@nBoxQty + @nTotPickQty) AS NVARCHAR( 5))                
         SET @cOutField08 = CAST(@nTaskQty AS NVARCHAR( 5))                   
         SET @cOutField09 = ''        
         SET @cOutField10 = CAST(@nQtyAvail AS NVARCHAR( 5))            
         SET @nScn = @nScn - 5                
         SET @nStep = @nStep - 6                   
         SET @nFromScn = 11                
         SET @nFromStep = 11                
      END
   END                
                
   IF @nInputKey = 0 -- ESC                
   BEGIN     
      -- (james17)
      IF @cPrev_ToTote <> @cToToteno 
         AND ISNULL( @cPrev_ToTote, '') <> ''   -- Not the 1st time scanning the tote  (james15)
      BEGIN
         -- Perform close tote
         EXEC [RDT].[rdt_TM_DynamicPickCloseTote] 
            @nMobile             = @nMobile, 
            @nFunc               = @nFunc, 
            @cLangCode           = @cLangCode, 
            @nStep               = @nStep, 
            @nInputKey           = @nInputKey, 
            @cDropID             = @cDropID,
            @cToToteNo           = @cToToteNo, 
            @cLoadkey            = @cLoadkey, 
            @cTaskStorer         = @cTaskStorer, 
            @cSKU                = @cSKU, 
            @cFromLoc            = @cFromLoc, 
            @cID                 = @cID, 
            @cLot                = @cLot, 
            @cTaskdetailkey      = @cTaskdetailkey, 
            @nPrevTotQty         = @nTotPickQty, 
            @nBoxQty             = @nBoxQty, 
            @nTaskQty            = @nTaskQty, 
            @cPickType           = @cPickType, 
            @cNewTaskDetailKey   = @cNewTaskDetailKey OUTPUT, 
            @nTotPickQty         = @nTotPickQty       OUTPUT, 
            @nErrNo              = @nErrNo            OUTPUT, 
            @cErrMsg             = @cErrMsg           OUTPUT 

         IF @nErrno <> 0                 
         BEGIN                
            SET @nErrNo = @nErrNo         
            SET @cErrMsg = @cErrMsg                
            GOTO Step_11_Fail                
         END                
         
         SET @cTaskDetailKey = @cNewTaskDetailKey
      END

      SET @nQtyAvail = 0     
      SELECT @nQtyAvail = ISNULL((SL.QTY - SL.QTYPicked), 0)     
      FROM dbo.SKUxLOC SL WITH (NOLOCK)      
      WHERE SL.StorerKey = @cTaskStorer     
        AND SL.Sku = @cSuggSKU      
        AND SL.LOC = @cFromLoc     

      SET @nTotPickQty=0  
      SET @nTotPrevPickQty = 0

      IF @cTTMTaskType = 'DPK'
      BEGIN
         SELECT @nTotPickQty = ISNULL(SUM(QtyMove), 0)     
         FROM RDT.RDTDPKLOG WITH (NOLOCK)            
         WHERE DropID = @cDropID          
           AND TaskDetailKey = @cTaskdetailkey     
           AND UserKey=@cUserName         

         IF ISNULL( @nTotPickQty, 0) = 0
            SELECT @nTotPickQty = ISNULL(SUM(Qty), 0)
            FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE StorerKey = @cTaskStorer
            AND   DropID = @cDropID
            AND   [Status] = '3'
            AND   SKU = @cSuggSKU      
      END
      ELSE
      BEGIN
         SELECT @nTotPickQty = ISNULL(SUM(QtyMove), 0)     
         FROM RDT.RDTDPKLOG WITH (NOLOCK)            
         WHERE DropID = @cDropID          
           AND TaskDetailKey = @cTaskdetailkey     
           AND UserKey=@cUserName         

         SELECT @nTotPrevPickQty = ISNULL(SUM(Qty), 0) 
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE DropID = @cDropID
         AND   LoadKey = @cLoadkey
         AND   StorerKey = @cTaskStorer
         AND   SKU = @cSuggSKU
         AND   FROMLOC = @cFromLoc

         SET @nTotPickQty = @nTotPickQty + @nTotPrevPickQty
      END

      SET @nQtyAvail = @nQtyAvail - @nTotPickQty     

      SET @cOutField01 = @cTitle                
      SET @cOutField02 = @cID                
      SET @cOutField03 = @cSKU                
      SET @cOutField04 = SUBSTRING(@cDescr,1,20)                
      SET @cOutField05 = SUBSTRING(@cDescr,21,20)                
      SET @cOutField06 = ''                
      SET @cOutField07 = @cUOM                
      SET @cOutField08 = CAST(@nTotPickQty AS NVARCHAR( 5))                
      SET @cOutField09 = CAST(@nTaskQty AS NVARCHAR( 5))                
                
      SET @nScn = @nScn - 6                
      SET @nStep = @nStep - 7                
   END                
   GOTO Quit                
                
   Step_11_Fail:                
   BEGIN                
      SET @cOutField08 = ''    
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
      Func          = @nFunc,                
      Step          = @nStep,                            
      Scn           = @nScn,                
                
      StorerKey     = @cStorerKey,                
      Facility      = @cFacility,                 
      Printer       = @cPrinter,                    
                
      V_SKU         = @cSKU,                
      V_SKUDescr    = @cDescr,                
      V_LOC         = @cFromloc,                
      V_ID          = @cID,                
      V_UOM         = @cUOM,                               
      V_LoadKey     = @cLoadKey,       
      
      V_QTY         = @nTotPickQty,         
                
      -- (SHONG11)          
      --V_String1   =  @cTaskdetailkey,           
      V_FromStep  =  @nFromStep, 
      V_TaskQty   =  @nTaskQty,
      --V_FromStep  =  @nFromStep,
      V_FromScn   =  @nFromScn,
      
      V_Integer1  =  @nCaseQty,                
      V_Integer2  =  @nBoxQty,
             
      V_String2   =  @cTaskStorer,                                
      V_String4   =  @cDropID,                                
      V_String5   =  @cTaskdetailkey,                           
      V_String7   =  @cPickToZone,                
      V_String8   =  @cPickType,                
      V_String9   =  @cTitle,                
      V_String10  =  @cSuggID,                
      V_String11  =  @cSuggFromLoc,                
      V_String12  =  @cSuggToloc,                
      V_String13  =  @cSuggSKU,                
      V_String14  =  @cPackKey,                
      V_String15  =  @cUOM,                
      V_String16  =  @cSuggLot,                                
      V_String19  =  @cUserPosition,         --(Kc06)                
      V_String20  =  @cPrev_ToTote, 
                
      V_String32  = @cAreakey,                         
      V_String33  = @cTTMStrategykey,                  
      V_String34  = @cTTMTasktype,                     
      V_String35  = @cRefKey01,                
      V_String36  = @cRefKey02,                          
      V_String37  = @cRefKey03,                        
      V_String38  = @cRefKey04,                        
      V_String39  = @cRefKey05,                        
                
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