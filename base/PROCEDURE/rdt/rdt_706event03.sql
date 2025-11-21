SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/****************************************************************************/
/* Store procedure: rdt_706Event03                                          */
/*                                                                          */
/* Modifications log:                                                       */
/*                                                                          */
/* Date       Rev  Author    Purposes                                       */
/* 2020-09-02 1.0  YeeKung   WMS-14829 Created                              */
/* 2021-02-21 1.1  kelvinong performance tuning consume high resource       */
/*                           with add StorerKey                             */
/* 2020-03-26 1.2  Chermaine WMS-16587 Change tracking logic (cc01)         */
/* 2021-04-18 1.3  YeeKung   WMS-16782 Add Extendedinfo (yeekung01)         */
/* 2021-05-27 1.4  Chermaine WMS-17102 Add codelkup checking (cc02)         */
/* 2021-09-01 1.5  YeeKung   WMS-17799 Add new feature (yeekung01)          */
/* 2022-01-06 1.6  YeeKung   WMS-21479 Add new feature (yeekung03)          */
/****************************************************************************/

CREATE   PROC [RDT].[rdt_706Event03] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cOption       NVARCHAR( 1),
   @cRetainValue  NVARCHAR( 10),
   @cTotalCaptr   INT           OUTPUT,
   @nStep         INT           OUTPUT,
   @nScn          INT           OUTPUT,
   @cLabel1       NVARCHAR( 20) OUTPUT,
   @cLabel2       NVARCHAR( 20) OUTPUT,
   @cLabel3       NVARCHAR( 20) OUTPUT,
   @cLabel4       NVARCHAR( 20) OUTPUT,
   @cLabel5       NVARCHAR( 20) OUTPUT,
   @cValue1       NVARCHAR( 60) OUTPUT,
   @cValue2       NVARCHAR( 60) OUTPUT,
   @cValue3       NVARCHAR( 60) OUTPUT,
   @cValue4       NVARCHAR( 60) OUTPUT,
   @cValue5       NVARCHAR( 60) OUTPUT,
   @cFieldAttr02  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr04  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr06  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr08  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr10  NVARCHAR( 1)  OUTPUT,
   @cExtendedinfo NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @cTrackingNo    NVARCHAR( 20)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cReceiptKey    NVARCHAR( 20)
   DECLARE @cErrMsg1       NVARCHAR( 20),
           @cErrMsg2       NVARCHAR( 20),
           @cErrMsg3       NVARCHAR( 20),
           @cErrMsg4       NVARCHAR( 20),
           @cErrMsg5       NVARCHAR( 20),
           @cErrMsg6       NVARCHAR( 20),
           @cErrMsg7       NVARCHAR( 20),
           @cErrMsg8       NVARCHAR( 20)
   DECLARE @nDay           INT
   DECLARE @nReceiptdate   Datetime
   DECLARE @cSKUBarcode    NVARCHAR(20)
   DECLARE @cOutfield02    NVARCHAR(20)

   --(cc01)
   DECLARE @cReceiptType   NVARCHAR(1),
           @cLottable08    NVARCHAR(30),
           @cLottable09    NVARCHAR(30),
           @cLottable10    NVARCHAR(30),
           @cUserdefine02  NVARCHAR(30),
           @cUserdefine03  NVARCHAR(30),  --(cc02)
           @cExtField01    NVARCHAR(30),
           @cExtField02    NVARCHAR(30),
           @cExtField03    NVARCHAR(30),
           @cExtField07    NVARCHAR(30),
           @cExtField08    NVARCHAR(30),
           @nAsnCount      INT

   -- Parameter mapping
   SET @cTrackingNo = @cValue1
   SET @cSKU = @cValue2
   SET @cReceiptType = '0'

   SELECT @cOutfield02=O_Field02
   from rdt.rdtmobrec (nolock)
   where mobile=@nMobile

   IF  @nStep =2
   BEGIN
      IF @nInputKey='1'
      BEGIN
         -- Check TrackingID blank
         IF @cTrackingNo = ''
         BEGIN
            SET @nErrNo = 159101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackingNoNeed
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- PalletID
            GOTO Quit
         END
         
         -- Check barcode format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'TRACKINGNO', @cTrackingNo) = 0
         BEGIN
            SET @nErrNo = 159109
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 2-- trackingno
            GOTO Quit
         END

         SELECT
            @nAsnCount  = COUNT(DISTINCT Key1)
         FROM RECEIPT R WITH (NOLOCK)
         JOIN DocInfo DI WITH (NOLOCK) ON DI.Key1 = R.ReceiptKey AND DI.StorerKey = R.StorerKey
         WHERE R.StorerKey = @cStorerKey
         AND DI.Key3 = @cTrackingNo
         AND R.ASNStatus <> 'CANC'
         AND tablename = 'Receipt'

         --(cc01)
         IF @nAsnCount >1
         BEGIN
            SET @cReceiptType = '2' -- Multi ASN

            SELECT TOP 1
               @cReceiptKey  = R.ReceiptKey
            FROM RECEIPT R WITH (NOLOCK)
            JOIN DocInfo DI WITH (NOLOCK) ON DI.Key1 = R.ReceiptKey AND DI.StorerKey = R.StorerKey
            WHERE R.StorerKey = @cStorerKey
            AND DI.Key3 = @cTrackingNo
            AND R.ASNStatus <> 'CANC'
            AND tablename = 'Receipt'
         END
         ELSE IF @nAsnCount = 1
         BEGIN
            SET @cReceiptType = '1' -- Single ASN

            SELECT
               @cReceiptKey  = R.ReceiptKey
            FROM RECEIPT R WITH (NOLOCK)
            JOIN DocInfo DI WITH (NOLOCK) ON DI.Key1 = R.ReceiptKey AND DI.StorerKey = R.StorerKey
            WHERE R.StorerKey = @cStorerKey
               AND DI.Key3 = @cTrackingNo
               AND R.ASNStatus <> 'CANC'
               AND tablename = 'Receipt'
         END
         ELSE
         BEGIN
            SET @cReceiptType = '0' -- Cancel ASN

            SELECT
               @cReceiptKey  = R.ReceiptKey
            FROM RECEIPT R WITH (NOLOCK)
            JOIN DocInfo DI WITH (NOLOCK) ON DI.Key1 = R.ReceiptKey AND DI.StorerKey = R.StorerKey
            WHERE R.StorerKey = @cStorerKey
               AND DI.Key3 = @cTrackingNo
               AND tablename = 'Receipt'
         END

         IF ISNULL(@cReceiptKey,'')='' and ISNULL(@cOutfield02,'')=''
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- PalletID
            GOTO Quit
         END
         ELSE IF ISNULL(@cSKU,'')='' and ISNULL(@cOutfield02,'')=''
         BEGIN
            SELECT
               @cLottable08 = lottable08,
               @cLottable09 = lottable09,
               @cLottable10 = lottable10
            FROM RECEIPTDETAIL WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND ReceiptKey = @cReceiptKey

            SELECT
             @nDay= UDF01
            FROM codelkup (nolock)
            WHERE listname='rdata'
            AND storerkey=@cstorerkey

            SELECT
               @nReceiptdate=userdefine06,
               @cUserdefine02 = UserDefine02,
               @cUserdefine03 = UserDefine03
            FROM receipt (NOLOCK)
            WHERE receiptkey=@cReceiptKey
            ORDER BY userdefine06

            --(cc01)
            IF @cReceiptType = '1' --single ASN
            BEGIN
               IF @cUserdefine02 = 'Y'
               BEGIN
                  SET @nErrNo = 159111
                  SET @cErrMsg1= rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Green Order
               END

               IF (GETDATE() - @nReceiptdate > @nDay)
               BEGIN
                  SET @nErrNo = 159112
                  SET @cErrMsg2 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Overdue
               END

               IF EXISTS (SELECT 1 FROM Receipt WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ReceiptKey = @cReceiptKey AND ASNStatus <> 'CANC' AND OpenQty = '1')
               BEGIN
               SELECT
                  @cExtField01 = ExtendedField01,
                  @cExtField02 = ExtendedField02,
                  @cExtField03 = ExtendedField03,
                  @cExtField07 = ExtendedField07,
                  @cExtField08 = ExtendedField08,
                  @cSKUBarcode = RD.SKU
               FROM SkuInfo SI WITH (NOLOCK)
               JOIN ReceiptDetail RD WITH (NOLOCK) ON (SI.Sku = RD.SKU AND SI.Storerkey = RD.StorerKey)
               WHERE RD.StorerKey = @cStorerKey
               AND rd.receiptkey = @cReceiptKey

               IF @cExtField01 = 'BP1'
               BEGIN
                  SET @nErrNo = 159113
                  SET @cErrMsg3= rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BP1 SKU
               END

               IF @cExtField02 = 'BP2'
               BEGIN
                  SET @nErrNo = 159114
                  SET @cErrMsg4= rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BP2 SKU
               END

               IF @cExtField03 = 'RFID'
               BEGIN
                  SET @nErrNo = 159115
                  SET @cErrMsg5= rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RFID SKU
               END

               IF @cExtField03 = 'NFC'
               BEGIN
                  SET @nErrNo = 159124
                  SET @cErrMsg5= rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NFC
               END

               IF NOT EXISTS (SELECT 1 FROM skuinfo (NOLOCK) where sku=@cSKUBarcode and StorerKey = @cStorerKey) OR
                              (ISNULL(@cExtField01,'') = '' AND ISNULL(@cExtField02,'') = '' AND ISNULL(@cExtField03,'') = ''
                              AND ISNULL(@cExtField07,'')='' AND ISNULL(@cExtField08,'')='')
               BEGIN
                  SET @nErrNo = 159116
                  SET @cErrMsg3= rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --N
               END

               --(cc02)
               IF EXISTS (SELECT 1 FROM codelkup WITH (NOLOCK) WHERE storerKey = @cStorerKey AND listName = 'NIKESoldto' AND long = 'Outlet' AND notes =@cuserdefine03 )
               BEGIN
                  SET @nErrNo = 159121
                  SET @cErrMsg6= rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Outlet Order
               END
            END

            IF EXISTS (SELECT 1 FROM Receipt WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ReceiptKey = @cReceiptKey AND ASNStatus <> 'CANC' AND OpenQty > '1')
            BEGIN
               SET @nErrNo = 159117
               SET @cErrMsg3= rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multiple ASN

               --(cc02)
               IF EXISTS (SELECT 1 FROM codelkup WITH (NOLOCK) WHERE storerKey = @cStorerKey AND listName = 'NIKESoldto' AND long = 'Outlet' AND notes =@cuserdefine03 )
               BEGIN
                  SET @nErrNo = 159121
                  SET @cErrMsg6= rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Outlet Order
               END
            END

            IF EXISTS (SELECT  1 FROM skuinfo (NOLOCK) where sku=@cSKUBarcode and StorerKey = @cStorerKey AND ExtendedField07='KEY')  --yeekung02
            BEGIN
               SET @nErrNo = 159122
               SET @cErrMsg7 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BP3 SKU
            END


            IF EXISTS (SELECT  1 FROM skuinfo (NOLOCK) where sku=@cSKUBarcode and StorerKey = @cStorerKey AND ExtendedField08='BOX')  --yeekung02
            BEGIN
               SET @nErrNo = 159123
               SET @cErrMsg8 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BP3 SKU
            END


            IF (isnull(@cErrMsg1,'')<>'' OR isnull(@cErrMsg2,'')<>'' OR isnull(@cErrMsg3,'')<>'' OR isnull(@cErrMsg4,'')<>'' OR isnull(@cErrMsg5,'')<>'' OR isnull(@cErrMsg6,'')<>''
               OR isnull(@cErrMsg7,'')<>''OR isnull(@cErrMsg8,'')<>'')
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5, @cErrMsg6,@cErrMsg7,@cErrMsg8
            END

            EXEC rdt.rdtSetFocusField @nMobile, 2 -- trackingNo
            SET @cValue1 = ''
            GOTO QUIT
         END

            IF @cReceiptType = '2' --multi ASN
            BEGIN
               IF EXISTS (SELECT 1 FROM Receipt WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ReceiptKey = @cReceiptKey AND ASNStatus <> 'CANC')
               BEGIN
                  SET @nErrNo = 159118
                  SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multiple ASN
               END

               IF (SELECT COUNT(DISTINCT R.UserDefine02) FROM RECEIPT R WITH (NOLOCK)
                        JOIN DocInfo DI WITH (NOLOCK) ON (DI.Key1 = R.ReceiptKey AND DI.StorerKey = R.StorerKey)
                     WHERE R.StorerKey = @cStorerKey
                     AND DI.Key3 = @cTrackingNo
                     AND R.ASNStatus <> 'CANC') = 1
               BEGIN
                  IF EXISTS (SELECT 1 FROM RECEIPT R WITH (NOLOCK)
                        JOIN DocInfo DI WITH (NOLOCK) ON (DI.Key1 = R.ReceiptKey AND DI.StorerKey = R.StorerKey)
                     WHERE R.StorerKey = @cStorerKey
                     AND DI.Key3 = @cTrackingNo
                     AND R.UserDefine02 = 'Y'
                     AND R.ASNStatus <> 'CANC')
                  BEGIN
                     SET @nErrNo = 159119
                     SET @cErrMsg2= rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Green Order
                  END
               END

               SELECT TOP 1
                  @nReceiptdate=userdefine06
               FROM RECEIPT R WITH (NOLOCK)
               JOIN DocInfo DI WITH (NOLOCK) ON (DI.Key1 = R.ReceiptKey AND DI.StorerKey = R.StorerKey)
               WHERE R.StorerKey = @cStorerKey
                  AND DI.Key3 = @cTrackingNo
                  AND R.ASNStatus <> 'CANC'
                  AND DI.TableName =  'Receipt'
               ORDER BY R.userdefine06

               IF DATEDIFF(DAY,@nReceiptdate,GETDATE()) > @nDay  --(GETDATE() - @nReceiptdate > @nDay)
               BEGIN
                  SET @nErrNo = 159120
                  SET @cErrMsg3 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Overdue
               END

               --(cc02)
               IF EXISTS (SELECT 1
                           FROM codelkup C WITH (NOLOCK)
                           JOIN Receipt R WITH (NOLOCK) ON (R.userdefine03 = C.Notes AND R.StorerKey = C.Storerkey)
                           JOIN DocInfo DI WITH (NOLOCK) ON (R.ReceiptKey = DI.Key1)
                           WHERE R.storerKey = @cStorerKey
                           AND C.listName = 'NIKESoldto'
                           AND C.long = 'Outlet'
                           AND DI.key3 = @cTrackingNo
                           AND R.ASNStatus <> 'CANC')
               BEGIN
                  SET @nErrNo = 159121
                  SET @cErrMsg5= rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Outlet Order
               END

               IF (isnull(@cErrMsg1,'')<>'' OR isnull(@cErrMsg2,'')<>'' OR isnull(@cErrMsg3,'')<>'' OR isnull(@cErrMsg4,'')<>'' OR isnull(@cErrMsg5,'')<>'')
               BEGIN
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                  @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
               END

               EXEC rdt.rdtSetFocusField @nMobile, 2 -- trackingNo
               SET @cValue1 = ''
               GOTO QUIT
            END

            ---- Insert event
            --EXEC RDT.rdt_STD_EventLog
            --   @cActionType   = '14',
            --   @nMobileNo     = @nMobile,
            --   @nFunctionID   = @nFunc,
            --   @cFacility     = @cFacility,
            --   @cStorerKey    = @cStorerKey,
            --   @cTrackingNo   = @cTrackingNo
      END

         IF ISNULL(@cSKU,'')=''
         BEGIN
            SET @nErrNo = 159110
            SET @cErrMSg= rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BP1 SKU
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- ID
            SET @cValue2=''
            GOTO QUIT
         END

         SET @cErrMsg1=''
         SET @cErrMsg2=''
         SET @cErrMsg3=''

         SELECT -- TOP 1
            @cSKUBarcode = A.SKU
         FROM
         (
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
            UNION ALL
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
         ) A

         IF ISNULL(@cSKUBarcode,'')=''
         BEGIN
            SET @nErrNo = 159108
            SET @cErrMSg= rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- ID
            SET @cValue2=''
            GOTO QUIT
         END


         IF EXISTS (SELECT  1 FROM skuinfo (NOLOCK) where sku=@cSKUBarcode and StorerKey = @cStorerKey and ExtendedField01='BP1')  --kelvinong
         BEGIN
            SET @nErrNo = 159105
            SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BP1 SKU
         END

         IF EXISTS (SELECT  1 FROM skuinfo (NOLOCK) where sku=@cSKUBarcode and StorerKey = @cStorerKey and ExtendedField02='BP2')  --kelvinong
         BEGIN
            SET @nErrNo = 159106
            SET @cErrMsg2 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BP2 SKU
         END

         IF EXISTS (SELECT  1 FROM skuinfo (NOLOCK) where sku=@cSKUBarcode and StorerKey = @cStorerKey and ExtendedField03='RFID')  --kelvinong
         BEGIN
            SET @nErrNo = 159107
            SET @cErrMsg3 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BP3 SKU
         END

         IF EXISTS (SELECT  1 FROM skuinfo (NOLOCK) where sku=@cSKUBarcode and StorerKey = @cStorerKey and ExtendedField03='NFC')  --kelvinong
         BEGIN
            SET @nErrNo = 159125
            SET @cErrMsg3 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RFID SKU
         END


         IF EXISTS (SELECT  1 FROM skuinfo (NOLOCK) where sku=@cSKUBarcode and StorerKey = @cStorerKey AND ExtendedField07='KEY')  --yeekung02
         BEGIN
            SET @nErrNo = 159122
            SET @cErrMsg7 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BP3 SKU
         END

         IF EXISTS (SELECT  1 FROM skuinfo (NOLOCK) where sku=@cSKUBarcode and StorerKey = @cStorerKey AND ExtendedField08='BOX')  --yeekung02
         BEGIN
            SET @nErrNo = 159125
            SET @cErrMsg8 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BP3 SKU
         END

         IF (ISNULL(@cErrMsg1,'')<>'' OR ISNULL(@cErrMsg2,'')<>'' OR ISNULL(@cErrMsg3,'')<>''OR ISNULL(@cErrMsg7,'')<>''OR ISNULL(@cErrMsg8,'')<>'')
         BEGIN
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5,@cErrMsg7,@cErrMsg8

            EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID

            SET @cValue1=''
            SET @cValue2=''
         END
         ELSE
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID

            SET @cValue1=''
            SET @cValue2=''
         END

         ---- Insert event
         --EXEC RDT.rdt_STD_EventLog
         --   @cActionType   = '14',
         --   @nMobileNo     = @nMobile,
         --   @nFunctionID   = @nFunc,
         --   @cFacility     = @cFacility,
         --   @cStorerKey    = @cStorerKey,
         --   @cTrackingNo   = @cTrackingNo,
         --   @cSKU          = @cSKU

         SET @cTotalCaptr=@cTotalCaptr+1
      
END
   END
Quit:
   -- Insert event
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '14',
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cTrackingNo   = @cTrackingNo,
         @cSKU          = @cSKU
END

GO