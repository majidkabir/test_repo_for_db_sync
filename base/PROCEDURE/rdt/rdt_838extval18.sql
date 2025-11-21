SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_838ExtVal18                                     */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2023-11-14 1.0  yeekung     WMS-23946 Created                        */
/* 2024-01-09 1.1  Ung         WMS-24587 Add TO DROP ID reuse checking  */
/* 2024-03-15 1.2  Ung         WMS-24885 Add MQTY checking              */
/************************************************************************/

CREATE   PROC rdt.rdt_838ExtVal18 (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cFromDropID      NVARCHAR( 20),
   @nCartonNo        INT,
   @cLabelNo         NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cUCCNo           NVARCHAR( 20),
   @cCartonType      NVARCHAR( 10),
   @cCube            NVARCHAR( 10),
   @cWeight          NVARCHAR( 10),
   @cRefNo           NVARCHAR( 20),
   @cSerialNo        NVARCHAR( 30),
   @nSerialQTY       INT,
   @cOption          NVARCHAR( 1),
   @cPackDtlRefNo    NVARCHAR( 20),
   @cPackDtlRefNo2   NVARCHAR( 20),
   @cPackDtlUPC      NVARCHAR( 30),
   @cPackDtlDropID   NVARCHAR( 20),
   @cPackData1       NVARCHAR( 30),
   @cPackData2       NVARCHAR( 30),
   @cPackData3       NVARCHAR( 30),
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nSKUWeight Float
   DECLARE @nTTlSKUWeight Float = 0
   DECLARE @nMaxCtnWeight Float
   DECLARE @nCtnWeight Float
   DECLARE @cDefaultcartontype NVARCHAR(20)
   DECLARE @cPackSKU NVARCHAR(20)
   DECLARE @nPackQTY  INT
   DECLARE @cErrMsg1  NVARCHAR(20)

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 2 -- Option
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cPackDtlDropID <> '' AND  -- TO DROP ID
               @cOption = '1'             -- NEW carton
            BEGIN
               -- Check TO DROP ID had used 
               IF EXISTS( SELECT TOP 1 1 
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND DropID = @cPackDtlDropID)
               BEGIN
                  SET @nErrNo = 208803
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pack NewCarton
                  GOTO Quit
               END
            END
         END
      END
      
      IF @nStep = 3 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get session info
            DECLARE @cInField08 NVARCHAR( 60)
            SELECT @cInField08 = I_Field08 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
            
            IF @cInField08 <> ''
            BEGIN
               SET @nErrNo = 208804
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PIECE NotAllow
               GOTO Quit
            END

            SELECT @nSKUWeight = stdgrosswgt * @nQTY
            FROM SKU (NOLOCK) 
            WHERE SKU = @cSKU 
            AND Storerkey = @cStorerkey

            SET @cDefaultcartontype=rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerKey)  --(cc01)  
            IF @cDefaultcartontype = '0'    
               SET @cDefaultcartontype = ''   

            IF ISNULL(@cDefaultcartontype,'') <>''
            BEGIN
               SELECT   @nMaxCtnWeight = MaxWeight,
                        @nCtnWeight = CartonWeight
               FROM cartonization
               WHERE CartonType = @cDefaultcartontype

               DECLARE CurPDtl CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT SKU,QTY
               FROM Packdetail (NOLOCK)
               Where PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
                  AND Storerkey = @cStorerKey
               OPEN CurPDtl  
               FETCH NEXT FROM CurPDtl INTO @cPackSKU, @nPackQTY  
               WHILE @@FETCH_STATUS = 0  
               BEGIN  
                  SELECT @nTTlSKUWeight = @nTTlSKUWeight+ stdgrosswgt*@nPackQTY
                  FROM SKU (NOLOCK)
                  WHERE SKU = @cSKU
                     AND Storerkey = @cStorerKey

                  FETCH NEXT FROM CurPDtl INTO @cPackSKU, @nPackQTY
               END

               SET @nTTlSKUWeight = @nTTlSKUWeight + @nSKUWeight

               IF @nTTlSKUWeight > @nMaxCtnWeight
               BEGIN
                  SET @cErrMsg1 = 'Weight exceeds limit'
               END
               ELSE IF @nTTlSKUWeight = @nMaxCtnWeight
               BEGIN
                  SET @cErrMsg1 = 'Weight reached limit'
               END

               IF ISNULL(@cErrMsg1,'')<>''
               BEGIN
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,      
                     @cErrMsg1

                  SET @nErrNo = 0
               END
            END
         END
      END
   END

Quit:

END

GO