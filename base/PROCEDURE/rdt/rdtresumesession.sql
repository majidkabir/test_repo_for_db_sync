SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
              
                     
                      
/******************************************************************************/                    
/* Store procedure: RDTResumeSession                                         */                    
/* Copyright      : IDS                                                       */                    
/*                                                                            */                    
/* Purpose: Resume the previous session                                       */                    
/*                                                                            */                    
/* Modifications log:                                                         */                    
/*                                                                            */                    
/* Date       Rev  Author   Purposes                                          */                    
/* 2019-02-15 1.0  YeeKung  Created                                           */                    
/* 2024-05-24 1.1  NLT013   Add session id to get unique mobile               */ 
/* 2024-07-26 1.2  Jackc    UWP-21905 Encrypt password                        */                    
/******************************************************************************/                    
CREATE PROC [RDT].[RDTResumeSession] (                   
   @nMobile    INT,                    
   @nErrNo     INT  OUTPUT,                    
   @cErrMsg    NVARCHAR(20) OUTPUT, -- screen limitation, 20 char max             
   @nFunction  INT     OUTPUT,
   @cClientIP  NVARCHAR( 15),
   @cSessionID NVARCHAR(60) = ''
) AS          
        
   SET NOCOUNT ON          
   SET QUOTED_IDENTIFIER OFF          
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF
            
   DECLARE  @nFunc            int,            
            @nScn             int,            
            @nStep            int,            
            @cUsrName         NVARCHAR(18),            
            @cPassword        NVARCHAR(15),            
            @cStorer          NVARCHAR(15),            
            @cFacility        NVARCHAR(5),            
            @cLangCode        NVARCHAR(3),            
            @iMenu            int,            
            @cMultiLogin      NVARCHAR(1),            
            @cUsrPasswd       NVARCHAR(32),--V1.2 Jackc Extend length from 15 to 32            
            @cDefaultUOM      NVARCHAR(10),            
            @bSuccess         int,            
            @cPrinter         NVARCHAR(10), -- Added on 10-Aug-2007            
            @cPrinter_Paper   NVARCHAR(10), -- (Vicky03)            
            @cDeviceID        NVARCHAR(20),             
            @cActive          NVARCHAR(1),            
            @cLightMode       NVARCHAR(10), -- (ChewKP01)             
            @cInField01       NVARCHAR(1),
            @cRemarks         NVARCHAR(30)        
        
   SELECT   @nFunc         = Func,          
            @nScn          = Scn,          
            @nStep         = Step,          
            @cInField01    = I_Field01,        
            @cUsrName      = username         
   FROM   RDT.RDTMOBREC WITH (NOLOCK)  WHERE Mobile = @nMobile          
        
        
   IF @cInField01 = '1'        
   BEGIN        

      DECLARE @cMobile01 INT, @cMobile02 INT        
        
		SELECT TOP 1 @cMobile01=mobile     
		FROM  rdt.rdtmobrec WITH (NOLOCK)     
		WHERE username=@cUsrName
		ORDER BY editdate ASC      

		SELECT TOP 1 @cMobile02=mobile     
		FROM  rdt.rdtmobrec WITH (NOLOCK)     
		WHERE username=@cUsrName    
		ORDER BY editdate DESC 

      SET @cRemarks = 'Logout-UserRecover (MobNo:'+CAST(@cMobile02 AS nvarchar(40))+')'

      -- Insert login record  
      INSERT INTO RDT.rdtLoginLog (UserName, Mobile, ClientIP, Remarks, SessionID)  
      VALUES (@cUsrname, @cMobile01, @cClientIP,@cRemarks, @cSessionID)
          
      UPDATE RDT.RDTMOBREC WITH (ROWLOCK)       
      SET mobile = (CASE WHEN mobile = @cMobile01 THEN @cMobile02 ELSE @cMobile01 END),        
      EditDate = GETDATE()        
      WHERE mobile = @cMobile02 OR mobile=@cMobile01        
        
   END        
        
   ELSE IF @cInField01 = '9'         
   BEGIN        
     
      SELECT TOP 1 @cMobile01=mobile         
      FROM  rdt.rdtmobrec WITH (NOLOCK)         
      WHERE username=@cUsrName 
    	ORDER BY editdate ASC        
        
      SELECT TOP 1 @cMobile02=mobile         
      FROM rdt.rdtmobrec WITH (NOLOCK)         
      WHERE username=@cUsrName        
      ORDER BY editdate DESC 
      
      SET @cRemarks = 'Logout-UserReset (MobNo:'+CAST(@cMobile02 AS nvarchar(40))+')'

      -- Insert login record  
      INSERT INTO RDT.rdtLoginLog (UserName, Mobile, ClientIP, Remarks, SessionID)  
      VALUES (@cUsrname, @cMobile01, @cClientIP, @cRemarks, @cSessionID)            
          
      UPDATE RDT.RDTMOBREC WITH (ROWLOCK)       
      SET mobile = (CASE WHEN mobile = @cMobile01 THEN @cMobile02 ELSE @cMobile01 END),        
      EditDate = GETDATE()        
      WHERE mobile = @cMobile02 OR mobile=@cMobile01      
           
      SELECT   @cStorer          = ISNULL(DefaultStorer, ''),            
               @cFacility        = ISNULL(DefaultFacility, ''),            
               @cLangCode        = DefaultLangCode, --ISNULL(DefaultLangCode, ''),            
               @iMenu            = ISNULL(DefaultMenu, ''),            
               @cMultiLogin      = ISNULL(MultiLogin, 0),            
               @cUsrPasswd       = ISNULL([Password], ''),            
               @cDefaultUOM      = ISNULL(DefaultUOM, ''),            
               @cPrinter         = ISNULL(DefaultPrinter, ''), -- Added on 10-Aug-2007            
               @cPrinter_Paper   = ISNULL(DefaultPrinter_Paper, ''), -- (Vicky03)            
               @cDeviceID        = ISNULL(DefaultDeviceID, ''), -- (james02)            
               @cActive          = ISNULL(Active, ''),            
               @cLightMode       = ISNULL(DefaultLightColor, '' ) -- (ChewKP01)             
		FROM RDT.rdtUser WITH (NOLOCK)               
      WHERE Username =  @cUsrname          
              
      EXEC rdt.rdtSetFocusField @nMobile, 1            
      UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET             
      EditDate  = GETDATE(),             
      Facility  = @cFacility,            
      StorerKey = @cStorer,            
      ErrMsg    = @cErrMsg,            
      Username  = @cUsrName,            
      Lang_code = @cLangCode,            
      Scn       = '1',            
      Step      = '1',            
      Func      = '1',            
      O_Field01 = @cStorer,            
      O_Field02 = @cFacility,            
      O_Field03 = CASE @cDefaultUOM WHEN '1' THEN 'Pallet'            
            WHEN '2' THEN 'Carton'            
            WHEN '3' THEN 'Inner Pack'            
            WHEN '4' THEN 'Other Unit 1'            
            WHEN '5' THEN 'Other Unit 2'            
            WHEN '6' THEN 'Each'            
            ELSE 'Each'            
      END,            
      O_Field04 = @cPrinter,            
      O_Field05 = @cPrinter_Paper, -- (Vicky03)            
      O_Field06 = @cDeviceID,             
      V_UOM     = @cDefaultUOM,            
      Printer   = @cPrinter,            
      Printer_Paper = @cPrinter_Paper, -- (Vicky03)            
      DeviceID  = @cDeviceID,             
      LightMode = @cLightMode, -- (ChewKP01)             
      FieldAttr01 = '', --(ung01)            
      FieldAttr02 = '',            
      FieldAttr03 = '',            
      FieldAttr04 = '',            
      FieldAttr05 = '',            
      FieldAttr06 = '',            
      FieldAttr07 = '',            
      FieldAttr08 = '',            
      FieldAttr09 = '',            
      FieldAttr10 = '',            
      FieldAttr11 = '',            
      FieldAttr12 = '',            
      FieldAttr13 = '',            
      FieldAttr14 = '',            
      FieldAttr15 = ''            
      WHERE Mobile = @nMobile            
   END           
   ELSE         
   BEGIN         
      SET @nErrNo = -1          
      SET @cErrMsg='Err Opt'         
   END        
        
   IF @nErrNo <>0        
   BEGIN        
      UPDATE RDT.RDTMOBREC WITH (ROWLOCK) 
      SET EditDate = GETDATE(),           
      ErrMsg = @cErrMsg          
      WHERE Mobile = @nMobile        
   END        
   ELSE        
   BEGIN        
      UPDATE RDT.RDTMOBREC WITH (ROWLOCK)          
      SET EditDate = GETDATE(),            
      USERNAME='RETIRED'         
      WHERE Mobile = (SELECT Top 1 Mobile FROM rdt.rdtmobrec        
      WITH (nolock) WHERE username= @cUsrName AND storerkey='')         
   END        
  
RETURN_SP:          
             
SET QUOTED_IDENTIFIER OFF        
SET ANSI_NULLS ON 

GO