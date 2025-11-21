SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_UCCReceiveAudit                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 10-Dec-2019  1.0  Chermaine   WMS-11357 - Created                    */
/* 19-Mar-2020  1.1  James       WMS-12451 Remove check ASN finalized   */
/*                               Add check UCC must received (james01)  */
/* 04-Aug-2020  1.2  Chermaine   Tuning                                 */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_UCCReceiveAudit] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(125) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cUserName   NVARCHAR( 18),
   @cSKU        NVARCHAR( 20),
   @bSuccess    INT,
   @nCQTY       INT,
   @nPQTY       INT,
   @nTQTY       INT,  

   @cReceiptKey      NVARCHAR( 10),
   @cUCC             NVARCHAR( 20), 
   @cChkFacility     NVARCHAR( 5), 
   @cChkStorerKey    NVARCHAR( 15),
   @cChkReceiptKey   NVARCHAR( 10),
   @cReceiptStatus   NVARCHAR( 10),
   @cPosition        NVARCHAR( 20),
   @nVariance        INT,
   @cOption          NVARCHAR(1),
   @nDeviceCount     NVARCHAR( 5),
   @nSKUCount        NVARCHAR( 5),
   @nMixSKU          INT,
   @cUCCStatus       NVARCHAR( 10),
   @cAllowASNNotFinalize   NVARCHAR( 1),

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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)

-- Getting Mobile information
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @nMenu       = Menu,
   @cLangCode   = Lang_code,

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,
   @cUserName   = UserName,

   @cReceiptKey = V_ReceiptKey,
   @cUCC        = V_UCC,
   @cSKU        = V_SKU,

   @nMixSKU       = V_Integer1,
   @nVariance     = V_Integer2,
   @nDeviceCount  = V_Integer3,
   @nSKUCount     = V_Integer4,

   @cOption              = V_String1,
   @cAllowASNNotFinalize = V_String2,
   
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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15

FROM rdt.RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 1840 
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func
   IF @nStep = 1 GOTO Step_1   -- Scn = 5650. ASN
   IF @nStep = 2 GOTO Step_2   -- Scn = 5651. UCC
   IF @nStep = 3 GOTO Step_3   -- Scn = 5652. reset Ucc?
   IF @nStep = 4 GOTO Step_4   -- Scn = 5653. Single SKU
   IF @nStep = 5 GOTO Step_5   -- Scn = 5654. Mixed SKU
   IF @nStep = 6 GOTO Step_6   -- Scn = 5655. Variance
   IF @nStep = 7 GOTO Step_7   -- Scn = 5656. Adj?
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1840. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Initialize value
   SET @cReceiptKey = ''

   -- (james01)
   SET @cAllowASNNotFinalize = rdt.rdtGetConfig( @nFunc, 'AllowASNNotFinalize', @cStorerKey)

   -- Prep next screen var
   SET @cOutField01 = '' -- ASN

   SET @nScn = 5650
   SET @nStep = 1

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 5650 (ANS)
   ASN      (field01, input) 
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cReceiptKey = @cInField01

      IF ISNULL( @cReceiptKey, '') = '' 
      BEGIN
         SET @nErrNo = 147051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN
         GOTO Quit
      END
      
      -- Get the ASN info
      SELECT
         @cChkFacility = Facility,
         @cChkStorerKey = StorerKey,
         @cReceiptStatus = ASNStatus
      FROM dbo.Receipt WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 147052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exists
         GOTO Quit
      END

      -- Validate ASN in different facility
      IF @cFacility <> @cChkFacility
      BEGIN
         SET @nErrNo = 147053
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Quit
      END

      -- Validate ASN belong to the storer
      IF @cStorerKey <> @cChkStorerKey
      BEGIN
         SET @nErrNo = 147054
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
         GOTO Quit
      END
      
      -- (james01)
      IF @cAllowASNNotFinalize = '0'
      BEGIN
         IF EXISTS (SELECT TOP 1 1 FROM RECEIPTdetail (NOLOCK) WHERE ReceiptKey= @cReceiptKey AND storerKey = @cStorerKey AND FinalizeFlag <> 'Y') 
         BEGIN
      	   SET @nErrNo = 147068
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotFinalize
            GOTO Quit
         END
      END
      
      SET @nDeviceCount = '-'
      --check devide position : sku  
      --SELECT @nDeviceCount = COUNT(DISTINCT dp.devicePosition) 
      --FROM (
      --      SELECT 
      --         userdefine01 AS ucc, COUNT(DISTINCT sku) AS Ctn 
      --      FROM RECEIPTDETAIL (NOLOCK) 
      --      WHERE receiptKey = @cReceiptKey 
      --      GROUP BY userdefine01) aa
      --JOIN RECEIPTDETAIL rd (NOLOCK) 
      --on aa.ucc = rd.UserDefine01
      --JOIN SKU S(NOLOCK)
      --ON rd.sku = s.Sku
      --   AND rd.storerKey =s.StorerKey
      --JOIN CODELKUP C (NOLOCK)
      --ON s.busr7 = c.Code
      --   AND s.StorerKey = c.Storerkey
      --JOIN DeviceProfile dp (NOLOCK) 
      --ON c.UDF02 = dp.deviceID
      --where aa.ctn > 1
      --   AND rd.storerkey = @cStorerKey
      --   AND rd.receiptKey = @cReceiptKey 
      --   AND c.listname = 'SDCPOSIT'

      -- (james01)
      IF @cAllowASNNotFinalize = '0'
      BEGIN         
         SELECT @nSKUCount = COUNT(cc.sku)
         FROM (
	         SELECT rd.sku,rd.ReceiptKey,SUM(QtyReceived) AS qty
            FROM (
      	         --find mixCarton in ASN
                  SELECT 
                     userdefine01 AS ucc, COUNT(DISTINCT sku) AS Ctn 
                  FROM RECEIPTDETAIL (NOLOCK) 
                  WHERE receiptKey = @cReceiptKey 
                  GROUP BY userdefine01
                  ) aa
            JOIN RECEIPTDETAIL rd (NOLOCK)
            ON rd.UserDefine01 = aa.ucc
            WHERE ctn > 1
               AND rd.receiptKey = @cReceiptKey 
               AND rd.StorerKey = @cStorerKey
               AND rd.UserDefine01 = aa.ucc
               GROUP BY rd.ReceiptKey,rd.sku 
         )cc
         JOIN sku s (NOLOCK)
         ON cc.sku = s.sku 
            AND s.storerKey = @cStorerKey
         JOIN CODELKUP c (NOLOCK)
         ON s.BUSR7 = c.code
            AND s.StorerKey = c. Storerkey
         where c.listname = 'SDCPOSIT'
            AND cc.qty > c.short
      END
      ELSE
      BEGIN
         SELECT @nSKUCount = COUNT(cc.sku)
         FROM (
	         SELECT rd.sku,rd.ReceiptKey,SUM(QtyExpected) AS qty
            FROM (
      	         --find mixCarton in ASN
                  SELECT 
                     userdefine01 AS ucc, COUNT(DISTINCT sku) AS Ctn 
                  FROM RECEIPTDETAIL (NOLOCK) 
                  WHERE receiptKey = @cReceiptKey 
                  GROUP BY userdefine01
                  ) aa
            JOIN RECEIPTDETAIL rd (NOLOCK)
            ON rd.UserDefine01 = aa.ucc
            WHERE ctn > 1
               AND rd.receiptKey = @cReceiptKey 
               AND rd.StorerKey = @cStorerKey
               AND rd.UserDefine01 = aa.ucc
               GROUP BY rd.ReceiptKey,rd.sku 
         )cc
         JOIN sku s (NOLOCK)
         ON cc.sku = s.sku 
            AND s.storerKey = @cStorerKey
         JOIN CODELKUP c (NOLOCK)
         ON s.BUSR7 = c.code
            AND s.StorerKey = c. Storerkey
         where c.listname = 'SDCPOSIT'
            AND cc.qty > c.short
      END
      
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @nDeviceCount + ':' + @nSKUCount
      SET @cOutField03 = ''

      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 2. Scn = 5651. (UCC)
   ASN         (field01)
   DeviceCount (field02)
   UCC         (field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField03

      IF ISNULL( @cUCC, '') = ''
      BEGIN
         SET @nErrNo = 147055
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC required
         GOTO Quit
      END

      SELECT @cChkReceiptKey = ReceiptKey,
             @cUCCStatus = [Status]
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   UCCNo = @cUCC

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 147056
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Not Exists
         GOTO Quit
      END
      
      -- Validate UCC in ASN
      IF @cChkReceiptKey <> @cReceiptKey
      BEGIN
         SET @nErrNo = 147057
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC notIN ASN
         GOTO Quit
      END
      
      -- (james01)
      IF @cUCCStatus = '0'
      BEGIN
         SET @nErrNo = 147074
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC NotReceive
         GOTO Quit
      END

      -- (james01)
      IF @cUCCStatus <> '1'
      BEGIN
         SET @nErrNo = 147075
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv UCC Status
         GOTO Quit
      END
      
      SELECT @nMixSKU = COUNT(DISTINCT SKU) 
      FROM UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   UCCNo = @cUCC
      
      -- UCC checked, reset?
      IF EXISTS( SELECT TOP 1 1 FROM rdt.RDTReceiveAudit WITH (NOLOCK) WHERE UCCNo = @cUCC AND StorerKey = @cStorerKey AND ReceiptKey = @cReceiptKey)
      BEGIN
          -- Prep next screen var --(Rest Ucc screen)
         SET @cOutField01 = @cUCC
         SET @cOutField02 = ''

         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
         GOTO Quit
      END
           
      --Mix SKU
      IF @nMixSKU >1
      BEGIN
      	SET @cOutField01 = @cUCC
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         
         SET @nScn  = @nScn + 3
         SET @nStep = @nStep + 3
      END
      ELSE -- Single SKU
      BEGIN
      	
      	SET @cOutField01 = @cUCC
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''

         SET @nScn  = @nScn + 2
         SET @nStep = @nStep + 2
      END
      
      ---- EventLog --(cc01)
      --EXEC RDT.rdt_STD_EventLog
      --   @cActionType = '4',
      --   @cUserID     = @cUserName,
      --   @nMobileNo   = @nMobile,
      --   @nFunctionID = @nFunc,
      --   @cFacility   = @cFacility,
      --   @cStorerKey  = @cStorerKey,
      --   @nStep       = @nStep,
      --   @cUCC        = @cUCC,
      --   @cReceiptKey = @cReceiptKey,
      --   @cLane       = @cLane   
         
   END
   
   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep prev screen var
      SET @cReceiptKey = ''
      SET @cUCC = ''

      SET @cOutField01 = ''
      
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 5652. (Reset UCC)
   UCC         (field01)
   Option       (field02, input)
********************************************************************************/
Step_3:
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN
      
      -- Screen mapping  
      SET @cOption = @cInField02  
  
      -- Check blank  
      IF @cOption = ''  
      BEGIN  
         SET @nErrNo = 147058
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option   
         GOTO Quit  
      END  
      
      -- Check option valid  
      IF @cOption NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 147059  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option  
         GOTO Quit  
      END  
  
      IF @cOption = '1' -- YES  
      BEGIN  
      	--del FROM rdt.RDTReceiveAudit then see go to mix/single sku screen
      	DELETE FROM rdt.RDTReceiveAudit WHERE uccno = @cUCC
      	
      	IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 147060
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL Log Fail
            GOTO Quit
         END
      	 
         --Mix SKU
         IF @nMixSKU >1
         BEGIN
      	   SET @cOutField01 = @cUCC
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
         
            SET @nScn  = @nScn + 2
            SET @nStep = @nStep + 2
         END
         ELSE -- Single SKU
         BEGIN
      	
      	   SET @cOutField01 = @cUCC
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = ''

            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1
         END 
  
         GOTO Quit  
      END 
      
      IF @cOption = '2' -- NO
      BEGIN
      	-- back to ucc screen
         -- Prepare next screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @nDeviceCount + ':' + @nSKUCount  
         SET @cOutField03 = ''
         
         SET @nScn = @nScn - 1  
         SET @nStep = @nStep - 1

         GOTO Quit  
      END       
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
   	SET @cUCC =''
      --back to ucc screen     
      SET @cOutField01 = @cReceiptKey 
      SET @cOutField02 = @nDeviceCount + ':' + @nSKUCount  
      SET @cOutField03 = ''
           
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit     
END  
GOTO Quit 

/********************************************************************************
Step 4. Scn = 5653. (Single SKU)
   UCC            (field01)
   SKU            (field02, input)
   SKU            (field03)
   SCAN QTY       (field04)
   CTN QTY        (field05)
   CTN TOTAL QTY  (field06)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField02 -- SKU
      
      -- Check SKU blank
      IF @cSKU = ''
      BEGIN
         SET @nErrNo = 147061
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- SKU required
         GOTO Quit
      END

      -- Check SKU valid
      EXEC dbo.nspg_GETSKU @cStorerKey, @cSKU OUTPUT, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
      IF @bSuccess = 0
      BEGIN
         SET @nErrNo = 147062
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid SKU
         GOTO Quit
      END

      -- Check SKU in ASN
      IF NOT EXISTS( SELECT TOP 1 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND SKU = @cSKU AND userdefine01 = @cUCC)
      BEGIN
         SET @nErrNo = 147063
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- SKU NotExists
         --GOTO Quit
      END
      
      SET @nErrNo = 0
      -- Confirm
      EXEC rdt.rdt_UCCReceiveAudit_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey
         ,@cReceiptKey
         ,@nMixSKU
         ,@cUCC
         ,@cSKU
         ,1 -- @nQTY
         ,''
         ,@nErrNo    OUTPUT
         ,@cErrMsg   OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Get statistic
      SET @nCQTY = 0
      EXECUTE rdt.rdt_UCCReceiveAudit_GetStat @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey
         ,@cReceiptKey
         ,@cUCC
         ,@cSKU 
         ,@nCQTY = @nCQTY OUTPUT
         ,@nPQTY = @nPQTY OUTPUT
         ,@nTQTY = @nTQTY OUTPUT
         ,@cPosition = @cPosition OUTPUT

      -- Prepare next screen var
      SET @cOutField01 = @cUCC
      SET @cOutField02 = ''
      SET @cOutField03 = @cSKU
      SET @cOutField04 = CAST( @nCQTY AS NVARCHAR(5))
      SET @cOutField05 = CAST( @nPQTY AS NVARCHAR(5))
      SET @cOutField06 = CAST( @nTQTY AS NVARCHAR(5))

   END

   IF @nInputKey = 0 -- ESC 
   BEGIN      
   	SET @cOutField01 =''
   	SET @cOutField02 =''
   	SET @cOutField03 =''
   	SET @cOutField04 =''
   	SET @cOutField05 =''
   	SET @cOutField06 =''
   	
   	SET @nErrNo = 0
      -- Confirm
      EXEC rdt.rdt_UCCReceiveAudit_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey
         ,@cReceiptKey
         ,@nMixSKU
         ,@cUCC
         ,@cSKU
         ,1 -- @nQTY
         ,'Variance'
         ,@nErrNo    OUTPUT
         ,@cErrMsg   OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   	   	
   	SET @nCQTY = 0	
   	EXECUTE rdt.rdt_UCCReceiveAudit_GetStat @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey
         ,@cReceiptKey
         ,@cUCC
         ,@cSKU 
         ,@nCQTY = @nCQTY OUTPUT
         ,@nPQTY = @nPQTY OUTPUT
         ,@nTQTY = @nTQTY OUTPUT
         ,@nVariance = @nVariance OUTPUT
         
      IF @nVariance >0
      BEGIN
      	EXECUTE rdt.rdt_UCCReceiveAudit_GetVariance @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey
         ,@cReceiptKey
         ,@cUCC
         ,@cOutField01 = @cOutField01 OUTPUT       ,@cOutField07 = @cOutField07 OUTPUT
         ,@cOutField02 = @cOutField02 OUTPUT       ,@cOutField08 = @cOutField08 OUTPUT
         ,@cOutField03 = @cOutField03 OUTPUT       ,@cOutField09 = @cOutField09 OUTPUT
         ,@cOutField04 = @cOutField04 OUTPUT       ,@cOutField10 = @cOutField10 OUTPUT
         ,@cOutField05 = @cOutField05 OUTPUT       ,@cOutField11 = @cOutField11 OUTPUT
         ,@cOutField06 = @cOutField06 OUTPUT       ,@cOutField12 = @cOutField12 OUTPUT
         
         -- to variance screen
         SET @nScn = @nScn + 2  
         SET @nStep = @nStep + 2
      END
   	ELSE
   	BEGIN
   		--No Variance screen esc to UCC screen
         SET @cOutField01 = @cReceiptKey 
         SET @cOutField02 = @nDeviceCount + ':' + @nSKUCount  
         SET @cOutField03 = '' 
           
         SET @nScn = @nScn - 2  
         SET @nStep = @nStep - 2
   	END
   END
   GOTO Quit                         
                                     

END
GOTO Quit

/********************************************************************************
Step 5. Scn = 5654. (Mixed SKU)
   UCC            (field01)
   SKU            (field02, input)
   SKU            (field03)
   SCAN QTY       (field04)
   CTN QTY        (field05)
   CTN TOTAL QTY  (field06)
   POSITION       (field07)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField02 -- SKU
      
      -- Check SKU blank
      IF @cSKU = ''
      BEGIN
         SET @nErrNo = 147061
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- SKU required
         GOTO Quit
      END

      -- Check SKU valid
      EXEC dbo.nspg_GETSKU @cStorerKey, @cSKU OUTPUT, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
      IF @bSuccess = 0
      BEGIN
         SET @nErrNo = 147062
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid SKU
         GOTO Quit
      END

      -- Check SKU in ASN
      IF NOT EXISTS( SELECT TOP 1 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND SKU = @cSKU AND userDefine01 = @cUCC )
      BEGIN
         SET @nErrNo = 147063
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- SKU NotExist
         --GOTO Quit
      END
      
      -- Confirm
      SET @nErrNo = 0
      EXEC rdt.rdt_UCCReceiveAudit_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey
         ,@cReceiptKey
         ,@nMixSKU
         ,@cUCC
         ,@cSKU
         ,1 -- @nQTY
         ,''
         ,@nErrNo    OUTPUT
         ,@cErrMsg   OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Get statistic
      SET @nCQTY = 0
      EXECUTE rdt.rdt_UCCReceiveAudit_GetStat @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey
         ,@cReceiptKey
         ,@cUCC
         ,@cSKU 
         ,@nCQTY = @nCQTY OUTPUT
         ,@nPQTY = @nPQTY OUTPUT
         ,@nTQTY = @nTQTY OUTPUT
         ,@cPosition = @cPosition OUTPUT

      -- Prepare next screen var
      SET @cOutField01 = @cUCC
      SET @cOutField02 = ''
      SET @cOutField03 = @cSKU
      SET @cOutField04 = CAST( @nCQTY AS NVARCHAR(5))
      SET @cOutField05 = CAST( @nPQTY AS NVARCHAR(5))
      SET @cOutField06 = CAST( @nTQTY AS NVARCHAR(5))
      SET @cOutField07 = @cPosition

   END

   IF @nInputKey = 0 -- ESC 
   BEGIN      
   	SET @cOutField01 =''
   	SET @cOutField02 =''
   	SET @cOutField03 =''
   	SET @cOutField04 =''
   	SET @cOutField05 =''
   	SET @cOutField06 =''
   	SET @cOutField07 =''
   	
   	SET @nErrNo = 0
      -- Confirm
      EXEC rdt.rdt_UCCReceiveAudit_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey
         ,@cReceiptKey
         ,@nMixSKU
         ,@cUCC
         ,@cSKU
         ,1 -- @nQTY
         ,'Variance'
         ,@nErrNo    OUTPUT
         ,@cErrMsg   OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
         
   	SET @nCQTY = 0	
   	EXECUTE rdt.rdt_UCCReceiveAudit_GetStat @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey
         ,@cReceiptKey
         ,@cUCC
         ,@cSKU 
         ,@nCQTY = @nCQTY OUTPUT
         ,@nPQTY = @nPQTY OUTPUT
         ,@nTQTY = @nTQTY OUTPUT
         ,@nVariance = @nVariance OUTPUT
         
      IF @nVariance >0
      BEGIN
      	EXECUTE rdt.rdt_UCCReceiveAudit_GetVariance @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey
         ,@cReceiptKey
         ,@cUCC
         ,@cOutField01 = @cOutField01 OUTPUT       ,@cOutField07 = @cOutField07 OUTPUT
         ,@cOutField02 = @cOutField02 OUTPUT       ,@cOutField08 = @cOutField08 OUTPUT
         ,@cOutField03 = @cOutField03 OUTPUT       ,@cOutField09 = @cOutField09 OUTPUT
         ,@cOutField04 = @cOutField04 OUTPUT       ,@cOutField10 = @cOutField10 OUTPUT
         ,@cOutField05 = @cOutField05 OUTPUT       ,@cOutField11 = @cOutField11 OUTPUT
         ,@cOutField06 = @cOutField06 OUTPUT       ,@cOutField12 = @cOutField12 OUTPUT
         
         -- to variance screen
         SET @nScn = @nScn + 1  
         SET @nStep = @nStep + 1
      END
   	ELSE
   	BEGIN
   		--No Variance screen esc to UCC screen
         SET @cOutField01 = @cReceiptKey 
         SET @cOutField02 = @nDeviceCount + ':' + @nSKUCount  
         SET @cOutField03 = ''
           
         SET @nScn = @nScn - 3  
         SET @nStep = @nStep - 3
   	END
   END
   GOTO Quit                         
                                     

END
GOTO Quit

/********************************************************************************
Step 6. Scn = 5655. (Variance)
   SKU            (field01-field13)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      --to ADJ screen     
      SET @cOutField01 = '' 
           
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC 
   BEGIN      
   	-- Get statistic
      SET @nCQTY = 0
      EXECUTE rdt.rdt_UCCReceiveAudit_GetStat @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey
         ,@cReceiptKey
         ,@cUCC
         ,@cSKU 
         ,@nCQTY = @nCQTY OUTPUT
         ,@nPQTY = @nPQTY OUTPUT
         ,@nTQTY = @nTQTY OUTPUT
         ,@cPosition = @cPosition OUTPUT
      
   	--Mix SKU
      IF @nMixSKU >1
      BEGIN
      	SET @cOutField01 = @cUCC
         SET @cOutField02 = ''
         SET @cOutField03 = @cSKU
         SET @cOutField04 = CAST( @nCQTY AS NVARCHAR(5))
         SET @cOutField05 = CAST( @nPQTY AS NVARCHAR(5))
         SET @cOutField06 = CAST( @nTQTY AS NVARCHAR(5))
         SET @cOutField07 = @cPosition

         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE -- Single SKU
      BEGIN
      	
      	SET @cOutField01 = @cUCC
         SET @cOutField02 = ''
         SET @cOutField03 = @cSKU
         SET @cOutField04 = CAST( @nCQTY AS NVARCHAR(5))
         SET @cOutField05 = CAST( @nPQTY AS NVARCHAR(5))
         SET @cOutField06 = CAST( @nTQTY AS NVARCHAR(5))

         SET @nScn  = @nScn - 2
         SET @nStep = @nStep - 2
      END 
   END
   GOTO Quit                                                    
END
GOTO Quit

/********************************************************************************
Step 7. Scn = 5656. (Adj)
   Option     (field01, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
   	SET @cOption = @cInField01 -- Option

      -- Check option blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 147066
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- OptionRequired
         GOTO Quit
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 147067
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Option
         GOTO Quit
      END
      
      IF @cOption = '1'
      BEGIN
      	-- Adjustment
         EXEC rdt.rdt_UCCReceiveAudit_Adj @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey
            ,@cReceiptKey
            ,@cUCC
            ,@nErrNo    OUTPUT
            ,@cErrMsg   OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
         
      	--SET @cOutField01 = @cReceiptKey 
      	--SET @cOutField02 = @nDeviceCount + ':' + @nSKUCount  
       --  SET @cOutField03 = ''
           
      END
      
      --IF @cOption = '2'
      --BEGIN 
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @nDeviceCount + ':' + @nSKUCount  
         SET @cOutField03 = ''  
      --END
      
      --option 1/2 also back ucc screen
      SET @nScn = @nScn - 5  
      SET @nStep = @nStep - 5
      
   END

   IF @nInputKey = 0 -- ESC 
   BEGIN      
      SET @cOutField01 = @cUCC
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''

      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
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
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      UserName  = @cUserName,

      V_ReceiptKey = @cReceiptKey,
      V_UCC        = @cUCC,
      V_SKU        = @cSKU,
      
      V_Integer1  = @nMixSKU,
      V_Integer2  = @nVariance,
      V_Integer3  = @nDeviceCount,
      V_Integer4  = @nSKUCount,
      
      V_String1   = @cOption,
      V_String2   = @cAllowASNNotFinalize,

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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15
   WHERE Mobile = @nMobile
END


GO