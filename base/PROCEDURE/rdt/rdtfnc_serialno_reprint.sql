SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
     
     
/******************************************************************************/       
/* Copyright: LF                                                              */       
/* Purpose:                                                                   */       
/*                                                                            */       
/* Modifications log:                                                         */       
/*                                                                            */       
/* Date       Rev  Author     Purposes                                        */       
/* 2017-05-23 1.0  ChewKP     Created. WMS-1931                               */  
/* 2018-10-29 1.1  TungGH     Performance                                     */ 
/* 2022-05-24 1.2  YeeKung    WMS-19693 add New 9l-Bundle  (yeekung01)        */
/******************************************************************************/      
      
CREATE   PROC [RDT].[rdtfnc_SerialNo_RePrint] (      
   @nMobile    int,      
   @nErrNo     int  OUTPUT,      
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max      
)      
AS      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
-- Misc variable      
DECLARE       
   @nCount      INT,      
   @nRowCount   INT      
      
-- RDT.RDTMobRec variable      
DECLARE       
   @nFunc      INT,      
   @nScn       INT,      
   @nStep      INT,      
   @cLangCode  NVARCHAR( 3),      
   @nInputKey  INT,      
   @nMenu      INT,      
      
   @cStorerKey NVARCHAR( 15),      
   @cFacility  NVARCHAR( 5),       
   @cPrinter   NVARCHAR( 20),       
   @cUserName  NVARCHAR( 18),      
         
   @nError            INT,      
   @b_success         INT,      
   @n_err             INT,           
   @c_errmsg          NVARCHAR( 250),       
   @cPUOM             NVARCHAR( 10),          
   @bSuccess          INT,      
   @cDataWindow		 NVARCHAR( 50),  
   @cTargetDB    		 NVARCHAR( 20), 
   @cWorkOrderNo      NVARCHAR( 10),
   @cSerialNo         NVARCHAR(20) ,
   @n9LQty            INT,
   @n9LBQty           INT,
   @nInnerQty         INT,
   @nMasterQty        INT,
   @c9LNewLabel       NVARCHAR(1),
   @c9LBNewLabel      NVARCHAR(60), --(yeekung01)
   @c9LBNewLabel2     NVARCHAR(60),
   @cInnerNewLabel    NVARCHAR(1),
   @cMasterNewLabel   NVARCHAR(1),
   @cSerialType       NVARCHAR(1),
   @cInnerSerial      NVARCHAR(20),
   @cMasterSerial     NVARCHAR(20),
   @c9LSerial         NVARCHAR(20),
   @c9LBSerial        NVARCHAR(20), --(yeekung01)
   @cInnerSKU         NVARCHAR(20), 
   @cMasterSKU        NVARCHAR(20), 
   @cSKU              NVARCHAR(20), 
   @nInnerChildQty    INT,
   @nChildQty         INT,
   @nMasterChildQty   INT,
   @cPrinter9L        NVARCHAR( 20),      
   @cPrinterInner     NVARCHAR( 20),      
   @cPrinterMaster    NVARCHAR( 20),      
   @cPrinterGTIN      NVARCHAR( 20),
   @cPrinter9LB       NVARCHAR( 20), 
   @cCurSerial        NVARCHAR( 20),
  

   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),    
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),    
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),    
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),    
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),    
            
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

   @cWorkOrderNo = V_String1, 
   
         
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
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04  = FieldAttr04,      
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,      
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,      
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,      
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,      
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,      
   @cFieldAttr15 =  FieldAttr15      
      
FROM RDTMOBREC (NOLOCK)      
WHERE Mobile = @nMobile      
      
Declare @n_debug INT      
      
SET @n_debug = 0      
      
      
IF @nFunc = 1009  -- Serial No RePrint
BEGIN      
         
   -- Redirect to respective screen      
   IF @nStep = 0 GOTO Step_0   -- Serial No SKU Change  
   IF @nStep = 1 GOTO Step_1   -- Scn = 4880. WorkOrderNo
   IF @nStep = 2 GOTO Step_2   -- Scn = 4881. SerialNo
   
         
END      
      
      
RETURN -- Do nothing if incorrect step      
      
/********************************************************************************      
Step 0. func = 1009. Menu      
********************************************************************************/      
Step_0:      
BEGIN      
   -- Get prefer UOM      
   SET @cPUOM = ''      
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA      
   FROM RDT.rdtMobRec M WITH (NOLOCK)      
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)      
   WHERE M.Mobile = @nMobile      
       
       

      
   -- Initiate var      
   -- EventLog - Sign In Function      
   EXEC RDT.rdt_STD_EventLog      
     @cActionType = '1', -- Sign in function      
     @cUserID     = @cUserName,      
     @nMobileNo   = @nMobile,      
     @nFunctionID = @nFunc,      
     @cFacility   = @cFacility,      
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep      
           
   
   
   -- Init screen      
   SET @cOutField01 = ''       
   SET @cOutField02 = ''      
     
 
      
   -- Set the entry point      
   SET @nScn = 4880      
   SET @nStep = 1      
         
   EXEC rdt.rdtSetFocusField @nMobile, 1      
         
END      
GOTO Quit      
            
/********************************************************************************      
Step 1. Scn = 4850.      
   WorkOrderNo     (field01 , input)      
     
    
********************************************************************************/      
Step_1:      
BEGIN      
   IF @nInputKey = 1 --ENTER      
   BEGIN      
            
      SET @cWorkOrderNo = ISNULL(RTRIM(@cInField01),'')      
          
      IF @cWorkOrderNo = ''
      BEGIN
         SET @nErrNo = 109701      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WorkOrdeRNoReq    
         GOTO Step_1_Fail  
      END
      
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrder WITH (NOLOCK)  
                      WHERE StorerKey = @cStorerKey  
                      AND Facility = @cFacility  
                      AND WorkOrderKey = @cWorkOrderNo )   
      BEGIN  
         SET @nErrNo = 109702      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvdWorkOrder
         GOTO Step_1_Fail      
      END    
      
       -- GOTO Next Screen      
      SET @nScn = @nScn + 1      
      SET @nStep = @nStep + 1     
          
       -- Prepare Next Screen Variable      
      --SET @cOutField01 = @cPTSZone    
      SET @cOutField01 = ''  
      SET @cOutField02 = ''
      SET @cOutField03 = ''
        
    
        
            
   END  -- Inputkey = 1      
      
   IF @nInputKey = 0     
   BEGIN      
              
--    -- EventLog - Sign In Function      
      EXEC RDT.rdt_STD_EventLog      
        @cActionType = '9', -- Sign in function      
        @cUserID     = @cUserName,      
        @nMobileNo   = @nMobile,      
        @nFunctionID = @nFunc,      
        @cFacility   = @cFacility,      
        @cStorerKey  = @cStorerkey,
        @nStep       = @nStep      
              
      --go to main menu      
      SET @nFunc = @nMenu      
      SET @nScn  = @nMenu      
      SET @nStep = 0      
      SET @cOutField01 = ''      
  
   END      
   GOTO Quit      
      
   STEP_1_FAIL:      
   BEGIN      
      -- Prepare Next Screen Variable      
      SET @cOutField01 = ''    
     
   END      
END       
GOTO QUIT      
      
      
/********************************************************************************      
Step 2. Scn = 4721.       
       
   From SKU        (field01, input)      
   To SKU          (field02, input)    
   SerialNo        (field03, input)    
         
********************************************************************************/      
Step_2:      
BEGIN      
   IF @nInputKey = 1      
   BEGIN      
      SET @cSerialNo         = ISNULL(RTRIM(@cInField01),'')      
        
      --SET @cSerialNo = '1634EP00858C'

      --9-C-M
      --1643SD10A5D9
      --1647SD00749C
      --1647SD00470M

      --9-M
      --1648CE0F28B9
      --1648CE02B79M
      

      IF @cSerialNo = ''      
      BEGIN      
         SET @nErrNo = 109703      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SerialNoReq'    
         GOTO Step_2_Fail    
      END     
      
      SELECT @n9LQty = Qty 
            ,@c9LNewLabel = WKORDUDEF1 
      FROM dbo.WorkOrderDetail WITH (NOLOCK) 
      WHERE WorkOrderKey = @cWorkOrderNo
      AND Type = 'REWORK'
      AND Unit = '9L'
            
      SELECT @nInnerQty = Qty 
            ,@cInnerNewLabel = WKORDUDEF1 
      FROM dbo.WorkOrderDetail WITH (NOLOCK) 
      WHERE WorkOrderKey = @cWorkOrderNo
      AND Type = 'REWORK'
      AND Unit = 'Inner'
      
      SELECT @nMasterQty = Qty 
            ,@cMasterNewLabel = WKORDUDEF1 
      FROM dbo.WorkOrderDetail WITH (NOLOCK) 
      WHERE WorkOrderKey = @cWorkOrderNo
      AND Type = 'REWORK'
      AND Unit = 'Master' 

      SELECT @c9LBNewLabel = WKORDUDEF1 
            ,@c9LBNewLabel2 = WKORDUDEF2 
            , @cSKU = WKORDUDEF3
      FROM dbo.workorder  WITH (NOLOCK) 
      WHERE WorkOrderKey = @cWorkOrderNo
      
      
      SELECT @cPrinter9L = UDF01 
            ,@cPrinterInner = UDF02 
            ,@cPrinterMaster = UDF03
            ,@cPrinterGTIN = UDF04
            ,@cPrinter9LB = UDF05
      FROM dbo.CodeLkup WITH (NOLOCK) 
      WHERE ListName = 'SERIALPRN'
      AND StorerKey = @cStorerKey
      AND Code = @cUserName 
      
      
      SET @cSerialType = RIGHT ( @cSerialNo , 1 ) 
      
      IF @cSerialType = '9'
      BEGIN
         SELECT TOP 1 --@c9LSKU       = SKU 
                     -- @cInnerSKU    = ParentSKU
                     @cInnerSerial = ParentSerialNo
         FROM dbo.MasterSerialNo WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SerialNo = @cSerialNo 
         
         IF RIGHT(ISNULL(@cInnerSerial,''), 1  ) = 'M'
         BEGIN
            SELECT TOP 1  @cMasterSKU      = ParentSKU
                         ,@cMasterSerial = ParentSerialNo
                         --,@nMasterChildQty = ChildQty 
            FROM dbo.MasterSerialNo WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND SerialNo = @cSerialNo

            
            
         END
         ELSE
         BEGIN
            SELECT TOP 1  @cMasterSKU      = ParentSKU
                         ,@cMasterSerial = ParentSerialNo
                         --,@nMasterChildQty = ChildQty 
            FROM dbo.MasterSerialNo WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND SerialNo = @cInnerSerial

            
         END          
      END
      ELSE IF @cSerialType = 'C'
      BEGIN
         SELECT --@cInnerSKU     = SKU 
                   @cMasterSKU    = ParentSKU
                  ,@cMasterSerial = ParentSerialNo
                  --,@nMasterChildQty = ChildQty 
         FROM dbo.MasterSerialNo WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SerialNo = @cSerialNo 

         SET @cInnerSerial = @cSerialNo

         
         
      END 
      ELSE IF @cSerialType = 'M'
      BEGIN
         SET @cMasterSerial = @cSerialNo 
         
         SELECT 
                  @cMasterSKU    = ParentSKU
                 --,@cMasterSerial = ParrentSerialNo
                 --,@nMasterChildQty = ChildQty 
                   ,@cInnerSerial = SerialNo 
         FROM dbo.MasterSerialNo WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND ParentSerialNo = @cSerialNo

         
         
      END

      SET @nMasterChildQty = 0 
      
      
      IF @c9LNewLabel = '1' 
      BEGIN
         
         
         IF @cSerialType = '9'
         BEGIN              

               --IF RIGHT(ISNULL(@cInnerSerial,''), 1  ) = 'C'
               --BEGIN
               --   DECLARE CUR_9LPRINT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            
               --   SELECT TOP 1 SerialNo, SKU, ChildQty 
               --   FROM dbo.MasterSerialNo WITH (NOLOCK) 
               --   WHERE StorerKey = @cStorerKey
               --   AND ParentSerialNo = @cInnerSerial
               --END
               --ELSE IF RIGHT(ISNULL(@cInnerSerial,''), 1  ) = 'M'
               --BEGIN
                  DECLARE CUR_9LPRINT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            
                  SELECT TOP 1 SerialNo, SKU, ChildQty 
                  FROM dbo.MasterSerialNo WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND SerialNo = @cSerialNo
--               END
         END
         ELSE IF @cSerialType  = 'C'
         BEGIN
               DECLARE CUR_9LPRINT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            
               SELECT SerialNo, SKU, ChildQty 
               FROM dbo.MasterSerialNo WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND ParentSerialNo = @cSerialNo
         END
         ELSE IF @cSerialType  = 'M'
         BEGIN
               
               IF RIGHT(ISNULL(@cInnerSerial,''), 1  ) = 'C'
               BEGIN
                  DECLARE CUR_9LPRINT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               
                  SELECT SerialNo, SKU, ChildQty 
                  FROM dbo.MasterSerialNo WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND ParentSerialNo IN ( SELECT SerialNo
                                          FROM dbo.MasterSerialNo WITH (NOLOCK) 
                                          WHERE StorerKey = @cStorerKey
                                          AND ParentSerialNo = @cSerialNo ) 
                  GROUP BY SerialNo, SKU, ChildQty 
               END
               ELSE
               BEGIN
                  DECLARE CUR_9LPRINT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               
                  SELECT SerialNo, SKU, ChildQty 
                  FROM dbo.MasterSerialNo WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND SerialNo IN ( SELECT SerialNo
                                          FROM dbo.MasterSerialNo WITH (NOLOCK) 
                                          WHERE StorerKey = @cStorerKey
                                          AND ParentSerialNo = @cSerialNo ) 
                  GROUP BY SerialNo, SKU, ChildQty 
               END                        
         END   
         
         OPEN CUR_9LPRINT
         FETCH NEXT FROM CUR_9LPRINT INTO @c9LSerial, @cSKU, @nChildQty
         WHILE @@FETCH_STATUS <> -1 
         BEGIN
            
            SET @cDataWindow = ''
            SET @cTargetDB = ''
         
            SELECT @cDataWindow = DataWindow,     
      			   @cTargetDB = TargetDB     
      	   FROM rdt.rdtReport WITH (NOLOCK)     
      	   WHERE StorerKey = @cStorerKey    
      	   AND   ReportType = 'LOG9LLABEL'   
      	
      	   --IF ISNULL(@cDataWindow,'')  <> '' 
      	   --BEGIN
         	EXEC RDT.rdt_BuiltPrintJob      
         	             @nMobile,      
         	             @cStorerKey,      
         	             'LOG9LLABEL',    -- ReportType      
         	             'Serial9L',    -- PrintJobName      
         	             @cDataWindow,      
         	             @cPrinter9L,      
         	             @cTargetDB,      
         	             @cLangCode,      
         	             @nErrNo  OUTPUT,      
         	             @cErrMsg OUTPUT, 
         	             @c9LSerial
      	   --END
      	
      	   FETCH NEXT FROM CUR_9LPRINT INTO @c9LSerial, @cSKU, @nChildQty
         END
         CLOSE CUR_9LPRINT      
         DEALLOCATE CUR_9LPRINT
         
      END
      
      IF @cInnerNewLabel = '1'
      BEGIN
         
         
         IF @cSerialType = '9' 
         BEGIN
            DECLARE CUR_INNERPRINT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         
            SELECT TOP 1 ParentSerialNo, SKU, ChildQty
            FROM dbo.MasterSerialNo WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND ParentSerialNo = @cInnerSerial
         END
         ELSE IF @cSerialType = 'C'
         BEGIN
            DECLARE CUR_INNERPRINT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         
            SELECT TOP 1 ParentSerialNo, SKU, ChildQty
            FROM dbo.MasterSerialNo WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND ParentSerialNo = @cSerialNo
         END
         ELSE IF @cSerialType = 'M'
         BEGIN
              
            DECLARE CUR_INNERPRINT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            
            SELECT ParentSerialNo, SKU, ChildQty 
            FROM dbo.MasterSerialNo WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND ParentSerialNo IN ( SELECT SerialNo
                                    FROM dbo.MasterSerialNo WITH (NOLOCK) 
                                    WHERE StorerKey = @cStorerKey
                                    AND ParentSerialNo = @cSerialNo ) 
            GROUP BY ParentSerialNo, SKU, ChildQty 
            
         END
         
         OPEN CUR_INNERPRINT
         FETCH NEXT FROM CUR_INNERPRINT INTO @cCurSerial, @cSKU, @nChildQty
         WHILE @@FETCH_STATUS <> -1 
         BEGIN
           
            
            SET @cDataWindow = ''
            SET @cTargetDB = ''
         
            SELECT @cDataWindow = DataWindow,     
      			   @cTargetDB = TargetDB     
      	   FROM rdt.rdtReport WITH (NOLOCK)     
      	   WHERE StorerKey = @cStorerKey    
      	   AND   ReportType = 'LOGMASTLBL'   
      	
      	   --IF ISNULL(@cDataWindow,'')  <> '' 
      	   --BEGIN
         	EXEC RDT.rdt_BuiltPrintJob      
         	             @nMobile,      
         	             @cStorerKey,      
         	             'LOGMASTLBL',    -- ReportType      
         	             'SerialInner',    -- PrintJobName      
         	             @cDataWindow,      
         	             @cPrinterInner,      
         	             @cTargetDB,      
         	             @cLangCode,      
         	             @nErrNo  OUTPUT,      
         	             @cErrMsg OUTPUT, 
         	             @cStorerKey,
         	             @cSKU,   
         	             @cWorkOrderNo,
         	             @nChildQty,
         	             @cCurSerial
         	             
      	   --END
      	
      	   FETCH NEXT FROM CUR_INNERPRINT INTO @cCurSerial, @cSKU, @nChildQty
         END
         CLOSE CUR_INNERPRINT      
         DEALLOCATE CUR_INNERPRINT
      	   
      END      
      
      IF @cMasterNewLabel = '1' 
      BEGIN 
         

         -- PRINT Master Serial No 
         SET @cDataWindow = ''
         SET @cTargetDB = ''
      
         SELECT @cDataWindow = DataWindow,     
	   		   @cTargetDB = TargetDB     
		   FROM rdt.rdtReport WITH (NOLOCK)     
		   WHERE StorerKey = @cStorerKey    
		   AND   ReportType = 'LOGMASTLBL'   
		   
         ---SET @cERRMSG = @cInnerSerial
         --GOTO QUIT 

         IF RIGHT(ISNULL(@cInnerSerial,''), 1  ) = 'C'
         BEGIN

            SELECT @nMasterChildQty = Count(MasterSerialNoKey) 
            FROM dbo.MasterSerialNo WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND ParentSerialNo IN ( SELECT SerialNo
                                    FROM dbo.MasterSerialNo WITH (NOLOCK) 
                                    WHERE StorerKey = @cStorerKey
                                    AND ParentSerialNo = @cMasterSerial ) 
         END
         ELSE
         BEGIN
            
            
            SELECT @nMasterChildQty = Count(MasterSerialNoKey) 
            FROM dbo.MasterSerialNo WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND SerialNo IN ( SELECT SerialNo
                                    FROM dbo.MasterSerialNo WITH (NOLOCK) 
                                    WHERE StorerKey = @cStorerKey
                                    AND ParentSerialNo = @cMasterSerial ) 
         END           
         
		   --IF ISNULL(@cDataWindow,'')  <> '' 
		   --BEGIN
   		EXEC RDT.rdt_BuiltPrintJob      
   		             @nMobile,      
   		             @cStorerKey,      
   		             'LOGMASTLBL',    -- ReportType      
   		             'SerialMaster',    -- PrintJobName      
   		             @cDataWindow,      
   		             @cPrinterMaster,      
   		             @cTargetDB,      
   		             @cLangCode,      
   		             @nErrNo  OUTPUT,      
   		             @cErrMsg OUTPUT, 
   		             @cStorerKey,
   		             @cMasterSKU,   
   		             @cWorkOrderNo,
   		             @nMasterChildQty,
   		             @cMasterSerial
   		             
  		             
		   --END
      END    
      
      IF EXISTS(  SELECT 1
                  FROM dbo.WorkOrderDetail WITH (NOLOCK) 
                  WHERE WorkOrderKey = @cWorkOrderNo
                  AND Type = 'REWORK'
                  AND Unit = '9L-BUNDLE') --(yeekung01)
      BEGIN

         IF  EXISTS(SELECT 1 
                  FROM dbo.MasterSerialNo WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND ParentSerialNo = @cSerialNo) 
         BEGIN
            -- Common params  
            DECLARE @t9LBPrint AS VariableTable  
            INSERT INTO @t9LBPrint (Variable, Value) VALUES   
               ( '@cStorerkey',     @cStorerkey),   
               ( '@cSKU',@cSKU),
               ( '@c9LSerialNo',     @cSerialNo),   
               ( '@cWkOrdUdef2',@c9LBNewLabel2),
               ( '@cWkOrdUdef1',@c9LBNewLabel)

            -- Print label  
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPrinter9LB, '',   
               'LOG9LBLBL', -- Report type  
               @t9LBPrint, -- Report params  
               'rdtfnc_SerialNo_RePrint',   
               @nErrNo  OUTPUT,  
               @cErrMsg OUTPUT  
            IF @nErrNo <> 0  
               GOTO Quit 
         END
         
      END 
   END  -- Inputkey = 1      
         
   IF @nInputKey = 0       
   BEGIN      
       -- Prepare Previous Screen Variable      
       SET @cOutField01 = ''   
         
                
       -- GOTO Previous Screen      
       SET @nScn = @nScn - 1      
       SET @nStep = @nStep - 1      
             
         
   END      
   GOTO Quit      
         
   Step_2_Fail:      
   BEGIN      
            
      -- Prepare Next Screen Variable      
      
      SET @cOutField01 = ''   
      SET @cOutField02 = ''
      SET @cOutField03 = ''
            
   END      
      
END       
GOTO QUIT      
      

 
      
      
/********************************************************************************      
Quit. Update back to I/O table, ready to be pick up by JBOSS      
********************************************************************************/      
Quit:      
      
BEGIN      
   UPDATE RDTMOBREC WITH (ROWLOCK) SET       
      ErrMsg = @cErrMsg,       
      Func   = @nFunc,      
      Step   = @nStep,      
      Scn    = @nScn,      
      
      StorerKey = @cStorerKey,      
      Facility  = @cFacility,       
      Printer   = @cPrinter,       
      --UserName  = @cUserName,     
      EditDate  = GetDate() ,  
      InputKey  = @nInputKey,   
      
            
      V_String1 = @cWorkOrderNo,
      

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