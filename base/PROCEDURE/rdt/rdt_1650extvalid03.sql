SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1650ExtValid03                                  */
/* Purpose: If the pallet id was scanned, prompt error message          */
/*                                                                      */
/* Called from: rdtfnc_Scan_Pallet_To_Door                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-07-17 1.2  NLT013     FCR-574  Create                           */
/************************************************************************/

CREATE PROC rdt.rdt_1650ExtValid03 (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cPalletID        NVARCHAR( 18), 
   @cMbolKey         NVARCHAR( 10), 
   @cDoor            NVARCHAR( 20), 
   @cOption          NVARCHAR( 1), 
   @nAfterStep       INT, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE 
      @cPalletMBOLKey                     NVARCHAR(10),
      @nPalletCBOLKey                     INT,
      @nCBOLKey                           INT,
      @cFacility                          NVARCHAR(5),
      @nTotalPalletQty                    INT,
      @nScannedPalletQty                  INT,
      @nPrevCBOLKey                       INT,
      @cPrevMBOLKey                       NVARCHAR( 10)
   

   SELECT 
      @cFacility     = Facility,
      @nPrevCBOLKey  = C_Integer5,
      @cPrevMBOLKey  = C_String30
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nFunc = 1650
   BEGIN
      IF @nStep = 1
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ID = @cPalletID AND Notes = 'SCANNED' AND [Status] >= '5' AND [Status] < '9')
            BEGIN
               SET @nErrNo = 219351
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PalletScanned
               GOTO Quit
            END

            SELECT @nCBOLKey = ISNULL( CBOLKey, 0) FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey

            SELECT @cPalletMBOLKey = MD.MBOLKey, @nPalletCBOLKey = C.CBOLKey
            FROM dbo.MBOL M WITH (NOLOCK)
            INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
            LEFT JOIN dbo.CBOL C WITH (NOLOCK) ON C.Facility = M.Facility AND M.CBOLKey = C.CBOLKey
            WHERE M.Status <> '9'
               AND M.Facility = @cFacility
               AND M.MBOLKey = @cMBOLKey

            IF @nPrevCBOLKey IS NOT NULL AND @nPrevCBOLKey > 0
            BEGIN
               IF @nPalletCBOLKey IS NOT NULL AND @nPalletCBOLKey <> @nPrevCBOLKey
               BEGIN
                  SET @nErrNo = 219352
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DiffCBOLKey
                  GOTO Quit
               END
            END
            ELSE 
            BEGIN
               IF @cPrevMBOLKey IS NOT NULL AND TRIM(@cPrevMBOLKey) <> ''
               BEGIN
                  IF @cPalletMBOLKey IS NOT NULL AND TRIM(@cPalletMBOLKey) <> '' AND @cPalletMBOLKey <> @cPrevMBOLKey
                  BEGIN
                     SET @nErrNo = 219353
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DiffMBOLKey
                     GOTO Quit
                  END
               END
            END

            UPDATE RDT.RDTMOBREC WITH (ROWLOCK) 
            SET C_Integer5 = ISNULL(@nPalletCBOLKey, 0),
               C_String30 = ISNULL(@cPalletMBOLKey, '')
            WHERE Mobile = @nMobile
         END
      END
      ELSE IF @nStep = 2
      BEGIN
         IF @nInputKey = 0
         BEGIN
            SELECT @nCBOLKey = ISNULL( CBOLKey, 0) FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey

            IF @nCBOLKey IS NOT NULL AND @nCBOLKey > 0
            BEGIN
               SELECT @nTotalPalletQty = COUNT(DISTINCT PD.ID)
               FROM dbo.MBOL M WITH (NOLOCK)
               INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
               INNER JOIN dbo.CBOL C WITH (NOLOCK) ON M.Facility = C.Facility AND M.CBOLKey = C.CBOLKey
               WHERE M.Status <> '9'
                  AND M.Facility = @cFacility
                  AND M.CBOLKey = @nCBOLKey

               SELECT @nScannedPalletQty = COUNT(DISTINCT PD.ID)
               FROM dbo.MBOL M WITH (NOLOCK)
               INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
               INNER JOIN dbo.CBOL C WITH (NOLOCK) ON M.Facility = C.Facility AND M.CBOLKey = C.CBOLKey
               WHERE M.Status <> '9'
                  AND M.Facility = @cFacility
                  AND M.CBOLKey = @nCBOLKey
                  AND PD.Notes = 'SCANNED'
            END
            ELSE 
            BEGIN
               IF @cMBOLKey IS NOT NULL AND @cMBOLKey <> ''
               BEGIN
                  SELECT @nTotalPalletQty = COUNT(DISTINCT PD.ID)
                  FROM dbo.MBOL M WITH (NOLOCK)
                  INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                  WHERE M.Status <> '9'
                     AND M.Facility = @cFacility
                     AND M.MBOLKey = @cMBOLKey

                  SELECT @nScannedPalletQty = COUNT(DISTINCT PD.ID)
                  FROM dbo.MBOL M WITH (NOLOCK)
                  INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                  WHERE M.Status <> '9'
                     AND M.Facility = @cFacility
                     AND M.MBOLKey = @cMBOLKey
                     AND PD.Notes = 'SCANNED'
               END
            END

            IF @nTotalPalletQty = @nScannedPalletQty
            BEGIN
               SET @nErrNo = 219354
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoPalletLeft
               GOTO Quit
            END 
         END
      END
   END 

QUIT:
END

GO