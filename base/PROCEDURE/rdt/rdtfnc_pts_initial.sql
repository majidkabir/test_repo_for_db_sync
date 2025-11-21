SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/            
/* Store procedure: rdtfnc_PTS_Initial                                       */            
/* Copyright      : IDS                                                      */            
/*                                                                           */            
/* Purpose: SOS#317259 - User scan the tote and determine which module to use*/            
/*                     - If DropID.DropIDType = 'C' then PTS store sort      */            
/*                     - If DropID.DropIDType = 'PIECE' then tote conso      */  
/*                     - If certain PTS is setup in CODELKUP with listname   */     
/*                       PTS_INI then goto screen 10 in Tote conso (func=973)*/
/*                                                                           */       
/* Modifications log:                                                        */            
/*                                                                           */            
/* Date       Rev  Author   Purposes                                         */            
/* 2014-08-05 1.0  James    SOS317259 - Created                              */ 
/* 2014-09-02 1.1  James    SOS319877 - Add international order processing   */
/*                                      logic (james01)                      */
/* 2014-10-01 1.2  James    Bug fix. Get only PTSLOC for those not packed SPK*/
/*                          task (james02)                                   */
/* 2016-09-30 1.3  Ung      Performance tuning                               */
/* 2017-08-30 1.4  JihHaur  IN00448091 - Added PD.DropID = TD.DropID (JH01)  */
/* 2018-11-07 1.5  TungGH   Performance                                      */  
/*****************************************************************************/              
CREATE PROC [RDT].[rdtfnc_PTS_Initial](                
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
   @nInputKey           NVARCHAR( 3),                
   @cPrinter            NVARCHAR( 10),     
   @cPrinter_Paper      NVARCHAR( 10), 

   @cUserName           NVARCHAR( 18),                
                
   @cStorerKey          NVARCHAR( 15),                
   @cFacility           NVARCHAR( 5),                
                
   @cToteNo             NVARCHAR( 20),    
   @cStatus             NVARCHAR( 10),    
   @cDropIDType         NVARCHAR( 10),    
   @cType               NVARCHAR( 10),    
   @cDefaultToteLength  NVARCHAR( 2),  
   @cPickMethod         NVARCHAR( 10),  
   @cLabelPrinted       NVARCHAR( 10),  
   @cManifestPrinted    NVARCHAR( 10),  
   @cDropIDStatus       NVARCHAR( 10),  
   @cConsigneekey       NVARCHAR( 15),  
   @cPTSLOC             NVARCHAR( 10),  
   @cPutawayZone        NVARCHAR( 10),  
   @cPZ_PaperPrinter    NVARCHAR( 10), 
   @cPZ_LabelPrinter    NVARCHAR( 10), 
   @cLoadKey            NVARCHAR( 10), 
   @cOrderKey           NVARCHAR( 10), 
   @cUOM                NVARCHAR( 10), 
   @cCaseID             NVARCHAR( 20), 
   @cSKU                NVARCHAR( 20), 
   @cSKUDescr           NVARCHAR( 60), 
   @cLoc                NVARCHAR( 10), 
   @cPTS_Station        NVARCHAR( 10), 
   @nTotal_QTY          INT, 
   @nRemain_QTY         INT, 
   @nTranCount          INT, 
   @cPTSLOC1            NVARCHAR( 10), --james01
   @cPTSLOC2            NVARCHAR( 10), --james01
   @cPTSLOC3            NVARCHAR( 10), --james01
   @nRow                INT,           --james01


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
   @cPutawayZone     = V_Zone,  
   @cCaseID          = V_CaseID,      
   @cSKU             = V_SKU, 

   @cToteNo          = V_String1, 

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
IF @nFunc = 1811 
BEGIN 
   IF @nStep = 0 GOTO Step_0        -- Menu. Func = 1811 
   IF @nStep = 1 GOTO Step_1        -- Scn = 3940 -- Zone/Printers (SCN1) 
   IF @nStep = 2 GOTO Step_2        -- Scn = 3941 -- Tote (SCN2) 
END                
                
RETURN -- Do nothing if incorrect step                

/********************************************************************************
Step_Start. Func = 544. Screen 0.
********************************************************************************/
Step_0:
BEGIN
   SET @cFieldAttr01 = ''
   SET @cFieldAttr02 = ''
   SET @cFieldAttr03 = ''
   SET @cFieldAttr04 = ''
   SET @cFieldAttr05 = ''
   SET @cFieldAttr06 = ''
   SET @cFieldAttr07 = ''
   SET @cFieldAttr08 = ''
   SET @cFieldAttr09 = ''
   SET @cFieldAttr10 = ''
   SET @cFieldAttr11 = ''
   SET @cFieldAttr12 = ''
   SET @cFieldAttr13 = ''
   SET @cFieldAttr14 = ''
   SET @cFieldAttr15 = ''

   -- Prev next screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''

   EXEC rdt.rdtSetFocusField @nMobile, 1

   SET @nScn = 3940
   SET @nStep = 1
END
GOTO Quit

/********************************************************************************      
Step 1. Scn = 3940.      
   PTZONE         (field01, input)      
   LABEL PRINTER  (field01, input)      
   PAPER PRINTER  (field01, input)      
********************************************************************************/      
Step_1:      
BEGIN      
   IF @nInputKey = 1 --ENTER      
   BEGIN      
      SET @cPutawayZone = @cInField01      
      SET @cPZ_LabelPrinter = @cInField02      
      SET @cPZ_PaperPrinter = @cInField03      
      
      IF ISNULL(RTRIM(@cPutawayZone),'') = ''      
      BEGIN      
         SET @nErrNo = 50351      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'BAD PTZONE'      
         GOTO Step_1_Fail      
      END      
      
      IF NOT EXISTS(SELECT 1 FROM PutawayZone pz WITH (NOLOCK)      
                    WHERE pz.PutawayZone = @cPutawayZone)      
      BEGIN      
       SET @nErrNo = 50352      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'BAD PTZONE'      
         GOTO Step_1_Fail      
      END      
      
      -- If Paper printer scan in       
      IF ISNULL(@cPZ_PaperPrinter, '') <> ''      
      BEGIN      
         -- Check if printer setup correctly      
         IF NOT EXISTS(SELECT 1 FROM RDT.RDTPrinter (NOLOCK) WHERE PrinterID = RTRIM(@cPZ_PaperPrinter))      
         BEGIN      
            SET @nErrNo = 50353      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV PAPER PRT'      
            GOTO Step_1_Fail      
         END      
      
         -- Overwrite existing printer with the one scanned in      
         UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET      
            Printer_Paper = @cPZ_PaperPrinter      
         WHERE MOBILE = @nMOBILE      
      
         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 50354      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PRT FAIL'      
            GOTO Step_1_Fail      
         END      
      
         SET @cPrinter_Paper = @cPZ_PaperPrinter      
      END      
      
      -- If Paper printer scan in       
      IF ISNULL(@cPZ_LabelPrinter, '') <> ''      
      BEGIN      
         -- Check if printer setup correctly      
         IF NOT EXISTS(SELECT 1 FROM RDT.RDTPrinter (NOLOCK) WHERE PrinterID = RTRIM(@cPZ_LabelPrinter))      
         BEGIN      
            SET @nErrNo = 50355      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV LABEL PRT'      
            GOTO Step_1_Fail      
         END      
      
         -- Overwrite existing printer with the one scanned in      
         UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET      
            Printer = @cPZ_LabelPrinter      
         WHERE MOBILE = @nMOBILE      
      
         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 50356      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PRT FAIL'      
            GOTO Step_1_Fail      
         END      
      
         SET @cPrinter = @cPZ_LabelPrinter      
      END      
      
      IF ISNULL(@cPrinter_Paper, '') = ''      
      BEGIN      
         SET @nErrNo = 50357      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPaperPrinter      
         GOTO Step_1_Fail      
      END      

      -- Prev next screen var
      SET @cToteNo = ''
      SET @cOutField01 = ''

      -- Goto Tote Screen     
      SET @nScn  = @nScn + 1      
      SET @nStep = @nStep + 1      
      
   END -- @nInputKey = 1   

   IF @nInputKey = 0 --ESC      
   BEGIN      
      -- Back to menu      
      SET @nFunc = @nMenu      
      SET @nScn  = @nMenu      
      SET @nStep = 0      
      
      SET @cPutawayZone = ''      
      SET @cOutField01  = '' -- PTZone      
   END --ESC      
      
   GOTO Quit      
      
   Step_1_Fail:      
   BEGIN      
      SET @cPutawayZone = ''      
      SET @cOutField01 = '' -- PTZone      
   END      
      
END -- Step_PTZone      
GOTO Quit      

/********************************************************************************                
Step 2. Scn = 3941. Screen 2.
    SCAN TOTE (Field01, input)                
********************************************************************************/                
Step_2:                
BEGIN                
   IF @nInputKey = 1 -- ENTER                
   BEGIN                
      -- Screen mapping                
      SET @cToteNo   = @cInField01                
                
      /****************************                
       VALIDATION                 
      ****************************/                
      IF ISNULL( @cToteNo, '') = ''                
      BEGIN                
         SET @nErrNo = 50358 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOTE NO  req                
         GOTO Step_2_Fail                  
      END                 

      SET @cStatus = ''
      SET @cDropIDType = ''
      SET @cType = ''

      SELECT @cStatus = ISNULL( [Status], ''), @cDropIDType = DropIDType 
      FROM dbo.DropID WITH (NOLOCK) 
      WHERE DropID = @cToteNo 

      IF @@ROWCOUNT = 0
      BEGIN  
--         SELECT @cStatus = ISNULL( [Status], ''), @cDropIDType = DropIDType
--         FROM dbo.DropID WITH (NOLOCK) 
--         WHERE SUBSTRING( DROPID, 1, LEN( RTRIM( DROPID)) - 4) = @cToteNo

         SELECT @cStatus = ISNULL( [Status], ''), @cDropIDType = DropIDType 
         FROM dbo.DROPIDDETAIL  WITH (NOLOCK)      
         JOIN dbo.DROPID WITH (NOLOCK) ON DROPIDDETAIL.Dropid = DROPID.Dropid      
         WHERE ChildID = @cToteNo
                        
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 50359 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID TOTE                
            GOTO Step_2_Fail                  
         END
         ELSE
         BEGIN
            IF @cDropIDType = 'C'
               SET @cType = 'DPK'
            ELSE
            BEGIN
               SET @nErrNo = 50360 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID TOTE                
               GOTO Step_2_Fail                  
            END
         END
      END   
      ELSE
      BEGIN
         IF @cStatus = '0' AND @cDropIDType = 'PIECE'
            SET @cType = 'SPK'
         ELSE
         BEGIN
            SET @nErrNo = 50361 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID TOTE                
            GOTO Step_2_Fail                  
         END
      END
      
      /****************************                
       prepare next screen variable                
      ****************************/                
      IF @cType = 'SPK' -- goto tote consolidation module
      BEGIN

         -- Check the length of tote no (james03); 0 = No Check  
         SET @cDefaultToteLength  = rdt.RDTGetConfig( @nFunc, 'DefaultToteLength', @cStorerKey)  
         IF ISNULL(@cDefaultToteLength, '') = ''  
         BEGIN  
            SET @cDefaultToteLength = '8'  -- make it default to 8 digit if not setup  
         END  
     
         IF @cDefaultToteLength <> '0'  
         BEGIN  
            IF LEN(RTRIM(@cToteNo)) <> @cDefaultToteLength  
            BEGIN  
               SET @nErrNo = 50362  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TOTENO LEN  
               GOTO Step_2_Fail                  
            END  
         END  
     
         IF EXISTS (SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK)  
                    WHERE Listname = 'XValidTote'  
                       AND Code = SUBSTRING(RTRIM(@cToteNo), 1, 1))  
         BEGIN  
            SET @nErrNo = 50363  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TOTE NO  
            GOTO Step_2_Fail                  
         END  
     
         -- Get the Pick Method for Tote   
         SET @cPickMethod=''  
         SET @cLabelPrinted=''  
         SET @cManifestPrinted=''  
         SET @cDropIDStatus=''  
           
         SELECT @cPickMethod = DropIDType,  
                @cLabelPrinted = LabelPrinted,   
                @cManifestPrinted = ManifestPrinted,  
                @cDropIDStatus=[Status]  
         FROM   DROPID WITH (NOLOCK)   
         WHERE  DROPID = @cToteNo   
            
         IF @cPickMethod <> 'PIECE'   
         BEGIN  
            SET @nErrNo = 50364  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Tote  
            GOTO Step_2_Fail                  
         END  
     
         IF @cManifestPrinted = 'Y' AND @cDropIDStatus <> '9'  
         BEGIN  
            SET @nErrNo = 50365  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Manifest Print  
            GOTO Step_2_Fail                  
       END  
           
         IF @cLabelPrinted = 'Y' AND @cDropIDStatus <> '9'  
         BEGIN  
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE DropID = @cToteNo )   
            BEGIN  
               SET @nErrNo = 50366  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Tote  
               GOTO Step_2_Fail                  
            END            
         END  
         ELSE  
         BEGIN  
            IF NOT EXISTS (SELECT 1  
                           FROM dbo.PickDetail PD WITH (NOLOCK)     
                           JOIN dbo.ORDERS o WITH (NOLOCK) ON o.OrderKey = PD.OrderKey     
                           JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey   
                           JOIN dbo.DropId DI WITH (NOLOCK) ON DI.DropID = PD.DropID AND DI.Loadkey = O.LoadKey  -- (SHONGxx)  
                           WHERE PD.StorerKey = @cStorerKey                  
                             AND PD.DropID = @cToteNo                  
                             AND PD.Status >= '5'                  
                             AND PD.Status < '9'    
                             AND PD.Qty > 0          
                             AND TD.PickMethod = 'PIECE'        
                             AND TD.Status = '9'       
                             AND O.Status < '9' )  
            BEGIN                  
               SET @nErrNo = 50367                  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Cancel                  
               GOTO Step_2_Fail                  
            END                    
         END  
           
         IF @cDropIDStatus = '9'  
         BEGIN  
            SET @nErrNo = 50368  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Closed  
            GOTO Step_2_Fail                  
       END  
           
         IF EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)                   
                    JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey AND PD.DropID = TD.DropID  --(JH01) add AND PD.DropID = TD.DropID
                    JOIN dbo.Dropid d WITH (NOLOCK) ON d.Dropid = TD.DropID AND d.Loadkey = TD.LoadKey             
                    WHERE PD.Storerkey = @cStorerkey     
                    AND TD.DropID = @cToteNo     
                    AND PD.Status < '5'            
                    AND PD.Qty > 0          
                    AND TD.PickMethod = 'PIECE'        
                    AND TD.Status = '9')                       
         OR NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)                  
                        WHERE Storerkey = @cStorerkey AND DropID = @cToteNo)                           
         BEGIN          
            SET @nErrNo = 50369                 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToteNotPicked     
            GOTO Step_2_Fail                  
         END          
           
           
         IF NOT EXISTS (SELECT 1   
         FROM PICKDETAIL PD (NOLOCK)   
         INNER JOIN ORDERS O WITH (NOLOCK) ON PD.ORDERKEY = O.ORDERKEY    
         INNER JOIN DROPID DROPID WITH (NOLOCK) ON PD.DROPID = DROPID.DROPID AND O.LOADKEY = DROPID.LOADKEY  
         WHERE PD.DropID = @cToteNo  
            AND O.StorerKey = @cStorerKey  
            AND O.Status NOT IN ('9', 'CANC'))  
         BEGIN  
            SET @nErrNo = 50370  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Shipped  
            GOTO Step_2_Fail                  
         END  
     
         SELECT TOP 1 @cConsigneekey = O.ConsigneeKey, @cLoadKey = O.LoadKey, @cPTSLOC = TD.TOLOC  
         FROM dbo.PICKDETAIL PD (NOLOCK)   
         INNER JOIN dbo.ORDERS O WITH (NOLOCK) ON PD.ORDERKEY = O.ORDERKEY    
         INNER JOIN dbo.DROPID DROPID WITH (NOLOCK) ON PD.DROPID = DROPID.DROPID AND O.LOADKEY = DROPID.LOADKEY  
         INNER JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey   
         WHERE PD.DropID = @cToteNo  
            AND O.StorerKey = @cStorerKey  
            AND O.Status NOT IN ('9', 'CANC')  
            AND ISNULL( PD.ALTSKU, '') = ''  -- (james02)
     
         IF ISNULL(@cPTSLOC, '') = ''  
         BEGIN  
            SELECT TOP 1 @cPTSLOC = LOC   
            FROM dbo.StoreToLocDetail WITH (NOLOCK)   
            WHERE ConsigneeKey = @cConsigneekey  
            AND   Status = '1'  
         END  

         SELECT @cPTS_Station = ISNULL( PutawayZone, '')
         FROM dbo.LOC WITH (NOLOCK) 
         WHERE LOC = @cPTSLOC
         AND Facility = @cFacility

         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
                     WHERE ListName = 'PTS_INT' 
                     AND   Code = @cPTS_Station
                     AND   StorerKey = @cStorerKey)         
         BEGIN
            SET @nRow = 1
            SELECT TOP 3  @cPTSLOC1 = CASE WHEN @nRow = 1 THEN LOC ELSE @cPTSLOC1 END,
                          @cPTSLOC2 = CASE WHEN @nRow = 2 THEN LOC ELSE @cPTSLOC2 END,
                          @cPTSLOC3 = CASE WHEN @nRow = 3 THEN LOC ELSE @cPTSLOC3 END,
                          @nRow = @nRow + 1 
            FROM dbo.StoreToLocDetail WITH (NOLOCK) 
            WHERE Consigneekey = @cConsigneekey
            ORDER BY LOC

            SET @cOutField01 = @cToteNo  
            SET @cOutField02 = ''  
            SET @cOutField03 = ''  
            SET @cOutField04 = ''   
            SET @cOutField05 = ''   
            SET @cOutField06 = @cConsigneekey
            SET @cOutField07 = @cPTSLOC1
            SET @cOutField08 = @cPTSLOC2
            SET @cOutField09 = @cPTSLOC3
            
            SET @nFunc = 973
            SET @nStep = 10   
            SET @nScn  = 2469   

            EXEC rdt.rdtSetFocusField @nMobile, 2  -- SKU 

            GOTO Quit
         END
         ELSE
         BEGIN
            SET @cOutField01 = ''  
            SET @cOutField02 = @cConsigneekey  
            SET @cOutField03 = @cPTSLOC  
            SET @cOutField04 = @cToteNo   

            SET @nFunc = 973
            SET @nStep = 8   
            SET @nScn  = 2467   
            
            GOTO Quit
         END
      END

      IF @cType = 'DPK' -- goto tote consolidation module
      BEGIN
      
         SELECT TOP 1      
                @cOrderKey  = PICKDETAIL.OrderKey,      
                @cSKU       = PICKDETAIL.Sku,      
                @cSKUDescr  = SKU.DESCR,      
                @cLoc       = PICKDETAIL.Loc    
         FROM dbo.PICKDETAIL WITH (NOLOCK)      
         JOIN dbo.ORDERS WITH (NOLOCK)       
              ON PICKDETAIL.StorerKey = ORDERS.StorerKey AND PICKDETAIL.OrderKey = ORDERS.OrderKey      
         JOIN dbo.LOC WITH (NOLOCK) ON PICKDETAIL.LOC = LOC.LOC      
         JOIN dbo.SKU WITH (NOLOCK)      
              ON PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku      
         WHERE PICKDETAIL.CaseID = @cToteNo      
            AND PICKDETAIL.Storerkey = @cStorerKey      
            AND PICKDETAIL.Status = '3'      
            AND LOC.PUTAWAYZONE = @cPutawayZone      
         ORDER BY LOC.LogicalLocation, LOC.LOC, ORDERS.ConsigneeKey      
      
         SELECT @nTotal_QTY = ISNULL(SUM(Qty), 0)      
         FROM dbo.UCC WITH (NOLOCK)      
         WHERE UCCNo = @cToteNo      
            AND Storerkey = @cStorerKey      
            AND SKU = @cSKU      

      
         IF @nTotal_QTY = 0      
         BEGIN      
            SET @nErrNo = 50373      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Case Qty      
            EXEC rdt.rdtSetFocusField @nMobile, 1      
            GOTO Step_2_Fail      
         END      
      
         SELECT @nRemain_Qty = ISNULL(SUM(Qty), 0)      
         FROM dbo.PickDetail WITH (NOLOCK)      
         WHERE CaseID = @cToteNo      
            AND Storerkey = @cStorerKey      
            AND Status = '3'      
      
         IF @nRemain_Qty = 0      
         BEGIN      
            SET @nErrNo = 50374      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Qty To Sort      
            EXEC rdt.rdtSetFocusField @nMobile, 1      
            GOTO Step_2_Fail      
         END      
      
         SELECT @cUOM = PackUOM3      
         FROM dbo.SKU SKU WITH (NOLOCK)      
         JOIN dbo.Pack Pack WITH (NOLOCK) ON SKU.Packkey = Pack.Packkey      
         WHERE StorerKey = @cStorerKey      
           AND SKU = @cSKU      

         -- Update WCSRouting table     
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN      
         SAVE TRAN DPK
      
         UPDATE dbo.WCSRouting WITH (ROWLOCK) SET      
            Status = '9'      
         WHERE ToteNo = @cToteNo      
            AND TaskType = 'PK'      
            AND Status < '9'      
      
         IF @@ERROR <> 0 
         BEGIN      
            ROLLBACK TRAN DPK 
            SET @nErrNo = 50371      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD WCS FAIL      
            EXEC rdt.rdtSetFocusField @nMobile, 1      
            GOTO Step_2_Fail      
         END      
      
         UPDATE WCSRD WITH (ROWLOCK) SET      
            WCSRD.Status = '9'      
         FROM dbo.WCSRouting WCSR      
         JOIN dbo.WCSRoutingDetail WCSRD ON (WCSR.WCSKey = WCSRD.WCSKey)      
         WHERE WCSR.ToteNo = @cToteNo      
            AND WCSR.TaskType = 'PK'      
            AND WCSRD.Status < '9'      
      
         IF @@ERROR <> 0 
         BEGIN      
            ROLLBACK TRAN DPK  
            SET @nErrNo = 50372      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDATE WCSDET FAIL      
            EXEC rdt.rdtSetFocusField @nMobile, 1      
            GOTO Step_2_Fail      
         END      
      
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN DPK
            
         --prepare next screen variable      
         SET @cOutField01 = @cToteNo      
         SET @cOutField02 = @cSKU      
         SET @cOutField03 = SUBSTRING(@cSKUDescr, 1,20)      
         SET @cOutField04 = SUBSTRING(@cSKUDescr,21,40)      
         SET @cOutField05 = ''      
         SET @cOutField06 = RTRIM(CAST(@nRemain_Qty AS NVARCHAR( 5))) + '/' + CAST(@nTotal_QTY AS NVARCHAR( 5)) + @cUOM      
         SET @cOutField07 = @cLoc   -- (jamesxx)      
         SET @cOutField08 = ''      
         SET @cOutField09 = ''      
         SET @cOutField10 = ''      
         SET @cOutField11 = ''      

         SET @cCaseID = @cToteNo

         SET @nFunc = 1711

         SET @nScn = 2391      
         SET @nStep = 2
         
         GOTO Quit      
      END

   END                
                
   IF @nInputKey = 0 -- ESC                
   BEGIN                
      -- Goto Zone/Printers Screen      
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      SET @cPutawayZone = ''

      SET @cOutField01 = ''      
      SET @cOutField02 = ''      
      SET @cOutField03 = ''      

      EXEC rdt.rdtSetFocusField @nMobile, 1
   END                
   GOTO Quit       
                
   Step_2_Fail:                
   BEGIN                
      -- Reset this screen var                
      SET @cOutField01 = '' 
      SET @cToteNo = ''
   END                
END                
GOTO Quit          
           
/********************************************************************************            
Quit. Update back to I/O table, ready to be pick up by JBOSS                
********************************************************************************/                
Quit:                
BEGIN                
   UPDATE RDTMOBREC WITH (ROWLOCK) SET                
      EditDate       = GETDATE(), 
      ErrMsg         = @cErrMsg,                 
      Func           = @nFunc,                
      Step           = @nStep,                            
      Scn            = @nScn,                
                
      StorerKey      = @cStorerKey,                
      Facility       = @cFacility,                 
      Printer        = @cPrinter,                    
      -- UserName       = @cUserName,                
      
      V_Zone         = @cPutawayZone,  
      V_CaseID       = @cCaseID,      
      V_SKU          = @cSKU, 
   
      V_String1   =  @cToteNo,                     
                
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