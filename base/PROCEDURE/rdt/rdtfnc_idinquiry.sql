SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/
/* Store procedure: rdtfnc_IDInquiry                                         */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: ID Inquiry                                                       */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2013-09-05 1.0  Chee     Created                                          */  
/* 2016-09-30 1.1  Ung      Performance tuning                               */
/* 2018-10-08 1.2  TungGH   Performance                                      */
/* 2019-11-08 1.3  Ung      Fix SET option                                   */
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_IDInquiry](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @bSuccess           INT
        
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

   @cLabelNo            NVARCHAR(20),
   @cPickSlipNo         NVARCHAR(10),
   @cOrderKey           NVARCHAR(10),
   @cMBOLKey            NVARCHAR(10),
   @cLoadKey            NVARCHAR(10),
   @nTotalSKU           INT,
   @nLastSKU            INT,
   @cSKU                NVARCHAR(20),
   @cSKUDescr1          NVARCHAR(20),
   @cSKUDescr2          NVARCHAR(20),
   @nSKUQty             INT,
   @nCurrentPage        INT,
   @nTotalPage          INT,
   @cSOStatus           NVARCHAR(10),

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

DECLARE @tPackDetail TABLE (
   SeqNo    INT IDENTITY(1,1),
   SKU      NVARCHAR(20),
   SKUDescr NVARCHAR(40),
   Qty      INT
)
         
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

   @cLabelNo         = V_String1,
   @cMBOLKey         = V_String2,
   @cLoadKey         = V_String3,
   @cOrderKey        = V_String4,
   @cSOStatus        = V_String5,
   @cPickSlipNo      = V_String6,
   
   @nTotalSKU        = V_Integer1,
   @nLastSKU         = V_Integer2,
         
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
IF @nFunc = 1801
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1801
   IF @nStep = 1 GOTO Step_1   -- Scn = 3640  Scan LABELNO
   IF @nStep = 2 GOTO Step_2   -- Scn = 3641  Scan LABELNO Show Details
   IF @nStep = 3 GOTO Step_3   -- Scn = 3642  MultiSKU Info (1 SKU)
   IF @nStep = 4 GOTO Step_4   -- Scn = 3643  MultiSKU Info (2 SKU)
   IF @nStep = 5 GOTO Step_5   -- Scn = 3644  MultiSKU Info (3 SKU)
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1801)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 3640
   SET @nStep = 1

   -- initialise all variable
   SET @cLabelNo = ''
   SET @cLoadKey = ''
   SET @cMBOLKey = ''
   SET @cPickSlipNo = ''
   SET @nTotalSKU = 0
   SET @nLastSKU = 0

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
   SET @cOutField12 = '' 
END
GOTO Quit

/********************************************************************************
Step 1. screen = 3640
   LABELNO: 
   (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Reset mapping
      SET @cLabelNo = @cInField01

      -- Check label
      IF ISNULL(@cLabelNo, '') = ''
      BEGIN
         SET @nErrNo = 82601
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NEED LABELNO  
         GOTO Step_1_Fail  
      END

      SELECT TOP 1
         @cPickSlipNo = PH.PickSlipNo,   
         @cOrderKey = PH.OrderKey,   
         @cLoadKey = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE PH.LoadKey END
      FROM dbo.PackHeader PH WITH (NOLOCK)   
         JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
      WHERE PD.StorerKey = @cStorerKey   
         AND PD.LabelNo = @cLabelNo  

      -- Check ID valid  
      IF ISNULL(@cPickSlipNo, '') = '' 
      BEGIN  
         SET @nErrNo = 82602  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV LABELNO  
         GOTO Step_1_Fail  
      END  

      INSERT INTO @tPackDetail 
      SELECT SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40), PD.Qty
      FROM PackDetail PD WITH (NOLOCK)
      JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey)
      WHERE PD.StorerKey = @cStorerKey
        AND PD.PickSlipNo = @cPickSlipNo 
        AND PD.LabelNo = @cLabelNo
      ORDER BY PD.LabelLine

      SELECT @nTotalSKU = COUNT(1)
      FROM @tPackDetail

      SELECT @cLoadKey = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
      FROM LOADPLANDETAIL WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      SELECT 
         @cMBOLKey = MBOLKey, 
         @cLoadKey = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
      FROM MBOLDETAIL WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      SELECT @cSOStatus = SOStatus 
      FROM Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      SELECT TOP 1 
         @cSKU = SKU,
         @cSKUDescr1 = SUBSTRING(SKUDescr, 1, 20),
         @cSKUDescr2 = SUBSTRING(SKUDescr, 21, 20),
         @nSKUQty = Qty,
         @nLastSKU = SeqNo
      FROM @tPackDetail

      -- Prep next screen var 
      SET @cOutField01 = ''
      SET @cOutField02 = @cLabelNo
      SET @cOutField03 = @cMBOLKey
      SET @cOutField04 = @cLoadKey
      SET @cOutField05 = @cOrderKey
      SET @cOutField06 = @cSOStatus
      SET @cOutField07 = @cPickSlipNo
      SET @cOutField08 = @cSKU
      SET @cOutField09 = @cSKUDescr1
      SET @cOutField10 = @cSKUDescr2
      SET @cOutField11 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)

      IF @nTotalSKU > 1
         SET @nLastSKU = @nLastSKU + 1

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0 

      SET @cLabelNo = ''
      SET @cMBOLKey = ''
      SET @cLoadKey = ''
      SET @cOrderKey = ''
      SET @cSOStatus = ''
      SET @cPickSlipNo = ''
      SET @nTotalSKU = 0
      SET @nLastSKU = 0
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cLabelNo = ''
      SET @cMBOLKey = ''
      SET @cLoadKey = ''
      SET @cOrderKey = ''
      SET @cSOStatus = ''
      SET @cPickSlipNo = ''
      SET @nTotalSKU = 0
      SET @nLastSKU = 0

      SET @cOutField01 = '' 
   END

END
GOTO Quit

/********************************************************************************
Step 2. screen = 3641
   LABELNO: 
   (Field01, input)
   (Field02, display)
   MOBOLKEY: (Field03, display)  
   LOADKEY: (Field04, display)   
   ORDERKEY: (Field05, display)   
   SOSTATUS: (Field06, display)   
   PSNO: (Field07, display)   
   SKU:
   (Field09, display) 
   (Field10, display)
   (Field11, display)
   QTY: (Field12, display) 
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      IF ISNULL(@cLabelNo, '') <> '' AND @cInField01 = @cLabelNo
         GOTO Quit

      IF ISNULL(@cInField01, '') <> '' 
      BEGIN
         DECLARE 
            @c_PickSlipNo NVARCHAR(10),
            @c_OrderKey   NVARCHAR(10),
            @c_LoadKey    NVARCHAR(10)

         SELECT TOP 1
            @c_PickSlipNo = PH.PickSlipNo,   
            @c_OrderKey = PH.OrderKey,   
            @c_LoadKey = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE PH.LoadKey END
         FROM dbo.PackHeader PH WITH (NOLOCK)   
            JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
         WHERE PD.StorerKey = @cStorerKey   
            AND PD.LabelNo = @cInField01  

         IF ISNULL(@c_PickSlipNo, '') = ''  
         BEGIN  
            SET @nErrNo = 82603 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV LABELNO  
            GOTO Step_2_Fail  
         END  

         SET @cLabelNo = @cInField01
         SET @cPickSlipNo = @c_PickSlipNo 
         SET @cOrderKey = @c_OrderKey
         SET @cLoadKey = @c_LoadKey
         SET @cMBOLKey = ''
         SET @cSOStatus = ''
         SET @nTotalSKU = 0
         SET @nLastSKU = 0
      END -- IF ISNULL(@cInField01, '') <> ''

      INSERT INTO @tPackDetail 
      SELECT SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40), PD.Qty
      FROM PackDetail PD WITH (NOLOCK)
      JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey)
      WHERE PD.StorerKey = @cStorerKey
        AND PD.PickSlipNo = @cPickSlipNo 
        AND PD.LabelNo = @cLabelNo
      ORDER BY PD.LabelLine

      IF @nLastSKU > 1
      BEGIN
         -- Prep next screen var 
         DECLARE CUR_PACKDETAIL_SKUQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TOP 3 SKU, SUBSTRING(SKUDescr, 1, 20), SUBSTRING(SKUDescr, 21, 20), Qty, SeqNo  
         FROM @tPackDetail
         WHERE SeqNo > 1

         OPEN CUR_PACKDETAIL_SKUQTY    
         FETCH NEXT FROM CUR_PACKDETAIL_SKUQTY INTO @cSKU, @cSKUDescr1, @cSKUDescr2, @nSKUQty, @nLastSKU
         WHILE (@@FETCH_STATUS <> -1)    
         BEGIN
            IF @nLastSKU%3 = 2
            BEGIN
               SET @cOutField01 = @cSKU
               SET @cOutField02 = @cSKUDescr1
               SET @cOutField03 = @cSKUDescr2
               SET @cOutField04 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)

               SET @nScn = @nScn + 1
               SET @nStep = @nStep + 1
            END
            ELSE IF @nLastSKU%3 = 0
            BEGIN
               SET @cOutField05 = @cSKU
               SET @cOutField06 = @cSKUDescr1
               SET @cOutField07 = @cSKUDescr2
               SET @cOutField08 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)

               SET @nScn = @nScn + 1
               SET @nStep = @nStep + 1
            END
            ELSE IF @nLastSKU%3 = 1
            BEGIN
               SET @cOutField09 = @cSKU
               SET @cOutField10 = @cSKUDescr1
               SET @cOutField11 = @cSKUDescr2
               SET @cOutField12 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)

               SET @nScn = @nScn + 1
               SET @nStep = @nStep + 1
            END

            FETCH NEXT FROM CUR_PACKDETAIL_SKUQTY INTO @cSKU, @cSKUDescr1, @cSKUDescr2, @nSKUQty, @nLastSKU
         END  
         CLOSE CUR_PACKDETAIL_SKUQTY
         DEALLOCATE CUR_PACKDETAIL_SKUQTY
      END
      ELSE 
      BEGIN
         SELECT @nTotalSKU = COUNT(1)
         FROM @tPackDetail

         SELECT @cLoadKey = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
         FROM LOADPLANDETAIL WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         SELECT 
            @cMBOLKey = MBOLKey, 
            @cLoadKey = CASE WHEN ISNULL(@cLoadKey, '') <> '' THEN @cLoadKey ELSE LoadKey END
         FROM MBOLDETAIL WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         SELECT @cSOStatus = SOStatus 
         FROM Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         SELECT TOP 1 
            @cSKU = SKU,
            @cSKUDescr1 = SUBSTRING(SKUDescr, 1, 20),
            @cSKUDescr2 = SUBSTRING(SKUDescr, 21, 20),
            @nSKUQty = Qty,
            @nLastSKU = SeqNo
         FROM @tPackDetail

         -- Prep next screen var 
         SET @cOutField01 = ''
         SET @cOutField02 = @cLabelNo
         SET @cOutField03 = @cMBOLKey
         SET @cOutField04 = @cLoadKey
         SET @cOutField05 = @cOrderKey
         SET @cOutField06 = @cSOStatus
         SET @cOutField07 = @cPickSlipNo
         SET @cOutField08 = @cSKU
         SET @cOutField09 = @cSKUDescr1
         SET @cOutField10 = @cSKUDescr2
         SET @cOutField11 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)

         IF @nTotalSKU > 1
            SET @nLastSKU = @nLastSKU + 1

         SET @nScn = @nScn
         SET @nStep = @nStep 
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      SET @cLabelNo = ''
      SET @cMBOLKey = ''
      SET @cLoadKey = ''
      SET @cOrderKey = ''
      SET @cSOStatus = ''
      SET @cPickSlipNo = ''
      SET @nTotalSKU = 0
      SET @nLastSKU = 0
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOutField01 = '' 
   END

END
GOTO Quit

/********************************************************************************
Step 3. screen = 3642
   SKU:
   (Field01, display)
   (Field02, display)
   (Field03, display)
   QTY: (Field04, display)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      SET @nScn = @nScn 
      SET @nStep = @nStep 
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      INSERT INTO @tPackDetail 
      SELECT SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40), PD.Qty
      FROM PackDetail PD WITH (NOLOCK)
      JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey)
      WHERE PD.StorerKey = @cStorerKey
        AND PD.PickSlipNo = @cPickSlipNo 
        AND PD.LabelNo = @cLabelNo
      ORDER BY PD.LabelLine

      SET @nCurrentPage = (@nLastSKU + 1)/3 + 1

      IF @nCurrentPage = 2
      BEGIN
         SELECT TOP 1 
            @cSKU = SKU,
            @cSKUDescr1 = SUBSTRING(SKUDescr, 1, 20),
            @cSKUDescr2 = SUBSTRING(SKUDescr, 21, 20),
            @nSKUQty = Qty,
            @nLastSKU = SeqNo
         FROM @tPackDetail

         -- Prep next screen var 
         SET @cOutField01 = ''
         SET @cOutField02 = @cLabelNo
         SET @cOutField03 = @cMBOLKey
         SET @cOutField04 = @cLoadKey
         SET @cOutField05 = @cOrderKey
         SET @cOutField06 = @cSOStatus
         SET @cOutField07 = @cPickSlipNo
         SET @cOutField08 = @cSKU
         SET @cOutField09 = @cSKUDescr1
         SET @cOutField10 = @cSKUDescr2
         SET @cOutField11 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)

         IF @nTotalSKU > 1
            SET @nLastSKU = @nLastSKU + 1

         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END 
      ELSE
      BEGIN
         SET @nCurrentPage = @nCurrentPage - 1

         DECLARE CUR_PACKDETAIL_SKUQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TOP 3 SKU, SUBSTRING(SKUDescr, 1, 20), SUBSTRING(SKUDescr, 21, 20), Qty, SeqNo  
         FROM @tPackDetail
         WHERE SeqNo > 3*@nCurrentPage-5

         OPEN CUR_PACKDETAIL_SKUQTY    
         FETCH NEXT FROM CUR_PACKDETAIL_SKUQTY INTO @cSKU, @cSKUDescr1, @cSKUDescr2, @nSKUQty, @nLastSKU
         WHILE (@@FETCH_STATUS <> -1)    
         BEGIN
            IF @nLastSKU%3 = 2
            BEGIN
               SET @cOutField01 = @cSKU
               SET @cOutField02 = @cSKUDescr1
               SET @cOutField03 = @cSKUDescr2
               SET @cOutField04 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)
            END
            ELSE IF @nLastSKU%3 = 0
            BEGIN
               SET @cOutField05 = @cSKU
               SET @cOutField06 = @cSKUDescr1
               SET @cOutField07 = @cSKUDescr2
               SET @cOutField08 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)
            END
            ELSE IF @nLastSKU%3 = 1
            BEGIN
               SET @cOutField09 = @cSKU
               SET @cOutField10 = @cSKUDescr1
               SET @cOutField11 = @cSKUDescr2
               SET @cOutField12 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)
            END

            FETCH NEXT FROM CUR_PACKDETAIL_SKUQTY INTO @cSKU, @cSKUDescr1, @cSKUDescr2, @nSKUQty, @nLastSKU
         END  
         CLOSE CUR_PACKDETAIL_SKUQTY
         DEALLOCATE CUR_PACKDETAIL_SKUQTY

         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
   END  
   GOTO Quit
   
   Step_3_Fail:
   GOTO Quit   
END
GOTO Quit

/********************************************************************************
Step 4. screen = 3643
   SKU:
   (Field01, display)
   (Field02, display)
   (Field03, display)
   QTY: (Field04, display)
   (Field05, display)
   (Field06, display)
   (Field07, display)
   QTY: (Field08, display)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      SET @nScn = @nScn 
      SET @nStep = @nStep 
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      INSERT INTO @tPackDetail 
      SELECT SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40), PD.Qty
      FROM PackDetail PD WITH (NOLOCK)
      JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey)
      WHERE PD.StorerKey = @cStorerKey
        AND PD.PickSlipNo = @cPickSlipNo 
        AND PD.LabelNo = @cLabelNo
      ORDER BY PD.LabelLine

      SET @nCurrentPage = (@nLastSKU + 1)/3 + 1

      IF @nCurrentPage = 2
      BEGIN
         SELECT TOP 1 
            @cSKU = SKU,
            @cSKUDescr1 = SUBSTRING(SKUDescr, 1, 20),
            @cSKUDescr2 = SUBSTRING(SKUDescr, 21, 20),
            @nSKUQty = Qty,
            @nLastSKU = SeqNo
         FROM @tPackDetail

         -- Prep next screen var 
         SET @cOutField01 = ''
         SET @cOutField02 = @cLabelNo
         SET @cOutField03 = @cMBOLKey
         SET @cOutField04 = @cLoadKey
         SET @cOutField05 = @cOrderKey
         SET @cOutField06 = @cSOStatus
         SET @cOutField07 = @cPickSlipNo
         SET @cOutField08 = @cSKU
         SET @cOutField09 = @cSKUDescr1
         SET @cOutField10 = @cSKUDescr2
         SET @cOutField11 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)

         IF @nTotalSKU > 1
            SET @nLastSKU = @nLastSKU + 1

         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END 
      ELSE
      BEGIN
         SET @nCurrentPage = @nCurrentPage - 1

         DECLARE CUR_PACKDETAIL_SKUQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TOP 3 SKU, SUBSTRING(SKUDescr, 1, 20), SUBSTRING(SKUDescr, 21, 20), Qty, SeqNo  
         FROM @tPackDetail
         WHERE SeqNo > 3*@nCurrentPage-5

         OPEN CUR_PACKDETAIL_SKUQTY    
         FETCH NEXT FROM CUR_PACKDETAIL_SKUQTY INTO @cSKU, @cSKUDescr1, @cSKUDescr2, @nSKUQty, @nLastSKU
         WHILE (@@FETCH_STATUS <> -1)    
         BEGIN
            IF @nLastSKU%3 = 2
            BEGIN
               SET @cOutField01 = @cSKU
               SET @cOutField02 = @cSKUDescr1
               SET @cOutField03 = @cSKUDescr2
               SET @cOutField04 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)
            END
            ELSE IF @nLastSKU%3 = 0
            BEGIN
               SET @cOutField05 = @cSKU
               SET @cOutField06 = @cSKUDescr1
               SET @cOutField07 = @cSKUDescr2
               SET @cOutField08 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)
            END
            ELSE IF @nLastSKU%3 = 1
            BEGIN
               SET @cOutField09 = @cSKU
               SET @cOutField10 = @cSKUDescr1
               SET @cOutField11 = @cSKUDescr2
               SET @cOutField12 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)
            END

            FETCH NEXT FROM CUR_PACKDETAIL_SKUQTY INTO @cSKU, @cSKUDescr1, @cSKUDescr2, @nSKUQty, @nLastSKU
         END  
         CLOSE CUR_PACKDETAIL_SKUQTY
         DEALLOCATE CUR_PACKDETAIL_SKUQTY

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END  
   GOTO Quit
   
   Step_4_Fail:
   GOTO Quit   
END
GOTO Quit

/********************************************************************************
Step 5. screen = 3644
   SKU:
   (Field01, display)
   (Field02, display)
   (Field03, display)
   QTY: (Field04, display)
   (Field05, display)
   (Field06, display)
   (Field07, display)
   QTY: (Field08, display)
   (Field09, display)
   (Field10, display)
   (Field11, display)
   QTY: (Field12, display)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      SET @nCurrentPage = (@nLastSKU + 1)/3 + 1
      SET @nTotalPage = (@nTotalSKU + 1)/3 + 1

      IF @nCurrentPage = @nTotalPage
         GOTO Quit

      SET @nCurrentPage = @nCurrentPage + 1

      INSERT INTO @tPackDetail 
      SELECT SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40), PD.Qty
      FROM PackDetail PD WITH (NOLOCK)
      JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey)
      WHERE PD.StorerKey = @cStorerKey
        AND PD.PickSlipNo = @cPickSlipNo 
        AND PD.LabelNo = @cLabelNo
      ORDER BY PD.LabelLine

      -- Prep next screen var 
      DECLARE CUR_PACKDETAIL_SKUQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TOP 3 SKU, SUBSTRING(SKUDescr, 1, 20), SUBSTRING(SKUDescr, 21, 20), Qty, SeqNo  
      FROM @tPackDetail
      WHERE SeqNo > 3*@nCurrentPage-5

      OPEN CUR_PACKDETAIL_SKUQTY    
      FETCH NEXT FROM CUR_PACKDETAIL_SKUQTY INTO @cSKU, @cSKUDescr1, @cSKUDescr2, @nSKUQty, @nLastSKU
      WHILE (@@FETCH_STATUS <> -1)    
      BEGIN
         IF @nLastSKU%3 = 2
         BEGIN
            SET @cOutField01 = @cSKU
            SET @cOutField02 = @cSKUDescr1
            SET @cOutField03 = @cSKUDescr2
            SET @cOutField04 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)

            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2 
         END
         ELSE IF @nLastSKU%3 = 0
         BEGIN
            SET @cOutField05 = @cSKU
            SET @cOutField06 = @cSKUDescr1
            SET @cOutField07 = @cSKUDescr2
            SET @cOutField08 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)

            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
         END
         ELSE IF @nLastSKU%3 = 1
         BEGIN
            SET @cOutField09 = @cSKU
            SET @cOutField10 = @cSKUDescr1
            SET @cOutField11 = @cSKUDescr2
            SET @cOutField12 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)

            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
         END

         FETCH NEXT FROM CUR_PACKDETAIL_SKUQTY INTO @cSKU, @cSKUDescr1, @cSKUDescr2, @nSKUQty, @nLastSKU
      END  
      CLOSE CUR_PACKDETAIL_SKUQTY
      DEALLOCATE CUR_PACKDETAIL_SKUQTY
   END

   IF @nInputKey = 0 -- ESC
   BEGIN

      INSERT INTO @tPackDetail 
      SELECT SKU.SKU, SUBSTRING(SKU.DESCR, 1, 40), PD.Qty
      FROM PackDetail PD WITH (NOLOCK)
      JOIN SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey)
      WHERE PD.StorerKey = @cStorerKey
        AND PD.PickSlipNo = @cPickSlipNo 
        AND PD.LabelNo = @cLabelNo
      ORDER BY PD.LabelLine

      SET @nCurrentPage = (@nLastSKU + 1)/3 + 1

      IF @nCurrentPage = 2
      BEGIN
         SELECT TOP 1 
            @cSKU = SKU,
            @cSKUDescr1 = SUBSTRING(SKUDescr, 1, 20),
            @cSKUDescr2 = SUBSTRING(SKUDescr, 21, 20),
            @nSKUQty = Qty,
            @nLastSKU = SeqNo
         FROM @tPackDetail

         -- Prep next screen var 
         SET @cOutField01 = ''
         SET @cOutField02 = @cLabelNo
         SET @cOutField03 = @cMBOLKey
         SET @cOutField04 = @cLoadKey
         SET @cOutField05 = @cOrderKey
         SET @cOutField06 = @cSOStatus
         SET @cOutField07 = @cPickSlipNo
         SET @cOutField08 = @cSKU
         SET @cOutField09 = @cSKUDescr1
         SET @cOutField10 = @cSKUDescr2
         SET @cOutField11 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)

         IF @nTotalSKU > 1
            SET @nLastSKU = @nLastSKU + 1

         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3
      END 
      ELSE
      BEGIN
         SET @nCurrentPage = @nCurrentPage - 1

         DECLARE CUR_PACKDETAIL_SKUQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TOP 3 SKU, SUBSTRING(SKUDescr, 1, 20), SUBSTRING(SKUDescr, 21, 20), Qty, SeqNo  
         FROM @tPackDetail
         WHERE SeqNo > 3*@nCurrentPage-5

         OPEN CUR_PACKDETAIL_SKUQTY    
         FETCH NEXT FROM CUR_PACKDETAIL_SKUQTY INTO @cSKU, @cSKUDescr1, @cSKUDescr2, @nSKUQty, @nLastSKU
         WHILE (@@FETCH_STATUS <> -1)    
         BEGIN
            IF @nLastSKU%3 = 2
            BEGIN
               SET @cOutField01 = @cSKU
               SET @cOutField02 = @cSKUDescr1
               SET @cOutField03 = @cSKUDescr2
               SET @cOutField04 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)
            END
            ELSE IF @nLastSKU%3 = 0
            BEGIN
               SET @cOutField05 = @cSKU
               SET @cOutField06 = @cSKUDescr1
               SET @cOutField07 = @cSKUDescr2
               SET @cOutField08 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)
            END
            ELSE IF @nLastSKU%3 = 1
            BEGIN
               SET @cOutField09 = @cSKU
               SET @cOutField10 = @cSKUDescr1
               SET @cOutField11 = @cSKUDescr2
               SET @cOutField12 = CAST(@nSKUQty AS NCHAR(10)) + CAST(@nLastSKU AS NVARCHAR) + '/' + CAST(@nTotalSKU AS NVARCHAR)
            END

            FETCH NEXT FROM CUR_PACKDETAIL_SKUQTY INTO @cSKU, @cSKUDescr1, @cSKUDescr2, @nSKUQty, @nLastSKU
         END  
         CLOSE CUR_PACKDETAIL_SKUQTY
         DEALLOCATE CUR_PACKDETAIL_SKUQTY

         SET @nScn = @nScn
         SET @nStep = @nStep 
      END
   END  
   GOTO Quit
   
   Step_5_Fail:
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

      V_String1     = @cLabelNo,  
      V_String2     = @cMBOLKey,
      V_String3     = @cLoadKey,   
      V_String4     = @cOrderKey,
      V_String5     = @cSOStatus,
      V_String6     = @cPickSlipNo,
      
      V_Integer1    = @nTotalSKU,
      V_Integer2    = @nLastSKU,

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