SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: rdtfnc_Print_Kimball_Label                             */
/* Copyright      : IDS                                                    */
/*                                                                         */
/* Purpose: SOS#256190 Print Kimball Label                                 */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author     Purposes                                   */
/* 2012-09-24   1.0  James      Created                                    */
/* 2013-06-14   1.1  ChewKP     SOS#280982 Cater for UPC field char(30)    */
/*                              (ChewKP01)                                 */
/* 2013-09-26   1.2  James      SOS289765 - Customise decoding (james01)   */
/* 2016-09-30   1.3  Ung        Performance tuning                         */
/* 2018-10-10   1.4  Gan        Performance tuning                         */
/***************************************************************************/

CREATE PROC [RDT].[rdtfnc_Print_Kimball_Label](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,

   @nPrevScn       INT,
   @nPrevStep      INT,

   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cPrinter       NVARCHAR( 10),
   @cPrinter_Paper NVARCHAR( 10), 

   @cSKU           NVARCHAR( 20),
   @cInSKU         NVARCHAR( 30), -- (ChewKP01)
   @cSKUDescr      NVARCHAR( 60),
   @cDescription   NVARCHAR( 60),
   @cQTY           NVARCHAR( 5),    
   
   @cOption        NVARCHAR( 1), 
   @cCode          NVARCHAR( 1),
   @cReportType    NVARCHAR( 10),                  
   @cPrintJobName  NVARCHAR( 50),                  
   @cDataWindow    NVARCHAR( 50),                  
   @cTargetDB      NVARCHAR( 20),   
   
   @nCnt           INT, 
   @nSKUCnt        INT,
   @nQTY           INT,

   @b_success      INT,
   @n_err          INT,
   @c_errmsg       NVARCHAR( 250),
   
   @cMaxAllowLabel2Print   NVARCHAR(5),
   @cDefaultQty            NVARCHAR(5), -- (ChewKP01)
   @cSKULength2Trim        NVARCHAR( 20), -- (james01)
   @cDecodeLabelNo         NVARCHAR( 20), -- (james01)
   @cLength                NVARCHAR( 20), -- (james01)
   
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

-- (james01)
DECLARE
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),   
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),   
   @c_oFieled15 NVARCHAR(20)                              
   
-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cPrinter         = Printer,
   @cPrinter_Paper   = Printer_Paper, 

   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr,
   @cQTY             = V_QTY,

   @cOption          = V_String1,
   @cSKULength2Trim  = V_String2,
   @cOption          = V_String3,

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

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 975
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0       -- Menu. Func = 975
   IF @nStep = 1  GOTO Step_1       -- Scn = 3200. Label Option
   IF @nStep = 2  GOTO Step_2       -- Scn = 3201. SKU/UPC
   IF @nStep = 3  GOTO Step_3       -- Scn = 3202. # of copies
   IF @nStep = 4  GOTO Step_4       -- Scn = 3203. Length of barcode
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 975
********************************************************************************/
Step_0:
BEGIN

   -- Prepare next screen var
   SET @cOption = ''
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
   
   SET @nCnt = 1
   DECLARE CUR_KIMBALLLBL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT CODE, [DESCRIPTION] 
   FROM dbo.CodeLKUP WITH (NOLOCK) 
   WHERE ListName = 'KIMBALLLBL'
   AND   StorerKey = @cStorerKey
   OPEN CUR_KIMBALLLBL
   FETCH NEXT FROM CUR_KIMBALLLBL INTO @cCode, @cDescription
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @nCnt = 1
         SET @cOutField01 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
      IF @nCnt = 2
         SET @cOutField02 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
      IF @nCnt = 3
         SET @cOutField03 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
      IF @nCnt = 4
         SET @cOutField04 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
      IF @nCnt = 5
         SET @cOutField05 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
      IF @nCnt = 6
         SET @cOutField06 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
      IF @nCnt = 7
         SET @cOutField07 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
      IF @nCnt = 8
         SET @cOutField08 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
      IF @nCnt = 9
         SET @cOutField09 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         
      SET @nCnt = @nCnt + 1

      FETCH NEXT FROM CUR_KIMBALLLBL INTO @cCode, @cDescription
   END
   CLOSE CUR_KIMBALLLBL
   DEALLOCATE CUR_KIMBALLLBL
   
   SET @cOption = ''
   
   -- Go to next screen
   SET @nScn = 3200
   SET @nStep = 1
END
GOTO Quit


/************************************************************************************
Scn = 3200. Label Option
   Option   (field01, input)
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField10

      --Check if it is blank
      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 77151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req
         GOTO Step_1_Fail
      END

      --Check if it is valip option
      IF NOT EXISTS (SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) 
                     WHERE ListName = 'KIMBALLLBL' 
                     AND   Code = @cOption
                     AND   StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 77152
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_1_Fail
      END

      -- (james01)
      IF rdt.RDTGetConfig( @nFunc, 'SKULength2Trim', @cStorerKey) = '1' 
      BEGIN
         SET @cFieldAttr08 = ''
         -- Prepare SKU screen var
         SET @cOutField01 = '0'

         -- Go to SKU screen
         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3
         
         GOTO Quit
      END
      ELSE
         SET @cSKULength2Trim = '0'
         
      SELECT @cDescription = [DESCRIPTION] 
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'KIMBALLLBL' 
      AND   Code = @cOption
      AND   StorerKey = @cStorerKey
      
      -- Prepare SKU screen var
      SET @cSKU = ''
      SET @cOutField01 = @cDescription
      SET @cOutField02 = '' -- SKU

      -- Go to SKU screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      -- Reset all variables
      SET @cOption = ''
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
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField10 = ''
   END
END
GOTO Quit


/***********************************************************************************
Scn = 3201. SKU screen
   Description (field01)
   SKU/UPC     (field02, input)
***********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cInSKU = @cInField02 -- SKU -- (ChewKP01)

      -- Validate blank
      IF ISNULL(@cInSKU, '') = '' -- (ChewKP01)
      BEGIN
         SET @nErrNo = 77153
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU needed
         GOTO Step_2_Fail
      END

      -- (james01)
      SET @cDecodeLabelNo = ''    
      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerkey)    

      IF ISNULL(@cDecodeLabelNo,'') NOT IN ('','0')   
      BEGIN    
         IF @cSKULength2Trim <> '0'
            SET @c_oFieled01 = @cSKULength2Trim
         
         EXEC dbo.ispLabelNo_Decoding_Wrapper    
          @c_SPName     = @cDecodeLabelNo    
         ,@c_LabelNo    = @cInSKU    
         ,@c_Storerkey  = @cStorerkey    
         ,@c_ReceiptKey = @nMobile    
         ,@c_POKey      = ''    
         ,@c_LangCode   = @cLangCode    
         ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- Length    
         ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- SKU output
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
    
         IF ISNULL(@cErrMsg, '') <> ''    
         BEGIN    
            SET @cErrMsg = @cErrMsg    
            GOTO Step_2_Fail    
         END    
    
         SET @cInSKU = @c_oFieled02    
      END    

      -- (Vicky08) - Start
      EXEC RDT.rdt_GETSKUCNT   
         @cStorerKey  = @cStorerKey,   
         @cSKU        = @cInSKU,       -- (ChewKP01)
         @nSKUCnt     = @nSKUCnt       OUTPUT,   
         @bSuccess    = @b_Success     OUTPUT,   
         @nErr        = @n_Err         OUTPUT,   
         @cErrMsg     = @c_ErrMsg      OUTPUT  
          
      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 77154
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_2_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 77155
         SET @cErrMsg = rdt.rdtgetmessage(  @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
         EXEC rdt.rdtSetFocusField @nMobile, 02 -- SKU
         GOTO Step_2_Fail
      END

      -- Return actual SKU If barcode is scanned (SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU OR UPC.UPC)  
      EXEC [RDT].[rdt_GETSKU]    
         @cStorerKey  = @cStorerKey,   
         @cSKU        = @cInSKU        OUTPUT,  -- (ChewKP01)
         @bSuccess    = @b_Success     OUTPUT,   
         @nErr        = @n_Err         OUTPUT,   
         @cErrMsg     = @c_ErrMsg      OUTPUT  

      SET @cSKU = @cInSKU -- (ChewKP01)
      
      SELECT @cSKUDescr = DESCR 
      FROM dbo.SKU WITH (NOLOCK)
      WHERE SKU = @cSKU
      AND   StorerKey = @cStorerKey

      SELECT @cDescription = [DESCRIPTION] 
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'KIMBALLLBL' 
      AND   Code = @cOption
      AND   StorerKey = @cStorerKey
      
      -- Prepare QTY screen var
      SET @cOutField01 = @cDescription
      SET @cOutField02 = @cSKU -- SKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
      
      -- (ChewKP01)
      SET @cDefaultQty = ''
      SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'DefaultQty', @cStorerKey)  
      
      IF @cDefaultQty <> '0'
      BEGIN
         SET @cOutField05 = @cDefaultQty -- Qty
      END
      ELSE
      BEGIN
         SET @cOutField05 = '' -- Qty
      END

      -- Go to QTY screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END -- InputKey = 1

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare next screen var
      SET @cOption = ''
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

      SET @nCnt = 1
      DECLARE CUR_KIMBALLLBL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT CODE, [DESCRIPTION] 
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'KIMBALLLBL'
      AND   StorerKey = @cStorerKey
      OPEN CUR_KIMBALLLBL
      FETCH NEXT FROM CUR_KIMBALLLBL INTO @cCode, @cDescription
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nCnt = 1
            SET @cOutField01 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 2
            SET @cOutField02 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 3
            SET @cOutField03 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 4
            SET @cOutField04 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 5
            SET @cOutField05 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 6
            SET @cOutField06 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 7
            SET @cOutField07 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 8
            SET @cOutField08 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 9
            SET @cOutField09 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
            
         SET @nCnt = @nCnt + 1

         FETCH NEXT FROM CUR_KIMBALLLBL INTO @cCode, @cDescription
      END
      CLOSE CUR_KIMBALLLBL
      DEALLOCATE CUR_KIMBALLLBL

      -- Go to SKU screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cSKU = ''
	   SET @cOutField02 = '' -- SKU
   END

END
GOTO Quit


/********************************************************************************
Scn = 3202. QTY screen
   Description (field01)
   SKU/UPC     (field02)
   Qty         (field05, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cQTY = IsNULL( @cInField05, '')

	   IF @cQTY  = '' SET @cQTY  = '0' -- Blank taken as zero

	   IF RDT.rdtIsValidQTY( @cQTY, 1) = 0
	   BEGIN
         SET @nErrNo = 77156
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         GOTO Step_3_Fail
	   END

      SET @nQTY = CAST(@cQTY AS INT)
      
      SET @cMaxAllowLabel2Print = rdt.RDTGetConfig( @nFunc, 'MAXALLOWLABEL2PRINT', @cStorerKey)  
      IF @nQTY > CAST(@cMaxAllowLabel2Print AS INT)  
	   BEGIN
         SET @nErrNo = 77157
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY Exceeded
         GOTO Step_3_Fail
	   END

      -- Printing process
      IF ISNULL(@cPrinter, '') = ''
      BEGIN                  
         SET @nErrNo = 77158
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Printer
         GOTO Step_3_Fail
      END                  
      
      SET @cPrintJobName = 'PRINT_KIMBALL_LABEL' 
                       
      SELECT @cReportType = Short
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'KIMBALLLBL'
      AND   Code = @cOption
      AND   StorerKey = @cStorerKey
                  
      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),                  
             @cTargetDB = ISNULL(RTRIM(TargetDB), '')                   
      FROM RDT.RDTReport WITH (NOLOCK)                   
      WHERE StorerKey = @cStorerKey                  
      AND   ReportType = @cReportType                  
                  
      IF ISNULL(@cDataWindow, '') = ''                  
      BEGIN                  
         SET @nErrNo = 77159
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSETUP
         GOTO Step_3_Fail
      END                  
                        
      IF ISNULL(@cTargetDB, '') = ''                  
      BEGIN                  
         SET @nErrNo = 77160
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TGETDB NOT SET                  
         GOTO Step_3_Fail
      END                  
                  
      SET @nErrNo = 0                  
      EXEC RDT.rdt_BuiltPrintJob                   
         @nMobile,                  
         @cStorerKey,                  
         @cReportType,                  
         @cPrintJobName,                  
         @cDataWindow,                  
         @cPrinter,                  
         @cTargetDB,                  
         @cLangCode,                  
         @nErrNo  OUTPUT,                   
         @cErrMsg OUTPUT,                  
         @cStorerKey,                  
         @cSKU,
         @nQty                  

      IF @nErrNo <> 0                  
      BEGIN                  
         SET @nErrNo = 77161                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSERTPRTFAIL                  
         GOTO Step_3_Fail
      END                  
  
      -- Go back to SKU Screen   
      -- Prep SKU screen var
      SELECT @cDescription = [DESCRIPTION] 
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'KIMBALLLBL' 
      AND   Code = @cOption
      AND   StorerKey = @cStorerKey
      
      -- Prepare SKU screen var
      SET @cSKU = ''
      SET @cOutField01 = @cDescription
      SET @cOutField02 = '' -- SKU

      -- Go to SKU screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END 

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Go back to SKU Screen   
      -- Prep SKU screen var
      SELECT @cDescription = [DESCRIPTION] 
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'KIMBALLLBL' 
      AND   Code = @cOption
      AND   StorerKey = @cStorerKey
      
      -- Prepare SKU screen var
      SET @cSKU = ''
      SET @cOutField01 = @cDescription
      SET @cOutField02 = '' -- SKU

      -- Go to SKU screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cQty = ''
      SET @nQty = 0
      SET @cOutField05 = ''
   END
END
GOTO Quit

/********************************************************************************
Scn = 3203. Length screen
   Length         (field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- (james01)
      -- Screen mapping
      SET @cLength = @cInField01
      
      -- Validate length
      IF ISNULL( @cLength, '') = '' OR ISNUMERIC( @cLength) <> '1'
      BEGIN
         SET @nErrNo = 77162                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Len                  
         GOTO Step_4_Fail
      END

      SET @cSKULength2Trim = @cLength
      
      SELECT @cDescription = [DESCRIPTION] 
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'KIMBALLLBL' 
      AND   Code = @cOption
      AND   StorerKey = @cStorerKey
      
      -- Prepare SKU screen var
      SET @cSKU = ''
      SET @cOutField01 = @cDescription
      SET @cOutField02 = '' -- SKU

      -- Go to SKU screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nCnt = 1
      DECLARE CUR_KIMBALLLBL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT CODE, [DESCRIPTION] 
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'KIMBALLLBL'
      AND   StorerKey = @cStorerKey
      OPEN CUR_KIMBALLLBL
      FETCH NEXT FROM CUR_KIMBALLLBL INTO @cCode, @cDescription
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nCnt = 1
            SET @cOutField01 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 2
            SET @cOutField02 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 3
            SET @cOutField03 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 4
            SET @cOutField04 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 5
            SET @cOutField05 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 6
            SET @cOutField06 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 7
            SET @cOutField07 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 8
            SET @cOutField08 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
         IF @nCnt = 9
            SET @cOutField09 = RTRIM(@cCode) + ' - ' + RTRIM(@cDescription)
            
         SET @nCnt = @nCnt + 1

         FETCH NEXT FROM CUR_KIMBALLLBL INTO @cCode, @cDescription
      END
      CLOSE CUR_KIMBALLLBL
      DEALLOCATE CUR_KIMBALLLBL
      
      SET @cOption = ''
      
      -- Go to next screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cLength = ''
      SET @cOutField01 = '0' 
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey    = @cStorerKey,
      Facility     = @cFacility,
      -- UserName     = @cUserName,
      Printer      = @cPrinter,
      Printer_Paper= @cPrinter_Paper,
      
	   V_SKU        = @cSKU,
	   V_SKUDescr   = @cSKUDescr,
	   V_QTY        = @cQTY,
	
	   V_String1    = @cOption,
      V_String2    = @cSKULength2Trim, 
      V_String3    = @cOption,
      
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