SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/              
/* Store procedure: rdtfnc_Tote_QC_Inquiry                                   */              
/* Copyright      : IDS                                                      */              
/*                                                                           */              
/* Purpose: Case and Tote Inquiry                                            */              
/*                                                                           */              
/* Modifications log:                                                        */              
/*                                                                           */              
/* Date       Rev  Author   Purposes                                         */              
/* 2010-09-21 1.0  ChewKP   Created                                          */   
/* 2010-09-21 1.1  James    Show pick n pack qty (james01)                   */   
/* 2010-11-02 1.2  James    Include StorerKey when insert GM task (james02)  */   
/* 2010-12-22 1.3  James    Include Loc in Msg when insert GM task (james03) */   
/* 2016-09-30 1.4  Ung      Performance tuning                               */
/* 2018-11-16 1.5  TungGH   Performance                                      */   
/*****************************************************************************/              
CREATE PROC [RDT].[rdtfnc_Tote_QC_Inquiry](              
   @nMobile    INT,              
   @nErrNo     INT  OUTPUT,              
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max              
) AS              
              
-- Misc variable              
DECLARE              
   @b_success           INT              
                      
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
              
   @cToteNo             NVARCHAR(18),              
   @cOption             NVARCHAR(1),              
   @cOrderKey           NVARCHAR(10),              
   @cConsigneekey       NVARCHAR(15),              
   @cSKU                NVARCHAR(20),              
   @cSKUDescr           NVARCHAR(60),              
   @cPackUOM03          NVARCHAR(5),              
   @cTaskType           NVARCHAR(10),              
   @cReason             NVARCHAR(20),              
   @cLastUser           NVARCHAR(18),              
   @cLastZone           NVARCHAR(10),              
   @cFinalZone          NVARCHAR(10),              
   @cWCSKey             NVARCHAR(10),              
   @cTaskDetailKey      NVARCHAR(10),              
   @cLoadkey            NVARCHAR(10),              
   @cPrevOrderKey       NVARCHAR(10),              
   @cActStorer          NVARCHAR(15),              
   @cCompany1           NVARCHAR(20),                 
   @cCompany2           NVARCHAR(20),               
   @cPltDropID          NVARCHAR(18),              
   @cOrgPltDropID       NVARCHAR(18),               
   @cFinalStation       NVARCHAR(10),             
   @cLastStation        NVARCHAR(10),             
              
   @nOrdQty             INT,              
   @nActQty             INT,                 
   @nRecCnt             INT,              
   @nCounter            INT,              
   @nTTL_QTY            INT,              
   @nPicked_QTY         INT,              
   @nTotRecCnt          INT,              
   @nRecCounter         INT,     
   @cManifestPrinted    NVARCHAR(1),    
   @cDropIDShipped      NVARCHAR(1),    
   @cNextZone           NVARCHAR(10),    
   @cNextStation        NVARCHAR(10),     
   @nQCKey              INT,       
   @cPickMethod         NVARCHAR(10),    
   @nLoopCount          INT,          
   @cPickslipNo         NVARCHAR(10),     
   @cReasonKey          NVARCHAR(10),    
       
    
   @cLoc                NVARCHAR(10),    
   @cLot                NVARCHAR(10),    
   @nQtyAllocated       INT,    
   @nQtyPicked          INT,     
   @nSOHQty             INT,    
   @cSOHAvailable       NVARCHAR(10),    
   @cStatus             NVARCHAR(10),    
   @cQCOption           NVARCHAR(1),    
   @nScanQty            INT,    
   @nSPQty              INT,    
       
   -- Var for SKU Inquiry    
   @nTotalRec           INT,       
   @nCurrentRec         INT,    
   @cPUOM_Desc          NVARCHAR( 5), -- Preferred UOM desc      
   @cMUOM_Desc          NVARCHAR( 5), -- Master unit desc      
   @nPQTY_Avail         INT, -- QTY avail in preferred UOM      
   @nMQTY_Avail         INT, -- QTY avail in master UOM      
   @nPQTY_Alloc         INT, -- QTY alloc in preferred UOM      
   @nMQTY_Alloc         INT, -- QTY alloc in master UOM      
   @nPUOM_Div           INT, -- UOM divider     
   @nPQTY_Hold          INT, -- QTY Hold in preferred UOM      
   @nMQTY_Hold          INT, -- QTY Hold in master UOM      
   @cLottable01         NVARCHAR( 18),      
   @cLottable02         NVARCHAR( 18),      
   @cLottable03         NVARCHAR( 18),      
   @dLottable04         DATETIME,       
   @dLottable05         DATETIME,         
   @cInquiry_LOC        NVARCHAR( 10),       
   --@cInquiry_ID         NVARCHAR( 18),       
   @cID                 NVARCHAR( 18),       
   @cPUOM               NVARCHAR( 1), -- Prefer UOM      
   @cAltLOC             NVARCHAR(10),    
   @nFromScn            INT,    
   @nFromStep           INT,   
   @cScannedSKU         NVARCHAR(20),  
   @cTaskDetailKeyPK    NVARCHAR(10),  
   @cStatusMsg          NVARCHAR(255),  
   @cInTote             NVARCHAR(18),  
   @cInLoc              NVARCHAR(10),  
   @cQCZone             NVARCHAR(10),  
   @cRefTaskKey         NVARCHAR(10),  

   @nMQty_RPL           INT,      -- (james02)
   @nPQty_RPL           INT,      -- (james02)
   @nMQty_TTL           INT,      -- (james02)
   @nPQty_TTL           INT,      -- (james02)
   @nMQty_Pick          INT,      -- (james02)
   @nPQty_Pick          INT,      -- (james02)
   @cLottable04         NVARCHAR( 16), -- (james02)
   @cLottable05         NVARCHAR( 16), -- (james02) 
   @nQtyPacked          INT,       -- (james01)
   @nPAQty              INT,       -- (james01)
            
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

   @cLottable01      =  V_Lottable01, 
   @cLottable02      =  V_Lottable02, 
   @cLottable03      =  V_Lottable03, 
   @cLottable04      =  V_Lottable04, 
   @cLottable05      =  V_Lottable05, 

   @cOrderKey        = V_Orderkey,              
   @cConsigneekey    = V_ConsigneeKey,              
   @cSKU             = V_SKU,              
   @cSKUDescr        = V_SKUDescr,              
   @cPUOM            = V_UOM,      
   @cLoc             = V_Loc,         
   @cLOT             = V_LOT,   
   @cToteNo          = V_CASEID,                      
   @cTaskDetailKey   = V_String1,              
   @cOption          = V_String2,              
   @cTaskType        = V_String3,              
   @cReason          = V_String4,              
   @cLastUser        = V_String5,              
   @cLastZone        = V_String6,              
   @cFinalZone       = V_String7,                            
   @cWCSKey          = V_String10,              
   @cPrevOrderKey    = V_String11,              
   @cActStorer       = V_String12,              
   @cCompany1        = V_String13,              
   @cCompany2        = V_String14,              
   @cPltDropID       = V_String15,                        
   @cManifestPrinted = V_String20,     
   @cDropIDShipped   = V_String21,     
   @cNextZone        = V_String22,     
   @cNextStation     = V_String23, 
         
   @cPUOM_Desc       = V_String29,          
   @cMUOM_Desc       = V_String33,       
   @cAltLoc          = V_String39,    
   @cPickMethod      = V_String40,  

   @nMQTY_RPL        = V_QTY,
      
   @nFromScn         = V_FromScn,      
   @nFromStep        = V_FromStep,
      
   @nOrdQty          = V_Integer1,              
   @nActQty          = V_Integer2,  
   @nRecCnt          = V_Integer3,              
   @nCounter         = V_Integer4,              
   @nTotRecCnt       = V_Integer5,              
   @nRecCounter      = V_Integer6,     
   @nQCKey           = V_Integer7,              
   @nScanQty         = V_Integer8,              
   @nSPQty           = V_Integer9,              
   @nTotalRec        = V_Integer10,      
   @nCurrentRec      = V_Integer11,  
   @nPQTY_Avail      = V_Integer12,      
   @nPQTY_Alloc      = V_Integer13,      
   @nPQTY_Hold       = V_Integer14,     
   @nMQTY_Avail      = V_Integer15,      
   @nMQTY_Alloc      = CASE WHEN rdt.rdtIsValidQTY( V_String35,  0) = 1 THEN LEFT( V_String35, 5) ELSE 0 END,      
   @nMQTY_Hold       = CASE WHEN rdt.rdtIsValidQTY( V_String36,  0) = 1 THEN LEFT( V_String36, 5) ELSE 0 END,      
   @nPQTY_RPL        = V_LottableLabel01,
   @nPQTY_TTL        = V_LottableLabel02,
   @nMQTY_TTL        = V_LottableLabel03,
   @nMQTY_Pick       = V_LottableLabel04,
   @nPQTY_Pick       = V_LottableLabel05,
                    
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
IF @nFunc = 1646              
BEGIN              
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1646              
   IF @nStep = 1 GOTO Step_1   -- Scn = 2560  Option              
   IF @nStep = 2 GOTO Step_2   -- Scn = 2561  Tote/Case              
   IF @nStep = 3 GOTO Step_3   -- Scn = 2562  Routing Info              
   IF @nStep = 4 GOTO Step_4   -- Scn = 2563  SKU Info    
   IF @nStep = 5 GOTO Step_5   -- Scn = 2564  DropID, Loc, SKU    
   IF @nStep = 6 GOTO Step_6   -- Scn = 2565  QC Confirm      
   IF @nStep = 7 GOTO Step_7   -- Scn = 2566  New Tote / Case    
   IF @nStep = 8 GOTO Step_8   -- Scn = 2567  Short Pick Confirm      
   IF @nStep = 9 GOTO Step_9   -- Scn = 2568  SKU Inquiry Screen    
   IF @nStep = 10 GOTO Step_10 -- Scn = 2569  SKU Inquiry Lottable Screen    
   IF @nStep = 11 GOTO Step_11 -- Scn = 2570  SP Confirm      
   IF @nStep = 12 GOTO Step_12 -- Scn = 2571  PA Screen      
END              
              
RETURN -- Do nothing if incorrect step              
              
/********************************************************************************              
Step 0. Called from menu (func = 1629)              
********************************************************************************/              
Step_0:              
BEGIN              
   -- Set the entry point              
   SET @nScn  = 2560              
   SET @nStep = 1              
              
   -- initialise all variable              
   SET @cToteNo        = ''              
   SET @cOption        = ''              
   SET @cOrderKey      = ''              
   SET @cConsigneekey  = ''              
   SET @cSKU           = ''              
   SET @cSKUDescr      = ''              
   SET @cPackUOM03     = ''              
   SET @cTaskType      = ''              
   SET @cReason        = ''              
   SET @cLastUser      = ''              
   SET @cLastZone      = ''              
   SET @cFinalZone     = ''              
   SET @cWCSKey        = ''              
   SET @cTaskDetailKey = ''              
   SET @cLoadkey       = ''              
   SET @cPrevOrderKey  = ''              
   SET @cActStorer     = ''              
   SET @cCompany1      = ''              
   SET @cCompany2      = ''              
   SET @cPltDropID     = ''              
   SET @nOrdQty        = 0              
   SET @nActQty        = 0              
   SET @cOrgPltDropID  = ''      
   SET @cManifestPrinted = ''     
   SET @cDropIDShipped   = ''    
   SET @cNextZone        = ''               
              
   -- Prep next screen var                 
   SET @cOutField01 = ''               
   SET @cOutField02 = ''               
   SET @cOutField03 = ''               
   SET @cOutField04 = ''               
   SET @cOutField05 = ''               
   SET @cOutField06 = ''               
   SET @cOutField07 = ''               
   SET @cOutField08 = ''               
   SET @cOutField09 = ''               
   SET @cOutField10 = ''               
   SET @cOutField11 = ''       
    
   -- Get prefer UOM      
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA      
   FROM RDT.rdtMobRec M WITH (NOLOCK)      
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)      
   WHERE M.Mobile = @nMobile      
            
END              
GOTO Quit              
              
/********************************************************************************              
Step 1. screen = 2560              
   Option (Field01, input)              
********************************************************************************/              
Step_1:              
BEGIN              
   IF @nInputKey = 1 -- ENTER              
   BEGIN              
      -- Screen mapping              
      SET @cOption = @cInField01              
              
      IF ISNULL(RTRIM(@cOption), '') = ''              
      BEGIN              
         SET @nErrNo = 71216              
         SET @cErrMsg = rdt.rdtgetmessage( 71216, @cLangCode, 'DSP') --Option req              
         EXEC rdt.rdtSetFocusField @nMobile, 1              
         GOTO Step_1_Fail                
      END               
              
      IF @cOption <> '1' AND @cOption <> '9'              
      BEGIN              
         SET @nErrNo = 71217              
         SET @cErrMsg = rdt.rdtgetmessage( 71217, @cLangCode, 'DSP') --Invalid Option              
         EXEC rdt.rdtSetFocusField @nMobile, 1              
         GOTO Step_1_Fail                
      END               
                      
      --prepare next screen variable              
      SET @cOutField01 = ''              
              
      SET @nScn = @nScn + 1              
      SET @nStep = @nStep + 1              
   END              
              
   IF @nInputKey = 0 -- ESC              
   BEGIN              
      -- Back to menu              
      SET @nFunc = @nMenu              
      SET @nScn  = @nMenu              
      SET @nStep = 0              
              
      SET @cOutField01 = ''               
      SET @cOutField02 = ''               
      SET @cOutField03 = ''               
      SET @cOutField04 = ''               
      SET @cOutField05 = ''               
      SET @cOutField06 = ''               
      SET @cOutField07 = ''               
      SET @cOutField08 = ''               
      SET @cOutField09 = ''               
      SET @cOutField10 = ''               
      SET @cOutField11 = ''               
              
      SET @cToteNo        = ''              
      SET @cOption        = ''              
      SET @cOrderKey      = ''              
      SET @cConsigneekey  = ''              
      SET @cSKU           = ''              
      SET @cSKUDescr      = ''              
      SET @cPackUOM03     = ''              
      SET @cTaskType      = ''              
      SET @cReason        = ''              
      SET @cLastUser      = ''              
      SET @cLastZone      = ''              
      SET @cFinalZone     = ''              
      SET @cWCSKey      = ''              
      SET @cTaskDetailKey = ''              
      SET @cLoadkey       = ''              
      SET @cPrevOrderKey  = ''              
      SET @cActStorer     = ''              
      SET @cCompany1      = ''              
      SET @cCompany2      = ''              
      SET @cPltDropID     = ''              
      SET @nOrdQty        = 0              
      SET @nActQty        = 0              
      SET @cOrgPltDropID  = ''     
      SET @cManifestPrinted = ''     
      SET @cDropIDShipped   = ''    
      SET @cNextZone        = ''      
                 
   END              
   GOTO Quit              
              
   Step_1_Fail:              
   BEGIN              
      SET @cOption = ''              
              
      SET @cOutField01 = ''              
   END              
END              
GOTO Quit              
              
/********************************************************************************              
Step 2. screen = 2561              
   TOTE NO/CASE ID  (Field01, input)              
********************************************************************************/              
Step_2:              
BEGIN              
   IF @nInputKey = 1 -- ENTER              
   BEGIN              
      -- Screen mapping              
      SET @cToteNo = @cInField01              
           
      IF ISNULL(RTRIM(@cToteNo), '') = ''              
      BEGIN              
         SET @nErrNo = 71218              
         SET @cErrMsg = rdt.rdtgetmessage( 71218, @cLangCode, 'DSP') --TOTE/CASE # req              
         EXEC rdt.rdtSetFocusField @nMobile, 1              
         GOTO Step_2_Fail                
      END        
          
      DELETE FROM rdt.rdtQCInquiryLog      
      WHERE UserID = @cUserName    
    
      SET @nCounter = 1                
      SET @nRecCounter = 1             
            
      IF @cOption = '1' -- Scan Tote No              
      BEGIN              
         -- check exists in WCSRouting              
         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToteNo)              
         BEGIN        
            SET @nErrNo = 71219              
            SET @cErrMsg = rdt.rdtgetmessage( 71219, @cLangCode, 'DSP') --Invalid TOTE/CASE              
            EXEC rdt.rdtSetFocusField @nMobile, 1              
            GOTO Step_2_Fail                
         END              
        
         SELECT @cFinalZone = c2.Code,   
                @cFinalStation = c1.Short   
         FROM DROPID D WITH (NOLOCK)  
         JOIN CODELKUP c1 WITH (NOLOCK) ON c1.listname = 'WCSROUTE' AND c1.Code = D.DropIDType   
         JOIN CODELKUP c2 ON  c2.LISTNAME = 'WCSSTATION' AND c2.Short = c1.Short   
         WHERE D.Dropid = @cToteNo   
        
         SELECT TOP 1   
                @cTaskType = TaskType,              
                @cLastUser = EditWho,                         
                @cWCSKey = WCSKey,              
                @cActStorer = Storerkey              
         FROM dbo.WCSRouting WITH (NOLOCK)              
         WHERE ToteNo = @cToteNo              
         AND Facility = @cFacility              
         ORDER BY WCSKey DESC              
        
         SET @cLastStation=''        
         SELECT TOP 1 @cLastStation = ISNULL(ZONE,'')  
         FROM dbo.WCSRoutingDetail WITH (NOLOCK)              
         WHERE Status <> '0' -- (ChewKP03)            
         AND   ToteNo = @cToteNo  
         ORDER BY RowRef DESC      
  
                 
--      SELECT @cFinalZone = Code             
--      FROM dbo.CodeLKup WITH (NOLOCK)             
--      WHERE Listname = 'WCSStation'            
--         AND Short = @cFinalStation     
        
         IF ISNULL(@cLastStation,'') = ''  
         BEGIN  
            SELECT TOP 1   
                   @cLastZone = LOC.PutawayZone  
            FROM TaskDetail td WITH (NOLOCK)   
            JOIN LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc   
            WHERE dropid = @cToteNo       
            AND   td.[Status]='9'   
            ORDER BY td.EditDate DESC  
         END  
         ELSE  
         BEGIN  
            SELECT @cLastZone = code            
            FROM dbo.CodeLKup WITH (NOLOCK)            
            WHERE Listname = 'WCSStation'            
               AND Short = @cLastStation               
         END         
  
         SELECT @cQCZone = Short  
               FROM dbo.CodeLKup WITH (NOLOCK)            
         WHERE Listname = 'WCSROUTE'            
            AND Code = 'QC'     
                         
         SELECT TOP 1   
               @cNextStation = ZONE     
         FROM dbo.WCSRoutingDetail WITH (NOLOCK)    
         WHERE Status = '0'    
         --AND AddDate = GetDate() - 1     
         AND ToteNo = @cToteNo    
         AND Zone NOT IN (@cQCZone)  
         ORDER BY RowRef   
       
         SET @cNextZone    = ''       
         SELECT @cNextZone = Code    
         FROM dbo.CodeLKup WITH (NOLOCK)            
         WHERE Listname = 'WCSStation'            
            AND Short = @cNextStation      
    
        SELECT @cManifestPrinted = CASE ManifestPrinted      
               WHEN '0' THEN 'N'    
               ELSE 'Y' END           
        FROM dbo.DropID WITH (NOLOCK)                
        WHERE DropID = @cToteNo       
    
        IF EXISTS (SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)       
                            JOIN dbo.PickDetail PD WITH (NOLOCK) ON TD.TaskDetailKey = PD.TaskDetailKey      
                            JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey      
                            WHERE TD.StorerKey = @cStorerKey      
                             AND TD.DropID = @cToteno      
                             AND O.Status NOT IN ('9', 'CANC'))    
        BEGIN    
           SET @cDropIDShipped = 'N'    
        END      
        ELSE    
        BEGIN    
           SET @cDropIDShipped = 'Y'    
        END          
                
        SELECT TOP 1 @cLoadkey = TD.LoadKey            
        FROM dbo.TaskDetail TD WITH (NOLOCK)             
        JOIN dbo.PickDetail PD WITH (NOLOCK)             
           ON (TD.StorerKey = PD.StorerKey AND TD.TaskDetailKey = PD.TaskDetailKey)           
        JOIN dbo.Orders O WITH (NOLOCK)   -- (ChewKP01)          
           ON (O.Orderkey = PD.Orderkey ) -- (ChewKP01)           
        WHERE TD.DropID = @cToteNo              
           AND  TD.Storerkey = @cActStorer          
           AND O.Status NOT IN ('9', 'CANC') -- (ChewKP01)          
          
        SET @cReason = ''  
            
        DECLARE CUR_Reason CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
        SELECT DISTINCT ReasonKey              
        FROM dbo.TaskDetail WITH (NOLOCK)              
        WHERE DropID = @cToteNo              
        AND  ReasonKey <> ''              
        AND  Loadkey = @cLoadkey              
        AND  Storerkey = @cActStorer              
        OPEN CUR_Reason    
        FETCH NEXT FROM CUR_Reason INTO @cReasonKey     
        WHILE @@FETCH_STATUS <> -1    
        BEGIN    
           SET @cReason = @cReason + CASE WHEN LEN(@cReason) > 1 THEN ',' + @cReasonKey  
                                          ELSE @cReasonKey  
                                     END     
                
           FETCH NEXT FROM CUR_Reason INTO @cReasonKey     
        END    
        CLOSE CUR_Reason    
        DEALLOCATE CUR_Reason    
            
            
        IF ISNULL(RTRIM(@cReason), '') = ''              
        BEGIN              
          SET @cReason = ''              
        END     
            
            
        -- Insert Record Into rdt.rdtQCInquiryLog (Start)--    
        SET @nRecCnt = 0    
        SET @cPrevOrderkey = ''    
            
        SELECT @cPickMethod = DropIDType FROM dbo.DropID WITH (NOLOCK)    
        WHERE DropID = @cToteNo    
            
        DECLARE curTote CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
        SELECT PD.Orderkey, PD.PickslipNo, OD.SKU, PD.Loc,   
               --SUM(CASE WHEN PD.STATUS IN ('0','1','2','3') THEN PD.Qty ELSE 0 END) AS QtyAllocated,   
               SUM(PD.Qty) AS QtyAllocated,  
               SUM(CASE WHEN PD.STATUS IN ('5','6','7','8')  THEN PD.Qty ELSE 0 END) AS QtyPicked,   
               SUM(CASE WHEN PD.STATUS = '4'  THEN PD.Qty ELSE 0 END) AS SPQty,   
               PD.TaskDetailkey  
        FROM dbo.PickDetail PD WITH (NOLOCK)    
        INNER JOIN dbo.Orders O WITH (NOLOCK) ON (O.Orderkey = PD.Orderkey)    
        INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON   
            (OD.Orderkey = PD.Orderkey AND PD.OrderlineNumber = OD.OrderLineNumber)    
        INNER JOIN dbo.TaskDetail TD WITH (NOLOCK) ON TD.TaskDetailkey = PD.TaskDetailkey    
        WHERE TD.DropID =  @cToteNo    
        AND TD.PickMethod = @cPickMethod    
        AND O.Facility = @cFacility    
        AND O.Status NOT IN ('9', 'CANC')   
        AND TD.TaskType = 'PK'       
        GROUP BY PD.Orderkey, PD.PickslipNo, OD.SKU, PD.Loc, PD.TaskDetailkey 
        HAVING SUM(CASE WHEN PD.STATUS = '4'  THEN PD.Qty ELSE 0 END) > 0 -- (SHONGxx)     
        ORDER BY PD.OrderKey, PD.PickSlipNo, OD.SKU     
            
        OPEN curTote            
        FETCH NEXT FROM curTote INTO @cOrderkey, @cPickslipNo, @cSKU , @cLoc ,   
                        @nQtyAllocated, @nQtyPicked , @nSPQty, @cTaskDetailkey       
        WHILE @@FETCH_STATUS <> -1              
        BEGIN           
--           IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)     
--                           WHERE PickSlipNo = @cPickSlipNo    
--                           AND Orderkey = @cOrderkey    
--                           AND Status = '9')    
--           BEGIN    
             SET @cReasonkey = ''    
             SELECT @cReasonkey = Reasonkey FROM dbo.TAskDetail WITH (NOLOCK)     
             WHERE TaskDetailkey = @cTaskDetailkey    
                   AND DropID = @cToteNo    
                   AND SKU = @cSKU    
                    
             BEGIN TRAN  
                    
             INSERT INTO rdt.rdtQCInquiryLog (Mobile, UserID, Status, Storerkey, DropID, DropIDType, ReasonKey,     
                                           Orderkey, TaskDetailKey, SKU, Loc, QtyAllocated, QtyPicked,   
                                           QtyShortPick, AddWho, AddDate )    
             VALUES (@nMobile, @cUserName, '0', @cStorerkey, @cToteNo, @cPickMethod, @cReasonkey,    
                     @cOrderkey, @cTaskDetailKey, @cSKU, @cLoc, @nQtyAllocated, @nQtyPicked, @nSPQty, 
                     @cUserName, GetDate())    
                    
              IF @@ERROR <> 0              
              BEGIN              
                  ROLLBACK TRAN              
                  SET @nErrNo = 71226                 
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsQCFail                
                  GOTO Step_2_Fail                    
              END           
              ELSE    
              BEGIN    
                  COMMIT TRAN    
              END    
                
--            END    
                
            FETCH NEXT FROM curTote INTO @cOrderkey, @cPickslipNo, @cSKU , @cLoc ,   
                        @nQtyAllocated, @nQtyPicked , @nSPQty, @cTaskDetailkey      
         END              
         CLOSE curTote              
         DEALLOCATE curTote          
         -- Insert Record Into rdt.rdtQCInquiryLog (End)--    
      END              
              
      IF @cOption = '9' -- Scan Case ID              
      BEGIN            
         IF NOT EXISTS (SELECT 1   
                        FROM dbo.DropIDDetail DD WITH (NOLOCK)   
                        JOIN dbo.Dropid D WITH (NOLOCK) ON D.Dropid = DD.Dropid AND D.DropIDType='C'           
                        WHERE DD.ChildId = @cToteNo)          
         BEGIN        
           SET @nErrNo = 71237              
           SET @cErrMsg = rdt.rdtgetmessage( 71237, @cLangCode, 'DSP') --Invalid Case              
           EXEC rdt.rdtSetFocusField @nMobile, 1              
           GOTO Step_2_Fail                
         END        
            
        SELECT @cOrgPltDropID = DID.DropID,              
                  @cLoadkey = DP.Loadkey,    
                  @cManifestPrinted = CASE DP.ManifestPrinted      
                  WHEN '0' THEN 'N'    
                  ELSE 'Y' END           
        FROM dbo.DROPIDDETAIL DID WITH (NOLOCK)                      
        JOIN dbo.DROPID DP WITH (NOLOCK) ON (DP.DropID = DID.DropID AND DP.DropIDType='C')              
        WHERE ChildID = @cToteNo          
  
         -- For DPK Store Case Pick  
         -- Pallet Close and Comfirm in Induction   
         -- Case ID should exists in WCSRouting   
         --SELECT *   
         --FROM WCSRouting wd WITH (NOLOCK)   
         --WHERE wd.ToteNo = @cToteNo   
         --AND     
  
-------------------------------  
         SET @cFinalZone = ''  
         SET @cTaskType = 'PA'   
         SET @cTaskDetailKey = ''  
         SET @cRefTaskKey = ''  
           
         SELECT TOP 1   
                @cFinalZone = ISNULL(l.PutawayZone,''),   
                @cRefTaskKey = ISNULL(TD.RefTaskKey,''),   
                @cTaskDetailKey = TD.TaskDetailKey,
                @cLoc = TD.ToLoc,
                @nPAQty = ISNULL(Qty, 0)    
         FROM LOC L WITH (NOLOCK)   
         JOIN TASKDETAIL TD WITH (NOLOCK) ON L.Loc = TD.ToLoc AND TD.TaskType='PA'    
         WHERE TD.Caseid = @cToteNo   
         AND   TD.Status >= '0'   -- Only show activated PA case (james01) 
         ORDER BY TD.TaskDetailKey DESC   
  
         SELECT TOP 1   
                @cLastUser = AddWho,                                    
                @cActStorer = Storerkey,   
                @cSKU       = SKU               
         FROM dbo.UCC WITH (NOLOCK)              
         WHERE UCCNo = @cToteNo              
  
         IF ISNULL(RTRIM(@cFinalZone),'') = ''  
         BEGIN  
            SET @cTaskDetailKey = ''  
              
            SELECT TOP 1   
                   @cFinalZone = l.PutawayZone   
            FROM LOC L WITH (NOLOCK)   
            JOIN PICKDETAIL PD WITH (NOLOCK) ON L.Loc = PD.Loc   
            WHERE PD.StorerKey = @cStorerKey  
            AND   PD.SKU = @cSKU   
            AND   PD.STATUS <> '9'   
            AND   PD.CaseID = @cToteNo   
            ORDER BY l.PutawayZone DESC

            IF ISNULL(RTRIM(@cFinalZone),'') <> ''  
            BEGIN  
               SET @cTaskType = 'CASE'  
            END  
         END  
  
         IF @cTaskType = 'CASE'  
         BEGIN              
            SELECT @cQCZone = Short  
                  FROM dbo.CodeLKup WITH (NOLOCK)            
            WHERE Listname = 'WCSROUTE'            
               AND Code = 'QC'     

            SELECT TOP 1   
                  @cLastStation = ZONE     
            FROM dbo.WCSRoutingDetail WITH (NOLOCK)    
            WHERE Status > '0'    
            AND ToteNo = @cToteNo    
            AND Zone NOT IN (@cQCZone)  
            ORDER BY RowRef DESC

            SET @cLastZone    = ''       
            SELECT @cLastZone = Code    
            FROM dbo.CodeLKup WITH (NOLOCK)            
            WHERE Listname = 'WCSStation'            
               AND Short = @cLastStation   

            SELECT TOP 1   
                  @cNextStation = ZONE     
            FROM dbo.WCSRoutingDetail WITH (NOLOCK)    
            WHERE Status = '0'    
            AND ToteNo = @cToteNo    
            AND Zone NOT IN (@cQCZone)  
            ORDER BY RowRef  
                 
            SET @cNextZone    = ''       
            SELECT @cNextZone = Code    
            FROM dbo.CodeLKup WITH (NOLOCK)            
            WHERE Listname = 'WCSStation'            
               AND Short = @cNextStation                                  
         END     
         ELSE  
         BEGIN  
            SET @cNextZone = ''  
         END     
  
        IF SUBSTRING (@cOrgPltDropID , 1 ,1 ) = 'N'              
        BEGIN              
            SET @cPltDropID = SUBSTRING (@cOrgPltDropID , 2, 18)              
        END              
        ELSE              
        BEGIN              
            SET @cPltDropID = SUBSTRING(@cOrgPltDropID, 1, LEN(RTRIM(@cOrgPltDropID)) - 4)            
        END              
       
        IF EXISTS (SELECT 1 FROM dbo.PICKDETAIL  WITH (NOLOCK)               
                   WHERE CaseID = @cToteNo AND Status = '9' AND StorerKey = @cStorerkey)    
        BEGIN     
            SET @cDropIDShipped = 'Y'    
        END    
        ELSE    
        BEGIN    
            SET @cDropIDShipped = 'N'    
        END    
          
        SET @cReason = ''  
          
        DECLARE CUR_Reason CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
        SELECT DISTINCT ReasonKey              
        FROM dbo.TaskDetail WITH (NOLOCK)              
        WHERE CaseID = @cToteNo              
           AND  ReasonKey <> ''              
           AND  DropID = @cPltDropID              
           AND  Loadkey = @cLoadkey              
           AND  Storerkey = @cActStorer              
        OPEN CUR_Reason    
        FETCH NEXT FROM CUR_Reason INTO @cReasonKey     
        WHILE @@FETCH_STATUS <> -1    
        BEGIN    
           SET @cReason = @cReason + CASE WHEN LEN(@cReason) > 1 THEN ',' + @cReasonKey  
                                          ELSE @cReasonKey  
                                     END     
                
           FETCH NEXT FROM CUR_Reason INTO @cReasonKey     
        END    
        CLOSE CUR_Reason    
        DEALLOCATE CUR_Reason            
              
        IF ISNULL(RTRIM(@cReason), '') = ''              
        BEGIN          
          SET @cReason = ''              
        END      
          
        -- Insert Record Into rdt.rdtQCInquiryLog (Start)--    
        SET @nRecCnt = 0    
        SET @cPrevOrderkey = ''    
          
        IF @cTaskType <> 'PA'  
        BEGIN     
           DECLARE curTote CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
           SELECT PD.Orderkey, PD.PickslipNo, OD.SKU, PD.Loc,   
                  --SUM(CASE WHEN PD.STATUS IN ('0','1','2','3') THEN PD.Qty ELSE 0 END) AS QtyAllocated,  
                  SUM(PD.Qty) AS QtyAllocated,   
                  SUM(CASE WHEN PD.STATUS IN ('5','6','7','8')  THEN PD.Qty ELSE 0 END) AS QtyPicked,    
                  SUM(CASE WHEN PD.STATUS = '4'  THEN PD.Qty ELSE 0 END) AS SPQty,   
                  PD.TaskDetailkey     
           FROM dbo.PickDetail PD WITH (NOLOCK)    
           INNER JOIN dbo.Orders O WITH (NOLOCK) ON (O.Orderkey = PD.Orderkey)    
           INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey   
                      AND PD.OrderlineNumber = OD.OrderLineNumber)    
           --INNER JOIN dbo.TaskDetail TD WITH (NOLOCK) ON TD.TaskDetailkey = PD.TaskDetailkey    
           WHERE PD.CaseID =  @cToteNo    
           AND O.Facility = @cFacility    
           AND O.Status NOT IN ('9', 'CANC')       
           GROUP BY PD.Orderkey, PD.PickslipNo, OD.SKU, PD.Loc, PD.TaskDetailkey    
           ORDER BY PD.OrderKey, PD.PickSlipNo, OD.SKU     
               
           OPEN curTote              
           FETCH NEXT FROM curTote INTO @cOrderkey, @cPickslipNo, @cSKU , @cLoc,   
                                        @nQtyAllocated, @nQtyPicked,    
                                        @nSPQty, @cTaskDetailkey       
           WHILE @@FETCH_STATUS <> -1              
           BEGIN           
            --IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)     
            --               WHERE PickSlipNo = @cPickSlipNo    
            --               AND Orderkey = @cOrderkey    
            --               AND Status = '9')    
            BEGIN    
                SET @cReasonkey = ''    
                SELECT @cReasonkey = Reasonkey   
                FROM dbo.TAskDetail WITH (NOLOCK)     
                WHERE TaskDetailkey = @cTaskDetailkey    
                    
                    
                BEGIN TRAN        
                INSERT INTO rdt.rdtQCInquiryLog (Mobile, UserID, Status, Storerkey, DropID, DropIDType, ReasonKey,     
                                              Orderkey, TaskDetailKey, SKU, Loc, QtyAllocated, QtyPicked, QtyShortPick, 
                                              AddWho, AddDate )    
                VALUES (@nMobile, @cUserName, '0', @cStorerkey, @cToteNo, 'CASE', @cReasonkey,    
                        @cOrderkey, @cTaskDetailKey, @cSKU, @cLoc, @nQtyAllocated, @nQtyPicked, 
                        @nSPQty , @cUserName, GetDate())    
                    
                 IF @@ERROR <> 0              
                 BEGIN              
                     ROLLBACK TRAN              
                     SET @nErrNo = 71238                 
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsQCFail                
                     GOTO Step_2_Fail                    
                 END           
                 ELSE    
                 BEGIN    
                     COMMIT TRAN    
                 END    
                   
            END    
                
            FETCH NEXT FROM curTote INTO @cOrderkey, @cPickslipNo, @cSKU , @cLoc,   
                                        @nQtyAllocated, @nQtyPicked,    
                                        @nSPQty, @cTaskDetailkey       
           END              
           CLOSE curTote              
           DEALLOCATE curTote          
                  
           -- Insert Record Into rdt.rdtQCInquiryLog (End)--            
         END            
         ELSE
         BEGIN
            SELECT @cTaskType = TaskType FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey

            SET @cOutField01 = CASE WHEN @cTaskType = 'PA' THEN 'PUTAWAY' ELSE 'REPLEN' END
            SET @cOutField02 = '1/1'      
            SET @cOutField03 = @cToteNo    
            SET @cOutField04 = @cLastUser               
            SET @cOutField05 = @cLastZone              
            SET @cOutField06 = @cNextZone          
            SET @cOutField07 = @cFinalZone     
            SET @cOutField08 = @cLoc    
            SET @cOutField09 = @nPAQty   
                  
            SET @nScn = 2571    
            SET @nStep = 12     

            GOTO Quit
         END

         SET @cPickMethod = @cTaskType    
      END -- Scan Case ID   
  
     --prepare next screen variable              
      SET @cOutField01 = @cToteNo              
      SET @cOutField02 = @cManifestPrinted              
      SET @cOutField03 = @cDropIDShipped    
      SET @cOutField04 = @cLastUser               
      SET @cOutField05 = @cLastZone              
      SET @cOutField06 = @cNextZone          
      SET @cOutField07 = @cFinalZone     
      SET @cOutField08 = @cReason     
      SET @cOutField09 = @cPickMethod  
      SET @nScn = @nScn + 1              
      SET @nStep = @nStep + 1                       
   END              
              
   IF @nInputKey = 0 -- ESC              
   BEGIN  
      DELETE FROM rdt.rdtQCInquiryLog      
      WHERE UserID = @cUserName    
                    
      SET @cOutField01 = ''               
      SET @cOutField02 = ''               
      SET @cOutField03 = ''               
      SET @cOutField04 = ''               
      SET @cOutField05 = ''               
      SET @cOutField06 = ''               
      SET @cOutField07 = ''               
      SET @cOutField08 = ''               
      SET @cOutField09 = ''               
      SET @cOutField10 = ''               
      SET @cOutField11 = ''               
              
      SET @cToteNo        = ''              
      SET @cOption        = ''              
      SET @cOrderKey      = ''              
      SET @cConsigneekey  = ''              
      SET @cSKU           = ''              
      SET @cSKUDescr      = ''              
      SET @cPackUOM03     = ''              
      SET @cTaskType      = ''              
      SET @cReason        = ''              
      SET @cLastUser      = ''              
      SET @cLastZone      = ''              
      SET @cFinalZone     = ''              
      SET @cWCSKey        = ''              
      SET @cTaskDetailKey = ''              
      SET @cLoadkey       = ''              
      SET @cPrevOrderKey  = ''              
      SET @cActStorer     = ''              
      SET @cCompany1      = ''              
      SET @cCompany2      = ''              
      SET @cPltDropID     = ''              
      SET @nOrdQty        = 0              
      SET @nActQty        = 0              
      SET @cOrgPltDropID  = ''               
              
      SET @nScn = @nScn - 1              
      SET @nStep = @nStep - 1              
   END              
   GOTO Quit              
              
   Step_2_Fail:              
   BEGIN              
      SET @cToteNo = ''              
              
      SET @cOutField01 = ''              
   END              
END              
GOTO Quit              
              
/********************************************************************************              
Step 3. screen = 2562              
 Info Screen              
********************************************************************************/              
Step_3:              
BEGIN              
   IF @nInputKey = 1 -- ENTER              
   BEGIN              
          
      SET @cOrderKey = ''    
      SET @cSKU = ''    
      SET @nQtyAllocated = 0    
      SET @nQtyPicked = 0    
      SET @cReasonkey = ''    
      SET @nSOHQty = 0    
      SET @cSOHAvailable = ''    
      SET @nTotRecCnt = 0    
      SET @nRecCnt = 0    
      SET @nSPQty  = 0    
    
          
      SELECT TOP 1     
       @cPickMethod     = DropIDType     
      ,@cOrderkey       = Orderkey    
      ,@nQtyAllocated   = QtyAllocated    
      ,@cReasonkey      = Reasonkey    
      ,@cSKU            = SKU    
      ,@cLoc            = Loc    
      FROM rdt.rdtQCInquiryLog WITH (NOLOCK)    
      WHERE UserID = @cUserName   
        and Mobile = @nMobile   
        and DropID = @cToteNo     
      Order by Orderkey, SKU             
             
      IF @@RowCount = 0    
      BEGIN    
           SET @cErrMsg = 'No More Records'            
           --  SET @nScn = @nScn + 1        
           --  SET @nStep =@nStep + 1        
           GOTO QUIT         
      END    
    
      SET @nCounter = 1                
      SET @nRecCounter = 1        
    
          
      SELECT @nRecCnt = COUNT(DISTINCT Orderkey)   
      FROM rdt.rdtQCInquiryLog WITH (NOLOCK)    
      WHERE UserID = @cUserName and Mobile = @nMobile and DropID = @cToteNo      
          
      SELECT DISTINCT @nTotRecCnt = Count(1)   
      FROM rdt.rdtQCInquiryLog WITH (NOLOCK)    
      WHERE UserID = @cUserName and Mobile = @nMobile   
      and DropID = @cToteNo and Orderkey = @cOrderkey    
          
      SELECT @nSOHQty = SUM(Qty)   
      FROM dbo.SKUxLoc SL WITH (NOLOCK)    
      INNER JOIN LOC LOC WITH (NOLOCK) ON Loc.Loc = SL.Loc    
      WHERE SL.SKU = @cSKU    
      AND LOC.LocationType = 'PICK'    
          
      IF @nSOHQty = 0    
      BEGIN    
          SET @cSOHAvailable = 'No'    
      END      
      ELSE    
      BEGIN    
         SET @cSOHAvailable = 'Yes'    
      END    
          
      SELECT @nQtyPicked = QtyPicked,  
             @nQtyAllocated = QtyAllocated,  
             @nSPQty = QtyShortPick   
      FROM rdt.rdtQCInquiryLog WITH (NOLOCK)    
      WHERE Orderkey = @cOrderkey     
        AND SKU = @cSKU    
        AND UserID = @cUserName  

     -- (james01)
     SELECT @nQtyPacked = ISNULL(SUM(PD.Qty), 0) 
      FROM dbo.PackDetail PD WITH (NOLOCK)      
      JOIN dbo.packHeader PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
      WHERE PH.StorerKey = @cStorerKey      
         AND PH.OrderKey = @cOrderkey      
         AND PD.SKU = @cSKU
    
      --SET @nSPQty = @nQtyAllocated - @nQtyPicked    
    
      SET @cPrevOrderkey = @cOrderkey              
            
      --prepare next screen variable              
      SET @cOutField01 = @cPickMethod     
      SET @cOutField02 = RTRIM(CAST(@nCounter AS NVARCHAR( 5))) + '/' + CAST(@nRecCnt AS NVARCHAR( 5))      
      SET @cOutField03 = @cOrderkey    
      SET @cOutField04 = @nQtyAllocated   
      SET @cOutField05 = @nQtyPicked    
      SET @cOutField06 = ISNULL(RTRIM(@cReasonkey),'')    
      SET @cOutField07 = @nSPQty    
      SET @cOutField08 = RTRIM(CAST(@nRecCounter AS NVARCHAR( 5))) + '/' + CAST(@nTotRecCnt AS NVARCHAR( 5))      
      SET @cOutField09 = @cSKU     
      SET @cOutField10 = ISNULL(LEFT(RTRIM(@cLoc), 20), '')              
      SET @cOutField11 = CAST(@nSOHQty AS INT)              
      SET @cOutField12 = @cSOHAvailable        
      SET @cOutField13 = ''          
      SET @cOutField14 = @nQtyPacked
            
      SET @nScn = @nScn + 1    
      SET @nStep = @nStep + 1     
   END              
              
   IF @nInputKey = 0 -- ESC              
   BEGIN      
          
       --prepare next screen variable              
      SET @cOutField01 = @cToteNo              
      SET @cOutField02 = @cManifestPrinted              
      SET @cOutField03 = @cDropIDShipped    
      SET @cOutField04 = @cLastUser               
      SET @cOutField05 = @cLastZone              
      SET @cOutField06 = @cNextZone          
      SET @cOutField07 = @cFinalZone     
      SET @cOutField08 = @cReason     
               
      SET @cOutField09 = @cPickMethod              
      SET @cOutField10 = ''              
      SET @cOutField11 = ''              
              
      SET @cToteNo        = ''              
      SET @cOrderKey      = ''              
      SET @cConsigneekey  = ''              
      SET @cSKU           = ''              
      SET @cSKUDescr      = ''              
      SET @cPackUOM03     = ''              
      SET @cTaskType      = ''              
      SET @cReason        = ''              
      SET @cLastUser      = ''              
      SET @cLastZone      = ''              
      SET @cFinalZone     = ''              
      SET @cWCSKey        = ''              
      SET @cTaskDetailKey = ''              
      SET @cLoadkey       = ''              
      SET @cPrevOrderKey  = ''              
      SET @cActStorer     = ''              
      SET @cCompany1      = ''              
      SET @cCompany2      = ''              
      SET @cPltDropID     = ''              
      SET @nOrdQty        = 0        
      SET @nActQty        = 0              
      SET @cOrgPltDropID  = ''               
              
      SET @nScn = @nScn - 1              
      SET @nStep = @nStep - 1              
   END              
   GOTO Quit              
END              
GOTO Quit              
              
/********************************************************************************              
Step 4. screen = 2563               
  info screen              
********************************************************************************/              
Step_4:              
BEGIN              
   IF @nInputKey = 1 -- ENTER              
   BEGIN              
         
      --SET @cOrderKey = ''    
      --SET @cSKU = ''    
      SET @nQtyAllocated = 0    
      SET @nQtyPicked = 0    
      SET @cReasonkey = ''    
      SET @nSOHQty = 0    
      SET @cSOHAvailable = ''    
      --SET @nTotRecCnt = 0    
      --SET @nRecCnt = 0    
    
      SET @cQCOption = ISNULL(@cInField13,'')       
    
      IF ISNULL(@cQCOption,'') <> ''    
      BEGIN    
         IF ISNULL(RTRIM(@cQCOption), '') <> '1' AND ISNULL(RTRIM(@cQCOption), '') <> '9'           
         BEGIN              
            SET @nErrNo = 71221              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'              
            GOTO Step_4_Fail              
         END      
      END      
     
      IF ISNULL(@cQCOption,'') <> ''    
      BEGIN    
         GOTO QCOption    
      END    
         
      IF @cPrevOrderkey = ''    
      BEGIN    
         SET @nRecCounter = 1  
           
         SELECT TOP 1     
          @cPickMethod     = DropIDType     
         ,@cOrderkey       = Orderkey    
         ,@nQtyAllocated   = QtyAllocated    
         ,@cReasonkey      = Reasonkey    
         ,@cSKU            = SKU    
         ,@cLoc            = Loc
         ,@cTaskDetailKey  = TaskDetailKey     
         FROM rdt.rdtQCInquiryLog WITH (NOLOCK)    
         WHERE UserID = @cUserName and Mobile = @nMobile and DropID = @cToteNo     
         Order by Orderkey, SKU    
             
         IF @@RowCount = 0    
         BEGIN    
           SET @cErrMsg = 'No More Records'            
                         
           SET @nScn = @nScn      
           SET @nStep =@nStep    
           GOTO QUIT       
         END    
      END    
      ELSE    
      BEGIN    
         SELECT TOP 1     
          @cPickMethod      = DropIDType     
         ,@cOrderkey       = Orderkey    
         ,@nQtyAllocated   = QtyAllocated    
         ,@cReasonkey      = Reasonkey    
         ,@cSKU            = SKU    
         ,@cLoc            = Loc    
         ,@cTaskDetailKey  = TaskDetailKey  
         FROM rdt.rdtQCInquiryLog WITH (NOLOCK)    
         WHERE UserID = @cUserName and Mobile = @nMobile and DropID = @cToteNo     
         AND SKU > @cSKU    
         AND Orderkey = @cOrderkey     
         Order by Orderkey, SKU    
                 
         IF @@RowCount = 0    
         BEGIN    
            SELECT TOP 1     
            @cPickMethod      = DropIDType     
            ,@cOrderkey       = Orderkey    
            ,@nQtyAllocated   = QtyAllocated    
            ,@cReasonkey      = Reasonkey    
            ,@cSKU            = SKU    
            ,@cLoc            = Loc    
            ,@cTaskDetailKey  = TaskDetailKey 
            FROM rdt.rdtQCInquiryLog WITH (NOLOCK)    
            WHERE UserID = @cUserName and Mobile = @nMobile and DropID = @cToteNo     
            AND Orderkey > @cOrderkey     
            Order by Orderkey, SKU    
    
            IF @@RowCount = 0    
            BEGIN    
               SET @cErrMsg = 'No More Records'            
                            
               SET @nScn = @nScn       
               SET @nStep =@nStep       
               GOTO QUIT         
            END    
            SET @nRecCounter = 1  
            SET @nCounter = @nCounter + 1         
         END    
         ELSE    
         BEGIN    
            SET @nRecCounter = @nRecCounter + 1    
         END    
      END    
               
      SELECT @nRecCnt = count(DISTINCT Orderkey)   
      FROM rdt.rdtQCInquiryLog WITH (NOLOCK)    
      WHERE UserID = @cUserName and Mobile = @nMobile and DropID = @cToteNo       
          
          
      SELECT DISTINCT @nTotRecCnt = Count(1)   
      FROM rdt.rdtQCInquiryLog WITH (NOLOCK)    
      WHERE UserID = @cUserName and Mobile = @nMobile and DropID = @cToteNo and Orderkey = @cOrderkey    
          
      SELECT @nSOHQty = SUM(Qty)   
      FROM dbo.SKUxLoc SL WITH (NOLOCK)    
      INNER JOIN LOC LOC WITH (NOLOCK) ON Loc.Loc = SL.Loc    
      WHERE SL.SKU = @cSKU    
      AND LOC.LocationType = 'PICK'    
          
      IF @nSOHQty = 0    
      BEGIN    
          SET @cSOHAvailable = 'No'    
      END      
      ELSE    
      BEGIN    
         SET @cSOHAvailable = 'Yes'    
      END    
     
      SELECT @nQtyPicked = QtyPicked,  
             @nQtyAllocated = QtyAllocated,  
             @nSPQty = QtyShortPick   
      FROM rdt.rdtQCInquiryLog WITH (NOLOCK)    
      WHERE Orderkey = @cOrderkey     
        AND SKU = @cSKU    
        AND UserID = @cUserName   

     -- (james01)
     SELECT @nQtyPacked = ISNULL(SUM(PD.Qty), 0) 
      FROM dbo.PackDetail PD WITH (NOLOCK)      
      JOIN dbo.packHeader PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
      WHERE PH.StorerKey = @cStorerKey      
         AND PH.OrderKey = @cOrderkey      
         AND PD.SKU = @cSKU

      SET @cPrevOrderkey = @cOrderkey              
            
      --prepare next screen variable              
      SET @cOutField01 = @cPickMethod     
      SET @cOutField02 = RTRIM(CAST(@nCounter AS NVARCHAR( 5))) + '/' + CAST(@nRecCnt AS NVARCHAR( 5))      
      SET @cOutField03 = @cOrderkey    
      SET @cOutField04 = @nQtyAllocated   
      SET @cOutField05 = @nQtyPicked    
      SET @cOutField06 = ISNULL(RTRIM(@cReasonkey),'')    
      SET @cOutField07 = @nSPQty    
      SET @cOutField08 = RTRIM(CAST(@nRecCounter AS NVARCHAR( 5))) + '/' + CAST(@nTotRecCnt AS NVARCHAR( 5))      
      SET @cOutField09 = @cSKU     
      SET @cOutField10 = ISNULL(LEFT(RTRIM(@cLoc), 20), '')              
      SET @cOutField11 = CAST(@nSOHQty AS INT)              
      SET @cOutField12 = @cSOHAvailable     
      SET @cOutfield13 = ''             
      SET @cOutfield14 = @nQtyPacked  -- (james01)
          
      QCOption:    
    
      EXEC rdt.rdtSetFocusField @nMobile, 1   
      IF @cQCOption = '1'    
      BEGIN    
         -- Get total record      
         SET @nTotalRec = 0      
         --    Performance tuning  (James01)      
         --    Either LOC/ID/SKU, so break it into 3 statement and eliminate the CASE      
               
         SELECT @nTotalRec = COUNT( 1)      
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)      
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)      
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)      
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)      
         WHERE LLI.StorerKey = @cStorerKey      
            AND LOC.Facility = @cFacility      
            AND (LLI.QTY - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) ) > 0      
            AND LLI.SKU = @cSKU      
            
         IF @nTotalRec = 0      
         BEGIN      
            SET @nErrNo = 71224      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No record'      
            EXEC rdt.rdtSetFocusField @nMobile, 1      
            GOTO Step_4_Fail      
         END      
            
      -- Get stock info      
      -- Performance tuning  (James01)      
      -- Either LOC/ID/SKU, so break it into 3 statement and eliminate the CASE      
         BEGIN      
            SET @nMQTY_Alloc = 0      
            SET @nMQTY_Avail = 0      
            SET @nMQTY_Hold = 0 
            SET @nMQTY_TTL = 0
            SET @nMQty_RPL=0
            SET @nMQty_Pick=0
            --SET @cPUOM_Desc = ''      
            SET @nPQTY_Alloc = 0      
            SET @nPQTY_Avail = 0      
            SET @nPQTY_Hold = 0 
            SET @nPQTY_TTL = 0
            SET @nPQty_RPL=0
            SET @nPQty_Pick=0
            --SET @cMUOM_Desc=''
            
                        
            SELECT TOP 1      
               @cLOT = LLI.LOT,      
               @cAltLOC = LLI.LOC,      
               @cID = LLI.ID,      
               @cSKU = LLI.SKU,      
               @cSKUDescr = SKU.Descr,      
               @cMUOM_Desc = Pack.PackUOM3,       
               @cPUOM_Desc =       
                  CASE @cPUOM      
                     WHEN '2' THEN Pack.PackUOM1 -- Case      
                     WHEN '3' THEN Pack.PackUOM2 -- Inner pack      
                     WHEN '6' THEN Pack.PackUOM3 -- Master unit      
                     WHEN '1' THEN Pack.PackUOM4 -- Pallet      
                     WHEN '4' THEN Pack.PackUOM8 -- Other unit 1      
                     WHEN '5' THEN Pack.PackUOM9 -- Other unit 2      
                  END,       
               @nMQTY_Alloc = LLI.QTYAllocated,      
               @nMQTY_Pick  = LLI.QTYPicked,
               @nMQTY_Avail = LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),      
               @nPUOM_Div = CAST( IsNULL(       
               CASE @cPUOM      
                     WHEN '2' THEN Pack.CaseCNT      
                     WHEN '3' THEN Pack.InnerPack      
                     WHEN '6' THEN Pack.QTY      
                     WHEN '1' THEN Pack.Pallet      
                     WHEN '4' THEN Pack.OtherUnit1      
                     WHEN '5' THEN Pack.OtherUnit2      
                  END, 1) AS INT),       
               @cLottable01 = LA.Lottable01,      
               @cLottable02 = LA.Lottable02,      
               @cLottable03 = LA.Lottable03,      
               @cLottable04 = LA.Lottable04,       
               @cLottable05 = LA.Lottable05,
               @nMQty_TTL = LLI.Qty,        -- (james02)
               @nMQty_RPL = CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END    -- (james02)      
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
               INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)      
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)      
               INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)      
               INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)      
            WHERE LLI.StorerKey = @cStorerKey      
               AND LOC.Facility = @cFacility      
               AND (LLI.QTY - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0      
               AND LLI.SKU = @cSKU      
            ORDER BY LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT -- Needed for looping      
            
            -- (Vicky01) - Start      
            SET @nMQTY_Hold = 0      
         
            IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)      
                       WHERE LOC = @cAltLOC AND Facility = @cFacility AND LocationFlag = 'HOLD')      
            BEGIN      
               SELECT @nMQTY_Hold = SUM(LLI.QTY)      
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
               WHERE LLI.StorerKey = @cStorerKey      
                AND  LLI.SKU = @cSKU      
                AND  LLI.LOC = @cAltLOC      
                AND  LLI.LOT = @cLOT      
                AND  LLI.ID = @cID      
            END      
            ELSE IF EXISTS (SELECT 1 FROM dbo.InventoryHold WITH (NOLOCK)      
                            WHERE LOT = @cLOT AND Hold = '1')      
            BEGIN      
               SELECT @nMQTY_Hold = SUM(LLI.QTY)      
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
               WHERE LLI.StorerKey = @cStorerKey      
                  AND  LLI.SKU = @cSKU      
                  AND  LLI.LOC = @cAltLOC      
                  AND  LLI.LOT = @cLOT      
                  AND  LLI.ID = @cID      
            END      
            ELSE IF EXISTS (SELECT 1 FROM dbo.ID WITH (NOLOCK)      
                            WHERE ID = @cID AND Status = 'HOLD')      
            BEGIN      
                SELECT @nMQTY_Hold = SUM(LLI.QTY)      
                FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
                WHERE LLI.StorerKey = @cStorerKey      
                 AND  LLI.SKU = @cSKU      
                 AND  LLI.LOC = @cAltLOC      
                 AND  LLI.LOT = @cLOT      
                 AND  LLI.ID = @cID      
            END        
          
            SET @nMQTY_Avail = @nMQTY_Avail - @nMQTY_Hold      
            -- (Vicky01) - End      
         END      
                  
         -- Validate if any result      
         IF @@ROWCOUNT = 0      
         BEGIN      
            SET @nErrNo = 71225    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No record'      
            EXEC rdt.rdtSetFocusField @nMobile, 3      
            GOTO Step_4_Fail      
         END      
            
         -- Convert to prefer UOM QTY      
         IF @cPUOM = '6' OR -- When preferred UOM = master unit       
            @nPUOM_Div = 0 -- UOM not setup      
         BEGIN      
            SET @cPUOM_Desc = ''      
            SET @nPQTY_Alloc = 0      
            SET @nPQTY_Avail = 0      
            SET @nPQTY_Hold = 0  

            -- Calc the remaining in master unit      
            SET @nPQTY_TTL = 0      
            SET @nPQTY_Pick = 0      
            SET @nPQTY_RPL =  0     
               
         END      
         ELSE      
         BEGIN      
            -- Calc QTY in preferred UOM      
            SET @nPQTY_Avail = @nMQTY_Avail / @nPUOM_Div      
            SET @nPQTY_Alloc = @nMQTY_Alloc / @nPUOM_Div      
            SET @nPQTY_Hold  = @nMQTY_Hold  / @nPUOM_Div
            SET @nPQTY_TTL   = @nMQty_TTL   / @nPUOM_Div     
            SET @nPQTY_Pick  = @nMQTY_Pick  / @nPUOM_Div
            SET @nPQTY_RPL   = @nMQty_RPL   / @nPUOM_Div
                  
            -- Calc the remaining in master unit      
            SET @nMQTY_Avail = @nMQTY_Avail % @nPUOM_Div      
            SET @nMQTY_Alloc = @nMQTY_Alloc % @nPUOM_Div      
            SET @nMQTY_Hold =  @nMQTY_Hold  % @nPUOM_Div     
            SET @nMQTY_TTL   = @nMQty_TTL   % @nPUOM_Div
            SET @nMQTY_Pick  = @nMQTY_Pick  % @nPUOM_Div
            SET @nMQTY_RPL   = @nMQty_RPL   % @nPUOM_Div
         END      

         -- Prep next screen var      
         SET @nCurrentRec = 1      
         SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))      
         SET @cOutField02 = @cSKU      
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)      
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)      
         SET @cOutField05 = @cAltLOC      
         SET @cOutField06 = @cID      
--         IF @cPUOM_Desc = ''      
--         BEGIN      
--            SET @cOutField07 = '' -- @cPUOM_Desc      
--            SET @cOutField08 = '' -- @nPQTY_Alloc      
--            SET @cOutField09 = '' -- @nPQTY_Avail      
--         END      
--         ELSE      
--         BEGIN      
--            SET @cOutField07 = @cPUOM_Desc      
--            SET @cOutField08 = CAST( @nPQTY_Avail AS NVARCHAR( 5))      
--            SET @cOutField09 = CAST( @nPQTY_Alloc AS NVARCHAR( 5))      
--            SET @cOutField13 = CAST( @nPQTY_Hold  AS NVARCHAR( 5))      
--         END      
--         SET @cOutField10 = @cMUOM_Desc      
--         SET @cOutField11 = CAST( @nMQTY_Avail AS NVARCHAR( 5))      
--         SET @cOutField12 = CAST( @nMQTY_Alloc AS NVARCHAR( 5))      
--         SET @cOutField14 = CAST( @nMQTY_Hold  AS NVARCHAR( 5))     
         SET @cOutField07 = CASE WHEN @cPUOM_Desc <> '' 
                   THEN @cPUOM_Desc + ' ' + @cMUOM_Desc 
                   ELSE SPACE( 6) + @cMUOM_Desc END 
         SET @cOutField08 = CASE WHEN @cPUOM_Desc <> '' 
                   THEN LEFT( CAST( @nPQTY_TTL AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_TTL AS NVARCHAR( 5)) 
                   ELSE SPACE( 6) + CAST( @nMQTY_TTL   AS NVARCHAR( 5)) END -- (james02)
         SET @cOutField09 = CASE WHEN @cPUOM_Desc <> '' 
                   THEN LEFT( CAST( @nPQTY_Hold AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Hold AS NVARCHAR( 5)) 
                   ELSE SPACE( 6) + CAST( @nMQTY_Hold  AS NVARCHAR( 5)) END -- (Vicky01)
         SET @cOutField10 = CASE WHEN @cPUOM_Desc <> '' 
                   THEN LEFT( CAST( @nPQTY_Alloc AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Alloc AS NVARCHAR( 5)) 
                   ELSE SPACE( 6) + CAST( @nMQTY_Alloc AS NVARCHAR( 5)) END
         SET @cOutField11 = CASE WHEN @cPUOM_Desc <> '' 
                   THEN LEFT( CAST( @nPQTY_Pick AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Pick AS NVARCHAR( 5)) 
                   ELSE SPACE( 6) + CAST( @nMQTY_Pick AS NVARCHAR( 5)) END
         SET @cOutField12 = CASE WHEN @cPUOM_Desc <> '' 
                   THEN LEFT( CAST( @nPQTY_RPL AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_RPL AS NVARCHAR( 5)) 
                   ELSE SPACE( 6) + CAST( @nMQTY_RPL   AS NVARCHAR( 5)) END -- (james02)
         SET @cOutField13 = CASE WHEN @cPUOM_Desc <> '' 
                   THEN LEFT( CAST( @nPQTY_Avail AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5))
                   ELSE SPACE( 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5)) END 

            
          -- GOTO SKU Inquiry Screen      
         SET @nFromScn = 2563    
         SET @nFromStep = 4    
           
         SET @nScn = 2568      
         SET @nStep = 9    
         GOTO QUIT            
      END    
          
    
      IF @cQCOption = '9'    
      BEGIN  
         IF @nSPQty = 0   
         BEGIN  
            SET @nErrNo = 71241    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'71241^No Short Pick'      
            EXEC rdt.rdtSetFocusField @nMobile, 3      
            GOTO Step_4_Fail                 
         END  
           
         IF @cPickMethod = 'CASE'   
         BEGIN  
            SET @nErrNo = 71242    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'71242^Opt Not Allow      
            EXEC rdt.rdtSetFocusField @nMobile, 3      
            GOTO Step_4_Fail                 
         END  
            
                
         SET @nScanQty = 0    
         SET @cOutField01 = ''  
         SET @cOutField07 = @cToteNo  
         SET @cOutField02 = ''   
         SET @cOutField08 = ISNULL(LEFT(RTRIM(@cLoc), 20), '')     
         SET @cOutField03 = @cSKU    
         SET @cOutField04 = ''    
         SET @cOutField05 = RTRIM(CAST(@nScanQty AS NVARCHAR( 5))) + '/' + CAST((@nQtyAllocated - @nQtyPicked) AS NVARCHAR( 5)) --@nScanQty / @nQtyAllocated - @nQtyPicked    
         SET @cOutField06 = ''  
            
        -- GOTO Resolve QC Screen           
        SET @nScn = @nScn + 1      
        SET @nStep =@nStep + 1    
        GOTO QUIT      
      END  -- @cQCOption=9 
    
      SET @nScn = @nScn     
      SET @nStep = @nStep  
           
      GOTO QUIT  
   END              
              
   IF @nInputKey = 0 -- ESC              
   BEGIN  
  
      SET @cOutField01 = @cToteNo              
      SET @cOutField02 = @cManifestPrinted              
      SET @cOutField03 = @cDropIDShipped    
      SET @cOutField04 = @cLastUser               
      SET @cOutField05 = @cLastZone              
      SET @cOutField06 = @cNextZone          
      SET @cOutField07 = @cFinalZone     
      SET @cOutField08 = @cReason  
      SET @cOutField09 = ''              
      SET @cOutField10 = ''              
      SET @cOutField11 = ''          
              
      SET @cOrderKey      = ''              
      SET @cConsigneekey  = ''              
      SET @cSKU           = ''              
      SET @cSKUDescr      = ''              
      SET @cPackUOM03     = ''              
      SET @cWCSKey        = ''              
      SET @cTaskDetailKey = ''              
      SET @cLoadkey       = ''              
      SET @cPrevOrderKey  = ''              
      SET @cCompany1      = ''              
      SET @cCompany2      = ''              
      SET @nOrdQty        = 0              
      SET @nActQty        = 0              
      SET @cOrgPltDropID  = ''
      SET @cTaskDetailKey = ''                
              
    SET @nScn = @nScn - 1              
    SET @nStep = @nStep - 1              
   END              
   GOTO Quit        
    
   Step_4_Fail:              
   BEGIN              
      SET @cOutField01 = @cPickMethod     
      SET @cOutField02 = RTRIM(CAST(@nCounter AS NVARCHAR( 5))) + '/' + CAST(@nRecCnt AS NVARCHAR( 5))      
      SET @cOutField03 = @cOrderkey    
      SET @cOutField04 = @nQtyAllocated    
      SET @cOutField05 = @nQtyPicked    
      SET @cOutField06 = ISNULL(RTRIM(@cReasonkey),'')    
      SET @cOutField07 = @nQtyAllocated - @nQtyPicked    
      SET @cOutField08 = RTRIM(CAST(@nRecCounter AS NVARCHAR( 5))) + '/' + CAST(@nTotRecCnt AS NVARCHAR( 5))      
      SET @cOutField09 = @cSKU     
      SET @cOutField10 = ISNULL(LEFT(RTRIM(@cLoc), 20), '')              
      SET @cOutField11 = CAST(@nSOHQty AS INT)              
      SET @cOutField12 = @cSOHAvailable     
      SET @cOutField13 = ''     
      SET @cOutField14 = @nQtyPacked  -- (james01)
   END        
             
END              
GOTO Quit        
    
            
/********************************************************************************            
Step 5. screen = 2564             
  info screen            
********************************************************************************/            
Step_5:            
BEGIN            
   IF @nInputKey = 1 -- ENTER            
   BEGIN       
      SET @cQCOption = ''    
      SET @cQCOption = ISNULL(@cInField06,'')    
        
      SET @cScannedSKU = ''    
      SET @cScannedSKU = ISNULL(@cInField04,'')    
        
      SET @cInTote = ''  
      SET @cInTote = ISNULL(@cInField01,'')       
        
      SET @cInLoc = ''  
      SET @cInLoc = ISNULL(@cInField02,'')     
        
      IF @cInTote = ''  
      BEGIN  
         SET @nErrNo = 71234              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropID Req'              
         GOTO Step_5_Fail    
      END  
        
      IF @cInLoc = ''  
      BEGIN  
         SET @nErrNo = 71235             
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Loc Req'              
         GOTO Step_5_Fail    
      END  
        
      IF @cInLoc <> @cLoc  
      BEGIN  
         IF NOT EXISTS (SELECT 1 FROM dbo.Loc WITH (NOLOCK)   
                        WHERE LOC = @cInLoc   
                        AND Facility = @cFacility  
                        AND LocationType <> 'QC' )  
         BEGIN  
               SET @nErrNo = 71236             
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Loc'              
               GOTO Step_5_Fail  
         END  
      END  
    
      IF ISNULL(@cQCOption,'') <> ''    
      BEGIN    
         IF ISNULL(RTRIM(@cQCOption), '') <> '1' AND ISNULL(RTRIM(@cQCOption), '') <> '9'  AND ISNULL(RTRIM(@cQCOption), '') <> '5'           
         BEGIN              
            SET @nErrNo = 71222              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'              
            GOTO Step_5_Fail              
         END      
      END      
     
      IF ISNULL(@cQCOption,'') <> ''    
      BEGIN    
         GOTO QCOptionStep_5    
      END    
        
      IF ISNULL(RTRIM(@cScannedSKU),'') = ''   
      BEGIN  
         SET @nErrNo = 71230              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU Req'              
         GOTO Step_5_Fail    
      END  
        
      IF @cScannedSKU <> @cSKU  
      BEGIN  
         SET @nErrNo = 71231              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'              
         GOTO Step_5_Fail    
      END  
        
      IF @nScanQty + 1 > @nSPQty   
      BEGIN  
         SET @nErrNo = 71232             
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Qty>Expected'              
         GOTO Step_5_Fail    
      END  
          
      SET @nScanQty = @nScanQty + 1
        
      SET @cOutField05 = RTRIM(CAST(@nScanQty AS NVARCHAR( 5))) + '/' + CAST((@nSPQty) AS NVARCHAR( 5)) --@nScanQty / @nQtyAllocated - @nQtyPicked    
      EXEC rdt.rdtSetFocusField @nMobile, 4   
          
      QCOptionStep_5:    
    
      IF @cQCOption = '1'    
      BEGIN    
        IF @cToteNo = @cInTote   
        BEGIN  
           SET @cPickMethod = ''  
           SELECT @cPickMethod = DropIDType   
           FROM dbo.DropID WITH (NOLOCK)    
           WHERE DropID = @cToteNo   
  
           -- Confirm Pick --  
           EXECUTE RDT.rdt_Tote_QC_Inquiry_Confirm             
            @nMobile,             
            @nFunc,               
            @cStorerKey,            
            @cUserName,            
            @cFacility,    
            @cOrderkey,          
            @cTaskDetailKey, 
            @cSKU,            
            @cLoc,            
            @cToteNo,            
            @nScanQty,   
            '5',            
            @cLangCode,            
            @nErrNo OUTPUT,   
            @cErrMsg OUTPUT,            
            @cPickMethod            
                         
            IF @nErrNo <> 0            
            BEGIN            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')             
               GOTO Step_5_Fail             
            END     
                   
           -- GOTO QC Confirm Screen          
           SET @nScn = @nScn + 1    
           SET @nStep =@nStep + 1    
           GOTO QUIT  
        END  
        ELSE  
        BEGIN  
           -- GOTO New Tote Confirm Screen     
           SET @cToteNo = @cInTote       
  
           SET @nScn = 2566  
           SET @nStep = 7  
           GOTO QUIT    
        END  
      END -- Option=1
        
      IF @cQCOption = '5'    
      BEGIN    
         -- Get total record      
         SET @nTotalRec = 0      
         --    Performance tuning  (James01)      
         --    Either LOC/ID/SKU, so break it into 3 statement and eliminate the CASE      
         
         SELECT @nTotalRec = COUNT( 1)      
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)      
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)      
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)      
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)      
         WHERE LLI.StorerKey = @cStorerKey      
            AND LOC.Facility = @cFacility      
            AND (LLI.QTY - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) ) > 0      
            AND LLI.SKU = @cSKU      
                
               
            IF @nTotalRec = 0      
            BEGIN      
               SET @nErrNo = 71228      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No record'      
               EXEC rdt.rdtSetFocusField @nMobile, 1      
               GOTO Step_5_Fail      
            END      
            
            -- Get stock info      
      --    Performance tuning  (James01)      
      --    Either LOC/ID/SKU, so break it into 3 statement and eliminate the CASE      
            BEGIN      
               SELECT TOP 1      
                  @cLOT = LLI.LOT,      
                  @cAltLOC = LLI.LOC,      
                  @cID = LLI.ID,      
                  @cSKU = LLI.SKU,      
                  @cSKUDescr = SKU.Descr,      
                  @cMUOM_Desc = Pack.PackUOM3,       
                  @cPUOM_Desc =       
                     CASE @cPUOM      
                        WHEN '2' THEN Pack.PackUOM1 -- Case      
                        WHEN '3' THEN Pack.PackUOM2 -- Inner pack      
                        WHEN '6' THEN Pack.PackUOM3 -- Master unit      
                        WHEN '1' THEN Pack.PackUOM4 -- Pallet      
                        WHEN '4' THEN Pack.PackUOM8 -- Other unit 1      
                        WHEN '5' THEN Pack.PackUOM9 -- Other unit 2      
                     END,       
                  @nMQTY_Alloc = LLI.QTYAllocated,      
                  @nMQTY_Pick  = LLI.QTYPicked,
                  @nMQTY_Avail = LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),      
                  @nPUOM_Div = CAST( IsNULL(       
                  CASE @cPUOM      
                        WHEN '2' THEN Pack.CaseCNT      
                        WHEN '3' THEN Pack.InnerPack      
                        WHEN '6' THEN Pack.QTY      
                        WHEN '1' THEN Pack.Pallet      
                        WHEN '4' THEN Pack.OtherUnit1      
                        WHEN '5' THEN Pack.OtherUnit2      
                     END, 1) AS INT),       
                  @cLottable01 = LA.Lottable01,      
                  @cLottable02 = LA.Lottable02,      
                  @cLottable03 = LA.Lottable03,      
                  @cLottable04 = LA.Lottable04,       
                  @cLottable05 = LA.Lottable05, 
                  @nMQty_TTL = LLI.Qty,        -- (james02)
                  @nMQty_RPL = CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END    -- (james02)      
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
                  INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)      
                  INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)      
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)      
                  INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)      
               WHERE LLI.StorerKey = @cStorerKey      
                  AND LOC.Facility = @cFacility      
                  AND (LLI.QTY - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0      
                  AND LLI.SKU = @cSKU      
               ORDER BY LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT -- Needed for looping      
            
               -- (Vicky01) - Start      
               SET @nMQTY_Hold = 0      
            
               IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)      
                          WHERE LOC = @cAltLOC AND Facility = @cFacility AND LocationFlag = 'HOLD')      
               BEGIN      
                 SELECT @nMQTY_Hold = SUM(LLI.QTY)      
                 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
                 WHERE LLI.StorerKey = @cStorerKey      
                  AND  LLI.SKU = @cSKU      
                  AND  LLI.LOC = @cAltLOC      
                  AND  LLI.LOT = @cLOT      
                  AND  LLI.ID = @cID      
               END      
               ELSE IF EXISTS (SELECT 1 FROM dbo.InventoryHold WITH (NOLOCK)      
                               WHERE LOT = @cLOT AND Hold = '1')      
               BEGIN      
                 SELECT @nMQTY_Hold = SUM(LLI.QTY)      
                 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
                 WHERE LLI.StorerKey = @cStorerKey      
                  AND  LLI.SKU = @cSKU      
                  AND  LLI.LOC = @cAltLOC      
                  AND  LLI.LOT = @cLOT      
                  AND  LLI.ID = @cID      
               END      
               ELSE IF EXISTS (SELECT 1 FROM dbo.ID WITH (NOLOCK)      
                               WHERE ID = @cID AND Status = 'HOLD')      
               BEGIN      
                 SELECT @nMQTY_Hold = SUM(LLI.QTY)      
                 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
                 WHERE LLI.StorerKey = @cStorerKey      
                  AND  LLI.SKU = @cSKU      
                  AND  LLI.LOC = @cAltLOC      
                  AND  LLI.LOT = @cLOT      
                  AND  LLI.ID = @cID      
                END        
            
                SET @nMQTY_Avail = @nMQTY_Avail - @nMQTY_Hold      
               -- (Vicky01) - End      
            END      
                  
            -- Validate if any result      
            IF @@ROWCOUNT = 0      
            BEGIN      
               SET @nErrNo = 71229    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No record'      
               EXEC rdt.rdtSetFocusField @nMobile, 3      
               GOTO Step_5_Fail      
            END      
            
            -- Convert to prefer UOM QTY      
            IF @cPUOM = '6' OR -- When preferred UOM = master unit       
               @nPUOM_Div = 0 -- UOM not setup      
            BEGIN      
               SET @cPUOM_Desc = ''      
               SET @nPQTY_Alloc = 0      
               SET @nPQTY_Avail = 0      
               SET @nPQTY_Hold = 0     
               SET @nPQTY_TTL = 0 -- (james02)
               SET @nPQTY_RPL = 0 -- (james02)
               SET @nMQTY_Pick = 0 -- (james02)
            END      
            ELSE      
            BEGIN      
               -- Calc QTY in preferred UOM      
               SET @nPQTY_Avail = @nMQTY_Avail / @nPUOM_Div      
               SET @nPQTY_Alloc = @nMQTY_Alloc / @nPUOM_Div      
               SET @nPQTY_Hold  = @nMQTY_Hold / @nPUOM_Div     
               SET @nPQTY_TTL   = @nMQTY_TTL / @nPUOM_Div  -- (james02)
               SET @nPQTY_RPL   = @nMQTY_RPL / @nPUOM_Div  -- (james02)
               SET @nPQTY_Pick  = @nMQTY_Pick / @nPUOM_Div  -- (james02)
                     
               -- Calc the remaining in master unit      
               SET @nMQTY_Avail = @nMQTY_Avail % @nPUOM_Div      
               SET @nMQTY_Alloc = @nMQTY_Alloc % @nPUOM_Div      
               SET @nMQTY_Hold =  @nMQTY_Hold  % @nPUOM_Div     
               SET @nMQTY_TTL   = @nMQTY_Alloc % @nPUOM_Div  -- (james02)
               SET @nMQTY_RPL   = @nMQTY_Hold % @nPUOM_Div   -- (james02)
               SET @nMQTY_Pick  = @nMQTY_Pick % @nPUOM_Div   -- (james02)
            END      
            
            -- Prep next screen var      
            SET @nCurrentRec = 1      
            SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))      
            SET @cOutField02 = @cSKU      
            SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)      
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)      
            SET @cOutField05 = @cAltLOC      
            SET @cOutField06 = @cID      
            --SET @cOutField07 = @cPUOM_Desc      
            --SET @cOutField08 = CAST( @nPQTY_Avail AS NVARCHAR( 5))      
            --SET @cOutField09 = CAST( @nPQTY_Alloc AS NVARCHAR( 5))      
            --SET @cOutField13 = CAST( @nPQTY_Hold  AS NVARCHAR( 5))      
            SET @cOutField07 = CASE WHEN @cPUOM_Desc <> '' 
                      THEN @cPUOM_Desc + ' ' + @cMUOM_Desc 
                      ELSE SPACE( 6) + @cMUOM_Desc END 
            SET @cOutField08 = CASE WHEN @cPUOM_Desc <> '' 
                      THEN LEFT( CAST( @nPQTY_TTL AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_TTL AS NVARCHAR( 5)) 
                      ELSE SPACE( 6) + CAST( @nMQTY_TTL   AS NVARCHAR( 5)) END -- (james02)
            SET @cOutField09 = CASE WHEN @cPUOM_Desc <> '' 
                      THEN LEFT( CAST( @nPQTY_Hold AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Hold AS NVARCHAR( 5)) 
                      ELSE SPACE( 6) + CAST( @nMQTY_Hold  AS NVARCHAR( 5)) END -- (Vicky01)
            SET @cOutField10 = CASE WHEN @cPUOM_Desc <> '' 
                      THEN LEFT( CAST( @nPQTY_Alloc AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Alloc AS NVARCHAR( 5)) 
                      ELSE SPACE( 6) + CAST( @nMQTY_Alloc AS NVARCHAR( 5)) END
            SET @cOutField11 = CASE WHEN @cPUOM_Desc <> '' 
                      THEN LEFT( CAST( @nPQTY_Pick AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Pick AS NVARCHAR( 5)) 
                      ELSE SPACE( 6) + CAST( @nMQTY_Pick AS NVARCHAR( 5)) END
            SET @cOutField12 = CASE WHEN @cPUOM_Desc <> '' 
                      THEN LEFT( CAST( @nPQTY_RPL AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_RPL AS NVARCHAR( 5)) 
                      ELSE SPACE( 6) + CAST( @nMQTY_RPL   AS NVARCHAR( 5)) END -- (james02)
            SET @cOutField13 = CASE WHEN @cPUOM_Desc <> '' 
                      THEN LEFT( CAST( @nPQTY_Avail AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5))
                      ELSE SPACE( 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5)) END 
            --SET @cOutField10 = @cMUOM_Desc      
            --SET @cOutField11 = CAST( @nMQTY_Avail AS NVARCHAR( 5))      
            --SET @cOutField12 = CAST( @nMQTY_Alloc AS NVARCHAR( 5))      
            --SET @cOutField14 = CAST( @nMQTY_Hold  AS NVARCHAR( 5))     
               
    
            -- GOTO SKU Inquiry Screen      
           SET @nFromScn = 2564    
           SET @nFromStep = 5    
           
           SET @nScn = 2568      
           SET @nStep = 9    
           GOTO QUIT            
      END -- Option=5       
    
      IF @cQCOption = '9'    
      BEGIN    
           -- GOTO Short Pick Confirm      
           SET @cOutField01 = @cSKU    
           SET @cOutField02 = ''    
           SET @cOutField03 = ''    
      
           SET @nScn = 2567    
           SET @nStep = 8    
           GOTO QUIT      
      END    
          
        
      SET @cOutField01 = @cInTote  
      SET @cOutField02 = @cLoc 
  
      SET @nScn = @nScn          
      SET @nStep = @nStep   
                
   END            
            
   IF @nInputKey = 0 -- ESC            
   BEGIN      
    
      SELECT TOP 1     
       @cPickMethod     = DropIDType     
      ,@nQtyAllocated   = QtyAllocated    
      ,@cReasonkey      = Reasonkey
      ,@cTaskDetailKey  = TaskDetailKey     
      FROM rdt.rdtQCInquiryLog WITH (NOLOCK)    
      WHERE UserID = @cUserName and Mobile = @nMobile and DropID = @cToteNo     
      AND SKU = @cSKU    
      AND LOC = @cLoc    
      AND Orderkey = @cOrderkey    
      Order by Orderkey, SKU    
    
          
      SELECT @nSOHQty = SUM(Qty) FROM dbo.SKUxLoc SL WITH (NOLOCK)    
      INNER JOIN LOC LOC WITH (NOLOCK) ON Loc.Loc = SL.Loc    
      WHERE SL.SKU = @cSKU    
      AND LOC.LocationType = 'PICK'    
          
      IF @nSOHQty = 0    
      BEGIN    
          SET @cSOHAvailable = 'No'    
      END      
      ELSE    
      BEGIN    
         SET @cSOHAvailable = 'Yes'    
      END    
          
      SELECT @nQtyPicked = QtyPicked,  
             @nQtyAllocated = QtyAllocated,  
             @nSPQty = QtyShortPick   
      FROM rdt.rdtQCInquiryLog WITH (NOLOCK)    
      WHERE Orderkey = @cOrderkey     
        AND SKU = @cSKU    
        AND UserID = @cUserName  

     -- (james01)
     SELECT @nQtyPacked = ISNULL(SUM(PD.Qty), 0) 
      FROM dbo.PackDetail PD WITH (NOLOCK)      
      JOIN dbo.packHeader PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
      WHERE PH.StorerKey = @cStorerKey      
         AND PH.OrderKey = @cOrderkey      
         AND PD.SKU = @cSKU

      SET @cOutField01 = @cPickMethod     
      SET @cOutField02 = RTRIM(CAST(@nCounter AS NVARCHAR( 5))) + '/' + CAST(@nRecCnt AS NVARCHAR( 5))      
      SET @cOutField03 = @cOrderkey    
      SET @cOutField04 = @nQtyAllocated    
      SET @cOutField05 = @nQtyPicked    
      SET @cOutField06 = ISNULL(RTRIM(@cReasonkey),'')    
      SET @cOutField07 = @nSPQty --@nQtyAllocated - @nQtyPicked    
      SET @cOutField08 = RTRIM(CAST(@nRecCounter AS NVARCHAR( 5))) + '/' + CAST(@nTotRecCnt AS NVARCHAR( 5))      
      SET @cOutField09 = @cSKU     
      SET @cOutField10 = ISNULL(LEFT(RTRIM(@cLoc), 20), '')              
      SET @cOutField11 = CAST(@nSOHQty AS INT)              
      SET @cOutField12 = @cSOHAvailable      
      SET @cOutField13 = ''      
      SET @cOutField14 = @nQtyPacked
            
      SET @nScn = @nScn - 1            
      SET @nStep = @nStep - 1            
   END            
   GOTO Quit     
    
   Step_5_Fail:              
   BEGIN              
--      SET @cOutField01 = @cPickMethod     
--      SET @cOutField02 = RTRIM(CAST(@nCounter AS NVARCHAR( 5))) + '/' + CAST(@nRecCnt AS NVARCHAR( 5))   
        
            
--    SET @nScanQty = 0    
      SET @cOutField01 = @cToteNo    
      SET @cOutField02 = ISNULL(LEFT(RTRIM(@cLoc), 20), '')     
      SET @cOutField03 = @cSKU    
      SET @cOutField04 = ''    
      SET @cOutField05 = RTRIM(CAST(@nScanQty AS NVARCHAR( 5))) + '/' + CAST((@nSPQty) AS NVARCHAR( 5)) --@nScanQty / @nQtyAllocated - @nQtyPicked    
         
         
   END             
END            
GOTO Quit       
    
/********************************************************************************            
Step 6. screen = 2565             
  QC Confirm          
********************************************************************************/            
Step_6:            
BEGIN            
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER        / ESC    
   BEGIN            
          
      SET @cOutField01 = ''      
       
      SET @nScn = 2561         
      SET @nStep = 2          
   END            
            
END            
GOTO Quit      
    
/********************************************************************************            
Step 7. screen = 2566             
  New Tote / Case         
********************************************************************************/            
Step_7:            
BEGIN            
   IF @nInputKey = 1 -- ENTER            
   BEGIN            
           SET @cPickMethod = ''  
           SELECT @cPickMethod = DropIDType FROM dbo.DropID WITH (NOLOCK)    
           WHERE DropID = @cToteNo            
  
            -- Confirm Pick --  
           EXECUTE RDT.rdt_Tote_QC_Inquiry_Confirm             
            @nMobile,             
            @nFunc,               
            @cStorerKey,            
            @cUserName,            
            @cFacility,    
            @cOrderkey,          
            @cTaskDetailKey, 
            @cSKU,            
            @cLoc,            
            @cToteNo,            
            @nScanQty,   
            '5',            
            @cLangCode,            
            @nErrNo OUTPUT,   
            @cErrMsg OUTPUT,            
            @cPickMethod            
                         
            IF @nErrNo <> 0            
            BEGIN            
    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')             
               GOTO QUIT            
            END     
       
      SET @nScn = 2565   -- Confirm QC      
      SET @nStep = 6          
   END            
            
   IF @nInputKey = 0 -- ESC            
   BEGIN      
            
      SET @nScn = 2564 -- DropID, Loc, SKU    
      SET @nStep = 5          
   END            
   GOTO Quit            
END            
GOTO Quit      
    
/********************************************************************************            
Step 8. screen = 2567             
  Short Pick Confirm         
********************************************************************************/            
Step_8:            
BEGIN            
   IF @nInputKey = 1 -- ENTER            
   BEGIN         
       
      SET @cQCOption = ''    
      SET @cQCOption = ISNULL(@cInField03,'')       
    
      IF ISNULL(@cQCOption,'') <> ''    
      BEGIN    
         IF  ISNULL(RTRIM(@cQCOption), '') <> '9'         
         BEGIN              
            SET @nErrNo = 71223              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'              
            GOTO Step_8_Fail              
         END      
      END      
     
    
      IF @cQCOption = '9'    
      BEGIN    
           SET @cPickMethod = ''  
           SELECT @cPickMethod = DropIDType FROM dbo.DropID WITH (NOLOCK)    
           WHERE DropID = @cToteNo   
  
           --  Short Pick Confirm   
            -- Confirm Pick --  
           EXECUTE RDT.rdt_Tote_QC_Inquiry_Confirm             
            @nMobile,             
            @nFunc,               
            @cStorerKey,            
            @cUserName,            
            @cFacility,    
            @cOrderkey,    
            @cTaskDetailKey,      
            @cSKU,            
            @cLoc,            
            @cToteNo,            
            @nScanQty,            
            '4',            
            @cLangCode,            
            @nErrNo OUTPUT,   
            @cErrMsg OUTPUT,            
            @cPickMethod            
                         
            IF @nErrNo <> 0            
            BEGIN            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')             
               GOTO Step_8_Fail            
            END        
              
           -- Generate GM Task to TaskDetail --  
           EXECUTE dbo.nspg_getkey                   
            'TaskDetailKey'                  
            , 10                  
            , @cTaskDetailKeyPK OUTPUT                  
            , @b_success OUTPUT                  
            , @nErrNo OUTPUT                  
            , @cErrMsg OUTPUT                  
            
            IF NOT @b_success = 1                  
            BEGIN                  
               SET @nErrNo = @nErrNo            
               SET @cErrMsg = @cErrMsg            
               GOTO Step_8_Fail            
            END               
              
           BEGIN TRAN  
           SET @cStatusMSG = 'No Inventory for SKU ' + RTRIM(@cSKU) + ' at LOC ' + @cLoc -- (james03)
             
           INSERT INTO dbo.TaskDetail (TaskDetailKey, TaskType, Status, StatusMsg, StartTime, EndTime, StorerKey)  
           Values (@cTaskDetailKeyPK,'GM','0',@cStatusMSG, GetDate(), GetDate(), @cStorerKey)  -- (james02)
             
           IF @@ERROR <> 0            
           BEGIN            
                  SET @nErrNo = 71233            
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsTaskFailed'            
                  ROLLBACK TRAN             
                  GOTO Step_4_Fail             
           END            
           ELSE             
           BEGIN            
                  COMMIT TRAN             
           END    
             
             
           --  Confirm Short Pick    
           SET @cOutfield01 = ''   
             
              
      END    
    
      SET @nScn = 2570   -- Confirm SP     
      SET @nStep = 11           
   END       
            
   IF @nInputKey = 0 -- ESC            
   BEGIN      
      SET @cOutField01 = @cToteNo    
      SET @cOutField02 = ISNULL(LEFT(RTRIM(@cLoc), 20), '')     
      SET @cOutField03 = @cSKU    
      SET @cOutField04 = ''    
      SET @cOutField05 = RTRIM(CAST(@nScanQty AS NVARCHAR( 5))) + '/' + CAST((@nSPQty) AS NVARCHAR( 5)) --@nScanQty / @nQtyAllocated - @nQtyPicked    
      
      SET @nScn = 2564 -- DropID, Loc, SKU    
      SET @nStep = 5            
   END            
   GOTO Quit    
    
   Step_8_Fail:              
   BEGIN        
      SET @cOutField01 = @cSKU        
      SET @cOutField02 = ''     
      SET @cOutField03 = ''     
         
   END              
END            
GOTO Quit            
    
    
/********************************************************************************      
Step 9. Scn = 2568. Result screen      
   Counter    (field01)      
   SKU        (field02)      
   Desc1      (field03      
   Desc2      (field04)      
   LOC        (field05)      
   ID         (field06)      
   UOM        (field07, 10)      
   QTY AVL    (field08, 11)      
   QTY ALC    (field09, 12)      
   QTY HLD    (field13, 14)      
********************************************************************************/      
Step_9:      
BEGIN      
   IF @nInputKey = 1      -- Yes or Send      
   BEGIN      
--      IF @nCurrentRec = @nTotalRec      
--      BEGIN      
--         SET @cSKU = ''      
--         SET @cLOC = ''      
--         SET @cID = ''      
--         SET @cLOT = ''      
--         SET @nCurrentRec = 0      
--      END      
         
      -- Prepare next screen var      
--      SET @cOutField04 = RDT.rdtFormatDate( @dLottable04)      
--      SET @cOutField05 = RDT.rdtFormatDate( @dLottable05)      
      SET @cOutField01 = @cLottable01
      SET @cOutField02 = @cLottable02
      SET @cOutField03 = @cLottable03
      SET @cOutField04 = CASE WHEN ISNULL(@cLottable04, '') = '' THEN '' ELSE RDT.rdtFormatDate( @cLottable04) END 
      SET @cOutField05 = CASE WHEN ISNULL(@cLottable05, '') = '' THEN '' ELSE RDT.rdtFormatDate( @cLottable05) END 

      
      -- Go to next screen      
      SET @nScn = @nScn + 1      
      SET @nStep = @nStep + 1      
            
   END      
      
   IF @nInputKey = 0 -- Esc or No      
   BEGIN      
      -- Prepare prev screen var      
      SELECT TOP 1     
       @cPickMethod      = DropIDType     
      ,@nQtyAllocated   = QtyAllocated    
      ,@cReasonkey      = Reasonkey    
      FROM rdt.rdtQCInquiryLog WITH (NOLOCK)    
      WHERE UserID = @cUserName   
      AND Mobile = @nMobile   
      AND DropID = @cToteNo     
      AND SKU = @cSKU    
      AND LOC = @cLoc    
      AND Orderkey = @cOrderkey    
      Order by Orderkey, SKU    
    
          
      SELECT @nSOHQty = SUM(Qty) FROM dbo.SKUxLoc SL WITH (NOLOCK)    
      INNER JOIN LOC LOC WITH (NOLOCK) ON Loc.Loc = SL.Loc    
      WHERE SL.SKU = @cSKU    
      AND LOC.LocationType = 'PICK'    
          
      IF @nSOHQty = 0    
      BEGIN    
          SET @cSOHAvailable = 'No'    
      END      
      ELSE    
      BEGIN    
         SET @cSOHAvailable = 'Yes'    
      END    
          
          
      SELECT @nQtyPicked = QtyPicked,  
             @nQtyAllocated = QtyAllocated,  
             @nSPQty = QtyShortPick   
      FROM rdt.rdtQCInquiryLog WITH (NOLOCK)    
      WHERE Orderkey = @cOrderkey     
        AND SKU = @cSKU    
        AND UserID = @cUserName  

     -- (james01)
     SELECT @nQtyPacked = ISNULL(SUM(PD.Qty), 0) 
      FROM dbo.PackDetail PD WITH (NOLOCK)      
      JOIN dbo.packHeader PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
      WHERE PH.StorerKey = @cStorerKey      
         AND PH.OrderKey = @cOrderkey      
         AND PD.SKU = @cSKU

      SET @cOutField01 = @cPickMethod     
      SET @cOutField02 = RTRIM(CAST(@nCounter AS NVARCHAR( 5))) + '/' + CAST(@nRecCnt AS NVARCHAR( 5))      
      SET @cOutField03 = @cPrevOrderKey --@cOrderkey    
      SET @cOutField04 = @nQtyAllocated    
      SET @cOutField05 = @nQtyPicked    
      SET @cOutField06 = ISNULL(RTRIM(@cReasonkey),'')    
      SET @cOutField07 = @nSPQty    
      SET @cOutField08 = RTRIM(CAST(@nRecCounter AS NVARCHAR( 5))) + '/' + CAST(@nTotRecCnt AS NVARCHAR( 5))      
      SET @cOutField09 = @cSKU     
      SET @cOutField10 = ISNULL(LEFT(RTRIM(@cLoc), 20), '')              
      SET @cOutField11 = CAST(@nSOHQty AS INT)              
      SET @cOutField12 = @cSOHAvailable     
      SET @cOutField13 = ''     
      SET @cOutField14 = @nQtyPacked

      EXEC rdt.rdtSetFocusField @nMobile, 1      
      
      -- Go to prev screen      
      SET @nScn = @nFromScn    
      SET @nStep = @nFromStep      
   END      
END      
GOTO Quit      
    
/********************************************************************************      
Step 10. Scn = 2569. Result screen      
   LOTTABLE01 (field01)      
   LOTTABLE02 (field02)      
   LOTTABLE03 (field03)      
   LOTTABLE04 (field04)      
   LOTTABLE05 (field05)      
********************************************************************************/      
Step_10:      
BEGIN      
   IF @nInputKey = 1      -- Yes or Send      
   BEGIN      
      
      IF @nCurrentRec = @nTotalRec      
      BEGIN      
         --SET @cSKU = ''      
         SET @cAltLOC = @cLoc    
         SET @cID = ''      
         SET @cLOT = ''      
         SET @nCurrentRec = 0      
      END      
    
        
      
--    Performance tuning  (James01)      
--    Either LOC/ID/SKU, so break it into 3 statement and eliminate the CASE      
      BEGIN      
         SELECT TOP 1      
            @cLOT = LLI.LOT,      
            @cAltLOC = LLI.LOC,      
            @cID = LLI.[ID],      
            @cSKU = LLI.SKU,      
            @cSKUDescr = SKU.Descr,      
            @cMUOM_Desc = Pack.PackUOM3,       
            @cPUOM_Desc =       
               CASE @cPUOM      
                  WHEN '2' THEN Pack.PackUOM1 -- Case      
                  WHEN '3' THEN Pack.PackUOM2 -- Inner pack      
                  WHEN '6' THEN Pack.PackUOM3 -- Master unit      
                  WHEN '1' THEN Pack.PackUOM4 -- Pallet      
                  WHEN '4' THEN Pack.PackUOM8 -- Other unit 1      
                  WHEN '5' THEN Pack.PackUOM9 -- Other unit 2      
               END,       
            @nMQTY_Alloc = LLI.QTYAllocated,      
            @nMQTY_Pick  = LLI.QTYPicked,
            @nMQTY_Avail = LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),      
            @nPUOM_Div = CAST(       
               CASE @cPUOM      
                  WHEN '2' THEN Pack.CaseCNT      
                  WHEN '3' THEN Pack.InnerPack      
                  WHEN '6' THEN Pack.QTY      
                  WHEN '1' THEN Pack.Pallet      
                  WHEN '4' THEN Pack.OtherUnit1      
                  WHEN '5' THEN Pack.OtherUnit2      
               END AS INT),       
            @cLottable01 = LA.Lottable01,      
            @cLottable02 = LA.Lottable02,      
            @cLottable03 = LA.Lottable03,      
            @cLottable04 = LA.Lottable04,       
            @cLottable05 = LA.Lottable05,
            @nMQty_TTL = LLI.Qty,        -- (james02)
            @nMQty_RPL = CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END    -- (james02)            
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)      
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)               
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)      
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)      
         WHERE LLI.StorerKey = @cStorerKey      
            AND LOC.Facility = @cFacility      
            AND (LLI.QTY - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0      
            AND LLI.SKU  = @cSKU      
            AND  (RTRIM(LLI.SKU) + RTRIM(LLI.LOC) + RTRIM(LLI.ID) + RTRIM(LLI.LOT)) > (RTRIM(@cSKU) + RTRIM(@cAltLOC) + RTRIM(ISNULL(@cID,'')) +RTRIM(@cLOT)) -- next row      
         ORDER BY LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT      
         -- (Vicky01) - Start      
         SET @nMQTY_Hold = 0      
      
         IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)      
                    WHERE LOC = @cAltLOC AND Facility = @cFacility AND LocationFlag = 'HOLD')      
         BEGIN      
           SELECT @nMQTY_Hold = SUM(LLI.QTY)      
           FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
           WHERE LLI.StorerKey = @cStorerKey      
            AND  LLI.SKU = @cSKU      
            AND  LLI.LOC = @cAltLOC      
            AND  LLI.LOT = @cLOT      
            AND  LLI.ID = @cID      
         END      
         ELSE IF EXISTS (SELECT 1 FROM dbo.InventoryHold WITH (NOLOCK)      
                         WHERE LOT = @cLOT AND Hold = '1')      
         BEGIN      
           SELECT @nMQTY_Hold = SUM(LLI.QTY)      
           FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
           WHERE LLI.StorerKey = @cStorerKey      
            AND  LLI.SKU = @cSKU      
            AND  LLI.LOC = @cAltLOC      
            AND  LLI.LOT = @cLOT      
            AND  LLI.ID = @cID      
         END      
         ELSE IF EXISTS (SELECT 1 FROM dbo.ID WITH (NOLOCK)      
                         WHERE ID = @cID AND Status = 'HOLD')      
         BEGIN      
           SELECT @nMQTY_Hold = SUM(LLI.QTY)      
           FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
           WHERE LLI.StorerKey = @cStorerKey      
            AND  LLI.SKU = @cSKU      
            AND  LLI.LOC = @cAltLOC      
            AND  LLI.LOT = @cLOT      
            AND  LLI.ID = @cID      
          END        
      
          SET @nMQTY_Avail = @nMQTY_Avail - @nMQTY_Hold      
         -- (Vicky01) - End      
      END      
    
         
      -- Validate if any result      
      IF @@ROWCOUNT = 0      
      BEGIN      
         SET @nErrNo = 60684      
         SET @cErrMsg = rdt.rdtgetmessage( 60684, @cLangCode, 'DSP') --'No record'      
         EXEC rdt.rdtSetFocusField @nMobile, 3      
         GOTO Step_1_Fail      
      END      
      
     
    
      -- Convert to prefer UOM QTY      
      IF @cPUOM = '6' OR -- When preferred UOM = master unit       
         @nPUOM_Div = 0 -- UOM not setup      
      BEGIN      
         SET @cPUOM_Desc = ''      
         SET @nPQTY_Alloc = 0      
         SET @nPQTY_Avail = 0      
         SET @nPQTY_Hold  = 0     
         SET @nPQTY_TTL = 0 -- (james02)
         SET @nPQTY_RPL = 0 -- (james02)
         SET @nMQTY_Pick = 0 -- (james02)
      END      
      ELSE      
      BEGIN      
         -- Calc QTY in preferred UOM      
         SET @nPQTY_Avail = @nMQTY_Avail / @nPUOM_Div      
         SET @nPQTY_Alloc = @nMQTY_Alloc / @nPUOM_Div      
         SET @nPQTY_Hold  = @nMQTY_Hold / @nPUOM_Div     

         SET @nPQTY_TTL   = @nMQTY_TTL / @nPUOM_Div  -- (james02)
         SET @nPQTY_RPL   = @nMQTY_RPL / @nPUOM_Div  -- (james02)
         SET @nPQTY_Pick  = @nMQTY_Pick / @nPUOM_Div  -- (james02)
               
         -- Calc the remaining in master unit      
         SET @nMQTY_Avail = @nMQTY_Avail % @nPUOM_Div      
         SET @nMQTY_Alloc = @nMQTY_Alloc % @nPUOM_Div      
         SET @nMQTY_Hold  = @nMQTY_Hold  % @nPUOM_Div

         SET @nMQTY_TTL   = @nMQTY_Alloc % @nPUOM_Div  -- (james02)
         SET @nMQTY_RPL   = @nMQTY_Hold % @nPUOM_Div   -- (james02)
         SET @nMQTY_Pick  = @nMQTY_Pick % @nPUOM_Div   -- (james02)
     
      END      
    
          
      
      -- Prep next screen var      
      SET @nCurrentRec = @nCurrentRec + 1      
      SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))      
      SET @cOutField02 = @cSKU      
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)      
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)      
      SET @cOutField05 = @cAltLOC      
      SET @cOutField06 = @cID      
--      IF @cPUOM_Desc = ''      
--      BEGIN      
--         SET @cOutField07 = '' -- @cPUOM_Desc      
--         SET @cOutField08 = '' -- @nPQTY_Alloc      
--         SET @cOutField09 = '' -- @nPQTY_Avail      
--         SET @cOutField13 = '' -- @nPQTY_Hold     
--      END      
--      ELSE      
--      BEGIN      
--         SET @cOutField07 = @cPUOM_Desc      
--         SET @cOutField08 = CAST( @nPQTY_Avail AS NVARCHAR( 5))      
--         SET @cOutField09 = CAST( @nPQTY_Alloc AS NVARCHAR( 5))      
--         SET @cOutField13 = CAST( @nPQTY_Hold  AS NVARCHAR( 5))     
--      END      
--      SET @cOutField10 = @cMUOM_Desc      
--      SET @cOutField11 = CAST( @nMQTY_Avail AS NVARCHAR( 5))      
--      SET @cOutField12 = CAST( @nMQTY_Alloc AS NVARCHAR( 5))      
--      SET @cOutField14 = CAST( @nMQTY_Hold  AS NVARCHAR( 5))     
      SET @cOutField07 = CASE WHEN @cPUOM_Desc <> '' 
                THEN @cPUOM_Desc + ' ' + @cMUOM_Desc 
                ELSE SPACE( 6) + @cMUOM_Desc END 
      SET @cOutField08 = CASE WHEN @cPUOM_Desc <> '' 
                THEN LEFT( CAST( @nPQTY_TTL AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_TTL AS NVARCHAR( 5)) 
                ELSE SPACE( 6) + CAST( @nMQTY_TTL   AS NVARCHAR( 5)) END -- (james02)
      SET @cOutField09 = CASE WHEN @cPUOM_Desc <> '' 
                THEN LEFT( CAST( @nPQTY_Hold AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Hold AS NVARCHAR( 5)) 
                ELSE SPACE( 6) + CAST( @nMQTY_Hold  AS NVARCHAR( 5)) END -- (Vicky01)
      SET @cOutField10 = CASE WHEN @cPUOM_Desc <> '' 
                THEN LEFT( CAST( @nPQTY_Alloc AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Alloc AS NVARCHAR( 5)) 
                ELSE SPACE( 6) + CAST( @nMQTY_Alloc AS NVARCHAR( 5)) END
      SET @cOutField11 = CASE WHEN @cPUOM_Desc <> '' 
                THEN LEFT( CAST( @nPQTY_Pick AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Pick AS NVARCHAR( 5)) 
                ELSE SPACE( 6) + CAST( @nMQTY_Pick AS NVARCHAR( 5)) END
      SET @cOutField12 = CASE WHEN @cPUOM_Desc <> '' 
                THEN LEFT( CAST( @nPQTY_RPL AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_RPL AS NVARCHAR( 5)) 
                ELSE SPACE( 6) + CAST( @nMQTY_RPL   AS NVARCHAR( 5)) END -- (james02)
      SET @cOutField13 = CASE WHEN @cPUOM_Desc <> '' 
                THEN LEFT( CAST( @nPQTY_Avail AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5))
                ELSE SPACE( 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5)) END 

/*      
      SET @cOutField12 = @cLottable01      
      SET @cOutField13 = @cLottable02      
      SET @cOutField14 = @cLottable03      
*/      
--      SET @cOutField13 = RDT.rdtFormatDate( @dLottable04)      
--      SET @cOutField14 = RDT.rdtFormatDate( @dLottable05)      
      
      -- Remain in current screen      
      SET @nScn = @nScn - 1      
      SET @nStep = @nStep - 1      
   END      
      
   IF @nInputKey = 0 -- Esc or No      
   BEGIN      
     -- Prepare prev screen var      
      SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))      
      SET @cOutField02 = @cSKU      
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)      
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)      
      SET @cOutField05 = @cAltLOC      
      SET @cOutField06 = @cID
      SET @cOutField07 = CASE WHEN @cPUOM_Desc <> '' 
                THEN @cPUOM_Desc + ' ' + @cMUOM_Desc 
                ELSE SPACE( 6) + @cMUOM_Desc END 
      SET @cOutField08 = CASE WHEN @cPUOM_Desc <> '' 
                THEN LEFT( CAST( @nPQTY_TTL AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_TTL AS NVARCHAR( 5)) 
                ELSE SPACE( 6) + CAST( @nMQTY_TTL   AS NVARCHAR( 5)) END -- (james02)
      SET @cOutField09 = CASE WHEN @cPUOM_Desc <> '' 
                THEN LEFT( CAST( @nPQTY_Hold AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Hold AS NVARCHAR( 5)) 
                ELSE SPACE( 6) + CAST( @nMQTY_Hold  AS NVARCHAR( 5)) END -- (Vicky01)
      SET @cOutField10 = CASE WHEN @cPUOM_Desc <> '' 
                THEN LEFT( CAST( @nPQTY_Alloc AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Alloc AS NVARCHAR( 5)) 
                ELSE SPACE( 6) + CAST( @nMQTY_Alloc AS NVARCHAR( 5)) END
      SET @cOutField11 = CASE WHEN @cPUOM_Desc <> '' 
                THEN LEFT( CAST( @nPQTY_Pick AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Pick AS NVARCHAR( 5)) 
                ELSE SPACE( 6) + CAST( @nMQTY_Pick AS NVARCHAR( 5)) END
      SET @cOutField12 = CASE WHEN @cPUOM_Desc <> '' 
                THEN LEFT( CAST( @nPQTY_RPL AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_RPL AS NVARCHAR( 5)) 
                ELSE SPACE( 6) + CAST( @nMQTY_RPL   AS NVARCHAR( 5)) END -- (james02)
      SET @cOutField13 = CASE WHEN @cPUOM_Desc <> '' 
                THEN LEFT( CAST( @nPQTY_Avail AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5))
                ELSE SPACE( 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5)) END 
      
--      IF @cPUOM_Desc = ''      
--      BEGIN      
--         SET @cOutField07 = '' -- @cPUOM_Desc      
--         SET @cOutField08 = '' -- @nPQTY_Alloc      
--         SET @cOutField09 = '' -- @nPQTY_Avail      
--         SET @cOutField13 = '' -- @nPQTY_Hold     
--      END      
--      ELSE      
--      BEGIN      
--         SET @cOutField07 = @cPUOM_Desc      
--         SET @cOutField08 = CAST( @nPQTY_Avail AS NVARCHAR( 5))      
--         SET @cOutField09 = CAST( @nPQTY_Alloc AS NVARCHAR( 5))      
--         SET @cOutField13 = CAST( @nPQTY_Hold  AS NVARCHAR( 5))      
--      END      
--      SET @cOutField10 = @cMUOM_Desc      
--      SET @cOutField11 = CAST( @nMQTY_Avail AS NVARCHAR( 5))      
--      SET @cOutField12 = CAST( @nMQTY_Alloc AS NVARCHAR( 5))      
--      SET @cOutField14 = CAST( @nMQTY_Hold  AS NVARCHAR( 5))     
      
      -- Go to prev screen      
      SET @nScn = @nScn - 1      
      SET @nStep = @nStep - 1      
   END      
END      
GOTO Quit           
  
/********************************************************************************            
Step 11. screen = 2570            
  SP Confirm          
********************************************************************************/            
Step_11:            
BEGIN            
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER        / ESC    
   BEGIN            
          
      SET @cOutField01 = ''      
       
      SET @nScn = 2561         
      SET @nStep = 2          
   END            
            
END            
GOTO Quit    

/********************************************************************************              
Step 1. screen = 2571              
   PA Screen (Field01, input)              
********************************************************************************/              
Step_12:              
BEGIN              
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER        / ESC    
   BEGIN            
          
      SET @cOutField01 = @cToteNo      
       
      SET @nScn = 2561         
      SET @nStep = 2          
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
       -- UserName      = @cUserName,              

       V_Lottable01 = @cLottable01, 
       V_Lottable02 = @cLottable02, 
       V_Lottable03 = @cLottable03, 
       V_Lottable04 = @cLottable04, 
       V_Lottable05 = @cLottable05, 

       V_Orderkey         = @cOrderKey,                   
       V_ConsigneeKey     = @cConsigneekey,               
       V_SKU              = @cSKU,                        
       V_SKUDescr         = @cSKUDescr,                   
       V_UOM              = @cPUOM,    
       V_Loc              = @cLoc,     
       V_LOT              = @cLOT,   
       V_CASEID           = @cToteNo,                 
       V_String1          = @cTaskDetailKey,                    
       V_String2          = @cOption,                     
       V_String3          = @cTaskType,                   
       V_String4          = @cReason,                     
       V_String5          = @cLastUser,                   
       V_String6          = @cLastZone,                   
       V_String7          = @cFinalZone,                                   
       V_String10         = @cWCSKey,                
       V_String11         = @cPrevOrderKey,              
       V_String12         = @cActStorer,              
       V_String13         = @cCompany1,                  
       V_String14         = @cCompany2,               
       V_String15         = @cPltDropID,           
       V_String20         = @cManifestPrinted,     
       V_String21         = @cDropIDShipped,     
       V_String22         = @cNextZone ,        
       V_String23         = @cNextStation,      
       V_String29         = @cPUOM_Desc,        
       V_String33         = @cMUOM_Desc ,                  
       V_String39         = @cAltLoc,    
       V_String40         = @cPickMethod,   

       V_QTY              = @nMQTY_RPL,    
       V_LottableLabel01  = @nPQTY_RPL,    
       V_LottableLabel02  = @nPQTY_TTL,    
       V_LottableLabel03  = @nMQTY_TTL,    
       V_LottableLabel04  = @nMQTY_Pick,   
       V_LottableLabel05  = @nPQTY_Pick,  
       
       V_FromScn          = @nFromScn,          
       V_FromStep         = @nFromStep, 
       
       V_Integer1         = @nOrdQty,                     
       V_Integer2         = @nActQty,             
       V_Integer3         = @nRecCnt,              
       V_Integer4         = @nCounter,              
       V_Integer5         = @nTotRecCnt,              
       V_Integer6         = @nRecCounter,       
       V_Integer7         = @nQCKey,    
       V_Integer8         = @nScanQty,    
       V_Integer9         = @nSPQty,    
       V_Integer10        = @nTotalRec,           
       V_Integer11        = @nCurrentRec,                      
       V_Integer12        = @nPQTY_Avail,      
       V_Integer13        = @nPQTY_Alloc,       
       V_Integer14        = @nPQTY_Hold ,     
       V_Integer15        = @nMQTY_Avail,     
       V_String35         = @nMQTY_Alloc,      
       V_String36         = @nMQTY_Hold ,
            
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