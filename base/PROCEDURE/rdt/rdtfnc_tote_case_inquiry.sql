SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/        
/* Store procedure: rdtfnc_Tote_Case_Inquiry                                 */        
/* Copyright      : IDS                                                      */        
/*                                                                           */        
/* Purpose: Case and Tote Inquiry                                            */        
/*                                                                           */        
/* Modifications log:                                                        */        
/*                                                                           */        
/* Date       Rev  Author   Purposes                                         */        
/* 2010-06-16 1.0  Vicky    Created                                          */        
/* 2010-07-02 1.1  James    Allow to display orders with > 1 SKU (james01)   */              
/* 2010-08-06 1.2  ChewKP   Bug Fixes - OrderQty Double Up(ChewKP01)         */             
/* 2010-08-10 1.3  ChewKP   Fixes- Check Prefix N for DropID (ChewKP02)      */        
/* 2010-08-13 1.4  James    Add in Counter (james02)                         */        
/* 2010-08-14 1.5  James    Cater for SINGLES short pick (james03)           */      
/* 2010-08-15 1.6  James    Display PA Zone instead of Station ID (james04)  */      
/* 2010-08-28 1.7  James    Change display nn/nnn to total allocated qty/    */      
/*                          total qty picked (james05)                       */      
/* 2010-09-06 1.8  James    Show only the Qty in Tote/Case (james06)         */      
/* 2010-09-06 1.9  James    Check for case/tote validity (james07)           */      
/* 2010-09-14 2.0  ChewKP   Bug Fixes should query only on UnShipped Tote    */    
/*                          (ChewKP01)                                       */    
/* 2010-09-18 2.0  ChewKP   Display Last Zone by WCSRoutingDetail Status <> 0*/    
/*                          (ChewKP03)                                       */   
/* 2010-09-21 2.1  ChewKP   Display only Current Active Tote (ChewKP04)      */   
/* 2010-10-05 2.2  James    Show packed qty (james08)                        */   
/* 2010-10-19 2.3  James    Show and order by PTS LOC (james09)              */   
/* 2010-11-15 2.4  James    Show correct PAZone if > 1 station is assigned   */
/*                          to same PAZone (james10)                         */ 
/* 2010-11-19 2.5  James    Add OrderGroup (james11)                         */
/* 2013-02-07 2.6  James    SOS268332 Enable goto prev record (james12)      */
/* 2016-09-30 2.7  Ung      Performance tuning                               */
/* 2018-11-16 2.8  TungGH   Performance                                      */   
/*****************************************************************************/        
CREATE PROC [RDT].[rdtfnc_Tote_Case_Inquiry](        
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
   @cReason             NVARCHAR(10),        
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
   @cOrgPltDropID       NVARCHAR(18), -- (ChewKP02)        
   @cFinalStation       NVARCHAR(10), -- (james04)      
   @cLastStation        NVARCHAR(10), -- (james04)      
   @cLOC                NVARCHAR(10), -- (james09)      
   @cPutawayzone        NVARCHAR(10), -- (james09)      
   @cOrderGroup         NVARCHAR(20), -- (james11)     
   
   @cPrev               NVARCHAR(1),  -- (james12)     

   @nOrdQty             INT,        
   @nActQty             INT,           
   @nRecCnt             INT,  -- (james02)      
   @nCounter            INT,  -- (james02)      
   @nTTL_QTY            INT,  -- (james05)      
   @nPicked_QTY         INT,  -- (james05)      
   @nSKUCnt             INT,  -- (james02)      
   @nSKUCounter         INT,  -- (james02)     
   @nPacked_QTY         INT,  -- (james08)     
      
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
        
   @cOrderKey        = V_Orderkey,        
   @cConsigneekey    = V_ConsigneeKey,        
   @cSKU             = V_SKU,        
   @cSKUDescr        = V_SKUDescr,        
   @cPackUOM03       = V_UOM,        
   @cToteNo          = V_String1,        
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
   
   @nOrdQty          = V_Integer1,        
   @nActQty          = V_Integer2,       
   @nRecCnt          = V_Integer3,        
   @nCounter         = V_Integer4,        
   @nSKUCnt          = V_Integer5,        
   @nSKUCounter      = V_Integer6,        
      
              
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
IF @nFunc = 1629        
BEGIN        
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1629        
   IF @nStep = 1 GOTO Step_1   -- Scn = 2410  Option        
   IF @nStep = 2 GOTO Step_2   -- Scn = 2411  Tote/Case        
   IF @nStep = 3 GOTO Step_3   -- Scn = 2412  Info        
   IF @nStep = 4 GOTO Step_4   -- Scn = 2413  Info        
END        
        
RETURN -- Do nothing if incorrect step        
        
/********************************************************************************        
Step 0. Called from menu (func = 1629)        
********************************************************************************/        
Step_0:        
BEGIN        
   -- Set the entry point        
   SET @nScn  = 2410        
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
   SET @cOrgPltDropID  = '' -- (ChewKP02)        
        
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
END        
GOTO Quit        
        
/********************************************************************************        
Step 1. screen = 2410        
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
         SET @nErrNo = 69916        
         SET @cErrMsg = rdt.rdtgetmessage( 69916, @cLangCode, 'DSP') --Option req        
         EXEC rdt.rdtSetFocusField @nMobile, 1        
         GOTO Step_1_Fail          
      END         
        
      IF @cOption <> '1' AND @cOption <> '9'        
      BEGIN        
         SET @nErrNo = 69917        
         SET @cErrMsg = rdt.rdtgetmessage( 69917, @cLangCode, 'DSP') --Invalid Option        
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
      SET @cOrgPltDropID  = '' -- (ChewKP02)        
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
Step 2. screen = 2411        
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
         SET @nErrNo = 69918        
         SET @cErrMsg = rdt.rdtgetmessage( 69918, @cLangCode, 'DSP') --TOTE/CASE # req        
         EXEC rdt.rdtSetFocusField @nMobile, 1        
         GOTO Step_2_Fail          
      END        
        
        -- check exists in WCSRouting        
      IF NOT EXISTS (SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK) WHERE ToteNo = @cToteNo         
                     AND Facility = @cFacility)        
      BEGIN  
         --SET @nErrNo = 69919        
         --SET @cErrMsg = rdt.rdtgetmessage( 69919, @cLangCode, 'DSP') --Invalid TOTE/CASE        
         --EXEC rdt.rdtSetFocusField @nMobile, 1        
         --GOTO Step_2_Fail
         IF @cOption = '1'
         BEGIN
            SET @cTaskType = ''
            
            SELECT TOP 1 
               @cTaskType = td.TaskType, 
               @cLastUser = td.UserKey, 
               @cFinalStation = '*NO ROUTE*',
               @cActStorer    = td.Storerkey, 
               @cWCSKey ='' 
            FROM   TaskDetail td (NOLOCK) 
            JOIN   DROPID DI (NOLOCK) ON DI.Dropid = TD.DropID AND DI.Loadkey = TD.LoadKey 
            WHERE  TD.Dropid = @cToteNo 
            AND    TD.STATUS = '9' 
            AND    td.TaskType = 'PK'
            IF ISNULL(RTRIM(@cTaskType),'') = ''
            BEGIN
               SET @nErrNo = 69919        
               SET @cErrMsg = rdt.rdtgetmessage( 69919, @cLangCode, 'DSP') --Invalid TOTE/CASE        
               EXEC rdt.rdtSetFocusField @nMobile, 1        
               GOTO Step_2_Fail            
            END        
                    
         END          
         ELSE
         BEGIN
            SET @cTaskType = ''
            
            SELECT TOP 1 
               @cTaskType = td.TaskType, 
               @cLastUser = td.UserKey, 
               @cFinalStation = '*NO ROUTE*',
               @cActStorer    = td.Storerkey, 
               @cWCSKey ='' 
            FROM   TaskDetail td (NOLOCK) 
            JOIN   UCC U (NOLOCK) ON U.SourceKey = TD.TaskDetailKey  
            WHERE  U.UccNo = @cToteNo 
            AND    TD.STATUS <> 'X' 
            AND    td.TaskType IN ('DPK','DRP')
             
            IF ISNULL(RTRIM(@cTaskType),'') = ''
            BEGIN
               SET @nErrNo = 69919        
               SET @cErrMsg = rdt.rdtgetmessage( 69919, @cLangCode, 'DSP') --Invalid TOTE/CASE        
               EXEC rdt.rdtSetFocusField @nMobile, 1        
               GOTO Step_2_Fail            
            END        
         END          
         SET @cLastStation = '*NO ROUTE*'             
         SET @cLastZone    = '*NO ROUTE*'
         SET @cFinalZone   = '*NO ROUTE*'
      END        
      ELSE
      BEGIN
         SELECT TOP 1 @cTaskType = TaskType,        
                      @cLastUser = EditWho,        
                      @cFinalStation = Final_Zone,  -- (james04)      
                      @cWCSKey = WCSKey,        
                      @cActStorer = Storerkey        
         FROM dbo.WCSRouting WITH (NOLOCK)        
         WHERE ToteNo = @cToteNo        
         AND Facility = @cFacility        
         ORDER BY WCSKey DESC        
           
         SELECT TOP 1 @cLastStation = ZONE        -- (james04)      
         FROM dbo.WCSRoutingDetail WITH (NOLOCK)        
         WHERE WCSKey = @cWCSKey        
         AND Status <> '0' -- (ChewKP03)      
         ORDER BY EditDate DESC        

         IF EXISTS (SELECT 1 FROM dbo.Codelkup WITH (NOLOCK) 
            WHERE ListName = 'WCSSTATION'
            AND   Short = @cFinalStation
            GROUP BY Short
            HAVING COUNT(1) > 1)         
         BEGIN
            IF @cTaskType = 'PA'
            BEGIN
               SELECT @cFinalZone = Code       
               FROM dbo.CodeLKup CL WITH (NOLOCK)       
               JOIN dbo.LOC LOC WITH (NOLOCK) ON CL.CODE = LOC.PUTAWAYZONE
               JOIN dbo.TaskDetail TD WITH (NOLOCK) ON LOC.LOC = TD.TOLOC
               WHERE Listname = 'WCSStation'      
                  AND Short = @cFinalStation
                  AND CaseID = @cToteNo     
            END
            ELSE
            IF @cTaskType = 'PK'
            BEGIN
               SELECT TOP 1       
                   @cLOC = PD.Loc       
               FROM dbo.PickDetail PD WITH (NOLOCK)       
               JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)      
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
               JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)    
               JOIN dbo.DropID D WITH (NOLOCK) ON (D.DropID = TD.DropID AND D.DropIDType = TD.PickMethod AND D.LoadKey = O.LoadKey) -- (ChewKP04)   
               WHERE TD.Storerkey = @cActStorer      
                  AND TD.DropID =  @cToteNo      
                  AND O.Facility = @cFacility      
                  AND O.Status NOT IN ('9', 'CANC') -- (ChewKP01)    
               ORDER BY PD.OrderKey, PD.SKU  

               SELECT @cFinalZone = Code       
               FROM dbo.CodeLKup CL WITH (NOLOCK)       
               JOIN dbo.LOC LOC WITH (NOLOCK) ON CL.CODE = LOC.PUTAWAYZONE
               WHERE Listname = 'WCSStation'      
                  AND Short = @cFinalStation
                  AND LOC = @cLOC  
            END
            ELSE
            IF @cTaskType = 'PK'
            BEGIN
               SELECT TOP 1       
                   @cLOC = PD.LOC      -- (james09) 
               FROM dbo.PickDetail PD WITH (NOLOCK)       
               JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)      
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
               JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey) 
               JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID)       
               WHERE PD.Storerkey = @cActStorer      
                  AND PD.CaseID =  @cToteNo      
                  --AND PD.DropID =  @cPltDropID      
                  AND O.Facility = @cFacility      
               ORDER BY PD.OrderKey, PD.SKU      

               SELECT @cFinalZone = Code       
               FROM dbo.CodeLKup CL WITH (NOLOCK)       
               JOIN dbo.LOC LOC WITH (NOLOCK) ON CL.CODE = LOC.PUTAWAYZONE
               WHERE Listname = 'WCSStation'      
                  AND Short = @cFinalStation
                  AND LOC = @cLOC  
            END
            ELSE
            BEGIN
               SELECT @cFinalZone = Code       
               FROM dbo.CodeLKup WITH (NOLOCK)       
               WHERE Listname = 'WCSStation'      
                  AND Short = @cFinalStation      
            END
         END
         ELSE
         BEGIN
            -- (james04)      
            SELECT @cFinalZone = Code       
            FROM dbo.CodeLKup WITH (NOLOCK)       
            WHERE Listname = 'WCSStation'      
               AND Short = @cFinalStation      
         END

         -- (james04)      
         SELECT @cLastZone = code      
         FROM dbo.CodeLKup WITH (NOLOCK)      
         WHERE Listname = 'WCSStation'      
            AND Short = @cLastStation      
         
      END  
      
      IF @cOption = '1' -- Scan Tote No        
      BEGIN        
        /*
        IF NOT EXISTS (SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)       
                   WHERE Toteno = @cToteNo      
                   AND TaskType = 'PK'      
        AND OrderType <> 'CASE') -- (james07)      
        BEGIN      
           SET @nErrNo = 69920        
           SET @cErrMsg = rdt.rdtgetmessage( 69920, @cLangCode, 'DSP') --Invalid TOTE        
           EXEC rdt.rdtSetFocusField @nMobile, 1        
           GOTO Step_2_Fail          
        END      
        */    
          
        SELECT TOP 1 @cLoadkey = TD.LoadKey      
        FROM dbo.TaskDetail TD WITH (NOLOCK)       
        JOIN dbo.PickDetail PD WITH (NOLOCK)       
           ON (TD.StorerKey = PD.StorerKey AND TD.TaskDetailKey = PD.TaskDetailKey)     
        JOIN dbo.Orders O WITH (NOLOCK)   -- (ChewKP01)    
           ON (O.Orderkey = PD.Orderkey ) -- (ChewKP01)     
        WHERE TD.DropID = @cToteNo        
           AND  TD.Storerkey = @cActStorer    
           AND O.Status NOT IN ('9', 'CANC') -- (ChewKP01)    
              
      
        SELECT TOP 1 @cReason = ReasonKey        
        FROM dbo.TaskDetail WITH (NOLOCK)        
        WHERE DropID = @cToteNo        
        AND  ReasonKey <> ''        
        AND  Loadkey = @cLoadkey        
        AND  Storerkey = @cActStorer        
        
        IF ISNULL(RTRIM(@cReason), '') = ''        
        BEGIN        
          SET @cReason = ''        
        END        
      END        
        
      IF @cOption = '9' -- Scan Case ID        
      BEGIN
         /*      
         IF NOT EXISTS (SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)       
                        WHERE Toteno = @cToteNo       
                        AND Tasktype = 'PK'      
                        AND OrderType = 'CASE') -- (james07)      
         BEGIN  
            IF NOT EXISTS (SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK)       
                       WHERE Toteno = @cToteNo       
                       AND Tasktype = 'PA'      
                       AND OrderType = '') -- (james07)      
           BEGIN      
              SET @nErrNo = 69921        
              SET @cErrMsg = rdt.rdtgetmessage( 69921, @cLangCode, 'DSP') --Invalid Case        
              EXEC rdt.rdtSetFocusField @nMobile, 1        
              GOTO Step_2_Fail          
           END      
        END  
        */
        
        SET @cOrgPltDropID=''
        
        SELECT @cOrgPltDropID = DID.DropID,        
               @cLoadkey = DP.Loadkey        
        FROM dbo.DROPIDDETAIL DID WITH (NOLOCK)        
        JOIN dbo.DROPID DP WITH (NOLOCK) ON (DP.DropID = DID.DropID)        
        WHERE ChildID = @cToteNo        
                
        -- (ChewKP02) Start    
        IF LEN(RTRIM(@cOrgPltDropID)) > 0 
        BEGIN
           IF SUBSTRING (@cOrgPltDropID , 1 ,1 ) = 'N'        
           BEGIN        
               SET @cPltDropID = SUBSTRING (@cOrgPltDropID , 2, 18)        
           END        
           ELSE        
           BEGIN        
               SET @cPltDropID = SUBSTRING(@cOrgPltDropID, 1, LEN(RTRIM(@cOrgPltDropID)) - 4)      
           END                   
        END    
        -- (ChewKP02) End        
        
        SET @cReason = ''       
        SELECT TOP 1 @cReason = TaskDetail.ReasonKey        
        FROM dbo.TaskDetail WITH (NOLOCK) 
        JOIN dbo.UCC WITH (NOLOCK) ON dbo.TaskDetail.TaskDetailKey = UCC.Sourcekey         
        WHERE CaseID = @cToteNo        
           AND  TaskDetail.ReasonKey <> ''        
           --AND  DropID = @cPltDropID        
           AND  UCC.UCCNo = @cToteNo
           --AND  Loadkey = @cLoadkey        
           AND  TaskDetail.Storerkey = @cActStorer        
        
        IF ISNULL(RTRIM(@cReason), '') = ''        
        BEGIN    
          SET @cReason = ''        
        END        
      END        
        
      --prepare next screen variable        
      SET @cOutField01 = @cToteNo        
      SET @cOutField02 = @cTaskType         
      SET @cOutField03 = @cReason         
      SET @cOutField04 = @cLastUser         
      SET @cOutField05 = @cLastZone        
      SET @cOutField06 = @cFinalZone        
        
      SET @nScn = @nScn + 1        
      SET @nStep = @nStep + 1        
   END        
        
   IF @nInputKey = 0 -- ESC        
   BEGIN        
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
      SET @cOrgPltDropID  = '' -- (ChewKP02)        
        
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
Step 3. screen = 2412        
 Info Screen        
********************************************************************************/        
Step_3:        
BEGIN        
   IF @nInputKey = 1 -- ENTER        
   BEGIN        
      IF @cOption = '1' -- Tote No        
      BEGIN        
         SELECT TOP 1       
             @cOrderkey = OD.Orderkey,      
             @cSKU = OD.SKU,      
             @cConsigneekey = ISNULL(RTRIM(O.ConsigneeKey), ''),      
             @cPackUOM03 = OD.UOM, 
             @cLOC = PD.Loc       
         FROM dbo.PickDetail PD WITH (NOLOCK)       
         JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)      
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)    
         JOIN dbo.DropID D WITH (NOLOCK) ON (D.DropID = TD.DropID AND D.DropIDType = TD.PickMethod AND D.LoadKey = O.LoadKey) -- (ChewKP04)   
         WHERE TD.Storerkey = @cActStorer      
            AND TD.DropID =  @cToteNo      
            AND O.Facility = @cFacility      
            AND O.Status NOT IN ('9', 'CANC') -- (ChewKP01)    
         ORDER BY PD.OrderKey, PD.SKU      
         
         SELECT @cPutawayzone = Putawayzone 
         FROM dbo.LOC WITH (NOLOCK) 
         WHERE LOC = @cLOC
         
         SELECT @nTTL_QTY = ISNULL(SUM(Qty), 0)      
         FROM dbo.PickDetail WITH (NOLOCK)      
         WHERE StorerKey = @cActStorer      
            AND OrderKey = @cOrderkey      
            AND SKU = @cSKU      
      
         SELECT @nPicked_QTY = CASE WHEN Status >= '5' THEN ISNULL(SUM(Qty), 0) ELSE 0 END      
         FROM dbo.PickDetail WITH (NOLOCK)      
         WHERE StorerKey = @cActStorer      
            AND OrderKey = @cOrderkey      
            AND SKU = @cSKU      
         GROUP BY Status      
      
         SELECT @nPacked_QTY = ISNULL(SUM(PD.Qty), 0) 
         FROM dbo.PackDetail PD WITH (NOLOCK)      
         JOIN dbo.packHeader PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
         JOIN dbo.DropID D WITH (NOLOCK) ON (D.DropID = PD.DropID AND D.Loadkey = PH.LoadKey)
         WHERE PH.StorerKey = @cActStorer      
            AND PH.OrderKey = @cOrderkey      
            AND PD.SKU = @cSKU      

         SELECT @nRecCnt = COUNT(DISTINCT PD.OrderKey)       
         FROM dbo.PickDetail PD WITH (NOLOCK)      
         JOIN dbo.TaskDetail TD WITH (NOLOCK)       
            ON (PD.StorerKey = TD.StorerKey AND PD.TaskDetailKey = TD.TaskDetailKey)      
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  -- (ChewKP01)   
         JOIN dbo.DropID D WITH (NOLOCK) ON (D.DropID = TD.DropID AND D.DropIDType = TD.PickMethod AND D.Loadkey = O.LoadKey) -- (ChewKP04)      
         WHERE PD.Storerkey = @cActStorer        
            AND TD.DropID =  @cToteNo       
            AND O.Status NOT IN ('9', 'CANC') -- (ChewKP01)     
      
         SELECT @nSKUCnt = COUNT(DISTINCT PD.SKU)       
         FROM dbo.PickDetail PD WITH (NOLOCK)      
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  -- (ChewKP01) 
         JOIN dbo.TaskDetail TD WITH (NOLOCK)       
            ON (PD.StorerKey = TD.StorerKey AND PD.TaskDetailKey = TD.TaskDetailKey)      
         JOIN dbo.DropID D WITH (NOLOCK) ON (D.DropID = TD.DropID AND D.DropIDType = TD.PickMethod AND D.Loadkey = O.LoadKey) -- (ChewKP04)  
         WHERE TD.Storerkey = @cActStorer        
            AND TD.DropID =  @cToteNo        
            AND PD.OrderKey = @cOrderkey      
      END        
        
      IF @cOption = '9' -- Case ID        
      BEGIN        
         IF EXISTS (SELECT 1 FROM dbo.UCC UCC WITH (NOLOCK)       
                    JOIN TaskDetail TD WITH (NOLOCK) ON (UCC.SourceKey = TD.TaskDetailKey)      
                    WHERE TD.StorerKey = @cActStorer       
                       AND TD.TaskType = 'DPK'      
                       AND UCC.UCCNO = @cToteNo)      
         BEGIN      
            SELECT TOP 1       
                @cOrderkey = OD.Orderkey,      
                @cSKU = OD.SKU,      
                @cConsigneekey = ISNULL(RTRIM(O.ConsigneeKey), ''),      
                @cPackUOM03 = OD.UOM,
                @cLOC = PD.LOC      -- (james09) 
            FROM dbo.PickDetail PD WITH (NOLOCK)       
            JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)      
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
            JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey) 
            JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID)       
            WHERE PD.Storerkey = @cActStorer      
               AND PD.CaseID =  @cToteNo      
               --AND PD.DropID =  @cPltDropID      
               AND O.Facility = @cFacility      
            ORDER BY PD.OrderKey, PD.SKU      
      
            IF @@RowCount = 0      
            BEGIN      
                  SELECT TOP 1       
                      @cOrderkey = OD.Orderkey,      
                      @cSKU = OD.SKU,      
                      @cConsigneekey = ISNULL(RTRIM(O.ConsigneeKey), ''),      
                      @cPackUOM03 = OD.UOM,
                      @cLOC = PD.LOC      -- (james09)
                  FROM dbo.PickDetail PD WITH (NOLOCK)       
                  JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)      
                  JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
                  JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)      
                  JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID ) 
                  WHERE PD.Storerkey = @cActStorer      
                     AND PD.CaseID =  @cToteNo      
                     --AND PD.DropID =  @cPltDropID      
                     AND O.Facility = @cFacility      
                  ORDER BY PD.OrderKey, PD.SKU      
            END      
      
            SELECT @nTTL_QTY = ISNULL(SUM(Qty), 0)      
            FROM dbo.PickDetail WITH (NOLOCK)      
            WHERE StorerKey = @cActStorer      
               AND OrderKey = @cOrderkey      
               AND SKU = @cSKU      
--               AND CaseID = @cToteNo   -- (james06)      
      
           SELECT @nPicked_QTY = CASE WHEN Status IN ('3', '5', '9') THEN ISNULL(SUM(Qty), 0) ELSE 0 END      
            FROM dbo.PickDetail WITH (NOLOCK)      
            WHERE StorerKey = @cActStorer      
               AND OrderKey = @cOrderkey      
               AND SKU = @cSKU      
--               AND CaseID = @cToteNo   -- (james06)      
            GROUP BY Status      

            SELECT @nPacked_QTY = ISNULL(SUM(PD.Qty), 0) 
            FROM dbo.PackDetail PD WITH (NOLOCK)      
            JOIN dbo.packHeader PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
            WHERE PH.StorerKey = @cActStorer      
               AND PH.OrderKey = @cOrderkey      
               AND PD.SKU = @cSKU      
      
            SELECT @nRecCnt = COUNT(DISTINCT PD.OrderKey)       
            FROM dbo.PickDetail PD WITH (NOLOCK)      
            JOIN dbo.TaskDetail TD WITH (NOLOCK)       
               ON (PD.StorerKey = TD.StorerKey AND PD.TaskDetailKey = TD.TaskDetailKey)      
            JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID ) 
            WHERE PD.Storerkey = @cActStorer        
               AND PD.CaseID =  @cToteNo      
               --AND PD.DropID =  @cPltDropID      
      
            SELECT @nSKUCnt = COUNT(DISTINCT PD.SKU)       
            FROM dbo.PickDetail PD WITH (NOLOCK)      
            JOIN dbo.TaskDetail TD WITH (NOLOCK)       
               ON (PD.StorerKey = TD.StorerKey AND PD.TaskDetailKey = TD.TaskDetailKey)      
            JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID ) 
            WHERE TD.Storerkey = @cActStorer        
               AND PD.CaseID =  @cToteNo      
               --AND PD.DropID =  @cPltDropID      
               AND PD.OrderKey = @cOrderkey      

            -- (james09)
            SELECT @cPutawayzone = Putawayzone FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cLOC
         END        
         ELSE      
         BEGIN      
            IF EXISTS (SELECT 1 FROM dbo.UCC UCC WITH (NOLOCK)       
                    JOIN TaskDetail TD WITH (NOLOCK) ON (UCC.SourceKey = TD.TaskDetailKey)      
                    WHERE TD.StorerKey = @cActStorer       
                       AND TD.TaskType = 'DRP'      
               AND UCC.UCCNO = @cToteNo)      
            BEGIN      
               SELECT @cSKU = TD.SKU, @nTTL_QTY = TD.Qty, @cPackUOM03 = Pack.PackUOM3       
               FROM dbo.TaskDetail TD WITH (NOLOCK)       
               JOIN dbo.SKU SKU WITH (NOLOCK) ON TD.SKU = SKU.SKU AND TD.StorerKey = SKU.StorerKey      
               JOIN dbo.Pack Pack WITH (NOLOCK) ON SKU.PackKey = Pack.Packkey      
               WHERE TD.StorerKey = @cActStorer      
                  AND TD.CaseID = @cToteNo      
      
               SET @nPacked_QTY = 0
               SET @nRecCnt = 0
               SET @nPicked_QTY=0
               
               SET @cOutField01 = ''        
               SET @cOutField02 = 'DYNAMIC REPLEN'      
               SET @cOutField03 = ''         
               SET @cOutField04 = ''        
               SET @cOutField05 = @cSKU        
               SET @cOutField06 = ''        
               SET @cOutField07 = ''        
               SET @cOutField08 = @cPackUOM03         
               SET @cOutField09 = CAST(@nTTL_QTY AS INT)        
               SET @cOutField10 = ''      
               SET @cOutField11 = '1/1'      
               SET @cOutField12 = '1/1'    
               SET @cOutField13 = ''  
      
               SET @nScn = @nScn + 1        
               SET @nStep = @nStep + 1      
      
               GOTO Quit      
            END      
            ELSE      
            BEGIN      
               SELECT @cSKU = TD.SKU, @nTTL_QTY = TD.Qty, @cPackUOM03 = Pack.PackUOM3       
               FROM dbo.TaskDetail TD WITH (NOLOCK)       
               JOIN dbo.SKU SKU WITH (NOLOCK) ON TD.SKU = SKU.SKU AND TD.StorerKey = SKU.StorerKey      
               JOIN dbo.Pack Pack WITH (NOLOCK) ON SKU.PackKey = Pack.Packkey      
               WHERE TD.StorerKey = @cActStorer      
                  AND TD.CaseID = @cToteNo      
      
               SET @cOutField01 = ''        
               SET @cOutField02 = 'PUTAWAY'      
               SET @cOutField03 = ''         
               SET @cOutField04 = ''        
               SET @cOutField05 = @cSKU        
               SET @cOutField06 = ''        
               SET @cOutField07 = ''        
               SET @cOutField08 = @cPackUOM03         
               SET @cOutField09 = CAST(@nTTL_QTY AS INT)        
               SET @cOutField10 = ''      
               SET @cOutField11 = '1/1'      
               SET @cOutField12 = '1/1'      
      
               SET @nScn = @nScn + 1        
               SET @nStep = @nStep + 1      
      
               GOTO Quit      
            END      
         END      
      END      
      
      SET @cPrevOrderkey = @cOrderkey        
        
      SELECT @cCompany1     = LEFT(RTRIM(Company), 20),        
             @cCompany2     = SUBSTRING(RTRIM(Company), 21,20)        
      FROM dbo.STORER WITH (NOLOCK)         
      WHERE Storerkey = @cConsigneekey         
      AND Type = '2'        
      
      SELECT @cSKUDescr = RTRIM(DESCR)        
      FROM dbo.SKU WITH (NOLOCK)        
      WHERE Storerkey = @cActStorer        
      AND   SKU = @cSKU        

      -- (james11)
      SELECT TOP 1 @cOrderGroup = OrderGroup 
      FROM Orders WITH (NOLOCK) 
      WHERE StorerKey = @cActStorer
      AND   OrderKey = @cOrderkey

      SET @nCounter = 1    -- (james02)      
      SET @nSKUCounter = 1    -- (james02)      
      
      --prepare next screen variable        
      SET @cOutField01 = @cOrderkey        
      SET @cOutField02 = CASE WHEN ISNULL(RTRIM(@cConsigneekey), '') = '' THEN 'ECOMM' + '-' + @cOrderGroup
                              ELSE ISNULL(RTRIM(@cConsigneekey), '') + '-' + ISNULL(RTRIM(@cPutawayzone),'') + '-' + @cOrderGroup END -- (james09/11)     
      SET @cOutField03 = @cCompany1         
      SET @cOutField04 = @cCompany2        
      SET @cOutField05 = @cSKU        
      SET @cOutField06 = ISNULL(LEFT(RTRIM(@cSKUDescr), 20), '')        
      SET @cOutField07 = ISNULL(SUBSTRING(RTRIM(@cSKUDescr), 21,20), '')        
      SET @cOutField08 = @cPackUOM03         
      SET @cOutField09 = CAST(@nTTL_QTY AS INT)        
      SET @cOutField10 = CAST(@nPicked_QTY AS INT)         
      SET @cOutField11 = RTRIM(CAST(@nCounter AS NVARCHAR( 5))) + '/' + CAST(@nRecCnt AS NVARCHAR( 5))   -- (james02)      
      SET @cOutField12 = RTRIM(CAST(@nSKUCounter AS NVARCHAR( 5))) + '/' + CAST(@nSKUCnt AS NVARCHAR( 5))   -- (james02)      
      SET @cOutField13 = CAST(@nPacked_QTY AS INT)         
      SET @cOutField14 = ''   -- (james12)

      SET @nScn = @nScn + 1        
      SET @nStep = @nStep + 1        
   END        
        
   IF @nInputKey = 0 -- ESC        
   BEGIN        
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
      SET @cOrgPltDropID  = '' -- (ChewKP02)        
        
      SET @nScn = @nScn - 1        
      SET @nStep = @nStep - 1        
   END        
   GOTO Quit        
END        
GOTO Quit        
        
/********************************************************************************        
Step 4. screen = 2413         
  info screen        
********************************************************************************/        
Step_4:        
BEGIN        
   IF @nInputKey = 1 -- ENTER        
   BEGIN        
      -- Screen mapping        
      SET @cPrev = @cInField14     
      
      IF ISNULL(@cPrev, '') <> ''
      BEGIN      
         IF ISNULL(@cPrev, '') <> '1'
         BEGIN
            SET @nErrNo = 69923        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid OPT        
            SET @nScn = @nScn         
            SET @nStep = @nStep        
            GOTO QUIT       
         END
      END      
           
      IF @cOption = '1' -- Tote No        
      BEGIN        
         IF ISNULL(@cPrev, '') = '1' -- (james12)
         BEGIN
            -- (james05)      
            SELECT TOP 1       
                @cOrderkey = OD.Orderkey,      
                @cSKU = OD.SKU,      
                @cConsigneekey = ISNULL(RTRIM(O.ConsigneeKey), ''),      
                @cPackUOM03 = OD.UOM, 
                @cLOC = PD.Loc            
            FROM dbo.PickDetail PD WITH (NOLOCK)       
            JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)      
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
            JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)    
            JOIN dbo.DropID D WITH (NOLOCK) ON (D.DropID = TD.DropID AND D.DropIDType = TD.PickMethod AND D.Loadkey = O.LoadKey) -- (ChewKP04)        
            WHERE TD.Storerkey = @cActStorer      
               AND TD.DropID =  @cToteNo      
               AND O.Facility = @cFacility      
               AND PD.OrderKey = @cPrevOrderkey      
               AND PD.SKU < @cSKU      
               AND O.Status NOT IN ('9', 'CANC') -- (ChewKP01)    
            ORDER BY PD.SKU DESC
         
            IF @@ROWCOUNT = 0      
            BEGIN      
               SELECT TOP 1       
                   @cOrderkey = OD.Orderkey,      
                   @cSKU = OD.SKU,      
                   @cConsigneekey = ISNULL(RTRIM(O.ConsigneeKey), ''),      
                   @cPackUOM03 = OD.UOM, 
                   @cLOC = PD.Loc            
               FROM dbo.PickDetail PD WITH (NOLOCK)       
               JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)      
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
               JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
               JOIN dbo.DropID D WITH (NOLOCK) ON (D.DropID = TD.DropID AND D.DropIDType = TD.PickMethod AND D.Loadkey = O.LoadKey) -- (ChewKP04)          
               WHERE TD.Storerkey = @cActStorer      
                  AND TD.DropID =  @cToteNo      
                  AND O.Facility = @cFacility      
                  AND PD.OrderKey < @cPrevOrderkey      
                  AND O.Status NOT IN ('9', 'CANC') -- (ChewKP01)    
               ORDER BY PD.OrderKey DESC, PD.SKU DESC
               
               IF @@rowcount = 0        
               BEGIN        
                  SET @cErrMsg = 'No More Records'        

                  SET @nScn = @nScn         
                  SET @nStep = @nStep        
                  GOTO QUIT        
               END           

               SELECT @nTTL_QTY = ISNULL(SUM(Qty), 0)      
               FROM dbo.PickDetail WITH (NOLOCK)      
               WHERE StorerKey = @cActStorer      
                  AND OrderKey = @cOrderkey      
                  AND SKU = @cSKU      
         
               SELECT @nPicked_QTY = CASE WHEN Status >= '5' THEN ISNULL(SUM(Qty), 0) ELSE 0 END      
               FROM dbo.PickDetail WITH (NOLOCK)      
               WHERE StorerKey = @cActStorer      
                  AND OrderKey = @cOrderkey      
                  AND SKU = @cSKU      
               GROUP BY Status      

               SELECT @nPacked_QTY = ISNULL(SUM(PD.Qty), 0) 
               FROM dbo.PackDetail PD WITH (NOLOCK)      
               JOIN dbo.packHeader PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
               WHERE PH.StorerKey = @cActStorer      
                  AND PH.OrderKey = @cOrderkey      
                  AND PD.SKU = @cSKU      

               SELECT @cPutawayzone = Putawayzone 
               FROM dbo.LOC WITH (NOLOCK) 
               WHERE LOC = @cLOC               

               SELECT @nSKUCnt = COUNT(DISTINCT PD.SKU)       
               FROM dbo.PickDetail PD WITH (NOLOCK)      
               JOIN dbo.TaskDetail TD WITH (NOLOCK)       
                  ON (PD.StorerKey = TD.StorerKey AND PD.TaskDetailKey = TD.TaskDetailKey)      
               WHERE TD.Storerkey = @cActStorer        
                  AND TD.DropID =  @cToteNo        
                  AND PD.OrderKey = @cOrderkey   
            
               SET @nCounter = @nCounter - 1    -- (james02)  
               SET @nSKUCounter = @nSKUCnt      -- (james02)  
               SET @cPrevOrderkey = @cOrderkey  
               
               GOTO Display_Rec            
            END
            ELSE      
            BEGIN      
               SELECT @nTTL_QTY = ISNULL(SUM(Qty), 0)      
               FROM dbo.PickDetail WITH (NOLOCK)      
               WHERE StorerKey = @cActStorer      
                  AND OrderKey = @cOrderkey      
                  AND SKU = @cSKU      
         
               SELECT @nPicked_QTY = CASE WHEN Status >= '5' THEN ISNULL(SUM(Qty), 0) ELSE 0 END      
               FROM dbo.PickDetail WITH (NOLOCK)      
               WHERE StorerKey = @cActStorer      
                  AND OrderKey = @cOrderkey      
                  AND SKU = @cSKU      
               GROUP BY Status      

               SELECT @nPacked_QTY = ISNULL(SUM(PD.Qty), 0) 
               FROM dbo.PackDetail PD WITH (NOLOCK)      
               JOIN dbo.packHeader PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
               WHERE PH.StorerKey = @cActStorer      
                  AND PH.OrderKey = @cOrderkey      
                  AND PD.SKU = @cSKU      

               SET @nSKUCounter = @nSKUCounter - 1    -- (james02)      
               
               SELECT @cPutawayzone = Putawayzone 
               FROM dbo.LOC WITH (NOLOCK) 
               WHERE LOC = @cLOC               
            END
            
            GOTO Display_Rec
         END
         ELSE
         BEGIN
            -- (james05)      
            SELECT TOP 1       
                @cOrderkey = OD.Orderkey,      
                @cSKU = OD.SKU,      
                @cConsigneekey = ISNULL(RTRIM(O.ConsigneeKey), ''),      
                @cPackUOM03 = OD.UOM, 
                @cLOC = PD.Loc            
            FROM dbo.PickDetail PD WITH (NOLOCK)       
            JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)      
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
            JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)    
            JOIN dbo.DropID D WITH (NOLOCK) ON (D.DropID = TD.DropID AND D.DropIDType = TD.PickMethod AND D.Loadkey = O.LoadKey) -- (ChewKP04)        
            WHERE TD.Storerkey = @cActStorer      
               AND TD.DropID =  @cToteNo      
               AND O.Facility = @cFacility      
               AND PD.OrderKey = @cPrevOrderkey      
               AND PD.SKU > @cSKU      
               AND O.Status NOT IN ('9', 'CANC') -- (ChewKP01)    
            ORDER BY PD.OrderKey, PD.SKU      
            
            IF @@ROWCOUNT = 0      
            BEGIN      
               SELECT TOP 1       
                   @cOrderkey = OD.Orderkey,      
                   @cSKU = OD.SKU,      
                   @cConsigneekey = ISNULL(RTRIM(O.ConsigneeKey), ''),      
                   @cPackUOM03 = OD.UOM, 
                   @cLOC = PD.Loc            
               FROM dbo.PickDetail PD WITH (NOLOCK)       
               JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)      
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
               JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
               JOIN dbo.DropID D WITH (NOLOCK) ON (D.DropID = TD.DropID AND D.DropIDType = TD.PickMethod AND D.Loadkey = O.LoadKey) -- (ChewKP04)          
               WHERE TD.Storerkey = @cActStorer      
                  AND TD.DropID =  @cToteNo      
                  AND O.Facility = @cFacility      
                  AND PD.OrderKey > @cPrevOrderkey      
                  AND O.Status NOT IN ('9', 'CANC') -- (ChewKP01)    
               ORDER BY PD.OrderKey, PD.SKU   

               IF @@rowcount = 0        
               BEGIN        
                  SET @cErrMsg = 'No More Records'        
                           
                  SET @nScn = @nScn         
                  SET @nStep = @nStep        
                  GOTO QUIT        
               END   
               
               SELECT @nTTL_QTY = ISNULL(SUM(Qty), 0)      
               FROM dbo.PickDetail WITH (NOLOCK)      
               WHERE StorerKey = @cActStorer      
                  AND OrderKey = @cOrderkey      
                  AND SKU = @cSKU      
         
               SELECT @nPicked_QTY = CASE WHEN Status >= '5' THEN ISNULL(SUM(Qty), 0) ELSE 0 END      
               FROM dbo.PickDetail WITH (NOLOCK)      
               WHERE StorerKey = @cActStorer      
                  AND OrderKey = @cOrderkey      
                  AND SKU = @cSKU      
               GROUP BY Status      

               SELECT @nPacked_QTY = ISNULL(SUM(PD.Qty), 0) 
               FROM dbo.PackDetail PD WITH (NOLOCK)      
               JOIN dbo.packHeader PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
               WHERE PH.StorerKey = @cActStorer      
                  AND PH.OrderKey = @cOrderkey      
                  AND PD.SKU = @cSKU      

               SELECT @cPutawayzone = Putawayzone 
               FROM dbo.LOC WITH (NOLOCK) 
               WHERE LOC = @cLOC               
            
               SET @nCounter = @nCounter + 1    -- (james02)    
               SET @nSKUCounter = 1             -- (james02)    
               SET @cPrevOrderkey = @cOrderkey  
               
               GOTO Display_Rec                       
            END
            ELSE      
            BEGIN      
               SELECT @nTTL_QTY = ISNULL(SUM(Qty), 0)      
               FROM dbo.PickDetail WITH (NOLOCK)      
               WHERE StorerKey = @cActStorer      
                  AND OrderKey = @cOrderkey      
                  AND SKU = @cSKU      
         
               SELECT @nPicked_QTY = CASE WHEN Status >= '5' THEN ISNULL(SUM(Qty), 0) ELSE 0 END      
               FROM dbo.PickDetail WITH (NOLOCK)      
               WHERE StorerKey = @cActStorer      
                  AND OrderKey = @cOrderkey      
                  AND SKU = @cSKU      
               GROUP BY Status      

               SELECT @nPacked_QTY = ISNULL(SUM(PD.Qty), 0) 
               FROM dbo.PackDetail PD WITH (NOLOCK)      
               JOIN dbo.packHeader PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
               WHERE PH.StorerKey = @cActStorer      
                  AND PH.OrderKey = @cOrderkey      
                  AND PD.SKU = @cSKU      

               SET @nSKUCounter = @nSKUCounter + 1    -- (james02)      
               
               SELECT @cPutawayzone = Putawayzone 
               FROM dbo.LOC WITH (NOLOCK) 
               WHERE LOC = @cLOC               
            END
            
            GOTO Display_Rec
         END
     
         SELECT @nTTL_QTY = ISNULL(SUM(Qty), 0)      
         FROM dbo.PickDetail WITH (NOLOCK)      
         WHERE StorerKey = @cActStorer      
            AND OrderKey = @cOrderkey      
            AND SKU = @cSKU      
   
         SELECT @nPicked_QTY = CASE WHEN Status >= '5' THEN ISNULL(SUM(Qty), 0) ELSE 0 END      
         FROM dbo.PickDetail WITH (NOLOCK)      
         WHERE StorerKey = @cActStorer      
            AND OrderKey = @cOrderkey      
            AND SKU = @cSKU      
         GROUP BY Status      

         SELECT @nPacked_QTY = ISNULL(SUM(PD.Qty), 0) 
         FROM dbo.PackDetail PD WITH (NOLOCK)      
         JOIN dbo.packHeader PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
         WHERE PH.StorerKey = @cActStorer      
            AND PH.OrderKey = @cOrderkey      
            AND PD.SKU = @cSKU      

         SET @nCounter = @nCounter + 1    -- (james02)      
         SET @nSKUCounter = 1    -- (james02)      
   
         SELECT @nSKUCnt = COUNT(DISTINCT PD.SKU)       
         FROM dbo.PickDetail PD WITH (NOLOCK)      
         JOIN dbo.TaskDetail TD WITH (NOLOCK)       
            ON (PD.StorerKey = TD.StorerKey AND PD.TaskDetailKey = TD.TaskDetailKey)      
         WHERE TD.Storerkey = @cActStorer        
            AND TD.DropID =  @cToteNo        
            AND PD.OrderKey = @cOrderkey      
   
         SET @cPrevOrderkey = @cOrderkey      
      END      

        
      IF @cOption = '9' -- Case ID        
      BEGIN        
         IF ISNULL(@cPrev, '') = '1' -- (james12)
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.UCC UCC WITH (NOLOCK)       
                       JOIN TaskDetail TD WITH (NOLOCK) ON (UCC.SourceKey = TD.TaskDetailKey)      
                       WHERE TD.StorerKey = @cActStorer       
                          AND TD.TaskType = 'DPK'      
                          AND UCC.UCCNO = @cToteNo)      
            BEGIN      
               SELECT TOP 1       
                   @cOrderkey = OD.Orderkey,      
                   @cSKU = OD.SKU,      
                   @cConsigneekey = ISNULL(RTRIM(O.ConsigneeKey), ''),      
                   @cPackUOM03 = OD.UOM,
                   @cLOC = PD.LOC      -- (james09)
               FROM dbo.PickDetail PD WITH (NOLOCK)       
               JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)      
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
               JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey) 
               JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID)       
               WHERE PD.Storerkey = @cActStorer      
                  AND PD.CaseID =  @cToteNo      
                  --AND PD.DropID =  @cPltDropID      
                  AND O.Facility = @cFacility      
                  AND PD.SKU < @cSKU      
                  AND PD.Status >= '3'      
                  AND PD.OrderKey = @cPrevOrderkey
               ORDER BY PD.SKU DESC     
         
               IF @@ROWCOUNT = 0      
               BEGIN      
                  SELECT TOP 1       
                      @cOrderkey = OD.Orderkey,      
                      @cSKU = OD.SKU,      
                      @cConsigneekey = ISNULL(RTRIM(O.ConsigneeKey), ''),      
                      @cPackUOM03 = OD.UOM,
                      @cLOC = PD.LOC      -- (james09)      
                  FROM dbo.PickDetail PD WITH (NOLOCK)       
                  JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)      
                  JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
                  JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey) 
                  JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID)       
                  WHERE PD.Storerkey = @cActStorer      
                     AND PD.CaseID =  @cToteNo      
                     --AND PD.DropID =  @cPltDropID      
                     AND O.Facility = @cFacility      
                     AND PD.Status >= '3'      
                     AND PD.OrderKey < @cPrevOrderkey      
                  ORDER BY PD.OrderKey DESC, PD.SKU      
         
                  IF @@rowcount = 0        
                  BEGIN        
                     SET @cErrMsg = 'No More Records'        
                              
                     SET @nScn = @nScn         
                     SET @nStep = @nStep        
                     GOTO QUIT        
                  END        
         
                  SET @nCounter = @nCounter - 1    -- (james02)      
                  SET @cPrevOrderkey = @cOrderkey        
         
                  SELECT @nTTL_QTY = ISNULL(SUM(Qty), 0)      
                  FROM dbo.PickDetail WITH (NOLOCK)      
                  WHERE StorerKey = @cActStorer      
                     AND OrderKey = @cOrderkey      
                     AND SKU = @cSKU      
   --                  AND CaseID = @cToteNo   -- (james06)      
         
                  SELECT @nPicked_QTY = CASE WHEN Status IN ('3', '5', '9') THEN ISNULL(SUM(Qty), 0) ELSE 0 END      
                  FROM dbo.PickDetail WITH (NOLOCK)      
                  WHERE StorerKey = @cActStorer      
                     AND OrderKey = @cOrderkey      
                     AND SKU = @cSKU      
   --                  AND CaseID = @cToteNo   -- (james06)      
                  GROUP BY Status      

                  SELECT @nPacked_QTY = ISNULL(SUM(PD.Qty), 0) 
                  FROM dbo.PackDetail PD WITH (NOLOCK)      
                  JOIN dbo.packHeader PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
                  WHERE PH.StorerKey = @cActStorer      
                     AND PH.OrderKey = @cOrderkey      
                     AND PD.SKU = @cSKU      

                  SELECT @nRecCnt = COUNT(DISTINCT PD.OrderKey)       
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.TaskDetail TD WITH (NOLOCK)       
                     ON (PD.StorerKey = TD.StorerKey AND PD.TaskDetailKey = TD.TaskDetailKey)
                  JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID)                        
                  WHERE PD.Storerkey = @cActStorer        
                     AND PD.CaseID =  @cToteNo      
                     --AND PD.DropID =  @cPltDropID      
         
                  SELECT @nSKUCnt = COUNT(DISTINCT PD.SKU)       
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.TaskDetail TD WITH (NOLOCK)       
                     ON (PD.StorerKey = TD.StorerKey AND PD.TaskDetailKey = TD.TaskDetailKey) 
                  JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID)                         
                  WHERE TD.Storerkey = @cActStorer        
                     AND PD.CaseID =  @cToteNo      
                     --AND PD.DropID =  @cPltDropID      
                     AND PD.OrderKey = @cOrderkey  

                  SELECT @cPutawayzone = Putawayzone FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cLOC  -- (james09)    
               END                                                      
               ELSE      
               BEGIN      
                  SELECT @nTTL_QTY = ISNULL(SUM(Qty), 0)      
                  FROM dbo.PickDetail WITH (NOLOCK)      
                  WHERE StorerKey = @cActStorer      
                     AND OrderKey = @cOrderkey      
                     AND SKU = @cSKU      
                     AND CaseID = @cToteNo   -- (james06)      
         
                  SELECT @nPicked_QTY = CASE WHEN STATUS IN ('3', '5', '9') THEN ISNULL(SUM(Qty), 0) ELSE 0 END      
                  FROM dbo.PickDetail WITH (NOLOCK)      
                  WHERE StorerKey = @cActStorer      
                     AND OrderKey = @cOrderkey      
                     AND SKU = @cSKU      
                     AND CaseID = @cToteNo   -- (james06)      
                  GROUP BY Status      

                  SELECT @nPacked_QTY = ISNULL(SUM(PD.Qty), 0) 
                  FROM dbo.PackDetail PD WITH (NOLOCK)      
                  JOIN dbo.packHeader PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
                  WHERE PH.StorerKey = @cActStorer      
                     AND PH.OrderKey = @cOrderkey      
                     AND PD.SKU = @cSKU      

                  SELECT @nRecCnt = COUNT(DISTINCT PD.OrderKey)       
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.TaskDetail TD WITH (NOLOCK)       
                     ON (PD.StorerKey = TD.StorerKey AND PD.TaskDetailKey = TD.TaskDetailKey) 
                  JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID)       
                  WHERE PD.Storerkey = @cActStorer        
                     AND PD.CaseID =  @cToteNo      
                     --AND PD.DropID =  @cPltDropID      
         
                  SELECT @nSKUCnt = COUNT(DISTINCT PD.SKU)       
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.TaskDetail TD WITH (NOLOCK)       
                     ON (PD.StorerKey = TD.StorerKey AND PD.TaskDetailKey = TD.TaskDetailKey)
                  JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID)       
                  WHERE TD.Storerkey = @cActStorer        
                     AND PD.CaseID =  @cToteNo      
                     --AND PD.DropID =  @cPltDropID      
                     AND PD.OrderKey = @cOrderkey      

                  SELECT @cPutawayzone = Putawayzone FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cLOC  -- (james09)
               END      
            END      
            ELSE      
            BEGIN      
               SET @cErrMsg = 'No More Records'        
                        
               SET @nScn = @nScn         
               SET @nStep = @nStep        
               GOTO QUIT      
            END      
         END
         ELSE
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.UCC UCC WITH (NOLOCK)       
                       JOIN TaskDetail TD WITH (NOLOCK) ON (UCC.SourceKey = TD.TaskDetailKey)      
                       WHERE TD.StorerKey = @cActStorer       
                          AND TD.TaskType = 'DPK'      
                          AND UCC.UCCNO = @cToteNo)      
            BEGIN      
               SELECT TOP 1       
                   @cOrderkey = OD.Orderkey,      
                   @cSKU = OD.SKU,      
                   @cConsigneekey = ISNULL(RTRIM(O.ConsigneeKey), ''),      
                   @cPackUOM03 = OD.UOM,
                   @cLOC = PD.LOC      -- (james09)
               FROM dbo.PickDetail PD WITH (NOLOCK)       
               JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)      
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
               JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey) 
               JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID)       
               WHERE PD.Storerkey = @cActStorer      
                  AND PD.CaseID =  @cToteNo      
                  --AND PD.DropID =  @cPltDropID      
                  AND O.Facility = @cFacility      
                  AND PD.SKU > @cSKU      
                  AND PD.Status >= '3'      
                  AND PD.OrderKey = @cPrevOrderkey
               ORDER BY PD.OrderKey, PD.SKU      
         
               IF @@ROWCOUNT = 0      
               BEGIN      
                  SELECT TOP 1       
                      @cOrderkey = OD.Orderkey,      
                      @cSKU = OD.SKU,      
                      @cConsigneekey = ISNULL(RTRIM(O.ConsigneeKey), ''),      
                      @cPackUOM03 = OD.UOM,
                      @cLOC = PD.LOC      -- (james09)      
                  FROM dbo.PickDetail PD WITH (NOLOCK)       
                  JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)      
                  JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
                  JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey) 
                  JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID)       
                  WHERE PD.Storerkey = @cActStorer      
                     AND PD.CaseID =  @cToteNo      
                     --AND PD.DropID =  @cPltDropID      
                     AND O.Facility = @cFacility      
                     AND PD.Status >= '3'      
                     AND PD.OrderKey > @cPrevOrderkey      
                  ORDER BY PD.OrderKey, PD.SKU      
         
                  IF @@rowcount = 0        
                  BEGIN        
                     SET @cErrMsg = 'No More Records'        
                              
                     SET @nScn = @nScn         
                     SET @nStep = @nStep        
                     GOTO QUIT        
                  END        
         
                  SET @nCounter = @nCounter + 1    -- (james02)  
                  SET @nSKUCounter = 1             -- (james02)      
                  SET @cPrevOrderkey = @cOrderkey        
         
                  SELECT @nTTL_QTY = ISNULL(SUM(Qty), 0)      
                  FROM dbo.PickDetail WITH (NOLOCK)      
                  WHERE StorerKey = @cActStorer      
                     AND OrderKey = @cOrderkey      
                     AND SKU = @cSKU      
   --                  AND CaseID = @cToteNo   -- (james06)      
         
                  SELECT @nPicked_QTY = CASE WHEN Status IN ('3', '5', '9') THEN ISNULL(SUM(Qty), 0) ELSE 0 END      
                  FROM dbo.PickDetail WITH (NOLOCK)      
                  WHERE StorerKey = @cActStorer      
                     AND OrderKey = @cOrderkey      
                     AND SKU = @cSKU      
   --                  AND CaseID = @cToteNo   -- (james06)      
                  GROUP BY Status      

                  SELECT @nPacked_QTY = ISNULL(SUM(PD.Qty), 0) 
                  FROM dbo.PackDetail PD WITH (NOLOCK)      
                  JOIN dbo.packHeader PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
                  WHERE PH.StorerKey = @cActStorer      
                     AND PH.OrderKey = @cOrderkey      
                     AND PD.SKU = @cSKU      

                  SELECT @nRecCnt = COUNT(DISTINCT PD.OrderKey)       
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.TaskDetail TD WITH (NOLOCK)       
                     ON (PD.StorerKey = TD.StorerKey AND PD.TaskDetailKey = TD.TaskDetailKey)
                  JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID)                        
                  WHERE PD.Storerkey = @cActStorer        
                     AND PD.CaseID =  @cToteNo      
                     --AND PD.DropID =  @cPltDropID      
         
                  SELECT @nSKUCnt = COUNT(DISTINCT PD.SKU)       
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.TaskDetail TD WITH (NOLOCK)       
                     ON (PD.StorerKey = TD.StorerKey AND PD.TaskDetailKey = TD.TaskDetailKey) 
                  JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID)                         
                  WHERE TD.Storerkey = @cActStorer        
                     AND PD.CaseID =  @cToteNo      
                     --AND PD.DropID =  @cPltDropID      
                     AND PD.OrderKey = @cOrderkey  

                  SELECT @cPutawayzone = Putawayzone FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cLOC  -- (james09)    
               END                                                      
               ELSE      
               BEGIN      
                  SELECT @nTTL_QTY = ISNULL(SUM(Qty), 0)      
                  FROM dbo.PickDetail WITH (NOLOCK)      
                  WHERE StorerKey = @cActStorer      
                     AND OrderKey = @cOrderkey      
                     AND SKU = @cSKU      
                     AND CaseID = @cToteNo   -- (james06)      
         
                  SELECT @nPicked_QTY = CASE WHEN STATUS IN ('3', '5', '9') THEN ISNULL(SUM(Qty), 0) ELSE 0 END      
                  FROM dbo.PickDetail WITH (NOLOCK)      
                  WHERE StorerKey = @cActStorer      
                     AND OrderKey = @cOrderkey      
                     AND SKU = @cSKU      
                     AND CaseID = @cToteNo   -- (james06)      
                  GROUP BY Status      

                  SELECT @nPacked_QTY = ISNULL(SUM(PD.Qty), 0) 
                  FROM dbo.PackDetail PD WITH (NOLOCK)      
                  JOIN dbo.packHeader PH WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
                  WHERE PH.StorerKey = @cActStorer      
                     AND PH.OrderKey = @cOrderkey      
                     AND PD.SKU = @cSKU      

                  SELECT @nRecCnt = COUNT(DISTINCT PD.OrderKey)       
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.TaskDetail TD WITH (NOLOCK)       
                     ON (PD.StorerKey = TD.StorerKey AND PD.TaskDetailKey = TD.TaskDetailKey) 
                  JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID)       
                  WHERE PD.Storerkey = @cActStorer        
                     AND PD.CaseID =  @cToteNo      
                     --AND PD.DropID =  @cPltDropID      
         
                  SELECT @nSKUCnt = COUNT(DISTINCT PD.SKU)       
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.TaskDetail TD WITH (NOLOCK)       
                     ON (PD.StorerKey = TD.StorerKey AND PD.TaskDetailKey = TD.TaskDetailKey)
                  JOIN dbo.UCC UCC WITH (NOLOCK) ON (UCC.Sourcekey = TD.TaskDetailKey AND UCC.UCCNo = PD.CaseID)       
                  WHERE TD.Storerkey = @cActStorer        
                     AND PD.CaseID =  @cToteNo      
                     --AND PD.DropID =  @cPltDropID      
                     AND PD.OrderKey = @cOrderkey      

                  SELECT @cPutawayzone = Putawayzone FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cLOC  -- (james09)
               END      
            END      
            ELSE      
            BEGIN      
               SET @cErrMsg = 'No More Records'        
                        
               SET @nScn = @nScn         
               SET @nStep = @nStep        
               GOTO QUIT      
            END      
         END
      END        

      Display_Rec:
      SELECT @cCompany1     = LEFT(RTRIM(Company), 20),        
             @cCompany2     = SUBSTRING(RTRIM(Company), 21,20)        
      FROM dbo.STORER WITH (NOLOCK)        
      WHERE Storerkey = @cConsigneekey         
      AND Type = '2'        
        
      SELECT @cSKUDescr = RTRIM(DESCR)        
      FROM dbo.SKU WITH (NOLOCK)        
      WHERE Storerkey = @cActStorer        
      AND   SKU = @cSKU        

      -- (james11)
      SELECT TOP 1 @cOrderGroup = OrderGroup 
      FROM Orders WITH (NOLOCK) 
      WHERE StorerKey = @cActStorer
      AND   OrderKey = @cOrderkey

      --prepare next screen variable        
      SET @cOutField01 = @cOrderkey        
      SET @cOutField02 = CASE WHEN ISNULL(RTRIM(@cConsigneekey), '') = '' THEN 'ECOMM' + '-' + @cOrderGroup
                              ELSE ISNULL(RTRIM(@cConsigneekey), '') + '-' + ISNULL(RTRIM(@cPutawayzone),'') + '-' + @cOrderGroup END -- (james09/11)     
      SET @cOutField03 = @cCompany1         
      SET @cOutField04 = @cCompany2        
      SET @cOutField05 = @cSKU        
      SET @cOutField06 = ISNULL(LEFT(RTRIM(@cSKUDescr), 20), '')        
      SET @cOutField07 = ISNULL(SUBSTRING(RTRIM(@cSKUDescr), 21,20), '')        
      SET @cOutField08 = @cPackUOM03         
      SET @cOutField09 = CAST(@nTTL_QTY AS INT)        
      SET @cOutField10 = CAST(@nPicked_QTY AS INT)         
      SET @cOutField11 = RTRIM(CAST(@nCounter AS NVARCHAR( 5))) + '/' + CAST(@nRecCnt AS NVARCHAR( 5))      
      SET @cOutField12 = RTRIM(CAST(@nSKUCounter AS NVARCHAR( 5))) + '/' + CAST(@nSKUCnt AS NVARCHAR( 5))      
      SET @cOutField13 = CAST(@nPacked_QTY AS INT)         
      SET @cOutField14 = ''   -- (james12) 

      SET @nScn = @nScn         
      SET @nStep = @nStep        
   END        
        
   IF @nInputKey = 0 -- ESC        
   BEGIN        
      SET @cOutField01 = @cToteNo        
      SET @cOutField02 = @cTaskType         
      SET @cOutField03 = @cReason         
      SET @cOutField04 = @cLastUser         
      SET @cOutField05 = @cLastZone        
      SET @cOutField06 = @cFinalZone        
      SET @cOutField07 = ''        
      SET @cOutField08 = ''        
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
--      SET @cActStorer     = '' -- (james01)        
      SET @cCompany1      = ''        
      SET @cCompany2      = ''        
--      SET @cPltDropID     = '' -- (james01)        
      SET @nOrdQty        = 0        
      SET @nActQty        = 0        
      SET @cOrgPltDropID  = ''  -- (ChewKP02)        
        
      SET @nScn = @nScn - 1        
      SET @nStep = @nStep - 1        
   END    
   GOTO Quit
   
   Step_4_Fail:        
   BEGIN        
      SET @cOption = ''        
        
      SET @cOutField14 = ''        
   END            
   GOTO Quit        
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
                
       V_Orderkey         = @cOrderKey,             
       V_ConsigneeKey     = @cConsigneekey,         
       V_SKU              = @cSKU,                  
       V_SKUDescr         = @cSKUDescr,             
       V_UOM              = @cPackUOM03,            
       V_String1          = @cToteNo,              
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
             
       V_Integer1         = @nOrdQty,               
       V_Integer2         = @nActQty,
       V_Integer3         = @nRecCnt,        
       V_Integer4         = @nCounter,        
       V_Integer5         = @nSKUCnt,        
       V_Integer6         = @nSKUCounter,        
      
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