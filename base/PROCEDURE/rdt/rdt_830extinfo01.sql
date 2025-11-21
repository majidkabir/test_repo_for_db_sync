SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_830ExtInfo01                                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 21-09-2018  1.0  Ung         WMS-6410 Created                        */
/* 10-01-2019  1.1  James       WMS-7429 Change holiday definition      */
/*                              (james01)                               */
/* 27-12-2020  1.2  YeeKung     WMS-15995 Add PickZone (yeekung01)      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_830ExtInfo01]
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nAfterStep    INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPickSlipNo   NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10),
   @cSuggLOC      NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cDropID       NVARCHAR( 20),
   @cSKU          NVARCHAR( 20),
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,
   @nTaskQTY      INT,
   @nQTY          INT,
   @cToLOC        NVARCHAR( 10),
   @cOption       NVARCHAR( 1),
   @cExtendedInfo NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey NVARCHAR( 10)
   DECLARE @cConsigneeKey NVARCHAR( 15)
   DECLARE @cSUSR5 NVARCHAR( 20)

   IF @nFunc = 830 -- PickSKU
   BEGIN
      IF @nAfterStep = 2 -- LOC
      BEGIN
         SET @cExtendedInfo = ''

         -- Get PickSlip info
         SELECT @cOrderKey = OrderKey FROM PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo
         
         -- Get order info
         DECLARE @dDeliveryDate DATETIME
         DECLARE @cCompany NVARCHAR( 45)
         SELECT 
            @cConsigneeKey = ConsigneeKey, 
            @dDeliveryDate = DeliveryDate, 
            @cCompany = C_Company
         FROM Orders O WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey

         -- Get consignee info
         SELECT @cSUSR5 = SUSR5 FROM Storer WITH (NOLOCK) WHERE StorerKey = @cConsigneeKey
         
         IF @cSUSR5 = '@@'
         BEGIN
            -- Order contain consignee SKU
            IF EXISTS( SELECT TOP 1 1 
               FROM Orders O WITH (NOLOCK)
                  JOIN OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
                  JOIN ConsigneeSKU CS WITH (NOLOCK) ON (OD.StorerKey = CS.StorerKey AND OD.SKU = CS.SKU AND CS.ConsigneeKey = O.ConsigneeKey)
               WHERE O.OrderKey = @cOrderKey)
            BEGIN
               -- Get holiday info
               DECLARE @cHolidayKey NVARCHAR( 10)
               SELECT @cHolidayKey = ISNULL( HolidayKey, '')
               FROM StorerSODefault WITH (NOLOCK)
               WHERE StorerKey = @cConsigneeKey
               
               IF @cHolidayKey <> ''
               BEGIN
                  DECLARE @dToday DATETIME
                  SET @dToday = DATEADD( DD, DATEDIFF( DD, 0, GETDATE()), 0) -- Strip off time portion
                  
                  -- Get holiday in between today and delivery date
                  DECLARE @nHoliday INT
                  SELECT @nHoliday = COUNT(1)
                  FROM HolidayHeader HH WITH (NOLOCK)
                     JOIN HolidayDetail HD WITH (NOLOCK) ON (HH.HolidayKey = HD.HolidayKey)
                  WHERE HD.HolidayKey = @cHolidayKey
                     AND HolidayDate BETWEEN @dToday AND @dDeliveryDate
                     AND HolidayDate <> @dDeliveryDate   -- if holiday=deliverydate then ignore holiday (james01)
            
                  IF DATEDIFF( DD, @dToday, @dDeliveryDate) - @nHoliday > 1
                     SET @cExtendedInfo = '[@@]'
               END
            END
         END

         SET @cExtendedInfo = LEFT( @cExtendedInfo + @cCompany, 20)
      END

      IF @nAfterStep = 3 -- SKU
      BEGIN
         -- Get PickSlip info
         SELECT @cOrderKey = OrderKey FROM PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo

         -- Get order info
         SELECT @cConsigneeKey = ConsigneeKey FROM Orders O WITH (NOLOCK) WHERE OrderKey = @cOrderKey

         -- Get consignee info
         SELECT @cSUSR5 = SUSR5 FROM Storer WITH (NOLOCK) WHERE StorerKey = @cConsigneeKey

         IF (@cSUSR5 = '!!') OR 
            (@cSUSR5 <> '!!' AND @cSUSR5 <> '@@')
         BEGIN
            DECLARE @cUDF01 NVARCHAR( 60)
            DECLARE @cUDF02 NVARCHAR( 60)
            DECLARE @cUDF03 NVARCHAR( 60)
            DECLARE @cUDF04 NVARCHAR( 60)
            DECLARE @cUDF05 NVARCHAR( 60)
            
            SET @cUDF01 = ''
            SET @cUDF02 = ''
            SET @cUDF03 = ''
            SET @cUDF04 = ''
            SET @cUDF05 = ''
            
            -- Get Consignee SKU info
            SELECT 
               @cUDF01 = UDF01, 
               @cUDF02 = UDF02, 
               @cUDF03 = UDF03, 
               @cUDF04 = UDF04, 
               @cUDF05 = UDF05
            FROM ConsigneeSKU WITH (NOLOCK) 
            WHERE ConsigneeKey = @cConsigneeKey
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU

            IF @cSUSR5 = '!!'
               SET @cExtendedInfo = 
                  LEFT( @cUDF01, 1) + 
                  LEFT( @cUDF02, 1) + 
                  LEFT( @cUDF03, 1) + 
                  LEFT( @cUDF04, 1) + 
                  LEFT( @cUDF05, 1)
            ELSE
               IF @cUDF01 <> '' OR 
                  @cUDF02 <> '' OR 
                  @cUDF03 <> '' OR 
                  @cUDF04 <> '' OR 
                  @cUDF05 <> '' 
                  SET @cExtendedInfo = '[**]'
         END
      END
   END

Quit:

END

GO