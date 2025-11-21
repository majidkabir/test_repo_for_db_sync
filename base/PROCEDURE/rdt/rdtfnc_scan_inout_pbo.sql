SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
/********************************************************************************/        
/* Store procedure: rdtfnc_SCAN_INOUT_PBO                                       */        
/* Copyright      : IDS                                                         */        
/*                                                                              */        
/* Purpose: Capture OverDate                                                    */        
/*                                                                              */        
/* Date       Rev  Author     Purposes                                          */        
/* 2020-06-12 1.0  YeeKung    WMS-13628 Created                                 */        
/* 2020-11-01 1.1  CalvinKhor Fix Order Status condition - Add ''  (CLVN01)     */       
/* 2021-01-29 1.2  YeeKung    Add nolock to solve deadlock (yeekung01)          */       
/* 2021-05-06 1.3  YeeKung    Fix deadlock issues (yeekung02)                   */    
/* 2021-06-16 1.4  YeeKung    WMS-17277 Add pickerID (yeekung03)                */  
/* 2021-11-02 1.5  YeeKung    Fix Deadlock issues (yeekung04)                   */
/* 2023-02-27 1.6  YeeKung    WMS-21821 Add rdtformat (yeekung05)                */
/********************************************************************************/        
        
CREATE    PROC [RDT].[rdtfnc_SCAN_INOUT_PBO] (        
   @nMobile    INT,        
   @nErrNo     INT  OUTPUT,        
   @cErrMsg    NVARCHAR(1024) OUTPUT        
)        
AS        
SET NOCOUNT ON        
SET QUOTED_IDENTIFIER OFF        
SET ANSI_NULLS OFF        
SET CONCAT_NULL_YIELDS_NULL OFF        
        
        
DECLARE        
   @nFunc               INT,        
   @nScn                INT,        
   @nStep               INT,        
   @cLangCode           NVARCHAR( 3),        
   @nInputKey           INT,        
   @nMenu               INT,        
        
   @cStorerKey          NVARCHAR(15),        
   @cFacility           NVARCHAR(5),        
   @cUserName           NVARCHAR(18),        
   @cPrinter            NVARCHAR(10),        
   @cWaveKey            NVARCHAR(20),        
   @cCaseID             NVARCHAR(20),        
   @cUserID             NVARCHAR(20),        
   @cBarcode            NVARCHAR(20),        
   @cPickSlipNO         NVARCHAR(20),        
   @cOrderkey           NVARCHAR(20),      
        
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1),        
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1),        
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1),        
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1),        
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1),        
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1),        
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1),        
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1),        
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1),        
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1),        
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1),        
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1),        
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1),        
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1),        
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1)        
        
-- Load RDT.RDTMobRec        
SELECT        
   @nFunc         = Func,        
   @nScn          = Scn,        
   @nStep   = Step,        
   @nInputKey     = InputKey,        
   @nMenu         = Menu,        
   @cLangCode     = Lang_code,        
        
   @cStorerKey    = StorerKey,        
   @cFacility     = Facility,        
   @cPrinter      = Printer,        
   @cUserName     = UserName,        
        
   @cWaveKey    = V_String1,        
   @cCaseID     = V_String2,        
   @cUserID     = V_String3,        
   @cBarcode    = V_String4,        
   @cPickSlipNO = V_String5,        
   @cOrderkey   = V_String6,      
        
   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,        
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,        
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,        
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,        
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,        
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,        
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,        
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,        
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,        
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,        
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,        
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,        
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,        
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,        
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15        
        
FROM RDTMOBREC (NOLOCK)        
WHERE Mobile = @nMobile        
        
IF @nFunc = 1652 -- Handover data capture        
BEGIN        
   -- Redirect to respective screen        
   IF @nStep = 0 GOTO Step_0   -- Func = Data capture        
   IF @nStep = 1 GOTO Step_1   -- Scn = 5750 WaveKey        
   IF @nStep = 2 GOTO Step_2   -- Scn = 5751 UserID        
END        
        
RETURN -- Do nothing if incorrect step        
        
/********************************************************************************        
Step 0. func = 1652. Menu        
********************************************************************************/        
Step_0:        
BEGIN        
        
   -- Set the entry point        
   SET @nScn = 5750        
   SET @nStep = 1        
        
   -- Prepare next screen var        
   SET @cOutField01 = '' -- Wavekey        
        
   -- EventLog        
   EXEC RDT.rdt_STD_EventLog        
      @cActionType = '1', -- Sign-in        
      @cUserID     = @cUserName,        
      @nMobileNo   = @nMobile,        
      @nFunctionID = @nFunc,        
      @cFacility   = @cFacility,        
      @cStorerKey  = @cStorerkey        
        
END        
GOTO Quit        
        
/********************************************************************************        
Step 1. Screen = 5610        
   WaveKey  (Field01, input)        
********************************************************************************/        
Step_1:        
BEGIN        
   IF @nInputKey = 1 -- ENTER        
   BEGIN        
    -- Screen mapping        
      SET @cBarcode=@cInField01        
      SET @cWaveKey = SUBSTRING(@cInField01,1,10)        
      SET @cCaseID = SUBSTRING(@cInField01,11,15)        
        
      IF ISNULL(@cWaveKey,'')='' AND  ISNULL(@cCaseID,'')=''        
      BEGIN        
         SET @nErrNo = 153701        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Orderkey Needed        
         GOTO Step_1_Fail        
      END        
        
      IF NOT EXISTS  (select 1    --(yeekung01)    
                     FROM  wavedetail w (NOLOCK)  JOIN orders o (nolock) ON w.WaveKey=o.UserDefine09     
                     JOIN PICKHEADER PH (nolock) ON PH.orderkey=o.orderkey      
                     JOIN pickdetail pd (NOLOCK) ON pd.OrderKey=ph.OrderKey   
                     WHERE w.WaveKey=@cWaveKey         
                        AND pd.caseid=@cCaseID        
                        AND pd.status<'5'      --(CLVN01)        
                        AND ISNULL(ph.pickheaderkey,'')<>''        
                        AND o.storerkey=@cStorerKey   )     
      BEGIN        
         SET @nErrNo = 153702        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid orders        
         GOTO Step_1_Fail        
      END        
        
      SET @cOutField01=@cBarcode        
        
      SET @nStep= @nStep +1        
      SET @nScn = @nScn + 1        
        
      GOTO QUIT        
        
   END        
        
   IF @nInputkey = 0        
   BEGIN        
      -- EventLog        
      EXEC RDT.rdt_STD_EventLog        
         @cActionType = '9', -- Sign-out        
         @cUserID     = @cUserName,        
         @nMobileNo   = @nMobile,        
         @nFunctionID = @nFunc,        
         @cFacility   = @cFacility,        
         @cStorerKey  = @cStorerkey        
        
      SET @nFunc = @nMenu        
      SET @nScn  = @nMenu        
      SET @nStep = 0        
      SET @cOutField01 = ''        
        
      GOTO Quit        
   END        
        
   Step_1_Fail:        
   BEGIN        
      SET @cWaveKey=''        
      SET @cOutField01=''        
      SET @cCaseID=''        
      SET @cBarcode=''        
      GOTO Quit        
   END        
END        
GOTO Quit        
        
/********************************************************************************        
Step 2. Screen = 5611        
   WAVEKEY        
   (field01)        
   USERID        
   (field02)        
********************************************************************************/        
Step_2:        
BEGIN        
   IF @nInputKey = 1 -- ENTER        
   BEGIN        
      SET @cUserID=@cInField02        
        
      IF ISNULL(@cUserID,'')=''        
      BEGIN        
         SET @nErrNo = 153703        
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UserID Needed        
         GOTO Step_2_Fail        
      END        

      -- Check userid format (yeekung05)
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'USERID', @cUserID) = 0
      BEGIN
         SET @nErrNo = 153708
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_2_Fail
      END
  
      BEGIN TRAN rdtfnc_SCAN_INOUT_PBO        
        
      DECLARE cursor_pickinginfo CURSOR        
      FOR               
         SELECT Distinct(ph.pickheaderkey) ,o.orderkey  --(yeekung02)    (yeekung05)
         FROM dbo.wavedetail w (NOLOCK) JOIN orders o (nolock)  ON w.WaveKey=o.UserDefine09        
         JOIN PICKHEADER PH (nolock) ON PH.orderkey=o.orderkey        
         JOIN Pickdetail PD (NOLOCK) ON pd.OrderKey=o.OrderKey    
         WHERE w.WaveKey=@cWaveKey         
            AND EXISTS  ( SELECT 1 FROM Pickdetail PD (NOLOCK) WHERE  pd.OrderKey=o.OrderKey         
            AND pd.caseid=@cCaseID        
            AND pd.status<'5'      )       
         OPEN cursor_pickinginfo;        

        
         FETCH NEXT FROM cursor_pickinginfo INTO  @cPickslipNO,@cOrderkey;         
         WHILE @@FETCH_STATUS = 0        
         BEGIN         
      
            IF NOT EXISTS (SELECT 1 from pickinginfo (NOLOCK)      
                            WHERE pickslipno=@cPickslipNO)      
            BEGIN      
               INSERT INTO pickinginfo (pickslipno,scanindate,pickerid,scanoutdate,Wavekey,Caseid)        
               VALUES(@cPickslipNO,GETDATE(),@cUserID,GETDATE(),@cWavekey,@cCaseID)        
        
               IF @@ERROR <>0        
          BEGIN        
                  SET @nErrNo = 153706        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsertPIFail        
                  ROLLBACK TRAN rdtfnc_SCAN_INOUT_PBO        
                  GOTO Step_2_CursorFail         
               END        
            END      
        
            -- EventLog        
            EXEC RDT.rdt_STD_EventLog        
               @cActionType = '4', -- Sign-out        
               @cUserID     = @cUserName,        
               @nMobileNo   = @nMobile,        
               @nFunctionID = @nFunc,        
               @cFacility   = @cFacility,        
               @cStorerKey  = @cStorerkey,        
               @cPickSlipNo = @cPickSlipNo,        
               @cWaveKey    = @cWaveKey,        
               @cCaseID     = @cCaseID,        
               @cRefno1     = @cUserID       
                   
            DECLARE @cpickdetailkey NVARCHAR(20)     
    
            DECLARE c_pickdetailkey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT PICKDETAILKEY    
            FROM pickdetail(NOLOCK)    
            WHERE orderkey=@cOrderkey      
            and storerkey=@cStorerKey  
            AND Status < '5'    
    
            OPEN c_pickdetailkey          
            FETCH NEXT FROM c_pickdetailkey INTO  @cpickdetailkey          
            WHILE (@@FETCH_STATUS <> -1)          
            BEGIN        
                                
               UPDATE Pickdetail WITH (ROWLOCK)  --(yeekung02)      
               SET        
                  status = '5',        
                  editwho=@cUserID,        
                  editdate=GETDATE()        
               WHERE PICKDETAILKEY=@cpickdetailkey   
               AND Status < '5' 
      
               IF @@ERROR <>0        
               BEGIN        
                  SET @nErrNo = 153705        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdatePDFail        
                  GOTO Step_2_CursorFail        
               END        
    
               FETCH NEXT FROM c_pickdetailkey INTO  @cpickdetailkey       
            END    
               
            CLOSE c_pickdetailkey        
            DEALLOCATE c_pickdetailkey      
    
                    
            UPDATE Orders WITH (ROWLOCK) --(yeekung02)      
            SET        
               status = '5',        
               editwho=@cUserID,        
               editdate=GETDATE()        
            WHERE orderkey  = @cOrderkey  
            AND Status < '5'    
        
            IF @@ERROR <>0        
            BEGIN        
               SET @nErrNo = 153707        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdateOSFail        
               GOTO Step_2_CursorFail          
            END         
        
            FETCH NEXT FROM cursor_pickinginfo INTO         
            @cPickSlipNO,@cOrderkey        
         END;        
        
         CLOSE cursor_pickinginfo        
         DEALLOCATE cursor_pickinginfo        
        
        
         --UPDATE PD        
         --SET        
         --   PD.status = '5',        
         --   PD.editwho=@cUserID,        
         --   PD.editdate=GETDATE()        
         --FROM         
         --   Pickdetail PD  WITH (NOLOCK) --(yeekung01)      
         --   INNER JOIN Orders O   WITH (NOLOCK)  --(yeekung01)      
         --   ON PD.orderkey= O.orderkey        
         --WHERE o.userdefine09=@cWaveKey         
         --   AND pd.caseid=@cCaseID        
         --   AND pd.status<'5'    --(CLVN01)        
        
         --IF @@ERROR <>0        
         --BEGIN        
         --   SET @nErrNo = 153705        
         --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdatePDFail        
         --   ROLLBACK TRAN rdtfnc_SCAN_INOUT_PBO        
         --   GOTO Step_2_Fail        
         --END        
        
         --UPDATE O       
         --SET        
         --   O.status = '5',        
         --   O.editwho=@cUserID,        
         --   O.editdate=GETDATE()        
         --FROM         
         --   Pickdetail PD  WITH (NOLOCK)  --(yeekung01)      
         --   INNER JOIN Orders O   WITH (NOLOCK)  --(yeekung01)      
         --   ON PD.orderkey= O.orderkey        
         --WHERE o.userdefine09=@cWaveKey         
         --   AND pd.caseid=@cCaseID        
         --   AND o.status<'5'    --(CLVN01)        
        
         --IF @@ERROR <>0        
         --BEGIN        
         --   SET @nErrNo = 153707        
         --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdateOSFail        
         --   ROLLBACK TRAN rdtfnc_SCAN_INOUT_PBO                 --   GOTO Step_2_Fail        
         --END        
            
        
      COMMIT TRAN rdtfnc_SCAN_INOUT_PBO        
        
      SET @nScn  = @nScn-1        
      SET @nStep = @nStep-1        
      SET @cWavekey=''        
      SET @cBarcode=''        
      SET @cCaseID=''        
      SET @cOutField01=''        
        
      GOTO Quit        
        
   END        
        
   IF @nInputkey = 0        
   BEGIN        
        
      SET @nScn  = @nScn-1        
      SET @nStep = @nStep-1        
      SET @cWavekey=''        
      SET @cBarcode=''        
      SET @cCaseID=''        
      GOTO Quit        
   END        
        
   STEP_2_Fail:        
   BEGIN        
     SET @cUserID=''        
     SET @cInField02=''        
     GOTO QUIT      
   END        
      
   STEP_2_CursorFail:      
   BEGIN       
      if @@TRANCOUNT>0      
         ROLLBACK TRAN rdtfnc_SCAN_INOUT_PBO      
      
      CLOSE cursor_pickinginfo;        
      DEALLOCATE cursor_pickinginfo;        
      
      SET @cUserID=''        
      SET @cInField02=''       
      GOTO QUIT      
    END       
        
END        
GOTO Quit        
        
        
/********************************************************************************        
Quit. Update back to I/O table, ready to be pick up by JBOSS        
********************************************************************************/        
Quit:        
BEGIN        
   UPDATE RDTMOBREC WITH (ROWLOCK) SET        
      ErrMsg         = @cErrMsg,        
      Func           = @nFunc,        
      Step           = @nStep,        
      Scn            = @nScn,        
        
      StorerKey      = @cStorerKey,        
      Facility       = @cFacility,        
      Printer        = @cPrinter,        
      UserName       = @cUserName,        
        
      V_String1      = @cWaveKey   ,        
      V_String2      = @cCaseID    ,        
      V_String3      = @cUserID    ,        
      V_String4      = @cBarcode   ,        
      V_String5      = @cPickSlipNO,      
      V_String6      = @cOrderkey,      
        
      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,        
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,        
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,        
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,        
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,        
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,        
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,        
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,        
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,        
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,        
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,        
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,        
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,        
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,        
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15        
        
   WHERE Mobile = @nMobile        
END 

GO