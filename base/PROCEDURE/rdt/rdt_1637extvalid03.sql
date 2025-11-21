SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1637ExtValid03                                  */  
/* Purpose: Validate pallet id before scanned to truck                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2018-06-20 1.0  James      WMS5460 Created                           */  
/* 2018-09-25 1.1  James      Add check unique id within mbol (james01) */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1637ExtValid03] (  
   @nMobile                   INT,           
   @nFunc                     INT,           
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT,           
   @nInputKey                 INT,           
   @cStorerkey                NVARCHAR( 15), 
   @cContainerKey             NVARCHAR( 10), 
   @cContainerNo              NVARCHAR( 20), 
   @cMBOLKey                  NVARCHAR( 10), 
   @cSSCCNo                   NVARCHAR( 20), 
   @cPalletKey                NVARCHAR( 18), 
   @cTrackNo                  NVARCHAR( 20), 
   @cOption                   NVARCHAR( 1), 
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT   
)  
AS  
   DECLARE @cOrderKey      NVARCHAR( 10),
           @cLOC           NVARCHAR( 10),
           @cFacility      NVARCHAR( 5),
           @cInField02     NVARCHAR( 60),
           @cSeal02        NVARCHAR( 30),
           @cSeal03        NVARCHAR( 30), 
           @cPalletLoc     NVARCHAR( 10), 
           @cScanCnt       NVARCHAR( 5),
           @nScanCnt       INT,
           @nSeal02        INT,
           @nMBOLCnt       INT,
           @cQty           NVARCHAR( 5),
           @cMbolNotFromOtherReference   NVARCHAR( 1) -- (james01)

   DECLARE @cErrMsg1       NVARCHAR( 20), 
           @cErrMsg2       NVARCHAR( 20),
           @cErrMsg3       NVARCHAR( 20), 
           @cErrMsg4       NVARCHAR( 20),
           @cErrMsg5       NVARCHAR( 20)

   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  

   SELECT @cFacility = Facility,
          @cInField02 = I_Field02,
          @cMbolNotFromOtherReference = V_String9  -- (james01)
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 1  -- (james02)
      BEGIN
         SELECT @cSeal02 = Seal02,
                @cContainerNo = ExternContainerKey
         FROM dbo.Container WITH (NOLOCK)
         WHERE ContainerKey = @cContainerKey

         -- If container no not key in or is blank in container table, prompt error
         IF ISNULL( @cInField02, '') = '' OR ISNULL( @cContainerNo, '') = ''
         BEGIN
            SET @nErrNo = 125451  -- Container# req
            GOTO Fail         
         END

         IF rdt.rdtIsValidQty( @cSeal02, 1) = 0
         BEGIN
            SET @nErrNo = 125452  -- Inv # pallet
            GOTO Fail         
         END
      END

      IF @nStep = 3
      BEGIN
         SELECT @nMBOLCnt = COUNT( DISTINCT OD.MBOLKEY)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.ID = @cPalletKey
         AND   PD.Status < '9'
         AND   LOC.Facility = @cFacility

         -- Check if pallet contain > 1 mbol
         IF @nMBOLCnt > 1
         BEGIN
            SET @nErrNo = 125453  -- ID in >1 mbol
            GOTO Fail         
         END

         -- Check if pallet belong to correct mbol
         SELECT TOP 1 @cOrderKey = OrderKey,
                      @cLOC = PD.LOC
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
         WHERE StorerKey = @cStorerKey
         AND   ID = @cPalletKey
         AND   PD.Status < '9'
         AND   LOC.Facility = @cFacility

         -- Validate pallet id 
         IF NOT EXISTS ( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK)
                         WHERE MBOLKey = @cMBOLKey
                         AND   OrderKey = @cOrderKey)
         BEGIN
            SET @nErrNo = 125454  -- ID not in mbol
            GOTO Fail         
         END

         SELECT @cSeal02 = Seal02, 
                @cSeal03 = Seal03 
         FROM dbo.CONTAINER WITH (NOLOCK)
         WHERE ContainerKey = @cContainerKey

         SELECT @cScanCnt = COUNT(DISTINCT PalletKey) 
         FROM dbo.CONTAINERDETAIL WITH (NOLOCK)
         WHERE ContainerKey = @cContainerKey

         IF rdt.rdtIsValidQty( @cSeal02, 1) = 0
            SET @nSeal02 = 0
         ELSE
            SET @nSeal02 = CAST( @cSeal02 AS INT)

         IF rdt.rdtIsValidQty( @cScanCnt, 1) = 0
            SET @nScanCnt = 0
         ELSE
            SET @nScanCnt = CAST( @cScanCnt AS INT)

         -- Check over scanned. + 1 pallet here 
         -- as it is still not inserted into containerdetail
         IF @nSeal02 < (@nScanCnt + 1)
         BEGIN
            SET @nErrNo = 125455  -- Over scanned
            GOTO Fail         
         END

         SET @cPalletLoc = ''
         SELECT TOP 1 @cPalletLoc = LLI.LOC 
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey 
         AND   LLI.ID = @cPalletKey 
         AND   LOC.Facility = @cFacility
         AND   LOC.LocationCategory = 'STAGING'
         AND   Qty > 0

         IF ISNULL( @cPalletLoc, '') <> ISNULL( @cSeal03, '')
         BEGIN
            SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 125456, @cLangCode, 'DSP'), 7, 14) --Stage loc
            SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 125457, @cLangCode, 'DSP'), 7, 14) --Not match
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END         

            SET @nErrNo = 125456
            GOTO Fail         
         END

         -- (james01)
         -- Check palletkey must be unique within mbol. 1 mbol can contain multiple containerkey
         -- 1 palletkey is unique within containerkey by default. So it may happen palletkey appear
         -- in 2 containerkey but that 2 containerkey will ship together within 1 mbol. 
         -- We need prompt error if detect above condition happen
         IF EXISTS ( SELECT 1 FROM dbo.CONTAINER C WITH (NOLOCK)
                     JOIN dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON ( C.ContainerKey = CD.ContainerKey)
                     WHERE 1 = CASE WHEN @cMbolNotFromOtherReference = '1' AND C.MBOLKey = @cMBOLKey THEN 1
                                    WHEN @cMbolNotFromOtherReference <> '1' AND ISNULL(RTRIM(C.OtherReference), '') = @cMbolKey THEN 1
                              ELSE 0 END
                     AND   CD.PalletKey = @cPalletKey
                     GROUP BY C.MBOLKey
                     HAVING COUNT( CD.PalletKey) > 0)
         BEGIN
            SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 125462, @cLangCode, 'DSP'), 7, 14) --Duplicate Plt
            SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 125463, @cLangCode, 'DSP'), 7, 14) --ID Per Mbol
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END         

            SET @nErrNo = 125462
            GOTO Fail      
         END
      END

      IF @nStep = 6  -- (james02)
      BEGIN
         SELECT @cSeal02 = Seal02
         FROM dbo.CONTAINER WITH (NOLOCK)
         WHERE ContainerKey = @cContainerKey

         SELECT @cScanCnt = COUNT(DISTINCT PalletKey) 
         FROM dbo.CONTAINERDETAIL WITH (NOLOCK)
         WHERE ContainerKey = @cContainerKey

         IF rdt.rdtIsValidQty( @cSeal02, 1) = 0
            SET @nSeal02 = 0
         ELSE
            SET @nSeal02 = CAST( @cSeal02 AS INT)

         IF rdt.rdtIsValidQty( @cScanCnt, 1) = 0
            SET @nScanCnt = 0
         ELSE
            SET @nScanCnt = CAST( @cScanCnt AS INT)

         IF @nSeal02 > @nScanCnt
         BEGIN
            SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 125458, @cLangCode, 'DSP'), 7, 14) --Not all pallet
            SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 125459, @cLangCode, 'DSP'), 7, 14) --Scanned
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END         

            SET @nErrNo = 125458
            GOTO Fail         
         END
      END

      IF @nStep = 7  -- (james04)
      BEGIN
         SELECT @cQty = I_Field02
         FROM RDT.RDTMOBREC WITH (NOLOCK)
         WHERE Mobile = @nMobile

         IF ISNULL( @cQty, '') = ''
         BEGIN
            SET @nErrNo = 125460  -- Invalid qty
            GOTO Fail         
         END

         -- Validate qty key in. 0 allow
         IF rdt.rdtIsValidQTY( @cQty, 1) = 0
         BEGIN
            SET @nErrNo = 125461  -- Invalid qty
            GOTO Fail         
         END
      END
   END  
  
Fail:  

GO